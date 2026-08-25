/****************************************************************************
** M169C - self-checking functional testbench                             **
**                                                                         **
** M169C is the gate-level 74LS169 synchronous 4-bit up/down binary        **
** counter (35 gates plus four D_FLIPFLOP #(.InvertClockEnable(0))). It is **
** transcribed from the schematic, so the value of a testbench here is     **
** checking the TRANSCRIPTION against the datasheet function, not checking **
** the datasheet.                                                          **
**                                                                         **
** The reference model below is written from the SN74ALS169B function      **
** table, independently of the netlist:                                    **
**                                                                         **
**   NL (LOAD_n) = 0  -> synchronous parallel load of {D,C,B,A} on the     **
**                       rising edge of CP, REGARDLESS of PN and TN        **
**   NL = 1, PN = 0 and TN = 0 -> count: up when UP=1, down when UP=0      **
**   NL = 1, PN = 1 or  TN = 1 -> hold                                     **
**   CON (RCO_n, active low) = 0 when TN = 0 AND the count is terminal     **
**                       (1111 counting up, 0000 counting down).           **
**                       CON is combinational - it does NOT depend on PN,  **
**                       on NL, or on a clock edge.                        **
**                                                                         **
** All four of those statements were MEASURED against this RTL before      **
** being written down, and all four hold.                                  **
**                                                                         **
** A counter is easy to test badly: counting up from 0 to 15 and back      **
** would also pass on a design with the carry chain broken above bit 1 if  **
** you only checked the low bits. Here EVERY edge is compared against the  **
** model over 40 consecutive up counts (two and a half full wraps) and 40  **
** down counts, plus a randomised 300-step walk that mixes load, hold,     **
** direction changes and enable changes. CON is checked on every single    **
** one of those steps, not just at the terminal counts.                    **
**                                                                         **
** Also covered: hold with NO clock edge at all, the falling edge doing    **
** nothing, load winning over the enables, and inputs churning between     **
** edges. The 74169 has no asynchronous clear or preset, so the            **
** set-and-reset-together case does not exist on this cell; the nearest    **
** conflict - LOAD asserted at the same time as both count enables off -   **
** IS tested, and LOAD wins.                                               **
**                                                                         **
** BUILD MODE: no `ifdef in M169C.v or any cell it uses - latch mode and   **
** -DFPGA_FF_MODE must be bit-identical. Both are run.                     **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-m169c                     **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module M169C_tb;

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
  reg NL = 1'b1;                 // load, active low
  reg PN = 1'b0;                 // enable P, active low
  reg TN = 1'b0;                 // enable T, active low
  reg UP = 1'b1;                 // 1 = up, 0 = down
  reg [3:0] din = 4'b0000;       // {D,C,B,A}

  wire CON, QA, QB, QC, QD;

  M169C DUT (
      .A(din[0]), .B(din[1]), .C(din[2]), .D(din[3]),
      .CP(CP), .NL(NL), .PN(PN), .TN(TN), .UP(UP),
      .CON(CON), .QA(QA), .QB(QB), .QC(QC), .QD(QD)
  );

  wire [3:0] q = {QD, QC, QB, QA};

  // ---- independent reference model (datasheet function table) ----
  reg [3:0] mq = 4'b0000;

  function [3:0] next_q(input [3:0] cur, input nl, input pn, input tn,
                        input up, input [3:0] d);
    begin
      if (!nl)                 next_q = d;
      else if (!pn && !tn)     next_q = up ? (cur + 4'd1) : (cur - 4'd1);
      else                     next_q = cur;
    end
  endfunction

  function ref_con(input [3:0] cur, input tn, input up);
    begin
      ref_con = ~(~tn & ((up & (cur == 4'd15)) | (~up & (cur == 4'd0))));
    end
  endfunction

  task clk_rise; begin #5 CP = 1'b1; #1; end endtask
  task clk_fall; begin #5 CP = 1'b0; #1; end endtask

  // one edge, model advanced in lock-step, both outputs checked
  task step;
    begin
      mq = next_q(mq, NL, PN, TN, UP, din);
      clk_rise;
      `CHK("count/load/hold matches the model", q, mq)
      `CHK("CON matches the model", CON, ref_con(mq, TN, UP))
      clk_fall;
    end
  endtask

  task force_load(input [3:0] v);
    begin
      NL = 1'b0; din = v;
      step;
      NL = 1'b1;
    end
  endtask

  integer i;
  integer seed;

  initial begin
    $dumpfile("M169C_tb.vcd");
    $dumpvars(0, M169C_tb);
  end

  initial begin
    seed = 32'h0BADF00D;
    #1;

    // ---- 1. synchronous load establishes a known state ----
    force_load(4'b0000);
    `CHK("loaded 0000", q, 4'b0000)

    // ---- 2. NO CLOCK EDGE AT ALL: the count must not move ----
    NL = 1'b1; PN = 1'b0; TN = 1'b0; UP = 1'b1;
    #30;
    `CHK("no clock edge: q holds", q, 4'b0000)
    // ... but CON is combinational and DOES follow UP/TN with no edge
    UP = 1'b0; #2;
    `CHK("CON is combinational: 0000 counting DOWN is terminal", CON, 1'b0)
    UP = 1'b1; #2;
    `CHK("CON: 0000 counting UP is not terminal", CON, 1'b1)
    TN = 1'b1; UP = 1'b0; #2;
    `CHK("CON is gated by TN: TN=1 forces CON high", CON, 1'b1)
    TN = 1'b0; UP = 1'b1; #2;

    // ---- 3. 40 consecutive UP counts (two and a half wraps) ----
    UP = 1'b1; PN = 1'b0; TN = 1'b0; NL = 1'b1;
    for (i = 0; i < 40; i = i + 1) step;

    // ---- 4. 40 consecutive DOWN counts ----
    UP = 1'b0;
    for (i = 0; i < 40; i = i + 1) step;

    // ---- 5. HOLD via each enable separately ----
    UP = 1'b1;
    force_load(4'b1001);
    PN = 1'b1; TN = 1'b0;
    for (i = 0; i < 3; i = i + 1) step;
    `CHK("PN=1 holds the count", q, 4'b1001)
    PN = 1'b0; TN = 1'b1;
    for (i = 0; i < 3; i = i + 1) step;
    `CHK("TN=1 holds the count", q, 4'b1001)
    PN = 1'b1; TN = 1'b1;
    for (i = 0; i < 3; i = i + 1) step;
    `CHK("both enables off holds the count", q, 4'b1001)

    // ---- 6. LOAD WINS over both enables being off ----
    NL = 1'b0; din = 4'b0110; PN = 1'b1; TN = 1'b1;
    step;
    `CHK("load overrides PN=1 and TN=1", q, 4'b0110)
    NL = 1'b1; PN = 1'b0; TN = 1'b0;

    // ---- 7. the falling edge must do nothing ----
    UP = 1'b1;
    clk_rise;
    mq = next_q(mq, NL, PN, TN, UP, din);
    `CHK("rising edge counts", q, mq)
    clk_fall;
    `CHK("falling edge does not count", q, mq)

    // ---- 8. inputs churning between edges: only the pre-edge value counts --
    NL = 1'b0;
    din = 4'b0001; #2;
    din = 4'b1110; #2;
    din = 4'b1010; #2;
    step;
    `CHK("mid-cycle load-data churn: the final value is loaded", q, 4'b1010)
    NL = 1'b1;
    UP = 1'b1; #2; UP = 1'b0; #2; UP = 1'b1; #2;
    step;
    `CHK("mid-cycle UP churn: the final direction is used", q, 4'b1011)

    // ---- 9. randomised 300-step walk over load / hold / direction ----
    // The VCD is a committed timing diagram, so the random bulk is kept OUT
    // of it - everything up to here is the readable story (load, count up
    // through the wrap, count down, hold, load-wins, edge polarity).
    $dumpoff;
    for (i = 0; i < 300; i = i + 1) begin
      NL  = ($random(seed) % 8) == 0;       // load about 1 step in 8
      NL  = ~NL;                            // NL is active LOW
      PN  = ($random(seed) % 4) == 0;
      TN  = ($random(seed) % 4) == 0;
      UP  = $random(seed);
      din = $random(seed);
      step;
    end
    $dumpon;

    $display("M169C_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire
