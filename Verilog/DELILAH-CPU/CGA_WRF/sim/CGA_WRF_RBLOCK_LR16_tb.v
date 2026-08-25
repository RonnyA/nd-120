/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CGA_WRF_RBLOCK_LR16 testbench                                         **
**                                                                       **
** Verification of the L-register / R-register pair (PDF page 63):      **
**                                                                       **
** Independent model (from the netlist reading):                         **
**   IR      = WR ? RB_15_0 : R (MUX24P recirculation)                   **
**   R       : 2x R81_EN, captures IR on the ALUCLK rise                 **
**   LR      : 2x L8 transparent latch, gate = ~ALUCLK & WR              **
**             (follows IR while ALUCLK=0 and WR=1, else holds)          **
**                                                                       **
** Test plan (task step = apply WR/RB, check transparency, clock,        **
** check capture; 4 checks per step):                                    **
**   1. defining load                                                    **
**   2. walking-one writes, each followed by a WR=0 recirculation step   **
**      (R must hold, LR must stay closed), then walking-zero writes     **
**   3. hold without clock                                               **
**   4. 256 fixed-seed LFSR steps with random WR/RB                      **
**                                                                       **
** Build modes: R81_EN switches on FPGA_FF_MODE (ALUCLK_EN-gated sysclk  **
** capture); L8 switches on USE_TRANSPARENT_LATCHES (pure transparent    **
** latch vs the sysclk-synchronized FPGA form). The Makefile target      **
** test-wrf-lr16 therefore runs this THREE times: default, then          **
** -DFPGA_FF_MODE, then -DUSE_TRANSPARENT_LATCHES.                       **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_WRF_RBLOCK_LR16_tb;

  reg         sysclk = 0;
  reg         sys_rst_n = 1;
  reg         ALUCLK_EN = 0;
  reg         ALUCLK = 0;
  reg  [15:0] RB_15_0 = 0;
  reg         WR = 0;

  wire [15:0] LR_15_0;
  wire [15:0] R_15_0;

  integer errors = 0;
  integer checks = 0;
  integer i;

  // reference model
  reg [15:0] m_r;
  reg [15:0] m_lr;
  reg [31:0] lfsr;

  wire [15:0] m_ir = WR ? RB_15_0 : m_r;

  CGA_WRF_RBLOCK_LR16 dut (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .ALUCLK_EN(ALUCLK_EN),
      .ALUCLK(ALUCLK),
      .RB_15_0(RB_15_0),
      .WR(WR),
      .LR_15_0(LR_15_0),
      .R_15_0(R_15_0)
  );

  always #5 sysclk = ~sysclk;

  // One ALUCLK event, valid in ALL build modes: the EN-mode register
  // captures at posedge sysclk while ALUCLK_EN=1; the CP-mode register
  // captures at the posedge of ALUCLK raised just after the same sysclk
  // edge (inputs stable). The LR latch gate (~ALUCLK & WR) closes when
  // ALUCLK rises; the same sysclk edge refreshed the FPGA-form latch.
  task pulse_aluclk;
    begin
      @(negedge sysclk);
      ALUCLK_EN = 1;
      @(posedge sysclk);
      #1 ALUCLK = 1;
      @(negedge sysclk);
      ALUCLK    = 0;
      ALUCLK_EN = 0;
    end
  endtask

  task check_pair(input [15:0] exp_r, input [15:0] exp_lr, input [127:0] name);
    begin
      checks = checks + 1;
      if (R_15_0 !== exp_r) begin
        errors = errors + 1;
        $display("FAIL %0s R: got %04h expected %04h (WR=%b RB=%04h ALUCLK=%b)",
                 name, R_15_0, exp_r, WR, RB_15_0, ALUCLK);
      end
      checks = checks + 1;
      if (LR_15_0 !== exp_lr) begin
        errors = errors + 1;
        $display("FAIL %0s LR: got %04h expected %04h (WR=%b RB=%04h ALUCLK=%b)",
                 name, LR_15_0, exp_lr, WR, RB_15_0, ALUCLK);
      end
    end
  endtask

  // Apply WR/RB with ALUCLK low, verify transparency, clock once, verify
  // capture. 4 checks per call. `first` skips the pre-clock R compare
  // (power-up R is undefined until the first defining load).
  task step(input v_wr, input [15:0] v_rb, input first, input [127:0] name);
    begin
      WR      = v_wr;
      RB_15_0 = v_rb;
      #2;
      // gate open only when WR=1 (ALUCLK=0 here): LR follows IR
      if (v_wr) m_lr = m_ir;
      if (!first) check_pair(m_r, m_lr, name);
      else begin
        checks = checks + 2;  // keep the per-step check count constant
      end
      pulse_aluclk;
      m_r = v_wr ? v_rb : m_r;   // R captures IR (pre-edge value)
      #2;                        // ALUCLK back low: gate reopens if WR=1
      if (v_wr) m_lr = m_ir;     // IR = RB (unchanged) when WR=1
      check_pair(m_r, m_lr, name);
    end
  endtask

  function [31:0] lfsr_next(input [31:0] x);
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  initial begin
`ifdef USE_TRANSPARENT_LATCHES
    $display("CGA_WRF_RBLOCK_LR16_tb: USE_TRANSPARENT_LATCHES mode");
`elsif FPGA_FF_MODE
    $display("CGA_WRF_RBLOCK_LR16_tb: FPGA_FF_MODE (sysclk+ALUCLK_EN capture)");
`else
    $display("CGA_WRF_RBLOCK_LR16_tb: default mode (posedge ALUCLK / sync latch)");
`endif

    // 1. defining load
    step(1, 16'h0000, 1, "init load");

    // 2. walking-one writes, each followed by a WR=0 recirculation step,
    //    then walking-zero writes
    for (i = 0; i < 16; i = i + 1) begin
      step(1, 16'h0001 << i, 0, "walk1 write");
      step(0, 16'hDEAD, 0, "recirculate");
    end
    for (i = 0; i < 16; i = i + 1)
      step(1, ~(16'h0001 << i), 0, "walk0 write");

    // 3. hold without clock: WR=0, gate closed, no ALUCLK
    WR = 0; RB_15_0 = 16'h1234;
    #40;
    check_pair(m_r, m_lr, "hold w/o clock");

    // 4. fixed-seed LFSR random steps
    lfsr = 32'hBEEF0451;
    for (i = 0; i < 256; i = i + 1) begin
      lfsr = lfsr_next(lfsr);
      step(lfsr[16], lfsr[15:0], 0, "lfsr step");
    end

    // Verdict. Steps: 1 + 32 + 16 + 256 = 305, at 4 checks each, plus the
    // 2-check hold = 1222 checks.
    if (errors == 0 && checks == 1222)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 1222 checks)", errors, checks);
    $finish;
  end

endmodule
