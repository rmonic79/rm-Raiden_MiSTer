// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) Umberto Parisi (rmonic79). GPL v3 or later.
//
/*  Raiden_MiSTer — Text layer renderer Seibu D-Con (8x8, 4bpp, 64x32).
    Author: Umberto Parisi (rmonic79)

    Specifiche da MAME (src/mame/seibu/dcon.cpp):

      // get_text_tile_info
      tile  = textram[tile_index];
      color = (tile >> 12) & 0xf;
      tile  = tile & 0xfff;
      tileinfo.set(0, tile, color, 0);

      // create
      m_text_layer = create(... TILEMAP_SCAN_ROWS, 8, 8, 64, 32);
      m_text_layer->set_transparent_pen(15);

      // GFXDECODE
      GFXDECODE_ENTRY("txtiles", 0, dcon_charlayout, 1024+768, 16);
      // → color base = 0x700, 16 colorset

      // sdgndmps_map dispatcher
      m_text_layer->set_scrollx(0, 128);
      m_text_layer->set_scrolly(0, 0);

      // dcon_charlayout
      8x8, RGN_FRAC(1,2), 4 bpp,
      planes  = { 0, 4, 0x80000, 0x80004 },     // bit-offset
      x_bits  = { 3,2,1,0, 11,10,9,8 },         // pixel→bit-offset
      y_bits  = { 0,16,32,...,7*16 },
      tile_size = 128 bit (= 16 byte per metà)

    Char ROM mapping in SDRAM (vedi MRA):
      0x080000..0x08FFFF (64KB): planes 0,1 (= ROM 911-a08.66)
      0x090000..0x09FFFF (64KB): planes 2,3 (= ROM 911-a07.73)

    Cache strategy: 128KB BRAM totali (32 M10K), tutti i 4096 char,
    caricati durante MRA download via ioctl_addr 0x080000..0x09FFFF.

    Pixel decode per (col, row) di char idx:
      byte_lo = char_lo[idx*16 + row*2 + (col>=4 ? 1 : 0)]
      byte_hi = char_hi[idx*16 + row*2 + (col>=4 ? 1 : 0)]
      sub     = 3 - (col & 3)
      pen[0]  = byte_lo[sub]
      pen[1]  = byte_lo[sub+4]
      pen[2]  = byte_hi[sub]
      pen[3]  = byte_hi[sub+4]

    Pen finale a palette = 0x300 + (color << 4) + pen, transparent se pen==15.
    (raiden.cpp:697 GFXDECODE text 768 16 → palette base 0x300)
*/

