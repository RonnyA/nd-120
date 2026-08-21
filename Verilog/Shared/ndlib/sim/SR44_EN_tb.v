/****************************************************************************
** SR44_EN - self-checking functional testbench, both modes                **
**                                                                         **
**   USE_ENABLE=0 (default) wraps SR44: four Multiplexer_2 cells feeding   **
**       four D_FLIPFLOPs on posedge CP. sysclk and EN unused.             **
**   USE_ENABLE=1 : a behavioural rewrite in the sysclk domain -           **
**       if (EN) q_r <= L ? {D,C,B,A} : {q_r[2:0], SI};                    **
**       The CP pin is unused.                                             **
**                                                                         **
** The two modes are written completely differently (structural mux+flop   **
** chain versus one concatenation), so the SHIFT DIRECTION is the thing    **
** most likely to end up mirrored between them. The SERIAL WALK section    **
** pushes a single 1 through both DUTs and checks its position after every **
** edge, in both modes. A mirrored rewrite fails on the first step.        **
**                                                                         **
** Neither mode has a reset or preset pin, so that case does not exist     **
** here. What is covered instead: ENABLE HELD LOW across many sysclk       **
** edges, no clock edge at all, L flipping between load and shift on       **
** successive edges, the falling CP edge doing nothing, and inputs         **
** churning between edges.                                                 **
**                                                                         **
** Both modes power up 0000 - mode 0 because D_FLIPFLOP initialises its    **
** state, mode 1 because the wrapper declares `reg [3:0] q_r = 4'b0`. That **
** is unlike R41P_EN/R81_EN, where the two modes disagree at power-up.     **
**                                                                         **
** BUILD MODE: no `ifdef - latch mode and -DFPGA_FF_MODE are identical.    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-sr44en                    **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module SR44_EN_tb;

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
  reg L = 1'b1;
  reg SI = 1'b0;
  reg [3:0] din = 4'b0000;

  wire QA0,QAN0,QB0,QBN0,QC0,QCN0,QD0,QDN0;
  wire QA1,QAN1,QB1,QBN1,QC1,QCN1,QD1,QDN1;

  SR44_EN #(.USE_ENABLE(0)) U_M0 (
      .sysclk(sysclk), .EN(EN), .CP(CP), .L(L), .SI(SI),
      .A(din[0]), .B(din[1]), .C(din[2]), .D(din[3]),
      .QA(QA0), .QAN(QAN0), .QB(QB0), .QBN(QBN0),
      .QC(QC0), .QCN(QCN0), .QD(QD0), .QDN(QDN0));

  SR44_EN #(.USE_ENABLE(1)) U_M1 (
      .sysclk(sysclk), .EN(EN), .CP(CP), .L(L), .SI(SI),
      .A(din[0]), .B(din[1]), .C(din[2]), .D(din[3]),
      .QA(QA1), .QAN(QAN1), .QB(QB1), .QBN(QBN1),
      .QC(QC1), .QCN(QCN1), .QD(QD1), .QDN(QDN1));

  wire [3:0] q0 = {QD0, QC0, QB0, QA0};
  wire [3:0] q1 = {QD1, QC1, QB1, QA1};
  wire [3:0] qn0 = {QDN0, QCN0, QBN0, QAN0};
  wire [3:0] qn1 = {QDN1, QCN1, QBN1, QAN1};

  task sys_tick; begin #5 sysclk = 1'b1; #5 sysclk = 1'b0; #1; end endtask
  task cp_rise;  begin #5 CP = 1'b1; #1; end endtask
  task cp_fall;  begin #5 CP = 1'b0; #1; end endtask
  task both;     begin #2; cp_rise; cp_fall; sys_tick; end endtask

  task par_load(input [3:0] v); begin L = 1'b1; din = v; both; end endtask
  task shift_in(input s);       begin L = 1'b0; SI = s;  both; end endtask

  integer i;

  initial begin
    $dumpfile("SR44_EN_tb.vcd");
    $dumpvars(0, SR44_EN_tb);
  end

  initial begin
    #1;
    `CHK("mode0 power-up", q0, 4'b0000)
    `CHK("mode1 power-up", q1, 4'b0000)

    // ---- 1. NO CLOCK EDGE AT ALL ----
    L = 1'b1; din = 4'b1111; #20;
    `CHK("no edge: mode0 does not load", q0, 4'b0000)
    `CHK("no edge: mode1 does not load", q1, 4'b0000)
    L = 1'b0; SI = 1'b1; #20;
    `CHK("no edge: mode0 does not shift", q0, 4'b0000)
    `CHK("no edge: mode1 does not shift", q1, 4'b0000)

    // ---- 2. each mode listens to its own clock only ----
    L = 1'b1; din = 4'b1010; #2;
    cp_rise;
    `CHK("posedge CP: mode0 loads", q0, 4'b1010)
    `CHK("posedge CP: mode1 ignores CP", q1, 4'b0000)
    cp_fall;
    sys_tick;
    `CHK("posedge sysclk with EN high: mode1 loads", q1, 4'b1010)

    // ---- 3. EN irrelevant in mode 0, decisive in mode 1 ----
    EN = 1'b0; din = 4'b0101; #2;
    cp_rise; cp_fall;
    `CHK("mode0 loads with EN low", q0, 4'b0101)
    sys_tick; sys_tick; sys_tick;
    `CHK("mode1 EN held low: frozen", q1, 4'b1010)
    // a shift is frozen by EN too, not just a load
    L = 1'b0; SI = 1'b1; sys_tick; sys_tick;
    `CHK("mode1 EN held low: the shift is frozen as well", q1, 4'b1010)
    EN = 1'b1; L = 1'b1; din = 4'b0101; sys_tick;
    `CHK("mode1 loads when re-enabled", q1, 4'b0101)

    // ---- 4. parallel load, all 16 patterns, both modes ----
    for (i = 0; i < 16; i = i + 1) begin
      par_load(i[3:0]);
      `CHK("mode0 parallel load", q0, i[3:0])
      `CHK("mode1 parallel load", q1, i[3:0])
    end

    // ---- 5. SERIAL WALK: one 1 through a cleared register, both modes ----
    par_load(4'b0000);
    shift_in(1'b1);
    `CHK("mode0 walk step 1 -> QA", q0, 4'b0001)
    `CHK("mode1 walk step 1 -> QA", q1, 4'b0001)
    shift_in(1'b0);
    `CHK("mode0 walk step 2 -> QB", q0, 4'b0010)
    `CHK("mode1 walk step 2 -> QB", q1, 4'b0010)
    shift_in(1'b0);
    `CHK("mode0 walk step 3 -> QC", q0, 4'b0100)
    `CHK("mode1 walk step 3 -> QC", q1, 4'b0100)
    shift_in(1'b0);
    `CHK("mode0 walk step 4 -> QD", q0, 4'b1000)
    `CHK("mode1 walk step 4 -> QD", q1, 4'b1000)
    shift_in(1'b0);
    `CHK("mode0 walk step 5 -> gone", q0, 4'b0000)
    `CHK("mode1 walk step 5 -> gone", q1, 4'b0000)

    // ---- 6. SERIAL WALK, opposite polarity ----
    par_load(4'b1111);
    shift_in(1'b0);
    `CHK("mode0 zero walk 1", q0, 4'b1110)
    `CHK("mode1 zero walk 1", q1, 4'b1110)
    shift_in(1'b1);
    `CHK("mode0 zero walk 2", q0, 4'b1101)
    `CHK("mode1 zero walk 2", q1, 4'b1101)
    shift_in(1'b1);
    `CHK("mode0 zero walk 3", q0, 4'b1011)
    `CHK("mode1 zero walk 3", q1, 4'b1011)
    shift_in(1'b1);
    `CHK("mode0 zero walk 4", q0, 4'b0111)
    `CHK("mode1 zero walk 4", q1, 4'b0111)

    // ---- 7. SI ignored while L high; A..D ignored while L low ----
    par_load(4'b0000);
    L = 1'b1; din = 4'b0000; SI = 1'b1; both;
    `CHK("mode0 L=1: SI must not reach QA", q0, 4'b0000)
    `CHK("mode1 L=1: SI must not reach QA", q1, 4'b0000)
    L = 1'b0; din = 4'b1111; SI = 1'b0; both;
    `CHK("mode0 L=0: A..D must not reach the register", q0, 4'b0000)
    `CHK("mode1 L=0: A..D must not reach the register", q1, 4'b0000)

    // ---- 8. L flipping between load and shift on successive edges ----
    par_load(4'b0101);
    shift_in(1'b1);
    `CHK("mode0 shift after load", q0, 4'b1011)
    `CHK("mode1 shift after load", q1, 4'b1011)
    par_load(4'b0011);
    `CHK("mode0 load after shift", q0, 4'b0011)
    `CHK("mode1 load after shift", q1, 4'b0011)
    shift_in(1'b0);
    `CHK("mode0 shift after load again", q0, 4'b0110)
    `CHK("mode1 shift after load again", q1, 4'b0110)

    // ---- 9. falling CP does nothing (mode 0) ----
    L = 1'b1; din = 4'b1001; #2; cp_rise;
    `CHK("mode0 rising CP loads", q0, 4'b1001)
    din = 4'b0110; cp_fall;
    `CHK("mode0 falling CP does not load", q0, 4'b1001)

    // ---- 10. inputs churning between edges ----
    par_load(4'b1001);
    L = 1'b0; SI = 1'b1; #2; SI = 1'b0; #2; SI = 1'b1; #2;
    cp_rise; cp_fall; sys_tick;
    `CHK("mode0 final SI=1 shifted in", q0, 4'b0011)
    `CHK("mode1 final SI=1 shifted in", q1, 4'b0011)

    `CHK("mode0 complements", qn0, ~q0)
    `CHK("mode1 complements", qn1, ~q1)

    $display("SR44_EN_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire
