/****************************************************************************
** R81_EN - self-checking functional testbench, both modes                 **
**                                                                         **
**   USE_ENABLE=0 (default) wraps R81 - note R81, NOT R81P, even though    **
**       the two files are behaviourally identical and both exist. Every   **
**       posedge CP loads {H..A} unconditionally; sysclk and EN unused.    **
**   USE_ENABLE=1 : posedge sysclk, load only while EN is high; the CP     **
**       pin is unused.                                                    **
**                                                                         **
** No reset and no preset pin in either mode, so the                       **
** set-and-reset-together case does not exist on this cell.                **
**                                                                         **
** POWER-UP DIFFERS BETWEEN THE MODES, and it is a real difference:        **
**   mode 0 -> R81 declares `reg [7:0] reg8bit;` with NO initialiser, so   **
**             the outputs come up UNKNOWN (x)                             **
**   mode 1 -> the wrapper declares `reg [7:0] q_r = 8'b0`, so 0x00        **
**   Verilator forces x to 0 and hides the difference; iverilog does not.  **
**   Both are asserted.                                                    **
**                                                                         **
** Bit order (A->QA .. H->QH) is checked with a walking one and a walking  **
** zero in both modes. ENABLE HELD LOW across many sysclk edges, no clock  **
** edge at all, the falling CP edge, and data churning between edges are   **
** all covered.                                                            **
**                                                                         **
** BUILD MODE: no `ifdef - latch mode and -DFPGA_FF_MODE are identical.    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-r81en                     **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module R81_EN_tb;

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
  reg [7:0] din = 8'h00;

  wire QA0,QAN0,QB0,QBN0,QC0,QCN0,QD0,QDN0,QE0,QEN0,QF0,QFN0,QG0,QGN0,QH0,QHN0;
  wire QA1,QAN1,QB1,QBN1,QC1,QCN1,QD1,QDN1,QE1,QEN1,QF1,QFN1,QG1,QGN1,QH1,QHN1;

  R81_EN #(.USE_ENABLE(0)) U_M0 (
      .sysclk(sysclk), .EN(EN), .CP(CP),
      .A(din[0]), .B(din[1]), .C(din[2]), .D(din[3]),
      .E(din[4]), .F(din[5]), .G(din[6]), .H(din[7]),
      .QA(QA0), .QAN(QAN0), .QB(QB0), .QBN(QBN0),
      .QC(QC0), .QCN(QCN0), .QD(QD0), .QDN(QDN0),
      .QE(QE0), .QEN(QEN0), .QF(QF0), .QFN(QFN0),
      .QG(QG0), .QGN(QGN0), .QH(QH0), .QHN(QHN0));

  R81_EN #(.USE_ENABLE(1)) U_M1 (
      .sysclk(sysclk), .EN(EN), .CP(CP),
      .A(din[0]), .B(din[1]), .C(din[2]), .D(din[3]),
      .E(din[4]), .F(din[5]), .G(din[6]), .H(din[7]),
      .QA(QA1), .QAN(QAN1), .QB(QB1), .QBN(QBN1),
      .QC(QC1), .QCN(QCN1), .QD(QD1), .QDN(QDN1),
      .QE(QE1), .QEN(QEN1), .QF(QF1), .QFN(QFN1),
      .QG(QG1), .QGN(QGN1), .QH(QH1), .QHN(QHN1));

  wire [7:0] q0  = {QH0,QG0,QF0,QE0,QD0,QC0,QB0,QA0};
  wire [7:0] qn0 = {QHN0,QGN0,QFN0,QEN0,QDN0,QCN0,QBN0,QAN0};
  wire [7:0] q1  = {QH1,QG1,QF1,QE1,QD1,QC1,QB1,QA1};
  wire [7:0] qn1 = {QHN1,QGN1,QFN1,QEN1,QDN1,QCN1,QBN1,QAN1};

  task sys_tick; begin #5 sysclk = 1'b1; #5 sysclk = 1'b0; #1; end endtask
  task cp_rise;  begin #5 CP = 1'b1; #1; end endtask
  task cp_fall;  begin #5 CP = 1'b0; #1; end endtask
  task load(input [7:0] v);
    begin
      din = v; #2;
      cp_rise; cp_fall;
      sys_tick;
    end
  endtask

  integer i;
  reg [7:0] pat;

  initial begin
    $dumpfile("R81_EN_tb.vcd");
    $dumpvars(0, R81_EN_tb);
  end

  initial begin
    #1;
    `CHK("mode0 powers up UNKNOWN (R81 has no initialiser)", q0, 8'bxxxxxxxx)
    `CHK("mode1 powers up 0x00 (wrapper initialises q_r)",   q1, 8'h00)

    // ---- 1. NO CLOCK EDGE AT ALL ----
    din = 8'hFF; #20;
    `CHK("no edge: mode0 holds", q0, 8'bxxxxxxxx)
    `CHK("no edge: mode1 holds", q1, 8'h00)

    // ---- 2. each mode listens to its own clock only ----
    din = 8'hA5; #2;
    cp_rise;
    `CHK("posedge CP: mode0 loads", q0, 8'hA5)
    `CHK("posedge CP: mode1 ignores CP", q1, 8'h00)
    cp_fall;
    sys_tick;
    `CHK("posedge sysclk with EN high: mode1 loads", q1, 8'hA5)

    // ---- 3. EN irrelevant in mode 0, decisive in mode 1 ----
    EN = 1'b0; din = 8'h3C; #2;
    cp_rise; cp_fall;
    `CHK("mode0 loads with EN low", q0, 8'h3C)
    sys_tick; sys_tick; sys_tick;
    `CHK("mode1 EN held low: no load at all", q1, 8'hA5)
    EN = 1'b1; sys_tick;
    `CHK("mode1 loads when re-enabled", q1, 8'h3C)

    // ---- 4. WALKING ONE and WALKING ZERO, both modes ----
    for (i = 0; i < 8; i = i + 1) begin
      load(8'h01 << i);
      `CHK("mode0 walking one", q0, 8'h01 << i)
      `CHK("mode1 walking one", q1, 8'h01 << i)
    end
    for (i = 0; i < 8; i = i + 1) begin
      load(~(8'h01 << i));
      `CHK("mode0 walking zero", q0, ~(8'h01 << i))
      `CHK("mode1 walking zero", q1, ~(8'h01 << i))
    end

    // ---- 5. 32 deterministic pseudo-random patterns (kept out of the VCD) --
    $dumpoff;
    pat = 8'h5A;
    for (i = 0; i < 32; i = i + 1) begin
      pat = {pat[6:0], pat[7] ^ pat[5] ^ pat[4] ^ pat[3]};
      load(pat);
      `CHK("mode0 pattern", q0, pat)
      `CHK("mode1 pattern", q1, pat)
      `CHK("mode0 complements", qn0, ~pat)
      `CHK("mode1 complements", qn1, ~pat)
    end
    $dumpon;

    // ---- 6. falling CP does nothing (mode 0) ----
    din = 8'h0F; #2; cp_rise;
    `CHK("mode0 rising CP loads", q0, 8'h0F)
    din = 8'hF0; cp_fall;
    `CHK("mode0 falling CP does not load", q0, 8'h0F)

    // ---- 7. data churning between edges ----
    din = 8'h11; #2; din = 8'h22; #2; din = 8'h44; #2;
    cp_rise; cp_fall; sys_tick;
    `CHK("mode0 takes the final value", q0, 8'h44)
    `CHK("mode1 takes the final value", q1, 8'h44)

    $display("R81_EN_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire
