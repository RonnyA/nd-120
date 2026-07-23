/**************************************************************************************************
** ND120 Shared - unit test                                                                      **
**                                                                                               **
** AM29833A equivalence testbench: USE_SYSCLK=0 (original posedge CLK) vs                        **
** USE_SYSCLK=2 (sysclk-sampled rising-edge capture, the FPGA-safe mode).                        **
**                                                                                               **
** Contract under test (docs/plan-fix-unconstrained-clocks.md P1a): when CLK                     **
** is generated in the sysclk domain and is at least one sysclk cycle wide                       **
** (true for RDATA from PAL_44310), both modes latch the same ERR value for                      **
** every CLK rise; mode 2 is allowed exactly one sysclk of capture latency.                      **
** The combinational ports (R_OUT/T_OUT/PAR_OUT) must match cycle-exact.                         **
**                                                                                               **
** Self-check: pass 2 re-runs the comparison against a deliberately wrong                        **
** reference (parity input inverted) and MUST report mismatches - proving                        **
** the testbench can actually fail.                                                              **
**                                                                                               **
** Run: make test-am29833a                                                                       **
**                                                                                               **
** Last reviewed: 9-JUL-2026                                                                     **
** Ronny Hansen                                                                                  **
***************************************************************************************************/
`timescale 1ns / 1ps

module AM29833A_equiv_tb;

  reg sysclk = 0;
  always #10 sysclk = ~sysclk;

  reg        clk_strobe = 0;
  reg        clr_n = 1;
  reg        oer_n = 1;
  reg        oet_n = 1;
  reg        par = 0;
  reg  [7:0] r_in = 0;
  reg  [7:0] t_in = 0;

  wire       err_a, err_b, err_bad;
  wire       parout_a, parout_b;
  wire [7:0] rout_a, rout_b, tout_a, tout_b;

  // Reference: original chip model
  AM29833A #(.USE_SYSCLK(0)) ref_chip (
      .sysclk(sysclk), .CLK(clk_strobe), .CLR_n(clr_n),
      .ERR_n(err_a), .OER_n(oer_n), .OET_n(oet_n),
      .PAR(par), .PAR_OUT(parout_a),
      .R(r_in), .R_OUT(rout_a), .T(t_in), .T_OUT(tout_a)
  );

  // Device under test: FPGA edge-capture mode
  AM29833A #(.USE_SYSCLK(2)) dut_chip (
      .sysclk(sysclk), .CLK(clk_strobe), .CLR_n(clr_n),
      .ERR_n(err_b), .OER_n(oer_n), .OET_n(oet_n),
      .PAR(par), .PAR_OUT(parout_b),
      .R(r_in), .R_OUT(rout_b), .T(t_in), .T_OUT(tout_b)
  );

  // Teeth-prover: same DUT but fed inverted parity - must diverge from ref
  AM29833A #(.USE_SYSCLK(2)) bad_chip (
      .sysclk(sysclk), .CLK(clk_strobe), .CLR_n(clr_n),
      .ERR_n(err_bad), .OER_n(oer_n), .OET_n(oet_n),
      .PAR(~par), .PAR_OUT(),
      .R(r_in), .R_OUT(), .T(t_in), .T_OUT()
  );

  integer errors = 0;
  integer bad_mismatches = 0;
  integer captures = 0;

  // Combinational ports must match at all times (checked every cycle)
  always @(negedge sysclk) begin
    if (rout_a !== rout_b || tout_a !== tout_b || parout_a !== parout_b) begin
      errors = errors + 1;
      $display("FAIL t=%0t: comb mismatch R %02x/%02x T %02x/%02x P %b/%b",
               $time, rout_a, rout_b, tout_a, tout_b, parout_a, parout_b);
    end
  end

  // Drive one CLK strobe of `width` sysclk cycles with the current inputs,
  // then verify both ERR registers agree one cycle after the strobe.
  task pulse_and_check(input integer width);
    integer w;
    begin
      @(negedge sysclk) clk_strobe = 1;
      for (w = 0; w < width; w = w + 1) @(negedge sysclk);
      clk_strobe = 0;
      @(negedge sysclk);  // one sysclk grace for the mode-2 capture latency
      captures = captures + 1;
      if (err_a !== err_b) begin
        errors = errors + 1;
        $display("FAIL t=%0t: ERR mismatch ref=%b dut=%b (T=%02x PAR=%b OER_n=%b OET_n=%b)",
                 $time, err_a, err_b, t_in, par, oer_n, oet_n);
      end
      if (err_a !== err_bad) bad_mismatches = bad_mismatches + 1;
    end
  endtask

  integer i;
  initial begin
    $dumpfile("AM29833A_equiv_tb.vcd");
    $dumpvars(0, AM29833A_equiv_tb);

    // Reset both error registers
    clr_n = 0;
    repeat (3) @(negedge sysclk);
    clr_n = 1;
    @(negedge sysclk);

    // Directed: even parity on T+PAR (error) and odd parity (no error),
    // in transmit mode (OET_n=0) and disabled mode (both high)
    oer_n = 1; oet_n = 0;
    t_in = 8'h0F; par = 0;  pulse_and_check(1);  // even 9-bit parity -> error
    t_in = 8'h0F; par = 1;  pulse_and_check(1);  // odd -> no error
    oet_n = 1;
    t_in = 8'hFF; par = 0;  pulse_and_check(2);  // 8 ones + 0 -> even -> error
    t_in = 8'h01; par = 0;  pulse_and_check(3);  // odd -> no error

    // Mid-sequence clear must win in both modes
    clr_n = 0;
    repeat (2) @(negedge sysclk);
    clr_n = 1;
    @(negedge sysclk);
    if (err_a !== 1'b1 || err_b !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL t=%0t: CLR_n did not clear (ref=%b dut=%b)", $time, err_a, err_b);
    end

    // Randomized soak: random data/parity/mode, strobe widths 1..4
    for (i = 0; i < 500; i = i + 1) begin
      t_in  = $random;
      r_in  = $random;
      par   = $random;
      // receive mode excluded from capture checks by the chip itself, but
      // exercise all three enable combinations anyway
      {oer_n, oet_n} = ($random & 1) ? 2'b10 : (($random & 1) ? 2'b01 : 2'b11);
      pulse_and_check(1 + ($random & 3));
      if (($random & 7) == 0) begin
        clr_n = 0; @(negedge sysclk); clr_n = 1; @(negedge sysclk);
      end
    end

    $display("captures=%0d errors=%0d teeth(bad-ref mismatches)=%0d",
             captures, errors, bad_mismatches);
    if (bad_mismatches == 0) begin
      $display("TB_RESULT: FAIL (teeth check: the bad reference never diverged - tb cannot detect errors)");
    end else if (errors == 0) begin
      $display("TB_RESULT: PASS");
    end else begin
      $display("TB_RESULT: FAIL (%0d errors)", errors);
    end
    $finish;
  end

endmodule
