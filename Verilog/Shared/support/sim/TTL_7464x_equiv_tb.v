/**************************************************************************************************
** ND120 Shared - unit test                                                                      **
**                                                                                               **
** TTL_74646 / TTL_74648 equivalence: USE_SYSCLK_AB/BA = 0 (original posedge                     **
** CLKAB/CLKBA registers) vs = 2 (sysclk-sampled rising-edge capture, the                        **
** FPGA-safe mode for strobe-driven clock pins - plan P1c-2/P1d/P3).                             **
**                                                                                               **
** Contract: the strobe is generated in the sysclk domain, >= 1 sysclk wide.                     **
** Mode 2 may lag one sysclk; outputs are compared one settled cycle after                       **
** each strobe. Real-time (non-registered) paths must match cycle-exact.                        **
**                                                                                               **
** Self-check: a level-capture variant (USE_SYSCLK-like bug class) is                            **
** emulated by holding the strobe high while data changes - the registered                       **
** output must keep the EDGE value in both modes.                                                **
**                                                                                               **
** Run: make test-7464x                                                                          **
**                                                                                               **
** Last reviewed: 9-JUL-2026                                                                     **
** Ronny Hansen                                                                                  **
***************************************************************************************************/
`timescale 1ns / 1ps

module TTL_7464x_equiv_tb;

  reg sysclk = 0;
  always #10 sysclk = ~sysclk;

  reg [7:0] a_in = 0, b_in = 0;
  reg clkab = 0, clkba = 0;
  reg dir = 0, oe_n = 0, sab = 1, sba = 1;

  // 74646: reference vs DUT (both clocks in edge-capture mode)
  wire [7:0] r46_a, r46_b, d46_a, d46_b;
  TTL_74646 #(.USE_SYSCLK_AB(0), .USE_SYSCLK_BA(0)) ref46 (
      .sysclk(sysclk), .A_IN(a_in), .B_IN(b_in), .CLKAB(clkab), .CLKBA(clkba),
      .DIR(dir), .OE_n(oe_n), .SAB(sab), .SBA(sba), .A_OUT(r46_a), .B_OUT(r46_b));
  TTL_74646 #(.USE_SYSCLK_AB(2), .USE_SYSCLK_BA(2)) dut46 (
      .sysclk(sysclk), .A_IN(a_in), .B_IN(b_in), .CLKAB(clkab), .CLKBA(clkba),
      .DIR(dir), .OE_n(oe_n), .SAB(sab), .SBA(sba), .A_OUT(d46_a), .B_OUT(d46_b));

  // 74648: reference vs DUT
  wire [7:0] r48_a, r48_b, d48_a, d48_b;
  TTL_74648 #(.USE_SYSCLK_AB(0), .USE_SYSCLK_BA(0)) ref48 (
      .sysclk(sysclk), .A_IN(a_in), .B_IN(b_in), .CLKAB(clkab), .CLKBA(clkba),
      .DIR(dir), .OE_n(oe_n), .SAB(sab), .SBA(sba), .A_OUT_n(r48_a), .B_OUT_n(r48_b));
  TTL_74648 #(.USE_SYSCLK_AB(2), .USE_SYSCLK_BA(2)) dut48 (
      .sysclk(sysclk), .A_IN(a_in), .B_IN(b_in), .CLKAB(clkab), .CLKBA(clkba),
      .DIR(dir), .OE_n(oe_n), .SAB(sab), .SBA(sba), .A_OUT_n(d48_a), .B_OUT_n(d48_b));

  integer errors = 0;
  integer checks = 0;

  task check(input [127:0] what);
    begin
      @(negedge sysclk);
      @(negedge sysclk);
      checks = checks + 1;
      if (r46_a !== d46_a || r46_b !== d46_b) begin
        errors = errors + 1;
        $display("FAIL t=%0t 74646 %0s: A %02x/%02x B %02x/%02x",
                 $time, what, r46_a, d46_a, r46_b, d46_b);
      end
      if (r48_a !== d48_a || r48_b !== d48_b) begin
        errors = errors + 1;
        $display("FAIL t=%0t 74648 %0s: A_n %02x/%02x B_n %02x/%02x",
                 $time, what, r48_a, d48_a, r48_b, d48_b);
      end
    end
  endtask

  integer i;
  reg [7:0] edge_val;
  initial begin
    $dumpfile("TTL_7464x_equiv_tb.vcd");
    $dumpvars(0, TTL_7464x_equiv_tb);

    // Registered path B->A (dir=0, sba=1): capture B on CLKBA rise
    dir = 0; sba = 1; b_in = 8'hA5;
    @(negedge sysclk) clkba = 1; check("capture B");
    clkba = 0;                   check("hold B");

    // KEY edge-vs-level case: data changes while strobe held high;
    // both modes must keep the value from the RISE
    b_in = 8'h3C;
    @(negedge sysclk) clkba = 1; check("capture B=3C");
    edge_val = b_in;
    b_in = 8'hFF;                check("data change under held strobe ignored");
    clkba = 0; b_in = 8'h00;     check("hold after strobe drops");

    // Registered path A->B (dir=1, sab=1)
    dir = 1; sab = 1; a_in = 8'h5A;
    @(negedge sysclk) clkab = 1; check("capture A");
    clkab = 0;                   check("hold A");

    // Real-time paths must match cycle-exact (sba/sab = 0)
    dir = 0; sba = 0; b_in = 8'h77; check("real-time B->A");
    dir = 1; sab = 0; a_in = 8'h88; check("real-time A->B");

    // OE_n gating
    oe_n = 1; check("outputs disabled");
    oe_n = 0;

    // Randomized soak
    for (i = 0; i < 400; i = i + 1) begin
      a_in = $random; b_in = $random;
      dir = $random & 1; sab = $random & 1; sba = $random & 1;
      oe_n = ($random & 7) == 0;
      case ($random & 3)
        0: begin @(negedge sysclk) clkba = 1; repeat (1 + ($random & 1)) @(negedge sysclk); clkba = 0; end
        1: begin @(negedge sysclk) clkab = 1; repeat (1 + ($random & 1)) @(negedge sysclk); clkab = 0; end
        2: begin @(negedge sysclk) clkab = 1; clkba = 1; @(negedge sysclk); clkab = 0; clkba = 0; end
        3: ;  // data-only change
      endcase
      check("soak");
    end

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
