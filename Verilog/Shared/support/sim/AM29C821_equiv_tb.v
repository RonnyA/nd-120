/**************************************************************************
** ND120 CPU - unit test                                                 **
** AM29C821 mode equivalence: USE_SYSCLK=0 (posedge CK) vs =2 (sysclk    **
** edge capture), plus the documented =1 level-capture hazard.           **
**                                                                       **
** CK is driven ONLY as a sysclk-registered signal (like every real      **
** consumer in FF mode: BCGNT50, s_clk, ...), so mode 0 and mode 2 must  **
** produce identical Y on every sysclk. Mode 1 is checked to DIVERGE on  **
** the multi-cycle-CK case (D changes while CK held high) - that is the  **
** teeth: the tb fails if the known-bad mode ever looks equivalent.      **
**                                                                       **
** Run: make test-am29c821   (Shared/support/sim)                        **
***************************************************************************/
`timescale 1ns / 1ps

module AM29C821_equiv_tb;

  reg        sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg        ck = 0;
  reg        oe_n = 0;
  reg  [9:0] d = 10'o0000;

  wire [9:0] y_ref, y_edge, y_level;

  AM29C821 #(.USE_SYSCLK(0)) U_REF   (.sysclk(sysclk), .CK(ck), .OE_n(oe_n), .D(d), .Y(y_ref));
  AM29C821 #(.USE_SYSCLK(2)) U_EDGE  (.sysclk(sysclk), .CK(ck), .OE_n(oe_n), .D(d), .Y(y_edge));
  AM29C821 #(.USE_SYSCLK(1)) U_LEVEL (.sysclk(sysclk), .CK(ck), .OE_n(oe_n), .D(d), .Y(y_level));

  integer checks = 0;
  integer errors = 0;
  integer teeth  = 0;   // sysclk cycles where the known-bad level mode diverges

  // Compare just before each sysclk rise (both modes settled).
  task check;
    begin
      @(negedge sysclk);
      checks = checks + 1;
      if (y_ref !== y_edge) begin
        errors = errors + 1;
        $display("FAIL t=%0t: y_ref=%o y_edge=%o (ck=%b d=%o oe_n=%b)",
                 $time, y_ref, y_edge, ck, d, oe_n);
      end
      if (y_ref !== y_level) teeth = teeth + 1;
    end
  endtask

  integer i;
  initial begin
    $dumpfile("AM29C821_equiv_tb.vcd");
    $dumpvars(0, AM29C821_equiv_tb);

    // ---- 1. single-cycle CK pulses (the s_clk-style consumer) ----
    for (i = 0; i < 20; i = i + 1) begin
      @(negedge sysclk); d = i * 3 + 1;
      @(negedge sysclk); ck = 1;       // one-sysclk pulse
      @(negedge sysclk); ck = 0;
      check; check;
    end

    // ---- 2. multi-cycle CK with D changing under the held strobe ----
    // (the BCGNT50 case that broke deposits: address first, data later)
    for (i = 0; i < 20; i = i + 1) begin
      @(negedge sysclk); d = 10'o0100 + i;   // "address" on the bus
      @(negedge sysclk); ck = 1;             // strobe rises: capture NOW
      check;
      @(negedge sysclk); d = 10'o0700 + i;   // bus moves on to "data"
      check;                                  // mode 1 re-captures here (teeth)
      @(negedge sysclk); check;
      @(negedge sysclk); ck = 0; d = 10'o0250;
      check; check;
    end

    // ---- 3. OE_n gating (no capture involvement) ----
    @(negedge sysclk); d = 10'o1234; ck = 1;
    @(negedge sysclk); ck = 0;
    @(negedge sysclk); oe_n = 1; check;
    @(negedge sysclk); oe_n = 0; check;

    // ---- 4. back-to-back pulses, minimum spacing ----
    for (i = 0; i < 10; i = i + 1) begin
      @(negedge sysclk); d = 10'o0400 + i; ck = 1;
      @(negedge sysclk); ck = 0;
      check;
    end

    $display("checks=%0d errors=%0d teeth(level-mode divergences)=%0d",
             checks, errors, teeth);
    if (errors == 0 && teeth > 0) begin
      $display("TB_RESULT: PASS");
    end else begin
      if (teeth == 0)
        $display("FAIL: level mode never diverged - tb has no teeth");
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

  initial begin
    #200000;
    $display("FAIL [timeout]: watchdog fired");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
