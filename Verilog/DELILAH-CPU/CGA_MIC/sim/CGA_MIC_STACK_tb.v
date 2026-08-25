/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MIC_STACK testbench (integration: 13 bit cells + control decode)  **
**                                                                       **
** Verification of the full 4-deep 13-bit microcode-return stack         **
** (74S482-style). Golden model re-derived from the gates:               **
**   decode: L = ~(SC3&SC4); S4S3N = SC4&~SC3; S4NS3N = ~SC4&~SC3        **
**   per-bit SR44 planes L0(QA/RET) L1(QB) L2(QC) L3(QD/DEEP bit12):     **
**     SC43=00 HOLD : all levels hold                                    **
**     SC43=01 POP  : L0<=L1, L1<=L2, L2<=L3, L3<=L3 (bottom duplicates) **
**     SC43=10 LOAD : L0<=ff(NEXT), L1..L3 hold                          **
**     SC43=11 PUSH : L0<=ff(NEXT), L1<=L0, L2<=L1, L3<=L2 (oldest lost) **
**   ff = NEXT captured per-bit at the MCLK RISE; levels update at the   **
**   MCLK FALL (SCLKN rise). RET = L0, DEEP = L3[12].                    **
**                                                                       **
**  1. Directed sequences: initial-state hold, 4 pushes / 6 pops         **
**     (incl. 2 bottom-duplication pops past the depth-4 boundary),      **
**     LOAD-replaces-top-only, hold, 5-push overflow (oldest dropped)    **
**     verified by popping everything back out. RET and DEEP checked     **
**     after every operation.                                            **
**  2. Rise/fall split: NEXT changed between the rise and the fall of a  **
**     PUSH - the value CAPTURED at the rise must be pushed.             **
**  3. 2000-operation fixed-seed LFSR soak (op+data both from the LFSR), **
**     entered through 4 canonical pushes that fully determine all 4     **
**     levels; running checksum of golden (RET,DEEP) vs the constant     **
**     from the independent Python model gen_mic_stack_golden.py.        **
**                                                                       **
** Sequential, two clock domains. Compile once plain and once with       **
** -DFPGA_FF_MODE - the Makefile target test-mic-stack runs both.        **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MIC_STACK_tb;

  reg         sysclk = 0;
  reg         MCLK_EN = 0;
  reg         MCLK_FALL_EN = 0;
  reg         MCLK = 0;
  reg         SC3 = 0;
  reg         SC4 = 0;
  reg  [12:0] NEXT_12_0 = 0;
  wire        DEEP;
  wire [12:0] RET_12_0;

  wire SCLKN = ~MCLK;

  localparam [1:0] OP_HOLD = 2'b00;  // {SC4,SC3}
  localparam [1:0] OP_POP  = 2'b01;
  localparam [1:0] OP_LOAD = 2'b10;
  localparam [1:0] OP_PUSH = 2'b11;

  integer errors = 0;
  integer checks = 0;
  integer i;

  // Golden model: 4 levels, L0=top(RET) .. L3=bottom(DEEP bit12), plus
  // the per-bit rise-captured NEXT value.
  reg [12:0] gl0, gl1, gl2, gl3;
  reg [12:0] gff;

  reg [31:0] lfsr = 32'hDEADBEEF;
  reg [31:0] cksum = 0;
  localparam [31:0] STACK_CKS = 32'h1DD57454;  // gen_mic_stack_golden.py

  CGA_MIC_STACK dut (
      .sysclk      (sysclk),
      .MCLK_EN     (MCLK_EN),
      .MCLK_FALL_EN(MCLK_FALL_EN),
      .MCLK        (MCLK),
      .SCLKN       (SCLKN),
      .SC3         (SC3),
      .SC4         (SC4),
      .NEXT_12_0   (NEXT_12_0),
      .DEEP        (DEEP),
      .RET_12_0    (RET_12_0)
  );

  always #5 sysclk = ~sysclk;

  task mclk_rise;
    begin
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 1;
      @(negedge sysclk);
      MCLK_EN = 0;
      gff = NEXT_12_0;
    end
  endtask

  task mclk_fall;
    begin
      @(negedge sysclk);
      MCLK_FALL_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 0;
      @(negedge sysclk);
      MCLK_FALL_EN = 0;
      model_fall({SC4, SC3});
    end
  endtask

  // Golden fall-time update (see header for the gate derivation).
  task model_fall(input [1:0] op);
    begin
      case (op)
        OP_HOLD: ;
        OP_POP:  begin gl0 = gl1; gl1 = gl2; gl2 = gl3; end
        OP_LOAD: gl0 = gff;
        OP_PUSH: begin gl3 = gl2; gl2 = gl1; gl1 = gl0; gl0 = gff; end
      endcase
    end
  endtask

  task check_outs(input [127:0] name);
    begin
      checks = checks + 1;
      if (RET_12_0 !== gl0) begin
        errors = errors + 1;
        $display("FAIL %0s: RET=%05o expected %05o", name, RET_12_0, gl0);
      end
      checks = checks + 1;
      if (DEEP !== gl3[12]) begin
        errors = errors + 1;
        $display("FAIL %0s: DEEP=%b expected %b", name, DEEP, gl3[12]);
      end
    end
  endtask

  task do_op(input [1:0] op, input [12:0] data, input [127:0] name);
    begin
      SC4       = op[1];
      SC3       = op[0];
      NEXT_12_0 = data;
      mclk_rise;
      mclk_fall;
      check_outs(name);
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_MIC_STACK_tb: FPGA_FF_MODE (sysclk enable capture)");
`else
    $display("CGA_MIC_STACK_tb: latch/CP mode (MCLK / ~MCLK edges)");
`endif
    gl0 = 0; gl1 = 0; gl2 = 0; gl3 = 0; gff = 0;
    #12;

    // ------------------------------------------------------------------
    // 1. Directed sequences (23 ops, RET+DEEP checked after each).
    // ------------------------------------------------------------------
    do_op(OP_HOLD, 13'o00000, "initial-hold");

    do_op(OP_PUSH, 13'o10421, "push1");
    do_op(OP_PUSH, 13'o05252, "push2");
    do_op(OP_PUSH, 13'o12525, "push3");
    do_op(OP_PUSH, 13'o17777, "push4");

    do_op(OP_POP, 13'o00000, "pop1");  // -> 12525
    do_op(OP_POP, 13'o00000, "pop2");  // -> 05252
    do_op(OP_POP, 13'o00000, "pop3");  // -> 10421
    do_op(OP_POP, 13'o00000, "pop4");  // -> old L3 (bottom)
    do_op(OP_POP, 13'o00000, "pop5-underflow-duplicates");
    do_op(OP_POP, 13'o00000, "pop6-underflow-duplicates");

    do_op(OP_PUSH, 13'o00707, "load-setup-push");
    do_op(OP_LOAD, 13'o00007, "load-replaces-top");
    do_op(OP_POP,  13'o00000, "pop-shows-below-load-intact");

    // Overflow: 5 pushes into a 4-deep stack, then pop everything out -
    // the FIRST push must be gone, the bottom then duplicates push2.
    do_op(OP_PUSH, 13'o00001, "ovf-push1");
    do_op(OP_PUSH, 13'o00002, "ovf-push2");
    do_op(OP_PUSH, 13'o00003, "ovf-push3");
    do_op(OP_PUSH, 13'o00004, "ovf-push4");
    do_op(OP_PUSH, 13'o00005, "ovf-push5");
    do_op(OP_POP,  13'o00000, "ovf-pop1");  // -> 4
    do_op(OP_POP,  13'o00000, "ovf-pop2");  // -> 3
    do_op(OP_POP,  13'o00000, "ovf-pop3");  // -> 2 (1 was dropped)
    do_op(OP_POP,  13'o00000, "ovf-pop4");  // -> 2 duplicated

    // ------------------------------------------------------------------
    // 2. Rise/fall split: the value captured at the rise is pushed even
    //    if NEXT changes before the fall.
    // ------------------------------------------------------------------
    SC4       = 1;
    SC3       = 1;
    NEXT_12_0 = 13'o12345;
    mclk_rise;
    NEXT_12_0 = 13'o00000;  // pin changes after capture; gff holds 12345
    mclk_fall;
    check_outs("push-uses-rise-captured-next");

    // ------------------------------------------------------------------
    // 3. LFSR soak: 4 canonical pushes (state fully determined), then
    //    2000 LFSR-driven ops. Golden (RET,DEEP) checksummed.
    // ------------------------------------------------------------------
    // The canonical pushes are NOT checksummed: DEEP (L3 bit12) still
    // depends on the prior directed-phase state until all 4 have landed.
    do_op(OP_PUSH, 13'o01111, "canon1");
    do_op(OP_PUSH, 13'o02222, "canon2");
    do_op(OP_PUSH, 13'o04444, "canon3");
    do_op(OP_PUSH, 13'o10707, "canon4");

    for (i = 0; i < 2000; i = i + 1) begin
      if (lfsr[0]) lfsr = (lfsr >> 1) ^ 32'hEDB88320;
      else lfsr = lfsr >> 1;
      do_op(lfsr[1:0], lfsr[14:2], "lfsr");
      cksum = cksum * 33 + {19'b0, gl0, gl3[12]};
    end

    checks = checks + 1;
    if (cksum !== STACK_CKS) begin
      errors = errors + 1;
      $display("FAIL checksum: got %08x expected %08x", cksum, STACK_CKS);
    end

    // ------------------------------------------------------------------
    // Verdict. Expected: (23 directed + 1 split + 4 canon + 2000 lfsr)
    // ops x 2 checks + 1 checksum = 4057.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == 4057)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 4057 checks)",
               errors, checks);
    $finish;
  end

endmodule
