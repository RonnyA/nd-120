/****************************************************************************
** TESTBENCH: control-store READBACK over a FULL RWCS microcycle            **
**            (the TRA CS / TRA 17 path, cycle-timing half)                 **
**                                                                         **
** WHY THIS EXISTS (08-AUG-2026)                                           **
**                                                                         **
** CPU_CS_RWCS_tb.v (next to this file) proves the STATIC half of the       **
** control-store readback: RWCS command decode, the ECSL read window, the   **
** transceiver slice select, and writable-control-store storage/readback.   **
** All of that passes, yet on the full machine TRA CS (150017) still        **
** returns 000000 and SINTRAN III refuses to start with                     **
**   "Micro-code not loaded. CPU revision too low !!"                       **
** (its test is PH-P2-RESTART.NPL:1049-1055: X := 100 ; *150017 ; IF A<<13).**
**                                                                         **
** This bench covers the half CPU_CS_RWCS_tb.v cannot see: TIMING across a  **
** whole RWCS microcycle. The requirement it pins down is not a signal      **
** shape but the end-to-end contract the rest of the CPU depends on:        **
**                                                                         **
**   The control-store word addressed by COMM,ADCS must still be on the     **
**   IDB at the TERM edge that ends the RWCS microcycle.                    **
**                                                                         **
** That deadline is not arbitrary. The destination register (A) lives in    **
** the CGA working register file, which is written by ALUCLK, and           **
**   CYC_36.v:365   assign s_aluclk = ~(s_term_n | s_lcs);                  **
** so ALUCLK fires ONLY at TERM. The path from the CPU's IDB input to that  **
** register file is entirely combinational (CGA_ALU FIDBI_15_0 ->           **
** CGA_ALU_OUTMUX -> F_15_0 -> CGA_ALU_SHIFT RB_15_0 -> CGA_WRF); the DBR   **
** holding register in CGA_ALU_DBR captures CD_15_0 (memory data), not the  **
** control store. There is therefore nowhere for the word to wait: if it is **
** not on the IDB when TERM arrives, the A register captures whatever is.   **
**                                                                         **
** HOW IT IS DRIVEN                                                        **
**                                                                         **
** Everything is the real RTL - PAL_44601B walks the cycle states, and      **
** PAL_44307C derives MACLK from them, exactly as CYC_36.v wires it         **
** (MACLK = ~(TERM_n & MACLK_n)). The bench only stands in for the CGA,     **
** and only in the one way the CGA behaves here: EWCA_n asserted means the  **
** MIC drives the WCA register (the ADCS-latched control-store address)     **
** onto MA, otherwise MA carries the next microaddress. That mirrors        **
** PAL_44305D's own comment on EWCA_n - "ENABLE WCA REG. IN MIC ONTO MA" -  **
** and matches what the full machine does in the waveform.                  **
**                                                                         **
** Checks (all self-verifying, verdict on the last line):                   **
**   1. The RWCS cycle really is the long one: it terminates on             **
**      PAL_44601B's dedicated "UART, LCS, RWCS CYCLES" term (CC3 high,     **
**      CC2/CC1/CC0 low) and not on any short/slow term.                    **
**   2. EWCA and ECSL overlap at least once - PAL_44305D's ECSL term        **
**      commented "HOLD OVERLAP WITH EWCA_n" - so the addressed word does   **
**      reach the IDB at all.                                              **
**   3. The addressed word is on the IDB for that whole overlap.            **
**   4. THE DEADLINE: the addressed word is still on the IDB at the TERM    **
**      edge that ends the cycle - i.e. when ALUCLK captures it into A.     **
**   5. The address presented to the WCS does not wander off the ADCS       **
**      address while ECSL is still holding the read window open.          **
**   6. A second address (different stored word) gives the same result, so  **
**      a pass cannot come from a stuck/zero bus.                          **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <n> errors                    **
**                                                                         **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module CPU_CS_RWCS_CYCLE_tb;

  integer errors = 0;

  task ck;
    input         cond;
    input [1023:0] what;
    begin
      if (!cond) begin
        $display("FAIL: %0s", what);
        errors = errors + 1;
      end else begin
        $display("[ ok ] %0s", what);
      end
    end
  endtask

  // ------------------------------------------------------------------
  // Clocks
  // ------------------------------------------------------------------
  reg sysclk = 1'b0;
  always #1 sysclk = ~sysclk;

  reg sys_rst_n = 1'b0;

  // OSC drives PAL_44601B's CK. One cycle state per OSC period.
  reg osc = 1'b0;

  // ------------------------------------------------------------------
  // Cycle state machine - the real PAL
  // ------------------------------------------------------------------
  reg  rwcs_n = 1'b1;   // 0 = a RWCS (read/write control store) microword
  reg  lcs_n  = 1'b1;
  reg  wcs_n  = 1'b1;   // 1 = READ direction
  reg  brk_n  = 1'b1;
  reg  form_n = 1'b1;
  reg  fetch  = 1'b0;
  reg  trap_n = 1'b1;
  reg  vex    = 1'b0;
  reg  wca_n  = 1'b1;
  reg  pd1    = 1'b0;

  // Cycle-length selectors. A RWCS microword asks for neither SHORT nor
  // SLOW - measured on the full machine, and the only way the state walk
  // reaches PAL_44601B's "UART, LCS, RWCS CYCLES" terminate term.
  reg  short_n = 1'b1;
  reg  slow_n  = 1'b1;

  reg  dly0_n = 1'b1;
  reg  dly1_n = 1'b1;
  reg  csdelay0 = 1'b0;
  reg  wait1 = 1'b0;
  reg  wait2 = 1'b0;
  reg  cgntcact_n = 1'b1;
  reg  hit = 1'b0;

  wire cx_n, term_n, cc0_n, cc1_n, cc2_n, cc3_n;

  PAL_44601B UCYCFSM (
      .CK        (osc),
      .OE_n      (1'b0),
      .DLY1_n    (dly1_n),
      .DLY0_n    (dly0_n),
      .CSDELAY0  (csdelay0),
      .WAIT1     (wait1),
      .WAIT2     (wait2),
      .CGNTCACT_n(cgntcact_n),
      .HIT       (hit),
      .BRK_n     (brk_n),
      .SLOW_n    (slow_n),
      .SHORT_n   (short_n),
      .CX_n      (cx_n),
      .TERM_n    (term_n),
      .CC0_n     (cc0_n),
      .CC1_n     (cc1_n),
      .CC2_n     (cc2_n),
      .CC3_n     (cc3_n)
  );

  // ------------------------------------------------------------------
  // Clock generation PAL - MACLK / MCLK / WRFSTB
  // ------------------------------------------------------------------
  wire mclk_n, maclk_n, wrfstb, cyd, eorf_n, uclk, etrap_n, map_n;

  PAL_44307C UCYCLK (
      .TERM_n (term_n),
      .CC0_n  (cc0_n),
      .CC1_n  (cc1_n),
      .CC2_n  (cc2_n),
      .CC3_n  (cc3_n),
      .FORM_n (form_n),
      .BRK_n  (brk_n),
      .RWCS_n (rwcs_n),
      .TRAP_n (trap_n),
      .VEX    (vex),
      .MCLK_n (mclk_n),
      .MACLK_n(maclk_n),
      .WRFSTB (wrfstb),
      .CYD    (cyd),
      .EORF_n (eorf_n),
      .UCLK   (uclk),
      .ETRAP_n(etrap_n),
      .MAP_n  (map_n)
  );

  // Exactly how CYC_36.v combines them (CYC_36.v:223, :268-269, :365).
  wire maclk  = ~(term_n & maclk_n);
  wire mclk   = ~(term_n & mclk_n);
  wire aluclk = ~(term_n | ~lcs_n);
  wire clk    = ~term_n;

  // ------------------------------------------------------------------
  // Control store - the real sheet-16 module
  // ------------------------------------------------------------------
  // The bench stands in for the CGA on ONE signal only: MA (CSA_12_0).
  // EWCA_n low = the MIC drives the WCA register (the ADCS-latched control
  // store address) onto MA; otherwise MA carries the next microaddress.
  localparam [12:0] CS_ADDR_A   = 13'o0100;  // what ADCS latched (SINTRAN uses X=100)
  localparam [12:0] CS_ADDR_B   = 13'o0777;  // second address, proves it is not stuck
  localparam [12:0] NEXT_UADDR  = 13'o0677;  // the microaddress the sequencer moves to

  reg [12:0] cs_addr = CS_ADDR_A;
  wire ewca_n;
  wire [12:0] csa_12_0 = ewca_n ? NEXT_UADDR : cs_addr;

  reg  [15:0] idb_in = 16'h0000;
  reg  [ 1:0] rf_1_0 = 2'b00;   // word select: slice 0 = CSBITS[15:0]

  wire [63:0] csbits;
  wire [15:0] idb_out;
  wire [12:0] lua_12_0;

  CPU_CS_16 CS (
      .sysclk     (sysclk),
      .sys_rst_n  (sys_rst_n),
      .CLK        (clk),
      .MACLK      (maclk),
      .IDB_15_0_IN(idb_in),
      .RF_1_0     (rf_1_0),
      .CC_3_1_n   ({cc3_n, cc2_n, cc1_n}),
      .CSA_12_0   (csa_12_0),
      .CSCA_9_0   (10'd0),
      .PD1        (pd1),
      .FETCH      (fetch),
      .BLCS_n     (1'b1),
      .BRK_n      (brk_n),
      .FORM_n     (form_n),
      .LCS_n      (lcs_n),
      .RWCS_n     (rwcs_n),
      .TERM_n     (term_n),
      .WCA_n      (wca_n),
      .WCS_n      (wcs_n),
      .EWCA_n     (ewca_n),
      .CSBITS     (csbits),
      .IDB_15_0_OUT(idb_out),
      .LUA_12_0   (lua_12_0)
  );

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------
  task osc_tick;
    begin
      osc = 1'b0; #4;
      osc = 1'b1; #4;
    end
  endtask

  // PAL16R6 has no reset pin - on the real board the registers come up from
  // power-on. Put them in a defined state so the walk is repeatable.
  task cyc_init;
    begin
      force UCYCFSM.TERM_reg = 1'b0;
      force UCYCFSM.CC0_reg  = 1'b0;
      force UCYCFSM.CC1_reg  = 1'b0;
      force UCYCFSM.CC2_reg  = 1'b0;
      force UCYCFSM.CC3_reg  = 1'b0;
      osc_tick;
      release UCYCFSM.TERM_reg;
      release UCYCFSM.CC0_reg;
      release UCYCFSM.CC1_reg;
      release UCYCFSM.CC2_reg;
      release UCYCFSM.CC3_reg;
    end
  endtask

  // Walk to the end of whatever cycle is in progress, so the next osc tick
  // starts a fresh one. RWCS_n is latched with the new microword at TERM,
  // exactly as the DGA drives it.
  task run_to_term;
    integer guard;
    begin
      guard = 0;
      while (term_n && guard < 40) begin
        osc_tick;
        guard = guard + 1;
      end
    end
  endtask

  // Force the writable control store to a known word at a known address,
  // through the same wires the LCS microcode load uses.
  task wcs_write;
    input [12:0] addr;
    input [63:0] word;
    integer k;
    begin
      // Park the state machine, then drive a write cycle by hand.
      force CS.ACAL.s_lua_9_0    = addr[9:0];
      force CS.ACAL.s_q_chip30h_7_0[0] = addr[12];
      force CS.ACAL.s_q_chip30h_7_0[1] = addr[11];
      force CS.ACAL.s_q_chip30h_7_0[2] = addr[10];
      force CS.WCS.CSBITS_63_0   = word;
      force CS.WCS.ELOW_n        = 1'b0;
      force CS.WCS.WW0_n         = 1'b0;
      force CS.WCS.WW1_n         = 1'b0;
      force CS.WCS.WW2_n         = 1'b0;
      force CS.WCS.WW3_n         = 1'b0;
      for (k = 0; k < 4; k = k + 1) @(posedge sysclk);
      release CS.WCS.WW0_n;
      release CS.WCS.WW1_n;
      release CS.WCS.WW2_n;
      release CS.WCS.WW3_n;
      release CS.WCS.ELOW_n;
      release CS.WCS.CSBITS_63_0;
      release CS.ACAL.s_lua_9_0;
      release CS.ACAL.s_q_chip30h_7_0[0];
      release CS.ACAL.s_q_chip30h_7_0[1];
      release CS.ACAL.s_q_chip30h_7_0[2];
      for (k = 0; k < 4; k = k + 1) @(posedge sysclk);
    end
  endtask

  // ------------------------------------------------------------------
  // The RWCS cycle, instrumented
  // ------------------------------------------------------------------
  integer overlap_states;      // states where EWCA and ECSL are both on
  integer overlap_good;        // ... of those, how many had the right word on IDB
  integer hold_states;         // states where ECSL is on but EWCA is off
  integer hold_addr_ok;        // ... of those, how many still addressed CS_ADDR
  integer states_run;
  reg     saw_term;
  reg [15:0] idb_at_term;      // IDB sampled at the TERM edge - the deadline
  reg [15:0] idb_pre_edge;     // IDB one state before that edge (setup instant)
  reg [3:0]  term_state;

  task run_rwcs_cycle;
    input [12:0] addr;
    input [15:0] expect_word;
    integer guard;
    begin
      cs_addr        = addr;
      overlap_states = 0;
      overlap_good   = 0;
      hold_states    = 0;
      hold_addr_ok   = 0;
      states_run     = 0;
      saw_term       = 1'b0;
      idb_at_term    = 16'hxxxx;
      idb_pre_edge   = 16'hxxxx;
      term_state     = 4'hx;

      // Finish whatever cycle is running, then assert RWCS for the next one -
      // the DGA latches the new microword's commands at TERM.
      run_to_term;
      rwcs_n = 1'b0;   // the RWCS microword is now executing

      for (guard = 0; guard < 40 && !saw_term; guard = guard + 1) begin
        // The state the cycle is IN before this tick - PAL_44601B clears the
        // CC counter on the same edge that asserts TERM, so the terminating
        // state has to be sampled before the tick, not after.
        term_state = {~cc3_n, ~cc2_n, ~cc1_n, ~cc0_n};
        // ALUCLK is edge-triggered, so what it writes to A is the IDB as it
        // stood at the setup instant BEFORE the terminating edge - not after,
        // by which point PAL_44305D has already dropped ECSL (both of its
        // terms are qualified with TERM_n).
        idb_pre_edge = idb_out;
        osc_tick;
        states_run = states_run + 1;
`ifdef RWCS_TRACE
        $display("    state=%b TERM_n=%b EWCA_n=%b ECSL_n=%b MACLK=%b LUA=%0o IDB=%04h",
                 {~cc3_n, ~cc2_n, ~cc1_n, ~cc0_n}, term_n, ewca_n,
                 CS.CTL.ECSL_n, maclk, lua_12_0, idb_out);
`endif

        if (!term_n) begin
          // TERM: ALUCLK fires here and the A register captures the IDB.
          saw_term    = 1'b1;
          idb_at_term = idb_pre_edge;
        end else begin
          if (!CS.CTL.ECSL_n && !ewca_n) begin
            overlap_states = overlap_states + 1;
            if (idb_out === expect_word) overlap_good = overlap_good + 1;
          end
          if (!CS.CTL.ECSL_n && ewca_n) begin
            hold_states = hold_states + 1;
            if (lua_12_0 === addr) hold_addr_ok = hold_addr_ok + 1;
          end
        end
      end

      rwcs_n = 1'b1;
    end
  endtask

  // ------------------------------------------------------------------
  // Test sequence
  // ------------------------------------------------------------------
  localparam [63:0] WORD_A = 64'h0000_0000_0000_C401;  // low slice 0142001
  localparam [63:0] WORD_B = 64'h0000_0000_0000_5A5A;

  integer k;

  initial begin
    $dumpfile("CPU_CS_RWCS_CYCLE_tb.vcd");
    $dumpvars(0, CPU_CS_RWCS_CYCLE_tb);

    sys_rst_n = 1'b0;
    for (k = 0; k < 8; k = k + 1) @(posedge sysclk);
    sys_rst_n = 1'b1;
    for (k = 0; k < 8; k = k + 1) @(posedge sysclk);

    // Idle the cycle machine a few states so it is in a defined place.
    cyc_init;
    for (k = 0; k < 6; k = k + 1) osc_tick;

    $display("");
    $display("== load the writable control store ==");
    wcs_write(CS_ADDR_A, WORD_A);
    wcs_write(CS_ADDR_B, WORD_B);
    $display("[info] WCS[%0o] = %04h, WCS[%0o] = %04h",
             CS_ADDR_A, WORD_A[15:0], CS_ADDR_B, WORD_B[15:0]);

    // ----------------------------------------------------------------
    $display("");
    $display("== RWCS read cycle at control-store address %0o ==", CS_ADDR_A);
    run_rwcs_cycle(CS_ADDR_A, WORD_A[15:0]);

    $display("[info] cycle ran %0d states, terminated in state CC=%b",
             states_run, term_state);
    $display("[info] EWCA/ECSL overlap states = %0d (word correct in %0d)",
             overlap_states, overlap_good);
    $display("[info] ECSL-hold states after EWCA off = %0d (address still %0o in %0d)",
             hold_states, CS_ADDR_A, hold_addr_ok);
    $display("[info] IDB at the TERM edge = %04h (want %04h)",
             idb_at_term, WORD_A[15:0]);

    // 1. It is the long cycle, terminating on the RWCS term.
    ck(states_run > 8,
       "RWCS microcycle is the long one (more than 8 cycle states)");
    ck(term_state === 4'b1000,
       "RWCS cycle terminates on PAL_44601B's CC3-only 'UART, LCS, RWCS CYCLES' term");

    // 2. The designed EWCA/ECSL overlap exists.
    ck(overlap_states > 0,
       "PAL_44305D's 'HOLD OVERLAP WITH EWCA_n' window exists (EWCA and ECSL both on)");

    // 3. The addressed word is on the IDB throughout that overlap.
    ck(overlap_states > 0 && overlap_good == overlap_states,
       "addressed control-store word is on the IDB for the whole EWCA/ECSL overlap");

    // 5. CORRECTED 08-AUG-2026. This check used to demand that the read
    //    ADDRESS stay parked on the ADCS address while ECSL held the window
    //    open. That was wrong, and it was wrong in a way that hid the real
    //    fault for a day: the design DELIBERATELY moves the micro-address on
    //    when EWCA drops, so that the microaddress to be EXECUTED can be
    //    presented (PAL_44307C's MCLK comment says exactly this). What holds
    //    the DATA is the pair of 74PCT373 latches on sheet 20 (chips 8C/9C),
    //    which close on the falling edge of ECSL~.
    //
    //    So the property to assert is the opposite of the old one: the address
    //    MUST move, and the data must survive anyway. Asserting that the
    //    address moves is what stops this test passing for the wrong reason -
    //    if LUA happened to stay put, the deadline check below would pass even
    //    with the capture deleted.
    ck(hold_states > 0,
       "ECSL keeps the read window open after EWCA drops (PAL_44305D 'READ CONTROL STORE HOLD')");
    ck(hold_states > 0 && hold_addr_ok == 0,
       "the read address DOES move off the ADCS address once EWCA drops (so the data below is held by the sheet-20 capture, not by a stationary address)");

    // 4. THE DEADLINE - what ALUCLK actually captures into A.
    ck(idb_at_term === WORD_A[15:0],
       "addressed control-store word is still on the IDB at the TERM edge (what ALUCLK writes to A)");

    // ----------------------------------------------------------------
    $display("");
    $display("== RWCS read cycle at control-store address %0o ==", CS_ADDR_B);
    for (k = 0; k < 4; k = k + 1) osc_tick;
    run_rwcs_cycle(CS_ADDR_B, WORD_B[15:0]);

    $display("[info] EWCA/ECSL overlap states = %0d (word correct in %0d)",
             overlap_states, overlap_good);
    $display("[info] IDB at the TERM edge = %04h (want %04h)",
             idb_at_term, WORD_B[15:0]);

    ck(overlap_states > 0 && overlap_good == overlap_states,
       "second address: word on the IDB for the whole EWCA/ECSL overlap");
    ck(idb_at_term === WORD_B[15:0],
       "second address: word still on the IDB at the TERM edge (not a stuck bus)");

    // ----------------------------------------------------------------
    $display("");
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

endmodule
