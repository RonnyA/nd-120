/**************************************************************************
** ND120 CPU - unit test                                                 **
** CPU_MMU_PT_29: MMU SHADOW MEMORY (page-table RAM) read-modify-write   **
**                                                                       **
** DUT sheet 29 holds three RAMs:                                        **
**   PT STATUS bank : CHIP_24G (PT[15:8]) + CHIP_25G (PT[7:0])           **
**                    chip select EPT_n,   data PT_15_0_IN/OUT           **
**   PPN bank       : CHIP_22G (PPN[15:8]) + CHIP_23G (PPN[7:0])         **
**                    chip select EPMAP_n, data PPN_25_10_IN/OUT         **
**   CHIP_20G       : IMS1403_25 cache-inhibit bit, strobe WCLIM_n,      **
**                    addressed by the PPN VALUE (held inactive here)    **
** WMAP_n is ONE write strobe SHARED by the PT and the PPN bank; only    **
** EPT_n vs EPMAP_n decides which bank a write lands in. Both banks are  **
** addressed by LA_20_10[10:0] = 2048 entries.                           **
**                                                                       **
** Shadow index convention used here: PT_number*64 + virtual_page,       **
** i.e. LA_20_10 = {pt_number[4:0], vpn[5:0]} - 32 tables of 64 pages.   **
**                                                                       **
** PT status word bits (decoded from the trap logic):                    **
**   15 write-permit, 14 read-permit, 13 fetch-permit, 12 WIP,           **
**   11 PGU, 10:9 ring, 8:0 undocumented. Captured real entry = 162000.  **
**                                                                       **
** WHY THIS BENCH EXISTS: a live SINTRAN boot repeats a trap cycle, and  **
** the suspicion is that a page-table entry written by the trap handler  **
** either does not stick or is read back stale. The trap handler's       **
** update is a READ-MODIFY-WRITE of the PT status word, so that exact    **
** shape is driven here at several read->write-back distances, including **
** the tightest the RTL allows.                                          **
**                                                                       **
** TWO BUILD MODES (the Makefile runs both):                             **
**   plain              - TMM2018D_25 SYNCHRONOUS block-RAM read:        **
**                        data_out_reg loads on posedge clk while        **
**                        (!CS_n && W_n) => ONE clock of read latency.   **
**   -DTMM_ASYNC_READ   - the faithful async SRAM read of the real       **
**                        TMM2018D: D_OUT follows ADDRESS combinationally**
**                        => ZERO clocks of read latency.                **
** Every expectation that differs between the two models is written per  **
** model with `ifdef TMM_ASYNC_READ, so BOTH builds must pass. The read  **
** latency itself is asserted (RDLAT), so the number is pinned by a test **
** rather than by memory.                                                **
**                                                                       **
** Notes on modelled behaviour that the checks pin down:                 **
**   - reset does NOT clear the arrays (the reset branch is empty), so   **
**     nothing here expects zeroed shadow RAM after reset;               **
**   - a DESELECTED output drives 0, not z (FPGA convention);            **
**   - a bank being WRITTEN drives 0 on its data output (W_n low kills   **
**     the output gate);                                                 **
**   - with BOTH selects low and WMAP_n low the RTL writes BOTH banks,   **
**     each from its own data input (recorded, section G).               **
**                                                                       **
** Coverage:                                                             **
**   A  PT STATUS bank write + readback (bank had NO coverage before)    **
**   B  PPN bank write + readback, and cross-bank output isolation       **
**   C  both banks for the same index, interleaved                       **
**   D  BANK SHIFTING: pt_number 0/1/2/31 x vpn 0/1/63 (block            **
**      boundaries), 24 entries, no aliasing between tables              **
**   E  PTE CHANGE STICKS: read, set WIP(12), write back, read; then     **
**      set PGU(11) the same way - at read->write gaps 0 (tightest),     **
**      1 and 3 clocks, asserting the new value AND that no other bit    **
**      moved                                                            **
**   F  multiple writes then multiple reads; read of address A in the    **
**      same negedge slot as a just-completed write to address B (the    **
**      classic stale-output case - MODE DEPENDENT)                      **
**   G  shared WMAP_n: one select writes ONLY that bank; both selects    **
**      low writes both                                                  **
**   H  read latency measured from a single address presentation and     **
**      asserted against the model's own RDLAT                           **
**                                                                       **
** Stimulus is driven on the NEGEDGE so it is stable and unambiguous at  **
** the sampling posedge (the deliberate anti-race convention of the      **
** other benches in this directory).                                     **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** Run: make test-mmupt-rmw   (CPU-BOARD-3202/circuit/sim)               **
**                                                                       **
** 11-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CPU_MMU_PT_29_shadow_rmw_tb;

  // Expected number of checks - the verdict is gated on this too, so a
  // silently skipped section cannot pass.
  localparam integer EXPECTED_CHECKS = 77;

  // Read latency of the compiled RAM model, in posedges from the address
  // presentation to valid data. Asserted in section H.
`ifdef TMM_ASYNC_READ
  localparam integer RDLAT = 0;
`else
  localparam integer RDLAT = 1;
`endif

  // PT status word bit positions
  localparam integer BIT_WIP = 12;
  localparam integer BIT_PGU = 11;

  reg         sysclk;
  reg         sys_rst_n;
  reg  [10:0] LA_20_10;
  reg         EPMAP_n;  // PPN bank chip select (active low)
  reg         EPT_n;  // PT  bank chip select (active low)
  reg         WCLIM_n;  // cache-inhibit RAM write strobe (held inactive)
  reg         WMAP_n;  // SHARED write strobe (active low)
  reg  [15:0] PPN_25_10_IN;
  reg  [15:0] PT_15_0_IN;

  wire [15:0] PPN_25_10_OUT;
  wire [15:0] PT_15_0_OUT;
  wire        WCINH_n;

  integer errors = 0;
  integer checks = 0;

  CPU_MMU_PT_29 DUT (
      .sysclk       (sysclk),
      .sys_rst_n    (sys_rst_n),
      .LA_20_10     (LA_20_10),
      .EPMAP_n      (EPMAP_n),
      .EPT_n        (EPT_n),
      .WCLIM_n      (WCLIM_n),
      .WMAP_n       (WMAP_n),
      .PPN_25_10_IN (PPN_25_10_IN),
      .PPN_25_10_OUT(PPN_25_10_OUT),
      .PT_15_0_IN   (PT_15_0_IN),
      .PT_15_0_OUT  (PT_15_0_OUT),
      .WCINH_n      (WCINH_n)
  );

  // 100 MHz clock
  initial sysclk = 0;
  always #5 sysclk = ~sysclk;

  /*************************************************************************
   ** Helpers                                                             **
   *************************************************************************/

  task check_eq(input [15:0] got, input [15:0] exp, input [(8*56):1] msg);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        $display("  FAIL: %0s  got=%06o expected=%06o", msg, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  // shadow index = PT_number*64 + virtual_page
  function [10:0] sidx(input integer pt_number, input integer vpn);
    begin
      sidx = pt_number * 64 + vpn;
    end
  endfunction

  task idle_deselected;
    begin
      @(negedge sysclk);
      EPT_n   = 1'b1;
      EPMAP_n = 1'b1;
      WMAP_n  = 1'b1;
      @(posedge sysclk);
    end
  endtask

  // --- writes: one clocked write into ONE bank ------------------------- //
  task pt_write(input [10:0] idx, input [15:0] value);
    begin
      @(negedge sysclk);
      LA_20_10   = idx;
      PT_15_0_IN = value;
      EPT_n      = 1'b0;  // select PT status bank only
      EPMAP_n    = 1'b1;
      WMAP_n     = 1'b0;
      @(posedge sysclk);  // CHIP_24G/25G write array[idx] <= value here
      @(negedge sysclk);
      WMAP_n = 1'b1;  // release AFTER the edge
      EPT_n  = 1'b1;
    end
  endtask

  task ppn_write(input [10:0] idx, input [15:0] value);
    begin
      @(negedge sysclk);
      LA_20_10     = idx;
      PPN_25_10_IN = value;
      EPMAP_n      = 1'b0;  // select PPN bank only
      EPT_n        = 1'b1;
      WMAP_n       = 1'b0;
      @(posedge sysclk);  // CHIP_22G/23G write array[idx] <= value here
      @(negedge sysclk);
      WMAP_n  = 1'b1;
      EPMAP_n = 1'b1;
    end
  endtask

  // Both selects low with the one shared WMAP_n. Recorded, not assumed
  // illegal: the RTL writes BOTH banks, each from its own data input.
  task both_write(input [10:0] idx, input [15:0] ptval, input [15:0] ppnval);
    begin
      @(negedge sysclk);
      LA_20_10     = idx;
      PT_15_0_IN   = ptval;
      PPN_25_10_IN = ppnval;
      EPT_n        = 1'b0;
      EPMAP_n      = 1'b0;
      WMAP_n       = 1'b0;
      @(posedge sysclk);
      @(negedge sysclk);
      WMAP_n  = 1'b1;
      EPT_n   = 1'b1;
      EPMAP_n = 1'b1;
    end
  endtask

  // --- reads: present the address, wait `clocks` posedges, sample ------ //
  // The other bank is DESELECTED, so its output must read 0.
  task pt_read(input [10:0] idx, input integer clocks, output [15:0] got);
    integer i;
    begin
      @(negedge sysclk);
      LA_20_10 = idx;
      EPT_n    = 1'b0;
      EPMAP_n  = 1'b1;
      WMAP_n   = 1'b1;
      for (i = 0; i < clocks; i = i + 1) @(posedge sysclk);
      #1;  // let the combinational output gate settle after the edge
      got = PT_15_0_OUT;
    end
  endtask

  task ppn_read(input [10:0] idx, input integer clocks, output [15:0] got);
    integer i;
    begin
      @(negedge sysclk);
      LA_20_10 = idx;
      EPMAP_n  = 1'b0;
      EPT_n    = 1'b1;
      WMAP_n   = 1'b1;
      for (i = 0; i < clocks; i = i + 1) @(posedge sysclk);
      #1;
      got = PPN_25_10_OUT;
    end
  endtask

  // Latency probe: ONE address presentation, sampled at 0/1/2 posedges.
  // (Calling pt_read three times would not measure anything - the address
  // stays selected between calls and the model would already be loaded.)
  task pt_read_latency(input [10:0] idx, output [15:0] a0, output [15:0] a1,
                       output [15:0] a2);
    begin
      @(negedge sysclk);
      LA_20_10 = idx;
      EPT_n    = 1'b0;
      EPMAP_n  = 1'b1;
      WMAP_n   = 1'b1;
      #1;
      a0 = PT_15_0_OUT;
      @(posedge sysclk);
      #1;
      a1 = PT_15_0_OUT;
      @(posedge sysclk);
      #1;
      a2 = PT_15_0_OUT;
    end
  endtask

  // Write PPN[widx], then in the SAME negedge slot that releases the write
  // switch to reading a DIFFERENT address ridx: the classic stale-output
  // case, zero clocks after the write edge.
  task ppn_write_then_read(input [10:0] widx, input [15:0] wval,
                           input [10:0] ridx, output [15:0] a0,
                           output [15:0] a1);
    begin
      @(negedge sysclk);
      LA_20_10     = widx;
      PPN_25_10_IN = wval;
      EPMAP_n      = 1'b0;
      EPT_n        = 1'b1;
      WMAP_n       = 1'b0;
      @(posedge sysclk);  // the write lands here
      @(negedge sysclk);
      WMAP_n   = 1'b1;  // now reading ...
      LA_20_10 = ridx;  // ... a different address
      #1;
      a0 = PPN_25_10_OUT;  // 0 posedges after the write edge
      @(posedge sysclk);
      #1;
      a1 = PPN_25_10_OUT;  // 1 posedge after the write edge
    end
  endtask

  // --- the trap handler's shape: read PT, set one bit, write it back --- //
  // `gap` = extra posedges inserted between the read and the write-back;
  // gap 0 is the tightest the RTL allows (write on the very next posedge
  // after the read posedge in the sync model).
  task pt_rmw_setbit(input [10:0] idx, input integer bitnum, input integer gap,
                     input [15:0] prev_val);
    reg [15:0] got;
    reg [15:0] newv;
    integer i;
    begin
      pt_read(idx, RDLAT, got);
      check_eq(got, prev_val, "RMW: value read before modify");
      newv = got | (16'b1 << bitnum);
      for (i = 0; i < gap; i = i + 1) @(posedge sysclk);
      pt_write(idx, newv);
      pt_read(idx, RDLAT, got);
      check_eq(got, newv, "RMW: modified PTE stuck");
      check_eq(got & ~(16'b1 << bitnum), prev_val, "RMW: no other bit moved");
    end
  endtask

  /*************************************************************************
   ** Stimulus                                                            **
   *************************************************************************/

  reg [15:0] r0, r1, r2;
  reg [15:0] a0, a1, a2;
  reg [15:0] seen[0:23];
  integer    pti;
  integer    vpi;
  integer    k;
  integer    measured;
  reg [15:0] kw;
  reg [15:0] mw;

  // captured real PT status entry
  localparam [15:0] PTE_BASE = 16'o162000;

  integer pt_nums[0:3];
  integer vpns[0:2];

  initial begin
    sys_rst_n    = 0;
    LA_20_10     = 0;
    EPMAP_n      = 1;
    EPT_n        = 1;
    WCLIM_n      = 1;  // cache-inhibit RAM: never written by this bench
    WMAP_n       = 1;
    PPN_25_10_IN = 0;
    PT_15_0_IN   = 0;
    repeat (4) @(posedge sysclk);
    sys_rst_n = 1;
    repeat (2) @(posedge sysclk);

    $display("[info] compiled read model: %0s, RDLAT=%0d posedge(s)",
`ifdef TMM_ASYNC_READ
             "ASYNC (TMM_ASYNC_READ)",
`else
             "SYNC (block RAM)",
`endif
             RDLAT);

    // =================================================================== //
    // A. PT STATUS bank (EPT_n) - write then read back. This bank has no
    //    other coverage in the tree: CPU_MMU_PT_29_tb.v holds EPT_n high.
    // =================================================================== //
    pt_write(11'o0000, 16'o162000);
    pt_write(11'o0001, 16'o142000);
    pt_write(11'o0077, 16'o160400);
    pt_write(11'o3777, 16'o177777);

    pt_read(11'o0000, RDLAT, r0);
    check_eq(r0, 16'o162000, "PT[0000] readback");
    pt_read(11'o0001, RDLAT, r0);
    check_eq(r0, 16'o142000, "PT[0001] readback");
    pt_read(11'o0077, RDLAT, r0);
    check_eq(r0, 16'o160400, "PT[0077] readback");
    pt_read(11'o3777, RDLAT, r0);
    check_eq(r0, 16'o177777, "PT[3777] readback (top entry)");
    // the PPN bank is deselected during a PT read: output drives 0, not z
    check_eq(PPN_25_10_OUT, 16'o000000, "PPN out is 0 while deselected");

    // =================================================================== //
    // B. PPN bank (EPMAP_n) - same treatment
    // =================================================================== //
    ppn_write(11'o0000, 16'o000100);
    ppn_write(11'o0001, 16'o000200);
    ppn_write(11'o0077, 16'o000077);
    ppn_write(11'o3777, 16'o007777);

    ppn_read(11'o0000, RDLAT, r0);
    check_eq(r0, 16'o000100, "PPN[0000] readback");
    ppn_read(11'o0001, RDLAT, r0);
    check_eq(r0, 16'o000200, "PPN[0001] readback");
    ppn_read(11'o0077, RDLAT, r0);
    check_eq(r0, 16'o000077, "PPN[0077] readback");
    ppn_read(11'o3777, RDLAT, r0);
    check_eq(r0, 16'o007777, "PPN[3777] readback (top entry)");
    check_eq(PT_15_0_OUT, 16'o000000, "PT out is 0 while deselected");

    // =================================================================== //
    // C. Both banks for the SAME index, interleaved
    // =================================================================== //
    for (k = 0; k < 3; k = k + 1) begin
      kw = k;
      pt_write(sidx(3, 8 + k), PTE_BASE | kw);
      ppn_write(sidx(3, 8 + k), 16'o004000 + kw);
    end
    for (k = 0; k < 3; k = k + 1) begin
      kw = k;
      pt_read(sidx(3, 8 + k), RDLAT, r0);
      check_eq(r0, PTE_BASE | kw, "interleaved PT entry");
      ppn_read(sidx(3, 8 + k), RDLAT, r1);
      check_eq(r1, 16'o004000 + kw, "interleaved PPN entry");
    end

    // =================================================================== //
    // D. BANK SHIFTING: same virtual page in several page tables must NOT
    //    alias. Boundary pages 0 and 63 of each 64-entry block included.
    // =================================================================== //
    pt_nums[0] = 0;
    pt_nums[1] = 1;
    pt_nums[2] = 2;
    pt_nums[3] = 31;
    vpns[0]    = 0;
    vpns[1]    = 1;
    vpns[2]    = 63;

    for (pti = 0; pti < 4; pti = pti + 1) begin
      for (vpi = 0; vpi < 3; vpi = vpi + 1) begin
        pt_write(sidx(pt_nums[pti], vpns[vpi]),
                 16'o160000 | {5'b0, sidx(pt_nums[pti], vpns[vpi])});
        ppn_write(sidx(pt_nums[pti], vpns[vpi]),
                  16'o020000 | {5'b0, sidx(pt_nums[pti], vpns[vpi])});
      end
    end

    for (pti = 0; pti < 4; pti = pti + 1) begin
      for (vpi = 0; vpi < 3; vpi = vpi + 1) begin
        pt_read(sidx(pt_nums[pti], vpns[vpi]), RDLAT, r0);
        check_eq(r0, 16'o160000 | {5'b0, sidx(pt_nums[pti], vpns[vpi])},
                 "bank-shift PT entry");
        seen[pti*3+vpi] = r0;
        ppn_read(sidx(pt_nums[pti], vpns[vpi]), RDLAT, r1);
        check_eq(r1, 16'o020000 | {5'b0, sidx(pt_nums[pti], vpns[vpi])},
                 "bank-shift PPN entry");
      end
    end

    // explicit non-aliasing between page tables for the SAME virtual page
    check_eq((seen[0] == seen[3]) ? 16'o1 : 16'o0, 16'o0,
             "PT0/PT1 vpn0 do not alias");
    check_eq((seen[2] == seen[11]) ? 16'o1 : 16'o0, 16'o0,
             "PT0/PT31 vpn63 do not alias");

    // =================================================================== //
    // E. PTE CHANGE STICKS - the trap-handler read-modify-write shape.
    //    Three read->write-back distances, gap 0 being the tightest the
    //    RTL allows. Sets WIP (bit 12) then PGU (bit 11) on the same entry.
    // =================================================================== //
    // gap 0 - back to back
    pt_write(sidx(5, 10), PTE_BASE);
    pt_rmw_setbit(sidx(5, 10), BIT_WIP, 0, PTE_BASE);
    pt_rmw_setbit(sidx(5, 10), BIT_PGU, 0, PTE_BASE | (16'b1 << BIT_WIP));

    // gap 1
    pt_write(sidx(6, 63), PTE_BASE);
    pt_rmw_setbit(sidx(6, 63), BIT_WIP, 1, PTE_BASE);
    pt_rmw_setbit(sidx(6, 63), BIT_PGU, 1, PTE_BASE | (16'b1 << BIT_WIP));

    // gap 3
    pt_write(sidx(7, 0), PTE_BASE);
    pt_rmw_setbit(sidx(7, 0), BIT_WIP, 3, PTE_BASE);
    pt_rmw_setbit(sidx(7, 0), BIT_PGU, 3, PTE_BASE | (16'b1 << BIT_WIP));

    // =================================================================== //
    // F. Several writes in a row, then several reads in a row; then a read
    //    of address A in the same negedge slot that releases a write to
    //    address B. The 0-posedge sample is MODE DEPENDENT and is the whole
    //    point of the sync-vs-async divergence.
    // =================================================================== //
    ppn_write(sidx(9, 0), 16'o000401);
    ppn_write(sidx(9, 1), 16'o000402);
    ppn_write(sidx(9, 2), 16'o000403);
    ppn_write(sidx(9, 3), 16'o000404);

    ppn_read(sidx(9, 0), RDLAT, r0);
    check_eq(r0, 16'o000401, "sequence PPN[9,0]");
    ppn_read(sidx(9, 1), RDLAT, r0);
    check_eq(r0, 16'o000402, "sequence PPN[9,1]");
    ppn_read(sidx(9, 2), RDLAT, r0);
    check_eq(r0, 16'o000403, "sequence PPN[9,2]");
    // the LAST read before the stale probe: it is what the sync model's
    // output register still holds when the probe samples at 0 posedges.
    ppn_read(sidx(9, 3), RDLAT, r0);
    check_eq(r0, 16'o000404, "sequence PPN[9,3]");

    // write B = [9,2] with a new value, then immediately read A = [9,0]
    ppn_write_then_read(sidx(9, 2), 16'o000503, sidx(9, 0), a0, a1);
`ifdef TMM_ASYNC_READ
    // async model: the output follows the address at once
    check_eq(a0, 16'o000401, "async: A readable 0 clocks after write to B");
`else
    // sync model: the output register was NOT reloaded by the write cycle,
    // so it still shows the previously READ entry [9,3] - a consumer that
    // samples here gets a stale word
    check_eq(a0, 16'o000404, "sync: stale prior word 0 clocks after write");
`endif
    check_eq(a1, 16'o000401, "A readable 1 clock after write to B");
    ppn_read(sidx(9, 2), RDLAT, r0);
    check_eq(r0, 16'o000503, "write to B landed");

    // =================================================================== //
    // G. Shared WMAP_n: one chip select writes ONLY its own bank
    // =================================================================== //
    pt_write(sidx(11, 5), 16'o162000);
    ppn_write(sidx(11, 5), 16'o001111);

    pt_write(sidx(11, 5), 16'o172000);  // PT only
    pt_read(sidx(11, 5), RDLAT, r0);
    check_eq(r0, 16'o172000, "PT-only write updated PT");
    ppn_read(sidx(11, 5), RDLAT, r1);
    check_eq(r1, 16'o001111, "PT-only write left PPN untouched");

    ppn_write(sidx(11, 5), 16'o002222);  // PPN only
    ppn_read(sidx(11, 5), RDLAT, r1);
    check_eq(r1, 16'o002222, "PPN-only write updated PPN");
    pt_read(sidx(11, 5), RDLAT, r0);
    check_eq(r0, 16'o172000, "PPN-only write left PT untouched");

    // BOTH selects low with the single shared strobe: RECORDED behaviour of
    // this RTL - both banks are written, each from its own data input.
    both_write(sidx(11, 5), 16'o150000, 16'o003333);
    pt_read(sidx(11, 5), RDLAT, r0);
    check_eq(r0, 16'o150000, "both-selects-low wrote the PT bank");
    ppn_read(sidx(11, 5), RDLAT, r1);
    check_eq(r1, 16'o003333, "both-selects-low wrote the PPN bank");

    // =================================================================== //
    // H. Read latency, measured from ONE address presentation and asserted
    //    against the compiled model's RDLAT.
    // =================================================================== //
    pt_write(sidx(13, 1), 16'o164000);  // the address under test
    pt_write(sidx(13, 2), 16'o166000);  // a decoy read just before it
    pt_read(sidx(13, 2), RDLAT, r0);  // loads the sync output register
    idle_deselected;  // no read happens while deselected
    pt_read_latency(sidx(13, 1), a0, a1, a2);
    $display("[latency] PT[13,1]: after0=%06o after1=%06o after2=%06o (value 164000)",
             a0, a1, a2);

`ifdef TMM_ASYNC_READ
    check_eq(a0, 16'o164000, "async: data valid with 0 clocks");
`else
    check_eq(a0, 16'o166000, "sync: previous word still out at 0 clocks");
`endif
    check_eq(a1, 16'o164000, "data valid 1 clock after address");
    check_eq(a2, 16'o164000, "data still valid 2 clocks after address");

    if (a0 === 16'o164000) measured = 0;
    else if (a1 === 16'o164000) measured = 1;
    else if (a2 === 16'o164000) measured = 2;
    else measured = -1;
    $display("[latency] measured read latency = %0d posedge(s)", measured);
    mw = measured;
    check_eq(mw, RDLAT, "measured read latency == RDLAT");

    // =================================================================== //
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)", errors, checks,
               EXPECTED_CHECKS);
    $finish;
  end

  initial begin
    #500000;
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule
