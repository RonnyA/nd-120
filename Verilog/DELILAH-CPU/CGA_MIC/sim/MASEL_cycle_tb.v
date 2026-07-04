`timescale 1ns / 1ps

/**************************************************************************
** CGA_MIC_MASEL full-cycle testbench
**
** Tests complete microcode cycle behavior:
**   - Multi-sysclk MCLK pulses (realistic FPGA timing)
**   - IW_12_0 stability during active phase
**   - W_12_0 stability during active phase
**   - IW = W during active phase
**   - Sequential NEXT = IW + 1 correctness
**   - JMP target correctness
**   - Race condition: SC5/SC6 transition at MCLK edge
**
** Includes IINC model (combinational adder) to close the NEXT feedback loop.
**
** Run: make MASEL_cycle_tb && ./MASEL_cycle_tb
***************************************************************************/

module MASEL_cycle_tb;

  // Sysclk: 100 MHz, 10 ns period
  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  // MASEL ports
  reg         sys_rst_n;
  reg         CSBIT20;
  reg [11:0]  CSBIT_11_0;
  reg [3:0]   JMP_3_0;
  reg         MCLK;
  reg         MCLKN;
  reg         MRN;
  reg [12:0]  RET_12_0;
  reg         SC5;
  reg         SC6;

  // MASEL provides NEXT_12_0 input — we model IINC as IW + 1
  wire [12:0] IW_12_0;
  wire [12:0] W_12_0;
  wire [12:0] NEXT_12_0 = IW_12_0 + 13'd1;  // IINC model

  always @(*) MCLKN = ~MCLK;

  CGA_MIC_MASEL uut (
    .sysclk(sysclk),
    .sys_rst_n(sys_rst_n),
    .CSBIT20(CSBIT20),
    .CSBIT_11_0(CSBIT_11_0),
    .JMP_3_0(JMP_3_0),
    .MCLK(MCLK),
    .MCLKN(MCLKN),
    .MRN(MRN),
    .NEXT_12_0(NEXT_12_0),
    .RET_12_0(RET_12_0),
    .SC5(SC5),
    .SC6(SC6),
    .IW_12_0(IW_12_0),
    .W_12_0(W_12_0)
  );

  // Pass/fail tracking
  integer pass_count = 0;
  integer fail_count = 0;
  integer glitch_count = 0;

  // Helper: set JMP target address in CSBIT fields
  task set_jmp_target(input [12:0] addr);
    begin
      CSBIT20    = addr[12];
      CSBIT_11_0 = {addr[11:4], 4'b0000};  // bits 11..4 (low 4 are from JMP_3_0)
      JMP_3_0    = addr[3:0];
    end
  endtask

  // Helper: check a value
  task check(input [12:0] actual, input [12:0] expected, input [8*80-1:0] label);
    begin
      if (actual === expected) begin
        $display("  PASS: %0s = o%o", label, actual);
        pass_count = pass_count + 1;
      end else begin
        $display("  FAIL: %0s = o%o, expected o%o", label, actual, expected);
        fail_count = fail_count + 1;
      end
    end
  endtask

  // Monitor: check IW stability during MCLK=1 (active phase)
  reg [12:0] iw_snapshot;
  reg [12:0] w_snapshot;
  reg        monitoring = 0;

  always @(posedge sysclk) begin
    if (monitoring && MCLK) begin
      if (IW_12_0 !== iw_snapshot) begin
        $display("  GLITCH: IW_12_0 changed from o%o to o%o during active phase!", iw_snapshot, IW_12_0);
        glitch_count = glitch_count + 1;
        iw_snapshot = IW_12_0;
      end
      if (W_12_0 !== w_snapshot) begin
        $display("  GLITCH: W_12_0 changed from o%o to o%o during active phase!", w_snapshot, W_12_0);
        glitch_count = glitch_count + 1;
        w_snapshot = W_12_0;
      end
    end
  end

  // Helper: run one MCLK cycle (idle N sysclks, active M sysclks)
  task run_cycle(input integer idle_clks, input integer active_clks);
    integer i;
    begin
      // Idle phase
      MCLK = 0;
      for (i = 0; i < idle_clks; i = i + 1) @(posedge sysclk);

      // Rising edge + active phase
      @(posedge sysclk);
      MCLK = 1;
      #1;

      // Snapshot for stability monitoring
      iw_snapshot = IW_12_0;
      w_snapshot  = W_12_0;
      monitoring  = 1;

      for (i = 0; i < active_clks - 1; i = i + 1) @(posedge sysclk);

      monitoring = 0;
    end
  endtask

  // Helper: run one MCLK cycle with SC transition AT the mclk rising edge (race)
  task run_cycle_race(input integer idle_clks, input integer active_clks,
                      input new_sc6, input new_sc5);
    integer i;
    begin
      // Idle phase
      MCLK = 0;
      for (i = 0; i < idle_clks; i = i + 1) @(posedge sysclk);

      // Rising edge with SIMULTANEOUS SC change (race condition)
      @(posedge sysclk);
      MCLK = 1;
      SC6  = new_sc6;
      SC5  = new_sc5;
      #1;

      iw_snapshot = IW_12_0;
      w_snapshot  = W_12_0;
      monitoring  = 1;

      for (i = 0; i < active_clks - 1; i = i + 1) @(posedge sysclk);

      monitoring = 0;
    end
  endtask

  initial begin
    $dumpfile("MASEL_cycle_tb.vcd");
    $dumpvars(0, MASEL_cycle_tb);

    // Initialize
    sys_rst_n = 0; MRN = 0; MCLK = 0;
    SC6 = 0; SC5 = 0;
    CSBIT20 = 0; CSBIT_11_0 = 0; JMP_3_0 = 0;
    RET_12_0 = 13'o4567;

    @(posedge sysclk); @(posedge sysclk);
    sys_rst_n = 1; MRN = 1;
    @(posedge sysclk); @(posedge sysclk);

    $display("");
    $display("================================================================");
    $display(" CGA_MIC_MASEL full-cycle testbench");
    $display("================================================================");

    // ---------------------------------------------------------------
    // Test 1: Sequential NEXT — 3 cycles starting from JMP to o2001
    // Cycle 1: JMP to o2001
    // Cycle 2: NEXT (should be o2002)
    // Cycle 3: NEXT (should be o2003)
    // ---------------------------------------------------------------
    $display("");
    $display("Test 1: JMP to o2001 then 2 sequential NEXT cycles");

    // Set up JMP target o2001
    set_jmp_target(13'o2001);
    SC6 = 0; SC5 = 0;  // SEL_JUMP
    run_cycle(4, 4);
    check(IW_12_0, 13'o2001, "IW after JMP to o2001");
    check(W_12_0,  13'o2001, "W during active (= IW)");

    // Switch to SEL_NEXT
    SC6 = 1; SC5 = 0;
    run_cycle(4, 4);
    check(IW_12_0, 13'o2002, "IW after NEXT (= o2001+1)");

    run_cycle(4, 4);
    check(IW_12_0, 13'o2003, "IW after NEXT (= o2002+1)");

    // ---------------------------------------------------------------
    // Test 2: Race — SC changes from NEXT to JUMP at MCLK rising
    //
    // Setup: IW = o2003 (from test 1). NEXT = o2004.
    // During idle, SC = NEXT (= 10). At MCLK rising, SC transitions
    // to JUMP (= 00) simultaneously. JMP target = o3760.
    //
    // Expected: IW should capture the JUMP target (o3760), not NEXT (o2004)
    // ---------------------------------------------------------------
    $display("");
    $display("Test 2: Race — SC transitions NEXT->JUMP at MCLK rising");

    set_jmp_target(13'o3760);
    SC6 = 1; SC5 = 0;  // start in SEL_NEXT during idle
    MCLK = 0;
    @(posedge sysclk); @(posedge sysclk); @(posedge sysclk);

    // Race: MCLK rises AND SC changes to SEL_JUMP at the same edge
    run_cycle_race(0, 4, 0, 0);  // new_sc6=0, new_sc5=0 = SEL_JUMP
    check(IW_12_0, 13'o3760, "IW after race NEXT->JUMP (expect JMP target o3760)");

    // ---------------------------------------------------------------
    // Test 3: Race — SC changes from JUMP to NEXT at MCLK rising
    // ---------------------------------------------------------------
    $display("");
    $display("Test 3: Race — SC transitions JUMP->NEXT at MCLK rising");

    set_jmp_target(13'o5555);
    SC6 = 0; SC5 = 0;  // start in SEL_JUMP during idle (target o5555)
    MCLK = 0;
    @(posedge sysclk); @(posedge sysclk); @(posedge sysclk);

    // Race: MCLK rises AND SC changes to SEL_NEXT
    run_cycle_race(0, 4, 1, 0);  // new_sc6=1, new_sc5=0 = SEL_NEXT
    // NEXT = IW + 1 = o3760 + 1 = o3761 (IW still at o3760 from test 2)
    check(IW_12_0, 13'o3761, "IW after race JUMP->NEXT (expect NEXT = o3760+1 = o3761)");

    // ---------------------------------------------------------------
    // Test 4: RETURN path
    // ---------------------------------------------------------------
    $display("");
    $display("Test 4: SEL_RETURN");
    RET_12_0 = 13'o1234;
    SC6 = 0; SC5 = 1;  // SEL_RETURN
    run_cycle(4, 4);
    check(IW_12_0, 13'o1234, "IW after RETURN to o1234");

    // ---------------------------------------------------------------
    // Test 5: REPEAT path (IW feeds back to itself)
    // ---------------------------------------------------------------
    $display("");
    $display("Test 5: SEL_REPEAT");
    SC6 = 1; SC5 = 1;  // SEL_REPEAT
    run_cycle(4, 4);
    check(IW_12_0, 13'o1234, "IW after REPEAT (still o1234)");

    // ---------------------------------------------------------------
    // Test 6: Long sequential run (10 NEXT cycles) — stress test
    // ---------------------------------------------------------------
    $display("");
    $display("Test 6: 10 sequential NEXT cycles starting from o0100");
    set_jmp_target(13'o0100);
    SC6 = 0; SC5 = 0;  // JMP to o0100
    run_cycle(4, 4);
    check(IW_12_0, 13'o0100, "IW after JMP to o0100");

    SC6 = 1; SC5 = 0;  // SEL_NEXT
    begin : seq_block
      integer cycle_i;
      for (cycle_i = 1; cycle_i <= 10; cycle_i = cycle_i + 1) begin
        run_cycle(3, 3);  // shorter cycles
      end
    end
    check(IW_12_0, 13'o0112, "IW after 10 NEXT from o0100 (= o0100 + o12 = o0112)");

    // ---------------------------------------------------------------
    // Test 7: Realistic MCLK timing — 1-sysclk active (matches FPGA)
    // ---------------------------------------------------------------
    $display("");
    $display("Test 7: 1-sysclk active phase (FPGA-realistic tight timing)");
    set_jmp_target(13'o2341);
    SC6 = 0; SC5 = 0;  // JMP
    run_cycle(3, 1);  // only 1 sysclk active!
    check(IW_12_0, 13'o2341, "IW after JMP with 1-sysclk active");

    SC6 = 1; SC5 = 0;
    run_cycle(3, 1);
    check(IW_12_0, 13'o2342, "IW after NEXT with 1-sysclk active");

    run_cycle(3, 1);
    check(IW_12_0, 13'o2343, "IW after NEXT with 1-sysclk active");

    // ---------------------------------------------------------------
    // Test 8: Race with 1-sysclk active (FPGA worst case)
    // ---------------------------------------------------------------
    $display("");
    $display("Test 8: Race + 1-sysclk active (FPGA worst case)");
    set_jmp_target(13'o7777);
    SC6 = 1; SC5 = 0;  // start NEXT during idle
    MCLK = 0;
    @(posedge sysclk); @(posedge sysclk);

    run_cycle_race(0, 1, 0, 0);  // race to SEL_JUMP, only 1 sysclk active
    check(IW_12_0, 13'o7777, "IW after race with 1-sysclk active (expect o7777)");

    // ---------------------------------------------------------------
    // Summary
    // ---------------------------------------------------------------
    $display("");
    $display("================================================================");
    $display(" Summary: %0d PASS / %0d FAIL / %0d active-phase GLITCHES", pass_count, fail_count, glitch_count);
    if (fail_count > 0)
      $display(" NOTE: Race tests (2,3,8) are expected to FAIL with the");
      $display(" original posedge-MCLK pattern in iverilog because the");
      $display(" testbench drives SC and MCLK at the same posedge sysclk.");
    $display("================================================================");

    $finish;
  end

  // Safety timeout
  initial begin
    #50000;
    $display("TIMEOUT");
    $finish;
  end

endmodule
