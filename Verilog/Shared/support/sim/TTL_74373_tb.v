/****************************************************************************
** TTL_74373 - functional testbench                                        **
**                                                                         **
** Octal D-type transparent latch with 3-state outputs. Read from          **
** Verilog/Shared/support/TTL_74373.v:                                     **
**   - C=1 (active high) is TRANSPARENT: Q_Latch follows D combinationally.**
**   - C=0 HOLDS: Q_Latch keeps its last value (an explicit self-assign     **
**     in an always@(*) block, which is a level-sensitive latch, not an    **
**     edge FF - matches the real SN54LS373 transparent-latch behaviour).  **
**   - Q = OC_n ? 8'b0 : Q_Latch - the disabled output drives ZERO, not     **
**     high-Z. That is the repo-wide FPGA bus-sharing convention and a     **
**     departure from the real 74373 (which goes high-Z when disabled).    **
**   - Q_Latch has NO reset and NO initial value in the RTL, so before the  **
**     first C=1 period its value (and hence Q, when OC_n=0) is X. This     **
**     testbench opens the latch before ever checking a value, exactly as  **
**     real hardware requires a first load before Q means anything.        **
**                                                                         **
** COVERAGE: an exhaustive sweep of all 256 D values through the           **
** TRANSPARENT path (Q must track D exactly, C=1, OC_n=0), plus an         **
** exhaustive sweep of all 256 D values presented while HOLDING (C=0) -    **
** Q must not move at all as D is walked through every value. 512 value    **
** checks in total. A full history-dependent exhaustive sweep (D history x **
** C history) is not attempted - the state space is unbounded - so this is **
** a directed sequence (open/hold/reopen/OC_n-masking-in-both-states) plus **
** the two exhaustive single-axis sweeps described above.                  **
**                                                                         **
** Run: cd Verilog/Shared/support/sim && make test-74373                  **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module TTL_74373_tb;

  reg  [7:0] D;
  reg        C, OC_n;
  wire [7:0] Q;

  integer errors = 0;
  integer checks = 0;

  TTL_74373 DUT (
      .D(D),
      .C(C),
      .OC_n(OC_n),
      .Q(Q)
  );

  initial begin
    $dumpfile("TTL_74373_tb.vcd");
    $dumpvars(0, TTL_74373_tb);

    $display("=====================================================");
    $display(" TTL_74373 functional testbench");
    $display(" (directed sequence + 256+256 exhaustive D sweeps)");
    $display("=====================================================");

    // ---- directed documentation sequence ----------------------------------
    D = 8'h00; C = 1'b0; OC_n = 1'b1; #10; // reset-ish state, latch not yet opened, output masked

    // Open the latch and prove transparent follow
    C = 1'b1; OC_n = 1'b0; D = 8'hA5; #10;
    checks = checks + 1;
    if (Q !== 8'hA5) begin
      errors = errors + 1;
      $display("FAIL TRANSPARENT_1: D=A5 C=1 OC_n=0 -> Q=%02h expected A5", Q);
    end

    D = 8'h3C; #10; // still transparent, Q must follow again
    checks = checks + 1;
    if (Q !== 8'h3C) begin
      errors = errors + 1;
      $display("FAIL TRANSPARENT_2: D=3C C=1 OC_n=0 -> Q=%02h expected 3C", Q);
    end

    // Close the latch (hold) and change D - Q must not move
    C = 1'b0; #10;
    checks = checks + 1;
    if (Q !== 8'h3C) begin
      errors = errors + 1;
      $display("FAIL HOLD_ENTRY: Q=%02h changed the instant C fell, expected 3C", Q);
    end
    D = 8'hFF; #10;
    checks = checks + 1;
    if (Q !== 8'h3C) begin
      errors = errors + 1;
      $display("FAIL HOLD_1: D changed to FF while C=0 but Q=%02h, expected held 3C", Q);
    end
    D = 8'h00; #10;
    checks = checks + 1;
    if (Q !== 8'h3C) begin
      errors = errors + 1;
      $display("FAIL HOLD_2: D changed to 00 while C=0 but Q=%02h, expected held 3C", Q);
    end

    // OC_n masking while HOLDING: output must go to 0 regardless of the
    // latched value, and come back to the held value when re-enabled
    OC_n = 1'b1; #10;
    checks = checks + 1;
    if (Q !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL OC_MASK_HOLD: OC_n=1 while holding but Q=%02h, expected 0", Q);
    end
    OC_n = 1'b0; #10;
    checks = checks + 1;
    if (Q !== 8'h3C) begin
      errors = errors + 1;
      $display("FAIL OC_UNMASK_HOLD: OC_n=0 again but Q=%02h, expected held 3C", Q);
    end

    // Re-open the latch, prove transparent follow resumes
    C = 1'b1; D = 8'h81; #10;
    checks = checks + 1;
    if (Q !== 8'h81) begin
      errors = errors + 1;
      $display("FAIL REOPEN: D=81 C=1 OC_n=0 -> Q=%02h expected 81", Q);
    end

    // OC_n masking while TRANSPARENT and D changing: Q must read 0 no
    // matter what D does, and resume following D the instant OC_n clears
    OC_n = 1'b1; D = 8'h00; #10;
    checks = checks + 1;
    if (Q !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL OC_MASK_TRANSPARENT_1: D=00 OC_n=1 -> Q=%02h expected 0", Q);
    end
    D = 8'hFF; #10;
    checks = checks + 1;
    if (Q !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL OC_MASK_TRANSPARENT_2: D=FF OC_n=1 -> Q=%02h expected 0 (masked, not FF)", Q);
    end
    OC_n = 1'b0; #10;
    checks = checks + 1;
    if (Q !== 8'hFF) begin
      errors = errors + 1;
      $display("FAIL OC_UNMASK_TRANSPARENT: OC_n=0 again, D=FF, but Q=%02h expected FF", Q);
    end

    $dumpoff;

    // ---- exhaustive sweep 1: transparent path, all 256 D values -----------
    C = 1'b1; OC_n = 1'b0;
    for (integer id = 0; id < 256; id = id + 1) begin
      D = id[7:0];
      #1;
      checks = checks + 1;
      if (Q !== D) begin
        errors = errors + 1;
        if (errors < 10)
          $display("FAIL TRANSPARENT_SWEEP: D=%02h -> Q=%02h", D, Q);
      end
    end

    // ---- exhaustive sweep 2: holding, all 256 D values must NOT move Q ----
    D = 8'h5A; C = 1'b1; #1; C = 1'b0; #1; // latch a known value, then hold
    for (integer id2 = 0; id2 < 256; id2 = id2 + 1) begin
      D = id2[7:0];
      #1;
      checks = checks + 1;
      if (Q !== 8'h5A) begin
        errors = errors + 1;
        if (errors < 10)
          $display("FAIL HOLD_SWEEP: D=%02h while C=0 but Q=%02h, expected held 5A", D, Q);
      end
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
