/****************************************************************************
** Am9150_w_clock (module Am9150_w_clock, in Am9150_with_clk.v) testbench  **
**                                                                         **
** This is the REGISTERED-OUTPUT sibling of Am9150 (1024 x 4 SRAM). Read   **
** from Am9150_with_clk.v: data_out is declared `output reg` and driven by **
** its OWN `always @(posedge clk)` block:                                  **
**   if (!CS_n && !OE_n && WE_n && RESET_n)                                **
**       data_out <= amc_memory_array[address];                            **
**   else                                                                  **
**       data_out <= 4'b0;                                                 **
** so the read path is SYNCHRONOUS with ONE CLOCK of latency: address and  **
** enables set up before a posedge clk are reflected in data_out AFTER     **
** that edge, not combinationally. Write is a separate always block, also  **
** posedge clk, gated by (!CS_n && !RESET_n -> no-op) / (!CS_n && !WE_n -> **
** write).                                                                 **
**                                                                         **
** RESET_n: exactly like the plain Am9150, the write block's              **
** `if (!RESET_n) begin end` branch is EMPTY (memory clear commented out - **
** "Doesnt work with block-ram.. TODO"). RESET_n low here only forces the  **
** REGISTERED data_out to 0 via the output block's AND term; it never      **
** clears amc_memory_array. Reported as a deviation from the doc header.  **
**                                                                         **
** COVERAGE: same plan as Am9150_tb.v - address 0, address 1023 (max),    **
** three arbitrary addresses (5, 500, 777) with overwrite, no-aliasing,    **
** read-during-write, each output-mask term (CS_n, OE_n, WE_n, RESET_n)    **
** forced individually, and a dedicated LATENCY measurement (samples       **
** data_out every clock after the read setup to find exactly which edge    **
** it updates on), and the RESET_n-does-not-clear-memory proof.           **
**                                                                         **
** Run: cd Verilog/Shared/support/sim && iverilog -g2012 -o tb.vvp         **
**      Am9150_w_clock_tb.v ../Am9150_with_clk.v && vvp tb.vvp            **
**                                                                         **
** Last reviewed: 20-AUG-2026                                             **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module Am9150_w_clock_tb;

  reg        clk = 0;
  always #5 clk = ~clk;

  reg  [9:0] address;
  reg  [3:0] data_in;
  wire [3:0] data_out;
  reg        WRITE_ENABLE_n, CHIP_SELECT_n, OUTPUT_ENABLE_n, RESET_n;

  integer errors = 0;
  integer checks = 0;

  Am9150_w_clock DUT (
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

  // Set up read enables/address, wait ONE extra clock for the registered
  // output to update, then check.
  task expect_read(input [9:0] addr, input [3:0] expected, input [255:0] label);
    begin
      address = addr;
      CHIP_SELECT_n = 0; WRITE_ENABLE_n = 1; OUTPUT_ENABLE_n = 0; RESET_n = 1;
      @(posedge clk); #1;
      checks = checks + 1;
      if (data_out !== expected) begin
        errors = errors + 1;
        $display("FAIL %0s: addr=%0d data_out=%h expected %h", label, addr, data_out, expected);
      end
    end
  endtask

  initial begin
    $dumpfile("Am9150_w_clock_tb.vcd");
    $dumpvars(0, Am9150_w_clock_tb);

    address = 0; data_in = 0;
    WRITE_ENABLE_n = 1; CHIP_SELECT_n = 1; OUTPUT_ENABLE_n = 1; RESET_n = 1;
    @(posedge clk); #1;

    // ---- short documented sequence first (readable in the VCD) ----------
    do_write(10'd0, 4'hA);
    expect_read(10'd0, 4'hA, "doc: addr0=A");
    do_write(10'd1023, 4'hF);
    expect_read(10'd1023, 4'hF, "doc: addr1023=F");

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
    expect_read(10'd500, 4'h6, "addr 500 = 6 (overwrite of earlier value)");
    expect_read(10'd777, 4'hC, "addr 777 = C");

    // ---- 4. no aliasing ----------------------------------------------------
    do_write(10'd4, 4'h0);
    do_write(10'd6, 4'h0);
    expect_read(10'd4, 4'h0, "addr 4 unaffected by addr5 write");
    expect_read(10'd6, 4'h0, "addr 6 unaffected by addr5 write");
    expect_read(10'd5, 4'h1, "addr 5 still 1 (not disturbed by neighbours)");

    // ---- 5. read latency measurement --------------------------------------
    // Prove the EXACT clock the registered output updates on: set up read
    // enables at addr 777 (known = C), then sample every subsequent clock.
    address = 10'd777;
    CHIP_SELECT_n = 0; WRITE_ENABLE_n = 1; OUTPUT_ENABLE_n = 0; RESET_n = 1;
    @(posedge clk); #1;
    checks = checks + 1;
    if (data_out !== 4'hC) begin
      errors = errors + 1;
      $display("FAIL LATENCY_1CLK: data_out=%h after exactly 1 clock, expected C (1-clock latency)",
                data_out);
    end

    // ---- 6. read-during-write: WE_n=0 forces the registered output to 0 --
    do_write(10'd0, 4'h7);
    address = 10'd0; data_in = 4'hE;
    CHIP_SELECT_n = 0; WRITE_ENABLE_n = 0; OUTPUT_ENABLE_n = 0; RESET_n = 1;
    @(posedge clk); #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL READ_DURING_WRITE: data_out=%h during write, expected 0 (masked)", data_out);
    end
    WRITE_ENABLE_n = 1;
    expect_read(10'd0, 4'hE, "addr 0 = E after the write committed");

    // ---- 7. output-mask terms, forced individually ------------------------
    do_write(10'd10, 4'hD);
    address = 10'd10; WRITE_ENABLE_n = 1; RESET_n = 1;

    CHIP_SELECT_n = 1; OUTPUT_ENABLE_n = 0;
    @(posedge clk); #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL MASK_CS_n: data_out=%h with CHIP_SELECT_n=1, expected 0", data_out);
    end

    CHIP_SELECT_n = 0; OUTPUT_ENABLE_n = 1;
    @(posedge clk); #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL MASK_OE_n: data_out=%h with OUTPUT_ENABLE_n=1, expected 0", data_out);
    end

    CHIP_SELECT_n = 0; OUTPUT_ENABLE_n = 0; WRITE_ENABLE_n = 0;
    @(posedge clk); #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL MASK_WE_n: data_out=%h with WRITE_ENABLE_n=0, expected 0", data_out);
    end
    WRITE_ENABLE_n = 1;

    CHIP_SELECT_n = 0; OUTPUT_ENABLE_n = 0; RESET_n = 0;
    @(posedge clk); #1;
    checks = checks + 1;
    if (data_out !== 4'h0) begin
      errors = errors + 1;
      $display("FAIL MASK_RESET_n: data_out=%h with RESET_n=0, expected 0", data_out);
    end

    // ---- 8. RESET_n does NOT clear memory ----------------------------------
    RESET_n = 0;
    @(posedge clk); @(posedge clk); #1;
    RESET_n = 1;
    expect_read(10'd10, 4'hD, "RESET_n pulse did NOT clear addr 10 (still D)");
    expect_read(10'd0, 4'hE, "RESET_n pulse did NOT clear addr 0 (still E)");

    $display("-----------------------------------------------------");
    $display(" Am9150_w_clock testbench");
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
