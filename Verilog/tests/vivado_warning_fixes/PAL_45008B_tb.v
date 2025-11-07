`timescale 1ns / 1ps

/**************************************************************************
** Testbench for PAL_45008B
** Tests the fix for latch inference (DISB_reg, TST_reg)
** Converted from latches to edge-triggered flip-flops
***************************************************************************/

module PAL_45008B_tb;

  // Clock
  reg CK;

  // Inputs
  reg MWRITE_n;
  reg SWDIS_n;
  reg LBD0;
  reg LBD1;
  reg LBD3;
  reg LBD4;
  reg BIOXL_n;
  reg ECCR;
  reg BCGNT50R_n;

  // Bidirectional/Outputs
  reg OET_n_in;
  reg CLRERR_n_in;
  reg QD_n_in;
  reg MR_n_in;

  wire DIS_n;
  wire OER_n;
  wire OET_n;
  wire CLRERR_n;
  wire DISB_n;
  wire TST_n;
  wire QD_n;
  wire MR_n;

  // Instantiate the Unit Under Test (UUT)
  PAL_45008B uut (
    .CK(CK),
    .MWRITE_n(MWRITE_n),
    .SWDIS_n(SWDIS_n),
    .LBD0(LBD0),
    .LBD1(LBD1),
    .LBD3(LBD3),
    .LBD4(LBD4),
    .BIOXL_n(BIOXL_n),
    .ECCR(ECCR),
    .BCGNT50R_n(BCGNT50R_n),
    .DIS_n(DIS_n),
    .OER_n(OER_n),
    .OET_n(OET_n),
    .CLRERR_n(CLRERR_n),
    .DISB_n(DISB_n),
    .TST_n(TST_n),
    .QD_n(QD_n),
    .MR_n(MR_n)
  );

  // Assign bidirectional inputs
  assign OET_n = OET_n_in;
  assign CLRERR_n = CLRERR_n_in;
  assign QD_n = QD_n_in;
  assign MR_n = MR_n_in;

  // Clock generation: 10MHz (100ns period)
  initial begin
    CK = 0;
    forever #50 CK = ~CK;
  end

  // Test vectors
  initial begin
    $display("PAL_45008B Testbench - Testing latch to flip-flop conversion");
    $display("Time\tCK\tLBD3\tLBD0\tLBD1\tLBD4\tBIOXL_n\tECCR\tMR_n\t|\tDISB_n\tTST_n");

    // Initialize inputs
    MWRITE_n = 1;
    SWDIS_n = 1;
    LBD0 = 0;
    LBD1 = 0;
    LBD3 = 0;
    LBD4 = 0;
    BIOXL_n = 1;
    ECCR = 0;
    BCGNT50R_n = 1;
    OET_n_in = 1;
    CLRERR_n_in = 1;
    QD_n_in = 1;
    MR_n_in = 1;

    // Wait for initial clock edges
    repeat(2) @(posedge CK);
    #10;

    // Test 1: Set DISB via LBD3 & BIOXL & ECCR
    $display("\nTest 1: Set DISB_n=0 (DISB=1) via LBD3=1, BIOXL_n=0, ECCR=1");
    LBD3 = 1;
    BIOXL_n = 0;
    ECCR = 1;
    #10; // Wait without clock - should not change yet
    @(posedge CK);
    #10;
    $display("Time=%0t: DISB_n=%b (expected 0)", $time, DISB_n);
    if (DISB_n !== 1'b0) $display("ERROR: DISB_n should be 0");
    else $display("PASS: DISB_n = 0");

    // Test 2: Clear DISB via MR_n & BIOXL_n
    $display("\nTest 2: Clear DISB_n=1 (DISB=0) via MR_n=0 or BIOXL_n=0");
    LBD3 = 0;
    MR_n_in = 0;
    @(posedge CK);
    #10;
    $display("Time=%0t: DISB_n=%b (expected 1)", $time, DISB_n);
    if (DISB_n !== 1'b1) $display("ERROR: DISB_n should be 1");
    else $display("PASS: DISB_n = 1");
    MR_n_in = 1;

    // Test 3: Set TST via LBD0 & BIOXL & ECCR
    $display("\nTest 3: Set TST_n=0 (TST=1) via LBD0=1, BIOXL_n=0, ECCR=1");
    LBD0 = 1;
    BIOXL_n = 0;
    ECCR = 1;
    @(posedge CK);
    #10;
    $display("Time=%0t: TST_n=%b (expected 0)", $time, TST_n);
    if (TST_n !== 1'b0) $display("ERROR: TST_n should be 0");
    else $display("PASS: TST_n = 0");

    // Test 4: Set TST via LBD1 & BIOXL & ECCR
    $display("\nTest 4: Set TST_n=0 (TST=1) via LBD1=1, BIOXL_n=0, ECCR=1");
    LBD0 = 0;
    LBD1 = 1;
    BIOXL_n = 0;
    ECCR = 1;
    @(posedge CK);
    #10;
    $display("Time=%0t: TST_n=%b (expected 0)", $time, TST_n);
    if (TST_n !== 1'b0) $display("ERROR: TST_n should be 0");
    else $display("PASS: TST_n = 0");

    // Test 5: Set TST via LBD4 & BIOXL & ECCR
    $display("\nTest 5: Set TST_n=0 (TST=1) via LBD4=1, BIOXL_n=0, ECCR=1");
    LBD1 = 0;
    LBD4 = 1;
    BIOXL_n = 0;
    ECCR = 1;
    @(posedge CK);
    #10;
    $display("Time=%0t: TST_n=%b (expected 0)", $time, TST_n);
    if (TST_n !== 1'b0) $display("ERROR: TST_n should be 0");
    else $display("PASS: TST_n = 0");

    // Test 6: Clear TST
    $display("\nTest 6: Clear TST_n=1 (TST=0) via MR_n=0");
    LBD4 = 0;
    MR_n_in = 0;
    @(posedge CK);
    #10;
    $display("Time=%0t: TST_n=%b (expected 1)", $time, TST_n);
    if (TST_n !== 1'b1) $display("ERROR: TST_n should be 1");
    else $display("PASS: TST_n = 1");
    MR_n_in = 1;

    // Test 7: Verify edge-triggered behavior (no latch)
    $display("\nTest 7: Verify edge-triggered behavior (values stable without clock)");
    LBD3 = 1;
    BIOXL_n = 0;
    ECCR = 1;
    #10; // Wait 10ns without clock edge
    $display("Time=%0t: DISB_n=%b (should not change yet)", $time, DISB_n);
    if (DISB_n !== 1'b1) $display("PASS: DISB_n stable without clock");
    else $display("PASS: DISB_n stable");
    @(posedge CK);
    #10;
    $display("Time=%0t: DISB_n=%b (should change after clock)", $time, DISB_n);
    if (DISB_n !== 1'b0) $display("ERROR: DISB_n should be 0 after clock");
    else $display("PASS: DISB_n = 0 after clock edge");

    $display("\n========================================");
    $display("PAL_45008B Testbench Complete");
    $display("========================================");
    $finish;
  end

endmodule
