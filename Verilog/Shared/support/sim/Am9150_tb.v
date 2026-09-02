/****************************************************************************
** Am9150 (1024 x 4 SRAM) testbench                                        **
**                                                                         **
** Targets Shared/support/Am9150.v with the 29-AUG-2026 memory reset:      **
**                                                                         **
** READ PATH: data_out is a CONTINUOUS ASSIGN reading the array            **
** combinationally, masked by /S, /G, /W, /R AND the location's VALID bit: **
**   assign data_out = (!CS_n & !OE_n & WE_n & RESET_n & valid[address])   **
**                      ? am_memory_array[address] : 4'b0;                 **
** WRITE is synchronous (posedge clk, CS_n=0 & WE_n=0) and sets valid.     **
**                                                                         **
** RESET (/R) - the datasheet "memory reset function": the real part       **
** clears the ENTIRE array to 0 in two cycle times. The model keeps one    **
** valid flip-flop per location: /R low clears all 1024 in ONE clock, a    **
** never-written location reads 0, and NO write is ever dropped.           **
** History: the first model skipped the clear (stale lines survived /R);   **
** the 24-AUG model cleared with a 1024-step sweep that DROPPED writes     **
** while it ran - CACHE-1X0-A00 test 2 writes its test word a few hundred  **
** clocks after a cache clear, the used bit was dropped, and the cache     **
** reported "DATA is taken FROM MEMORY when present in DATA CACHE" on the  **
** board and in Verilator alike (29-AUG-2026). T0 pins that a write right  **
** after power-up is KEPT.                                                 **
**                                                                         **
** COVERAGE:                                                               **
**   T0 power-up: reads 0 before anything is written; all 1024 locations   **
**      read 0; a write issued immediately after power-up is KEPT          **
**   T1 write/read: addr 0, addr 1023, arbitrary set, overwrite,           **
**      no-aliasing neighbours, read-during-write masking                  **
**   T2 output-mask terms /S /G /W /R forced individually                  **
**   T3 /R falling edge clears the ENTIRE array: scatter of written        **
**      locations + full 1024-location scan reads 0 after the sweep,       **
**      and the part accepts writes again afterwards                       **
**                                                                         **
** Self-checking, exact check count enforced; TB_RESULT: PASS / FAIL.      **
**                                                                         **
** Run: make test-am9150   (Shared/support/sim)                            **
**                                                                         **
** Last reviewed: 24-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module Am9150_tb;

  localparam integer EXPECTED_CHECKS = 29;

  reg        clk = 0;
  always #5 clk = ~clk;

  reg  [9:0] address;
  reg  [3:0] data_in;
  wire [3:0] data_out;
  reg        WRITE_ENABLE_n, CHIP_SELECT_n, OUTPUT_ENABLE_n, RESET_n;

  integer errors = 0;
  integer checks = 0;
  integer i, mismatches;

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

  // wait out a clear sweep (1024 steps) with margin
  task sweep_wait;
    begin
      repeat (1200) @(posedge clk);
    end
  endtask

  // scan every location, count nonzero reads, book ONE aggregated check
  task expect_all_zero(input [255:0] label);
    begin
      mismatches = 0;
      CHIP_SELECT_n = 0; WRITE_ENABLE_n = 1; OUTPUT_ENABLE_n = 0; RESET_n = 1;
      for (i = 0; i < 1024; i = i + 1) begin
        address = i[9:0];
        #1;
        if (data_out !== 4'h0) begin
          if (mismatches < 8)
            $display("  %0s: addr=%0d reads %h, expected 0", label, i, data_out);
          mismatches = mismatches + 1;
        end
      end
      checks = checks + 1;
      if (mismatches != 0) begin
        errors = errors + 1;
        $display("FAIL %0s: %0d of 1024 locations nonzero", label, mismatches);
      end
    end
  endtask

  initial begin
    $dumpfile("Am9150_tb.vcd");
    $dumpvars(0, Am9150_tb);

    address = 0; data_in = 0;
    WRITE_ENABLE_n = 1; CHIP_SELECT_n = 1; OUTPUT_ENABLE_n = 1; RESET_n = 1;
    @(posedge clk); #1;

    // ---- T0: power-up ----------------------------------------------------
    // a never-written location reads 0 (no X, no random cold state)
    address = 10'd37;
    CHIP_SELECT_n = 0; WRITE_ENABLE_n = 1; OUTPUT_ENABLE_n = 0; RESET_n = 1;
    #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL T0_READ_AT_POWERUP: data_out=%h, expected 0", data_out);
    end
    // the whole array reads 0 at power-up
    expect_all_zero("T0_ARRAY_ZERO_AT_POWERUP");
    // a write issued right after power-up is KEPT - the 24-AUG sweep model
    // dropped it, and that dropped write was the cache's fault 2
    do_write(10'd900, 4'hB);
    sweep_wait;
    expect_read(10'd900, 4'hB, "T0_WRITE_RIGHT_AFTER_POWERUP_KEPT");

    $dumpoff;

    // ---- T1: normal write/read after the sweep ---------------------------
    do_write(10'd0, 4'h5);
    expect_read(10'd0, 4'h5, "T1 addr 0 = 5");

    do_write(10'd1023, 4'h9);
    expect_read(10'd1023, 4'h9, "T1 addr 1023 = 9");

    do_write(10'd5, 4'h1);
    do_write(10'd500, 4'h3);
    do_write(10'd500, 4'h6);            // overwrite
    do_write(10'd777, 4'hC);
    expect_read(10'd5, 4'h1, "T1 addr 5 = 1");
    expect_read(10'd500, 4'h6, "T1 addr 500 = 6 (overwrite of earlier 3)");
    expect_read(10'd777, 4'hC, "T1 addr 777 = C");

    // no aliasing: neighbours keep their (swept-to-0) contents
    expect_read(10'd4, 4'h0, "T1 addr 4 unaffected by addr5 write");
    expect_read(10'd6, 4'h0, "T1 addr 6 unaffected by addr5 write");
    expect_read(10'd499, 4'h0, "T1 addr 499 unaffected by addr500 write");
    expect_read(10'd501, 4'h0, "T1 addr 501 unaffected by addr500 write");
    expect_read(10'd5, 4'h1, "T1 addr 5 still 1");
    expect_read(10'd500, 4'h6, "T1 addr 500 still 6");

    // read-during-write: WE_n low forces data_out to 0, write then commits
    do_write(10'd0, 4'h7);
    address = 10'd0; data_in = 4'hE;
    CHIP_SELECT_n = 0; WRITE_ENABLE_n = 0; OUTPUT_ENABLE_n = 0; RESET_n = 1;
    #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL T1_READ_DURING_WRITE: data_out=%h while WE_n=0, expected 0", data_out);
    end
    @(posedge clk); #1;
    WRITE_ENABLE_n = 1;
    expect_read(10'd0, 4'hE, "T1 addr 0 = E after the write committed");

    // ---- T2: output-mask terms, each forced individually -----------------
    do_write(10'd10, 4'hD);
    address = 10'd10; WRITE_ENABLE_n = 1; RESET_n = 1;

    CHIP_SELECT_n = 1; OUTPUT_ENABLE_n = 0; #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL T2_MASK_CS_n: data_out=%h with CHIP_SELECT_n=1, expected 0", data_out);
    end

    CHIP_SELECT_n = 0; OUTPUT_ENABLE_n = 1; #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL T2_MASK_OE_n: data_out=%h with OUTPUT_ENABLE_n=1, expected 0", data_out);
    end

    CHIP_SELECT_n = 0; OUTPUT_ENABLE_n = 0; WRITE_ENABLE_n = 0; #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL T2_MASK_WE_n: data_out=%h with WRITE_ENABLE_n=0, expected 0", data_out);
    end
    WRITE_ENABLE_n = 1;
    // note: WE_n was low across a posedge here, so addr 10 was rewritten
    // with data_in - harmless, T3 clears everything anyway

    CHIP_SELECT_n = 0; OUTPUT_ENABLE_n = 0; RESET_n = 0; #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL T2_MASK_RESET_n: data_out=%h with RESET_n=0, expected 0", data_out);
    end
    RESET_n = 1;

    // ---- T3: /R falling edge clears the ENTIRE array ---------------------
    // (datasheet "memory reset function"; the check that FAILS against the
    // old model, whose /R pulse left every location's contents intact)
    // scatter is already written: 0=E, 5=1, 500=6, 777=C, 1023=9, 10=x
    //
    // The T2 mask check above dropped /R for 1 ns BETWEEN clock edges: no
    // posedge sampled it low, so no clear started - and must not have
    // (the datasheet reset needs /R held for two cycle times, not a
    // sub-cycle glitch):
    expect_read(10'd777, 4'hC, "T3 addr 777 intact after sub-cycle /R glitch");
    // now a proper /R pulse, held across two clock edges
    RESET_n = 0;
    @(posedge clk); @(posedge clk); #1;
    RESET_n = 1;
    // the whole array is invalid the moment /R has been sampled low
    address = 10'd777;
    CHIP_SELECT_n = 0; WRITE_ENABLE_n = 1; OUTPUT_ENABLE_n = 0; RESET_n = 1;
    #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL T3_READ_RIGHT_AFTER_RESET: data_out=%h, expected 0", data_out);
    end
    sweep_wait;
    expect_read(10'd0, 4'h0, "T3 addr 0 cleared by /R");
    expect_read(10'd5, 4'h0, "T3 addr 5 cleared by /R");
    expect_read(10'd500, 4'h0, "T3 addr 500 cleared by /R");
    expect_read(10'd777, 4'h0, "T3 addr 777 cleared by /R");
    expect_read(10'd1023, 4'h0, "T3 addr 1023 cleared by /R");
    expect_all_zero("T3_ARRAY_ZERO_AFTER_RESET");
    // and the part accepts writes again
    do_write(10'd10, 4'hD);
    expect_read(10'd10, 4'hD, "T3 addr 10 = D written after the clear");

    $display("-----------------------------------------------------");
    $display(" Am9150 testbench (memory reset function model)");
    $display(" checks run : %0d (expected %0d)", checks, EXPECTED_CHECKS);
    $display(" failures   : %0d", errors);
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS");
    else begin
      if (checks != EXPECTED_CHECKS)
        $display("FAIL: check count %0d != expected %0d - vacuous or truncated run", checks, EXPECTED_CHECKS);
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

  initial begin
    #200000;
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire
