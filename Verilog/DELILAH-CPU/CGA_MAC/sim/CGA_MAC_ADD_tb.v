/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MAC_ADD testbench                                                 **
**                                                                       **
** DUT: DELILAH-CPU/CGA_MAC/circuit/CGA_MAC_ADD.v (/CGA/MAC/ADD,        **
** page 29) - the MAC address adder. Pure combinational: 32 A02 AOI     **
** cells + 16 bubbled OR gates form a 4-way source selector             **
** PRP[n] = (RB[n]&PRB)|(BR[n]&PB)|(XR[n]&PX)|(LCA[n]&PLCA) (sources   **
** OR together when several selects are up); an 11-NAND network forms   **
** the effective CD high byte (CDS=0 -> CD[15:8]; CDS=1 -> eight        **
** copies of CD[7], i.e. SIGN EXTENSION of the low displacement byte);  **
** FASTADD then computes ADD = (PRP + effCD) mod 2^16.                  **
**                                                                       **
** Independent golden model (derived from the schematic intent, not     **
** transliterated from the gates): behavioral select-OR + sign-extend   **
** + 16-bit truncated add.                                              **
**                                                                       **
** Netlist-vs-header notes (gates verified, NOT transcription errors):  **
**  - The CDS port comment says "only the low 8 bits are added"; the    **
**    gates actually SIGN-EXTEND CD[7:0] (CDS=1, CD[7]=1 gives high     **
**    byte FF). Correct for signed 8-bit displacement arithmetic.       **
**  - The header note "Add CD if PLCA is low" is usage, not gating:     **
**    the netlist adds CD unconditionally for every select combo.       **
**                                                                       **
** Coverage layers (fixed expected total 121536 checks):                **
**  1. Exhaustive control subspace: all 32 {PB,PRB,PX,PLCA,CDS}         **
**     combos x 18 directed data tuples (zeros, ones, alternating,     **
**     distinct-source identity to catch select swaps, full carry      **
**     chains FFFF+1, sign-extension corners) = 576.                    **
**  2. Carry-position corners, every bit 0..15 x each of the 4          **
**     single-select modes x 3 patterns (two's-complement cancel,      **
**     FFFF ripple, equal-bit single carry) = 192.                      **
**  3. CDS sign-extension exhaustive: all 256 CD low-byte values x 3    **
**     CD high bytes {00,5A,FF} (must be ignored) = 768.                **
**  4. Fixed-seed random soak: 120000 full-width vectors (all five     **
**     16-bit words + 5 control bits random) vs the golden model.       **
**                                                                       **
** Teeth (scratch mutant, never committed): GATES_31 input pin moved    **
** from s_cdsn_nand_cd12 to s_cdsn_nand_cd11 (single wrong input pin    **
** in the CD high-byte network) -> TB_RESULT: FAIL.                     **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent), with    **
** a hard expected-check-count assertion.                               **
**                                                                       **
** 01-AUG-2026                                                          **
** Ronny Hansen                                                         **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MAC_ADD_tb;

  reg [15:0] BR_15_0 = 0;
  reg [15:0] RB_15_0 = 0;
  reg [15:0] XR_15_0 = 0;
  reg [15:0] LCA_15_0 = 0;
  reg [15:0] CD_15_0 = 0;
  reg PB = 0;
  reg PRB = 0;
  reg PX = 0;
  reg PLCA = 0;
  reg CDS = 0;
  wire [15:0] ADD_15_0;

  integer errors = 0;
  integer checks = 0;
  integer c, p, i, sel, n, h;
  integer seed;
  reg [15:0] pat_br[0:17];
  reg [15:0] pat_rb[0:17];
  reg [15:0] pat_xr[0:17];
  reg [15:0] pat_lca[0:17];
  reg [15:0] pat_cd[0:17];
  reg [15:0] v_reg, v_cd, hi_byte, xr_fix;

  localparam integer EXPECTED_CHECKS = 576 + 192 + 768 + 120000;  // 121536

  CGA_MAC_ADD dut (
      .BR_15_0 (BR_15_0),
      .RB_15_0 (RB_15_0),
      .XR_15_0 (XR_15_0),
      .LCA_15_0(LCA_15_0),
      .PB      (PB),
      .PRB     (PRB),
      .PX      (PX),
      .PLCA    (PLCA),
      .CD_15_0 (CD_15_0),
      .CDS     (CDS),
      .ADD_15_0(ADD_15_0)
  );

  // Independent golden model, derived from the schematic intent:
  // 4-way OR-merging source selector, CDS sign extension, 16-bit add.
  function [15:0] golden;
    input [15:0] br, rb, xr, lca, cd;
    input pb, prb, px, plca, cds;
    reg [15:0] prp, effcd;
    begin
      prp = (prb ? rb : 16'h0000) | (pb ? br : 16'h0000)
          | (px ? xr : 16'h0000) | (plca ? lca : 16'h0000);
      effcd = cds ? {{8{cd[7]}}, cd[7:0]} : cd;
      golden = prp + effcd;  // natural 16-bit truncation
    end
  endfunction

  task check_vec;
    input [15:0] br, rb, xr, lca, cd;
    input pb, prb, px, plca, cds;
    reg [15:0] exp;
    begin
      BR_15_0  = br;
      RB_15_0  = rb;
      XR_15_0  = xr;
      LCA_15_0 = lca;
      CD_15_0  = cd;
      PB       = pb;
      PRB      = prb;
      PX       = px;
      PLCA     = plca;
      CDS      = cds;
      #1;
      exp = golden(br, rb, xr, lca, cd, pb, prb, px, plca, cds);
      checks = checks + 1;
      if (ADD_15_0 !== exp) begin
        errors = errors + 1;
        if (errors <= 20)
          $display(
              "FAIL: BR=%04h RB=%04h XR=%04h LCA=%04h CD=%04h PB=%b PRB=%b PX=%b PLCA=%b CDS=%b -> ADD=%04h expected %04h",
              br, rb, xr, lca, cd, pb, prb, px, plca, cds, ADD_15_0, exp);
      end
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_MAC_ADD_tb: FPGA_FF_MODE build (module is pure comb)");
`else
    $display("CGA_MAC_ADD_tb: plain build");
`endif

    // ------------------------------------------------------------------
    // 1. Exhaustive control subspace x directed data patterns.
    //    Pattern 2/3 give every source a distinct value so any select
    //    swap (PRB<->PB, PX<->PLCA, A02 pin swap) changes the result.
    // ------------------------------------------------------------------
    pat_br[0]='h0000; pat_rb[0]='h0000; pat_xr[0]='h0000; pat_lca[0]='h0000; pat_cd[0]='h0000;
    pat_br[1]='hFFFF; pat_rb[1]='hFFFF; pat_xr[1]='hFFFF; pat_lca[1]='hFFFF; pat_cd[1]='hFFFF;
    pat_br[2]='h1111; pat_rb[2]='h2222; pat_xr[2]='h4444; pat_lca[2]='h8888; pat_cd[2]='h0000;
    pat_br[3]='h1111; pat_rb[3]='h2222; pat_xr[3]='h4444; pat_lca[3]='h8888; pat_cd[3]='h0001;
    pat_br[4]='hAAAA; pat_rb[4]='h5555; pat_xr[4]='hAAAA; pat_lca[4]='h5555; pat_cd[4]='h5555;
    pat_br[5]='h5555; pat_rb[5]='hAAAA; pat_xr[5]='h5555; pat_lca[5]='hAAAA; pat_cd[5]='hAAAA;
    pat_br[6]='hFFFF; pat_rb[6]='hFFFF; pat_xr[6]='hFFFF; pat_lca[6]='hFFFF; pat_cd[6]='h0001;
    pat_br[7]='h0001; pat_rb[7]='h0001; pat_xr[7]='h0001; pat_lca[7]='h0001; pat_cd[7]='hFFFF;
    pat_br[8]='h00FF; pat_rb[8]='h00FF; pat_xr[8]='h00FF; pat_lca[8]='h00FF; pat_cd[8]='hFF01;
    pat_br[9]='h8000; pat_rb[9]='h8000; pat_xr[9]='h8000; pat_lca[9]='h8000; pat_cd[9]='h8000;
    pat_br[10]='h7FFF; pat_rb[10]='h7FFF; pat_xr[10]='h7FFF; pat_lca[10]='h7FFF; pat_cd[10]='h0001;
    pat_br[11]='h1234; pat_rb[11]='h5678; pat_xr[11]='h9ABC; pat_lca[11]='hDEF0; pat_cd[11]='h0F0F;
    pat_br[12]='h0000; pat_rb[12]='h0000; pat_xr[12]='h0000; pat_lca[12]='h0000; pat_cd[12]='h0080;
    pat_br[13]='hFFFF; pat_rb[13]='h0000; pat_xr[13]='hFFFF; pat_lca[13]='h0000; pat_cd[13]='h0080;
    pat_br[14]='h0100; pat_rb[14]='h0200; pat_xr[14]='h0400; pat_lca[14]='h0800; pat_cd[14]='hFF7F;
    pat_br[15]='h4321; pat_rb[15]='h8765; pat_xr[15]='hCBA9; pat_lca[15]='h0FED; pat_cd[15]='hFF80;
    pat_br[16]='h00FF; pat_rb[16]='hFF00; pat_xr[16]='h0F0F; pat_lca[16]='hF0F0; pat_cd[16]='h55AA;
    pat_br[17]='hFEDC; pat_rb[17]='hBA98; pat_xr[17]='h7654; pat_lca[17]='h3210; pat_cd[17]='h8001;

    for (c = 0; c < 32; c = c + 1)
      for (p = 0; p < 18; p = p + 1)
        check_vec(pat_br[p], pat_rb[p], pat_xr[p], pat_lca[p], pat_cd[p],
                  c[0], c[1], c[2], c[3], c[4]);

    // ------------------------------------------------------------------
    // 2. Carry-position corners: every bit position, each single-select
    //    mode, CDS=0.
    //    a) reg = 1<<i, CD = two's complement -> sum 0, carry ripples
    //       from bit i out the top.
    //    b) reg = FFFF, CD = 1<<i -> ripple from bit i, result (1<<i)-1.
    //    c) reg = CD = 1<<i -> single carry generate at bit i.
    // ------------------------------------------------------------------
    for (i = 0; i < 16; i = i + 1)
      for (sel = 0; sel < 4; sel = sel + 1) begin
        v_reg = 16'h0001 << i;
        v_cd  = (~v_reg) + 16'h0001;
        check_vec(sel == 0 ? v_reg : 16'h0, sel == 1 ? v_reg : 16'h0,
                  sel == 2 ? v_reg : 16'h0, sel == 3 ? v_reg : 16'h0,
                  v_cd, sel == 0, sel == 1, sel == 2, sel == 3, 1'b0);
        check_vec(sel == 0 ? 16'hFFFF : 16'h0, sel == 1 ? 16'hFFFF : 16'h0,
                  sel == 2 ? 16'hFFFF : 16'h0, sel == 3 ? 16'hFFFF : 16'h0,
                  v_reg, sel == 0, sel == 1, sel == 2, sel == 3, 1'b0);
        check_vec(sel == 0 ? v_reg : 16'h0, sel == 1 ? v_reg : 16'h0,
                  sel == 2 ? v_reg : 16'h0, sel == 3 ? v_reg : 16'h0,
                  v_reg, sel == 0, sel == 1, sel == 2, sel == 3, 1'b0);
      end

    // ------------------------------------------------------------------
    // 3. CDS sign-extension exhaustive: every CD[7:0] value with three
    //    CD[15:8] values that must be ignored; PX-selected base varies.
    // ------------------------------------------------------------------
    for (h = 0; h < 3; h = h + 1) begin
      hi_byte = (h == 0) ? 16'h00 : (h == 1) ? 16'h5A : 16'hFF;
      xr_fix  = (h == 0) ? 16'h0123 : (h == 1) ? 16'h4567 : 16'hFFFF;
      for (i = 0; i < 256; i = i + 1)
        check_vec(16'h0, 16'h0, xr_fix, 16'h0, {hi_byte[7:0], i[7:0]},
                  1'b0, 1'b0, 1'b1, 1'b0, 1'b1);
    end

    // ------------------------------------------------------------------
    // 4. Fixed-seed random soak: 120000 full-width vectors.
    // ------------------------------------------------------------------
    seed = 32'h00AD0D12;
    for (n = 0; n < 120000; n = n + 1) begin
      pat_br[0]  = $random(seed);
      pat_rb[0]  = $random(seed);
      pat_xr[0]  = $random(seed);
      pat_lca[0] = $random(seed);
      pat_cd[0]  = $random(seed);
      c          = $random(seed);
      check_vec(pat_br[0], pat_rb[0], pat_xr[0], pat_lca[0], pat_cd[0],
                c[0], c[1], c[2], c[3], c[4]);
    end

    // ------------------------------------------------------------------
    // Verdict. A short count means part of the tb silently did not run.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)",
               errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule
