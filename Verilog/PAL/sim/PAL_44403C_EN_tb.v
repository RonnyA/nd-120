/****************************************************************************
** PAL_44403C_EN (15D, CYIN0 - cycle control input generator) golden tb    **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/44403C.txt. The model below is        **
** re-derived from that PALASM listing term by term; the Verilog is under   **
** test. A disagreement is a FINDING, not a reason to edit the RTL.         **
**                                                                         **
**   IF (VCC) DLY0 = MDLY + CSDELAY0 + ACOND * CSECOND + ACOND * CSLOOP     **
**                 + LUA12 * /DMA12 + /LUA12 * DMA12 + DMAP                 **
**   LCS   := MR + /DMA12 * /LUA12 * LCS + DMA12 * LUA12 * LCS              **
**              + /DMA12 * LUA12 * LCS                                      **
**   MDLY  := CSDLY                                                         **
**   DMA12 := LUA12                                                         **
**   DMAP  := MAP                                                           **
**   IF (VCC) SLCOND = ACOND * CSECOND + ACOND * CSLOOP                     **
**                                                                         **
** The LUA12 / DMA12 pair in DLY0 is an EXCLUSIVE-OR - it fires only in the **
** one cycle where LUA12 differs from its registered copy. Transcribed as   **
** an XNOR it fires whenever LUA12 is stable, which is nearly always; that  **
** was the 30-JUL audit find in this file, and building the model straight  **
** from the listing re-checks the fix independently.                        **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 9 input pins x 4 state bits = 8192 combinations,   **
** all applied to BOTH build variants in one loop:                          **
**   USE_ENABLE=1 - posedge sysclk + EN (the FPGA clock-enable conversion)  **
**   USE_ENABLE=0 - the original PAL_44403C on posedge CLK                  **
** All four registers are FORCED before every vector, so the whole          **
** transition function is exercised, not just the reachable states.         **
**                                                                         **
** OUTPUT ENABLE: on a PAL16R4 only pins 14-17 are /OE controlled. Here     **
** those are /DMAP /DMA12 /MDLY /LCS. /SLCOND (pin 13) and /DLY0 (pin 19)   **
** carry "IF (VCC)" and are always enabled - the RTL matches. A disabled    **
** output drives 0, never z; on these ACTIVE-LOW pins that reads as the     **
** signal ASSERTED, which is checked explicitly.                            **
**                                                                         **
** DLY0 and SLCOND take their feedback from the REGISTERS, not from the     **
** OE-gated pins, so /OE does not disturb them - also checked.              **
**                                                                         **
** Do NOT compile with SKIP_WCS_LOAD: that define replaces the whole LCS    **
** equation with a constant 0 and the golden model here would fail.         **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal44403c                           **
**                                                                         **
** Last reviewed: 20-AUG-2026                                               **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

`ifdef SKIP_WCS_LOAD
`error "PAL_44403C_EN_tb must not be built with SKIP_WCS_LOAD"
`endif

module PAL_44403C_EN_tb;

  reg sysclk, EN, CLK, OE_n;
  reg CSDELAY0, CSDLY, CSECOND, CSLOOP, ACOND_n, MR_n, LUA12, MAP_n;

  wire e_LCS_n, e_MDLY_n, e_DMA12_n, e_DMAP_n, e_DLY0_n, e_SLCOND_n;
  wire o_LCS_n, o_MDLY_n, o_DMA12_n, o_DMAP_n, o_DLY0_n, o_SLCOND_n;

  integer checks = 0, errors = 0, vec, st, dumped = 0;

  PAL_44403C_EN #(.USE_ENABLE(1)) DUT_EN (
      .sysclk(sysclk), .EN(EN), .CLK(1'b0), .OE_n(OE_n),
      .CSDELAY0(CSDELAY0), .CSDLY(CSDLY), .CSECOND(CSECOND), .CSLOOP(CSLOOP),
      .ACOND_n(ACOND_n), .MR_n(MR_n), .LUA12(LUA12), .MAP_n(MAP_n),
      .LCS_n(e_LCS_n), .MDLY_n(e_MDLY_n), .DMA12_n(e_DMA12_n),
      .DMAP_n(e_DMAP_n), .DLY0_n(e_DLY0_n), .SLCOND_n(e_SLCOND_n)
  );

  PAL_44403C_EN #(.USE_ENABLE(0)) DUT_OR (
      .sysclk(1'b0), .EN(1'b0), .CLK(CLK), .OE_n(OE_n),
      .CSDELAY0(CSDELAY0), .CSDLY(CSDLY), .CSECOND(CSECOND), .CSLOOP(CSLOOP),
      .ACOND_n(ACOND_n), .MR_n(MR_n), .LUA12(LUA12), .MAP_n(MAP_n),
      .LCS_n(o_LCS_n), .MDLY_n(o_MDLY_n), .DMA12_n(o_DMA12_n),
      .DMAP_n(o_DMAP_n), .DLY0_n(o_DLY0_n), .SLCOND_n(o_SLCOND_n)
  );

  // ---- golden model from the listing ------------------------------------
  wire g_ACOND = ~ACOND_n, g_MR = ~MR_n, g_MAP = ~MAP_n;

  reg  r_lcs, r_mdly, r_dma12, r_dmap;

  wire g_lcs_next   = g_MR
                    | (~r_dma12 & ~LUA12 & r_lcs)
                    | ( r_dma12 &  LUA12 & r_lcs)
                    | (~r_dma12 &  LUA12 & r_lcs);
  wire g_mdly_next  = CSDLY;
  wire g_dma12_next = LUA12;
  wire g_dmap_next  = g_MAP;

  wire g_DLY0_n   = ~( r_mdly | CSDELAY0
                     | (g_ACOND & CSECOND) | (g_ACOND & CSLOOP)
                     | (LUA12 & ~r_dma12) | (~LUA12 & r_dma12)
                     | r_dmap );
  wire g_SLCOND_n = ~( (g_ACOND & CSECOND) | (g_ACOND & CSLOOP) );

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | lcs=%b mdly=%b dma12=%b dmap=%b OE_n=%b CSDELAY0=%b CSDLY=%b CSECOND=%b CSLOOP=%b ACOND_n=%b MR_n=%b LUA12=%b MAP_n=%b",
                   name, got, exp, r_lcs, r_mdly, r_dma12, r_dmap, OE_n,
                   CSDELAY0, CSDLY, CSECOND, CSLOOP, ACOND_n, MR_n, LUA12, MAP_n);
      end
    end
  endtask

  task set_state (input l, input m, input d, input p);
    begin
      r_lcs = l; r_mdly = m; r_dma12 = d; r_dmap = p;
      DUT_EN.gen_enable.LCS   = l;
      DUT_EN.gen_enable.MDLY  = m;
      DUT_EN.gen_enable.DMA12 = d;
      DUT_EN.gen_enable.DMAP  = p;
      DUT_OR.gen_orig.PAL.LCS   = l;
      DUT_OR.gen_orig.PAL.MDLY  = m;
      DUT_OR.gen_orig.PAL.DMA12 = d;
      DUT_OR.gen_orig.PAL.DMAP  = p;
      #1;
    end
  endtask

  task tick;
    begin
      sysclk = 1'b0; CLK = 1'b0; #1;
      sysclk = 1'b1; CLK = 1'b1; #1;
      sysclk = 1'b0; CLK = 1'b0; #1;
    end
  endtask

  initial begin
    $dumpfile("PAL_44403C_EN_tb.vcd");
    $dumpvars(0, PAL_44403C_EN_tb);
  end

  initial begin
    sysclk = 1'b0; CLK = 1'b0; EN = 1'b1;
    r_lcs = 0; r_mdly = 0; r_dma12 = 0; r_dmap = 0;
    $display("=====================================================");
    $display(" PAL_44403C_EN (CYIN0) exhaustive golden testbench");
    $display(" 9 input pins x 4 state bits = 8192 combinations");
    $display(" checked for USE_ENABLE=1 and USE_ENABLE=0");
    $display("=====================================================");

    for (st = 0; st < 16; st = st + 1) begin
      for (vec = 0; vec < 512; vec = vec + 1) begin
        {CSDELAY0, CSDLY, CSECOND, CSLOOP, ACOND_n, MR_n, LUA12, MAP_n, OE_n} = vec[8:0];
        set_state(st[0], st[1], st[2], st[3]);

        // always-enabled pins - checked whatever /OE does
        chk("EN1_DLY0_n",   e_DLY0_n,   g_DLY0_n);
        chk("OR0_DLY0_n",   o_DLY0_n,   g_DLY0_n);
        chk("EN1_SLCOND_n", e_SLCOND_n, g_SLCOND_n);
        chk("OR0_SLCOND_n", o_SLCOND_n, g_SLCOND_n);

        if (OE_n === 1'b0) begin
          chk("EN1_LCS_n",   e_LCS_n,   ~r_lcs);
          chk("OR0_LCS_n",   o_LCS_n,   ~r_lcs);
          chk("EN1_MDLY_n",  e_MDLY_n,  ~r_mdly);
          chk("OR0_MDLY_n",  o_MDLY_n,  ~r_mdly);
          chk("EN1_DMA12_n", e_DMA12_n, ~r_dma12);
          chk("OR0_DMA12_n", o_DMA12_n, ~r_dma12);
          chk("EN1_DMAP_n",  e_DMAP_n,  ~r_dmap);
          chk("OR0_DMAP_n",  o_DMAP_n,  ~r_dmap);
        end else begin
          chk("OEOFF_EN1_LCS_n",   e_LCS_n,   1'b0);
          chk("OEOFF_OR0_LCS_n",   o_LCS_n,   1'b0);
          chk("OEOFF_EN1_MDLY_n",  e_MDLY_n,  1'b0);
          chk("OEOFF_OR0_MDLY_n",  o_MDLY_n,  1'b0);
          chk("OEOFF_EN1_DMA12_n", e_DMA12_n, 1'b0);
          chk("OEOFF_OR0_DMA12_n", o_DMA12_n, 1'b0);
          chk("OEOFF_EN1_DMAP_n",  e_DMAP_n,  1'b0);
          chk("OEOFF_OR0_DMAP_n",  o_DMAP_n,  1'b0);
        end

        tick;
        if (OE_n === 1'b0) begin
          chk("EN1_LCS_n_next",   e_LCS_n,   ~g_lcs_next);
          chk("OR0_LCS_n_next",   o_LCS_n,   ~g_lcs_next);
          chk("EN1_MDLY_n_next",  e_MDLY_n,  ~g_mdly_next);
          chk("OR0_MDLY_n_next",  o_MDLY_n,  ~g_mdly_next);
          chk("EN1_DMA12_n_next", e_DMA12_n, ~g_dma12_next);
          chk("OR0_DMA12_n_next", o_DMA12_n, ~g_dma12_next);
          chk("EN1_DMAP_n_next",  e_DMAP_n,  ~g_dmap_next);
          chk("OR0_DMAP_n_next",  o_DMAP_n,  ~g_dmap_next);
        end

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;
      end
    end

    // ---- named property checks -----------------------------------------
    OE_n = 1'b0;
    CSDELAY0 = 1'b0; CSDLY = 1'b0; CSECOND = 1'b0; CSLOOP = 1'b0;
    ACOND_n = 1'b1; MR_n = 1'b1; MAP_n = 1'b1;

    // 1. THE XOR PROPERTY: DLY0 must fire only while LUA12 differs from its
    //    registered copy DMA12. An XNOR here - the old bug - inverts this.
    LUA12 = 1'b1; set_state(1'b0, 1'b0, 1'b0, 1'b0);   // DMA12=0, LUA12=1
    checks = checks + 1;
    if (e_DLY0_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL DLY0_XOR_DIFF: e_DLY0_n=%b, must assert while LUA12 != DMA12", e_DLY0_n);
    end
    set_state(1'b0, 1'b0, 1'b1, 1'b0);                  // DMA12=1, LUA12=1
    checks = checks + 1;
    if (e_DLY0_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL DLY0_XOR_SAME: e_DLY0_n=%b, must NOT assert while LUA12 == DMA12", e_DLY0_n);
    end
    LUA12 = 1'b0; set_state(1'b0, 1'b0, 1'b0, 1'b0);    // both 0
    checks = checks + 1;
    if (e_DLY0_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL DLY0_XOR_ZERO: e_DLY0_n=%b, must NOT assert with both low", e_DLY0_n);
    end

    // 2. DLY0's MAP term is the REGISTERED DMAP, not the raw MAP pin
    MAP_n = 1'b0; set_state(1'b0, 1'b0, 1'b0, 1'b0);   // MAP active, DMAP clear
    checks = checks + 1;
    if (e_DLY0_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL DLY0_RAW_MAP: e_DLY0_n=%b, raw MAP must not reach DLY0", e_DLY0_n);
    end
    set_state(1'b0, 1'b0, 1'b0, 1'b1);                  // DMAP set
    checks = checks + 1;
    if (e_DLY0_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL DLY0_DMAP: e_DLY0_n=%b, DMAP must reach DLY0", e_DLY0_n);
    end
    MAP_n = 1'b1;

    // 3. LCS: MR sets it, and it holds until DMA12 and LUA12 are both...
    //    every one of the three hold terms is /DMA12*/LUA12, DMA12*LUA12 or
    //    /DMA12*LUA12 - i.e. everything except DMA12 * /LUA12, which clears.
    MR_n = 1'b0; set_state(1'b0, 1'b0, 1'b0, 1'b0);
    tick;
    checks = checks + 1;
    if (e_LCS_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL LCS_MR_SET: e_LCS_n=%b, MR must set LCS", e_LCS_n);
    end
    MR_n = 1'b1; LUA12 = 1'b0; set_state(1'b1, 1'b0, 1'b1, 1'b0);  // DMA12=1 LUA12=0
    tick;
    checks = checks + 1;
    if (e_LCS_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL LCS_CLEAR: e_LCS_n=%b, DMA12 * /LUA12 must clear LCS", e_LCS_n);
    end
    LUA12 = 1'b1; set_state(1'b1, 1'b0, 1'b1, 1'b0);               // DMA12=1 LUA12=1
    tick;
    checks = checks + 1;
    if (e_LCS_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL LCS_HOLD: e_LCS_n=%b, DMA12 * LUA12 must hold LCS", e_LCS_n);
    end

    // 4. the clock enable really gates the USE_ENABLE=1 registers
    CSDLY = 1'b1; set_state(1'b0, 1'b0, 1'b0, 1'b0);
    EN = 1'b0; sysclk = 1'b1; #1; sysclk = 1'b0; #1;
    checks = checks + 1;
    if (e_MDLY_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL EN_GATE: e_MDLY_n=%b, EN low must block the capture", e_MDLY_n);
    end
    EN = 1'b1; tick;
    checks = checks + 1;
    if (e_MDLY_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL EN_RELEASE: e_MDLY_n=%b, EN high must capture CSDLY", e_MDLY_n);
    end

    // 5. nothing floats
    checks = checks + 1;
    if (^{e_LCS_n, e_MDLY_n, e_DMA12_n, e_DMAP_n, e_DLY0_n, e_SLCOND_n} === 1'bx) begin
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
