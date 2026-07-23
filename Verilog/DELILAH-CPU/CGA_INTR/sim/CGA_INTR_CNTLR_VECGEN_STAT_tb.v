/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_VECGEN_STAT  (six SBIT cells = HISTAT_2_0 / LOSTAT_2_0, schematic p.87)          **
**                                                                                               **
** DUT contract: the Am2914 status register for the HI and LO interrupt groups.                   **
**   G is ACTIVE LOW (G=1 idle, G=0 on RDVECT/MCLR). HIF/LOF pulse on this group's LDSTAT+RDVECT. **
**   Per-group control encoding (derived from the confirmed SBIT equation):                       **
**     idle   : G=1, xIF=0                 -> hold                                                 **
**     LDSTAT : G=1, xIF=1, FIDBOx=0(GPE=1)-> HxSTAT <= xSIN   (S-bus load, the ROUND-TRIP)        **
**     RDVECT : G=0, xIF=1                 -> HxSTAT <= (xVEC+1) mod 8  (the re-dispatch FENCE)     **
**     MCLR   : G=0, xIF=0                 -> HxSTAT <= 0                                           **
**                                                                                               **
** REGRESSION FOCUS (docs/RUN-level14-livelock-analysis.md):                                       **
**   (1) LOAD ROUND-TRIP: drive LDSTAT with each value 0..7 on HISIN/LOSIN and require the status  **
**       reads back EXACTLY that value - guards the FIDBO[1]<->[2] swap / bit-corruption class     **
**       (the bug that turned status 2 into 4).                                                    **
**   (2) VECTOR+1 FENCE: drive RDVECT with vec=N and require status == (N+1) mod 8 - guards the    **
**       GATES_3 fence-transcription bug. Golden (N+1)&7 is pure arithmetic, independent of the    **
**       DUT's XNOR/AND incrementer network.                                                       **
**                                                                                               **
** Teeth: compile with -DTEETH_TEST to perturb the expected value -> harness MUST report FAIL.     **
** MCLK_EN tied 0, FPGA_FF_MODE NOT defined -> original posedge-MCLK behaviour.                    **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_stat -y Shared/logisim -y Shared/support -y Shared/ndlib \        **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_STAT_SBIT.v \                            **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_STAT.v \                                 **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_VECGEN_STAT_tb.v && vvp /tmp/tb_stat                **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_VECGEN_STAT_tb;

  reg        MCLK = 0;
  reg        G    = 1;   // active low: 1 = idle
  reg        HIF  = 0;
  reg        LOF  = 0;
  reg        FIDBO3 = 1; // GPE(HI) = ~FIDBO3, so FIDBO3=0 enables HI group load
  reg        FIDBO4 = 1; // GPE(LO) = ~FIDBO4
  reg  [2:0] HISIN_2_0 = 0;
  reg  [2:0] LOSIN_2_0 = 0;
  reg  [2:0] HIVEC_2_0 = 0;
  reg  [2:0] LOVEC_2_0 = 0;
  wire [2:0] HISTAT_2_0;
  wire [2:0] LOSTAT_2_0;

  CGA_INTR_CNTLR_VECGEN_STAT dut (
      .sysclk   (1'b0),
      .MCLK_EN  (1'b0),
      .FIDBO3   (FIDBO3),
      .FIDBO4   (FIDBO4),
      .G        (G),
      .HIF      (HIF),
      .HISIN_2_0(HISIN_2_0),
      .HIVEC_2_0(HIVEC_2_0),
      .LOF      (LOF),
      .LOSIN_2_0(LOSIN_2_0),
      .LOVEC_2_0(LOVEC_2_0),
      .MCLK     (MCLK),
      .HISTAT_2_0(HISTAT_2_0),
      .LOSTAT_2_0(LOSTAT_2_0)
  );

  integer errors = 0;
  integer checks = 0;

  task do_clk;   // one rising MCLK edge (inputs already set)
    begin
      #2 MCLK = 1; #2 MCLK = 0; #1;
    end
  endtask

  // Set HI group to a named op, clock, and check HISTAT against an
  // INDEPENDENTLY supplied expected value.
  task hi_check(input [127:0] what, input [2:0] expv);
    reg [2:0] e;
    begin
      e = expv;
`ifdef TEETH_TEST
      e = e ^ 3'b001;   // deliberately wrong -> harness must FAIL
`endif
      do_clk;
      checks = checks + 1;
      if (HISTAT_2_0 !== e) begin
        errors = errors + 1;
        $display("FAIL HI %0s: HISTAT exp=%0d got=%0d", what, e, HISTAT_2_0);
      end
    end
  endtask

  task lo_check(input [127:0] what, input [2:0] expv);
    reg [2:0] e;
    begin
      e = expv;
`ifdef TEETH_TEST
      e = e ^ 3'b001;
`endif
      do_clk;
      checks = checks + 1;
      if (LOSTAT_2_0 !== e) begin
        errors = errors + 1;
        $display("FAIL LO %0s: LOSTAT exp=%0d got=%0d", what, e, LOSTAT_2_0);
      end
    end
  endtask

  // control presets --------------------------------------------------------
  task set_idle;  begin G=1; HIF=0; LOF=0; end endtask
  task set_mclr;  begin G=0; HIF=0; LOF=0; end endtask
  task hi_ldstat; begin G=1; HIF=1; LOF=0; FIDBO3=0; end endtask   // GPE(HI)=1
  task hi_rdvect; begin G=0; HIF=1; LOF=0; end endtask
  task lo_ldstat; begin G=1; LOF=1; HIF=0; FIDBO4=0; end endtask
  task lo_rdvect; begin G=0; LOF=1; HIF=0; end endtask

  integer v;
  reg [2:0] expinc;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_VECGEN_STAT_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_VECGEN_STAT_tb);

    // Master clear both groups
    set_mclr; hi_check("initial MCLR", 3'd0); set_mclr; lo_check("initial MCLR", 3'd0);

    // ============ (1) HI LOAD ROUND-TRIP: value 0..7 must survive intact ==========
    for (v = 0; v < 8; v = v + 1) begin
      hi_ldstat; HISIN_2_0 = v[2:0];
      hi_check("HI LDSTAT round-trip", v[2:0]);
    end

    // ============ (1) LO LOAD ROUND-TRIP ==========================================
    for (v = 0; v < 8; v = v + 1) begin
      lo_ldstat; LOSIN_2_0 = v[2:0];
      lo_check("LO LDSTAT round-trip", v[2:0]);
    end

    // ============ (2) HI RDVECT FENCE: status <= (vec+1) mod 8 =====================
    for (v = 0; v < 8; v = v + 1) begin
      hi_rdvect; HIVEC_2_0 = v[2:0];
      expinc = (v + 1) % 8;             // independent arithmetic golden
      hi_check("HI RDVECT vec+1", expinc);
    end

    // ============ (2) LO RDVECT FENCE =============================================
    for (v = 0; v < 8; v = v + 1) begin
      lo_rdvect; LOVEC_2_0 = v[2:0];
      expinc = (v + 1) % 8;
      lo_check("LO RDVECT vec+1", expinc);
    end

    // ============ MCLR clears, idle holds =========================================
    hi_ldstat; HISIN_2_0 = 3'd5; hi_check("HI preload 5", 3'd5);
    set_idle;                    hi_check("HI idle holds 5", 3'd5);
    set_idle;                    hi_check("HI idle still 5", 3'd5);
    set_mclr;                    hi_check("HI MCLR->0", 3'd0);

    lo_ldstat; LOSIN_2_0 = 3'd3; lo_check("LO preload 3", 3'd3);
    set_idle;                    lo_check("LO idle holds 3", 3'd3);
    set_mclr;                    lo_check("LO MCLR->0", 3'd0);

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
