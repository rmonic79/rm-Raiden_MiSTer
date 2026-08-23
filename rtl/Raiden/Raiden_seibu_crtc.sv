// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) Umberto Parisi (rmonic79). GPL v3 or later.
//
/*  Raiden_MiSTer — Seibu CRTC per raidenb (newer hardware).
    Author: Umberto Parisi (rmonic79)

    Origine: _dev/dead_code_archive/Raiden/Raiden_seibu_crtc.sv (versione 68k),
    adattato al bus V30 del main (byte-enable attivi alti) con due correzioni:
      1. widx usava addr[5:1] perdendo addr[6]: i registri 0x40-0x4E (che il
         gioco scrive al boot, vregs default) aliasavano su 0x00-0x0E.
         Ora widx = addr[6:1] (0..0x27 = 40 word, offset byte 0x00-0x4E).
      2. Mappatura output sugli usi REALI di raidenb (raiden.cpp:273-282,
         791-794), non sulla doc generica CRTC:
           reg 0x1C (layer_en): d0=BG disable, d1=FG disable, d4=SPR disable
             (in Raiden il layer FG e' lo "screen 2" del CRTC → bit 1).
             d3 (text) qui e' IGNORATO: il text enable di raidenb sta nel
             control register 0x0B006 d3.
           reg 0x20/0x22 = BG scroll X/Y; reg 0x24/0x26 = FG scroll X/Y
             (word intere, dirette — nessuna ricomposizione byte).
           reg 0x28/0x2A (screen1 X/Y): scritti dal gioco, non usati.
           reg 0x1A: flip NON viene da qui in raidenb (callback non collegata
             in MAME); il flip sta nel control 0x0B006 d1.

    Mappa CPU: 0x0D040-0x0D08F (rw). addr = offset byte [6:1].
    Pure register file: scrittura → RAM interna, lettura senza side effect.
    Reset: azzera tutto (il device reale azzera solo 0x1A; azzerare anche il
    resto evita X in sim e lascia i layer ABILITATI — ~0 — finche' la ROM
    non scrive i suoi valori).
*/

module Raiden_seibu_crtc (
	input  wire        clk,
	input  wire        reset,

	// Bus 16-bit dal main V30 (offset byte 0x00-0x4F dentro 0x0D040-0x0D08F)
	input  wire        cs,
	input  wire        wr,
	input  wire        rd,
	input  wire  [6:1] addr,       // offset word 0x00..0x27
	input  wire  [1:0] be,         // byte enable attivi alti ([0]=low, [1]=high)
	input  wire [15:0] wdata,
	output reg  [15:0] rdata,

	// Layer enable per raidenb (gia' negati: 1 = layer visibile)
	output wire        layer_en_bg,
	output wire        layer_en_fg,
	output wire        layer_en_spr,

	// Scroll word intere (raidenb_state::screen_update: passate raw ai layer)
	output wire [15:0] scroll_bg_x,
	output wire [15:0] scroll_bg_y,
	output wire [15:0] scroll_fg_x,
	output wire [15:0] scroll_fg_y
);

	// 40 word (offset byte 0x00..0x4E)
	reg [15:0] regs [0:39];

	wire [5:0] widx = addr[6:1];

	// ── Write ────────────────────────────────────────────────────────────────
	integer i;
	always @(posedge clk) begin
		if (reset) begin
			for (i = 0; i < 40; i = i + 1) regs[i] <= 16'h0000;
		end else if (cs && wr) begin
			if (widx < 6'd40) begin
				if (be[1]) regs[widx][15:8] <= wdata[15:8];
				if (be[0]) regs[widx][7:0]  <= wdata[7:0];
			end
		end
	end

	// ── Read (pure register file, no side effects) ───────────────────────────
	always @(*) begin
		rdata = (cs && rd && widx < 6'd40) ? regs[widx] : 16'hFFFF;
	end

	// ── Output decode ────────────────────────────────────────────────────────
	// reg index = offset byte / 2: 0x1C → 0x0E; 0x20..0x26 → 0x10..0x13
	wire [15:0] reg_1c = regs[6'h0E];

	// MAME raidenb layer_enable_w: bit=1 → layer DISABILITATO. Esposti negati.
	assign layer_en_bg  = ~reg_1c[0];
	assign layer_en_fg  = ~reg_1c[1];
	assign layer_en_spr = ~reg_1c[4];

	assign scroll_bg_x = regs[6'h10];   // 0x20
	assign scroll_bg_y = regs[6'h11];   // 0x22
	assign scroll_fg_x = regs[6'h12];   // 0x24
	assign scroll_fg_y = regs[6'h13];   // 0x26

endmodule
