/****************************************************************************
** R41P - self-checking functional testbench                              **
**                                                                         **
** R41P is the plain 4-bit register with true and complement outputs:      **
**     always @(posedge CP) reg8bit[3:0] <= {D,C,B,A};                     **
** There is NO clock enable, NO reset, NO preset and NO parameter. Every   **
** rising edge of CP loads all four bits, unconditionally. This tb exists  **
** to state that in a form that fails if anyone adds a hidden enable.      **
**                                                                         **
** Bit order matters and is the thing most likely to be got wrong: A is    **
** bit 0 (QA), B is bit 1 (QB), C is bit 2 (QC), D is bit 3 (QD). The      **
** WALKING-ONE section drives exactly one input high at a time and checks  **
** that exactly the matching output goes high, so a transposed pair (say   **
** C and D swapped) fails on a named check rather than being averaged      **
** away by a random pattern.                                               **
**                                                                         **
** Covered: power-up, walking one, walking zero, all 16 patterns, hold     **
** with NO clock edge at all, the falling edge doing nothing, and data     **
** churning between edges. Complement outputs are checked after every      **
** load - there is no reset/preset case on this cell because the cell has  **
** neither pin (see R41P_EN_tb.v for the enabled variant).                 **
**                                                                         **
** NOTE the internal signal in R41P.v is called `reg8bit` although it is   **
** four bits wide - a copy/paste from R81P.v. Cosmetic, no behaviour.      **
**                                                                         **
** BUILD MODE: no `ifdef - latch mode and -DFPGA_FF_MODE are identical.    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-r41p                      **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module R41P_tb;

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
  reg [3:0] din = 4'b0000;          // {D,C,B,A}
  wire QA, QAN, QB, QBN, QC, QCN, QD, QDN;

  R41P DUT (
      .CP(CP),
      .A(din[0]), .B(din[1]), .C(din[2]), .D(din[3]),
      .QA(QA), .QAN(QAN), .QB(QB), .QBN(QBN),
      .QC(QC), .QCN(QCN), .QD(QD), .QDN(QDN)
  );

  wire [3:0] q  = {QD, QC, QB, QA};
  wire [3:0] qn = {QDN, QCN, QBN, QAN};

  task clk_rise; begin #5 CP = 1'b1; #1; end endtask
  task clk_fall; begin #5 CP = 1'b0; #1; end endtask
  task load(input [3:0] v);
    begin
      din = v;
      clk_rise;
      clk_fall;
    end
  endtask

  integer i;

  initial begin
    $dumpfile("R41P_tb.vcd");
    $dumpvars(0, R41P_tb);
  end

  initial begin
    #1;
    // ---- power-up: reg8bit has no initialiser, so the outputs are x ----
    `CHK("power-up q is UNKNOWN (no initialiser in R41P.v)", q, 4'bxxxx)

    // ---- no clock edge at all ----
    din = 4'b1111; #20;
    `CHK("no clock edge: nothing loads", q, 4'bxxxx)

    // ---- first real load ----
    load(4'b0000);
    `CHK("first load 0000", q, 4'b0000)
    `CHK("complements after 0000", qn, 4'b1111)

    // ---- WALKING ONE: proves the A/B/C/D -> QA/QB/QC/QD mapping ----
    load(4'b0001); `CHK("A=1 lights QA only", q, 4'b0001)
    load(4'b0010); `CHK("B=1 lights QB only", q, 4'b0010)
    load(4'b0100); `CHK("C=1 lights QC only", q, 4'b0100)
    load(4'b1000); `CHK("D=1 lights QD only", q, 4'b1000)

    // ---- WALKING ZERO ----
    load(4'b1110); `CHK("A=0 clears QA only", q, 4'b1110)
    load(4'b1101); `CHK("B=0 clears QB only", q, 4'b1101)
    load(4'b1011); `CHK("C=0 clears QC only", q, 4'b1011)
    load(4'b0111); `CHK("D=0 clears QD only", q, 4'b0111)

    // ---- all 16 patterns, complements checked every time ----
    for (i = 0; i < 16; i = i + 1) begin
      load(i[3:0]);
      `CHK("exhaustive pattern", q, i[3:0])
      `CHK("exhaustive complements", qn, ~i[3:0])
    end

    // ---- the falling edge must do nothing ----
    load(4'b1010);
    din = 4'b0101;
    clk_rise;                      // this DOES load 0101
    `CHK("rising edge loads", q, 4'b0101)
    din = 4'b1111;
    clk_fall;                      // this must not
    `CHK("falling edge does not load", q, 4'b0101)

    // ---- data churning between edges: only the last value lands ----
    din = 4'b0011; #2;
    din = 4'b1100; #2;
    din = 4'b1001; #2;
    clk_rise;
    `CHK("only the final pre-edge value is captured", q, 4'b1001)
    clk_fall;

    // ---- long hold with CP parked low ----
    for (i = 0; i < 6; i = i + 1) begin
      din = i[3:0]; #2;
    end
    `CHK("CP parked low: register holds", q, 4'b1001)
    `CHK("held complements", qn, ~4'b1001)

    $display("R41P_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire
