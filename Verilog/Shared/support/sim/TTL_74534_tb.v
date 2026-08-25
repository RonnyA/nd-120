/****************************************************************************
** TTL_74534 - functional testbench, both USE_SYSCLK modes                **
**                                                                        **
** COVERAGE: exhaustive over all 256 D values in mode 0 (USE_SYSCLK=0,    **
** posedge CK, matches the real chip's clocking) - Q_n checked against    **
** ~D after the capture edge for every value. Mode 2 (USE_SYSCLK=2,       **
** sysclk-sampled rising-edge capture of CK) is cross-checked against     **
** mode 0 on a smaller directed sweep, allowing for its one-sysclk        **
** capture lag (same pattern as TTL_74273/TTL_74374 in this directory).   **
**                                                                        **
** RTL note: regQ_n is declared `reg [7:0] regQ_n;` with NO initial       **
** value, so it reads X in simulation until the first capture edge -     **
** this differs from TTL_74374's Q_reg, which does have `= 8'b0`. This    **
** testbench always clocks at least once before checking Q_n, precisely  **
** so it never samples that undefined initial state.                     **
**                                                                        **
** Output enable: OE_n=1 must force Q_n to all-zero even when the stored  **
** (inverted) value would be all-ones - proven here by storing D=0 (so    **
** ~D=FF is latched) and then disabling and requiring 00, not FF.         **
**                                                                        **
** Run: cd Verilog/Shared/support/sim && iverilog -g2012 -o tb.vvp \      **
**   TTL_74534_tb.v ../TTL_74534.v && vvp tb.vvp                          **
**                                                                        **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module TTL_74534_tb;

  reg        sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg  [7:0] D = 8'h00;
  reg        CK = 0;
  reg        OE_n = 0;
  wire [7:0] Qn0, Qn2;

  integer errors = 0;
  integer checks = 0;

  TTL_74534 #(.USE_SYSCLK(0)) DUT0 (
      .sysclk(sysclk), .CK(CK), .OE_n(OE_n), .D(D), .Q_n(Qn0)
  );

  TTL_74534 #(.USE_SYSCLK(2)) DUT2 (
      .sysclk(sysclk), .CK(CK), .OE_n(OE_n), .D(D), .Q_n(Qn2)
  );

  // Mode 0 pulses on CK directly (posedge CK), immediate capture.
  task pulse_mode0(input [7:0] dval);
    begin
      D = dval;
      CK = 0;
      #2;
      CK = 1;
      #2;
      checks = checks + 1;
      if (Qn0 !== ~dval) begin
        errors = errors + 1;
        if (errors < 10) $display("FAIL mode0 capture: D=%02h Q_n0=%02h expected %02h", dval, Qn0, ~dval);
      end
      CK = 0;
      #2;
    end
  endtask

  // Cross-mode pulse driven relative to sysclk, both DUTs share CK/D.
  task pulse_both(input [7:0] dval);
    begin
      D = dval;
      @(negedge sysclk);
      CK = 1;
      #1;
      checks = checks + 1;
      if (Qn0 !== ~dval) begin
        errors = errors + 1;
        if (errors < 10) $display("FAIL mode0 (shared clk) capture: D=%02h Q_n0=%02h", dval, Qn0);
      end
      @(posedge sysclk);
      #1;
      checks = checks + 1;
      if (Qn2 !== ~dval) begin
        errors = errors + 1;
        if (errors < 10) $display("FAIL mode2 capture: D=%02h Q_n2=%02h expected %02h", dval, Qn2, ~dval);
      end
      @(negedge sysclk);
      CK = 0;
    end
  endtask

  integer i;

  initial begin
    $dumpfile("TTL_74534_tb.vcd");
    $dumpvars(0, TTL_74534_tb);

    // ---- short documentation sequence (mode0, direct CK pulses) -----------
    pulse_mode0(8'h55);
    pulse_mode0(8'hAA);
    pulse_mode0(8'h00);
    pulse_mode0(8'hFF);
    // cross-mode agreement, a few values
    pulse_both(8'h3C);
    pulse_both(8'hC3);
    $dumpoff;

    // ---- exhaustive: all 256 D values, mode 0 ------------------------------
    $display("=====================================================");
    $display(" TTL_74534 exhaustive capture sweep, mode 0 (256 D values)");
    $display("=====================================================");
    for (i = 0; i < 256; i = i + 1) begin
      pulse_mode0(i[7:0]);
    end

    // ---- directed cross-mode sweep: mode 0 vs mode 2 agree, allowing for
    //      mode 2's one-sysclk capture lag -----------------------------------
    $display(" TTL_74534 mode0 vs mode2 cross-check (32 values)");
    for (i = 0; i < 32; i = i + 1) begin
      pulse_both({i[4:0], i[2:0]});
    end

    // ---- named check: OE_n forces 0 even when ~D would be all-ones --------
    pulse_mode0(8'h00);       // stores D=0 -> Q_n = FF
    checks = checks + 1;
    if (Qn0 !== 8'hFF) begin
      errors = errors + 1;
      $display("FAIL OE_setup: Qn0=%02h expected FF before disabling", Qn0);
    end
    OE_n = 1;
    #1;
    checks = checks + 1;
    if (Qn0 !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL OE_MASK_MODE0: Qn0=%02h expected 00 with OE_n=1 (stored ~D=FF)", Qn0);
    end
    OE_n = 0;
    #1;
    checks = checks + 1;
    if (Qn0 !== 8'hFF) begin
      errors = errors + 1;
      $display("FAIL OE_UNMASK_MODE0: Qn0=%02h expected FF after OE_n back to 0", Qn0);
    end

    // same check for mode2
    OE_n = 0;
    pulse_both(8'h00);        // stores D=0 -> Q_n2 = FF
    checks = checks + 1;
    if (Qn2 !== 8'hFF) begin
      errors = errors + 1;
      $display("FAIL OE_setup mode2: Qn2=%02h expected FF before disabling", Qn2);
    end
    OE_n = 1;
    #1;
    checks = checks + 1;
    if (Qn2 !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL OE_MASK_MODE2: Qn2=%02h expected 00 with OE_n=1 (stored ~D=FF)", Qn2);
    end
    OE_n = 0;
    #1;
    checks = checks + 1;
    if (Qn2 !== 8'hFF) begin
      errors = errors + 1;
      $display("FAIL OE_UNMASK_MODE2: Qn2=%02h expected FF after OE_n back to 0", Qn2);
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
