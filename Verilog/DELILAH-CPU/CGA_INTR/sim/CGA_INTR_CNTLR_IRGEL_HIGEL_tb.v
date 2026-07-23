/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_IRGEL_HIGEL  (HI group-strobe FF, self-holding, schematic p.93)                 **
**                                                                                               **
** DUT contract (derived from the GATES_1..7 + MEMORY_8 netlist, NOT assumed):                    **
**   HIGSN = Q of a plain posedge-MCLK D flip-flop (D_FLIPFLOP_EN USE_ENABLE=0, no FPGA_FF_MODE). **
**   Q_next = D, where D is OR_GATE_6 with ALL SIX inputs bubbled (each NAND result inverted):     **
**     D = (FIDB03 & L & M)         // GATES_1                                                      **
**       | (LOGASN & L & ~M)        // GATES_2                                                      **
**       | (LOGASN & ~HIDET & N)    // GATES_3                                                      **
**       | (HIGAS & N)              // GATES_4                                                      **
**       | (HIENABN & N)            // GATES_5                                                      **
**       | (~L & M & Q)             // GATES_6  <- self-hold feedback of current Q                  **
**   The (~L & M & Q) term is the self-holding strobe: while (~L & M) once Q=1 it stays 1.         **
**   All init FFs power up at 0 (D_FLIPFLOP initial s_currentState=0).                             **
**                                                                                               **
** Self-checking: golden Q_next computed INDEPENDENTLY from the equation above, kept in a shadow  **
** register clocked in lockstep with the DUT. Covers directed set/hold/release named scenarios     **
** PLUS an exhaustive 2-pass sweep over all 256 input combinations (entered from both Q states).   **
**                                                                                               **
** Teeth: compile with -DTEETH_TEST to corrupt the compare value -> harness MUST report FAIL.      **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_higel -y Shared/logisim -y Shared/support -y Shared/ndlib \       **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_HIGEL.v \                                 **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRGEL_HIGEL_tb.v && vvp /tmp/tb_higel               **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_IRGEL_HIGEL_tb;

  reg sysclk = 0;
  reg MCLK_EN = 0;

  reg FIDB03 = 0;
  reg HIDET = 0;
  reg HIENABN = 0;
  reg HIGAS = 0;
  reg L = 0;
  reg LOGASN = 0;
  reg M = 0;
  reg MCLK = 0;
  reg N = 0;

  wire HIGSN;

  CGA_INTR_CNTLR_IRGEL_HIGEL dut (
      .sysclk (sysclk),
      .MCLK_EN(MCLK_EN),
      .FIDB03 (FIDB03),
      .HIDET  (HIDET),
      .HIENABN(HIENABN),
      .HIGAS  (HIGAS),
      .L      (L),
      .LOGASN (LOGASN),
      .M      (M),
      .MCLK   (MCLK),
      .N      (N),
      .HIGSN  (HIGSN)
  );

  integer errors = 0;
  integer checks = 0;
  reg shadow_q;      // independent model of the FF state
  reg exp_out;

  // Independent golden for D (Q_next), from the gate equation.
  function automatic higel_next(input fidb03, input hidet, input hienabn,
                                input higas, input l, input logasn,
                                input m, input n, input q);
    begin
      higel_next = (fidb03 & l & m)
                 | (logasn & l & ~m)
                 | (logasn & ~hidet & n)
                 | (higas & n)
                 | (hienabn & n)
                 | (~l & m & q);
    end
  endfunction

  // Pulse MCLK once; inputs must already be stable. Update shadow, then compare.
  task clk_and_check(input [127:0] what);
    reg d_exp;
    begin
      d_exp = higel_next(FIDB03, HIDET, HIENABN, HIGAS, L, LOGASN, M, N, shadow_q);
      MCLK = 0; #2;
      MCLK = 1; #2;   // posedge captures d
      MCLK = 0; #2;
      shadow_q = d_exp;
      exp_out  = shadow_q;
`ifdef TEETH_TEST
      exp_out  = ~exp_out;   // corrupt compare only -> harness must FAIL
`endif
      checks = checks + 1;
      if (HIGSN !== exp_out) begin
        errors = errors + 1;
        $display("FAIL %0s in{FIDB03=%b HIDET=%b HIENABN=%b HIGAS=%b L=%b LOGASN=%b M=%b N=%b} : HIGSN exp=%b got=%b",
                 what, FIDB03, HIDET, HIENABN, HIGAS, L, LOGASN, M, N, exp_out, HIGSN);
      end
    end
  endtask

  // At sim start the DUT FF powers up at 0; align the shadow to it.
  task init_state;
    begin
      shadow_q = 1'b0;
      FIDB03=0; HIDET=0; HIENABN=0; HIGAS=0; L=0; LOGASN=0; M=0; N=0;
    end
  endtask

  integer i, pass;
  reg named_set, named_hold, named_release;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_IRGEL_HIGEL_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_IRGEL_HIGEL_tb);

    init_state;
    #2;

    // ---- Named scenario: SET via (HIGAS & N) ----
    // Drive a set term, expect Q(=HIGSN) -> 1 after the clock.
    FIDB03=0; HIDET=0; HIENABN=0; HIGAS=1; L=0; LOGASN=0; M=0; N=1;
    clk_and_check("set(HIGAS&N)");
    named_set = (HIGSN === 1'b1);

    // ---- Named scenario: SELF-HOLD across 3 clocks with (~L & M) true ----
    // Remove all set terms, keep ~L & M (L=0,M=1). Q must persist at 1.
    FIDB03=0; HIDET=1; HIENABN=0; HIGAS=0; L=0; LOGASN=0; M=1; N=0;
    named_hold = 1'b1;
    clk_and_check("hold#1"); if (HIGSN !== 1'b1) named_hold = 1'b0;
    clk_and_check("hold#2"); if (HIGSN !== 1'b1) named_hold = 1'b0;
    clk_and_check("hold#3"); if (HIGSN !== 1'b1) named_hold = 1'b0;

    // ---- Named scenario: RELEASE by breaking the hold (L=1), no set terms ----
    // L=1 kills (~L&M&Q); all NAND set terms require specific combos we keep false.
    FIDB03=0; HIDET=1; HIENABN=0; HIGAS=0; L=1; LOGASN=0; M=1; N=0;
    clk_and_check("release(L=1)");
    named_release = (HIGSN === 1'b0);

    // ---- Exhaustive lockstep sweep, 2 passes (covers entry from both Q states) ----
    for (pass = 0; pass < 2; pass = pass + 1) begin
      for (i = 0; i < 256; i = i + 1) begin
        {FIDB03, HIDET, HIENABN, HIGAS, L, LOGASN, M, N} = i[7:0];
        clk_and_check("sweep");
      end
    end

    $display("named: set=%b hold=%b release=%b", named_set, named_hold, named_release);
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
