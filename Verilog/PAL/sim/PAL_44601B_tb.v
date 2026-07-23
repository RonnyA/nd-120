`timescale 1ns / 1ps

/**************************************************************************
** Testbench for PAL_44601B  (PAL16R6, CYCFSM)
** ND-120 cycle-control state counter.
**
** GOAL: validate that the 4-bit Gray-coded cycle counter CC3..CC0 and
**       the TERM output count / sequence correctly.
**
** The expected values below are derived from the intended state machine
** (Verilog/cycle_clock.md) and from Gray-code first principles, NOT by
** copying the PAL's own product-term equations. The point is to catch a
** wrong PALASM->Verilog transcription.
**
** Two structural invariants are enforced on EVERY clock (these are the
** real transcription-bug catchers, derived from first principles):
**
**   (A) Gray-code: on any registered transition whose SOURCE cycle had
**       TERM=0, the counter changes by at most ONE bit (0 = wait/hold,
**       1 = normal Gray step). A change of 2+ bits is a FAIL.
**
**   (B) Terminate/reset: whenever a cycle has TERM=1, the NEXT cycle must
**       be state a (0000) with TERM=0. (Every next-state product term in
**       the design is gated by TERM_n, so an asserted TERM forces all
**       registers to 0 on the following edge.)
**
** Per-scenario the number of clocks from state a until TERM asserts is
** checked against the documented timing hierarchy:
**   50 ns SHORT  -> TERM at cycle 1  (state path a -> b)
**   75 ns b path -> TERM at cycle 2  (a -> b -> c)
**  100 ns c path -> TERM at cycle 3  (a -> b -> c -> d)
**  BRK  (f)      -> TERM at cycle 6  (a -> b -> c -> d -> e -> f -> g)
**  SLOW (g)      -> TERM at cycle 7  (a -> b -> c -> d -> e -> f -> g -> h)
**  WAIT (d hold) -> holds in state d while WAIT1 asserted, then advances.
**
** Read output convention: OE_n is held 0 so outputs are enabled and
**   CCx  = ~CCx_n , TERM = ~TERM_n , CX = ~CX_n.
***************************************************************************/

module PAL_44601B_tb;

  // Clock / output enable
  reg CK;
  reg OE_n;

  // PAL inputs (I0..I7, B0, B1)
  reg DLY1_n;
  reg DLY0_n;
  reg CSDELAY0;
  reg WAIT1;
  reg WAIT2;
  reg CGNTCACT_n;
  reg HIT;
  reg BRK_n;
  reg SLOW_n;
  reg SHORT_n;

  // PAL outputs (all active-low)
  wire CX_n;
  wire TERM_n;
  wire CC0_n;
  wire CC1_n;
  wire CC2_n;
  wire CC3_n;

  // Bookkeeping
  integer errors;
  reg     checking;      // enable invariant checks (off during forced reset)
  reg [3:0] prev_cc;
  reg       prev_term;
  reg [3:0] cur_cc;
  reg       cur_term;
  integer   term_cycle;
  reg       term_found;
  integer   nbits;

  // Unit Under Test
  PAL_44601B uut (
    .CK        (CK),
    .OE_n      (OE_n),
    .DLY1_n    (DLY1_n),
    .DLY0_n    (DLY0_n),
    .CSDELAY0  (CSDELAY0),
    .WAIT1     (WAIT1),
    .WAIT2     (WAIT2),
    .CGNTCACT_n(CGNTCACT_n),
    .HIT       (HIT),
    .BRK_n     (BRK_n),
    .SLOW_n    (SLOW_n),
    .SHORT_n   (SHORT_n),
    .CX_n      (CX_n),
    .TERM_n    (TERM_n),
    .CC0_n     (CC0_n),
    .CC1_n     (CC1_n),
    .CC2_n     (CC2_n),
    .CC3_n     (CC3_n)
  );

  // Clock: 20 ns period
  initial begin
    CK = 0;
    forever #10 CK = ~CK;
  end

  // Human-readable state name (documented Gray encoding)
  function [15:0] sname(input [3:0] s);
    begin
      case (s)
        4'b0000: sname = "a";
        4'b0001: sname = "b";
        4'b0011: sname = "c";
        4'b0010: sname = "d";
        4'b0110: sname = "e";
        4'b0111: sname = "f";
        4'b0101: sname = "g";
        4'b0100: sname = "h";
        4'b1000: sname = "p";
        4'b1001: sname = "o";
        4'b1010: sname = "m";
        4'b1011: sname = "n";
        4'b1100: sname = "i";
        4'b1101: sname = "j";
        4'b1110: sname = "l";
        4'b1111: sname = "k";
        default: sname = "?";
      endcase
    end
  endfunction

  function integer bitcount(input [3:0] v);
    begin
      bitcount = v[0] + v[1] + v[2] + v[3];
    end
  endfunction

  // Advance one clock, sample outputs, run the structural invariants.
  task tick;
    begin
      @(posedge CK); #1;
      cur_cc   = {~CC3_n, ~CC2_n, ~CC1_n, ~CC0_n};
      cur_term = ~TERM_n;

      // CX must always be 1 in the fast version (CX_n = 0)
      if (CX_n !== 1'b0) begin
        errors = errors + 1;
        $display("FAIL [cx]  : CX_n=%b (expected 0) at t=%0t", CX_n, $time);
      end

      $display("  t=%0t  CC=%b (%0s)  TERM=%b", $time, cur_cc, sname(cur_cc), cur_term);

      if (checking) begin
        if (prev_term === 1'b1) begin
          // (B) terminate/reset invariant
          if (cur_cc !== 4'b0000 || cur_term !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL [rst] : after TERM=1 got CC=%b(%0s) TERM=%b, expected 0000(a)/TERM=0 at t=%0t",
                     cur_cc, sname(cur_cc), cur_term, $time);
          end
        end else begin
          // (A) Gray-code invariant on non-terminating transitions
          nbits = bitcount(prev_cc ^ cur_cc);
          if (nbits > 1) begin
            errors = errors + 1;
            $display("FAIL [gray]: multi-bit change %b(%0s) -> %b(%0s), %0d bits (source TERM=0) at t=%0t",
                     prev_cc, sname(prev_cc), cur_cc, sname(cur_cc), nbits, $time);
          end
        end
      end

      prev_cc   = cur_cc;
      prev_term = cur_term;
    end
  endtask

  // Force the registers to state a (0000, TERM=0) then release. The PAL has
  // no reset pin; force/release is a testbench-only construct and does not
  // modify the DUT.
  task reset_to_a;
    begin
      checking = 0;
      force uut.TERM_reg = 1'b0;
      force uut.CC0_reg  = 1'b0;
      force uut.CC1_reg  = 1'b0;
      force uut.CC2_reg  = 1'b0;
      force uut.CC3_reg  = 1'b0;
      @(posedge CK); #1;
      release uut.TERM_reg;
      release uut.CC0_reg;
      release uut.CC1_reg;
      release uut.CC2_reg;
      release uut.CC3_reg;
      cur_cc    = {~CC3_n, ~CC2_n, ~CC1_n, ~CC0_n};
      cur_term  = ~TERM_n;
      prev_cc   = cur_cc;
      prev_term = cur_term;
      checking  = 1;
      if (cur_cc !== 4'b0000 || cur_term !== 1'b0) begin
        errors = errors + 1;
        $display("FAIL [init]: reset did not reach state a, CC=%b TERM=%b", cur_cc, cur_term);
      end
    end
  endtask

  // Benign default inputs: SHORT/SLOW/BRK inactive, no wait, no cache hit.
  task default_inputs;
    begin
      SHORT_n    = 1'b1;  // SHORT inactive
      SLOW_n     = 1'b1;  // SLOW inactive
      BRK_n      = 1'b1;  // no break
      HIT        = 1'b0;  // no cache hit
      DLY0_n     = 1'b1;
      DLY1_n     = 1'b1;
      CSDELAY0   = 1'b0;
      WAIT1      = 1'b0;
      WAIT2      = 1'b0;
      CGNTCACT_n = 1'b1;  // CGNTCACT = 0
    end
  endtask

  // Tick until TERM asserts (or limit); record the cycle index.
  task count_to_term(input integer limit);
    integer c;
    begin
      term_found = 0;
      c = 0;
      while (!term_found && c < limit) begin
        tick;
        c = c + 1;
        if (cur_term === 1'b1) term_found = 1;
      end
      term_cycle = c;
    end
  endtask

  task expect_term(input integer expc, input [255:0] nm);
    begin
      if (term_found && term_cycle == expc)
        $display("PASS [%0s]: TERM asserted at cycle %0d (expected %0d)", nm, term_cycle, expc);
      else begin
        errors = errors + 1;
        $display("FAIL [%0s]: TERM at cycle %0d (found=%b), expected %0d", nm, term_cycle, term_found, expc);
      end
    end
  endtask

  initial begin
    errors   = 0;
    checking = 0;
    OE_n     = 1'b0;  // outputs enabled for the whole run
    default_inputs;

    $display("======================================================");
    $display("PAL_44601B cycle-control state counter self-check");
    $display("======================================================");

    // ---------------------------------------------------------------
    // Scenario 1: 50 ns SHORT cycle. Early terminate at state a.
    //   SHORT & DLY0_n & CSDELAY0_n  -> TERM at cycle 1 (path a -> b)
    // ---------------------------------------------------------------
    $display("\n-- Scenario 1: 50 ns SHORT cycle (early term at a) --");
    reset_to_a;
    SHORT_n = 1'b0; DLY0_n = 1'b1; CSDELAY0 = 1'b0; BRK_n = 1'b1;
    count_to_term(12);
    expect_term(1, "50ns SHORT");
    tick; // must land back in state a
    default_inputs;

    // ---------------------------------------------------------------
    // Scenario 2: 75 ns cycle. Terminate at state b.
    //   SHORT & BRK_n & DLY1_n, DLY0_n=0 (skip 50 ns) -> TERM at cycle 2
    // ---------------------------------------------------------------
    $display("\n-- Scenario 2: 75 ns cycle (term at b) --");
    reset_to_a;
    SHORT_n = 1'b0; BRK_n = 1'b1; DLY1_n = 1'b1; DLY0_n = 1'b0; CSDELAY0 = 1'b0;
    count_to_term(12);
    expect_term(2, "75ns b");
    tick;
    default_inputs;

    // ---------------------------------------------------------------
    // Scenario 3: 100 ns cycle. Terminate at state c.
    //   SHORT & BRK_n, DLY1_n=0 (skip 75 ns) -> TERM at cycle 3
    // ---------------------------------------------------------------
    $display("\n-- Scenario 3: 100 ns cycle (term at c) --");
    reset_to_a;
    SHORT_n = 1'b0; BRK_n = 1'b1; DLY1_n = 1'b0; DLY0_n = 1'b0; CSDELAY0 = 1'b0;
    HIT = 1'b0; CGNTCACT_n = 1'b1;
    count_to_term(12);
    expect_term(3, "100ns c");
    tick;
    default_inputs;

    // ---------------------------------------------------------------
    // Scenario 4: BRK cycle. Walk a->b->c->d->e->f, terminate at f.
    //   BRK asserted (BRK_n=0), SHORT/HIT inactive -> TERM at cycle 6
    // ---------------------------------------------------------------
    $display("\n-- Scenario 4: BRK cycle (term at f) --");
    reset_to_a;
    SHORT_n = 1'b1; HIT = 1'b0; BRK_n = 1'b0; SLOW_n = 1'b1;
    DLY0_n = 1'b0; DLY1_n = 1'b0; CSDELAY0 = 1'b0;
    WAIT1 = 1'b0; WAIT2 = 1'b0; CGNTCACT_n = 1'b1;
    count_to_term(12);
    expect_term(6, "BRK f");
    tick;
    default_inputs;

    // ---------------------------------------------------------------
    // Scenario 5: SLOW cycle. Walk a->b->c->d->e->f->g, terminate at g.
    //   SLOW asserted (SLOW_n=0), BRK/SHORT/HIT inactive -> TERM at cycle 7
    // ---------------------------------------------------------------
    $display("\n-- Scenario 5: SLOW cycle (term at g) --");
    reset_to_a;
    SLOW_n = 1'b0; BRK_n = 1'b1; SHORT_n = 1'b1; HIT = 1'b0;
    DLY0_n = 1'b0; DLY1_n = 1'b0; CSDELAY0 = 1'b0;
    WAIT1 = 1'b0; WAIT2 = 1'b0; CGNTCACT_n = 1'b1;
    count_to_term(14);
    expect_term(7, "SLOW g");
    tick;
    default_inputs;

    // ---------------------------------------------------------------
    // Scenario 6: WAIT scenario. Reach state d and hold while WAIT1
    //   asserted (bus not granted, no break), then release and advance.
    // ---------------------------------------------------------------
    $display("\n-- Scenario 6: WAIT hold in state d, then advance --");
    reset_to_a;
    SHORT_n = 1'b1; HIT = 1'b0; BRK_n = 1'b1; SLOW_n = 1'b1;
    DLY0_n = 1'b0; DLY1_n = 1'b0; CSDELAY0 = 1'b0;
    WAIT1 = 1'b1; WAIT2 = 1'b0; CGNTCACT_n = 1'b1;  // waiting for bus
    // a -> b -> c -> d
    tick; tick; tick;
    if (cur_cc === 4'b0010)
      $display("PASS [WAIT]: reached state d (0010) at t=%0t", $time);
    else begin
      errors = errors + 1;
      $display("FAIL [WAIT]: expected state d (0010), got %b (%0s)", cur_cc, sname(cur_cc));
    end
    // hold in d for 3 more clocks while WAIT1 stays asserted
    tick; tick; tick;
    if (cur_cc === 4'b0010 && cur_term === 1'b0)
      $display("PASS [WAIT]: held in state d while WAIT1 asserted");
    else begin
      errors = errors + 1;
      $display("FAIL [WAIT]: did not hold in state d, got %b (%0s) TERM=%b", cur_cc, sname(cur_cc), cur_term);
    end
    // release wait -> should advance to state e (0110)
    WAIT1 = 1'b0;
    tick;
    if (cur_cc === 4'b0110)
      $display("PASS [WAIT]: advanced d -> e (0110) after WAIT1 released");
    else begin
      errors = errors + 1;
      $display("FAIL [WAIT]: expected e (0110) after release, got %b (%0s)", cur_cc, sname(cur_cc));
    end
    default_inputs;

    // ---------------------------------------------------------------
    // Scenario 7: slowest path. With no early-terminate condition
    //   (SHORT/HIT/BRK/SLOW all inactive, waits released) the FSM walks
    //   the FULL 16-state Gray sequence a..p - the LCS/RWCS/UART/XSLOW
    //   class, ~435 ns per DesignDocuments/Other/CPU-Timing.md - and
    //   terminates at the maximum-length state p (1000, unconditional).
    //   This exercises the upper Gray states (i..p) that scenarios 1-6
    //   never reach. Validate: (1) the counter actually reaches state p
    //   (full walk, upper half reachable), and (2) the longest cycle
    //   still terminates (no deadlock in the upper states). The Gray and
    //   terminate/reset invariants run every tick as usual; the registered
    //   TERM lands one edge after the terminating state, so we check
    //   structural reach+terminate rather than a hardcoded cycle index.
    // ---------------------------------------------------------------
    $display("\n-- Scenario 7: full a..p slow walk (reach p, then terminate) --");
    reset_to_a;
    default_inputs;
    begin : slow_walk
      integer c;
      reg seen_p;
      reg saw_term;
      seen_p   = 1'b0;
      saw_term = 1'b0;
      for (c = 0; c < 20; c = c + 1) begin
        tick;
        if (cur_cc === 4'b1000) seen_p   = 1'b1;  // reached state p
        if (cur_term === 1'b1)  saw_term = 1'b1;  // longest cycle terminated
      end
      if (seen_p)
        $display("PASS [p-walk]: FSM reached state p (1000) on the slow path");
      else begin
        errors = errors + 1;
        $display("FAIL [p-walk]: FSM never reached state p (1000) - upper Gray states unreachable?");
      end
      if (saw_term)
        $display("PASS [p-walk]: longest cycle terminated (no deadlock in upper states)");
      else begin
        errors = errors + 1;
        $display("FAIL [p-walk]: longest cycle never asserted TERM - possible deadlock");
      end
    end
    default_inputs;

    // ---------------------------------------------------------------
    // Summary
    // ---------------------------------------------------------------
    $display("\n======================================================");
    if (errors == 0)
      $display("RESULT: PASS - all cycle-control checks passed (0 errors)");
    else
      $display("RESULT: FAIL - %0d error(s) detected", errors);
    $display("======================================================");

    if (errors != 0) $fatal(1, "PAL_44601B testbench failed with %0d error(s)", errors);
    $finish;
  end

  // Global watchdog
  initial begin
    #100000;
    $display("FAIL [timeout]: watchdog fired");
    $fatal(1, "timeout");
  end

endmodule
