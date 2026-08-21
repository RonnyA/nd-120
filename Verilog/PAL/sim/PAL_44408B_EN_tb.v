/****************************************************************************
** PAL_44408B_EN (22F, VEXFIX - virtual examine fix) golden testbench      **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/44408B.txt. The model is re-derived   **
** from that PALASM listing term by term; the Verilog is under test, and a  **
** disagreement is a FINDING to report, not a reason to edit the RTL.       **
**                                                                         **
**   pins: CLK C4 C3 C2 C1 C0 M1 M0 /LCS GND                                **
**         /OE IDB2 NC13 /RWCS OPCLCS VEX /LDEXM NC18 NC19 VCC              **
**                                                                         **
**   LDEXM   := C4 * /C3 * /C2 * /C1 * C0 * M1 * M0 * /LCS   ; command 21.3 **
**   /VEX    := LDEXM * /IDB2        ; CLEAR                                **
**            + /LDEXM * /VEX        ; HOLD CLEAR                           **
**            + LCS                                                        **
**   /OPCLCS := /C4 + /C3 + /C2 + /C1 + C0 + /M1 + M0 + LCS  ; command 36.2 **
**   RWCS    := C4 * C3 * C2 * C1 * /C0 * /M1 * M0 * /LCS    ; command 36.1 **
**                                                                         **
** The three command decodes are the golden spec for CSCOMM.CSMIS values    **
** 21.3, 36.2 and 36.1, so this testbench checks every one of the 128       **
** command codes, not only the three that should hit.                       **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 10 input pins x 4 state bits = 16384 combinations, **
** all applied to BOTH build variants in one loop:                          **
**   USE_ENABLE=1 - posedge sysclk + EN (the FPGA clock-enable conversion)  **
**   USE_ENABLE=0 - the original PAL_44408B on posedge CK                   **
** All four registers are FORCED before every vector, so the /VEX hold term **
** is exercised from both states rather than only from the reachable one.   **
**                                                                         **
** OUTPUT ENABLE: /RWCS, OPCLCS, VEX and /LDEXM are pins 14-17, the four    **
** registered pins a PAL16R4 puts under /OE, so gating all four is right.   **
** A disabled output drives 0, never z - checked explicitly. Note what that **
** means per pin: /RWCS and /LDEXM read ASSERTED, OPCLCS and VEX read       **
** INACTIVE, because the pins have opposite polarity.                       **
**                                                                         **
** RT_n IS NOT IN THIS LISTING. The port exists because the related PAL     **
** 444608 (VXFIX, a 16R6) has it; the RTL ties it to 1. It is checked AS    **
** IMPLEMENTED under a name that says so, so a change is noticed - passing  **
** is not evidence the tie-off is correct.                                  **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal44408b                           **
**                                                                         **
** Last reviewed: 20-AUG-2026                                               **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module PAL_44408B_EN_tb;

  reg sysclk, EN, CK, OE_n;
  reg C4, C3, C2, C1, C0, M1, M0, LCS_n, IDB2;

  wire e_LDEXM_n, e_VEX, e_OPCLCS, e_RWCS_n, e_RT_n;
  wire o_LDEXM_n, o_VEX, o_OPCLCS, o_RWCS_n, o_RT_n;

  integer checks = 0, errors = 0, vec, st, dumped = 0, cmd;

  PAL_44408B_EN #(.USE_ENABLE(1)) DUT_EN (
      .sysclk(sysclk), .EN(EN), .CK(1'b0), .OE_n(OE_n),
      .C4(C4), .C3(C3), .C2(C2), .C1(C1), .C0(C0), .M1(M1), .M0(M0),
      .LCS_n(LCS_n), .IDB2(IDB2),
      .LDEXM_n(e_LDEXM_n), .VEX(e_VEX), .OPCLCS(e_OPCLCS),
      .RWCS_n(e_RWCS_n), .RT_n(e_RT_n)
  );

  PAL_44408B_EN #(.USE_ENABLE(0)) DUT_OR (
      .sysclk(1'b0), .EN(1'b0), .CK(CK), .OE_n(OE_n),
      .C4(C4), .C3(C3), .C2(C2), .C1(C1), .C0(C0), .M1(M1), .M0(M0),
      .LCS_n(LCS_n), .IDB2(IDB2),
      .LDEXM_n(o_LDEXM_n), .VEX(o_VEX), .OPCLCS(o_OPCLCS),
      .RWCS_n(o_RWCS_n), .RT_n(o_RT_n)
  );

  // ---- golden model from the listing ------------------------------------
  wire g_LCS = ~LCS_n;

  reg  r_ldexm;      // LDEXM function
  reg  r_vex_n;      // /VEX
  reg  r_opclcs_n;   // /OPCLCS
  reg  r_rwcs;       // RWCS

  wire g_ldexm_next    = C4 & ~C3 & ~C2 & ~C1 & C0 & M1 & M0 & LCS_n;
  wire g_vex_n_next    = (r_ldexm & ~IDB2) | (~r_ldexm & r_vex_n) | g_LCS;
  wire g_opclcs_n_next = ~C4 | ~C3 | ~C2 | ~C1 | C0 | ~M1 | M0 | g_LCS;
  wire g_rwcs_next     = C4 & C3 & C2 & C1 & ~C0 & ~M1 & M0 & LCS_n;

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | ldexm=%b vex_n=%b opclcs_n=%b rwcs=%b OE_n=%b C4..C0=%b%b%b%b%b M1=%b M0=%b LCS_n=%b IDB2=%b",
                   name, got, exp, r_ldexm, r_vex_n, r_opclcs_n, r_rwcs, OE_n,
                   C4, C3, C2, C1, C0, M1, M0, LCS_n, IDB2);
      end
    end
  endtask

  task set_state (input l, input v, input o, input r);
    begin
      r_ldexm = l; r_vex_n = v; r_opclcs_n = o; r_rwcs = r;
      DUT_EN.gen_enable.LDEXM_int    = l;
      DUT_EN.gen_enable.VEX_n_int    = v;
      DUT_EN.gen_enable.OPCLCS_n_int = o;
      DUT_EN.gen_enable.RWCS_int     = r;
      DUT_OR.gen_orig.PAL.LDEXM_int    = l;
      DUT_OR.gen_orig.PAL.VEX_n_int    = v;
      DUT_OR.gen_orig.PAL.OPCLCS_n_int = o;
      DUT_OR.gen_orig.PAL.RWCS_int     = r;
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
    $dumpfile("PAL_44408B_EN_tb.vcd");
    $dumpvars(0, PAL_44408B_EN_tb);
  end

  initial begin
    sysclk = 1'b0; CK = 1'b0; EN = 1'b1;
    r_ldexm = 0; r_vex_n = 0; r_opclcs_n = 0; r_rwcs = 0;
    $display("=====================================================");
    $display(" PAL_44408B_EN (VEXFIX) exhaustive golden testbench");
    $display(" 10 input pins x 4 state bits = 16384 combinations");
    $display(" checked for USE_ENABLE=1 and USE_ENABLE=0");
    $display("=====================================================");

    for (st = 0; st < 16; st = st + 1) begin
      for (vec = 0; vec < 1024; vec = vec + 1) begin
        {C4, C3, C2, C1, C0, M1, M0, LCS_n, IDB2, OE_n} = vec[9:0];
        set_state(st[0], st[1], st[2], st[3]);

        // RT_n is not in the listing - checked as implemented
        chk("RT_n_TIED_HIGH_NOT_IN_LISTING_EN1", e_RT_n, 1'b1);
        chk("RT_n_TIED_HIGH_NOT_IN_LISTING_OR0", o_RT_n, 1'b1);

        if (OE_n === 1'b0) begin
          chk("EN1_LDEXM_n", e_LDEXM_n, ~r_ldexm);
          chk("OR0_LDEXM_n", o_LDEXM_n, ~r_ldexm);
          chk("EN1_VEX",     e_VEX,     ~r_vex_n);
          chk("OR0_VEX",     o_VEX,     ~r_vex_n);
          chk("EN1_OPCLCS",  e_OPCLCS,  ~r_opclcs_n);
          chk("OR0_OPCLCS",  o_OPCLCS,  ~r_opclcs_n);
          chk("EN1_RWCS_n",  e_RWCS_n,  ~r_rwcs);
          chk("OR0_RWCS_n",  o_RWCS_n,  ~r_rwcs);
        end else begin
          chk("OEOFF_EN1_LDEXM_n", e_LDEXM_n, 1'b0);
          chk("OEOFF_OR0_LDEXM_n", o_LDEXM_n, 1'b0);
          chk("OEOFF_EN1_VEX",     e_VEX,     1'b0);
          chk("OEOFF_OR0_VEX",     o_VEX,     1'b0);
          chk("OEOFF_EN1_OPCLCS",  e_OPCLCS,  1'b0);
          chk("OEOFF_OR0_OPCLCS",  o_OPCLCS,  1'b0);
          chk("OEOFF_EN1_RWCS_n",  e_RWCS_n,  1'b0);
          chk("OEOFF_OR0_RWCS_n",  o_RWCS_n,  1'b0);
        end

        tick;
        if (OE_n === 1'b0) begin
          chk("EN1_LDEXM_n_next", e_LDEXM_n, ~g_ldexm_next);
          chk("OR0_LDEXM_n_next", o_LDEXM_n, ~g_ldexm_next);
          chk("EN1_VEX_next",     e_VEX,     ~g_vex_n_next);
          chk("OR0_VEX_next",     o_VEX,     ~g_vex_n_next);
          chk("EN1_OPCLCS_next",  e_OPCLCS,  ~g_opclcs_n_next);
          chk("OR0_OPCLCS_next",  o_OPCLCS,  ~g_opclcs_n_next);
          chk("EN1_RWCS_n_next",  e_RWCS_n,  ~g_rwcs_next);
          chk("OR0_RWCS_n_next",  o_RWCS_n,  ~g_rwcs_next);
        end

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;
      end
    end

    // ---- named property checks -----------------------------------------
    OE_n = 1'b0; LCS_n = 1'b1; IDB2 = 1'b0;

    // 1. exactly ONE of the 128 command codes may fire each decode
    for (cmd = 0; cmd < 128; cmd = cmd + 1) begin
      {C4, C3, C2, C1, C0, M1, M0} = cmd[6:0];
      set_state(1'b0, 1'b1, 1'b1, 1'b0);
      tick;
      checks = checks + 2;
      // command 21.3 -> C=10001 (21 octal = 10001 binary), M1 M0 = 1 1
      if ((e_LDEXM_n === 1'b0) !== (cmd == {5'b10001, 2'b11})) begin
        errors = errors + 1;
        $display("FAIL LDEXM_DECODE: cmd=%0d LDEXM_n=%b", cmd, e_LDEXM_n);
      end
      // command 36.1 -> C=11110, M1 M0 = 0 1
      if ((e_RWCS_n === 1'b0) !== (cmd == {5'b11110, 2'b01})) begin
        errors = errors + 1;
        $display("FAIL RWCS_DECODE: cmd=%0d RWCS_n=%b", cmd, e_RWCS_n);
      end
      // command 36.2 -> C=11110, M1 M0 = 1 0
      checks = checks + 1;
      if ((e_OPCLCS === 1'b1) !== (cmd == {5'b11110, 2'b10})) begin
        errors = errors + 1;
        $display("FAIL OPCLCS_DECODE: cmd=%0d OPCLCS=%b", cmd, e_OPCLCS);
      end
    end

    // 2. LCS blocks every decode
    {C4, C3, C2, C1, C0, M1, M0} = {5'b10001, 2'b11};
    LCS_n = 1'b0;
    set_state(1'b0, 1'b1, 1'b1, 1'b0);
    tick;
    checks = checks + 1;
    if (e_LDEXM_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL LDEXM_LCS: e_LDEXM_n=%b, LCS must block the decode", e_LDEXM_n);
    end
    LCS_n = 1'b1;

    // 3. the /VEX hold term: once /VEX is 1 it stays 1 while LDEXM is low,
    //    and only LDEXM * IDB2 pulls it down
    {C4, C3, C2, C1, C0, M1, M0} = 7'b0000000;   // no decode -> LDEXM low
    set_state(1'b0, 1'b1, 1'b1, 1'b0);           // LDEXM=0, /VEX=1
    tick;
    checks = checks + 1;
    if (e_VEX !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL VEX_HOLD_CLEAR: e_VEX=%b, /VEX must hold at 1", e_VEX);
    end
    set_state(1'b1, 1'b1, 1'b1, 1'b0);           // LDEXM=1, IDB2=0 -> /VEX=1
    IDB2 = 1'b0; #1;
    tick;
    checks = checks + 1;
    if (e_VEX !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL VEX_CLEAR_TERM: e_VEX=%b, LDEXM * /IDB2 must keep /VEX at 1", e_VEX);
    end
    set_state(1'b1, 1'b1, 1'b1, 1'b0);           // LDEXM=1, IDB2=1 -> /VEX=0
    IDB2 = 1'b1; #1;
    tick;
    checks = checks + 1;
    if (e_VEX !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL VEX_SET: e_VEX=%b, LDEXM * IDB2 must drive VEX active", e_VEX);
    end
    //    LCS forces /VEX back to 1 whatever else is going on
    LCS_n = 1'b0;
    set_state(1'b1, 1'b0, 1'b1, 1'b0);
    tick;
    checks = checks + 1;
    if (e_VEX !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL VEX_LCS: e_VEX=%b, LCS must force /VEX to 1", e_VEX);
    end
    LCS_n = 1'b1;

    // 4. the clock enable really gates the USE_ENABLE=1 registers
    {C4, C3, C2, C1, C0, M1, M0} = {5'b11110, 2'b01};
    set_state(1'b0, 1'b1, 1'b1, 1'b0);
    EN = 1'b0; sysclk = 1'b1; #1; sysclk = 1'b0; #1;
    checks = checks + 1;
    if (e_RWCS_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL EN_GATE: e_RWCS_n=%b, EN low must block the capture", e_RWCS_n);
    end
    EN = 1'b1; tick;
    checks = checks + 1;
    if (e_RWCS_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL EN_RELEASE: e_RWCS_n=%b, EN high must capture", e_RWCS_n);
    end

    // 5. nothing floats
    checks = checks + 1;
    if (^{e_LDEXM_n, e_VEX, e_OPCLCS, e_RWCS_n, e_RT_n} === 1'bx) begin
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
