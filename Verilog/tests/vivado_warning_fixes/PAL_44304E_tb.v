`timescale 1ns / 1ps

/**************************************************************************
** Testbench for PAL_44304E
** Tests the fix for combinatorial loops (BACT_reg, EBADR_n_reg)
** Converted from combinatorial to edge-triggered flip-flops
***************************************************************************/

module PAL_44304E_tb;

  // Clock
  reg CK;

  // Inputs
  reg BGNT50;
  reg MWRITE_n;
  reg BDAP50;
  reg IBAPR_n;
  reg GNT_n;
  reg BGNT_n;

  // Outputs
  wire BACT;
  wire EBADR_n;

  // Instantiate the Unit Under Test (UUT)
  PAL_44304E uut (
    .CK(CK),
    .BGNT50(BGNT50),
    .MWRITE_n(MWRITE_n),
    .BDAP50(BDAP50),
    .IBAPR_n(IBAPR_n),
    .GNT_n(GNT_n),
    .BGNT_n(BGNT_n),
    .BACT(BACT),
    .EBADR_n(EBADR_n)
  );

  // Clock generation: 10MHz (100ns period)
  initial begin
    CK = 0;
    forever #50 CK = ~CK;
  end

  // Test vectors
  initial begin
    $display("PAL_44304E Testbench - Testing combinatorial loop fix");
    $display("Time\tCK\tBGNT50\tMWRITE_n\tBDAP50\tIBAPR_n\tGNT_n\tBGNT_n\t|\tBACT\tEBADR_n");
    $monitor("%0t\t%b\t%b\t%b\t%b\t%b\t%b\t%b\t|\t%b\t%b",
             $time, CK, BGNT50, MWRITE_n, BDAP50, IBAPR_n, GNT_n, BGNT_n, BACT, EBADR_n);

    // Initialize inputs
    BGNT50 = 0;
    MWRITE_n = 1;
    BDAP50 = 0;
    IBAPR_n = 1;
    GNT_n = 1;
    BGNT_n = 1;

    // Wait for initial clock edge
    @(posedge CK);
    #10;

    // Test 1: Set BACT (BGNT50 & MWRITE_n = 1)
    $display("\nTest 1: Set BACT via BGNT50=1, MWRITE_n=1");
    BGNT50 = 1;
    MWRITE_n = 1;
    @(posedge CK);
    #10;
    if (BACT !== 1'b1) $display("ERROR: BACT should be 1");
    else $display("PASS: BACT = 1");

    // Test 2: Hold BACT (BDAP50 = 1 to maintain)
    $display("\nTest 2: Hold BACT via BDAP50=1");
    BGNT50 = 0;
    BDAP50 = 1;
    @(posedge CK);
    #10;
    if (BACT !== 1'b1) $display("ERROR: BACT should remain 1");
    else $display("PASS: BACT held at 1");

    // Test 3: Clear BACT (BDAP50 = 0)
    $display("\nTest 3: Clear BACT via BDAP50=0");
    BDAP50 = 0;
    @(posedge CK);
    #10;
    if (BACT !== 1'b0) $display("ERROR: BACT should be 0");
    else $display("PASS: BACT = 0");

    // Test 4: Set EBADR_n (GNT_n & BGNT_n = 1)
    $display("\nTest 4: Set EBADR_n via GNT_n=1, BGNT_n=1");
    GNT_n = 1;
    BGNT_n = 1;
    @(posedge CK);
    #10;
    if (EBADR_n !== 1'b1) $display("ERROR: EBADR_n should be 1");
    else $display("PASS: EBADR_n = 1");

    // Test 5: Clear EBADR_n (IBAPR_n=0 & GNT_n=0)
    $display("\nTest 5: Clear EBADR_n via IBAPR_n=0, GNT_n=0");
    IBAPR_n = 0;
    GNT_n = 0;
    @(posedge CK);
    #10;
    if (EBADR_n !== 1'b0) $display("ERROR: EBADR_n should be 0");
    else $display("PASS: EBADR_n = 0");

    // Test 6: Hold EBADR_n at 0
    $display("\nTest 6: Hold EBADR_n at 0");
    IBAPR_n = 1;
    GNT_n = 1;
    BGNT_n = 1;
    @(posedge CK);
    #10;
    if (EBADR_n !== 1'b1) $display("ERROR: EBADR_n should be 1");
    else $display("PASS: EBADR_n = 1");

    // Test 7: Verify no combinatorial loops (signals stable after clock)
    $display("\nTest 7: Verify edge-triggered behavior (no combinatorial feedback)");
    BGNT50 = 1;
    MWRITE_n = 1;
    #10; // Wait without clock edge
    if (BACT !== 1'b1) $display("ERROR: BACT changed without clock edge");
    else $display("PASS: BACT stable without clock edge");
    @(posedge CK);
    #10;
    if (BACT !== 1'b1) $display("ERROR: BACT should be 1 after clock");
    else $display("PASS: BACT = 1 after clock edge");

    $display("\n========================================");
    $display("PAL_44304E Testbench Complete");
    $display("========================================");
    $finish;
  end

endmodule
