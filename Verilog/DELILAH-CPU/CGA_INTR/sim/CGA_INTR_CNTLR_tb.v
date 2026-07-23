/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - integration test                                       **
** CGA_INTR_CNTLR   (top-level PIC interrupt controller, schematic p.77)                          **
**                                                                                               **
** PRIMARY REGRESSION TARGET - the FIDBO -> status-write bit mapping, CGA_INTR_CNTLR.v ~129-131:  **
**     assign s_fidbo_2_0[0] = s_fidbo_15_0[0];                                                    **
**     assign s_fidbo_2_0[1] = s_fidbo_15_0[1];                                                    **
**     assign s_fidbo_2_0[2] = s_fidbo_15_0[2];   // STRAIGHT THROUGH - NO SWAP                     **
**   A recently-fixed transcription bug (docs/RUN-level14-livelock-analysis.md, 15-JUL) had        **
**   bits 1 and 2 SWAPPED here (s_fidbo_2_0[1]=FIDBO[2], [2]=FIDBO[1]). That corrupted the         **
**   TRA IIC status fence (VECGEN.FIDBO_2_0 -> HISIN/LOSIN = the microcode LDSTAT value) and       **
**   made an IOX interrupt decode as MOR (IIC 11 vs 7). This tb probes the internal wire           **
**   dut.s_fidbo_2_0 directly and asserts a bit-for-bit straight-through mapping across all        **
**   relevant FIDBO patterns, so ANY reintroduction of the swap fails the test.                    **
**                                                                                               **
** Also verifies integration wiring:                                                              **
**   - the DIN write mux (Multiplexer_bus_2, sel=s_oem): s_din_15_0 = s_oem ? PICMASK : FIDBO.     **
**   - MDCD's OEM strobe wiring: s_oem = (sel3|sel7) & EPIC   (LAA command 3 or 7 with EPIC).      **
**                                                                                               **
** Self-checking, "TB_RESULT: PASS/FAIL". -DTEETH_TEST makes the golden EXPECT the swap; a         **
**   correct (un-swapped) DUT then mismatches on any FIDBO with bit1!=bit2 -> FAIL, proving the    **
**   no-swap assertion truly distinguishes swapped from straight-through.                          **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_cntlr -y Shared/logisim -y Shared/support -y Shared/ndlib \        **
**     -y DELILAH-CPU/CGA_INTR/circuit \                                                           **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR.v \                                             **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_tb.v && vvp /tmp/tb_cntlr                            **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_tb;

  reg         sysclk;
  reg         MCLK_EN;
  reg         EPIC;
  reg  [15:0] FIDBO_15_0;
  reg  [15:0] IREQ_15_0_N;
  reg  [ 3:0] LAA_3_0;
  reg         MCLK;

  wire        EPICMASKN, HIGSN, IRQN, LOGSN, PD;
  wire [15:0] PICMASK_15_0;
  wire [ 2:0] PICS_2_0, PICV_2_0;

  CGA_INTR_CNTLR dut (
      .sysclk(sysclk), .MCLK_EN(MCLK_EN),
      .EPIC(EPIC), .FIDBO_15_0(FIDBO_15_0), .IREQ_15_0_N(IREQ_15_0_N),
      .LAA_3_0(LAA_3_0), .MCLK(MCLK),
      .EPICMASKN(EPICMASKN), .HIGSN(HIGSN), .IRQN(IRQN), .LOGSN(LOGSN),
      .PD(PD), .PICMASK_15_0(PICMASK_15_0), .PICS_2_0(PICS_2_0), .PICV_2_0(PICV_2_0)
  );

  integer errors = 0;
  integer checks = 0;
  integer swap_checks = 0;   // count of dedicated FIDBO no-swap assertions

  initial sysclk = 0;
  always #5 sysclk = ~sysclk;

  // ---- THE critical assertion: s_fidbo_2_0 is a straight-through slice of FIDBO ----
  task check_fidbo_noswap(input [127:0] tag);
    reg e0, e1, e2;
    begin
      #1;
`ifdef TEETH_TEST
      // TEETH: expect the (buggy) swap -> must mismatch a correct DUT when bit1!=bit2
      e0 = FIDBO_15_0[0];
      e1 = FIDBO_15_0[2];
      e2 = FIDBO_15_0[1];
`else
      e0 = FIDBO_15_0[0];
      e1 = FIDBO_15_0[1];
      e2 = FIDBO_15_0[2];
