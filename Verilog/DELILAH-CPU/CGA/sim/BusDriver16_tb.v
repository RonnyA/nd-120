`timescale 1ns / 1ps

/**************************************************************************
** Testbench for BusDriver16
** Tests the fix for latch inference in IO_reg and A_reg
** Changed from non-blocking to blocking assignments with defaults
***************************************************************************/

module BusDriver16_tb;

  // Inputs
  reg EN;
  reg TN;
  reg [15:0] A_15_0_IN;
  reg [15:0] IO_15_0_IN;

  // Outputs
  wire [15:0] A_15_0_OUT;
  wire [15:0] IO_15_0_OUT;

  // Instantiate the Unit Under Test (UUT)
  BusDriver16 uut (
    .EN(EN),
    .TN(TN),
    .A_15_0_IN(A_15_0_IN),
    .A_15_0_OUT(A_15_0_OUT),
    .IO_15_0_IN(IO_15_0_IN),
    .IO_15_0_OUT(IO_15_0_OUT)
  );

  // Test vectors
  initial begin
    $display("BusDriver16 Testbench - Testing latch fix with blocking assignments");
    $display("Time\tEN\tTN\tA_IN\t\tIO_IN\t\t|\tA_OUT\t\tIO_OUT");

    // Initialize inputs
    EN = 0;
    TN = 0;
    A_15_0_IN = 16'h0000;
    IO_15_0_IN = 16'h0000;
    #100;

    // Test 1: Write A to IO (EN=0, TN=1)
    $display("\nTest 1: Write A to IO (EN=0, TN=1)");
    EN = 0;
    TN = 1;
    A_15_0_IN = 16'hABCD;
    IO_15_0_IN = 16'h0000;
    #100;
    $display("Time=%0t: A_IN=%h, IO_IN=%h | A_OUT=%h, IO_OUT=%h",
             $time, A_15_0_IN, IO_15_0_IN, A_15_0_OUT, IO_15_0_OUT);
    if (IO_15_0_OUT !== 16'hABCD)
      $display("ERROR: IO_OUT should be ABCD (from A_IN)");
    else
      $display("PASS: IO_OUT = ABCD");
    if (A_15_0_OUT !== IO_15_0_IN)
      $display("ERROR: A_OUT should equal IO_IN");
    else
      $display("PASS: A_OUT = IO_IN (%h)", A_15_0_OUT);

    // Test 2: Write different value A to IO
    $display("\nTest 2: Write different A to IO");
    EN = 0;
    TN = 1;
    A_15_0_IN = 16'h1234;
    IO_15_0_IN = 16'h0000;
    #100;
    $display("Time=%0t: A_IN=%h, IO_IN=%h | A_OUT=%h, IO_OUT=%h",
             $time, A_15_0_IN, IO_15_0_IN, A_15_0_OUT, IO_15_0_OUT);
    if (IO_15_0_OUT !== 16'h1234)
      $display("ERROR: IO_OUT should be 1234");
    else
      $display("PASS: IO_OUT = 1234");

    // Test 3: Read IO to A (EN=1, TN=1)
    $display("\nTest 3: Read IO to A (EN=1, TN=1)");
    EN = 1;
    TN = 1;
    A_15_0_IN = 16'h0000;
    IO_15_0_IN = 16'h5678;
    #100;
    $display("Time=%0t: A_IN=%h, IO_IN=%h | A_OUT=%h, IO_OUT=%h",
             $time, A_15_0_IN, IO_15_0_IN, A_15_0_OUT, IO_15_0_OUT);
    if (A_15_0_OUT !== 16'h5678)
      $display("ERROR: A_OUT should be 5678 (from IO_IN)");
    else
      $display("PASS: A_OUT = 5678");
    if (IO_15_0_OUT !== 16'h0000)
      $display("ERROR: IO_OUT should be 0 when EN=1");
    else
      $display("PASS: IO_OUT = 0 (high-Z represented as 0)");

    // Test 4: Test with TN=0 (output disabled)
    $display("\nTest 4: TN=0 (outputs disabled/high-Z)");
    EN = 0;
    TN = 0;
    A_15_0_IN = 16'hFFFF;
    IO_15_0_IN = 16'h9ABC;
    #100;
    $display("Time=%0t: A_IN=%h, IO_IN=%h | A_OUT=%h, IO_OUT=%h",
             $time, A_15_0_IN, IO_15_0_IN, A_15_0_OUT, IO_15_0_OUT);
    if (IO_15_0_OUT !== 16'h0000)
      $display("ERROR: IO_OUT should be 0 when TN=0");
    else
      $display("PASS: IO_OUT = 0 (disabled)");
    if (A_15_0_OUT !== IO_15_0_IN)
      $display("ERROR: A_OUT should equal IO_IN");
    else
      $display("PASS: A_OUT = IO_IN (%h)", A_15_0_OUT);

    // Test 5: Verify combinational behavior (immediate response)
    $display("\nTest 5: Verify combinational behavior (immediate response to input changes)");
    EN = 0;
    TN = 1;
    A_15_0_IN = 16'hDEAD;
    #10; // Short delay
    $display("Time=%0t: Changed A_IN to DEAD", $time);
    #10; // Another short delay for combinational propagation
    $display("Time=%0t: IO_OUT=%h (should be DEAD)", $time, IO_15_0_OUT);
    if (IO_15_0_OUT !== 16'hDEAD)
      $display("ERROR: IO_OUT should respond immediately to A_IN change");
    else
      $display("PASS: IO_OUT updated combinationally");

    // Test 6: Toggle EN and verify behavior changes
    $display("\nTest 6: Toggle EN from 0 to 1");
    EN = 0;
    TN = 1;
    A_15_0_IN = 16'hBEEF;
    IO_15_0_IN = 16'hCAFE;
    #50;
    $display("Time=%0t: EN=0, IO_OUT=%h", $time, IO_15_0_OUT);
    EN = 1;
    #50;
    $display("Time=%0t: EN=1, IO_OUT=%h, A_OUT=%h", $time, IO_15_0_OUT, A_15_0_OUT);
    if (A_15_0_OUT !== 16'hCAFE)
      $display("ERROR: A_OUT should be CAFE when EN=1");
    else
      $display("PASS: Direction change works correctly");

    $display("\n========================================");
    $display("BusDriver16 Testbench Complete");
    $display("========================================");
    $finish;
  end

endmodule
