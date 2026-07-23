/**************************************************************************************************
** ND120 CPU Board 3202D - unit test                                                             **
**                                                                                               **
** Request/grant handshake flag equivalence (plan P1b/P1c):                                      **
** original = D_FLIPFLOP clocked by the request strobe with async grant clear                    **
** FF mode  = sysclk-registered flag, set on a DETECTED request rising edge,                     **
**            synchronous dominant grant clear (the MEM_ADEC_45 conversion)                      **
**                                                                                               **
** Contract: the request strobe is generated in the sysclk domain and is at                      **
** least one sysclk cycle wide; the FF-mode flag may lag by one sysclk but                       **
** must agree with the original at every "settled" observation point (one                        **
** cycle after any request edge or grant change).                                                **
**                                                                                               **
** Self-check: a deliberately broken variant (level-set instead of edge-set,                     **
** the 9b005c2 bug class) MUST diverge - proving the tb has teeth.                               **
**                                                                                               **
** Run: make test-reqgnt                                                                         **
**                                                                                               **
** Last reviewed: 9-JUL-2026                                                                     **
** Ronny Hansen                                                                                  **
***************************************************************************************************/
`timescale 1ns / 1ps

module reqgnt_equiv_tb;

  reg sysclk = 0;
  always #10 sysclk = ~sysclk;

  reg req = 0;    // request strobe (plays REFRQ_n / DDBAPR)
  reg gnt = 0;    // grant (plays RGNT / BGNT)
  reg d_in = 1;   // flop data (s_power = 1 for MEMORY_2, s_aok for MEMORY_1)

  // --- Reference: the original D_FLIPFLOP (async grant clear) -------------
  wire ref_q, ref_qbar;
  D_FLIPFLOP #(.ACTIVE_ASYNC(1), .InvertClockEnable(0)) ref_ff (
      .clock(req),
      .d(d_in),
      .preset(1'b0),
      .q(ref_q),
      .qBar(ref_qbar),
      .reset(gnt),
      .tick(1'b1)
  );

  // --- DUT: the FF-mode conversion (copy of the MEM_ADEC_45 logic) --------
  reg dut_q = 1'b0;
  reg req_d = 1'b0;
  always @(posedge sysclk) begin
    req_d <= req;
    if (gnt) dut_q <= 1'b0;
    else if (req && !req_d) dut_q <= d_in;
  end

  // --- Teeth-prover: LEVEL set instead of edge set (the known-bad class) --
  reg bad_q = 1'b0;
  always @(posedge sysclk) begin
    if (gnt) bad_q <= 1'b0;
    else if (req) bad_q <= d_in;  // re-captures every cycle while req high
  end

  integer errors = 0;
  integer checks = 0;
  integer bad_mismatches = 0;

  // Observation: one sysclk after stimulus settles
  task check(input [127:0] what);
    begin
      @(negedge sysclk);
      @(negedge sysclk);
      checks = checks + 1;
      if (ref_q !== dut_q) begin
        errors = errors + 1;
        $display("FAIL t=%0t: %0s ref=%b dut=%b (req=%b gnt=%b d=%b)",
                 $time, what, ref_q, dut_q, req, gnt, d_in);
      end
      if (ref_q !== bad_q) bad_mismatches = bad_mismatches + 1;
    end
  endtask

  integer i;
  initial begin
    $dumpfile("reqgnt_equiv_tb.vcd");
    $dumpvars(0, reqgnt_equiv_tb);

    // basic: request sets, grant clears
    @(negedge sysclk) req = 1;  check("set on request edge");
    req = 0;                    check("hold after request drops");
    gnt = 1;                    check("grant clears");
    gnt = 0;                    check("idle after grant");

    // d=0 request must NOT set (MEMORY_1 case: d = s_aok may be low)
    d_in = 0;
    @(negedge sysclk) req = 1;  check("request with d=0 stays clear");
    req = 0;                    check("still clear");
    d_in = 1;

    // request while grant held: grant dominates
    gnt = 1;
    @(negedge sysclk) req = 1;  check("grant dominates simultaneous request");
    req = 0; gnt = 0;           check("released");

    // KEY case for the level-set bug: d changes while req stays high.
    // Edge semantics: the value at the EDGE is kept; level-set would
    // re-capture the new value.
    @(negedge sysclk) req = 1;  check("edge captures d=1");
    d_in = 0;                   check("d change under held req is ignored");
    d_in = 1; req = 0; gnt = 1; check("clear");
    gnt = 0;

    // randomized soak: request pulses 1-3 cycles wide, random grants
    for (i = 0; i < 300; i = i + 1) begin
      case ($random & 3)
        0: begin @(negedge sysclk) req = 1; repeat (1 + ($random & 1)) @(negedge sysclk); req = 0; end
        1: begin @(negedge sysclk) gnt = 1; @(negedge sysclk); gnt = 0; end
        2: d_in = $random & 1;
        3: begin @(negedge sysclk) req = 1; @(negedge sysclk) gnt = 1; @(negedge sysclk); req = 0; gnt = 0; end
      endcase
      check("soak");
    end

    $display("checks=%0d errors=%0d teeth(bad mismatches)=%0d",
             checks, errors, bad_mismatches);
    if (bad_mismatches == 0)
      $display("TB_RESULT: FAIL (teeth check: level-set variant never diverged)");
    else if (errors == 0)
      $display("TB_RESULT: PASS");
    else
      $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
