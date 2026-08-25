/****************************************************************************
** PAL_45009B (4F, ERROR - local memory parity error latch) golden tb      **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/45009B.txt. The model is re-derived   **
** from that PALASM listing term by term; the Verilog is under test. One    **
** DEVIATION is recorded below - it is reported, not patched here.          **
**                                                                         **
**   pins: RDATA /BLOCKL25 BCGNT50 /PS /RERR /PA TEST /LERR NC9 GND         **
**         /MR SPEAL /NC13 /NC14 /NC15 /BLOCKL /EPEAL /EPESL SPESL VCC      **
**                                                                         **
**   IF (/TEST) /SPESL = /RDATA + BLOCKL25 + EPEAL + EPESL + MR             **
**   IF (/TEST) /SPEAL = /BCGNT50 + BLOCKL25 + EPEAL + MR                   **
**   IF (/TEST) EPESL  = PS * /RERR                                        **
**   IF (/TEST) EPEAL  = PA * /RERR                                        **
**   IF (/TEST) BLOCKL = RDATA * /EPEAL * /EPESL * LERR * /MR   ; SET       **
**                     + BLOCKL * /PA * /MR                     ; HOLD      **
**                                                                         **
** RDATA is the write pulse for the status word and BCGNT50 the write pulse **
** for the address word, so the two strobes have different first literals - **
** getting them the same way round would make the PEA register capture on   **
** the wrong edge and is exactly the sort of single-literal slip this suite **
** is for.                                                                  **
**                                                                         **
** DEVIATION - TEST IS NOT IMPLEMENTED FOR THE FOUR COMBINATIONAL PINS. The **
** listing gates SPESL, SPEAL, /EPESL and /EPEAL with IF (/TEST); this RTL  **
** does not (PAL_45009B.v:69 says so in as many words), and instead uses    **
** !TEST as a FREEZE on the BLOCKL feedback latch, where the listing would  **
** disable the /BLOCKL pin. The sister part PAL_45001B.v does implement its **
** TEST term, so the two differ. TEST is the C-print mode, wired to PD4,    **
** and PD1..PD4 are always low on the 3202D, so nothing in the machine      **
** exercises it. Pinned below by TEST_NOT_IMPLEMENTED_ON_STROBES and        **
** TEST_FREEZES_BLOCKL_INSTEAD_OF_DISABLING, and reported as a finding.     **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 9 input pins x 1 state bit = 1024 combinations,    **
** all applied, with DUT.BLOCKL_reg FORCED before each vector.              **
**                                                                         **
** BUILD MODE: default (edge-triggered) build - state is forced and CK is   **
** pulsed. Do not compile with USE_TRANSPARENT_LATCHES. Both RTL branches   **
** carry the same next-state expression.                                    **
**                                                                         **
** TRI-STATE: no /OE pin. Every output is always driven; checked for x/z.   **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal45009b                           **
**                                                                         **
** Last reviewed: 20-AUG-2026                                               **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module PAL_45009B_tb;

  reg CK, sys_rst_n;
  reg RDATA, BLOCKL25_n, BCGNT50, PS_n, RERR_n, PA_n, TEST, LERR_n, MR_n;

  wire SPESL, SPEAL, EPESL_n, EPEAL_n, BLOCKL_n;

  integer checks = 0, errors = 0, vec, st, dumped = 0;

  PAL_45009B DUT (
      .CK(CK), .sys_rst_n(sys_rst_n),
      .RDATA(RDATA), .BLOCKL25_n(BLOCKL25_n), .BCGNT50(BCGNT50),
      .PS_n(PS_n), .RERR_n(RERR_n), .PA_n(PA_n), .TEST(TEST),
      .LERR_n(LERR_n), .MR_n(MR_n),
      .SPESL(SPESL), .SPEAL(SPEAL),
      .EPESL_n(EPESL_n), .EPEAL_n(EPEAL_n), .BLOCKL_n(BLOCKL_n)
  );

  // ---- golden model from the listing ------------------------------------
  wire g_PS = ~PS_n, g_PA = ~PA_n, g_LERR = ~LERR_n, g_MR = ~MR_n;
  wire g_BLOCKL25 = ~BLOCKL25_n;

  reg  r_blockl;

  // EPESL / EPEAL are pins 18 and 17, both active low
  wire g_EPESL_n = ~(g_PS & RERR_n);
  wire g_EPEAL_n = ~(g_PA & RERR_n);

  wire g_SPESL = ~( ~RDATA | g_BLOCKL25 | ~g_EPEAL_n | ~g_EPESL_n | g_MR );
  wire g_SPEAL = ~( ~BCGNT50 | g_BLOCKL25 | ~g_EPEAL_n | g_MR );

  wire g_set  = RDATA & g_EPEAL_n & g_EPESL_n & g_LERR & MR_n;
  wire g_hold = PA_n & MR_n;
  // TEST freezes the latch in this RTL - see the DEVIATION note in the header
  wire g_blockl_next = TEST ? r_blockl : (g_set | (r_blockl & g_hold));

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | blockl=%b TEST=%b RDATA=%b BLOCKL25_n=%b BCGNT50=%b PS_n=%b RERR_n=%b PA_n=%b LERR_n=%b MR_n=%b",
                   name, got, exp, r_blockl, TEST, RDATA, BLOCKL25_n, BCGNT50,
                   PS_n, RERR_n, PA_n, LERR_n, MR_n);
      end
    end
  endtask

  task set_state (input v);
    begin r_blockl = v; DUT.BLOCKL_reg = v; #1; end
  endtask

  task tick; begin CK = 1'b0; #1; CK = 1'b1; #1; CK = 1'b0; #1; end endtask

  initial begin
    $dumpfile("PAL_45009B_tb.vcd");
    $dumpvars(0, PAL_45009B_tb);
  end

  initial begin
    CK = 1'b0; sys_rst_n = 1'b1; r_blockl = 0;
    $display("=====================================================");
    $display(" PAL_45009B (ERROR) exhaustive golden testbench");
    $display(" 9 input pins x 1 state bit = 1024 combinations");
    $display("=====================================================");

    for (st = 0; st < 2; st = st + 1) begin
      for (vec = 0; vec < 512; vec = vec + 1) begin
        {RDATA, BLOCKL25_n, BCGNT50, PS_n, RERR_n, PA_n, TEST,
         LERR_n, MR_n} = vec[8:0];
        set_state(st[0]);

        // The four combinational pins ignore TEST in this RTL - see header.
        chk("TEST_NOT_IMPLEMENTED_ON_STROBES_SPESL", SPESL,   g_SPESL);
        chk("TEST_NOT_IMPLEMENTED_ON_STROBES_SPEAL", SPEAL,   g_SPEAL);
        chk("EPESL_n", EPESL_n, g_EPESL_n);
        chk("EPEAL_n", EPEAL_n, g_EPEAL_n);
        chk("BLOCKL_n", BLOCKL_n, ~r_blockl);

        tick;
        chk("BLOCKL_n_next", BLOCKL_n, ~g_blockl_next);

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;
      end
    end

    // ---- named property checks -----------------------------------------
    TEST = 1'b0;

    // 1. async reset clears the BLOCKL latch
    set_state(1'b1);
    sys_rst_n = 1'b0; #1;
    checks = checks + 1;
    if (BLOCKL_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL RESET: BLOCKL_n=%b, reset must clear BLOCKL", BLOCKL_n);
    end
    sys_rst_n = 1'b1; #1;

    // 2. THE TWO STROBES USE DIFFERENT WRITE PULSES: RDATA for the status
    //    word, BCGNT50 for the address word. Neither may respond to the
    //    other's pulse.
    BLOCKL25_n = 1'b1; PS_n = 1'b1; PA_n = 1'b1; RERR_n = 1'b1; MR_n = 1'b1;
    RDATA = 1'b1; BCGNT50 = 1'b0; #1;
    checks = checks + 1;
    if (SPESL !== 1'b1 || SPEAL !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL STROBE_RDATA: SPESL=%b (want 1) SPEAL=%b (want 0)", SPESL, SPEAL);
    end
    RDATA = 1'b0; BCGNT50 = 1'b1; #1;
    checks = checks + 1;
    if (SPESL !== 1'b0 || SPEAL !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL STROBE_BCGNT50: SPESL=%b (want 0) SPEAL=%b (want 1)", SPESL, SPEAL);
    end

    // 3. BLOCKL25 stops BOTH strobes - the 1987 errata replaced BLOCKL with
    //    BLOCKL25 here precisely to kill a spike on SPEAL.
    RDATA = 1'b1; BCGNT50 = 1'b1; BLOCKL25_n = 1'b0; #1;
    checks = checks + 1;
    if (SPESL !== 1'b0 || SPEAL !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL BLOCKL25_STOPS: SPESL=%b SPEAL=%b, both must stop", SPESL, SPEAL);
    end
    BLOCKL25_n = 1'b1;

    // 4. EPESL and EPEAL are enabled only when the last error was LOCAL:
    //    an active RERR (remote) must suppress both.
    PS_n = 1'b0; PA_n = 1'b0; RERR_n = 1'b1; #1;
    checks = checks + 1;
    if (EPESL_n !== 1'b0 || EPEAL_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL EPE_LOCAL: EPESL_n=%b EPEAL_n=%b, both must enable", EPESL_n, EPEAL_n);
    end
    RERR_n = 1'b0; #1;
    checks = checks + 1;
    if (EPESL_n !== 1'b1 || EPEAL_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL EPE_REMOTE: EPESL_n=%b EPEAL_n=%b, RERR must suppress both",
               EPESL_n, EPEAL_n);
    end
    RERR_n = 1'b1; PS_n = 1'b1; PA_n = 1'b1;

    // 5. BLOCKL: set on a LOCAL error, held until a PEA read, cleared by MR
    RDATA = 1'b1; LERR_n = 1'b0; MR_n = 1'b1; PA_n = 1'b1;
    set_state(1'b0);
    tick;
    checks = checks + 1;
    if (BLOCKL_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL BLOCKL_SET: BLOCKL_n=%b, a local error must block", BLOCKL_n);
    end
    LERR_n = 1'b1; RDATA = 1'b0;
    set_state(1'b1);
    tick;
    checks = checks + 1;
    if (BLOCKL_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL BLOCKL_HOLD: BLOCKL_n=%b, BLOCKL must hold", BLOCKL_n);
    end
    PA_n = 1'b0;                                   // PEA read
    set_state(1'b1);
    tick;
    checks = checks + 1;
    if (BLOCKL_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL BLOCKL_PA: BLOCKL_n=%b, a PEA read must release BLOCKL", BLOCKL_n);
    end
    PA_n = 1'b1; MR_n = 1'b0;
    set_state(1'b1);
    tick;
    checks = checks + 1;
    if (BLOCKL_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL BLOCKL_MR: BLOCKL_n=%b, MR must release BLOCKL", BLOCKL_n);
    end
    MR_n = 1'b1;

    // 6. the RTL's TEST behaviour: a FREEZE of the latch, where the listing
    //    would disable the /BLOCKL pin. Documented deviation, see header.
    RDATA = 1'b1; LERR_n = 1'b0; PA_n = 1'b1; MR_n = 1'b1;
    TEST = 1'b1;
    set_state(1'b0);
    tick;
    checks = checks + 1;
    if (BLOCKL_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL TEST_FREEZES_BLOCKL_INSTEAD_OF_DISABLING: BLOCKL_n=%b, expected the frozen state", BLOCKL_n);
    end
    set_state(1'b1);
    tick;
    checks = checks + 1;
    if (BLOCKL_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL TEST_FREEZE_HIGH: BLOCKL_n=%b, TEST must freeze at 1 too", BLOCKL_n);
    end
    TEST = 1'b0;

    // 7. nothing floats
    checks = checks + 1;
    if (^{SPESL, SPEAL, EPESL_n, EPEAL_n, BLOCKL_n} === 1'bx) begin
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
