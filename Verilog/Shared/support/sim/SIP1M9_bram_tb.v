/****************************************************************************
** SIP1M9_bram_tb -- unit test for the ramSize=3 synchronous BRAM path      **
**                                                                          **
** Drives the DRAM RAS-before-CAS protocol the way MEM_43/MEM_RAMC_50 does: **
**   row address on AA during RAS,  column address on AA during CAS,        **
**   full word address = {col, row} = LBD[19:0].                            **
** Verifies: write/read correctness, NO aliasing (old model collapsed       **
** consecutive addresses 1024 apart), and read stability.                   **
****************************************************************************/
`timescale 1ns / 1ps

module SIP1M9_bram_tb;

  reg        sysclk = 1'b0;
  reg        RAS_n = 1'b1;
  reg        CAS_n = 1'b1;
  reg        W_n = 1'b1;
  reg  [9:0] ADDRESS = 10'b0;
  reg  [7:0] D8 = 8'b0;
  reg        D9 = 1'b0;
  wire [7:0] Q8;
  wire       Q9, PRD_n;

  SIP1M9 #(.ramSize(3)) dut (
      .sysclk(sysclk), .sys_rst_n(1'b1),
      .ADDRESS(ADDRESS), .CAS9_n(CAS_n), .CAS_n(CAS_n), .RAS_n(RAS_n), .W_n(W_n),
      .D8(D8), .D9(D9), .Q8(Q8), .Q9(Q9), .PRD_n(PRD_n)
  );

  always #5 sysclk = ~sysclk;

  integer errors = 0;

  // DRAM write: row on AA during RAS, col on AA during CAS, W_n=0
  task mem_write(input [19:0] lbd, input [7:0] data);
    begin
      @(negedge sysclk); ADDRESS = lbd[9:0];   RAS_n = 0; W_n = 0;   // row phase
      @(negedge sysclk);                                              // settle row
      @(negedge sysclk); ADDRESS = lbd[19:10]; D8 = data; CAS_n = 0;  // col phase + data
      @(negedge sysclk);
      @(negedge sysclk); RAS_n = 1; CAS_n = 1; W_n = 1;               // precharge
      @(negedge sysclk);
    end
  endtask

  // DRAM read: capture Q8 late in the CAS-low window (like the RDATA strobe)
  task mem_read(input [19:0] lbd, output [7:0] data);
    begin
      @(negedge sysclk); ADDRESS = lbd[9:0];   RAS_n = 0; W_n = 1;    // row phase (read)
      @(negedge sysclk);
      @(negedge sysclk); ADDRESS = lbd[19:10]; CAS_n = 0;            // col phase
      @(negedge sysclk);
      @(negedge sysclk); data = Q8;                                  // capture (CAS still low)
      @(negedge sysclk); RAS_n = 1; CAS_n = 1;
      @(negedge sysclk);
    end
  endtask

  reg [7:0] r;
  task check(input [19:0] lbd, input [7:0] exp);
    begin
      mem_read(lbd, r);
      if (r !== exp) begin
        $display("  FAIL addr %0d: got %0o expected %0o", lbd, r, exp); errors = errors + 1;
      end else $display("  ok   addr %0d = %0o", lbd, r);
    end
  endtask

  initial begin
    $dumpfile("SIP1M9_bram_tb.vcd"); $dumpvars(0, SIP1M9_bram_tb);
    repeat (4) @(negedge sysclk);

    $display("--- TEST 1: basic write/read ---");
    mem_write(0, 8'hAA); mem_write(1, 8'h55); mem_write(2, 8'h5A);
    check(0, 8'hAA); check(1, 8'h55); check(2, 8'h5A);

    $display("--- TEST 2: NO aliasing (old model collapsed addr 0 and addr 4) ---");
    mem_write(0, 8'h11); mem_write(4, 8'h22);
    check(0, 8'h11); check(4, 8'h22);
    mem_write(1, 8'h33); mem_write(5, 8'h44);   // another alias pair in the old model
    check(1, 8'h33); check(5, 8'h44);

    $display("--- TEST 3: the exact octal values from the FPGA bug report ---");
    mem_write(0, 8'o377); check(0, 8'o377);     // was reading 357
    mem_write(0, 8'o103); check(0, 8'o103);     // was reading 123
    mem_write(0, 8'o011); check(0, 8'o011);

    $display("--- TEST 4: a spread of addresses stays distinct ---");
    mem_write(20'o0,   8'h01);
    mem_write(20'o100, 8'h02);
    mem_write(20'o377, 8'h03);
    mem_write(20'o1000,8'h04);
    check(20'o0, 8'h01); check(20'o100, 8'h02); check(20'o377, 8'h03); check(20'o1000, 8'h04);

    $display("--- TEST 5: read stability (addr 0 was last set to 0x01 in TEST 4) ---");
    check(0, 8'h01); check(0, 8'h01);

    if (errors == 0) $display("\n=== ALL PASS ==="); else $display("\n=== %0d FAILURES ===", errors);
    $finish;
  end

  initial begin #500000; $display("TIMEOUT"); $finish; end

endmodule
