/****************************************************************************
** M169C_EN - self-checking functional testbench, both modes               **
**                                                                         **
**   USE_ENABLE=0 (default) wraps M169C: the gate-level 74LS169 clocked    **
**       on posedge CP. sysclk and EN unused.                              **
**   USE_ENABLE=1 : a STRUCTURAL COPY of the same 35-gate netlist with     **
**       only the four internal flops swapped to                           **
**       D_FLIPFLOP_EN #(.USE_ENABLE(1)), so the counter advances on       **
**       posedge sysclk while EN is high. The CP pin is unused.            **
**                                                                         **
** Because mode 1 is a hand-copied netlist, a single mistyped wire in the  **
** carry chain would only show up on particular counts. Both DUTs are      **
** therefore driven from the SAME stimulus and BOTH are compared against   **
** an independent datasheet reference model on EVERY edge - 40 up counts   **
** (two and a half wraps), 40 down counts, and a randomised 200-step walk  **
** mixing load, hold, direction and enable changes. CON is checked on      **
** every one of those steps.                                               **
**                                                                         **
** Reference (SN74ALS169B function table, measured against this RTL):      **
**   NL=0 -> synchronous load of {D,C,B,A}, overriding PN and TN           **
**   NL=1, PN=0 and TN=0 -> count, up when UP=1 and down when UP=0         **
**   NL=1, PN=1 or TN=1  -> hold                                           **
**   CON (RCO_n) = 0 when TN=0 and the count is terminal (15 up, 0 down);  **
**   it is combinational and independent of PN, NL and the clock.          **
**                                                                         **
** The 74169 has no asynchronous clear or preset, so set-and-reset-        **
** together cannot be built; the nearest conflict - LOAD asserted with     **
** both count enables off - is tested and LOAD wins, in both modes.        **
** ENABLE HELD LOW (mode 1) and no clock edge at all are covered.          **
**                                                                         **
** BUILD MODE: no `ifdef - latch mode and -DFPGA_FF_MODE are identical.    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-m169cen                   **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module M169C_EN_tb;

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
  reg NL = 1'b1, PN = 1'b0, TN = 1'b0, UP = 1'b1;
  reg [3:0] din = 4'b0000;

  wire CON0, QA0, QB0, QC0, QD0;
  wire CON1, QA1, QB1, QC1, QD1;

  M169C_EN #(.USE_ENABLE(0)) U_M0 (
      .sysclk(sysclk), .EN(EN),
      .A(din[0]), .B(din[1]), .C(din[2]), .D(din[3]),
      .CP(CP), .NL(NL), .PN(PN), .TN(TN), .UP(UP),
      .CON(CON0), .QA(QA0), .QB(QB0), .QC(QC0), .QD(QD0));

  M169C_EN #(.USE_ENABLE(1)) U_M1 (
      .sysclk(sysclk), .EN(EN),
      .A(din[0]), .B(din[1]), .C(din[2]), .D(din[3]),
      .CP(CP), .NL(NL), .PN(PN), .TN(TN), .UP(UP),
      .CON(CON1), .QA(QA1), .QB(QB1), .QC(QC1), .QD(QD1));

  wire [3:0] q0 = {QD0, QC0, QB0, QA0};
  wire [3:0] q1 = {QD1, QC1, QB1, QA1};

  reg [3:0] mq = 4'b0000;

  function [3:0] next_q(input [3:0] cur, input nl, input pn, input tn,
                        input up, input [3:0] d);
    begin
      if (!nl)             next_q = d;
      else if (!pn && !tn) next_q = up ? (cur + 4'd1) : (cur - 4'd1);
      else                 next_q = cur;
    end
  endfunction

  function ref_con(input [3:0] cur, input tn, input up);
    begin
      ref_con = ~(~tn & ((up & (cur == 4'd15)) | (~up & (cur == 4'd0))));
    end
  endfunction

  task cp_rise;  begin #5 CP = 1'b1; #1; end endtask
  task cp_fall;  begin #5 CP = 1'b0; #1; end endtask
  task sys_tick; begin #5 sysclk = 1'b1; #5 sysclk = 1'b0; #1; end endtask

  // advance both DUTs one step and check both against the model
  task step;
    begin
      mq = next_q(mq, NL, PN, TN, UP, din);
      #2;
      cp_rise; cp_fall;
      sys_tick;
      `CHK("mode0 matches the model", q0, mq)
      `CHK("mode1 matches the model", q1, mq)
      `CHK("mode0 CON matches the model", CON0, ref_con(mq, TN, UP))
      `CHK("mode1 CON matches the model", CON1, ref_con(mq, TN, UP))
    end
  endtask

  task force_load(input [3:0] v);
    begin NL = 1'b0; din = v; step; NL = 1'b1; end
  endtask

  integer i;
  integer seed;

  initial begin
    $dumpfile("M169C_EN_tb.vcd");
    $dumpvars(0, M169C_EN_tb);
  end

  initial begin
    seed = 32'h1234BEEF;
    #1;

    // ---- 1. load establishes a known state in both DUTs ----
    force_load(4'b0000);
    `CHK("mode0 loaded 0000", q0, 4'b0000)
    `CHK("mode1 loaded 0000", q1, 4'b0000)

    // ---- 2. NO CLOCK EDGE AT ALL ----
    NL = 1'b1; PN = 1'b0; TN = 1'b0; UP = 1'b1; #30;
    `CHK("no edge: mode0 holds", q0, 4'b0000)
    `CHK("no edge: mode1 holds", q1, 4'b0000)
    // CON is combinational in both
    UP = 1'b0; #2;
    `CHK("mode0 CON: 0 counting down is terminal", CON0, 1'b0)
    `CHK("mode1 CON: 0 counting down is terminal", CON1, 1'b0)
    TN = 1'b1; #2;
    `CHK("mode0 CON gated by TN", CON0, 1'b1)
    `CHK("mode1 CON gated by TN", CON1, 1'b1)
    TN = 1'b0; UP = 1'b1; #2;

    // ---- 3. each mode listens to its own clock only ----
    #2; cp_rise;
    `CHK("posedge CP: mode0 counted", q0, 4'b0001)
    `CHK("posedge CP: mode1 ignored CP", q1, 4'b0000)
    cp_fall;
    sys_tick;
    `CHK("posedge sysclk with EN high: mode1 counted", q1, 4'b0001)
    mq = 4'b0001;

    // ---- 4. ENABLE HELD LOW freezes mode 1 only ----
    EN = 1'b0;
    #2; cp_rise; cp_fall; sys_tick; sys_tick;
    `CHK("mode0 does not care about EN: one CP edge, one count", q0, 4'b0010)
    `CHK("mode1 EN held low: frozen", q1, 4'b0001)
    // a LOAD is frozen by EN too in mode 1
    NL = 1'b0; din = 4'b1111; sys_tick;
    `CHK("mode1 EN low: even a LOAD is frozen", q1, 4'b0001)
    NL = 1'b1;
    EN = 1'b1;
    // realign both DUTs and the model
    force_load(4'b0000);
    `CHK("mode0 realigned", q0, 4'b0000)
    `CHK("mode1 realigned", q1, 4'b0000)

    // ---- 5. 40 UP counts (two and a half wraps) ----
    UP = 1'b1; PN = 1'b0; TN = 1'b0; NL = 1'b1;
    for (i = 0; i < 40; i = i + 1) step;

    // ---- 6. 40 DOWN counts ----
    UP = 1'b0;
    for (i = 0; i < 40; i = i + 1) step;

    // ---- 7. hold via each enable separately ----
    UP = 1'b1;
    force_load(4'b1001);
    PN = 1'b1; TN = 1'b0; for (i = 0; i < 3; i = i + 1) step;
    `CHK("mode0 PN=1 holds", q0, 4'b1001)
    `CHK("mode1 PN=1 holds", q1, 4'b1001)
    PN = 1'b0; TN = 1'b1; for (i = 0; i < 3; i = i + 1) step;
    `CHK("mode0 TN=1 holds", q0, 4'b1001)
    `CHK("mode1 TN=1 holds", q1, 4'b1001)

    // ---- 8. LOAD WINS over both enables being off ----
    NL = 1'b0; din = 4'b0110; PN = 1'b1; TN = 1'b1;
    step;
    `CHK("mode0 load overrides the enables", q0, 4'b0110)
    `CHK("mode1 load overrides the enables", q1, 4'b0110)
    NL = 1'b1; PN = 1'b0; TN = 1'b0;

    // ---- 9. falling CP does nothing (mode 0) ----
    UP = 1'b1; #2;
    cp_rise;
    `CHK("mode0 rising CP counts", q0, 4'b0111)
    cp_fall;
    `CHK("mode0 falling CP does not count", q0, 4'b0111)
    sys_tick;                       // let mode1 catch up
    mq = 4'b0111;
    `CHK("mode1 caught up", q1, 4'b0111)

    // ---- 10. randomised 200-step walk (kept out of the VCD) ----
    $dumpoff;
    for (i = 0; i < 200; i = i + 1) begin
      NL  = ~(($random(seed) % 8) == 0);
      PN  = ($random(seed) % 4) == 0;
      TN  = ($random(seed) % 4) == 0;
      UP  = $random(seed);
      din = $random(seed);
      step;
    end
    $dumpon;

    $display("M169C_EN_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire
