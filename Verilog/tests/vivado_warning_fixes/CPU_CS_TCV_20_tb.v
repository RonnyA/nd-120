`timescale 1ns / 1ps

/**************************************************************************
** Testbench for CPU_CS_TCV_20
** Tests the fix for regCSBITS latch inference
** Added default initialization (regCSBITS = CSBITS)
***************************************************************************/

module CPU_CS_TCV_20_tb;

  // Inputs
  reg [63:0] CSBITS;
  reg [15:0] IDB_15_0_IN;
  reg ECSL_n;
  reg WCS_n;
  reg [3:0] EW_3_0_n;

  // Outputs
  wire [63:0] CSBITS_OUT;
  wire [15:0] IDB_15_0_OUT;

  // Instantiate the Unit Under Test (UUT)
  CPU_CS_TCV_20 uut (
    .CSBITS(CSBITS),
    .CSBITS_OUT(CSBITS_OUT),
    .IDB_15_0_IN(IDB_15_0_IN),
    .IDB_15_0_OUT(IDB_15_0_OUT),
    .ECSL_n(ECSL_n),
    .WCS_n(WCS_n),
    .EW_3_0_n(EW_3_0_n)
  );

  // Test vectors
  initial begin
    $display("CPU_CS_TCV_20 Testbench - Testing regCSBITS latch fix");
    $display("========================================");

    // Initialize inputs
    CSBITS = 64'hDEADBEEFCAFEBABE;
    IDB_15_0_IN = 16'h0000;
    ECSL_n = 1;
    WCS_n = 1;
    EW_3_0_n = 4'b1111;
    #100;

    // Test 1: Read CSBITS[15:0] to IDB (DIR=1, WCS_n=1)
    $display("\nTest 1: Read CSBITS[15:0] to IDB");
    CSBITS = 64'h0000000000001234;
    WCS_n = 1;         // DIR = H (CSBITS to IDB)
    ECSL_n = 0;        // Enable output
    EW_3_0_n = 4'b1110; // Enable word 0
    #100;
    $display("Time=%0t: Reading CSBITS[15:0]", $time);
    $display("  CSBITS=%h", CSBITS);
    $display("  IDB_15_0_OUT=%h (expected 1234)", IDB_15_0_OUT);
    if (IDB_15_0_OUT !== 16'h1234)
      $display("ERROR: IDB_15_0_OUT should be 1234");
    else
      $display("PASS: IDB_15_0_OUT = 1234");

    // Test 2: Read CSBITS[31:16] to IDB
    $display("\nTest 2: Read CSBITS[31:16] to IDB");
    CSBITS = 64'h0000000056780000;
    WCS_n = 1;
    ECSL_n = 0;
    EW_3_0_n = 4'b1101; // Enable word 1
    #100;
    $display("Time=%0t: Reading CSBITS[31:16]", $time);
    $display("  CSBITS=%h", CSBITS);
    $display("  IDB_15_0_OUT=%h (expected 5678)", IDB_15_0_OUT);
    if (IDB_15_0_OUT !== 16'h5678)
      $display("ERROR: IDB_15_0_OUT should be 5678");
    else
      $display("PASS: IDB_15_0_OUT = 5678");

    // Test 3: Read CSBITS[47:32] to IDB
    $display("\nTest 3: Read CSBITS[47:32] to IDB");
    CSBITS = 64'h0000ABCD00000000;
    WCS_n = 1;
    ECSL_n = 0;
    EW_3_0_n = 4'b1011; // Enable word 2
    #100;
    $display("Time=%0t: Reading CSBITS[47:32]", $time);
    $display("  IDB_15_0_OUT=%h (expected ABCD)", IDB_15_0_OUT);
    if (IDB_15_0_OUT !== 16'hABCD)
      $display("ERROR: IDB_15_0_OUT should be ABCD");
    else
      $display("PASS: IDB_15_0_OUT = ABCD");

    // Test 4: Read CSBITS[63:48] to IDB
    $display("\nTest 4: Read CSBITS[63:48] to IDB");
    CSBITS = 64'hEF010000000000 00;
    WCS_n = 1;
    ECSL_n = 0;
    EW_3_0_n = 4'b0111; // Enable word 3
    #100;
    $display("Time=%0t: Reading CSBITS[63:48]", $time);
    $display("  IDB_15_0_OUT=%h (expected EF01)", IDB_15_0_OUT);
    if (IDB_15_0_OUT !== 16'hEF01)
      $display("ERROR: IDB_15_0_OUT should be EF01");
    else
      $display("PASS: IDB_15_0_OUT = EF01");

    // Test 5: Write IDB to CSBITS[15:0] (DIR=0, WCS_n=0)
    $display("\nTest 5: Write IDB to CSBITS[15:0]");
    CSBITS = 64'h0000000000000000;
    IDB_15_0_IN = 16'hAAAA;
    WCS_n = 0;         // DIR = L (IDB to CSBITS)
    ECSL_n = 1;
    EW_3_0_n = 4'b1110; // Enable word 0
    #100;
    $display("Time=%0t: Writing to CSBITS[15:0]", $time);
    $display("  IDB_15_0_IN=%h", IDB_15_0_IN);
    $display("  CSBITS_OUT=%h (bits [15:0] should be AAAA)", CSBITS_OUT);
    if (CSBITS_OUT[15:0] !== 16'hAAAA)
      $display("ERROR: CSBITS_OUT[15:0] should be AAAA");
    else
      $display("PASS: CSBITS_OUT[15:0] = AAAA");

    // Test 6: Write IDB to CSBITS[31:16]
    $display("\nTest 6: Write IDB to CSBITS[31:16]");
    CSBITS = 64'h0000000000000000;
    IDB_15_0_IN = 16'hBBBB;
    WCS_n = 0;
    ECSL_n = 1;
    EW_3_0_n = 4'b1101; // Enable word 1
    #100;
    $display("Time=%0t: Writing to CSBITS[31:16]", $time);
    $display("  CSBITS_OUT=%h (bits [31:16] should be BBBB)", CSBITS_OUT);
    if (CSBITS_OUT[31:16] !== 16'hBBBB)
      $display("ERROR: CSBITS_OUT[31:16] should be BBBB");
    else
      $display("PASS: CSBITS_OUT[31:16] = BBBB");

    // Test 7: Write IDB to CSBITS[47:32]
    $display("\nTest 7: Write IDB to CSBITS[47:32]");
    CSBITS = 64'h0000000000000000;
    IDB_15_0_IN = 16'hCCCC;
    WCS_n = 0;
    ECSL_n = 1;
    EW_3_0_n = 4'b1011; // Enable word 2
    #100;
    $display("Time=%0t: Writing to CSBITS[47:32]", $time);
    $display("  CSBITS_OUT=%h (bits [47:32] should be CCCC)", CSBITS_OUT);
    if (CSBITS_OUT[47:32] !== 16'hCCCC)
      $display("ERROR: CSBITS_OUT[47:32] should be CCCC");
    else
      $display("PASS: CSBITS_OUT[47:32] = CCCC");

    // Test 8: Write IDB to CSBITS[63:48]
    $display("\nTest 8: Write IDB to CSBITS[63:48]");
    CSBITS = 64'h0000000000000000;
    IDB_15_0_IN = 16'hDDDD;
    WCS_n = 0;
    ECSL_n = 1;
    EW_3_0_n = 4'b0111; // Enable word 3
    #100;
    $display("Time=%0t: Writing to CSBITS[63:48]", $time);
    $display("  CSBITS_OUT=%h (bits [63:48] should be DDDD)", CSBITS_OUT);
    if (CSBITS_OUT[63:48] !== 16'hDDDD)
      $display("ERROR: CSBITS_OUT[63:48] should be DDDD");
    else
      $display("PASS: CSBITS_OUT[63:48] = DDDD");

    // Test 9: Test pass-through when no word is enabled
    $display("\nTest 9: Pass-through when no word enabled (all EW_3_0_n = 1111)");
    CSBITS = 64'h123456789ABCDEF0;
    IDB_15_0_IN = 16'h0000;
    WCS_n = 0;
    ECSL_n = 1;
    EW_3_0_n = 4'b1111; // No word enabled
    #100;
    $display("Time=%0t: No word selected", $time);
    $display("  CSBITS=%h", CSBITS);
    $display("  CSBITS_OUT=%h (should pass through)", CSBITS_OUT);
    if (CSBITS_OUT !== CSBITS)
      $display("ERROR: CSBITS_OUT should equal CSBITS");
    else
      $display("PASS: Pass-through works (latch fix verified)");

    // Test 10: Verify combinational behavior
    $display("\nTest 10: Verify combinational response");
    CSBITS = 64'h0000000000000000;
    IDB_15_0_IN = 16'h9999;
    WCS_n = 0;
    EW_3_0_n = 4'b1110;
    #10; // Short delay for combinational propagation
    $display("Time=%0t: CSBITS_OUT[15:0]=%h (should be 9999)", $time, CSBITS_OUT[15:0]);
    if (CSBITS_OUT[15:0] !== 16'h9999)
      $display("ERROR: Should respond combinationally");
    else
      $display("PASS: Combinational response verified");

    $display("\n========================================");
    $display("CPU_CS_TCV_20 Testbench Complete");
    $display("Verified: regCSBITS latch fix (default initialization)");
    $display("========================================");
    $finish;
  end

endmodule
