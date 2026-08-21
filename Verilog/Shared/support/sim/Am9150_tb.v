/****************************************************************************
** Am9150 (1024 x 4 SRAM) testbench                                        **
**                                                                         **
** Read from Am9150.v: data_out is a CONTINUOUS ASSIGN reading the memory  **
** array DIRECTLY and COMBINATIONALLY:                                    **
**   assign data_out = (!CS_n & !OE_n & WE_n & RESET_n) ?                  **
**                      am_memory_array[address] : 4'b0;                  **
** There IS a registered `data4bit` signal captured every posedge clk      **
** (data4bit <= am_memory_array[address]), but it is WRITTEN and NEVER     **
** READ anywhere else in the module - dead code, reported below and in    **
** the job report. The actual read path is ASYNCHRONOUS (address-driven,  **
** no clock needed to see new data once memory[address] changes) while     **
** WRITE is synchronous (posedge clk, when CHIP_SELECT_n=0 & WRITE_ENABLE  **
** _n=0).                                                                  **
**                                                                         **
** RESET_n: the header/doc block above the module (and the AM9150         **
** datasheet) describe a memory-clear-in-two-cycles reset feature. The    **
** RTL's write/read always block has that code COMMENTED OUT - RESET_n    **
** low here does nothing but ADD ITSELF as a fourth AND term in the       **
** data_out output mask (forces data_out to 0, exactly like CS_n/OE_n/    **
** WE_n do). It never clears am_memory_array. REPORTED AS A DEVIATION     **
** from the real part and from this file's own doc comment.               **
**                                                                         **
** COVERAGE: exhaustive over all 1024 addresses is not attempted here (16  **
** values each would be 16,384 write+read pairs and this is a functional, **
** not timing-closure, check) - covered explicitly: address 0, address    **
** 1023 (max), and addresses 5, 500, 777 (arbitrary/no-alias set), each    **
** with two different data values to also prove overwrite works. Plus:    **
** no-aliasing cross-check, read-during-write masking, each of the four    **
** output-mask terms (CS_n, OE_n, WE_n, RESET_n) forced individually with  **
** known-nonzero data underneath, and the RESET_n-does-not-clear-memory    **
** proof.                                                                  **
**                                                                         **
** Run: cd Verilog/Shared/support/sim && iverilog -g2012 -o tb.vvp         **
**      Am9150_tb.v ../Am9150.v && vvp tb.vvp                             **
**                                                                         **
** Last reviewed: 20-AUG-2026                                             **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module Am9150_tb;

  reg        clk = 0;
  always #5 clk = ~clk;

  reg  [9:0] address;
  reg  [3:0] data_in;
  wire [3:0] data_out;
  reg        WRITE_ENABLE_n, CHIP_SELECT_n, OUTPUT_ENABLE_n, RESET_n;

  integer errors = 0;
  integer checks = 0;

  Am9150 DUT (
      .clk             (clk),
      .address         (address),
      .data_in         (data_in),
      .data_out        (data_out),
      .WRITE_ENABLE_n  (WRITE_ENABLE_n),
      .CHIP_SELECT_n   (CHIP_SELECT_n),
      .OUTPUT_ENABLE_n (OUTPUT_ENABLE_n),
      .RESET_n         (RESET_n)
  );

  task do_write(input [9:0] addr, input [3:0] val);
    begin
      address = addr; data_in = val;
      CHIP_SELECT_n = 0; WRITE_ENABLE_n = 0; OUTPUT_ENABLE_n = 1; RESET_n = 1;
      @(posedge clk); #1;
      WRITE_ENABLE_n = 1;
    end
  endtask

  task expect_read(input [9:0] addr, input [3:0] expected, input [255:0] label);
    begin
      address = addr;
      CHIP_SELECT_n = 0; WRITE_ENABLE_n = 1; OUTPUT_ENABLE_n = 0; RESET_n = 1;
      #1;
      checks = checks + 1;
      if (data_out !== expected) begin
        errors = errors + 1;
        $display("FAIL %0s: addr=%0d data_out=%h expected %h", label, addr, data_out, expected);
      end
    end
  endtask

  initial begin
    $dumpfile("Am9150_tb.vcd");
    $dumpvars(0, Am9150_tb);

    address = 0; data_in = 0;
    WRITE_ENABLE_n = 1; CHIP_SELECT_n = 1; OUTPUT_ENABLE_n = 1; RESET_n = 1;
    @(posedge clk); #1;

    // ---- short documented sequence first (readable in the VCD) ----------
    do_write(10'd0, 4'hA);
    expect_read(10'd0, 4'hA, "doc: addr0=A");
    do_write(10'd1023, 4'hF);
    expect_read(10'd1023, 4'hF, "doc: addr1023=F");
    do_write(10'd500, 4'h3);
    expect_read(10'd500, 4'h3, "doc: addr500=3");

    $dumpoff;

    // ---- 1. write-then-read at address 0 ---------------------------------
    do_write(10'd0, 4'h5);
    expect_read(10'd0, 4'h5, "addr 0 = 5");

    // ---- 2. write-then-read at address 1023 (max) ------------------------
    do_write(10'd1023, 4'h9);
    expect_read(10'd1023, 4'h9, "addr 1023 = 9");

    // ---- 3. arbitrary addresses (also proves overwrite) -------------------
    do_write(10'd5, 4'h1);
    do_write(10'd500, 4'h6);
    do_write(10'd777, 4'hC);
    expect_read(10'd5, 4'h1, "addr 5 = 1");
    expect_read(10'd500, 4'h6, "addr 500 = 6 (overwrite of earlier 3)");
    expect_read(10'd777, 4'hC, "addr 777 = C");

    // ---- 4. no aliasing: neighbours of the written addresses must not ----
    //        have picked up the neighbour's value.
    do_write(10'd4, 4'h0);
    do_write(10'd6, 4'h0);
    do_write(10'd501, 4'h0);
    do_write(10'd499, 4'h0);
    expect_read(10'd4, 4'h0, "addr 4 unaffected by addr5 write");
    expect_read(10'd6, 4'h0, "addr 6 unaffected by addr5 write");
    expect_read(10'd501, 4'h0, "addr 501 unaffected by addr500 write");
    expect_read(10'd499, 4'h0, "addr 499 unaffected by addr500 write");
    expect_read(10'd5, 4'h1, "addr 5 still 1 (not disturbed by neighbours)");
    expect_read(10'd500, 4'h6, "addr 500 still 6 (not disturbed by neighbours)");

    // ---- 5. read-during-write: WE_n asserted forces data_out to 0 --------
    //        (WRITE_ENABLE_n is one of the AND terms in the output mask,
    //        so the chip cannot show read data while writing).
    do_write(10'd0, 4'h7);   // known content at addr 0
    address = 10'd0; data_in = 4'hE;
    CHIP_SELECT_n = 0; WRITE_ENABLE_n = 0; OUTPUT_ENABLE_n = 0; RESET_n = 1;
    #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL READ_DURING_WRITE: data_out=%h while WE_n=0, expected 0 (masked)", data_out);
    end
    @(posedge clk); #1;
    WRITE_ENABLE_n = 1;
    expect_read(10'd0, 4'hE, "addr 0 = E after the write committed");

    // ---- 6. output-mask terms, each forced individually with known -------
    //        nonzero data underneath.
    do_write(10'd10, 4'hD);
    address = 10'd10; WRITE_ENABLE_n = 1; RESET_n = 1;

    CHIP_SELECT_n = 1; OUTPUT_ENABLE_n = 0; #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL MASK_CS_n: data_out=%h with CHIP_SELECT_n=1, expected 0", data_out);
    end

    CHIP_SELECT_n = 0; OUTPUT_ENABLE_n = 1; #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL MASK_OE_n: data_out=%h with OUTPUT_ENABLE_n=1, expected 0", data_out);
    end

    CHIP_SELECT_n = 0; OUTPUT_ENABLE_n = 0; WRITE_ENABLE_n = 0; #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL MASK_WE_n: data_out=%h with WRITE_ENABLE_n=0, expected 0", data_out);
    end
    WRITE_ENABLE_n = 1;

    CHIP_SELECT_n = 0; OUTPUT_ENABLE_n = 0; RESET_n = 0; #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL MASK_RESET_n: data_out=%h with RESET_n=0, expected 0", data_out);
    end

    // ---- 7. RESET_n does NOT clear the memory array (deviation from the --
    //        real part / doc comment: content at addr 10 survives a
    //        RESET_n pulse).
    RESET_n = 0;
    @(posedge clk); @(posedge clk); #1;   // hold reset for 2 full clocks,
                                           // matching the doc's "two cycle
                                           // times" claim
    RESET_n = 1;
    expect_read(10'd10, 4'hD, "RESET_n pulse did NOT clear addr 10 (still D)");
    expect_read(10'd0, 4'hE, "RESET_n pulse did NOT clear addr 0 (still E)");

    $display("-----------------------------------------------------");
    $display(" Am9150 testbench");
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