`endif
      checks = checks + 1;
      swap_checks = swap_checks + 1;
      if (dut.s_fidbo_2_0[0] !== e0 ||
          dut.s_fidbo_2_0[1] !== e1 ||
          dut.s_fidbo_2_0[2] !== e2) begin
        errors = errors + 1;
        $display("FAIL[%0s] FIDBO[2:0]=%b_%b_%b -> s_fidbo_2_0=%b (exp %b%b%b)  [SWAP DETECTED?]",
                 tag, FIDBO_15_0[2], FIDBO_15_0[1], FIDBO_15_0[0],
                 dut.s_fidbo_2_0, e2, e1, e0);
      end
    end
  endtask

  // ---- integration: DIN write mux and OEM strobe wiring ----
  task check_din_mux(input [127:0] tag);
    reg [15:0] e_din;
    reg        e_oem;
    begin
      #1;
      // OEM = (LAA==3 || LAA==7) & EPIC   (MDCD GATES_7/oem path)
      e_oem = ((LAA_3_0 == 4'd3) | (LAA_3_0 == 4'd7)) & EPIC;
      checks = checks + 1;
      if (dut.s_oem !== e_oem) begin
        errors = errors + 1;
        $display("FAIL[%0s oem] LAA=%0d EPIC=%b : s_oem exp=%b got=%b",
                 tag, LAA_3_0, EPIC, e_oem, dut.s_oem);
      end
      // DIN mux: sel=s_oem selects PICMASK(1) else FIDBO(0). Use measured picmask (may be x).
      e_din = dut.s_oem ? dut.s_picmask_15_0_out : dut.s_fidbo_15_0;
      checks = checks + 1;
      if (dut.s_din_15_0 !== e_din) begin
        errors = errors + 1;
        $display("FAIL[%0s din] oem=%b : s_din exp=%04h got=%04h",
                 tag, dut.s_oem, e_din, dut.s_din_15_0);
      end
    end
  endtask

  integer f, li;

  initial begin
    MCLK_EN     = 1'b0;
    MCLK        = 1'b0;
    EPIC        = 1'b1;
    LAA_3_0     = 4'd0;
    FIDBO_15_0  = 16'h0000;
    IREQ_15_0_N = 16'hFFFF;   // no requests pending
    #3;

    // ---- FIDBO no-swap sweep: all 8 low patterns + upper-bit noise, both EPIC states ----
    // upper bits deliberately varied to prove only [2:0] pass through and nothing else leaks in
    for (f = 0; f < 16; f = f + 1) begin
      // low nibble carries the bits under test; smear pattern into the upper word too
      FIDBO_15_0 = {f[3:0], 4'b1010, f[3:0], f[3:0]};
      EPIC = 1'b1;
      check_fidbo_noswap("swap-hi-epic1");
      EPIC = 1'b0;
      check_fidbo_noswap("swap-hi-epic0");
    end
    // exhaustive over exactly FIDBO[2:0]=0..7 with clean upper bits
    for (f = 0; f < 8; f = f + 1) begin
      FIDBO_15_0 = {13'h0000, f[2:0]};
      check_fidbo_noswap("swap-clean");
    end

    // ---- integration wiring sweep: OEM strobe + DIN mux over all LAA, both EPIC ----
    FIDBO_15_0 = 16'hA53C;
    for (li = 0; li < 16; li = li + 1) begin
      LAA_3_0 = li[3:0];
      EPIC = 1'b1; check_din_mux("mux-epic1");
      EPIC = 1'b0; check_din_mux("mux-epic0");
    end

    // pulse MCLK a few times (settle sequential blocks) and re-probe the swap wire
    EPIC = 1'b1; LAA_3_0 = 4'd0; FIDBO_15_0 = 16'h0006;  // bit1=1,bit2=1
    repeat (4) begin MCLK = 1; #5; MCLK = 0; #5; end
    check_fidbo_noswap("swap-postclk-6");
    FIDBO_15_0 = 16'h0004;  // bit2=1,bit1=0  (the value that most exposes a 1<->2 swap)
    check_fidbo_noswap("swap-postclk-4");
    FIDBO_15_0 = 16'h0002;  // bit1=1,bit2=0
    check_fidbo_noswap("swap-postclk-2");

    $display("checks=%0d (fidbo-noswap=%0d) errors=%0d", checks, swap_checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
