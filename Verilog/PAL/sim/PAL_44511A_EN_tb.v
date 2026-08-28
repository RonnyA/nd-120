/****************************************************************************
** PAL_44511A_EN (26H, LEV0 - level zero / cache write + update) golden tb **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/44511A.txt. The model is re-derived   **
** from that PALASM listing; the Verilog is under test. Two DEVIATIONS from **
** the listing are recorded below - they are reported as findings, not      **
** patched here.                                                            **
**                                                                         **
**   pins: CLK PIL0 PIL1 PIL2 PIL3 CLK /MREQ /WCA NC9 GND                   **
**         /OE LEV0 /NC13 /NC14 /NC15 /NC16 CUP /NC18 /CWR VCC              **
**                                                                         **
**   IF (VCC) /LEV0 = PIL3 + PIL2 + PIL1 + PIL0                             **
**   IF (VCC) CWR   = MREQ * WCA      ; SET ON WRITE TO CACHE               **
**                  + CWR * /CLK      ; HOLD UNTIL START OF NEXT CYCLE      **
**   /CUP := /CWR * MREQ + /CUP * /MREQ                                     **
**                                                                         **
** DEVIATION 1 - CWR IS COMBINATIONAL IN THE LISTING. /CWR is pin 19, a     **
** 16R4 combinational I/O pin carrying "IF (VCC)", and its equation is a    **
** feedback latch (CWR * /CLK). The RTL evaluates it inside the clocked     **
** always block instead, so CWR only moves on a clock edge. The algebra is  **
** the same - CWR' = MREQ * WCA + CWR * /CLK - so the values agree at every **
** edge, but a mid-cycle MREQ * WCA does not reach the pin. Pinned below by **
** CWR_IS_CLOCKED_NOT_COMBINATIONAL_DEVIATION.                              **
**                                                                         **
** DEVIATION 2 - /CWR IS OE-GATED IN THE RTL. On a PAL16R4 only pins 14-17  **
** sit under /OE; pin 19 has its own enable term and the listing gives it   **
** "IF (VCC)" - always enabled. The RTL drives it to 0 when OE_n is high,   **
** which also feeds a false /CWR = 0 into the /CUP equation. Unreachable on **
** the 3202D, where /OE is PD1 and PD1..PD4 are always low                  **
** (PAL_44511A.v:22). Pinned below by CWR_OE_GATED_DEVIATION.               **
** CUP is pin 17, genuinely registered and genuinely /OE controlled; LEV0   **
** is pin 12, always enabled - the RTL matches for both.                    **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 8 input pins x 2 state bits = 1024 combinations,   **
** all applied to BOTH build variants in one loop:                          **
**   USE_ENABLE=1 - posedge sysclk + EN (the FPGA clock-enable conversion)  **
**   USE_ENABLE=0 - the original PAL_44511A on posedge CK                   **
** Both registers are FORCED before every vector. CLK appears twice in the  **
** pin list (pin 1 and pin 5); here CK is the clock and the CLK PORT is     **
** swept as the data input it is in the CWR hold term.                      **
**                                                                         **
** A disabled output drives 0, never z - checked explicitly.                **
**                                                                         **
** A flipped term is caught: the 26-JUL fix in this file swapped MREQ for   **
** MREQ_n in the /CUP set term. With that polarity back, CUP would differ   **
** on every vector where MREQ is asserted and /CWR is 1 - a quarter of the  **
** sweep.                                                                   **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal44511a                           **
**                                                                         **
** Last reviewed: 20-AUG-2026                                               **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module PAL_44511A_EN_tb;

  reg sysclk, EN, CK, OE_n;
  reg PIL0, PIL1, PIL2, PIL3, CLK, MREQ_n, WCA_n;

  wire e_CUP, e_CWR_n, e_LEV0;
  wire o_CUP, o_CWR_n, o_LEV0;

  integer checks = 0, errors = 0, vec, st, dumped = 0;

  PAL_44511A_EN #(.USE_ENABLE(1)) DUT_EN (
      .sysclk(sysclk), .EN(EN), .CK(1'b0), .OE_n(OE_n),
      .PIL0(PIL0), .PIL1(PIL1), .PIL2(PIL2), .PIL3(PIL3),
      .CLK(CLK), .MREQ_n(MREQ_n), .WCA_n(WCA_n),
      .CUP(e_CUP), .CWR_n(e_CWR_n), .LEV0(e_LEV0)
  );

  PAL_44511A_EN #(.USE_ENABLE(0)) DUT_OR (
      .sysclk(1'b0), .EN(1'b0), .CK(CK), .OE_n(OE_n),
      .PIL0(PIL0), .PIL1(PIL1), .PIL2(PIL2), .PIL3(PIL3),
      .CLK(CLK), .MREQ_n(MREQ_n), .WCA_n(WCA_n),
      .CUP(o_CUP), .CWR_n(o_CWR_n), .LEV0(o_LEV0)
  );

  // ---- golden model from the listing ------------------------------------
  wire g_MREQ = ~MREQ_n, g_WCA = ~WCA_n;

  reg  r_cwr;      // the CWR function
  reg  r_cup_n;    // /CUP

  wire g_LEV0 = ~(PIL3 | PIL2 | PIL1 | PIL0);

  // the /CWR pin as this RTL drives it - see DEVIATION 2 in the header
  wire g_CWR_pin_n = OE_n ? 1'b0 : ~r_cwr;

  wire g_cwr_next   = (g_MREQ & g_WCA) | (r_cwr & ~CLK);
  wire g_cup_n_next = (g_CWR_pin_n & g_MREQ) | (r_cup_n & MREQ_n);

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | cwr=%b cup_n=%b OE_n=%b PIL3..0=%b%b%b%b CLK=%b MREQ_n=%b WCA_n=%b",
                   name, got, exp, r_cwr, r_cup_n, OE_n, PIL3, PIL2, PIL1,
                   PIL0, CLK, MREQ_n, WCA_n);
      end
    end
  endtask

  task set_state (input w, input u);
    begin
      r_cwr = w; r_cup_n = u;
      DUT_EN.gen_enable.CWR_hold   = w;
      DUT_EN.gen_enable.CUP_n_reg = u;
      DUT_OR.gen_orig.PAL.CWR_hold   = w;
      DUT_OR.gen_orig.PAL.CUP_n_reg = u;
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
    $dumpfile("PAL_44511A_EN_tb.vcd");
    $dumpvars(0, PAL_44511A_EN_tb);
  end

  initial begin
    sysclk = 1'b0; CK = 1'b0; EN = 1'b1; r_cwr = 0; r_cup_n = 0;
    $display("=====================================================");
    $display(" PAL_44511A_EN (LEV0) exhaustive golden testbench");
    $display(" 8 input pins x 2 state bits = 1024 combinations");
    $display(" checked for USE_ENABLE=1 and USE_ENABLE=0");
    $display("=====================================================");

    for (st = 0; st < 4; st = st + 1) begin
      for (vec = 0; vec < 256; vec = vec + 1) begin
        {PIL0, PIL1, PIL2, PIL3, CLK, MREQ_n, WCA_n, OE_n} = vec[7:0];
        set_state(st[0], st[1]);

        // LEV0 is pin 12 - always enabled, never OE gated
        chk("EN1_LEV0", e_LEV0, g_LEV0);
        chk("OR0_LEV0", o_LEV0, g_LEV0);

        // /CWR: the RTL gates it - see DEVIATION 2
        chk("CWR_OE_GATED_DEVIATION_EN1", e_CWR_n, g_CWR_pin_n);
        chk("CWR_OE_GATED_DEVIATION_OR0", o_CWR_n, g_CWR_pin_n);

        if (OE_n === 1'b0) begin
          chk("EN1_CUP", e_CUP, ~r_cup_n);
          chk("OR0_CUP", o_CUP, ~r_cup_n);
        end else begin
          chk("OEOFF_EN1_CUP", e_CUP, 1'b0);
          chk("OEOFF_OR0_CUP", o_CUP, 1'b0);
        end

        tick;
        chk("EN1_CWR_n_next", e_CWR_n, OE_n ? 1'b0 : ~g_cwr_next);
        chk("OR0_CWR_n_next", o_CWR_n, OE_n ? 1'b0 : ~g_cwr_next);
        if (OE_n === 1'b0) begin
          chk("EN1_CUP_next", e_CUP, ~g_cup_n_next);
          chk("OR0_CUP_next", o_CUP, ~g_cup_n_next);
        end

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;
      end
    end

    // ---- named property checks -----------------------------------------
    OE_n = 1'b0;

    // 1. LEV0 asserts only when EVERY PIL bit is zero
    for (vec = 0; vec < 16; vec = vec + 1) begin
      {PIL3, PIL2, PIL1, PIL0} = vec[3:0]; #1;
      checks = checks + 1;
      if ((e_LEV0 === 1'b1) !== (vec == 0)) begin
        errors = errors + 1;
        $display("FAIL LEV0_DECODE: PIL=%0d LEV0=%b", vec, e_LEV0);
      end
    end
    {PIL3, PIL2, PIL1, PIL0} = 4'b0000;

    // 2. DEVIATION 1: the listing's CWR is combinational, so MREQ * WCA
    //    would reach the pin with no clock edge. This RTL needs the edge.
    MREQ_n = 1'b0; WCA_n = 1'b0; CLK = 1'b0;
    set_state(1'b0, 1'b1);
    checks = checks + 1;
    if (e_CWR_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL CWR_IS_CLOCKED_NOT_COMBINATIONAL_DEVIATION: e_CWR_n=%b, expected the RTL's clocked behaviour", e_CWR_n);
    end
    tick;
    checks = checks + 1;
    if (e_CWR_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL CWR_SET: e_CWR_n=%b, MREQ * WCA must set CWR at the edge", e_CWR_n);
    end

    // 3. CWR needs BOTH MREQ and WCA
    MREQ_n = 1'b0; WCA_n = 1'b1; CLK = 1'b1;
    set_state(1'b0, 1'b1);
    tick;
    checks = checks + 1;
    if (e_CWR_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL CWR_NEEDS_WCA: e_CWR_n=%b, MREQ alone must not set CWR", e_CWR_n);
    end
    MREQ_n = 1'b1; WCA_n = 1'b0;
    set_state(1'b0, 1'b1);
    tick;
    checks = checks + 1;
    if (e_CWR_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL CWR_NEEDS_MREQ: e_CWR_n=%b, WCA alone must not set CWR", e_CWR_n);
    end

    // 4. the CWR hold term is /CLK: CLK low holds, CLK high releases
    MREQ_n = 1'b1; WCA_n = 1'b1; CLK = 1'b0;
    set_state(1'b1, 1'b1);
    tick;
    checks = checks + 1;
    if (e_CWR_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL CWR_HOLD: e_CWR_n=%b, /CLK must hold CWR", e_CWR_n);
    end
    CLK = 1'b1;
    set_state(1'b1, 1'b1);
    tick;
    checks = checks + 1;
    if (e_CWR_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL CWR_RELEASE: e_CWR_n=%b, CLK high must release CWR", e_CWR_n);
    end

    // 5. THE 26-JUL POLARITY FIX: /CUP's set term is /CWR * MREQ, so with
    //    CWR asserted (pin /CWR = 0) and MREQ asserted, /CUP goes to 0 and
    //    the CUP pin goes ACTIVE. The old flipped polarity did the reverse.
    MREQ_n = 1'b0; CLK = 1'b0;
    set_state(1'b1, 1'b1);        // CWR set, /CUP = 1 (CUP inactive)
    tick;
    checks = checks + 1;
    if (e_CUP !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL CUP_SET_ON_CACHE_WRITE: e_CUP=%b, must go active", e_CUP);
    end
    //    and it holds while MREQ is away
    MREQ_n = 1'b1;
    set_state(1'b1, 1'b0);
    tick;
    checks = checks + 1;
    if (e_CUP !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL CUP_HOLD: e_CUP=%b, /MREQ must hold CUP", e_CUP);
    end
    //    a new MREQ with CWR clear drops it again
    MREQ_n = 1'b0;
    set_state(1'b0, 1'b0);
    tick;
    checks = checks + 1;
    if (e_CUP !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL CUP_CLEAR: e_CUP=%b, MREQ without CWR must clear CUP", e_CUP);
    end

    // 6. the clock enable really gates the USE_ENABLE=1 registers
    MREQ_n = 1'b0; WCA_n = 1'b0; CLK = 1'b0;
    set_state(1'b0, 1'b1);
    EN = 1'b0; sysclk = 1'b1; #1; sysclk = 1'b0; #1;
    checks = checks + 1;
    if (e_CWR_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL EN_GATE: e_CWR_n=%b, EN low must block the capture", e_CWR_n);
    end
    EN = 1'b1; tick;
    checks = checks + 1;
    if (e_CWR_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL EN_RELEASE: e_CWR_n=%b, EN high must capture", e_CWR_n);
    end

    // 7. nothing floats
    checks = checks + 1;
    if (^{e_CUP, e_CWR_n, e_LEV0} === 1'bx) begin
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
