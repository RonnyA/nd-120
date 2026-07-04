`timescale 1ns / 1ps

/**************************************************************************
** Testbench for F595
** Tests synchronous RS flip-flop sampled on sysclk
** R/S Latch with Gated input
***************************************************************************/

module F595_tb;

  // System clock
  reg sysclk;
  reg sys_rst_n;

  // Inputs
  reg H01_S;  // Set
  reg H02_R;  // Reset
  reg H03_G;  // Gate Enable

  // Outputs
  wire N01_Q;   // Q
  wire N02_QB;  // Qn

  // Generate 100MHz sysclk
  initial sysclk = 0;
  always #5 sysclk = ~sysclk;  // 10ns period

  // Instantiate the Unit Under Test (UUT)
  F595 uut (
    .sysclk(sysclk),
    .sys_rst_n(sys_rst_n),
    .H01_S(H01_S),
    .H02_R(H02_R),
    .H03_G(H03_G),
    .N01_Q(N01_Q),
    .N02_QB(N02_QB)
  );

  // Test vectors
  initial begin
    $display("F595 Testbench - Synchronous RS FF sampled on sysclk");
    $display("========================================");
    $display("");
    $display("Time\tS\tR\tG\t|\tQ\tQn");

    // Initialize inputs
    sys_rst_n = 0;  // Assert reset
    H01_S = 0;
    H02_R = 0;
    H03_G = 0;
    #20;
    sys_rst_n = 1;  // Release reset
    #80;

    // Test 1: Set condition (S=1, R=1) with gate high
    $display("\nTest 1: Set condition (S=1, R=1) with G=1");
    H01_S = 1;
    H02_R = 1;
    H03_G = 1;
    #20;  // Wait for sysclk edge
    $display("%0t\t%b\t%b\t%b\t|\t%b\t%b", $time, H01_S, H02_R, H03_G, N01_Q, N02_QB);
    if (N01_Q !== 1'b1 || N02_QB !== 1'b1)
      $display("ERROR: Both Q and Qn should be 1");
    else
      $display("PASS: Q=1, Qn=1 (set condition)");

    #50;

    // Test 2: Reset condition (S=0, R=1) with gate high
    $display("\nTest 2: Reset condition (S=0, R=1) with G=1");
    H01_S = 0;
    H02_R = 1;
    H03_G = 1;
    #20;
    $display("%0t\t%b\t%b\t%b\t|\t%b\t%b", $time, H01_S, H02_R, H03_G, N01_Q, N02_QB);
    if (N01_Q !== 1'b0 || N02_QB !== 1'b1)
      $display("ERROR: Q should be 0, Qn should be 1");
    else
      $display("PASS: Q=0, Qn=1 (reset condition)");

    #50;

    // Test 3: Set condition (S=1, R=0) with gate high
    $display("\nTest 3: Set condition (S=1, R=0) with G=1");
    H01_S = 1;
    H02_R = 0;
    H03_G = 1;
    #20;
    $display("%0t\t%b\t%b\t%b\t|\t%b\t%b", $time, H01_S, H02_R, H03_G, N01_Q, N02_QB);
    if (N01_Q !== 1'b1 || N02_QB !== 1'b0)
      $display("ERROR: Q should be 1, Qn should be 0");
    else
      $display("PASS: Q=1, Qn=0 (set condition)");

    #50;

    // Test 4: Hold condition (S=0, R=0) with gate high - should maintain state
    $display("\nTest 4: Hold condition (S=0, R=0) with G=1 - should maintain state");
    H01_S = 0;
    H02_R = 0;
    H03_G = 1;
    #20;
    $display("%0t\t%b\t%b\t%b\t|\t%b\t%b", $time, H01_S, H02_R, H03_G, N01_Q, N02_QB);
    if (N01_Q !== 1'b1 || N02_QB !== 1'b0)
      $display("ERROR: Should maintain previous state Q=1, Qn=0");
    else
      $display("PASS: State maintained Q=1, Qn=0");

    #50;

    // Test 5: Gate low - changes to S/R should not affect output
    $display("\nTest 5: Gate low - S/R changes should not affect output");
    H03_G = 0;
    #20;
    H01_S = 0;
    H02_R = 1;
    #20;
    $display("%0t\t%b\t%b\t%b\t|\t%b\t%b", $time, H01_S, H02_R, H03_G, N01_Q, N02_QB);
    if (N01_Q !== 1'b1 || N02_QB !== 1'b0)
      $display("ERROR: Output should not change when G=0");
    else
      $display("PASS: Output held while G=0");

    #50;

    // Test 6: Gate goes high again - should now respond
    $display("\nTest 6: Gate goes high - should respond to current S/R (S=0, R=1)");
    H03_G = 1;
    #20;
    $display("%0t\t%b\t%b\t%b\t|\t%b\t%b", $time, H01_S, H02_R, H03_G, N01_Q, N02_QB);
    if (N01_Q !== 1'b0 || N02_QB !== 1'b1)
      $display("ERROR: Q should be 0, Qn should be 1");
    else
      $display("PASS: Q=0, Qn=1 (reset after gate re-enabled)");

    // Test 7: Constant gate high, toggling S/R (mimics DGA_POW usage)
    $display("\nTest 7: Constant G=1, toggling S/R (DGA_POW pattern)");
    H03_G = 1;
    H01_S = 1; H02_R = 0;
    #20;
    $display("%0t: S=1,R=0 -> Q=%b, Qn=%b", $time, N01_Q, N02_QB);

    H01_S = 0; H02_R = 0;
    #20;
    $display("%0t: S=0,R=0 -> Q=%b, Qn=%b (hold)", $time, N01_Q, N02_QB);

    H01_S = 0; H02_R = 1;
    #20;
    $display("%0t: S=0,R=1 -> Q=%b, Qn=%b", $time, N01_Q, N02_QB);

    H01_S = 0; H02_R = 0;
    #20;
    $display("%0t: S=0,R=0 -> Q=%b, Qn=%b (hold)", $time, N01_Q, N02_QB);

    $display("\n========================================");
    $display("F595 Testbench Complete");
    $display("========================================");
    $finish;
  end

endmodule