module Raiden_text_renderer (
	input  wire        clk,
	input  wire        reset,
	input  wire        ce_pix,

	// raidenb (newer hardware): text tilemap TILEMAP_SCAN_COLS (raiden.cpp:463-471)
	// → vram_addr = col*32+row invece di row*32+col. 0 = set classici (SCAN_ROWS).
	input  wire        scan_cols,

	// Text decoder mode esteso (7 bit):
	//   bit 0: BS  byte swap (crom_lo ↔ crom_hi)
	//   bit 1: SI  sub direction (3-sub vs sub)
	//   bit 2: BL  bit position (sub/4+sub vs 3-sub/7-sub)
	//   bit 3: BR  byte-reverse (swap dei 2 byte interni alla word — N/A per text 8-bit/byte)
	//   bit 4: NIB nibble swap dentro ogni byte (HI↔LO 4-bit)
	//   bit 5: INV pen invert (XOR ~pen → cambia mapping pen 0↔15, utile se nero/grigio invertiti)
	//   bit 6: WS  word swap (swap col_s2[2] e quindi byte_sel half tile)
	input  wire  [6:0] decode_mode,

	// Video timing
	input  wire  [9:0] hpos,        // 0..383
	input  wire  [8:0] vpos,        // 0..262
	input  wire        de,
	input  wire        layer_en,
	input  wire        flip_screen, // DIP flip: specchia eff_x/eff_y

	// CRTC scroll (Raiden Text: 128 X, 0 Y; lasciamo input parametrico)
	input  wire [15:0] scroll_x,
	input  wire [15:0] scroll_y,

	// OSD offset di rendering (debug pixel-hunting)
	input  wire signed [9:0] xoff,
	input  wire signed [9:0] yoff,

	// Text VRAM read port (4KB = 2Kw, 64*32 grid)
	output reg  [10:0] vram_addr,   // 0..2047
	input  wire [15:0] vram_data,

	// Char ROM download via ioctl (WIDE=1 → 2 byte/word a indirizzi pari)
	// rom_dl_addr = byte address relativo al txtiles (0..0x1FFFF), [0]=0
	// rom_dl_data = {byte_high, byte_low}: byte_low scritto a addr, byte_high a addr+1
	//   bit[16] = 0 → metà bassa (plane 0,1)
	//   bit[16] = 1 → metà alta  (plane 2,3)
	input  wire        rom_dl_wr,
	input  wire [16:0] rom_dl_addr,
	input  wire [15:0] rom_dl_data,

	// Output pixel (combinatoriale: ultimo pixel a destra mostrato senza latency)
	output wire        opaque,
	output wire [10:0] pen_index
);

	// ── Char ROM cache: MRA section Text è interleave word di file 9 + file 10.
	// MRA: <interleave output=16><part 9 map=01/><part 10 map=10/></interleave>
	//   → ioctl_dout[7:0]  = byte da file 9  (planes 0,1)
	//   → ioctl_dout[15:8] = byte da file 10 (planes 2,3)
	// Ogni file è 32 KB byte. Indice byte all'interno del file = (rom_dl_addr - 0x000) / 2.
	// In ingresso rom_dl_addr è 17-bit ma il filtro Raiden.sv limita a 0..0xFFFF (64KB byte).
	// Quindi byte index nel file = rom_dl_addr[15:1] (range 0..32767).
	//
	// La pipeline pen-decode aspetta:
	//   crom_lo_byte = byte di file 9 a byte_off (idx*16 + row*2 + col[2])
	//   crom_hi_byte = byte di file 10 a byte_off identico
	// Quindi le BRAM sono BYTE-WIDE (8-bit), indicizzate per byte_addr 0..32767.
	(* ramstyle = "M10K,no_rw_check" *) reg [7:0] charrom_lo [0:32767];
	(* ramstyle = "M10K,no_rw_check" *) reg [7:0] charrom_hi [0:32767];
	always @(posedge clk) begin
		if (rom_dl_wr) begin
			charrom_lo[rom_dl_addr[15:1]] <= rom_dl_data[7:0];   // file 9 byte (planes 0,1)
			charrom_hi[rom_dl_addr[15:1]] <= rom_dl_data[15:8];  // file 10 byte (planes 2,3)
		end
	end

	// ── Pipeline ──────────────────────────────────────────────────────────────
	// Stage 0: input hpos/vpos → calc tile coords, emit vram_addr
	// Stage 1: vram_data registered, calc charrom addr
	// Stage 2: charrom byte_lo/byte_hi registered, decode pen
	// Stage 3: pen + color → pen_index latched

	// --- Stage 0: tile coords ---
	// MAME raiden.cpp:458 text_layer = TILEMAP_SCAN_ROWS, 8x8, 32x32 tiles.
	// textram = 0x0c000-0x0c7ff = 2048 byte = 1024 word = 32x32.
	// tile_index (SCAN_ROWS) = row * 32 + col.
	//
	// Fix wrap orizzontale (pattern BloodBros commit b264939):
	// Pipeline ha 3 ce_pix di latency tra hpos input e pen mostrato. A screen X=0
	// senza compensazione, il pen mostrato e' quello calcolato per timing_hpos=46
	// (HBLANK 0x3FE) che con tilemap 32-col wrappa al tile 31 → primo char tagliato.
	// Soluzione: eff_x signed con +3 ce_pix anticipo + gate x_in_range per nascondere
	// il wrap off-screen. Output finale usa `de` corrente (non de_s2) cosi' i 3 px
	// anticipati non restano bloccati da de_s2 ritardato.
	// flip_screen (DIP): specchia SOLO hpos/vpos attorno al centro area visibile
	// (255 = H_VISIBLE-1, 223 = V_VISIBLE-1). Gli offset (+3 latency, scroll,
	// xoff/yoff) restano additivi FUORI dal mirror: se inclusi nel 255-... il
	// loro segno si invertirebbe e l'immagine si sposterebbe (bug precedente).
	// Centro X = 251 (255 - 4): compensa latency+offset del text flippato.
	// Verificato HW: 253 lasciava 2px fuori, 251 allinea.
	wire signed [10:0] hpos_f = flip_screen ? (11'sd251 - $signed({1'b0, hpos})) : $signed({1'b0, hpos});
	wire signed [10:0] vpos_f = flip_screen ? (11'sd223 - $signed({2'b0, vpos})) : $signed({2'b0, vpos});
	wire signed [10:0] eff_x_s = hpos_f + 11'sd3 + $signed(scroll_x[10:0]) + $signed({xoff[9], xoff});
	wire signed [10:0] eff_y_s = vpos_f + $signed(scroll_y[10:0]) + $signed({yoff[9], yoff});
	wire        x_in_range_s0 = (eff_x_s >= 11'sd0) && (eff_x_s < 11'sd384);
	wire  [4:0] tile_x_s0 = eff_x_s[7:3];
	wire  [4:0] tile_y_s0 = eff_y_s[7:3];
	wire  [2:0] row_s0    = eff_y_s[2:0];
	wire  [2:0] col_s0    = eff_x_s[2:0];

	always @(posedge clk) begin
		// SCAN_ROWS: row*32+col (set classici) / SCAN_COLS: col*32+row (raidenb)
		if (ce_pix) vram_addr <= scan_cols ? {1'b0, tile_x_s0, tile_y_s0}
		                                   : {1'b0, tile_y_s0, tile_x_s0};
	end

	// --- Stage 1: vram_data, decode tile + color ---
	reg [2:0] row_s1, col_s1;
	reg       de_s1, layer_en_s1, x_in_range_s1;
	always @(posedge clk) begin
		if (ce_pix) begin
			row_s1        <= row_s0;
			col_s1        <= col_s0;
			de_s1         <= de;
			layer_en_s1   <= layer_en;
			x_in_range_s1 <= x_in_range_s0;
		end
	end

	// vram_data è valido in stage 1 (BRAM read latency 1 ce_pix)
	// MAME raiden.cpp get_text_tile_info:
	//   tile  = (data & 0xff) | ((data >> 6) & 0x300)   = bit[7:0] | bit[15:14] in [9:8]
	//   color = (data >> 8) & 0x0f                       = bit[11:8]
	wire [9:0] tile_idx_s1 = {vram_data[15:14], vram_data[7:0]};
	wire [3:0] tile_clr_s1 = vram_data[11:8];

	// charrom byte addr: idx*16 + row*2 + (col>=4 ? 1:0)
	// Indicizzazione diretta a byte: 15-bit (32KB per metà).
	// tile_idx ora 10-bit (1024 char × 16 byte = 16384 byte = 14-bit indice).
	wire [14:0] crom_byte_addr_s1 = ({5'd0, tile_idx_s1}) << 4   // idx*16 (14-bit)
	                              | ({12'd0, row_s1}) << 1       // + row*2
	                              | ({14'd0, col_s1[2]});         // + (col>=4 ? 1:0)

	// --- Stage 2: charrom byte read (BRAM 1 ce_pix latency) ---
	reg [7:0]  crom_lo_s2_r, crom_hi_s2_r;
	reg [2:0]  col_s2;
	reg [3:0]  tile_clr_s2;
	reg        de_s2, layer_en_s2, x_in_range_s2;
	always @(posedge clk) begin
		if (ce_pix) begin
			crom_lo_s2_r  <= charrom_lo[crom_byte_addr_s1];
			crom_hi_s2_r  <= charrom_hi[crom_byte_addr_s1];
			col_s2        <= col_s1;
			tile_clr_s2   <= tile_clr_s1;
			de_s2         <= de_s1;
			layer_en_s2   <= layer_en_s1;
			x_in_range_s2 <= x_in_range_s1;
		end
	end

	// bit 4 NIB: nibble swap per byte (HI↔LO 4-bit)
	wire [7:0] crom_lo_n = decode_mode[4] ? {crom_lo_s2_r[3:0], crom_lo_s2_r[7:4]} : crom_lo_s2_r;
	wire [7:0] crom_hi_n = decode_mode[4] ? {crom_hi_s2_r[3:0], crom_hi_s2_r[7:4]} : crom_hi_s2_r;
	// bit 3 BR: byte-reverse (swap crom_lo↔crom_hi DOPO nibble; equivale a XOR su bit 0)
	wire [7:0] crom_lo_s2 = decode_mode[3] ? crom_hi_n : crom_lo_n;
	wire [7:0] crom_hi_s2 = decode_mode[3] ? crom_lo_n : crom_hi_n;
	// bit 6 WS: word swap = flip col_s2[2] (intra-tile half swap)
	wire [2:0] col_eff    = {decode_mode[6] ^ col_s2[2], col_s2[1:0]};

	// --- Stage 3: pen decode (parametrizzato via decode_mode) ---
	wire [7:0] byte_a = decode_mode[0] ? crom_lo_s2 : crom_hi_s2;
	wire [7:0] byte_b = decode_mode[0] ? crom_hi_s2 : crom_lo_s2;
	wire [1:0] sub    = decode_mode[1] ? (2'd3 - col_eff[1:0]) : col_eff[1:0];
	wire [2:0] bit_lo = decode_mode[2] ? {1'b0, sub}   : (3'd3 - {1'b0, sub});
	wire [2:0] bit_hi = decode_mode[2] ? (3'd4 + {1'b0, sub}) : (3'd7 - {1'b0, sub});
	wire pen0_raw = byte_a[bit_lo];
	wire pen1_raw = byte_a[bit_hi];
	wire pen2_raw = byte_b[bit_lo];
	wire pen3_raw = byte_b[bit_hi];
	wire [3:0] pen_raw = {pen3_raw, pen2_raw, pen1_raw, pen0_raw};
	// bit 5 INV: pen invert (XOR ~pen)
	wire [3:0] pen = decode_mode[5] ? ~pen_raw : pen_raw;

	// Output combinatoriale (no latency).
	// `de` e `layer_en` CORRENTI (non _s2 ritardati): pattern BB b264939.
	// I 3 px anticipati da eff_x +3 si allineano al `de` reale del display.
	wire pixel_active = de & layer_en & (pen != 4'd15);
	assign opaque    = pixel_active;
	assign pen_index = pixel_active ? (11'h300 + {3'd0, tile_clr_s2, pen}) : 11'd0;

endmodule
