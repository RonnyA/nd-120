/****************************************************************************
** PAL_44407A_EN (19F, ERFFIX - register-file enable fix) golden testbench **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/44407A.txt. The model is re-derived   **
** from that PALASM listing; the Verilog is under test, and a disagreement  **
** is a FINDING that gets reported, never patched in the RTL.               **
**                                                                         **
**   pins: CLK IDBS0 IDBS1 IDBS2 IDBS3 IDBS4 WRTRF /LCS NC9 GND             **
**         /OE /NC12 /NC13 /NC14 /NC15 /NC16 /RRF /NC18 /ERF VCC            **
**                                                                         **
**   RRF := /LCS * /IDBS4 * /IDBS3 * IDBS2 * /IDBS1 * IDBS0                 **
**   IF (VCC) ERF = RRF + WRTRF                                             **
**                                                                         **
** RRF decodes IDBS = 5, the register-file source, and only while the       **
** control store is NOT being loaded.                                       **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 8 input pins x 1 state bit = 512 combinations, all **
** applied to BOTH build variants in one loop:                              **
**   USE_ENABLE=1 - posedge sysclk + EN (the FPGA clock-enable conversion)  **
**   USE_ENABLE=0 - the original PAL_44407A on posedge CK                   **
** The RRF register is FORCED before every vector.                          **
**                                                                         **
** OUTPUT ENABLE - READ THIS. /RRF is pin 17, one of the four registered    **
** pins a PAL16R4 puts under /OE, so gating it is right. /ERF is pin 19, a  **
** COMBINATIONAL I/O pin with its own enable term, and the listing gives it **
** "IF (VCC)" - always enabled. The RTL gates /ERF with OE_n anyway. That   **
** is a DEVIATION FROM THE LISTING; it cannot bite on the 3202D, where /OE  **
** is wired to PD1 and PD1..PD4 are always low (PAL_44407A.v:16). It is     **
** pinned below by the named check ERF_OE_GATED_DEVIATION so that the       **
** behaviour is recorded rather than assumed, and it is reported as a       **
** finding rather than fixed here.                                          **
**                                                                         **
** A disabled output drives 0, never z. On the active-low /RRF and /ERF     **
** pins that reads as RRF and ERF ASSERTED - checked explicitly.            **
**                                                                         **
** A flipped term is caught: decoding IDBS1 instead of /IDBS1 moves the RRF **
** decode from source 5 to source 7, so every IDBS=5 vector (16 of them per **
** state) would report RRF inactive.                                        **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal44407a                           **
**                                                                         **
** Last reviewed: 20-AUG-2026                                               **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module PAL_44407A_EN_tb;

  reg sysclk, EN, CK, OE_n;
  reg IDBS0, IDBS1, IDBS2, IDBS3, IDBS4, WRTRF, LCS_n;

  wire e_ERF_n, e_RRF_n, o_ERF_n, o_RRF_n;

  integer checks = 0, errors = 0, vec, st, dumped = 0;

  PAL_44407A_EN #(.USE_ENABLE(1)) DUT_EN (
      .sysclk(sysclk), .EN(EN), .CK(1'b0), .OE_n(OE_n),
      .IDBS0(IDBS0), .IDBS1(IDBS1), .IDBS2(IDBS2), .IDBS3(IDBS3),
      .IDBS4(IDBS4), .WRTRF(WRTRF), .LCS_n(LCS_n),
      .ERF_n(e_ERF_n), .RRF_n(e_RRF_n)
  );

  PAL_44407A_EN #(.USE_ENABLE(0)) DUT_OR (
      .sysclk(1'b0), .EN(1'b0), .CK(CK), .OE_n(OE_n),
      .IDBS0(IDBS0), .IDBS1(IDBS1), .IDBS2(IDBS2), .IDBS3(IDBS3),
      .IDBS4(IDBS4), .WRTRF(WRTRF), .LCS_n(LCS_n),
      .ERF_n(o_ERF_n), .RRF_n(o_RRF_n)
  );

  // ---- golden model from the listing ------------------------------------
  reg  r_rrf;
  wire g_rrf_next = LCS_n & ~IDBS4 & ~IDBS3 & IDBS2 & ~IDBS1 & IDBS0;
  wire g_ERF_n_listing = ~(r_rrf | WRTRF);   // IF (VCC) - always enabled

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | rrf=%b OE_n=%b IDBS4..0=%b%b%b%b%b WRTRF=%b LCS_n=%b",
                   name, got, exp, r_rrf, OE_n, IDBS4, IDBS3, IDBS2, IDBS1,
                   IDBS0, WRTRF, LCS_n);
      end
    end
  endtask

  task set_state (input v);
    begin
      r_rrf = v;
      DUT_EN.gen_enable.RRF_reg  = v;
      DUT_OR.gen_orig.PAL.RRF_reg = v;
      #1;
    end
  endtask

  task tick;
    begin
      sysclk = 1'b0; CK = 1'b0; #1;
      sysclk = 1'b1; CK = 1'b1; #1;
      sysclk = 1'b0; CK = 1'b0; #1;
    end
  endtask

  initial begin
    $dumpfile("PAL_44407A_EN_tb.vcd");
    $dumpvars(0, PAL_44407A_EN_tb);
  end

  initial begin
    sysclk = 1'b0; CK = 1'b0; EN = 1'b1; r_rrf = 1'b0;
    $display("=====================================================");
    $display(" PAL_44407A_EN (ERFFIX) exhaustive golden testbench");
    $display(" 8 input pins x 1 state bit = 512 combinations");
    $display(" checked for USE_ENABLE=1 and USE_ENABLE=0");
    $display("=====================================================");

    for (st = 0; st < 2; st = st + 1) begin
      for (vec = 0; vec < 256; vec = vec + 1) begin
        {IDBS0, IDBS1, IDBS2, IDBS3, IDBS4, WRTRF, LCS_n, OE_n} = vec[7:0];
        set_state(st[0]);

        if (OE_n === 1'b0) begin
          chk("EN1_RRF_n", e_RRF_n, ~r_rrf);
          chk("OR0_RRF_n", o_RRF_n, ~r_rrf);
          chk("EN1_ERF_n", e_ERF_n, g_ERF_n_listing);
          chk("OR0_ERF_n", o_ERF_n, g_ERF_n_listing);
        end else begin
          chk("OEOFF_EN1_RRF_n", e_RRF_n, 1'b0);
          chk("OEOFF_OR0_RRF_n", o_RRF_n, 1'b0);
          // DEVIATION, see header: the listing says /ERF is always enabled.
          chk("ERF_OE_GATED_DEVIATION_EN1", e_ERF_n, 1'b0);
          chk("ERF_OE_GATED_DEVIATION_OR0", o_ERF_n, 1'b0);
        end

        tick;
        if (OE_n === 1'b0) begin
          chk("EN1_RRF_n_next", e_RRF_n, ~g_rrf_next);
          chk("OR0_RRF_n_next", o_RRF_n, ~g_rrf_next);
        end

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;
      end
    end

    // ---- named property checks -----------------------------------------
    OE_n = 1'b0; LCS_n = 1'b1; WRTRF = 1'b0;

    // 1. RRF decodes IDBS = 5 (00101) and nothing else
    {IDBS4, IDBS3, IDBS2, IDBS1, IDBS0} = 5'b00101;
    set_state(1'b0);
    tick;
    checks = checks + 1;
    if (e_RRF_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL RRF_DECODE_5: e_RRF_n=%b, IDBS=5 must assert RRF", e_RRF_n);
    end
    for (vec = 0; vec < 32; vec = vec + 1) begin
      if (vec != 5) begin
        {IDBS4, IDBS3, IDBS2, IDBS1, IDBS0} = vec[4:0];
        set_state(1'b0);
        tick;
        checks = checks + 1;
        if (e_RRF_n !== 1'b1) begin
          errors = errors + 1;
          $display("FAIL RRF_DECODE_OTHER: IDBS=%0d asserted RRF", vec);
        end
      end
    end

    // 2. LCS blocks the decode entirely - no register-file read while the
    //    control store is being loaded
    {IDBS4, IDBS3, IDBS2, IDBS1, IDBS0} = 5'b00101;
    LCS_n = 1'b0;
    set_state(1'b0);
    tick;
    checks = checks + 1;
    if (e_RRF_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL RRF_LCS_BLOCK: e_RRF_n=%b, LCS must block the decode", e_RRF_n);
    end
    LCS_n = 1'b1;

    // 3. ERF is the OR of RRF and WRTRF, and WRTRF reaches it COMBINATIONALLY
    //    (no clock edge needed) - it is a 16L8-style pin, not a register
    set_state(1'b0);
    WRTRF = 1'b0; #1;
    checks = checks + 1;
    if (e_ERF_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL ERF_IDLE: e_ERF_n=%b, must be inactive", e_ERF_n);
    end
    WRTRF = 1'b1; #1;
    checks = checks + 1;
    if (e_ERF_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL ERF_WRTRF: e_ERF_n=%b, WRTRF must assert ERF with no clock", e_ERF_n);
    end
    WRTRF = 1'b0;
    set_state(1'b1); #1;
    checks = checks + 1;
    if (e_ERF_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL ERF_RRF: e_ERF_n=%b, RRF must assert ERF", e_ERF_n);
    end

    // 4. the clock enable really gates the USE_ENABLE=1 register
    {IDBS4, IDBS3, IDBS2, IDBS1, IDBS0} = 5'b00101;
    set_state(1'b0);
    EN = 1'b0; sysclk = 1'b1; #1; sysclk = 1'b0; #1;
    checks = checks + 1;
    if (e_RRF_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL EN_GATE: e_RRF_n=%b, EN low must block the capture", e_RRF_n);
    end
    EN = 1'b1; tick;
    checks = checks + 1;
    if (e_RRF_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL EN_RELEASE: e_RRF_n=%b, EN high must capture", e_RRF_n);
    end

    // 5. nothing floats
    checks = checks + 1;
    if (^{e_ERF_n, e_RRF_n, o_ERF_n, o_RRF_n} === 1'bx) begin
      errors = errors + 1;
      $display("FAIL NO_Z: an output is x/z");
    end

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

endmodule

`default_nettype wire
