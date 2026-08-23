// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) Umberto Parisi (rmonic79). GPL v3 or later.
//
// Raiden Main V30 address translator (pattern Irem M72 pal.sv)
// Decodifica address V30 Main → memrq segnali per region access.
// Memory map MAME raiden_state::main_map (riga 475-488):
//   0x00000-0x06FFF  RAM (28KB)               → ram_memrq
//   0x07000-0x07FFF  spriteram (4KB)          → sprite_memrq
//   0x08000-0x08FFF  shared RAM (Sub)         → shared_memrq
//   0x0A000-0x0A00D  seibu_sound (umask 00FF) → sound_memrq
//   0x0C000-0x0C7FF  textram (writeonly)      → text_memrq
//   0x0E000-0x0E001  P1_P2 (read)             → p1p2_memrq
//   0x0E002-0x0E003  DSW (read)               → dsw_memrq
//   0x0E004-0x0E005  watchdog (nopw)          → watchdog_memrq
//   0x0E006-0x0E006  control_w                → ctrl_memrq
//   0x0F000-0x0F03F  scroll_ram (writeonly)   → scroll_memrq
//   0xA0000-0xFFFFF  ROM (SDRAM)              → ls245_en
//
// board_raidenb=1: mappa raidenb_state::main_map (raiden.cpp:537-550) —
//   shared 0x0A000, I/O+ctrl 0x0B00x, sound 0x0D000, Seibu CRTC 0x0D040-8F,
//   niente scroll_ram. Stessi segnali riusati, piu' crtc_memrq.
//
// ls245_en alto SOLO per region SDRAM (ROM Main). Le altre region sono
// BRAM/registri interni → no stall.

module raiden_addr_main
(
	input  logic [19:0] A,
	input  logic        DBEN,    // = rd | wr (bus enable: pulse durante accesso)
	input  logic        board_raidenb, // 0=set classici, 1=raidenb (newer hw)

	// SDRAM ROM region
	output logic        ls245_en,    // alto se A in ROM range $A0000-$FFFFF
	output logic [23:0] sdr_addr,    // byte addr SDRAM (relativo a base 0)

	// BRAM region select (combinatorio)
	output logic        ram_memrq,       // $00000-$06FFF
	output logic        sprite_memrq,    // $07000-$07FFF
	output logic        shared_memrq,    // $08000-$08FFF
	output logic        sound_memrq,     // $0A000-$0A00D (8-bit)
	output logic        text_memrq,      // $0C000-$0C7FF (write-only)
	output logic        p1p2_memrq,      // $0E000-$0E001 (read)
	output logic        dsw_memrq,       // $0E002-$0E003 (read)
	output logic        watchdog_memrq,  // $0E004-$0E005 (write nop)
	output logic        ctrl_memrq,      // $0E006        (write 8-bit)
	output logic        scroll_memrq,    // $0F000-$0F03F (write-only)
	output logic        crtc_memrq       // raidenb: $0D040-$0D08F (rw)
);

always_comb begin
	// Default tutti 0
	ram_memrq      = 1'b0;
	sprite_memrq   = 1'b0;
	shared_memrq   = 1'b0;
	sound_memrq    = 1'b0;
	text_memrq     = 1'b0;
	p1p2_memrq     = 1'b0;
	dsw_memrq      = 1'b0;
	watchdog_memrq = 1'b0;
	ctrl_memrq     = 1'b0;
	scroll_memrq   = 1'b0;
	crtc_memrq     = 1'b0;
	ls245_en       = 1'b0;
	sdr_addr       = 24'd0;

	if (DBEN && board_raidenb) begin
		// raidenb_state::main_map (raiden.cpp:537-550)
		if (A < 20'h07000) begin
			// $00000-$06FFF: Main RAM 28KB
			ram_memrq = 1'b1;
		end else if (A < 20'h08000) begin
			// $07000-$07FFF: spriteram 4KB
			sprite_memrq = 1'b1;
		end else if ((A >= 20'h0A000) && (A < 20'h0B000)) begin
			// $0A000-$0AFFF: shared RAM 4KB
			shared_memrq = 1'b1;
		end else if ((A >= 20'h0B000) && (A < 20'h0B002)) begin
			// $0B000-$0B001: P1_P2 input
			p1p2_memrq = 1'b1;
		end else if ((A >= 20'h0B002) && (A < 20'h0B004)) begin
			// $0B002-$0B003: DSW
			dsw_memrq = 1'b1;
		end else if ((A >= 20'h0B004) && (A < 20'h0B006)) begin
			// $0B004-$0B005: watchdog (nopw)
			watchdog_memrq = 1'b1;
		end else if ((A >= 20'h0B006) && (A < 20'h0B007)) begin
			// $0B006: control_w (8-bit; d1=flip, d3=text disable)
			ctrl_memrq = 1'b1;
		end else if ((A >= 20'h0C000) && (A < 20'h0C800)) begin
			// $0C000-$0C7FF: text RAM (write-only from Main)
			text_memrq = 1'b1;
		end else if ((A >= 20'h0D000) && (A < 20'h0D00E)) begin
			// $0D000-$0D00D: seibu sound (8-bit umask 00FF)
			sound_memrq = 1'b1;
		end else if ((A >= 20'h0D040) && (A < 20'h0D090)) begin
			// $0D040-$0D08F: Seibu CRTC (rw)
			crtc_memrq = 1'b1;
		end else if (A >= 20'h0A0000) begin
			// $A0000-$FFFFF: ROM (SDRAM)
			ls245_en = 1'b1;
			sdr_addr = {4'd0, A} - 24'h0A0000;
		end
		// else: unmapped (incl. $08000-$09FFF), open bus
	end else if (DBEN) begin
		if (A < 20'h07000) begin
			// $00000-$06FFF: Main RAM 28KB
			ram_memrq = 1'b1;
		end else if (A < 20'h08000) begin
			// $07000-$07FFF: spriteram 4KB
			sprite_memrq = 1'b1;
		end else if (A < 20'h09000) begin
			// $08000-$08FFF: shared RAM 4KB
			shared_memrq = 1'b1;
		end else if ((A >= 20'h0A000) && (A < 20'h0A00E)) begin
			// $0A000-$0A00D: seibu sound (8-bit umask 00FF)
			sound_memrq = 1'b1;
		end else if ((A >= 20'h0C000) && (A < 20'h0C800)) begin
			// $0C000-$0C7FF: text RAM (write-only from Main)
			text_memrq = 1'b1;
		end else if ((A >= 20'h0E000) && (A < 20'h0E002)) begin
			// $0E000-$0E001: P1_P2 input
			p1p2_memrq = 1'b1;
		end else if ((A >= 20'h0E002) && (A < 20'h0E004)) begin
			// $0E002-$0E003: DSW
			dsw_memrq = 1'b1;
		end else if ((A >= 20'h0E004) && (A < 20'h0E006)) begin
			// $0E004-$0E005: watchdog (nopw)
			watchdog_memrq = 1'b1;
		end else if ((A >= 20'h0E006) && (A < 20'h0E007)) begin
			// $0E006: control_w (8-bit)
			ctrl_memrq = 1'b1;
		end else if ((A >= 20'h0F000) && (A < 20'h0F040)) begin
			// $0F000-$0F03F: scroll_ram (write-only)
			scroll_memrq = 1'b1;
		end else if (A >= 20'h0A0000) begin
			// $A0000-$FFFFF: ROM (SDRAM)
			ls245_en = 1'b1;
			sdr_addr = {4'd0, A} - 24'h0A0000;
		end
		// else: unmapped, open bus (tutti i memrq=0)
	end
end

endmodule
