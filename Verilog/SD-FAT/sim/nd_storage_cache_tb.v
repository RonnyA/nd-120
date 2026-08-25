/****************************************************************************
** nd_storage_cache_tb - unit test for the Phase-4 cache directory         **
**                                                                         **
** Full path:                                                              **
**   Verilog/SD-FAT/sim/nd_storage_cache_tb.v                              **
**                                                                         **
** Runs the directory at a DELIBERATELY tiny geometry (4 sets x 4 ways)    **
** so eviction can be forced in a handful of operations; the RTL geometry  **
** is parameters, and the logic under test does not depend on the size.    **
**                                                                         **
** What is asserted, and why each one is here:                             **
**   A. cold miss -> allocate -> hit, and the region line the lookup       **
**      returns is POOL_BASE + set*WAYS + way both times (a hit that       **
**      returned a different line than the fill would serve stale data).   **
**   B. four blocks that share a set fill the four free ways WITHOUT       **
**      evicting anything - "invalid ways before any valid way", the rule  **
**      that stops a cold pool from thrashing itself.                      **
**   C. the fifth block into a full set evicts the LEAST recently used     **
**      one, not an arbitrary one, and the evicted block then misses.      **
**   D. a HIT re-orders LRU: touch the oldest line, and the next eviction  **
**      must take a different victim than it would have.                   **
**   E. the same block number from two different clients must occupy two   **
**      different ways. This is the aliasing case the shared pool exists   **
**      to get right - the client id is inside the tag precisely so unit 0 **
**      block 5 and unit 1 block 5 cannot be confused for each other.      **
**   F. per-client invalidate drops that client's lines and LEAVES the     **
**      other client's lines resident (card swap / remount must not blow   **
**      away an unrelated unit).                                           **
**                                                                         **
** Verdict line: TB_RESULT: PASS / FAIL (registry convention).             **
*****************************************************************************/
`timescale 1ns/1ps

module nd_storage_cache_tb;

  localparam WAYS   = 4;
  localparam SETS   = 4;
  localparam SETIDX = 2;
  localparam BLKW   = 16;
  localparam [31:0] POOL_BASE = 32'd0;

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  always #5 clk = ~clk;

  reg              lookup_req = 1'b0;
  reg  [2:0]       lookup_client = 3'd0;
  reg  [BLKW-1:0]  lookup_block = 16'd0;
  wire             lookup_done;
  wire             lookup_hit;
  wire [2:0]       lookup_way;
  wire [10:0]      lookup_line;

  reg              alloc_req = 1'b0;
  reg  [2:0]       alloc_client = 3'd0;
  reg  [BLKW-1:0]  alloc_block = 16'd0;
  reg  [2:0]       alloc_way = 3'd0;
  wire             alloc_done;

  reg              inval_req = 1'b0;
  reg  [2:0]       inval_client = 3'd0;
  wire             inval_done;

  integer errors = 0;

  task check(input cond, input [255:0] what);
    begin
      if (!cond) begin
        $display("[FAIL] %0s", what);
        errors = errors + 1;
      end else begin
        $display("[ ok ] %0s", what);
      end
    end
  endtask

  // ---- one lookup, result left in the l_* regs ---------------------------
  reg        l_hit;
  reg [2:0]  l_way;
  reg [10:0] l_line;
  task do_lookup(input [2:0] c, input [BLKW-1:0] b);
    begin
      @(posedge clk);
      lookup_client <= c;
      lookup_block  <= b;
      lookup_req    <= 1'b1;
      @(posedge clk);
      lookup_req    <= 1'b0;
      wait (lookup_done === 1'b1);
      l_hit  = lookup_hit;
      l_way  = lookup_way;
      l_line = lookup_line;
      @(posedge clk);
    end
  endtask

  task do_alloc(input [2:0] c, input [BLKW-1:0] b, input [2:0] w);
    begin
      @(posedge clk);
      alloc_client <= c;
      alloc_block  <= b;
      alloc_way    <= w;
      alloc_req    <= 1'b1;
      @(posedge clk);
      alloc_req    <= 1'b0;
      wait (alloc_done === 1'b1);
      @(posedge clk);
    end
  endtask

  // miss + fill in one go (the engine's normal sequence)
  task fill(input [2:0] c, input [BLKW-1:0] b);
    begin
      do_lookup(c, b);
      do_alloc(c, b, l_way);
    end
  endtask

  task do_inval(input [2:0] c);
    begin
      @(posedge clk);
      inval_client <= c;
      inval_req    <= 1'b1;
      @(posedge clk);
      inval_req    <= 1'b0;
      wait (inval_done === 1'b1);
      @(posedge clk);
    end
  endtask

  nd_storage_cache #(
      .WAYS(WAYS), .SETS(SETS), .SETIDX(SETIDX),
      .POOL_BASE_BLK(POOL_BASE), .BLKW(BLKW)
  ) dut (
      .clk(clk), .rst_n(rst_n),
      .lookup_req(lookup_req), .lookup_client(lookup_client),
      .lookup_block(lookup_block), .lookup_done(lookup_done),
      .lookup_hit(lookup_hit), .lookup_way(lookup_way),
      .lookup_line(lookup_line),
      .alloc_req(alloc_req), .alloc_client(alloc_client),
      .alloc_block(alloc_block), .alloc_way(alloc_way),
      .alloc_done(alloc_done),
      .inval_req(inval_req), .inval_client(inval_client),
      .inval_done(inval_done)
  );

  reg [2:0]  way_b0, way_b4, way_b8, way_b12;
  reg [10:0] line_first;
  reg [2:0]  way_c6, way_c7;

  initial begin
    $dumpfile("nd_storage_cache_tb.vcd");
    $dumpvars(0, nd_storage_cache_tb);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (4) @(posedge clk);

    // ---- A. cold miss -> allocate -> hit --------------------------------
    // set 0 (block 0), client 6.
    do_lookup(3'd6, 16'd0);
    check(l_hit === 1'b0, "A1 cold lookup misses");
    line_first = l_line;
    check(l_line === (POOL_BASE[10:0] + 0*WAYS + l_way),
          "A2 miss line = POOL_BASE + set*WAYS + way");
    do_alloc(3'd6, 16'd0, l_way);

    do_lookup(3'd6, 16'd0);
    check(l_hit === 1'b1, "A3 same block now hits");
    check(l_line === line_first, "A4 hit returns the line that was filled");

    // ---- B. fill the remaining ways of a set without evicting -----------
    // set 1: blocks 1, 5, 9, 13 (block[1:0] == 1 for all four).
    fill(3'd6, 16'd1);  way_b0  = l_way;
    fill(3'd6, 16'd5);  way_b4  = l_way;
    fill(3'd6, 16'd9);  way_b8  = l_way;
    fill(3'd6, 16'd13); way_b12 = l_way;
    check((way_b0 !== way_b4) && (way_b0 !== way_b8) && (way_b0 !== way_b12) &&
          (way_b4 !== way_b8) && (way_b4 !== way_b12) && (way_b8 !== way_b12),
          "B1 four blocks of one set took four DIFFERENT ways");

    do_lookup(3'd6, 16'd1);  check(l_hit === 1'b1, "B2 block 1 still resident");
    do_lookup(3'd6, 16'd5);  check(l_hit === 1'b1, "B3 block 5 still resident");
    do_lookup(3'd6, 16'd9);  check(l_hit === 1'b1, "B4 block 9 still resident");
    do_lookup(3'd6, 16'd13); check(l_hit === 1'b1, "B5 block 13 still resident");

    // The four lookups above re-ordered LRU to (MRU) 13, 9, 5, 1 (LRU).

    // ---- C. fifth block evicts the least recently used -------------------
    do_lookup(3'd6, 16'd17);
    check(l_hit === 1'b0, "C1 fifth block of a full set misses");
    check(l_way === way_b0, "C2 victim is the LRU way (block 1), not an arbitrary one");
    do_alloc(3'd6, 16'd17, l_way);

    do_lookup(3'd6, 16'd1);
    check(l_hit === 1'b0, "C3 the evicted block now misses");
    do_lookup(3'd6, 16'd5);
    check(l_hit === 1'b1, "C4 a non-victim block survived the eviction");

    // ---- D. a hit re-orders LRU -----------------------------------------
    // Resident in set 1 now: 17, 13, 9, 5. LRU order (MRU first) is
    // 5, 17, 13, 9 after the two lookups in C3/C4 -> next victim is 9.
    do_lookup(3'd6, 16'd9);           // touch the oldest -> it becomes MRU
    check(l_hit === 1'b1, "D1 touched block was resident");
    do_lookup(3'd6, 16'd21);          // sixth block into set 1
    check(l_hit === 1'b0, "D2 new block misses");
    check(l_way === way_b12, "D3 touching block 9 moved the victim to block 13");
    do_alloc(3'd6, 16'd21, l_way);
    do_lookup(3'd6, 16'd9);
    check(l_hit === 1'b1, "D4 the block we touched was NOT evicted");

    // ---- E. same block number, two clients -------------------------------
    // set 2 (block 2) from client 6 and client 7.
    fill(3'd6, 16'd2); way_c6 = l_way;
    fill(3'd7, 16'd2); way_c7 = l_way;
    check(way_c6 !== way_c7, "E1 same block from two clients took different ways");
    do_lookup(3'd6, 16'd2);
    check((l_hit === 1'b1) && (l_way === way_c6), "E2 client 6 block 2 hits its own way");
    do_lookup(3'd7, 16'd2);
    check((l_hit === 1'b1) && (l_way === way_c7), "E3 client 7 block 2 hits its own way");

    // ---- F. per-client invalidate ----------------------------------------
    do_inval(3'd6);
    do_lookup(3'd6, 16'd2);
    check(l_hit === 1'b0, "F1 invalidated client's line is gone");
    do_lookup(3'd6, 16'd17);
    check(l_hit === 1'b0, "F2 invalidate swept every set, not just one");
    do_lookup(3'd7, 16'd2);
    check(l_hit === 1'b1, "F3 the OTHER client's line survived the invalidate");

    $display("");
    if (errors == 0) $display("TB_RESULT: PASS (nd_storage_cache: LRU, eviction, client aliasing, invalidate)");
    else             $display("TB_RESULT: FAIL (%0d checks failed)", errors);
    $finish;
  end

  // watchdog: a handshake that never completes must not hang the suite
  initial begin
    #200000;
    $display("TB_RESULT: FAIL (timeout - a handshake never completed)");
    $finish;
  end

endmodule
