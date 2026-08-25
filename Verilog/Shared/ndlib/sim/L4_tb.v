/****************************************************************************
** L4 - self-checking functional testbench, BOTH BUILD MODES               **
**                                                                         **
** L4 is the 4-bit transparent latch. Like LATCH.v (and L8.v) its          **
** behaviour is switched by USE_TRANSPARENT_LATCHES, NOT by FPGA_FF_MODE.  **
**                                                                         **
**   -DUSE_TRANSPARENT_LATCHES  (original 1988 hardware model)             **
**       always @(*) if (L) reg4bit = {D,C,B,A};   Q* = reg4bit            **
**       True level-sensitive latch. sysclk is IGNORED.                    **
**                                                                         **
**   default, no define      (the FPGA path that actually ships)           **
**       always @(posedge sysclk) if (L) reg4bit <= {D,C,B,A};             **
**       QA = L ? A : reg4bit[0];  (and likewise B/C/D)                    **
**       Transparent through a mux while L is high, but the value it       **
**       KEEPS is the one sampled on the last sysclk rising edge inside    **
**       the L window.                                                     **
**                                                                         **
** IDENTICAL IN BOTH MODES: while L is high the outputs track {A,B,C,D}    **
** with no clock edge needed; while L is low the inputs are ignored; QxN   **
** is always the exact complement of Qx.                                   **
**                                                                         **
** DIFFERENT BETWEEN THE MODES (the reason this file exists):              **
**   (1) inputs move after the last sysclk edge of the L window and then   **
**       L falls -> transparent mode keeps the NEW data, the FPGA path     **
**       keeps the sysclk-SAMPLED data.                                    **
**   (2) an L pulse that opens and closes entirely between two sysclk      **
**       rising edges -> transparent mode captures it, the FPGA path       **
**       misses it completely and reverts.                                 **
**   Each is asserted with the opposite expected value per mode, so a      **
**   build that took the wrong branch fails instead of passing quietly.    **
**                                                                         **
** FINDING, both modes: reg4bit in L4.v has NO initialiser, so L4 powers   **
** up UNKNOWN (x) where LATCH.v powers up 0. Verilator squashes x to 0 and **
** the FPGA tool picks its own value, so a reader that runs before the     **
** first load sees different data in sim and on silicon. Asserted as x.    **
**                                                                         **
** ALSO NOTED: the sys_rst_n port is declared and never read in either     **
** branch. This tb drives it both ways across a capture to prove it has    **
** no effect, so nobody wires a reset to it expecting one.                 **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-l4                        **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

`ifdef USE_TRANSPARENT_LATCHES
  `define L4_MODE_NAME "TRANSPARENT (USE_TRANSPARENT_LATCHES defined)"
`else
  `define L4_MODE_NAME "FPGA-SYSCLK (default build)"
`endif

module L4_tb;

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
  reg sys_rst_n = 1'b1;
  reg L = 1'b0;
  reg [3:0] din = 4'b0000;      // din = {D,C,B,A}
  wire QA, QAN, QB, QBN, QC, QCN, QD, QDN;

  L4 DUT (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n), .L(L),
      .A(din[0]), .B(din[1]), .C(din[2]), .D(din[3]),
      .QA(QA), .QAN(QAN), .QB(QB), .QBN(QBN),
      .QC(QC), .QCN(QCN), .QD(QD), .QDN(QDN)
  );

  wire [3:0] q  = {QD, QC, QB, QA};
  wire [3:0] qn = {QDN, QCN, QBN, QAN};

  task sysclk_tick;
    begin
      #5 sysclk = 1'b1;
      #5 sysclk = 1'b0;
      #1;
    end
  endtask

  task check_qn;
    begin
      `CHK("QxN complement of Qx", qn, ~q)
    end
  endtask

  initial begin
    $dumpfile("L4_tb.vcd");
    $dumpvars(0, L4_tb);
  end

  initial begin
    $display("L4_tb: build mode = %0s", `L4_MODE_NAME);
    #1;

    // ---- 1. power-up. FINDING: reg4bit in L4.v has NO initial value, so
    //         the outputs come up UNKNOWN (x), unlike LATCH.v whose regD is
    //         declared with an initialiser. Verilator forces x to 0 and the
    //         FPGA tools pick their own power-up value, so anything that
    //         reads an L4 before its first load is reading a value that is
    //         not the same in sim and on silicon. Asserted as x here so the
    //         day somebody adds an initialiser this check tells them. ----
    `CHK("power-up q is UNKNOWN (no initialiser in L4.v)", q, 4'bxxxx)
    check_qn;

    // ---- 2. L low: inputs ignored, with and without sysclk edges ----
    din = 4'b1011; #5;
    `CHK("L low, no sysclk edge: q holds (still x)", q, 4'bxxxx)
    sysclk_tick; sysclk_tick;
    `CHK("L low, sysclk running: q holds (still x)", q, 4'bxxxx)
    check_qn;

    // ---- 3. transparency with no clock edge at all ----
    L = 1'b1; #2;
    `CHK("L rises: q goes transparent", q, 4'b1011)
    din = 4'b0100; #2;
    `CHK("L high, inputs change, no sysclk edge: q follows", q, 4'b0100)
    din = 4'b1111; #2;
    `CHK("L high, all ones: q follows", q, 4'b1111)
    check_qn;

    // ---- 4. sys_rst_n is not wired to anything ----
    sys_rst_n = 1'b0; #3;
    `CHK("sys_rst_n low does not clear the outputs", q, 4'b1111)
    sysclk_tick;
    `CHK("sys_rst_n low across a sysclk edge still does nothing", q, 4'b1111)
    sys_rst_n = 1'b1; #2;

    // ---- 5. clean close: sysclk edge inside the window, data steady ----
    L = 1'b0; #2;
    `CHK("clean close keeps 1111 in BOTH modes", q, 4'b1111)
    check_qn;

    // ---- 6. DIVERGENCE (1): data moves after the last sysclk edge ----
    L = 1'b1; din = 4'b0101; #1;
    sysclk_tick;                  // FPGA path samples 0101 here
    din = 4'b1010; #2;            // no sysclk edge after this
    `CHK("still transparent before the fall", q, 4'b1010)
    L = 1'b0; #2;
`ifdef USE_TRANSPARENT_LATCHES
    `CHK("DIVERGENCE 1 - transparent mode keeps the NEW data 1010", q, 4'b1010)
`else
    `CHK("DIVERGENCE 1 - FPGA path keeps the SAMPLED data 0101", q, 4'b0101)
`endif
    check_qn;

    // ---- 7. DIVERGENCE (2): an L pulse between two sysclk edges ----
    L = 1'b1; din = 4'b0000; #1; sysclk_tick; L = 1'b0; #2;
    `CHK("both modes now hold 0000", q, 4'b0000)
    din = 4'b1100;
    L = 1'b1; #2;
    `CHK("during the pulse both modes show 1100", q, 4'b1100)
    L = 1'b0; #2;
`ifdef USE_TRANSPARENT_LATCHES
    `CHK("DIVERGENCE 2 - transparent mode captured the pulse", q, 4'b1100)
`else
    `CHK("DIVERGENCE 2 - FPGA path missed the pulse, reverts to 0000", q, 4'b0000)
`endif
    check_qn;

    // ---- 8. wide window: q must equal the inputs at every instant ----
    L = 1'b1;
    din = 4'b0001; #1; `CHK("wide window 0001", q, 4'b0001)
    sysclk_tick;
    din = 4'b0010; #1; `CHK("wide window 0010", q, 4'b0010)
    sysclk_tick;
    din = 4'b0100; #1; `CHK("wide window 0100", q, 4'b0100)
    sysclk_tick;
    din = 4'b1000; #1; `CHK("wide window 1000", q, 4'b1000)
    sysclk_tick;                  // sample 1000
    L = 1'b0; #2;
    `CHK("wide window closed cleanly on 1000 in BOTH modes", q, 4'b1000)

    // ---- 9. no leak after the close ----
    din = 4'b0111; sysclk_tick; sysclk_tick;
    `CHK("no leak with L low", q, 4'b1000)
    check_qn;

    $display("L4_tb (%0s): checks=%0d failures=%0d", `L4_MODE_NAME, checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire
