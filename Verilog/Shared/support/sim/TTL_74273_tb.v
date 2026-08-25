/****************************************************************************
** TTL_74273 - functional testbench, both USE_SYSCLK modes                **
**                                                                        **
** COVERAGE: all 256 D values captured through mode 0 (USE_SYSCLK=0,      **
** posedge CLK) and mode 2 (USE_SYSCLK=2, sysclk-sampled rising-edge      **
** capture of CLK), cross-checked against each other and against the     **
** expected value, plus named checks for hold-between-edges and clear.   **
**                                                                        **
** RTL-VS-DATASHEET DISAGREEMENT (record and assert the RTL, not the     **
** datasheet): the real SN74LS273 CLR is ASYNCHRONOUS - it forces Q to 0 **
** the instant MR goes low, with no clock edge needed. This RTL's        **
** mode 0 (USE_SYSCLK=0) clears ONLY on the next rising edge of CLK -    **
** it is a SYNCHRONOUS clear in this model. Mode 2 (USE_SYSCLK=2)        **
** samples CLR_n on every posedge sysclk regardless of CLK, so it clears **
** within one sysclk period even with CLK sitting idle - closer to async **
** behaviour than mode 0, but still not truly asynchronous (it is        **
** registered on sysclk, not combinational). Both are tested exactly as  **
** the RTL behaves; neither is asserted to match the datasheet's MR.     **
**                                                                        **
** Run: cd Verilog/Shared/support/sim && iverilog -g2012 -o tb.vvp \      **
**   TTL_74273_tb.v ../TTL_74273.v && vvp tb.vvp                         **
**                                                                        **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module TTL_74273_tb;

  reg        sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg        CLK = 0;
  reg        CLR_n = 1;
  reg  [7:0] D = 8'h00;
  wire [7:0] Q0, Q2;

  integer errors = 0;
  integer checks = 0;

  TTL_74273 #(.USE_SYSCLK(0)) DUT0 (
      .sysclk(sysclk), .CLK(CLK), .CLR_n(CLR_n), .D(D), .Q(Q0)
  );

  TTL_74273 #(.USE_SYSCLK(2)) DUT2 (
      .sysclk(sysclk), .CLK(CLK), .CLR_n(CLR_n), .D(D), .Q(Q2)
  );

  // Pulse CLK 0->1 at a sysclk negedge (mode0 captures instantly on that
  // edge), then let one full sysclk pass so mode2's sysclk-registered
  // detector catches up, then drop CLK back to 0 ready for the next pulse.
  task capture_and_check(input [7:0] dval);
    begin
      D = dval;
      @(negedge sysclk);
      CLK = 1;
      #1;
      checks = checks + 1;
      if (Q0 !== dval) begin
        errors = errors + 1;
        if (errors < 10) $display("FAIL mode0 capture: D=%02h Q0=%02h", dval, Q0);
      end
      @(posedge sysclk);
      #1;
      checks = checks + 1;
      if (Q2 !== dval) begin
        errors = errors + 1;
        if (errors < 10) $display("FAIL mode2 capture: D=%02h Q2=%02h", dval, Q2);
      end
      @(negedge sysclk);
      CLK = 0;
    end
  endtask

  integer i;

  initial begin
    $dumpfile("TTL_74273_tb.vcd");
    $dumpvars(0, TTL_74273_tb);

    // ---- short documentation sequence (readable in a waveform viewer) ----
    CLR_n = 1;
    capture_and_check(8'h55);
    capture_and_check(8'hAA);
    capture_and_check(8'h0F);
    @(negedge sysclk);
    CLR_n = 0;                 // async-looking clear request
    @(posedge sysclk); #1;     // mode2 clears within this sysclk
    @(negedge sysclk);
    CLK = 1; #1;                // mode0 needs this CLK edge to clear
    @(negedge sysclk);
    CLK = 0;
    CLR_n = 1;
    capture_and_check(8'hC3);
    $dumpoff;

    // ---- exhaustive: all 256 D values, both modes -------------------------
    $display("=====================================================");
    $display(" TTL_74273 exhaustive capture sweep (256 D values x 2 modes)");
    $display("=====================================================");
    CLR_n = 1;
    for (i = 0; i < 256; i = i + 1) begin
      capture_and_check(i[7:0]);
    end

    // ---- hold-between-edges: D changing without a CLK edge must not move Q
    D = 8'h3C;
    @(negedge sysclk);
    CLK = 1; #1;
    @(posedge sysclk); #1;
    checks = checks + 1;
    if (Q0 !== 8'h3C || Q2 !== 8'h3C) begin
      errors = errors + 1;
      $display("FAIL setup for hold test: Q0=%02h Q2=%02h expected 3C", Q0, Q2);
    end
    @(negedge sysclk);
    CLK = 0;
    D = 8'h99;                 // D changes, no CLK edge follows
    repeat (4) @(posedge sysclk);
    checks = checks + 1;
    if (Q0 !== 8'h3C) begin
      errors = errors + 1;
      $display("FAIL HOLD_MODE0: Q0=%02h changed without a CLK edge (D=%02h)", Q0, D);
    end
    checks = checks + 1;
    if (Q2 !== 8'h3C) begin
      errors = errors + 1;
      $display("FAIL HOLD_MODE2: Q2=%02h changed without a CLK edge (D=%02h)", Q2, D);
    end

    // ---- named check: mode0 clear is SYNCHRONOUS (needs a CLK edge) -------
    D = 8'hE7;
    @(negedge sysclk);
    CLK = 1; #1;
    @(posedge sysclk); #1;
    @(negedge sysclk);
    CLK = 0;
    checks = checks + 1;
    if (Q0 !== 8'hE7) begin
      errors = errors + 1;
      $display("FAIL setup for sync-clear test: Q0=%02h expected E7", Q0);
    end
    CLR_n = 0;                 // clear request asserted, CLK held low
    repeat (3) @(posedge sysclk);   // several sysclks pass, no CLK edge
    checks = checks + 1;
    if (Q0 !== 8'hE7) begin
      errors = errors + 1;
      $display("FAIL MODE0_CLEAR_NOT_ASYNC: Q0=%02h moved without a CLK edge, or RTL became async", Q0);
    end
    @(negedge sysclk);
    CLK = 1; #1;                // the CLK edge that actually clears mode0
    checks = checks + 1;
    if (Q0 !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL MODE0_CLEAR_ON_EDGE: Q0=%02h expected 00 after CLK edge with CLR_n low", Q0);
    end
    @(negedge sysclk);
    CLK = 0;
    CLR_n = 1;

    // ---- named check: mode2 clear lands within one sysclk, no CLK edge ---
    D = 8'hB4;
    @(negedge sysclk);
    CLK = 1; #1;
    @(posedge sysclk); #1;
    @(negedge sysclk);
    CLK = 0;
    checks = checks + 1;
    if (Q2 !== 8'hB4) begin
      errors = errors + 1;
      $display("FAIL setup for mode2-clear test: Q2=%02h expected B4", Q2);
    end
    CLR_n = 0;                 // CLK stays low - no CLK edge at all
    @(posedge sysclk); #1;
    checks = checks + 1;
    if (Q2 !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL MODE2_CLEAR_WITHIN_ONE_SYSCLK: Q2=%02h expected 00 with no CLK edge", Q2);
    end
    CLR_n = 1;

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

  initial begin
    #200000;
    $display("FAIL [timeout]: watchdog fired");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire
