/**************************************************************************
** MEM_RAM_49_DDR2 protocol testbench (iverilog)                         **
**                                                                       **
** Replays the measured sheet-49 DRAM protocol (docs/nd120-dram-memory.md **
** section 4: row at N, column at N+1, CAS at N+2, read data consumed    **
** from N+4, RAS off at N+5, min 11-cycle spacing) against the DDR2      **
** backend, with a behavioral DDR2 port model of RANDOM latency          **
** (10..70 ui cycles - covering MIG refresh collisions) behind it.       **
**                                                                       **
** The driver emulates the frozen control PALs: while MEM_HOLD is high   **
** at a sysclk edge the protocol phase does NOT advance - exactly what   **
** the HOLD input does to PAL_44803A/PAL_44902A.                         **
**                                                                       **
** Checks:                                                               **
**  1. Read hit: MEM_HOLD never asserts and data is on DD_17_0_OUT at    **
**     the start of N+3 (the proven MEM_RAM_49_BLOCKRAM timing).         **
**  2. Read miss: MEM_HOLD stretches the cycle; data correct and parity  **
**     odd after release; CORR_n high.                                   **
**  3. Write-through order: a read miss always sees earlier writes.      **
**  4. The 22-AUG alias map: 0o1000/1004/1010/1020/1040/1100/1200/1400,  **
**     0o2000..0o40000 and the 64K-word boundary 0o177777 vs 0o200000    **
**     are all DISTINCT cells, in both populated banks.                  **
**  5. BANK1 (absent) reads 0 with CORR_n=1; BANK1 writes are dropped.   **
**  6. Random stress vs a reference model (every access checked).        **
**                                                                       **
** Verdict: prints "TB_RESULT: PASS" or "TB_RESULT: FAIL ..." (registered **
** in Verilog/tests/run_all_tests.sh).                                   **
**                                                                       **
** Last reviewed: 25-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module MEM_RAM_49_DDR2_tb;

  // Small cache so conflict misses are frequent: 6 -> 64 lines x 8 words
  localparam CACHE_IDX_BITS = 6;

  reg sysclk = 0;
  reg ui_clk = 0;
  reg sys_rst_n = 0;

  always #30 sysclk = ~sysclk;    // 16.667 MHz
  always #6.66 ui_clk = ~ui_clk;  // ~75 MHz

  reg [9:0] AA = 0;
  reg BANK0 = 0, BANK1 = 0, BANK2 = 0;
  reg RAS = 0, CAS = 0;
  reg MWRITE50_n = 1;
  reg [17:0] DD_IN = 0;
  wire [17:0] DD_OUT;
  wire CORR_n;
  wire MEM_HOLD;

  wire         mm_req_valid, mm_req_we;
  wire [26:0]  mm_req_addr;
  wire [127:0] mm_req_wdata;
  wire [15:0]  mm_req_wmask;
  reg          mm_req_ready = 0;
  reg          mm_rsp_valid = 0;
  reg  [127:0] mm_rsp_rdata = 0;

  MEM_RAM_49_DDR2 #(
      .CACHE_IDX_BITS(CACHE_IDX_BITS)
  ) DUT (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .AA_9_0(AA),
      .BANK0(BANK0),
      .BANK1(BANK1),
      .BANK2(BANK2),
      .CAS(CAS),
      .RAS(RAS),
      .MWRITE50_n(MWRITE50_n),
      .DD_17_0_IN(DD_IN),
      .DD_17_0_OUT(DD_OUT),
      .CORR_n(CORR_n),
      .MEM_HOLD(MEM_HOLD),
      .ui_clk(ui_clk),
      .ui_rst(~sys_rst_n),
      .mm_req_valid(mm_req_valid),
      .mm_req_we(mm_req_we),
      .mm_req_addr(mm_req_addr),
      .mm_req_wdata(mm_req_wdata),
      .mm_req_wmask(mm_req_wmask),
      .mm_req_ready(mm_req_ready),
      .mm_rsp_valid(mm_rsp_valid),
      .mm_rsp_rdata(mm_rsp_rdata),
      .DBG_BRIDGE()
  );

  /*************************************************************************
   * Behavioral DDR2 (the nd_ddr2_port contract): random-latency single
   * outstanding op, 16-bit units, active-low byte mask on writes.
   * Backing store: 2M x 16 (the 4 MB main-memory region).
   *************************************************************************/
  reg [15:0] ddr_mem[0:2097151];

  integer d_lat;
  reg [26:0] d_addr;
  reg        d_we;
  reg [127:0] d_wdata;
  reg [15:0]  d_wmask;
  integer d_state;  // 0 idle, 1 busy
  integer d_cnt;
  integer bi;
  reg [20:0] d_unit;

  always @(posedge ui_clk) begin
    mm_rsp_valid <= 0;
    if (!sys_rst_n) begin
      d_state <= 0;
      mm_req_ready <= 0;
    end else begin
      mm_req_ready <= (d_state == 0);
      if (d_state == 0 && mm_req_valid && mm_req_ready) begin
        d_addr  <= mm_req_addr;
        d_we    <= mm_req_we;
        d_wdata <= mm_req_wdata;
        d_wmask <= mm_req_wmask;
        d_lat   <= 10 + ({$random} % 61);  // 10..70 ui cycles
        d_cnt   <= 0;
        d_state <= 1;
        mm_req_ready <= 0;
      end else if (d_state == 1) begin
        d_cnt <= d_cnt + 1;
        if (d_cnt == d_lat) begin
          d_unit = d_addr[20:0] & 21'h1FFFF8;
          if (d_we) begin
            for (bi = 0; bi < 8; bi = bi + 1) begin
              // two bytes per 16-bit unit, mask active low
              if (!d_wmask[2*bi])
                ddr_mem[d_unit+bi][7:0] <= d_wdata[16*bi+:8];
              if (!d_wmask[2*bi+1])
                ddr_mem[d_unit+bi][15:8] <= d_wdata[16*bi+8+:8];
            end
          end else begin
            for (bi = 0; bi < 8; bi = bi + 1)
              mm_rsp_rdata[16*bi+:16] <= ddr_mem[d_unit+bi];
          end
          mm_rsp_valid <= 1;
          d_state <= 0;
        end
      end
    end
  end

  /*************************************************************************
   * Reference model + protocol driver
   *************************************************************************/
  reg [15:0] ref_mem[0:2097151];
  integer i;
  initial begin
    for (i = 0; i < 2097152; i = i + 1) begin
      ddr_mem[i] = 16'h0000;
      ref_mem[i] = 16'h0000;
    end
  end

  integer errors = 0;
  integer n_access = 0;
  integer n_miss = 0;
  integer n_hit = 0;

  // Driving convention: every input changes on the NEGEDGE, the way the
  // real PAL flip-flop outputs change just after their posedge - so the DUT
  // samples stable values at every posedge and there is no same-time-slot
  // scheduler race between the driver and the DUT.
  //
  // one protocol phase advance; the phase only advances while MEM_HOLD is
  // low (the PAL-freeze emulation: a frozen PAL holds RAS/CAS/AA still)
  reg g_hold_seen = 0;  // set by step whenever a freeze was crossed
  task step;
    begin
      @(negedge sysclk);
      while (MEM_HOLD) begin
        g_hold_seen = 1;
        @(negedge sysclk);
      end
    end
  endtask

  // do one full access. bank: 0=BANK0, 1=BANK1(absent), 2=BANK2
  task access;
    input integer bank;
    input [19:0] addr;   // {row[9:0], col[9:0]}
    input do_write;
    input [15:0] wdata;
    reg [20:0] wa;
    reg expect_hold_none;
    reg [15:0] exp;
    integer hold_seen;
    begin
      wa = {(bank == 2) ? 1'b1 : 1'b0, addr};

      // N: RAS rise, row on AA, W_n and BANKx valid (all set on the negedge
      // BEFORE cycle N, like PAL outputs)
      @(negedge sysclk);
      AA = addr[19:10];
      BANK0 = (bank == 0);
      BANK1 = (bank == 1);
      BANK2 = (bank == 2);
      MWRITE50_n = ~do_write;
      DD_IN = do_write ? {1'b0, wdata[15:8], 1'b0, wdata[7:0]} : 18'h0;
      RAS = 1;
      CAS = 0;
      @(negedge sysclk);  // posedge N has passed: DUT saw the RAS rise + row

      // N+1: column on AA
      AA = addr[9:0];
      hold_seen = 0;
      g_hold_seen = 0;
      @(negedge sysclk);  // posedge N+1 has passed: lookup registered

      // N+2: CAS rises (write data valid on DD all along)
      CAS = 1;
      step;               // past posedge N+2 (+ any freeze)
      step;               // past posedge N+3
      step;               // past posedge N+4 - where read data is consumed
      hold_seen = g_hold_seen;

      // read check at N+4 (post-release: MEM_HOLD is low here by contract)
      if (!do_write) begin
        if (bank == 1) begin
          if (DD_OUT !== 18'h0 || CORR_n !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL: absent-bank read not 0/CORR at %o: DD=%o CORR=%b",
                     wa, DD_OUT, CORR_n);
          end
        end else begin
          exp = ref_mem[wa];
          if (DD_OUT[16:9] !== exp[15:8] || DD_OUT[7:0] !== exp[7:0]) begin
            errors = errors + 1;
            $display("FAIL: read %o got %x expected %x (hold_seen=%0d)",
                     wa, {DD_OUT[16:9], DD_OUT[7:0]}, exp, hold_seen);
          end
          if (DD_OUT[8] !== ~(^DD_OUT[7:0]) || DD_OUT[17] !== ~(^DD_OUT[16:9])) begin
            errors = errors + 1;
            $display("FAIL: parity wrong on read %o: DD=%b", wa, DD_OUT);
          end
          if (CORR_n !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL: CORR_n low on clean read %o", wa);
          end
          if (hold_seen) n_miss = n_miss + 1;
          else n_hit = n_hit + 1;
        end
      end

      // N+5: RAS off, CAS tail
      RAS = 0;
      @(negedge sysclk);
      // N+6: CAS off
      CAS = 0;
      BANK0 = 0; BANK1 = 0; BANK2 = 0;
      @(negedge sysclk);

      if (do_write && bank != 1) ref_mem[wa] = wdata;
      n_access = n_access + 1;

      // spacing: minimum RAS-to-RAS is 11 - here 5 idle cycles after the
      // 6-cycle access
      repeat (5) @(negedge sysclk);
    end
  endtask

  // wait until the DUT has drained its posted writes into the model
  task drain;
    integer k;
    begin
      for (k = 0; k < 3000; k = k + 1) @(negedge sysclk);
    end
  endtask

  integer t, bank_t;
  reg [19:0] ra;
  reg [15:0] rd;
  integer wr;

  initial begin
`ifdef DUMP
    $dumpfile("MEM_RAM_49_DDR2_tb.vcd");
    $dumpvars(0, MEM_RAM_49_DDR2_tb);
`endif
    repeat (8) @(posedge sysclk);
    sys_rst_n = 1;
    repeat (8) @(posedge sysclk);

    // ---- 1. hit timing: write a word, read it twice; the second read is a
    //         guaranteed hit and must not raise MEM_HOLD ----
    access(0, 20'o0001000, 1, 16'h1234);
    access(0, 20'o0001000, 0, 0);  // miss (first touch of the line, fills)
    begin : hitcheck
      integer h0;
      h0 = n_miss;
      access(0, 20'o0001000, 0, 0);  // must be a HIT now
      if (n_miss != h0) begin
        errors = errors + 1;
        $display("FAIL: second read of a filled line missed (hold asserted)");
      end
    end

    // ---- 2. the 22-AUG alias map: all these must be distinct cells ----
    access(0, 20'o0001000, 1, 16'hA000);
    access(0, 20'o0001004, 1, 16'hA004);
    access(0, 20'o0001010, 1, 16'hA010);
    access(0, 20'o0001020, 1, 16'hA020);
    access(0, 20'o0001040, 1, 16'hA040);
    access(0, 20'o0001100, 1, 16'hA100);
    access(0, 20'o0001200, 1, 16'hA200);
    access(0, 20'o0001400, 1, 16'hA400);
    access(0, 20'o0002000, 1, 16'hB000);
    access(0, 20'o0004000, 1, 16'hB004);
    access(0, 20'o0010000, 1, 16'hB010);
    access(0, 20'o0020000, 1, 16'hB020);
    access(0, 20'o0040000, 1, 16'hB040);
    // the 64K-word boundary that the old BRAM backend aliased
    access(0, 20'o0177777, 1, 16'hC177);
    access(0, 20'o0200000, 1, 16'hC200);
    access(0, 20'o0777777, 1, 16'hC777);
    // same offsets in the second populated bank
    access(2, 20'o0001000, 1, 16'hD000);
    access(2, 20'o0200000, 1, 16'hD200);

    access(0, 20'o0001000, 0, 0);
    access(0, 20'o0001004, 0, 0);
    access(0, 20'o0001010, 0, 0);
    access(0, 20'o0001020, 0, 0);
    access(0, 20'o0001040, 0, 0);
    access(0, 20'o0001100, 0, 0);
    access(0, 20'o0001200, 0, 0);
    access(0, 20'o0001400, 0, 0);
    access(0, 20'o0002000, 0, 0);
    access(0, 20'o0004000, 0, 0);
    access(0, 20'o0010000, 0, 0);
    access(0, 20'o0020000, 0, 0);
    access(0, 20'o0040000, 0, 0);
    access(0, 20'o0177777, 0, 0);
    access(0, 20'o0200000, 0, 0);
    access(0, 20'o0777777, 0, 0);
    access(2, 20'o0001000, 0, 0);
    access(2, 20'o0200000, 0, 0);

    // ---- 3. absent bank ----
    access(1, 20'o0001000, 1, 16'hDEAD);  // dropped
    access(1, 20'o0001000, 0, 0);         // reads 0

    // ---- 4. read-after-write, same line, immediately (write-through
    //         ordering: the refill must observe the posted write) ----
    access(0, 20'o0300010, 1, 16'h5678);
    access(0, 20'o0300011, 0, 0);  // same line, miss -> refill after drain
    access(0, 20'o0300010, 0, 0);  // now a hit, must be 5678

    // ---- 5. random stress vs the reference model ----
    for (t = 0; t < 4000; t = t + 1) begin
      bank_t = ({$random} % 10 == 0) ? 1 : (({$random} % 2) ? 2 : 0);
      // cluster addresses in a few pages so hits AND conflict misses occur
      if ({$random} % 3 == 0)
        ra = {$random} % 2097152 % 1048576;      // anywhere in the bank
      else
        ra = ({$random} % 64) * 8 + ({$random} % 8);  // hot low pages
      wr = ({$random} % 10) < 3;  // ~30 percent writes (measured is ~10)
      rd = $random;
      access(bank_t, ra, wr, rd);
    end

    // ---- 6. late-CAS write with AA drift (25-AUG stale-word root cause) ----
    // On the board CAS can rise LATER than N+2 (stretched cycles, refresh
    // interleave) and by then AA has moved off the column. tag_rd reloads
    // every posedge from the LIVE AA, so a hit computed at wr_edge time read
    // a foreign line's tag: the cache update was dropped while DDR2 took the
    // write - one stale cached word (SINTRAN spun forever on 056063).
    // Sequence: cache a line, write one word of it with CAS delayed two extra
    // cycles while AA drifts to a foreign column, then read it back.
    begin : latecas
      access(0, 20'o0500020, 1, 16'h1111);   // fill target word
      access(0, 20'o0500020, 0, 0);          // miss -> line cached
      access(0, 20'o0500020, 0, 0);          // hit (line resident)
      @(negedge sysclk);
      AA = 10'o0240;                        // row of 0500020 (addr[19:10])
      BANK0 = 1; BANK1 = 0; BANK2 = 0;
      MWRITE50_n = 0;
      DD_IN = {1'b0, 8'h22, 1'b0, 8'h22};   // write 0x2222
      RAS = 1; CAS = 0;
      @(negedge sysclk);                    // posedge N passed: row latched
      AA = 10'o0020;                        // N+1: column
      @(negedge sysclk);                    // A_COL latches col at next edge
      @(negedge sysclk);                    // col latched; A_CHK next edge
      AA = 10'o0777;                        // AA drifts off the column
      @(negedge sysclk);                    // posedge N+2 passed: A_CHK done
      @(negedge sysclk);                    // extra stretch, CAS still low
      CAS = 1;                              // CAS finally rises (late)
      @(negedge sysclk);
      @(negedge sysclk);
      @(negedge sysclk);
      RAS = 0;
      @(negedge sysclk);
      CAS = 0; BANK0 = 0; MWRITE50_n = 1;
      @(negedge sysclk);
      ref_mem[21'o0500020] = 16'h2222;
      repeat (5) @(negedge sysclk);
    end
    access(0, 20'o0500020, 0, 0);           // MUST read 0x2222, not stale 0x1111

    drain();

    $display("accesses=%0d hits=%0d misses=%0d errors=%0d",
             n_access, n_hit, n_miss, errors);
    if (errors == 0 && n_hit > 0 && n_miss > 0)
      $display("TB_RESULT: PASS");
    else if (n_hit == 0 || n_miss == 0)
      $display("TB_RESULT: FAIL (no coverage: hits=%0d misses=%0d)", n_hit, n_miss);
    else
      $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  // global watchdog: a stuck MEM_HOLD or lost toggle must fail loudly
  initial begin
    #200_000_000;  // 200 ms of sim time
    $display("TB_RESULT: FAIL (watchdog timeout)");
    $finish;
  end

endmodule
