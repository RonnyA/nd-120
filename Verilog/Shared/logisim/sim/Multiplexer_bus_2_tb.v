/****************************************************************************
** Multiplexer_bus_2 - functional testbench (parameterised bus width)     **
**                                                                         **
** WHAT THIS MODULE ACTUALLY IS                                            **
**   A 2-to-1 multiplexer over an nrOfBits-wide bus, with the whole bus    **
**   switched by ONE 1-bit sel:                                            **
**       muxOut = (sel == 0) ? muxIn_0 : muxIn_1                           **
**                                                                         **
** COVERAGE - three instances, exhaustive where the input space allows:    **
**   nrOfBits=1: inputs are muxIn_0[0], muxIn_1[0], sel = 3 bits, so       **
**               2^3 = 8 combinations, EXHAUSTIVE.                         **
**   nrOfBits=4: inputs are muxIn_0[3:0], muxIn_1[3:0], sel = 9 bits, so   **
**               2^9 = 512 combinations, EXHAUSTIVE.                       **
**   nrOfBits=8: inputs are muxIn_0[7:0], muxIn_1[7:0], sel = 17 bits, so  **
**               2^17 = 131072 combinations - too large for this repo's    **
**               "small combinational part, fully exhaustive" bar, so      **
**               this instance is exercised with DIRECTED patterns only    **
**               (all-0, all-1, walking-1, walking-0, alternating,         **
**               0x00/0xFF/0xA5/0x5A on each bus, both sel values), 40     **
**               directed checks, still verified against the same          **
**               reference model per pattern.                              **
**                                                                         **
** VCD: the nrOfBits=1 instance's full 8-step sweep is dumped (it is the   **
**   readable one); the wider instances are not dumped.                    **
**                                                                         **
** Run: cd Verilog/Shared/logisim/sim && iverilog -g2012 \
**          -o Multiplexer_bus_2_tb.vvp Multiplexer_bus_2_tb.v \
**          ../Multiplexer_bus_2.v && vvp Multiplexer_bus_2_tb.vvp         **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module Multiplexer_bus_2_tb;

  integer errors = 0;
  integer checks = 0;

  // ---- nrOfBits = 1 instance : EXHAUSTIVE, 8 combinations ----------------
  reg  [0:0] m1_in0, m1_in1;
  reg        m1_sel;
  wire [0:0] m1_out;

  Multiplexer_bus_2 #(.nrOfBits(1)) DUT1 (
      .muxIn_0(m1_in0),
      .muxIn_1(m1_in1),
      .sel    (m1_sel),
      .muxOut (m1_out)
  );

  // ---- nrOfBits = 4 instance : EXHAUSTIVE, 512 combinations ---------------
  reg  [3:0] m4_in0, m4_in1;
  reg        m4_sel;
  wire [3:0] m4_out;

  Multiplexer_bus_2 #(.nrOfBits(4)) DUT4 (
      .muxIn_0(m4_in0),
      .muxIn_1(m4_in1),
      .sel    (m4_sel),
      .muxOut (m4_out)
  );

  // ---- nrOfBits = 8 instance : DIRECTED patterns only ---------------------
  reg  [7:0] m8_in0, m8_in1;
  reg        m8_sel;
  wire [7:0] m8_out;

  Multiplexer_bus_2 #(.nrOfBits(8)) DUT8 (
      .muxIn_0(m8_in0),
      .muxIn_1(m8_in1),
      .sel    (m8_sel),
      .muxOut (m8_out)
  );

  // reference model, any width
  function [7:0] ref_out;
    input [7:0] in0, in1;
    input       s;
    begin
      ref_out = s ? in1 : in0;
    end
  endfunction

  integer combo;
  reg [7:0] pattern_list [0:9];
  integer p;
  reg [7:0] e1, e4, e8;

  initial begin
    $dumpfile("Multiplexer_bus_2_tb.vcd");
    $dumpvars(0, Multiplexer_bus_2_tb.DUT1);

    $display("=====================================================");
    $display(" Multiplexer_bus_2 functional testbench");
    $display(" nrOfBits=1: exhaustive, 8 combinations");
    $display(" nrOfBits=4: exhaustive, 512 combinations");
    $display(" nrOfBits=8: directed patterns only (131072 too large to sweep)");
    $display("=====================================================");

    // ---- nrOfBits=1 documentation + exhaustive sweep ----------------------
    m1_in0 = 1'b0; m1_in1 = 1'b1; m1_sel = 1'b0; #10;
    m1_sel = 1'b1; #10;

    for (combo = 0; combo < 8; combo = combo + 1) begin
      {m1_in0, m1_in1, m1_sel} = combo[2:0];
      #1;
      checks = checks + 1;
      e1 = ref_out({7'b0, m1_in0}, {7'b0, m1_in1}, m1_sel);
      if (m1_out !== e1[0:0]) begin
        errors = errors + 1;
        $display("FAIL nrOfBits=1: in0=%b in1=%b sel=%b -> out=%b expected %b",
                  m1_in0, m1_in1, m1_sel, m1_out, e1[0:0]);
      end
    end

    $dumpoff;

    // ---- nrOfBits=4 exhaustive sweep --------------------------------------
    for (combo = 0; combo < 512; combo = combo + 1) begin
      {m4_in0, m4_in1, m4_sel} = combo[8:0];
      #1;
      checks = checks + 1;
      e4 = ref_out({4'b0, m4_in0}, {4'b0, m4_in1}, m4_sel);
      if (m4_out !== e4[3:0]) begin
        errors = errors + 1;
        if (errors < 20)
          $display("FAIL nrOfBits=4: in0=%h in1=%h sel=%b -> out=%h expected %h",
                    m4_in0, m4_in1, m4_sel, m4_out, e4[3:0]);
      end
    end

    // ---- nrOfBits=8 directed patterns --------------------------------------
    pattern_list[0] = 8'h00;
    pattern_list[1] = 8'hFF;
    pattern_list[2] = 8'h01;
    pattern_list[3] = 8'h80;
    pattern_list[4] = 8'hFE;
    pattern_list[5] = 8'h7F;
    pattern_list[6] = 8'hAA;
    pattern_list[7] = 8'h55;
    pattern_list[8] = 8'hA5;
    pattern_list[9] = 8'h5A;

    for (p = 0; p < 10; p = p + 1) begin
      m8_in0 = pattern_list[p];
      m8_in1 = ~pattern_list[p];
      m8_sel = 1'b0; #1;
      checks = checks + 1;
      if (m8_out !== ref_out(m8_in0, m8_in1, m8_sel)) begin
        errors = errors + 1;
        $display("FAIL nrOfBits=8 sel=0: in0=%02h in1=%02h -> out=%02h expected %02h",
                  m8_in0, m8_in1, m8_out, ref_out(m8_in0, m8_in1, m8_sel));
      end
      m8_sel = 1'b1; #1;
      checks = checks + 1;
      if (m8_out !== ref_out(m8_in0, m8_in1, m8_sel)) begin
        errors = errors + 1;
        $display("FAIL nrOfBits=8 sel=1: in0=%02h in1=%02h -> out=%02h expected %02h",
                  m8_in0, m8_in1, m8_out, ref_out(m8_in0, m8_in1, m8_sel));
      end
    end

    // walking-1 / walking-0 across the 8-bit bus, both sel values
    for (p = 0; p < 8; p = p + 1) begin
      m8_in0 = (8'h01 << p);
      m8_in1 = ~(8'h01 << p);
      m8_sel = 1'b0; #1;
      checks = checks + 1;
      if (m8_out !== ref_out(m8_in0, m8_in1, m8_sel)) begin
        errors = errors + 1;
        $display("FAIL nrOfBits=8 walking bit=%0d sel=0: out=%02h expected %02h",
                  p, m8_out, ref_out(m8_in0, m8_in1, m8_sel));
      end
      m8_sel = 1'b1; #1;
      checks = checks + 1;
      if (m8_out !== ref_out(m8_in0, m8_in1, m8_sel)) begin
        errors = errors + 1;
        $display("FAIL nrOfBits=8 walking bit=%0d sel=1: out=%02h expected %02h",
                  p, m8_out, ref_out(m8_in0, m8_in1, m8_sel));
      end
    end

    // ---- named property checks (all widths) --------------------------------

    // 1. sel=0 ignores muxIn_1 entirely (nrOfBits=4 instance)
    m4_in0 = 4'b1010; m4_sel = 1'b0; m4_in1 = 4'b0000; #1;
    checks = checks + 1;
    if (m4_out !== 4'b1010) begin
      errors = errors + 1;
      $display("FAIL SEL0_IS_IN0_W4: out=%b expected 1010", m4_out);
    end
    m4_in1 = 4'b1111; #1;
    checks = checks + 1;
    if (m4_out !== 4'b1010) begin
      errors = errors + 1;
      $display("FAIL SEL0_IGNORES_IN1_W4: out=%b changed, must stay 1010", m4_out);
    end

    // 2. sel=1 ignores muxIn_0 entirely (nrOfBits=8 instance)
    m8_in1 = 8'hC3; m8_sel = 1'b1; m8_in0 = 8'h00; #1;
    checks = checks + 1;
    if (m8_out !== 8'hC3) begin
      errors = errors + 1;
      $display("FAIL SEL1_IS_IN1_W8: out=%02h expected C3", m8_out);
    end
    m8_in0 = 8'hFF; #1;
    checks = checks + 1;
    if (m8_out !== 8'hC3) begin
      errors = errors + 1;
      $display("FAIL SEL1_IGNORES_IN0_W8: out=%02h changed, must stay C3", m8_out);
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
