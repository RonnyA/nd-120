`timescale 1ns / 1ps

/**************************************************************************
** Testbench for IDT6168A_20 (4K x 4 static RAM model)
**
** Verifies:
**   1. Reset behavior (output = 0 when reset asserted)
**   2. Basic write-then-read at one address
**   3. Multiple address write-then-read
**   4. Sequential read with address change — measures latency
**   5. CE_n high (chip disabled) — output should go to 0
**   6. WE_n low (write mode) — read output should go to 0
**   7. Write-then-read in adjacent cycles — checks for forwarding behavior
**
** The testbench prints what happens at each sysclk so the human can SEE
** the actual timing relationship between address change, CE_n/WE_n
** transitions, and D_OUT updates.
**
** The original IDT6168 chip is asynchronous SRAM:
**   - 15-20ns access time, combinational read
**   - No clock pin
**   - Read: when CE_n=0 and WE_n=1, D_OUT = memory[A] after access time
**   - Write: when CE_n=0 and WE_n=0, memory[A] <= D_IN while WE_n asserted
**
** The Verilog model uses a clock because FPGA block RAM cannot be async.
** This testbench measures whether the model's clocked behavior is
** "close enough" to the original chip behavior for the design to work.
**
** Run with iverilog from this directory:
**   make IDT6168A_20_tb
**   ./IDT6168A_20_tb
***************************************************************************/

module IDT6168A_20_tb;

  // Sysclk: 100 MHz, 10 ns period
  reg clk = 0;
  always #5 clk = ~clk;

  // DUT ports
  reg         reset_n;
  reg [11:0]  A_11_0;
  reg         CE_n;
  reg         WE_n;
  reg [3:0]   D_3_0_IN;
  wire [3:0]  D_3_0_OUT;

  IDT6168A_20 uut (
    .clk(clk),
    .reset_n(reset_n),
    .A_11_0(A_11_0),
    .CE_n(CE_n),
    .WE_n(WE_n),
    .D_3_0_IN(D_3_0_IN),
    .D_3_0_OUT(D_3_0_OUT)
  );

  // Pass/fail tracking
  integer pass_count = 0;
  integer fail_count = 0;
  integer test_no    = 0;

  task expect_eq(input [3:0] expected, input [255:0] label);
    begin
      if (D_3_0_OUT === expected) begin
        $display("    PASS: %0s -- D_OUT = 4'h%h", label, D_3_0_OUT);
        pass_count = pass_count + 1;
      end else begin
        $display("    FAIL: %0s -- expected 4'h%h, got 4'h%h", label, expected, D_3_0_OUT);
        fail_count = fail_count + 1;
      end
    end
  endtask

  task tick;
    begin
      @(posedge clk);
      #1; // settle
    end
  endtask

  task show_state(input [255:0] label);
    begin
      $display("    %0s: t=%0t  A=%h CE_n=%b WE_n=%b D_IN=%h | D_OUT=%h",
               label, $time, A_11_0, CE_n, WE_n, D_3_0_IN, D_3_0_OUT);
    end
  endtask

  // Drive a single write transaction: address + data, with CE_n=0 and WE_n=0
  // for one full clock period.
  task do_write(input [11:0] addr, input [3:0] data);
    begin
      A_11_0   = addr;
      D_3_0_IN = data;
      CE_n     = 1'b0;
      WE_n     = 1'b0;
      tick;
      tick;
      // De-assert WE_n after the write cycle
      WE_n     = 1'b1;
    end
  endtask

  // Drive a single read transaction: address + CE_n=0 + WE_n=1.
  // Holds the read state for several cycles so we can observe how the
  // model latches and outputs.
  task do_read(input [11:0] addr);
    begin
      A_11_0   = addr;
      D_3_0_IN = 4'h0;
      CE_n     = 1'b0;
      WE_n     = 1'b1;
      tick;
      tick;
    end
  endtask

  initial begin
    $dumpfile("IDT6168A_20_tb.vcd");
    $dumpvars(0, IDT6168A_20_tb);

    // Initialize
    reset_n  = 1'b0;
    A_11_0   = 12'h000;
    CE_n     = 1'b1;
    WE_n     = 1'b1;
    D_3_0_IN = 4'h0;

    // Hold reset
    tick; tick; tick;
    reset_n = 1'b1;
    tick;

    $display("");
    $display("================================================================");
    $display(" IDT6168A_20 testbench — RAM read/write timing verification");
    $display("================================================================");

    // ---------------------------------------------------------------
    // Test 1: After reset, with CE_n=1 (chip disabled), output = 0
    // ---------------------------------------------------------------
    test_no = 1;
    $display("");
    $display("Test %0d: Reset state with CE_n=1 (chip disabled)", test_no);
    A_11_0 = 12'h000; CE_n = 1'b1; WE_n = 1'b1; D_3_0_IN = 4'h0;
    tick; tick;
    expect_eq(4'h0, "Output is 0 when CE_n=1");

    // ---------------------------------------------------------------
    // Test 2: Basic write-then-read at address 0x000
    // ---------------------------------------------------------------
    test_no = 2;
    $display("");
    $display("Test %0d: Basic write-then-read at addr 0x000, value 0xA", test_no);
    do_write(12'h000, 4'hA);
    do_read(12'h000);
    expect_eq(4'hA, "Read addr 0x000 = 0xA");

    // ---------------------------------------------------------------
    // Test 3: Write multiple addresses, read them back
    // ---------------------------------------------------------------
    test_no = 3;
    $display("");
    $display("Test %0d: Write addresses 0..3 with values 1,2,3,4 then read back", test_no);
    do_write(12'h000, 4'h1);
    do_write(12'h001, 4'h2);
    do_write(12'h002, 4'h3);
    do_write(12'h003, 4'h4);

    do_read(12'h000); expect_eq(4'h1, "Read addr 0x000 = 1");
    do_read(12'h001); expect_eq(4'h2, "Read addr 0x001 = 2");
    do_read(12'h002); expect_eq(4'h3, "Read addr 0x002 = 3");
    do_read(12'h003); expect_eq(4'h4, "Read addr 0x003 = 4");

    // ---------------------------------------------------------------
    // Test 4: Latency measurement — change address, observe output
    //
    // Sets up memory[10]=0x5 and memory[11]=0xF in advance, then changes
    // address from 10 to 11 and watches D_OUT every sysclk to see when
    // it switches.
    // ---------------------------------------------------------------
    test_no = 4;
    $display("");
    $display("Test %0d: Read latency measurement", test_no);
    do_write(12'h010, 4'h5);
    do_write(12'h011, 4'hF);

    // Settle on address 0x010
    A_11_0 = 12'h010; CE_n = 1'b0; WE_n = 1'b1; D_3_0_IN = 4'h0;
    tick; tick;
    show_state("Before A change (A=0x010)");

    // Change address at the start of a sysclk
    @(posedge clk);
    A_11_0 = 12'h011;
    show_state("Just after A change to 0x011 (same edge)");

    // Sample at each subsequent sysclk to see when D_OUT updates
    @(posedge clk); show_state("+1 sysclk after A change");
    @(posedge clk); show_state("+2 sysclks after A change");
    @(posedge clk); show_state("+3 sysclks after A change");

    // Final value should be 0xF
    expect_eq(4'hF, "Read addr 0x011 = 0xF after settling");

    // ---------------------------------------------------------------
    // Test 5: CE_n masking — assert CE_n high mid-read
    // ---------------------------------------------------------------
    test_no = 5;
    $display("");
    $display("Test %0d: CE_n masking", test_no);
    do_write(12'h020, 4'h7);
    do_read(12'h020);
    show_state("Reading 0x020 with CE_n=0");

    A_11_0 = 12'h020; CE_n = 1'b1; WE_n = 1'b1;
    tick; tick;
    show_state("After CE_n raised to 1");
    expect_eq(4'h0, "Output is 0 when CE_n=1");

    // ---------------------------------------------------------------
    // Test 6: WE_n low (write mode) masks read output
    // ---------------------------------------------------------------
    test_no = 6;
    $display("");
    $display("Test %0d: WE_n low (write mode) masks output", test_no);
    do_write(12'h030, 4'hC);
    do_read(12'h030);
    show_state("Reading 0x030 with WE_n=1");

    // Drop WE_n to 0 (write mode)
    A_11_0 = 12'h030; CE_n = 1'b0; WE_n = 1'b0; D_3_0_IN = 4'hE;
    tick; tick;
    show_state("Now WE_n=0, write mode");
    expect_eq(4'h0, "Output is 0 when WE_n=0");

    // De-assert write
    WE_n = 1'b1;
    tick; tick;

    // ---------------------------------------------------------------
    // Test 7: Write-then-read forwarding (write A, read same A next cycle)
    //
    // Models the WCS feedback case: writes during LCS load are followed
    // immediately by reads. We want to verify what the model does.
    // ---------------------------------------------------------------
    test_no = 7;
    $display("");
    $display("Test %0d: Write-then-read same address back-to-back", test_no);
    A_11_0 = 12'h040; CE_n = 1'b0; WE_n = 1'b0; D_3_0_IN = 4'h9;
    show_state("Setting up write to 0x040 = 9");
    tick;
    show_state("After 1 sysclk of write");
    tick;
    show_state("After 2 sysclks of write");
    // Switch to read of same address
    WE_n = 1'b1;
    show_state("WE_n raised, now reading 0x040");
    tick;
    show_state("+1 sysclk after WE_n=1");
    tick;
    show_state("+2 sysclks after WE_n=1");
    expect_eq(4'h9, "Read addr 0x040 = 9 after recent write");

    // ---------------------------------------------------------------
    // Summary
    // ---------------------------------------------------------------
    $display("");
    $display("================================================================");
    $display(" IDT6168A_20 testbench summary: %0d PASS / %0d FAIL", pass_count, fail_count);
    $display("================================================================");

    $finish;
  end

  // Safety timeout
  initial begin
    #20000;
    $display("TIMEOUT");
    $finish;
  end

endmodule
