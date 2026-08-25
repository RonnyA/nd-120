/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MAC_LASEL testbench                                               **
**                                                                       **
** Exhaustive verification of the LASEL block (/CGA/MAC/LASEL, page 39). **
** 19 combinational input bits (CSMREQ DOUBLE EXMN ICA_15_8[7:0]         **
** PCR_2_0[2:0] PEX PONI SEGZN SELPTN VEX) drive 11 combinational        **
** outputs; MCLK only clocks MEMORY_24 (D FF, posedge MCLK, LSHADOW =    **
** qBar of the captured s_shadow_n).                                     **
**                                                                       **
** Golden model: every gate instance was modeled literally (per-port     **
** hookup, Logisim BubblesMask semantics - note the inverted-input       **
** masks on GATES_18/19/20/21 and GATES_3 of the AND family) in the      **
** independent Python generator (gen_tier3_mac_golden.py, scratchpad     **
** only) and proven equal to the compact equations used below for ALL    **
** 2^19 = 524288 input combinations; the generator also emitted the      **
** sweep checksum constant and verified the two directed LSHADOW         **
** vectors (shadow_n = 0 and 1).                                         **
**                                                                       **
** Checks:                                                               **
**  1. Power-up: LSHADOW = 1 before any MCLK edge (FF inits to 0, qBar). **
**     1 check.                                                          **
**  2. Exhaustive comb sweep: all 524288 input combos, the 11-bit output **
**     bundle {A10,A1617,A1619,A1819,B1819,B1821,BB10,C10,D1617,E1617,   **
**     F1617} vs the verified compact model. 524288 checks.              **
**  3. Running checksum of the actual bundle sequence vs the Python      **
**     constant (chk = chk*33 + bundle mod 2^32). 1 check.               **
**  4. LSHADOW capture + hold: 16 MCLK pulses alternating shadow_n=0/1   **
**     vectors; after each pulse LSHADOW == ~shadow_n(captured), then    **
**     the opposite vector is driven WITHOUT a pulse and LSHADOW must    **
**     hold. 32 checks.                                                  **
**                                                                       **
** Build modes: MEMORY_24 is a D_FLIPFLOP_EN, so the Makefile target     **
** runs plain (posedge-MCLK FF) and -DFPGA_FF_MODE (sysclk+MCLK_EN       **
** capture). No L4/L8/LATCH primitives - USE_TRANSPARENT_LATCHES does    **
** not apply to this module.                                             **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MAC_LASEL_tb;

  reg        sysclk = 0;
  reg        MCLK_EN = 0;
  reg        MCLK = 0;

  reg        CSMREQ = 0;
  reg        DOUBLE = 0;
  reg        EXMN = 0;
  reg [7:0]  ICA = 0;
  reg [2:0]  PCR = 0;
  reg        PEX = 0;
  reg        PONI = 0;
  reg        SEGZN = 0;
  reg        SELPTN = 0;
  reg        VEX = 0;

  wire A10, A1617, A1619, A1819, B1819, B1821;
  wire BB10, C10, D1617, E1617, F1617, LSHADOW;

  integer errors = 0;
  integer checks = 0;
  integer i;
  reg [31:0] chk;
  reg [11:0] exp_g;
  reg        exp_ls;

  localparam integer EXPECTED_CHECKS = 524322;
  // Emitted by gen_tier3_mac_golden.py (chk = chk*33 + bundle, i ascending)
  localparam [31:0] SWEEP_CHECKSUM = 32'h828C2B30;

  // Directed vectors (verified by the generator):
  // shadow_n=0 needs all five GATES_22 inputs high: ex=1 (DOUBLE=PCR2=1),
  // ICA[7:3]=1 & ICA[0]=1, CSMREQ=1, PEX=1 (g19), SEGZN=0 (g20).
  localparam [18:0] V_SN0 = {1'b1, 1'b1, 1'b1, 8'hF9, 3'b100,
                             1'b1, 1'b1, 1'b0, 1'b1, 1'b0};
  localparam [18:0] V_SN1 = V_SN0 & ~(19'b1 << 18);  // CSMREQ=0 -> shadow_n=1

  wire [10:0] bundle = {A10, A1617, A1619, A1819, B1819, B1821,
                        BB10, C10, D1617, E1617, F1617};

  CGA_MAC_LASEL dut (
      .sysclk  (sysclk),
      .MCLK_EN (MCLK_EN),
      .CSMREQ  (CSMREQ),
      .DOUBLE  (DOUBLE),
      .EXMN    (EXMN),
      .ICA_15_8(ICA),
      .MCLK    (MCLK),
      .PCR_2_0 (PCR),
      .PEX     (PEX),
      .PONI    (PONI),
      .SEGZN   (SEGZN),
      .SELPTN  (SELPTN),
      .VEX     (VEX),
      .A10     (A10),
      .A1617   (A1617),
      .A1619   (A1619),
      .A1819   (A1819),
      .B1819   (B1819),
      .B1821   (B1821),
      .BB10    (BB10),
      .C10     (C10),
      .D1617   (D1617),
      .E1617   (E1617),
      .F1617   (F1617),
      .LSHADOW (LSHADOW)
  );

  always #5 sysclk = ~sysclk;

  task apply(input [18:0] v);
    begin
      CSMREQ = v[18];
      DOUBLE = v[17];
      EXMN   = v[16];
      ICA    = v[15:8];
      PCR    = v[7:5];
      PEX    = v[4];
      PONI   = v[3];
      SEGZN  = v[2];
      SELPTN = v[1];
      VEX    = v[0];
    end
  endtask

  // One MCLK event, valid in BOTH build modes: the EN-mode FF captures at
  // posedge sysclk while MCLK_EN=1; the plain FF captures at the posedge
  // of MCLK raised just after the same sysclk edge (inputs stable).
  task pulse_mclk;
    begin
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 1;
      @(negedge sysclk);
      MCLK    = 0;
      MCLK_EN = 0;
      #1;
    end
  endtask

  // Compact model, proven equal to the literal per-gate netlist model for
  // all 2^19 inputs by the Python generator (see header).
  function [11:0] golden(input [18:0] v);  // [11]=shadow_n, [10:0]=bundle
    reg csmreq, double_i, exmn, pex, poni, segzn, selptn, vex;
    reg [7:0] ica;
    reg [2:0] pcr;
    reg rexn, ex, g18, g19, g20, g21, sn, sh, g23n, selpt;
    reg a10, a1617, a1619, a1819, b1819, b1821, bb10, c10;
    reg d1617, e1617, f1617;
    begin
      csmreq = v[18]; double_i = v[17]; exmn = v[16];
      ica = v[15:8]; pcr = v[7:5];
      pex = v[4]; poni = v[3]; segzn = v[2]; selptn = v[1]; vex = v[0];

      rexn = ~(~double_i & ~pcr[2]);
      ex   = pcr[2] & double_i;
      g18  = (rexn | ica[0]) & (ica[7] & ica[6] & ica[5] & ica[4] & ica[3]);
      g19  = (pcr[1] & pcr[0]) | ~poni | pex;
      g20  = ~pex | ~segzn;
      g21  = ex | (ica[2] & ica[1]);
      sn   = ~(g21 & g18 & csmreq & g19 & g20);
      sh   = ~sn;
      g23n = exmn & csmreq & poni;
      selpt = ~selptn;

      a10   = sh & ~rexn;
      a1617 = sn & pex;
      a1619 = sn & g23n & selpt & ex;
      a1819 = sh & ex;
      b1819 = sn & selptn & g23n & ex;
      b1821 = sn & ~exmn;
      bb10  = sh & rexn;
      c10   = sn;
      d1617 = sn & ~ex & selpt & g23n;
      e1617 = sn & g23n & selptn;
      f1617 = sn & vex;
      golden = {sn, a10, a1617, a1619, a1819, b1819, b1821,
                bb10, c10, d1617, e1617, f1617};
    end
  endfunction

  task check_bundle(input [10:0] exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (bundle !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: bundle=%011b expected %011b (i=%0d)",
                 name, bundle, exp, i);
      end
    end
  endtask

  task check_lshadow(input exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (LSHADOW !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: LSHADOW=%b expected %b", name, LSHADOW, exp);
      end
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_MAC_LASEL_tb: FPGA_FF_MODE (sysclk+MCLK_EN capture)");
`else
    $display("CGA_MAC_LASEL_tb: plain build (posedge-MCLK FF)");
`endif

    // ------------------------------------------------------------------
    // 1. Power-up LSHADOW: 1 check.
    // ------------------------------------------------------------------
    #1;
    check_lshadow(1'b1, "power-up LSHADOW");

    // ------------------------------------------------------------------
    // 2+3. Exhaustive comb sweep + checksum: 524288 + 1 checks.
    // ------------------------------------------------------------------
    chk = 32'd0;
    for (i = 0; i < 524288; i = i + 1) begin
      apply(i[18:0]);
      #2;
      exp_g = golden(i[18:0]);
      check_bundle(exp_g[10:0], "exhaustive sweep");
      chk = chk * 33 + {21'b0, bundle};
    end
    checks = checks + 1;
    if (chk !== SWEEP_CHECKSUM) begin
      errors = errors + 1;
      $display("FAIL sweep checksum: got %08x expected %08x",
               chk, SWEEP_CHECKSUM);
    end

    // ------------------------------------------------------------------
    // 4. LSHADOW capture + hold: 16 pulses x 2 = 32 checks.
    // ------------------------------------------------------------------
    for (i = 0; i < 16; i = i + 1) begin
      apply((i[0] == 1'b0) ? V_SN0 : V_SN1);
      #2;
      exp_g  = golden((i[0] == 1'b0) ? V_SN0 : V_SN1);
      exp_ls = ~exp_g[11];  // ~shadow_n (generator-verified: 1 then 0)
      pulse_mclk;
      check_lshadow(exp_ls, "LSHADOW capture");
      apply((i[0] == 1'b0) ? V_SN1 : V_SN0);  // flip inputs, no pulse
      #22;
      check_lshadow(exp_ls, "LSHADOW hold");
    end

    // ------------------------------------------------------------------
    // Verdict. Expected: 1 + 524288 + 1 + 32 = 524322.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)",
               errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule
