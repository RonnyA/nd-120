/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_IRGEL_LOGEL  (LO group-strobe FF, self-holding, schematic p.94)                 **
**                                                                                               **
** DUT contract (derived from the GATES_1..5 + MEMORY_6 netlist, NOT assumed):                    **
**   LOGSN = Q of a plain posedge-MCLK D flip-flop (D_FLIPFLOP_EN USE_ENABLE=0, no FPGA_FF_MODE). **
**   Q_next = D, where D is OR_GATE_4 with ALL FOUR inputs bubbled (each NAND result inverted):    **
**     D = (FIDB04 & L & M)      // GATES_1                                                         **
**       | (LOGAS & N)           // GATES_2                                                         **
**       | (LIENABN & N)         // GATES_3                                                         **
**       | (~L & M & Q)          // GATES_4  <- self-hold feedback of current Q (LOGSN)             **
**   The (~L & M & Q) term is the self-holding strobe: while (~L & M) once Q=1 it stays 1.         **
**   FF powers up at 0.                                                                            **
**                                                                                               **
** Self-checking: golden Q_next computed INDEPENDENTLY, kept in a shadow register clocked in       **
** lockstep with the DUT. Directed set/hold/release named scenarios PLUS exhaustive 2-pass sweep   **
** over all 128 input combinations (entered from both Q states).                                   **
**                                                                                               **
** Teeth: compile with -DTEETH_TEST to corrupt the compare value -> harness MUST report FAIL.      **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_logel -y Shared/logisim -y Shared/support -y Shared/ndlib \       **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_LOGEL.v \                                 **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRGEL_LOGEL_tb.v && vvp /tmp/tb_logel               **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_IRGEL_LOGEL_tb;

  reg sysclk = 0;
  reg MCLK_EN = 0;

  reg FIDB04 = 0;
  reg L = 0;
  reg LIENABN = 0;
  reg LOGAS = 0;
  reg M = 0;
  reg MCLK = 0;
  reg N = 0;

  wire LOGSN;

  CGA_INTR_CNTLR_IRGEL_LOGEL dut (
      .sysclk (sysclk),
      .MCLK_EN(MCLK_EN),
      .FIDB04 (FIDB04),
      .L      (L),
      .LIENABN(LIENABN),
      .LOGAS  (LOGAS),
      .M      (M),
      .MCLK   (MCLK),
      .N      (N),
      .LOGSN  (LOGSN)
  );

  integer errors = 0;
  integer checks = 0;
  reg shadow_q;
  reg exp_out;

  function automatic logel_next(input fidb04, input l, input lienabn,
                                input logas, input m, input n, input q);
    begin
      logel_next = (fidb04 & l & m)
                 | (logas & n)
                 | (lienabn & n)
                 | (~l & m & q);
    end
  endfunction

  task clk_and_check(input [127:0] what);
    reg d_exp;
    begin
      d_exp = logel_next(FIDB04, L, LIENABN, LOGAS, M, N, shadow_q);
      MCLK = 0; #2;
      MCLK = 1; #2;
      MCLK = 0; #2;
      shadow_q = d_exp;
      exp_out  = shadow_q;
`ifdef TEETH_TEST
      exp_out  = ~exp_out;
`endif
      checks = checks + 1;
      if (LOGSN !== exp_out) begin
        errors = errors + 1;
        $display("FAIL %0s in{FIDB04=%b L=%b LIENABN=%b LOGAS=%b M=%b N=%b} : LOGSN exp=%b got=%b",
                 what, FIDB04, L, LIENABN, LOGAS, M, N, exp_out, LOGSN);
      end
    end
  endtask

  integer i, pass;
  reg named_set, named_hold, named_release;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_IRGEL_LOGEL_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_IRGEL_LOGEL_tb);

    shadow_q = 1'b0;
    FIDB04=0; L=0; LIENABN=0; LOGAS=0; M=0; N=0;
    #2;

    // ---- Named: SET via (LOGAS & N) ----
    FIDB04=0; L=0; LIENABN=0; LOGAS=1; M=0; N=1;
    clk_and_check("set(LOGAS&N)");
    named_set = (LOGSN === 1'b1);

    // ---- Named: SELF-HOLD across 3 clocks with (~L & M) ----
    FIDB04=0; L=0; LIENABN=0; LOGAS=0; M=1; N=0;
    named_hold = 1'b1;
    clk_and_check("hold#1"); if (LOGSN !== 1'b1) named_hold = 1'b0;
    clk_and_check("hold#2"); if (LOGSN !== 1'b1) named_hold = 1'b0;
    clk_and_check("hold#3"); if (LOGSN !== 1'b1) named_hold = 1'b0;

    // ---- Named: RELEASE by breaking hold (L=1), no set terms ----
    FIDB04=0; L=1; LIENABN=0; LOGAS=0; M=1; N=0;
    clk_and_check("release(L=1)");
    named_release = (LOGSN === 1'b0);

    // ---- Exhaustive lockstep sweep, 2 passes ----
    for (pass = 0; pass < 2; pass = pass + 1) begin
      for (i = 0; i < 128; i = i + 1) begin
        {FIDB04, L, LIENABN, LOGAS, M, N} = i[5:0];
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
