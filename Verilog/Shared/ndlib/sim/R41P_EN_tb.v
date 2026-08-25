/****************************************************************************
** R41P_EN - self-checking functional testbench, both modes                **
**                                                                         **
**   USE_ENABLE=0 (default) wraps R41P: every posedge CP loads             **
**       {D,C,B,A} unconditionally. sysclk and EN are unused, so EN low    **
**       must NOT stop it - that is checked.                               **
**   USE_ENABLE=1 : posedge sysclk, load only while EN is high. The CP     **
**       pin is unused, so a CP edge must do nothing - also checked.       **
**                                                                         **
** Neither mode has a reset or a preset pin, so the set-and-reset-together **
** case does not exist on this cell.                                       **
**                                                                         **
** POWER-UP DIFFERS BETWEEN THE MODES and the difference is real:          **
**   mode 0 -> R41P declares `reg [3:0] reg8bit;` with NO initialiser, so  **
**             the outputs come up UNKNOWN (x)                             **
**   mode 1 -> the wrapper declares `reg [3:0] q_r = 4'b0;`, so it comes   **
**             up 0000                                                     **
**   Verilator squashes x to 0 and hides this; iverilog does not. Anything **
**   that reads one of these registers before its first load therefore     **
**   sees a different value depending on which mode was built. Both are    **
**   asserted below.                                                       **
**                                                                         **
** Bit order (A->QA .. D->QD) is checked with a walking one and a walking  **
** zero in both modes, so a transposed pair fails on a named check.        **
** ENABLE HELD LOW across many sysclk edges, and no clock edge at all,     **
** are covered explicitly.                                                 **
**                                                                         **
** BUILD MODE: no `ifdef - latch mode and -DFPGA_FF_MODE are identical.    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-r41pen                    **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module R41P_EN_tb;

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

  reg sysclk = 1'b0;
  reg EN = 1'b1;
  reg CP = 1'b0;
  reg [3:0] din = 4'b0000;          // {D,C,B,A}

  wire QA0, QAN0, QB0, QBN0, QC0, QCN0, QD0, QDN0;
  wire QA1, QAN1, QB1, QBN1, QC1, QCN1, QD1, QDN1;

  R41P_EN #(.USE_ENABLE(0)) U_M0 (
      .sysclk(sysclk), .EN(EN), .CP(CP),
      .A(din[0]), .B(din[1]), .C(din[2]), .D(din[3]),
      .QA(QA0), .QAN(QAN0), .QB(QB0), .QBN(QBN0),
      .QC(QC0), .QCN(QCN0), .QD(QD0), .QDN(QDN0));

  R41P_EN #(.USE_ENABLE(1)) U_M1 (
      .sysclk(sysclk), .EN(EN), .CP(CP),
      .A(din[0]), .B(din[1]), .C(din[2]), .D(din[3]),
      .QA(QA1), .QAN(QAN1), .QB(QB1), .QBN(QBN1),
      .QC(QC1), .QCN(QCN1), .QD(QD1), .QDN(QDN1));

  wire [3:0] q0  = {QD0, QC0, QB0, QA0};
  wire [3:0] qn0 = {QDN0, QCN0, QBN0, QAN0};
  wire [3:0] q1  = {QD1, QC1, QB1, QA1};
  wire [3:0] qn1 = {QDN1, QCN1, QBN1, QAN1};

  task sys_tick; begin #5 sysclk = 1'b1; #5 sysclk = 1'b0; #1; end endtask
  task cp_rise;  begin #5 CP = 1'b1; #1; end endtask
  task cp_fall;  begin #5 CP = 1'b0; #1; end endtask
  task load(input [3:0] v);
    begin
      din = v; #2;
      cp_rise; cp_fall;
      sys_tick;
    end
  endtask

  integer i;

  initial begin
    $dumpfile("R41P_EN_tb.vcd");
    $dumpvars(0, R41P_EN_tb);
  end

  initial begin
    #1;
    `CHK("mode0 powers up UNKNOWN (R41P has no initialiser)", q0, 4'bxxxx)
    `CHK("mode1 powers up 0000 (wrapper initialises q_r)",    q1, 4'b0000)

    // ---- 1. NO CLOCK EDGE AT ALL ----
    din = 4'b1111; #20;
    `CHK("no edge: mode0 holds", q0, 4'bxxxx)
    `CHK("no edge: mode1 holds", q1, 4'b0000)

    // ---- 2. each mode listens to its own clock only ----
    din = 4'b1010; #2;
    cp_rise;
    `CHK("posedge CP: mode0 loads", q0, 4'b1010)
    `CHK("posedge CP: mode1 ignores CP", q1, 4'b0000)
    cp_fall;
    sys_tick;
    `CHK("posedge sysclk with EN high: mode1 loads", q1, 4'b1010)

    // ---- 3. EN is irrelevant in mode 0, decisive in mode 1 ----
    EN = 1'b0; din = 4'b0101; #2;
    cp_rise; cp_fall;
    `CHK("mode0 loads with EN low", q0, 4'b0101)
    sys_tick; sys_tick; sys_tick;
    `CHK("mode1 EN held low: no load at all", q1, 4'b1010)
    EN = 1'b1; sys_tick;
    `CHK("mode1 loads when re-enabled", q1, 4'b0101)

    // ---- 4. WALKING ONE, both modes ----
    load(4'b0001); `CHK("mode0 A=1 -> QA", q0, 4'b0001) `CHK("mode1 A=1 -> QA", q1, 4'b0001)
    load(4'b0010); `CHK("mode0 B=1 -> QB", q0, 4'b0010) `CHK("mode1 B=1 -> QB", q1, 4'b0010)
    load(4'b0100); `CHK("mode0 C=1 -> QC", q0, 4'b0100) `CHK("mode1 C=1 -> QC", q1, 4'b0100)
    load(4'b1000); `CHK("mode0 D=1 -> QD", q0, 4'b1000) `CHK("mode1 D=1 -> QD", q1, 4'b1000)

    // ---- 5. WALKING ZERO, both modes ----
    load(4'b1110); `CHK("mode0 A=0", q0, 4'b1110) `CHK("mode1 A=0", q1, 4'b1110)
    load(4'b1101); `CHK("mode0 B=0", q0, 4'b1101) `CHK("mode1 B=0", q1, 4'b1101)
    load(4'b1011); `CHK("mode0 C=0", q0, 4'b1011) `CHK("mode1 C=0", q1, 4'b1011)
    load(4'b0111); `CHK("mode0 D=0", q0, 4'b0111) `CHK("mode1 D=0", q1, 4'b0111)

    // ---- 6. all 16 patterns with complements ----
    for (i = 0; i < 16; i = i + 1) begin
      load(i[3:0]);
      `CHK("mode0 pattern", q0, i[3:0])
      `CHK("mode1 pattern", q1, i[3:0])
      `CHK("mode0 complements", qn0, ~i[3:0])
      `CHK("mode1 complements", qn1, ~i[3:0])
    end

    // ---- 7. falling CP does nothing (mode 0) ----
    din = 4'b1001; #2; cp_rise;
    `CHK("mode0 rising CP loads", q0, 4'b1001)
    din = 4'b0110; cp_fall;
    `CHK("mode0 falling CP does not load", q0, 4'b1001)

    // ---- 8. data churning between edges ----
    din = 4'b0011; #2; din = 4'b1100; #2; din = 4'b0110; #2;
    cp_rise; cp_fall; sys_tick;
    `CHK("mode0 takes the final value", q0, 4'b0110)
    `CHK("mode1 takes the final value", q1, 4'b0110)

    $display("R41P_EN_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire
