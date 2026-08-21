/****************************************************************************
** AM29861A - exhaustive functional testbench                            **
**                                                                        **
** COVERAGE: all 4 combinations of (OER_n, OET_n) are exercised. For EACH **
** of the 4 combinations, D_IN is swept over all 1024 values with Y_IN    **
** held fixed at 0, and separately Y_IN is swept over all 1024 values     **
** with D_IN held fixed at 0 - that is 4 x (1024 + 1024) = 8192 combi-    **
** national checks, plus the named property checks below.                 **
**                                                                        **
** RTL-VS-DATASHEET DISAGREEMENT (record and assert the RTL, not the      **
** datasheet): on the real AM29861A, asserting OER_n and OET_n together   **
** drives both directions at once and is an illegal/contention condition  **
** the datasheet does not define a clean output for. This RTL computes    **
** s_receive = !OER_n & OET_n and s_transmit = OER_n & !OET_n - so with   **
** BOTH enables asserted (OER_n=0 and OET_n=0) neither term is true and   **
** BOTH Y_OUT and D_OUT read all-zero. This is NOT contention in this     **
** model, it is "both paths disabled" - checked explicitly below as      **
** BOTH_ASSERTED_GIVES_ZERO, asserting the RTL's actual (safe) behaviour  **
** rather than the real part's undefined contention.                      **
**                                                                        **
** THE TRANSCEIVER PROPERTY THAT MATTERS MOST IN THIS REPO (the           **
** "B must not reach B_OUT" check from TTL_74245_tb.v, repeated here in   **
** both directions): while transmitting (Y_OUT=D_IN), the receive-side    **
** input Y_IN must have NO influence on Y_OUT; while receiving            **
** (D_OUT=Y_IN), the transmit-side input D_IN must have NO influence on   **
** D_OUT. Checked by flipping the unused input from all-zero to all-ones  **
** and requiring the active output not to move.                           **
**                                                                        **
** NO shared-helper-wire combinational-loop pattern (the                  **
** `wire bus = DIR ? A : B;` form removed from TTL_74245) exists in this  **
** module - Y_OUT and D_OUT are each assigned directly from an input, so  **
** this testbench found nothing of that shape to report.                  **
**                                                                        **
** Run: cd Verilog/Shared/support/sim && iverilog -g2012 -o tb.vvp \      **
**   AM29861A_tb.v ../AM29861A.v && vvp tb.vvp                            **
**                                                                        **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module AM29861A_tb;

  reg        OER_n, OET_n;
  reg  [9:0] D_IN, Y_IN;
  wire [9:0] D_OUT, Y_OUT;

  integer errors = 0;
  integer checks = 0;

  AM29861A DUT (
      .OER_n(OER_n), .OET_n(OET_n),
      .D_IN(D_IN), .Y_IN(Y_IN),
      .D_OUT(D_OUT), .Y_OUT(Y_OUT)
  );

  // Reference model, matching the RTL's own enable equations exactly
  // (s_receive = !OER_n & OET_n, s_transmit = OER_n & !OET_n).
  function [9:0] ref_y_out;
    input [9:0] d_in;
    input oer_n, oet_n;
    begin
      ref_y_out = (oer_n & !oet_n) ? d_in : 10'b0;
    end
  endfunction

  function [9:0] ref_d_out;
    input [9:0] y_in;
    input oer_n, oet_n;
    begin
      ref_d_out = (!oer_n & oet_n) ? y_in : 10'b0;
    end
  endfunction

  integer e, k;
  reg [9:0] ey, ed;

  initial begin
    $dumpfile("AM29861A_tb.vcd");
    $dumpvars(0, AM29861A_tb);

    // ---- short documentation sequence --------------------------------------
    OER_n = 1; OET_n = 0; D_IN = 10'o1234; Y_IN = 10'o0000; #1;   // transmit
    checks = checks + 1;
    if (Y_OUT !== 10'o1234 || D_OUT !== 10'b0) begin
      errors = errors + 1;
      $display("FAIL doc transmit: Y_OUT=%03o D_OUT=%03o", Y_OUT, D_OUT);
    end
    OER_n = 0; OET_n = 1; D_IN = 10'o0000; Y_IN = 10'o0765; #1;   // receive
    checks = checks + 1;
    if (D_OUT !== 10'o0765 || Y_OUT !== 10'b0) begin
      errors = errors + 1;
      $display("FAIL doc receive: D_OUT=%03o Y_OUT=%03o", D_OUT, Y_OUT);
    end
    OER_n = 1; OET_n = 1; #1;                                     // both off
    checks = checks + 1;
    if (D_OUT !== 10'b0 || Y_OUT !== 10'b0) begin
      errors = errors + 1;
      $display("FAIL doc both-deasserted: D_OUT=%03o Y_OUT=%03o", D_OUT, Y_OUT);
    end
    OER_n = 0; OET_n = 0; #1;                                     // both on
    checks = checks + 1;
    if (D_OUT !== 10'b0 || Y_OUT !== 10'b0) begin
      errors = errors + 1;
      $display("FAIL doc both-asserted: D_OUT=%03o Y_OUT=%03o", D_OUT, Y_OUT);
    end
    $dumpoff;

    // ---- exhaustive: 4 enable combos x (1024 D_IN sweep + 1024 Y_IN sweep) -
    $display("=====================================================");
    $display(" AM29861A exhaustive sweep: 4 enable states x 2048 = 8192 checks");
    $display("=====================================================");
    for (e = 0; e < 4; e = e + 1) begin
      OER_n = e[1];
      OET_n = e[0];

      // sweep D_IN, Y_IN fixed 0
      Y_IN = 10'b0;
      for (k = 0; k < 1024; k = k + 1) begin
        D_IN = k[9:0];
        #1;
        ey = ref_y_out(D_IN, OER_n, OET_n);
        ed = ref_d_out(Y_IN, OER_n, OET_n);
        checks = checks + 2;
        if (Y_OUT !== ey) begin
          errors = errors + 1;
          if (errors < 10)
            $display("FAIL D_IN-sweep: OER_n=%b OET_n=%b D_IN=%03o -> Y_OUT=%03o expected %03o",
                     OER_n, OET_n, D_IN, Y_OUT, ey);
        end
        if (D_OUT !== ed) begin
          errors = errors + 1;
          if (errors < 10)
            $display("FAIL D_IN-sweep: OER_n=%b OET_n=%b D_IN=%03o -> D_OUT=%03o expected %03o",
                     OER_n, OET_n, D_IN, D_OUT, ed);
        end
      end

      // sweep Y_IN, D_IN fixed 0
      D_IN = 10'b0;
      for (k = 0; k < 1024; k = k + 1) begin
        Y_IN = k[9:0];
        #1;
        ey = ref_y_out(D_IN, OER_n, OET_n);
        ed = ref_d_out(Y_IN, OER_n, OET_n);
        checks = checks + 2;
        if (Y_OUT !== ey) begin
          errors = errors + 1;
          if (errors < 10)
            $display("FAIL Y_IN-sweep: OER_n=%b OET_n=%b Y_IN=%03o -> Y_OUT=%03o expected %03o",
                     OER_n, OET_n, Y_IN, Y_OUT, ey);
        end
        if (D_OUT !== ed) begin
          errors = errors + 1;
          if (errors < 10)
            $display("FAIL Y_IN-sweep: OER_n=%b OET_n=%b Y_IN=%03o -> D_OUT=%03o expected %03o",
                     OER_n, OET_n, Y_IN, D_OUT, ed);
        end
      end
    end

    // ---- named check: both enables asserted -> BOTH outputs zero ----------
    OER_n = 0; OET_n = 0; D_IN = 10'o1777; Y_IN = 10'o1777; #1;
    checks = checks + 1;
    if (Y_OUT !== 10'b0 || D_OUT !== 10'b0) begin
      errors = errors + 1;
      $display("FAIL BOTH_ASSERTED_GIVES_ZERO: Y_OUT=%03o D_OUT=%03o, both must be 0 (RTL disables both paths, not contention)", Y_OUT, D_OUT);
    end

    // ---- named check: both enables deasserted -> BOTH outputs zero --------
    OER_n = 1; OET_n = 1; D_IN = 10'o1777; Y_IN = 10'o1777; #1;
    checks = checks + 1;
    if (Y_OUT !== 10'b0 || D_OUT !== 10'b0) begin
      errors = errors + 1;
      $display("FAIL BOTH_DEASSERTED_GIVES_ZERO: Y_OUT=%03o D_OUT=%03o, both must be 0", Y_OUT, D_OUT);
    end

    // ---- named check: TRANSMIT direction - Y_IN must not reach Y_OUT ------
    OER_n = 1; OET_n = 0; D_IN = 10'o0555;
    Y_IN = 10'b0; #1; ey = Y_OUT;
    checks = checks + 1;
    if (ey !== 10'o0555) begin
      errors = errors + 1;
      $display("FAIL TRANSMIT_setup: Y_OUT=%03o expected 0555", ey);
    end
    Y_IN = 10'o1777; #1;    // receive-side input swung to all-ones
    checks = checks + 1;
    if (Y_OUT !== ey) begin
      errors = errors + 1;
      $display("FAIL Y_IN_DOES_NOT_REACH_Y_OUT: Y_OUT changed from %03o to %03o when Y_IN moved", ey, Y_OUT);
    end

    // ---- named check: RECEIVE direction - D_IN must not reach D_OUT -------
    OER_n = 0; OET_n = 1; Y_IN = 10'o0222;
    D_IN = 10'b0; #1; ed = D_OUT;
    checks = checks + 1;
    if (ed !== 10'o0222) begin
      errors = errors + 1;
      $display("FAIL RECEIVE_setup: D_OUT=%03o expected 0222", ed);
    end
    D_IN = 10'o1777; #1;    // transmit-side input swung to all-ones
    checks = checks + 1;
    if (D_OUT !== ed) begin
      errors = errors + 1;
      $display("FAIL D_IN_DOES_NOT_REACH_D_OUT: D_OUT changed from %03o to %03o when D_IN moved", ed, D_OUT);
    end

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

  initial begin
    #400000;
    $display("FAIL [timeout]: watchdog fired");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire
