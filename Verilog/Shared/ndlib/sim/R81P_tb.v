/****************************************************************************
** R81P - self-checking functional testbench                              **
**                                                                         **
** R81P is the plain 8-bit register with true and complement outputs:      **
**     always @(posedge CP) reg8bit[7:0] <= {H,G,F,E,D,C,B,A};             **
** No clock enable, no reset, no preset, no parameter - every rising edge  **
** of CP loads all eight bits unconditionally.                             **
**                                                                         **
** WATCH OUT: R81P.v and R81.v are two SEPARATE files with byte-identical  **
** behaviour, and the wrapper R81_EN.v instantiates R81, not R81P. If a    **
** fix ever lands in one of them it must land in the other; this tb        **
** guards R81P specifically, so a one-sided edit shows up here.            **
**                                                                         **
** Bit order is the likeliest transcription error, so the WALKING-ONE and  **
** WALKING-ZERO sections drive exactly one input at a time and name the    **
** expected output. A swapped pair fails on its own named check instead of **
** hiding inside a random pattern.                                         **
**                                                                         **
** Covered: power-up, walking one, walking zero, 64 pseudo-random          **
** patterns, hold with NO clock edge at all, the falling edge doing        **
** nothing, and data churning between edges. There is no reset or preset   **
** pin on this cell, so that case does not exist here.                     **
**                                                                         **
** BUILD MODE: no `ifdef - latch mode and -DFPGA_FF_MODE are identical.    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-r81p                      **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module R81P_tb;

  integer checks = 0;
  integer errors = 0;

`define CHK(NM, GOT, EXP) \
  begin \
    checks = checks + 1; \
    if ((GOT) !== (EXP)) begin \
      errors = errors + 1; \
      $display("FAIL t=%0t %0s : got=%b expected=%b", $time, NM, (GOT), (EXP)); \
    end \
  end

  reg CP = 1'b0;
  reg [7:0] din = 8'h00;            // {H,G,F,E,D,C,B,A}
  wire QA, QAN, QB, QBN, QC, QCN, QD, QDN;
  wire QE, QEN, QF, QFN, QG, QGN, QH, QHN;

  R81P DUT (
      .CP(CP),
      .A(din[0]), .B(din[1]), .C(din[2]), .D(din[3]),
      .E(din[4]), .F(din[5]), .G(din[6]), .H(din[7]),
      .QA(QA), .QAN(QAN), .QB(QB), .QBN(QBN),
      .QC(QC), .QCN(QCN), .QD(QD), .QDN(QDN),
      .QE(QE), .QEN(QEN), .QF(QF), .QFN(QFN),
      .QG(QG), .QGN(QGN), .QH(QH), .QHN(QHN)
  );

  wire [7:0] q  = {QH, QG, QF, QE, QD, QC, QB, QA};
  wire [7:0] qn = {QHN, QGN, QFN, QEN, QDN, QCN, QBN, QAN};

  task clk_rise; begin #5 CP = 1'b1; #1; end endtask
  task clk_fall; begin #5 CP = 1'b0; #1; end endtask
  task load(input [7:0] v);
    begin
      din = v;
      clk_rise;
      clk_fall;
    end
  endtask

  integer i;
  reg [7:0] pat;

  initial begin
    $dumpfile("R81P_tb.vcd");
    $dumpvars(0, R81P_tb);
  end

  initial begin
    #1;
    `CHK("power-up q is UNKNOWN (no initialiser in R81P.v)", q, 8'bxxxxxxxx)

    // ---- no clock edge at all ----
    din = 8'hFF; #20;
    `CHK("no clock edge: nothing loads", q, 8'bxxxxxxxx)

    load(8'h00);
    `CHK("first load 00", q, 8'h00)
    `CHK("complements after 00", qn, 8'hFF)

    // ---- WALKING ONE across all eight bit positions ----
    for (i = 0; i < 8; i = i + 1) begin
      load(8'h01 << i);
      `CHK("walking one", q, 8'h01 << i)
      `CHK("walking one complements", qn, ~(8'h01 << i))
    end

    // ---- WALKING ZERO ----
    for (i = 0; i < 8; i = i + 1) begin
      load(~(8'h01 << i));
      `CHK("walking zero", q, ~(8'h01 << i))
    end

    // ---- 64 deterministic pseudo-random patterns ----
    // Kept out of the VCD: the committed waveform should show the walking
    // one, the walking zero and the hold, not 64 anonymous loads.
    $dumpoff;
    pat = 8'h5A;
    for (i = 0; i < 64; i = i + 1) begin
      pat = {pat[6:0], pat[7] ^ pat[5] ^ pat[4] ^ pat[3]};
      load(pat);
      `CHK("pattern load", q, pat)
      `CHK("pattern complements", qn, ~pat)
    end
    $dumpon;

    // ---- the falling edge must do nothing ----
    load(8'hA5);
    din = 8'h3C;
    clk_rise;
    `CHK("rising edge loads", q, 8'h3C)
    din = 8'hFF;
    clk_fall;
    `CHK("falling edge does not load", q, 8'h3C)

    // ---- data churning between edges ----
    din = 8'h11; #2;
    din = 8'h22; #2;
    din = 8'h44; #2;
    clk_rise;
    `CHK("only the final pre-edge value is captured", q, 8'h44)
    clk_fall;

    // ---- long hold with CP parked low ----
    for (i = 0; i < 8; i = i + 1) begin
      din = i[7:0]; #2;
    end
    `CHK("CP parked low: register holds", q, 8'h44)
    `CHK("held complements", qn, ~8'h44)

    $display("R81P_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire
