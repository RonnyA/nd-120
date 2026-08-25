/****************************************************************************
** F924_EN - self-checking functional testbench, both modes                **
**                                                                         **
** F924 is the NEC 4-bit D-type flip-flop used in the DGA. F924_EN is its  **
** P2 clock-domain wrapper.                                                **
**                                                                         **
**   USE_ENABLE=0 (default) wraps F924 (Verilog/DECODE-GateArray/DGA/      **
**       circuit/F924.v): four D_FLIPFLOP #(.InvertClockEnable(0)) on      **
**       posedge C_H05, preset/reset tied 0 and tick tied 1.               **
**       sysclk and EN are unused, so EN low must NOT stop it.             **
**   USE_ENABLE=1 : a structural copy of the same body with the four       **
**       flops swapped to D_FLIPFLOP_EN #(.USE_ENABLE(1)), i.e. posedge    **
**       sysclk capturing while EN is high. C_H05 is unused.               **
**                                                                         **
** Neither mode has a reset or preset pin exposed, so the                  **
** set-and-reset-together case does not exist on this cell.                **
**                                                                         **
** Both modes power up 0000: mode 0 because D_FLIPFLOP initialises its     **
** state to 0, mode 1 because D_FLIPFLOP_EN's gen_enable branch declares   **
** `reg q_r = 1'b0`. (Contrast R41P_EN/R81_EN, whose two modes disagree.)  **
**                                                                         **
** Bit mapping D0_H01..D3_H04 -> N01_Q0..N04_Q3 and the negated outputs    **
** N05_Q0B..N08_Q3B are checked with a walking one and a walking zero in   **
** both modes, so a crossed pair fails on its own named check. ENABLE      **
** HELD LOW across many sysclk edges, no clock edge at all, the falling    **
** clock edge, and data churning between edges are all covered.            **
**                                                                         **
** BUILD MODE: no `ifdef - latch mode and -DFPGA_FF_MODE are identical.    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-f924en                    **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module F924_EN_tb;

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
  reg C_H05 = 1'b0;
  reg [3:0] din = 4'b0000;      // {D3,D2,D1,D0}

  wire Q00, Q10, Q20, Q30, QB00, QB10, QB20, QB30;
  wire Q01, Q11, Q21, Q31, QB01, QB11, QB21, QB31;

  F924_EN #(.USE_ENABLE(0)) U_M0 (
      .sysclk(sysclk), .EN(EN), .C_H05(C_H05),
      .D0_H01(din[0]), .D1_H02(din[1]), .D2_H03(din[2]), .D3_H04(din[3]),
      .N01_Q0(Q00), .N02_Q1(Q10), .N03_Q2(Q20), .N04_Q3(Q30),
      .N05_Q0B(QB00), .N06_Q1B(QB10), .N07_Q2B(QB20), .N08_Q3B(QB30));

  F924_EN #(.USE_ENABLE(1)) U_M1 (
      .sysclk(sysclk), .EN(EN), .C_H05(C_H05),
      .D0_H01(din[0]), .D1_H02(din[1]), .D2_H03(din[2]), .D3_H04(din[3]),
      .N01_Q0(Q01), .N02_Q1(Q11), .N03_Q2(Q21), .N04_Q3(Q31),
      .N05_Q0B(QB01), .N06_Q1B(QB11), .N07_Q2B(QB21), .N08_Q3B(QB31));

  wire [3:0] q0  = {Q30, Q20, Q10, Q00};
  wire [3:0] qn0 = {QB30, QB20, QB10, QB00};
  wire [3:0] q1  = {Q31, Q21, Q11, Q01};
  wire [3:0] qn1 = {QB31, QB21, QB11, QB01};

  task sys_tick; begin #5 sysclk = 1'b1; #5 sysclk = 1'b0; #1; end endtask
  task clk_rise; begin #5 C_H05 = 1'b1; #1; end endtask
  task clk_fall; begin #5 C_H05 = 1'b0; #1; end endtask
  task load(input [3:0] v);
    begin din = v; #2; clk_rise; clk_fall; sys_tick; end
  endtask

  integer i;

  initial begin
    $dumpfile("F924_EN_tb.vcd");
    $dumpvars(0, F924_EN_tb);
  end

  initial begin
    #1;
    `CHK("mode0 power-up", q0, 4'b0000)
    `CHK("mode1 power-up", q1, 4'b0000)
    `CHK("mode0 power-up negated outputs", qn0, 4'b1111)
    `CHK("mode1 power-up negated outputs", qn1, 4'b1111)

    // ---- 1. NO CLOCK EDGE AT ALL ----
    din = 4'b1111; #20;
    `CHK("no edge: mode0 holds", q0, 4'b0000)
    `CHK("no edge: mode1 holds", q1, 4'b0000)

    // ---- 2. each mode listens to its own clock only ----
    din = 4'b1010; #2;
    clk_rise;
    `CHK("posedge C_H05: mode0 captures", q0, 4'b1010)
    `CHK("posedge C_H05: mode1 ignores it", q1, 4'b0000)
    clk_fall;
    sys_tick;
    `CHK("posedge sysclk with EN high: mode1 captures", q1, 4'b1010)

    // ---- 3. EN irrelevant in mode 0, decisive in mode 1 ----
    EN = 1'b0; din = 4'b0101; #2;
    clk_rise; clk_fall;
    `CHK("mode0 captures with EN low", q0, 4'b0101)
    sys_tick; sys_tick; sys_tick;
    `CHK("mode1 EN held low: frozen", q1, 4'b1010)
    EN = 1'b1; sys_tick;
    `CHK("mode1 captures when re-enabled", q1, 4'b0101)

    // ---- 4. WALKING ONE: the D0..D3 -> Q0..Q3 mapping ----
    load(4'b0001);
    `CHK("mode0 D0=1 lights Q0 only", q0, 4'b0001)
    `CHK("mode1 D0=1 lights Q0 only", q1, 4'b0001)
    load(4'b0010);
    `CHK("mode0 D1=1 lights Q1 only", q0, 4'b0010)
    `CHK("mode1 D1=1 lights Q1 only", q1, 4'b0010)
    load(4'b0100);
    `CHK("mode0 D2=1 lights Q2 only", q0, 4'b0100)
    `CHK("mode1 D2=1 lights Q2 only", q1, 4'b0100)
    load(4'b1000);
    `CHK("mode0 D3=1 lights Q3 only", q0, 4'b1000)
    `CHK("mode1 D3=1 lights Q3 only", q1, 4'b1000)

    // ---- 5. WALKING ZERO ----
    load(4'b1110); `CHK("mode0 D0=0", q0, 4'b1110) `CHK("mode1 D0=0", q1, 4'b1110)
    load(4'b1101); `CHK("mode0 D1=0", q0, 4'b1101) `CHK("mode1 D1=0", q1, 4'b1101)
    load(4'b1011); `CHK("mode0 D2=0", q0, 4'b1011) `CHK("mode1 D2=0", q1, 4'b1011)
    load(4'b0111); `CHK("mode0 D3=0", q0, 4'b0111) `CHK("mode1 D3=0", q1, 4'b0111)

    // ---- 6. all 16 patterns with negated outputs ----
    for (i = 0; i < 16; i = i + 1) begin
      load(i[3:0]);
      `CHK("mode0 pattern", q0, i[3:0])
      `CHK("mode1 pattern", q1, i[3:0])
      `CHK("mode0 negated outputs", qn0, ~i[3:0])
      `CHK("mode1 negated outputs", qn1, ~i[3:0])
    end

    // ---- 7. falling clock does nothing (mode 0) ----
    din = 4'b1001; #2; clk_rise;
    `CHK("mode0 rising edge captures", q0, 4'b1001)
    din = 4'b0110; clk_fall;
    `CHK("mode0 falling edge does not capture", q0, 4'b1001)

    // ---- 8. data churning between edges ----
    din = 4'b0011; #2; din = 4'b1100; #2; din = 4'b0110; #2;
    clk_rise; clk_fall; sys_tick;
    `CHK("mode0 takes the final value", q0, 4'b0110)
    `CHK("mode1 takes the final value", q1, 4'b0110)

    $display("F924_EN_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire
