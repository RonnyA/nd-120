`timescale 1ns / 1ps

/**************************************************************************
** Testbench for F617 - NEC D flip-flop with async RB (reset) / SB (set) **
**                                                                       **
** Covers BOTH parameter builds in one binary:                           **
**   ACTIVE_ASYNC=0 (repo default): async set only, RB ignored.          **
**   ACTIVE_ASYNC=1: async set AND reset, reset priority.                **
** F617.v has no VERILATOR_SIM / FPGA_FF_MODE ifdefs - the ACTIVE_ASYNC  **
** parameter is its only behavior switch, so this tb covers every build. **
**                                                                       **
** Directed tests: async-set init, posedge load 0/1, negedge hold,       **
** D-change hold, RB pulse (ignored vs active), set-dominates-clock,     **
** both-asserted priority, release ordering, final reload.               **
**                                                                       **
** Soak: 3000-step fixed-seed LFSR stimulus (seed 16'hACE1, taps         **
** 15/13/12/10); running checksum per instance compared against          **
** constants computed by an independent Python event model               **
** (scratchpad f617_model.py, re-derived from the sensitivity-list       **
** semantics, kept outside the repo per campaign convention).            **
**                                                                       **
** KNOWN RTL-vs-NEC-datasheet divergences (tb encodes the RTL as golden, **
** reported in the campaign log, NOT silently patched):                  **
**  1. RB=0 & SB=0 "prohibition": NEC table says Q=0,QB=0; the RTL's     **
**     if-priority gives Q=0,QB=1 (reset wins).                          **
**  2. Level-sensitivity loss: with SB (or RB) STILL asserted after the  **
**     other releases, a real async pin would re-assert; the RTL only    **
**     reacts to asserting EDGES, so it holds instead. Standard Verilog  **
**     async-FF modeling limitation.                                     **
***************************************************************************/

module F617_tb;

  localparam EXPECTED_CHECKS = 50;  // 12 directed steps * 4 + 2 soak checksums

  reg D, C, RB, SB;

  wire q0, qb0;  // ACTIVE_ASYNC=0 (set only)
  wire q1, qb1;  // ACTIVE_ASYNC=1 (set + reset)

  F617 #(.ACTIVE_ASYNC(0)) dut_single (
      .H01_D (D),
      .H02_C (C),
      .H03_RB(RB),
      .H04_SB(SB),
      .N01_Q (q0),
      .N02_QB(qb0)
  );

  F617 #(.ACTIVE_ASYNC(1)) dut_dual (
      .H01_D (D),
      .H02_C (C),
      .H03_RB(RB),
      .H04_SB(SB),
      .N01_Q (q1),
      .N02_QB(qb1)
  );

  integer checks;
  integer errors;

  task check4(input [255:0] name, input eq0, input eqb0, input eq1, input eqb1);
    begin
      checks = checks + 4;
      if (q0 !== eq0) begin
        errors = errors + 1;
        $display("ERROR: %0s single.Q=%b expected %b", name, q0, eq0);
      end
      if (qb0 !== eqb0) begin
        errors = errors + 1;
        $display("ERROR: %0s single.QB=%b expected %b", name, qb0, eqb0);
      end
      if (q1 !== eq1) begin
        errors = errors + 1;
        $display("ERROR: %0s dual.Q=%b expected %b", name, q1, eq1);
      end
      if (qb1 !== eqb1) begin
        errors = errors + 1;
        $display("ERROR: %0s dual.QB=%b expected %b", name, qb1, eqb1);
      end
    end
  endtask

  // Golden soak checksums from the independent Python model (f617_model.py)
  localparam [31:0] GOLD_CHK_SINGLE = 32'h823C5266;
  localparam [31:0] GOLD_CHK_DUAL = 32'h70ED0900;

  reg [15:0] lfsr;
  reg fb;
  reg [31:0] chk_s, chk_d;
  integer i;

  initial begin
    checks = 0;
    errors = 0;

    // ---------------- Directed tests ----------------
    D  = 0;
    C  = 0;
    RB = 1;
    SB = 1;
    #5;

    // 1. Async set pulse initializes both instances
    SB = 0;
    #5;
    check4("T1 async set (SB=0)", 1'b1, 1'b0, 1'b1, 1'b0);
    SB = 1;
    #5;

    // 2. Posedge load D=0
    D = 0;
    C = 1;
    #5;
    check4("T2 load 0", 1'b0, 1'b1, 1'b0, 1'b1);
    C = 0;
    #5;

    // 3. Posedge load D=1
    D = 1;
    C = 1;
    #5;
    check4("T3 load 1", 1'b1, 1'b0, 1'b1, 1'b0);

    // 4. Negedge must hold (D driven low before the falling edge)
    D = 0;
    C = 0;
    #5;
    check4("T4 negedge hold", 1'b1, 1'b0, 1'b1, 1'b0);

    // 5. D wiggles with C low: hold
    D = 1;
    #5;
    D = 0;
    #5;
    check4("T5 D-change hold", 1'b1, 1'b0, 1'b1, 1'b0);

    // 6a. RB asserted: single ignores (Q stays 1), dual resets
    RB = 0;
    #5;
    check4("T6a RB=0", 1'b1, 1'b0, 1'b0, 1'b1);

    // 6b. RB released: both hold
    RB = 1;
    #5;
    check4("T6b RB release hold", 1'b1, 1'b0, 1'b0, 1'b1);

    // 7a. Async set again
    SB = 0;
    #5;
    check4("T7a async set", 1'b1, 1'b0, 1'b1, 1'b0);

    // 7b. Clock posedge with D=0 while SB still low: set dominates clock
    D = 0;
    C = 1;
    #5;
    check4("T7b set dominates clock", 1'b1, 1'b0, 1'b1, 1'b0);
    C  = 0;
    SB = 1;
    #5;

    // 8a. Both asserted (RB first, then SB): dual keeps reset priority
    //     (RTL divergence: NEC prohibition row says Q=0,QB=0; RTL gives 0,1)
    RB = 0;
    #5;
    SB = 0;
    #5;
    check4("T8a RB=0 & SB=0 priority", 1'b1, 1'b0, 1'b0, 1'b1);

    // 8b. Release SB then RB: edge-only sensitivity means both hold
    //     (single still set from T8a's SB edge; dual still reset)
    SB = 1;
    #5;
    RB = 1;
    #5;
    check4("T8b release ordering hold", 1'b1, 1'b0, 1'b0, 1'b1);

    // 9. Normal reload after all releases
    D = 1;
    C = 1;
    #5;
    check4("T9 reload 1", 1'b1, 1'b0, 1'b1, 1'b0);
    C = 0;
    #5;

    // ---------------- LFSR soak ----------------
    // Preamble: known state via SB pulse (matches the Python model exactly)
    D  = 0;
    C  = 0;
    RB = 1;
    SB = 1;
    #5;
    SB = 0;
    #5;
    SB = 1;
    #5;

    lfsr  = 16'hACE1;
    chk_s = 32'd0;
    chk_d = 32'd0;
    for (i = 0; i < 3000; i = i + 1) begin
      case (lfsr[1:0])
        2'd0: C = lfsr[2];
        2'd1: D = lfsr[2];
        2'd2: RB = lfsr[2];
        2'd3: SB = lfsr[2];
      endcase
      #5;
      chk_s = chk_s * 32'd5 + {30'b0, q0, qb0};
      chk_d = chk_d * 32'd5 + {30'b0, q1, qb1};
      fb    = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];
      lfsr  = {lfsr[14:0], fb};
    end

    checks = checks + 1;
    if (chk_s !== GOLD_CHK_SINGLE) begin
      errors = errors + 1;
      $display("ERROR: soak checksum single = %08h expected %08h", chk_s, GOLD_CHK_SINGLE);
    end
    checks = checks + 1;
    if (chk_d !== GOLD_CHK_DUAL) begin
      errors = errors + 1;
      $display("ERROR: soak checksum dual = %08h expected %08h", chk_d, GOLD_CHK_DUAL);
    end

    // Verdict with hard expected-count assertion
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)", errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule
