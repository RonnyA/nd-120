`timescale 1ns/1ns

module F714_testbench;

  // Inputs
  reg H01_T;
  reg H02_R;
  reg H03_S;

  // Outputs
  wire N01_Q;
  wire N02_QB;

  // Instantiate the UUT (Unit Under Test)
  F714 uut (
    .H01_T(H01_T),
    .H02_R(H02_R),
    .H03_S(H03_S),
    .N01_Q(N01_Q),
    .N02_QB(N02_QB)
  );

  initial begin
    $dumpfile("F714_tb.vcd");
    $dumpvars(0, F714_testbench);


    // Initialize inputs
    H01_T = 0;
    H02_R = 0;    
    H03_S = 0;

    // Apply reset
    #10 H02_R = 1;

    // Apply different test cases
    // Test reset condition
    #10;
    H02_R = 1;
    #10;
    H02_R = 0;

    // Test set condition
    #10;
    H03_S = 1;
    #10;
    H03_S = 0;

    // Test toggle condition
    #10;
    H02_R = 0;
    H03_S = 0;
    H01_T = 1;
    #20;
    H01_T = 0;

    // Test toggle condition #2
    #10;
    H02_R = 0;
    H03_S = 0;
    H01_T = 1;
    #20;
    H01_T = 0;


    // Test prohibition condition
    #10;
    H02_R = 1;
    H03_S = 1;
    #10;
    H02_R = 0;
    H03_S = 0;

    // Test moving from prohibition to toggle
    #10;
    H02_R = 1;
    H03_S = 1;
    #10;
    H02_R = 0;
    H03_S = 0;
    #20;
    
    // Test toggle condition #3
    #10;
    H02_R = 0;
    H03_S = 0;
    H01_T = 1;
    #20;
    H01_T = 0;


    // Test toggle condition #4
    #10;
    H02_R = 0;
    H03_S = 0;
    H01_T = 1;
    #20;
    H01_T = 0;

    // End of test
    #10 $finish;
  end

  initial begin
    $monitor("At time %t, T = %b, R = %b, S = %b, Q = %b, QB = %b",
             $time, H01_T, H02_R, H03_S, N01_Q, N02_QB);
  end

endmodule
