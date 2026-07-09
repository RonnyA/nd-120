/**************************************************************************
** ND120 CPU - unit test                                                 **
** CYC_36 clock-enable alignment (FPGA_FF_MODE).                         **
**                                                                       **
** P2 foundation (docs/plan-fix-unconstrained-clocks.md): CYC_36 emits   **
** one-sysclk enable pulses CLK_EN/UCLK_EN/MCLK_EN/MACLK_EN/ALUCLK_EN.   **
** THE property (P2's "enable/clock alignment is THE risk"):             **
**                                                                       **
**   the enable is high in cycle N  <=>  the corresponding phase-        **
**   accurate clock RISES at the posedge ending cycle N                  **
**                                                                       **
** checked EVERY sysclk cycle while the cycle-control FSM free-runs      **
** microcycles. Teeth: each enable must pulse >= MIN_PULSES times or the **
** tb FAILS - an idle FSM would make the property vacuously true.        **
**                                                                       **
** Compile with -DFPGA_FF_MODE (the Makefile does).                      **
** Run: make test-cycen   (CPU-BOARD-3202/circuit/sim)                   **
***************************************************************************/
`timescale 1ns / 1ps

module CYC_36_enables_tb;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg mr_n = 0;

  // Benign "normal execution" tie-offs; a few are wiggled below to move
  // the FSM through SHORT/HIT/delay variations.
  reg acond_n = 1, brk_n = 1, cgntcact_n = 0;  // CGNTCACT_n=0: CPU granted+active (FSM free-runs)
  reg hit = 0, short_n = 1, slow_n = 1;
  reg mreq_n = 1, iorq_n = 1;
  reg [1:0] csdelay = 2'b00;

  wire aluclk, clk, maclk, mclk, uclk, wrfstb;
  wire clk_en, uclk_en, mclk_en, maclk_en, aluclk_en;

  CYC_36 dut (
      .sysclk(sysclk),
      .sys_rst_n(mr_n),
      .OSC(sysclk),

      .ACOND_n(acond_n),
      .BRK_n(brk_n),
      .CGNTCACT_n(cgntcact_n),
      .CSALUI7(1'b0),
      .CSALUI8(1'b0),
      .CSALUM0(1'b0),
      .CSALUM1(1'b0),
      .CSDELAY_1_0(csdelay),
      .CSDLY(1'b0),
      .CSECOND(1'b0),
      .CSLOOP(1'b0),
      .FORM_n(1'b1),
      .HIT(hit),
      .IORQ_n(iorq_n),
      .LBA0(1'b0),
      .LBA1(1'b0),
      .LBA3(1'b0),
      .LSHADOW(1'b0),
      .LUA12(1'b0),
      .MREQ_n(mreq_n),
      .MR_n(mr_n),
      .PD1(1'b0),
      .PD4(1'b0),
      .RRF_n(1'b1),
      .RT_n(1'b1),
      .RWCS_n(1'b1),
      .SHORT_n(short_n),
      .SLOW_n(slow_n),
      .TRAP_n(1'b1),
      .VEX(1'b0),

      .ALUCLK(aluclk),
      .CLK(clk),
      .MACLK(maclk),
      .MCLK(mclk),
      .UCLK(uclk),
      .WRFSTB(wrfstb),
      .CLK_EN(clk_en),
      .UCLK_EN(uclk_en),
      .MCLK_EN(mclk_en),
      .MACLK_EN(maclk_en),
      .ALUCLK_EN(aluclk_en),
      .CYD(),
      .CC_3_1_n(),
      .CC0_n(),
      .TERM_n(),
      .MAP_n(),
      .CX_n(),
      .EORF_n(),
      .ETRAP_n(),
      .LCS_n()
  );

  integer errors = 0;
  integer checks = 0;
  integer n_clk = 0, n_uclk = 0, n_mclk = 0, n_maclk = 0, n_aluclk = 0;
  localparam MIN_PULSES = 10;

  // e_*: the enable value each capturing POSEDGE actually saw (NBA sample
  // at the posedge = pre-edge value, i.e. exactly what a converted
  // `posedge sysclk + if (EN)` flop samples). p_*: the pa-clock level
  // before that edge (stable between posedges, sampled at negedge).
  reg p_clk, p_uclk, p_mclk, p_maclk, p_aluclk;
  reg e_clk, e_uclk, e_mclk, e_maclk, e_aluclk;
  reg checking = 0;

  always @(posedge sysclk) begin
    e_clk    <= clk_en;
    e_uclk   <= uclk_en;
    e_mclk   <= mclk_en;
    e_maclk  <= maclk_en;
    e_aluclk <= aluclk_en;
  end

  task check_one(input rise, input en_prev, input [63:0] name);
    begin
      checks = checks + 1;
      if (rise !== en_prev) begin
        errors = errors + 1;
        $display("FAIL t=%0t %0s: rise=%b but enable(prev cycle)=%b",
                 $time, name, rise, en_prev);
      end
    end
  endtask

  always @(negedge sysclk) begin
    if (checking) begin
      check_one(clk    & ~p_clk,    e_clk,    "CLK");
      check_one(uclk   & ~p_uclk,   e_uclk,   "UCLK");
      check_one(mclk   & ~p_mclk,   e_mclk,   "MCLK");
      check_one(maclk  & ~p_maclk,  e_maclk,  "MACLK");
      check_one(aluclk & ~p_aluclk, e_aluclk, "ALUCLK");
      if (clk    & ~p_clk)    n_clk    = n_clk + 1;
      if (uclk   & ~p_uclk)   n_uclk   = n_uclk + 1;
      if (mclk   & ~p_mclk)   n_mclk   = n_mclk + 1;
      if (maclk  & ~p_maclk)  n_maclk  = n_maclk + 1;
      if (aluclk & ~p_aluclk) n_aluclk = n_aluclk + 1;
    end
    p_clk    <= clk;
    p_uclk   <= uclk;
    p_mclk   <= mclk;
    p_maclk  <= maclk;
    p_aluclk <= aluclk;
  end

  integer i;
  initial begin
    $dumpfile("CYC_36_enables_tb.vcd");
    $dumpvars(0, CYC_36_enables_tb);

    // PAL_44601B has no reset pin: on the FPGA its state regs come up 0
    // (GSR) and Verilator is 2-state, but 4-state iverilog leaves them X
    // forever (X-locked FSM). Reproduce the FPGA power-up state here.
    dut.PAL_44601_UCYCFSM.TERM_reg = 0;
    dut.PAL_44601_UCYCFSM.CC0_reg  = 0;
    dut.PAL_44601_UCYCFSM.CC1_reg  = 0;
    dut.PAL_44601_UCYCFSM.CC2_reg  = 0;
    dut.PAL_44601_UCYCFSM.CC3_reg  = 0;

    // reset, then free-run
    repeat (8) @(negedge sysclk);
    mr_n = 1;
    repeat (4) @(negedge sysclk);
    checking = 1;

    // plain free-run
    repeat (400) @(negedge sysclk);

    // wiggle the cycle-shaping inputs through realistic combinations
    for (i = 0; i < 40; i = i + 1) begin
      hit     = i[0];
      short_n = ~i[1];
      slow_n  = ~i[2];
      csdelay = i[4:3];
      repeat (25) @(negedge sysclk);
    end
    hit = 0; short_n = 1; slow_n = 1; csdelay = 0;

    // memory-request cycles
    for (i = 0; i < 20; i = i + 1) begin
      mreq_n = 0;
      repeat (15) @(negedge sysclk);
      mreq_n = 1;
      repeat (10) @(negedge sysclk);
    end

    $display("checks=%0d errors=%0d pulses: clk=%0d uclk=%0d mclk=%0d maclk=%0d aluclk=%0d",
             checks, errors, n_clk, n_uclk, n_mclk, n_maclk, n_aluclk);
    if (n_clk < MIN_PULSES || n_uclk < MIN_PULSES || n_mclk < MIN_PULSES ||
        n_maclk < MIN_PULSES || n_aluclk < MIN_PULSES) begin
      errors = errors + 1;
      $display("FAIL: an enable pulsed fewer than %0d times - vacuous run", MIN_PULSES);
    end
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $finish;
  end

  initial begin
    #400000;
    $display("FAIL [timeout]: watchdog fired");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
