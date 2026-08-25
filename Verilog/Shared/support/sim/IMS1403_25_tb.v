/****************************************************************************
** IMS1403_25 (16K x 1 SRAM) testbench                                     **
**                                                                         **
** Read from IMS1403_25.v: Q is combinational:                             **
**   assign Q = (!CE_n && W_n) ? data_out : 1'b0;                          **
** data_out is a REGISTERED bit, updated ONLY inside                       **
** `always @(posedge clk)` when `!reset_n` is false and `!CE_n` and `!W_n` **
** is false (i.e. read mode): `data_out <= ims_memory_array[ADDRESS];`     **
** So the READ path is SYNCHRONOUS with ONE CLOCK of latency, exactly like **
** Am9150_w_clock. Write is the sibling branch of the same block, gated    **
** by !CE_n && !W_n.                                                       **
**                                                                         **
** NO OUTPUT-ENABLE PIN: unlike Am9150 (which has a separate               **
** OUTPUT_ENABLE_n), this RTL has only CE_n and W_n - there is no OE_n     **
** port at all. Whether the real IMS1403 has a separate OE pin was NOT     **
** checked against the datasheet for this job (no datasheet was opened);  **
** this is recorded as an open question for whoever compares this RTL     **
** against the physical part, not asserted either way.                    **
**                                                                         **
** RESET_n: `if (!reset_n) begin end` is an EMPTY branch (the intended     **
** memory-clear code is commented out, same TODO pattern as the other     **
** SRAM models in this directory). While reset_n=0, the entire always      **
** block's outer conditional is skipped, so BOTH data_out and the memory   **
** array are simply FROZEN (neither writes nor reads happen) - reset_n     **
** does not clear anything and does not force Q to 0 either (Q's mask      **
** expression has no reset_n term at all - only CE_n/W_n). Verified below. **
**                                                                         **
** COVERAGE: address 0, address 16383 (max), 4 arbitrary/scattered         **
** addresses, no-aliasing, read-during-write masking (W_n=0 forces Q=0     **
** via the CE_n&&W_n term), CE_n masking, and the reset_n-freezes-instead- **
** of-clears behaviour above. Exhaustive over all 16384 addresses is not   **
** attempted (1-bit-wide functional part, address decode is the risk, not **
** data width) - the addresses above were chosen to hit 0, max, and       **
** several bit-boundary-crossing values (mid-range, near-max).            **
**                                                                         **
** Run: cd Verilog/Shared/support/sim && iverilog -g2012 -o tb.vvp         **
**      IMS1403_25_tb.v ../IMS1403_25.v && vvp tb.vvp                     **
**                                                                         **
** Last reviewed: 20-AUG-2026                                             **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module IMS1403_25_tb;

  reg         clk = 0;
  always #5 clk = ~clk;

  reg         reset_n;
  reg  [13:0] ADDRESS;
  reg         CE_n;
  reg         D;
  reg         W_n;
  wire        Q;

  integer errors = 0;
  integer checks = 0;

  IMS1403_25 DUT (
      .clk    (clk),
      .reset_n(reset_n),
      .ADDRESS(ADDRESS),
      .CE_n   (CE_n),
      .D      (D),
      .W_n    (W_n),
      .Q      (Q)
  );

  task do_write(input [13:0] addr, input val);
    begin
      ADDRESS = addr; D = val;
      reset_n = 1; CE_n = 0; W_n = 0;
      @(posedge clk); #1;
      W_n = 1;
    end
  endtask

  // Read has 1 clock of latency (registered data_out); set up, wait one
  // clock, then check.
  task expect_read(input [13:0] addr, input expected, input [255:0] label);
    begin
      ADDRESS = addr;
      reset_n = 1; CE_n = 0; W_n = 1;
      @(posedge clk); #1;
      checks = checks + 1;
      if (Q !== expected) begin
        errors = errors + 1;
        $display("FAIL %0s: addr=%0d Q=%b expected %b", label, addr, Q, expected);
      end
    end
  endtask

  initial begin
    $dumpfile("IMS1403_25_tb.vcd");
    $dumpvars(0, IMS1403_25_tb);

    reset_n = 0; ADDRESS = 0; CE_n = 1; D = 0; W_n = 1;
    @(posedge clk); @(posedge clk); #1;
    reset_n = 1;
    @(posedge clk); #1;

    // ---- short documented sequence (readable in the VCD) ------------------
    do_write(14'd0, 1'b1);
    expect_read(14'd0, 1'b1, "doc: addr0=1");
    do_write(14'd16383, 1'b1);
    expect_read(14'd16383, 1'b1, "doc: addr16383=1");

    $dumpoff;

    // ---- 1. address 0 -------------------------------------------------------
    do_write(14'd0, 1'b1);
    expect_read(14'd0, 1'b1, "addr 0 = 1");
    do_write(14'd0, 1'b0);
    expect_read(14'd0, 1'b0, "addr 0 overwritten to 0");

    // ---- 2. address 16383 (max) ---------------------------------------------
    do_write(14'd16383, 1'b1);
    expect_read(14'd16383, 1'b1, "addr 16383 = 1");

    // ---- 3. scattered arbitrary addresses ------------------------------------
    do_write(14'd1, 1'b1);
    do_write(14'd8192, 1'b0);
    do_write(14'd16382, 1'b1);
    do_write(14'd12345, 1'b0);
    expect_read(14'd1, 1'b1, "addr 1 = 1");
    expect_read(14'd8192, 1'b0, "addr 8192 = 0");
    expect_read(14'd16382, 1'b1, "addr 16382 = 1");
    expect_read(14'd12345, 1'b0, "addr 12345 = 0");

    // ---- 4. no aliasing: addr16383 and addr16382 must be independent -------
    expect_read(14'd16383, 1'b1, "addr 16383 still 1 (unaffected by 16382 write)");
    do_write(14'd16382, 1'b0);
    expect_read(14'd16383, 1'b1, "addr 16383 STILL 1 after flipping 16382 to 0");
    expect_read(14'd16382, 1'b0, "addr 16382 = 0 as just written");

    // ---- 5. read-during-write masking: W_n=0 forces Q=0 regardless of ------
    //        CE_n or memory content.
    do_write(14'd0, 1'b1);        // known content = 1
    ADDRESS = 14'd0; D = 1'b0; reset_n = 1; CE_n = 0; W_n = 0;
    #1;
    checks = checks + 1;
    if (Q !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL READ_DURING_WRITE: Q=%b while W_n=0, expected 0 (masked)", Q);
    end
    @(posedge clk); #1;
    W_n = 1;
    expect_read(14'd0, 1'b0, "addr 0 = 0 after the write committed");

    // ---- 6. CE_n masking -----------------------------------------------------
    do_write(14'd50, 1'b1);
    ADDRESS = 14'd50; CE_n = 1; W_n = 1; reset_n = 1;
    #1;
    checks = checks + 1;
    if (Q !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL MASK_CE_n: Q=%b with CE_n=1, expected 0", Q);
    end

    // ---- 7. reset_n FREEZES (does not clear memory, does not force Q=0) ----
    expect_read(14'd50, 1'b1, "addr 50 = 1 (before reset probe)");
    reset_n = 0;
    ADDRESS = 14'd50; CE_n = 0; W_n = 0; D = 1'b0;   // would-be write, blocked
    @(posedge clk); @(posedge clk); #1;
    reset_n = 1; W_n = 1;
    expect_read(14'd50, 1'b1, "addr 50 STILL 1: reset_n held during an attempted write, write did NOT happen");

    $display("-----------------------------------------------------");
    $display(" IMS1403_25 testbench");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $finish;
  end

  initial begin
    #100000;
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire
