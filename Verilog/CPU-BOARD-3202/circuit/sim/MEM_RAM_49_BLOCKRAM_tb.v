/**************************************************************************
** ND120 CPU - unit test                                                 **
** MEM_RAM_49_BLOCKRAM: the block-RAM sheet-49 backend.                  **
**                                                                       **
** Drives the MEASURED DRAM protocol (docs/nd120-dram-memory.md sect. 4, **
** RAS/CAS ACTIVE-HIGH on this interface):                               **
**   - AA carries the ROW exactly at the RAS rising edge                 **
**   - AA switches to the COLUMN one sysclk later (CAS still low)        **
**   - write data is on DD BEFORE CAS rises (silicon lesson 8-JUL-2026)  **
**   - CAS rises with the column on AA; window = RAS & CAS & bank        **
**                                                                       **
** Checks: write/readback across all 3 banks, no-alias, row captured at  **
** RAS EDGE (AA change after the edge must not move the row), write-once **
** (DD change during a held window must not re-write), read-vs-write     **
** gating by MWRITE50_n, and CORR_n parity (odd halves -> 1, even -> 0). **
**                                                                       **
** Run: make test-blockram   (CPU-BOARD-3202/circuit/sim)                **
***************************************************************************/
`timescale 1ns / 1ps

module MEM_RAM_49_BLOCKRAM_tb;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg         sys_rst_n = 0;
  reg  [9:0]  aa = 0;
  reg         bank0 = 0, bank1 = 0, bank2 = 0;
  reg         ras = 0, cas = 0;
  reg         mwrite50_n = 1;
  reg  [17:0] dd_in = 0;
  wire [17:0] dd_out;
  wire        corr_n;

  MEM_RAM_49_BLOCKRAM dut (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .AA_9_0(aa),
      .BANK0(bank0),
      .BANK1(bank1),
      .BANK2(bank2),
      .CAS(cas),
      .RAS(ras),
      .MWRITE50_n(mwrite50_n),
      .DD_17_0_IN(dd_in),
      .DD_17_0_OUT(dd_out),
      .CORR_n(corr_n)
  );

  integer errors = 0;
  integer checks = 0;

  task set_bank(input [1:0] b);
    begin
      bank0 = (b == 0);
      bank1 = (b == 1);
      bank2 = (b == 2);
    end
  endtask

  // lin = {col, row}; the module uses lin[BANK_ADDR_BITS-1:0]
  task mem_write(input [1:0] b, input [9:0] row, input [9:0] col, input [17:0] data);
    begin
      @(negedge sysclk); set_bank(b); aa = row; ras = 1; mwrite50_n = 0; // RAS rise, AA=row
      @(negedge sysclk); aa = col; dd_in = data;                         // AA->col, DD valid pre-CAS
      @(negedge sysclk); cas = 1;                                        // CAS rise, window opens
      @(negedge sysclk);                                                 // window held
      @(negedge sysclk); ras = 0; cas = 0; mwrite50_n = 1; set_bank(3);  // precharge
      @(negedge sysclk);
    end
  endtask

  task mem_read(input [1:0] b, input [9:0] row, input [9:0] col, output [17:0] data,
                output corr);
    begin
      @(negedge sysclk); set_bank(b); aa = row; ras = 1; mwrite50_n = 1;
      @(negedge sysclk); aa = col;
      @(negedge sysclk); cas = 1;
      @(negedge sysclk);                                                 // rd_q registered
      @(negedge sysclk); data = dd_out; corr = corr_n;                   // read while CAS high
      @(negedge sysclk); ras = 0; cas = 0; set_bank(3);
      @(negedge sysclk);
    end
  endtask

  task check_eq(input [17:0] got, input [17:0] want, input [127:0] label);
    begin
      checks = checks + 1;
      if (got !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: got %o expected %o", label, got, want);
      end
    end
  endtask

  reg [17:0] r;
  reg        c;
  integer i;

  initial begin
    $dumpfile("MEM_RAM_49_BLOCKRAM_tb.vcd");
    $dumpvars(0, MEM_RAM_49_BLOCKRAM_tb);

    repeat (4) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (2) @(negedge sysclk);

    // ---- 1. write/readback across all 3 banks (odd-parity halves) ----
    // 18'o001001 = {000000001,000000001}: both 9-bit halves odd parity
    mem_write(0, 10'd5, 10'd1, 18'o001001);
    mem_write(1, 10'd5, 10'd1, 18'o001403);
    mem_write(2, 10'd5, 10'd1, 18'o002405);
    mem_read (0, 10'd5, 10'd1, r, c); check_eq(r, 18'o001001, "bank0 rdbk");
    check_eq({17'b0, c}, 18'b1, "bank0 corr_n odd parity");
    mem_read (1, 10'd5, 10'd1, r, c); check_eq(r, 18'o001403, "bank1 rdbk");
    mem_read (2, 10'd5, 10'd1, r, c); check_eq(r, 18'o002405, "bank2 rdbk");

    // ---- 2. no-alias: distinct rows and columns in one bank ----
    for (i = 0; i < 8; i = i + 1)
      mem_write(0, 10'd100 + i, 10'd2, 18'o000100 + i);
    for (i = 0; i < 8; i = i + 1) begin
      mem_read(0, 10'd100 + i, 10'd2, r, c);
      check_eq(r, 18'o000100 + i, "no-alias row");
    end
    mem_write(0, 10'd100, 10'd3, 18'o000777);
    mem_read (0, 10'd100, 10'd2, r, c); check_eq(r, 18'o000100, "col3 not aliased to col2");
    mem_read (0, 10'd100, 10'd3, r, c); check_eq(r, 18'o000777, "col3 rdbk");

    // ---- 3. row captured at the RAS EDGE, not level ----
    @(negedge sysclk); set_bank(0); aa = 10'd200; ras = 1; mwrite50_n = 0; // row=200 at edge
    @(negedge sysclk); aa = 10'd4; dd_in = 18'o000021;                     // col=4
    @(negedge sysclk); aa = 10'd4;                                          // AA stays col
    @(negedge sysclk); cas = 1;
    @(negedge sysclk);
    @(negedge sysclk); ras = 0; cas = 0; mwrite50_n = 1; set_bank(3);
    @(negedge sysclk);
    mem_read(0, 10'd200, 10'd4, r, c); check_eq(r, 18'o000021, "row from RAS edge");
    mem_read(0, 10'd4,   10'd4, r, c);
    if (r === 18'o000021) begin
      errors = errors + 1;
      $display("FAIL row-level: row picked up post-edge AA (level capture)");
    end
    checks = checks + 1;

    // ---- 4. write-once: DD change during held window must not rewrite ----
    @(negedge sysclk); set_bank(0); aa = 10'd300; ras = 1; mwrite50_n = 0;
    @(negedge sysclk); aa = 10'd5; dd_in = 18'o000104;
    @(negedge sysclk); cas = 1;                    // window opens, writes dd_q=000104
    @(negedge sysclk); dd_in = 18'o000777;         // bus junk during held window
    @(negedge sysclk); dd_in = 18'o000707;
    @(negedge sysclk); ras = 0; cas = 0; mwrite50_n = 1; set_bank(3);
    @(negedge sysclk);
    mem_read(0, 10'd300, 10'd5, r, c); check_eq(r, 18'o000104, "write-once pre-CAS data");

    // ---- 5. read does not write ----
    mem_read(0, 10'd100, 10'd2, r, c);
    mem_read(0, 10'd100, 10'd2, r, c); check_eq(r, 18'o000100, "read is non-destructive");

    // ---- 6. CORR_n flags even parity ----
    // 18'o000003 = low half 000000011b: even parity -> CORR_n must drop to 0
    mem_write(0, 10'd310, 10'd6, 18'o000003);
    mem_read (0, 10'd310, 10'd6, r, c);
    checks = checks + 1;
    if (c !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL corr_n even parity: got %b expected 0", c);
    end

    // ---- 7. output gating: DD_17_0_OUT is 0 outside a read window ----
    @(negedge sysclk);
    checks = checks + 1;
    if (dd_out !== 18'b0) begin
      errors = errors + 1;
      $display("FAIL output gating: dd_out=%o outside window", dd_out);
    end

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $finish;
  end

  initial begin
    #500000;
    $display("FAIL [timeout]: watchdog fired");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
