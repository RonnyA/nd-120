/****************************************************************************
** SR44 - self-checking functional testbench                              **
**                                                                         **
** SR44 is the 4-bit parallel-load / serial-shift register, built from     **
** four Multiplexer_2 cells feeding four                                   **
** D_FLIPFLOP #(.InvertClockEnable(0)) flops. The mux wiring in SR44.v is: **
**     PLEXERS_1: sel=L, in1=A,  in0=SI -> QA.d = L ? A : SI               **
**     PLEXERS_2: sel=L, in1=B,  in0=QA -> QB.d = L ? B : QA               **
**     PLEXERS_3: sel=L, in1=C,  in0=QB -> QC.d = L ? C : QB               **
**     PLEXERS_4: sel=L, in1=D,  in0=QC -> QD.d = L ? D : QC               **
** so L=1 loads {A,B,C,D} and L=0 shifts SI -> QA -> QB -> QC -> QD, one   **
** position per RISING edge of CP.                                         **
**                                                                         **
** THE SHIFT DIRECTION IS THE POINT. A register that shifted the other way **
** (QD -> QC -> QB -> QA) would still pass a "load then read back" test    **
** and still pass an all-ones or all-zeros shift. The SERIAL WALK section  **
** here pushes a single 1 through the chain and checks its position after  **
** each edge, so the wrong direction fails on the first check and names    **
** itself. The same section proves the four flops do not all sample the    **
** SAME source: a register that copied SI into every stage would show      **
** 1111 after one edge instead of 0001.                                    **
**                                                                         **
** Covered: power-up, parallel load of all 16 patterns, serial walk in     **
** both polarities, L flipping between load and shift on successive        **
** edges, hold with NO clock edge at all, the falling edge doing nothing,  **
** and inputs churning between edges. SR44 has NO reset, NO preset and NO  **
** clock enable, so those cases do not exist on this cell.                 **
**                                                                         **
** BUILD MODE: no `ifdef anywhere in SR44.v, D_FLIPFLOP.v or               **
** Multiplexer_2.v - latch mode and -DFPGA_FF_MODE must be identical.      **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-sr44                      **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module SR44_tb;

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
  reg L = 1'b1;
  reg SI = 1'b0;
  reg [3:0] din = 4'b0000;          // {D,C,B,A}
  wire QA, QAN, QB, QBN, QC, QCN, QD, QDN;

  SR44 DUT (
      .CP(CP), .L(L), .SI(SI),
      .A(din[0]), .B(din[1]), .C(din[2]), .D(din[3]),
      .QA(QA), .QAN(QAN), .QB(QB), .QBN(QBN),
      .QC(QC), .QCN(QCN), .QD(QD), .QDN(QDN)
  );

  // q[0]=QA (first stage) .. q[3]=QD (last stage)
  wire [3:0] q  = {QD, QC, QB, QA};
  wire [3:0] qn = {QDN, QCN, QBN, QAN};

  task clk_rise; begin #5 CP = 1'b1; #1; end endtask
  task clk_fall; begin #5 CP = 1'b0; #1; end endtask
  task edge_cp;  begin clk_rise; clk_fall; end endtask

  task par_load(input [3:0] v);
    begin
      L = 1'b1;
      din = v;
      edge_cp;
    end
  endtask

  task shift_in(input s);
    begin
      L = 1'b0;
      SI = s;
      edge_cp;
    end
  endtask

  integer i;

  initial begin
    $dumpfile("SR44_tb.vcd");
    $dumpvars(0, SR44_tb);
  end

  initial begin
    #1;
    // D_FLIPFLOP initialises its state to 0, so SR44 powers up 0000
    `CHK("power-up q", q, 4'b0000)
    `CHK("power-up complements", qn, 4'b1111)

    // ---- no clock edge at all ----
    L = 1'b1; din = 4'b1111; #20;
    `CHK("no clock edge: parallel load does not happen", q, 4'b0000)
    L = 1'b0; SI = 1'b1; #20;
    `CHK("no clock edge: shift does not happen", q, 4'b0000)

    // ---- parallel load, all 16 patterns ----
    for (i = 0; i < 16; i = i + 1) begin
      par_load(i[3:0]);
      `CHK("parallel load pattern", q, i[3:0])
      `CHK("parallel load complements", qn, ~i[3:0])
    end

    // ---- SERIAL WALK: one 1 pushed through a cleared register ----
    par_load(4'b0000);
    shift_in(1'b1);
    `CHK("walk step 1: the 1 is in QA only", q, 4'b0001)
    shift_in(1'b0);
    `CHK("walk step 2: the 1 moved to QB", q, 4'b0010)
    shift_in(1'b0);
    `CHK("walk step 3: the 1 moved to QC", q, 4'b0100)
    shift_in(1'b0);
    `CHK("walk step 4: the 1 moved to QD", q, 4'b1000)
    shift_in(1'b0);
    `CHK("walk step 5: the 1 shifted off the end", q, 4'b0000)

    // ---- SERIAL WALK, opposite polarity: one 0 through a filled register --
    par_load(4'b1111);
    shift_in(1'b0);
    `CHK("zero walk step 1", q, 4'b1110)
    shift_in(1'b1);
    `CHK("zero walk step 2", q, 4'b1101)
    shift_in(1'b1);
    `CHK("zero walk step 3", q, 4'b1011)
    shift_in(1'b1);
    `CHK("zero walk step 4", q, 4'b0111)
    shift_in(1'b1);
    `CHK("zero walk step 5: back to all ones", q, 4'b1111)

    // ---- SI is ignored while L is high ----
    par_load(4'b0000);
    L = 1'b1; din = 4'b0000; SI = 1'b1;
    edge_cp;
    `CHK("L=1: SI must not reach QA", q, 4'b0000)

    // ---- the parallel inputs are ignored while L is low ----
    L = 1'b0; din = 4'b1111; SI = 1'b0;
    edge_cp;
    `CHK("L=0: A/B/C/D must not reach the register", q, 4'b0000)

    // ---- L flipping between load and shift on successive edges ----
    par_load(4'b0101);              // 0101
    shift_in(1'b1);                 // {101,1} = 1011
    `CHK("shift after load", q, 4'b1011)
    par_load(4'b0011);              // straight back to a load
    `CHK("load immediately after a shift", q, 4'b0011)
    shift_in(1'b0);                 // {011,0} = 0110
    `CHK("shift immediately after a load", q, 4'b0110)

    // ---- the falling edge must do nothing ----
    L = 1'b1; din = 4'b1001;
    clk_rise;
    `CHK("rising edge loads", q, 4'b1001)
    din = 4'b0110;
    clk_fall;
    `CHK("falling edge does not load", q, 4'b1001)

    // ---- inputs churning between edges: only the final value counts ----
    L = 1'b0;
    SI = 1'b1; #2;
    SI = 1'b0; #2;
    SI = 1'b1; #2;
    clk_rise;
    `CHK("mid-cycle SI churn: final SI=1 is the one shifted in", q, 4'b0011)
    clk_fall;

    `CHK("final complements", qn, ~q)

    $display("SR44_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire
