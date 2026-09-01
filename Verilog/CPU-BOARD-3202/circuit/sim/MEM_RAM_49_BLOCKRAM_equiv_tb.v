//============================================================================
//! Equivalence-check driver for MEM_RAM_49_BLOCKRAM (31-AUG-2026) - same
//! purpose and method as IDT6168A_20_equiv_tb.v: drive the REAL DRAM
//! protocol (RAS/CAS/AA phases) with a deterministic sequence, log every
//! cycle, run once plain and once with -DQUARTUS_RAM_INFER=1, diff
//! (Shared/support/sim/run_quartus_ram_equiv.sh).
//============================================================================

`timescale 1ns / 1ps

module MEM_RAM_49_BLOCKRAM_equiv_tb;

  localparam integer BANK_ADDR_BITS = 12;

  reg        sysclk = 0;
  reg        sys_rst_n = 0;
  reg [ 9:0] AA_9_0 = 0;
  reg        BANK0 = 0, BANK1 = 0, BANK2 = 0;
  reg        CAS = 0, RAS = 0;
  reg        MWRITE50_n = 1;
  reg [17:0] DD_17_0_IN = 0;
  wire [17:0] DD_17_0_OUT;
  wire       CORR_n;

  integer logf;
  integer seed = 32'hBADC0DE;

  always #5 sysclk = ~sysclk;

  MEM_RAM_49_BLOCKRAM #(
      .BANK_ADDR_BITS(BANK_ADDR_BITS),
      .NUM_BANKS(3)
  ) DUT (
      .sysclk    (sysclk),
      .sys_rst_n (sys_rst_n),
      .AA_9_0    (AA_9_0),
      .BANK0     (BANK0),
      .BANK1     (BANK1),
      .BANK2     (BANK2),
      .CAS       (CAS),
      .RAS       (RAS),
      .MWRITE50_n(MWRITE50_n),
      .DD_17_0_IN(DD_17_0_IN),
      .DD_17_0_OUT(DD_17_0_OUT),
      .CORR_n    (CORR_n)
  );

  task step;
    begin
      @(posedge sysclk);
      #1;
      logf = $fopen("mem_equiv_log.txt", "a");
      $fdisplay(logf, "%0d AA=%0d B=%b%b%b CAS=%b RAS=%b MWn=%b DIN=%0d DOUT=%0d CORR=%b", $time,
                AA_9_0, BANK0, BANK1, BANK2, CAS, RAS, MWRITE50_n, DD_17_0_IN, DD_17_0_OUT, CORR_n);
      $fclose(logf);
    end
  endtask

  // One full DRAM access: RAS captures row (=addr), then CAS window carries
  // the column; write or read chosen by MWRITE50_n. Mirrors the real
  // protocol comment in MEM_RAM_49_BLOCKRAM.v (row at RAS rising edge,
  // {row,col} linear address).
  task access(input [9:0] row, input [9:0] col, input bank_sel, input wr,
              input [17:0] wdata);
    begin
      BANK0 = (bank_sel == 0);
      BANK1 = (bank_sel == 1);
      BANK2 = (bank_sel == 2);

      RAS      = 0;
      CAS      = 0;
      AA_9_0   = row;
      DD_17_0_IN = wdata;
      step;

      RAS = 1;  // rising edge captures row
      step;

      MWRITE50_n = !wr;
      AA_9_0     = col;
      CAS        = 1;  // window open now (RAS & CAS & bank)
      step;
      step;  // hold the window a second cycle (continuous re-read case)

      RAS = 0;
      CAS = 0;
      step;
      step;
    end
  endtask

  integer i;
  reg [9:0] r, c;
  reg [17:0] wd;

  initial begin
    logf = $fopen("mem_equiv_log.txt", "w");
    $fclose(logf);

    sys_rst_n = 0;
    repeat (4) step;
    sys_rst_n = 1;

    // directed: write then read back, same address, bank 0
    access(10'h010, 10'h020, 0, 1, 18'h1_5555);
    access(10'h010, 10'h020, 0, 0, 18'h0);

    // directed: burst writes across a bank, sequential columns
    for (i = 0; i < 8; i = i + 1) access(10'h030, 10'h000 + i, 1, 1, {14'd0, i[3:0]} ^ 18'h2_AAAA);
    for (i = 0; i < 8; i = i + 1) access(10'h030, 10'h000 + i, 1, 0, 18'h0);

    // directed: same row, alternating write/read, different banks
    access(10'h040, 10'h001, 2, 1, 18'h3_1234);
    access(10'h040, 10'h001, 2, 0, 18'h0);
    access(10'h040, 10'h001, 0, 1, 18'h0_4321);
    access(10'h040, 10'h001, 0, 0, 18'h0);

    // pseudo-random stress: 300 accesses, mixed read/write, random row/col/bank
    for (i = 0; i < 300; i = i + 1) begin
      r  = $random(seed) % 1024;
      c  = $random(seed) % 1024;
      wd = $random(seed) % 262144;
      access(r, c, $random(seed) % 3, ($random(seed) % 2 == 0), wd);
    end

    $display("EQUIV_TB_DONE");
    $finish;
  end

endmodule
