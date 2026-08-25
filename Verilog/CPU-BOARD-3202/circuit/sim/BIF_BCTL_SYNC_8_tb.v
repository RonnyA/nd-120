/**************************************************************************
** ND120 CPU - unit test                                                 **
** BIF_BCTL_SYNC_8: BIF bus-signal synchronizer (sheet 8) - two          **
** AM29C821 10-bit registers (3D/4D) clocked on posedge OSC building     **
** the 25/50/75ns delay taps of the incoming ND-bus handshake lines,     **
** with PD3 (3D) / PD1 (4D) as combinational output kills (OE_n; FPGA    **
** convention drives 0, not Z, when disabled).                           **
**                                                                       **
** INDEPENDENT golden model re-derived from the register wiring, not     **
** transliterated: two 10-bit state words g3/g4 updated on the same      **
** posedge; the 4D data word is built from the PRE-EDGE GATED outputs    **
** (y3 = PD3 ? 0 : g3, y4 = PD1 ? 0 : g4), which reproduces the real     **
** simultaneous-clocking semantics including the two 4D self-feedback    **
** taps (BINPUT75 re-registers BINPUT50, BDRY75 re-registers BDRY50 -    **
** both are chip-4D outputs fed back into chip-4D inputs) and the fact   **
** that an asserted PD3 poisons the NEXT 50ns captures with the gated    **
** zeros (active-low bus: gated 0 reads as ASSERTED downstream). That    **
** PD interaction is checked deliberately, not avoided.                  **
**                                                                       **
** BUILD MODES: this netlist contains NO ifdef branches - AM29C821 is    **
** instantiated with default USE_SYSCLK=0 (posedge CK) exactly as on     **
** the board, and neither FPGA_FF_MODE nor USE_TRANSPARENT_LATCHES       **
** appears in the DUT or the chip model. ONE build is the complete       **
** meaningful set.                                                       **
**                                                                       **
**  1. Power-on state (registers init 0, all outputs read asserted).     **
**  2. Per-input delay-tap walk: each of the 10 bus inputs pulsed low    **
**     for one clock, its 25/50/75 taps checked to move one stage per    **
**     edge (BLOCK/CACT 25-only, IBDAP/IBREQ/IBPERR/ISEMRQ/REFRQ/        **
**     CLEAR(MR) 50, IBDRY 25+50+75, IBINPUT 50+75).                     **
**  3. Hold/no-clock: input churn with the clock frozen leaves every    **
**     output untouched.                                                 **
**  4. PD gating: PD3/PD1 comb kill with the clock frozen, then the      **
**     PD3-poisons-next-capture sequence with the clock running.         **
**  5. 4000-step fixed-seed xorshift32 soak: random inputs (PD1/PD3      **
**     asserted 1/8 of the time), all 13 outputs compared after every    **
**     posedge.                                                          **
**                                                                       **
** Every check event compares all 13 outputs; the total check count is   **
** asserted exactly (a silent partial run FAILS).                        **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** Run: make test-bifsync   (CPU-BOARD-3202/circuit/sim)                 **
**                                                                       **
** 01-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module BIF_BCTL_SYNC_8_tb;

  // ---------------------------------------------------------------- clock
  // Manually pulsed: every capture edge is explicit (no free-running clock)
  // so the hold/no-clock phase is airtight.
  reg osc = 0;

  // ---------------------------------------------------------------- inputs
  reg block_n = 1, cact_n = 1, clear_n = 1, ibdap_n = 1, ibdry_n = 1;
  reg ibinput_n = 1, ibperr_n = 1, ibreq_n = 1, isemrq_n = 1, refrq_n = 1;
  reg pd1 = 0, pd3 = 0;

  // ---------------------------------------------------------------- outputs
  wire bdap50_n, bdry25_n, bdry50_n, bdry75_n, binput50_n, binput75_n;
  wire block25_n, bperr50_n, breq50_n, cact25_n, mr_n, refrq50_n, semrq50_n;

  BIF_BCTL_SYNC_8 dut (
      .sysclk    (osc),
      .BLOCK_n   (block_n),
      .CACT_n    (cact_n),
      .CLEAR_n   (clear_n),
      .IBDAP_n   (ibdap_n),
      .IBDRY_n   (ibdry_n),
      .IBINPUT_n (ibinput_n),
      .IBPERR_n  (ibperr_n),
      .IBREQ_n   (ibreq_n),
      .ISEMRQ_n  (isemrq_n),
      .OSC       (osc),
      .PD1       (pd1),
      .PD3       (pd3),
      .REFRQ_n   (refrq_n),

      .BDAP50_n  (bdap50_n),
      .BDRY25_n  (bdry25_n),
      .BDRY50_n  (bdry50_n),
      .BDRY75_n  (bdry75_n),
      .BINPUT50_n(binput50_n),
      .BINPUT75_n(binput75_n),
      .BLOCK25_n (block25_n),
      .BPERR50_n (bperr50_n),
      .BREQ50_n  (breq50_n),
      .CACT25_n  (cact25_n),
      .MR_n      (mr_n),
      .REFRQ50_n (refrq50_n),
      .SEMRQ50_n (semrq50_n)
  );

  // ------------------------------------------------------ independent model
  // g3/g4 mirror the two register words; y3/y4 are the gated (visible)
  // buses. Bit order re-derived from the sheet's concatenations:
  //   g3 = {BLOCK,IBDAP,IBREQ,CACT,IBDRY,IBPERR,IBINPUT,ISEMRQ,REFRQ,CLEAR}
  //   g4 = {y4[3],y3[8],y3[7],y4[5],y3[5],y3[4],y3[3],y3[2],y3[1],y3[0]}
  reg [9:0] g3 = 10'b0;
  reg [9:0] g4 = 10'b0;
  wire [9:0] y3 = pd3 ? 10'b0 : g3;
  wire [9:0] y4 = pd1 ? 10'b0 : g4;

  task golden_edge;  // one posedge OSC in the model (pre-edge y3/y4 sampled)
    reg [9:0] oy3, oy4;
    begin
      oy3 = y3;
      oy4 = y4;
      g3  = {block_n, ibdap_n, ibreq_n, cact_n, ibdry_n,
             ibperr_n, ibinput_n, isemrq_n, refrq_n, clear_n};
      g4  = {oy4[3], oy3[8], oy3[7], oy4[5], oy3[5],
             oy3[4], oy3[3], oy3[2], oy3[1], oy3[0]};
    end
  endtask

  task pulse_clk;  // one explicit capture edge, DUT and model together
    begin
      #5 osc = 1;
      golden_edge;
      #5 osc = 0;
    end
  endtask

  // ---------------------------------------------------------------- checking
  integer checks = 0;
  integer errors = 0;

  task chk1(input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("MISMATCH t=%0t %0s got=%b exp=%b", $time, name, got, exp);
      end
    end
  endtask

  task check_all;  // 13 output compares vs the model's gated buses
    begin
      chk1("BLOCK25_n", block25_n, y3[9]);
      chk1("CACT25_n", cact25_n, y3[6]);
      chk1("BDRY25_n", bdry25_n, y3[5]);
      chk1("BINPUT75_n", binput75_n, y4[9]);
      chk1("BDAP50_n", bdap50_n, y4[8]);
      chk1("BREQ50_n", breq50_n, y4[7]);
      chk1("BDRY75_n", bdry75_n, y4[6]);
      chk1("BDRY50_n", bdry50_n, y4[5]);
      chk1("BPERR50_n", bperr50_n, y4[4]);
      chk1("BINPUT50_n", binput50_n, y4[3]);
      chk1("SEMRQ50_n", semrq50_n, y4[2]);
      chk1("REFRQ50_n", refrq50_n, y4[1]);
      chk1("MR_n", mr_n, y4[0]);
    end
  endtask

  // Directed helper: pulse one input low for exactly one captured clock,
  // then flush 4 clocks, checking after every edge (5 check events).
  task walk_input(input integer which);
    integer k;
    begin
      set_input(which, 1'b0);
      pulse_clk;
      #1 check_all;
      set_input(which, 1'b1);
      for (k = 0; k < 4; k = k + 1) begin
        pulse_clk;
        #1 check_all;
      end
    end
  endtask

  task set_input(input integer which, input v);
    begin
      case (which)
        0: clear_n   = v;
        1: refrq_n   = v;
        2: isemrq_n  = v;
        3: ibinput_n = v;
        4: ibperr_n  = v;
        5: ibdry_n   = v;
        6: cact_n    = v;
        7: ibreq_n   = v;
        8: ibdap_n   = v;
        9: block_n   = v;
      endcase
    end
  endtask

  // ---------------------------------------------------------------- soak rng
  reg [31:0] rnd = 32'h5EED0008;
  task next_rnd;
    begin
      rnd = rnd ^ (rnd << 13);
      rnd = rnd ^ (rnd >> 17);
      rnd = rnd ^ (rnd << 5);
    end
  endtask

  // Expected totals: 4 power-on + 10*5 walk + 6 hold + 8 PD + 4000 soak
  // check events, 13 compares each.
  localparam EXP_CHECKS = (4 + 50 + 6 + 8 + 4000) * 13;

  integer i;
  initial begin
    // ---- 1. power-on: registers are 0 (all active-low taps ASSERTED)
    #1 check_all;
    pulse_clk;  // all inputs idle-high: pipeline fills with 1s
    #1 check_all;
    pulse_clk;
    #1 check_all;
    pulse_clk;
    #1 check_all;

    // ---- 2. per-input delay-tap walks (single-cycle low pulse each)
    for (i = 0; i < 10; i = i + 1) walk_input(i);

    // ---- 3. hold: clock frozen, inputs churn, outputs must not move
    ibdry_n = 0;
    #3 check_all;
    ibdry_n = 1;
    cact_n  = 0;
    #3 check_all;
    cact_n  = 1;
    clear_n = 0;
    #3 check_all;
    clear_n   = 1;
    block_n   = 0;
    ibinput_n = 0;
    #3 check_all;
    block_n   = 1;
    ibinput_n = 1;
    isemrq_n  = 0;
    refrq_n   = 0;
    #3 check_all;
    isemrq_n = 1;
    refrq_n  = 1;
    #3 check_all;

    // ---- 4. PD gating
    // Load a non-trivial pattern first (IBDRY low pulse mid-pipeline).
    ibdry_n = 0;
    pulse_clk;
    ibdry_n = 1;
    // comb kill with clock frozen: PD3 zeros the 25 taps, PD1 the 50/75.
    pd3 = 1;
    #3 check_all;
    pd1 = 1;
    #3 check_all;
    pd3 = 0;
    #3 check_all;
    pd1 = 0;
    #3 check_all;
    // PD3 held across an edge poisons the next 50ns captures with zeros.
    pd3 = 1;
    pulse_clk;
    #1 check_all;
    pd3 = 0;
    pulse_clk;
    #1 check_all;
    pulse_clk;
    #1 check_all;
    pulse_clk;
    #1 check_all;

    // ---- 5. randomized soak, compared after every edge
    for (i = 0; i < 4000; i = i + 1) begin
      next_rnd;
      block_n   = rnd[0];
      ibdap_n   = rnd[1];
      ibreq_n   = rnd[2];
      cact_n    = rnd[3];
      ibdry_n   = rnd[4];
      ibperr_n  = rnd[5];
      ibinput_n = rnd[6];
      isemrq_n  = rnd[7];
      refrq_n   = rnd[8];
      clear_n   = rnd[9];
      pd3       = (rnd[12:10] == 3'b000);
      pd1       = (rnd[15:13] == 3'b000);
      pulse_clk;
      #1 check_all;
    end

    // ---------------------------------------------------------- verdict
    if (checks != EXP_CHECKS) begin
      $display("CHECK-COUNT MISMATCH: ran %0d, expected %0d", checks, EXP_CHECKS);
      errors = errors + 1;
    end
    if (errors == 0) $display("TB_RESULT: PASS (%0d checks)", checks);
    else $display("TB_RESULT: FAIL (%0d errors in %0d checks)", errors, checks);
    $finish;
  end

endmodule
