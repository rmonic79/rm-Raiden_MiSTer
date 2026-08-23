// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) Umberto Parisi (rmonic79). GPL v3 or later.
//
// Raiden Sub V30 address translator (pattern Irem M72 pal.sv)
// Decodifica address V30 Sub → memrq segnali per region access.
// Memory map MAME raiden_state::sub_map (riga 490-501):
//   0x00000-0x01FFF  RAM (8KB)                → ram_memrq
//   0x02000-0x027FF  bgram (R/W)              → bgram_memrq
//   0x02800-0x02FFF  fgram (R/W)              → fgram_memrq
//   0x03000-0x03FFF  palette (R/W xBGR_444)   → palette_memrq
//   0x04000-0x04FFF  shared RAM (Main)        → shared_memrq
//   0x07FFE-0x07FFF  nopw (?)                 → nopw_a_memrq
//   0x08000-0x08001  watchdog (?)             → nopw_wd_memrq
//   0x0A000-0x0A001  nopw (?)                 → nopw_b_memrq
//   0xC0000-0xFFFFF  ROM (SDRAM)              → ls245_en
//
// ls245_en alto SOLO per region SDRAM (ROM Sub). Le altre region sono
// BRAM interni → no stall.

module raiden_addr_sub
(
	input  logic [19:0] A,
	input  logic        DBEN,    // = rd | wr (bus enable: pulse durante accesso)

	// SDRAM ROM region
	output logic        ls245_en,    // alto se A in ROM range $C0000-$FFFFF
	output logic [23:0] sdr_addr,    // byte addr SDRAM (relativo a base 0)

	// BRAM region select (combinatorio)
	output logic        ram_memrq,        // $00000-$01FFF
	output logic        bgram_memrq,      // $02000-$027FF
	output logic        fgram_memrq,      // $02800-$02FFF
	output logic        palette_memrq,    // $03000-$03FFF
	output logic        shared_memrq,     // $04000-$04FFF
	output logic        nopw_a_memrq,     // $07FFE-$07FFF
	output logic        nopw_wd_memrq,    // $08000-$08001
	output logic        nopw_b_memrq      // $0A000-$0A001
);

always_comb begin
	// Default tutti 0
	ram_memrq      = 1'b0;
	bgram_memrq    = 1'b0;
	fgram_memrq    = 1'b0;
	palette_memrq  = 1'b0;
	shared_memrq   = 1'b0;
	nopw_a_memrq   = 1'b0;
	nopw_wd_memrq  = 1'b0;
	nopw_b_memrq   = 1'b0;
	ls245_en       = 1'b0;
	sdr_addr       = 24'd0;

	if (DBEN) begin
		if (A < 20'h02000) begin
			// $00000-$01FFF: Sub RAM 8KB
			ram_memrq = 1'b1;
		end else if (A < 20'h02800) begin
			// $02000-$027FF: bgram (R/W)
			bgram_memrq = 1'b1;
		end else if (A < 20'h03000) begin
			// $02800-$02FFF: fgram (R/W)
			fgram_memrq = 1'b1;
		end else if (A < 20'h04000) begin
			// $03000-$03FFF: palette RAM (xBGR_444)
			palette_memrq = 1'b1;
		end else if (A < 20'h05000) begin
			// $04000-$04FFF: shared RAM 4KB
			shared_memrq = 1'b1;
		end else if ((A >= 20'h07FFE) && (A < 20'h08000)) begin
			// $07FFE-$07FFF: nopw
			nopw_a_memrq = 1'b1;
		end else if ((A >= 20'h08000) && (A < 20'h08002)) begin
			// $08000-$08001: watchdog
			nopw_wd_memrq = 1'b1;
		end else if ((A >= 20'h0A000) && (A < 20'h0A002)) begin
			// $0A000-$0A001: nopw
			nopw_b_memrq = 1'b1;
		end else if (A >= 20'h0C0000) begin
			// $C0000-$FFFFF: ROM (SDRAM)
			ls245_en = 1'b1;
			sdr_addr = {4'd0, A} - 24'h0C0000;
		end
		// else: unmapped, open bus
	end
end

endmodule
