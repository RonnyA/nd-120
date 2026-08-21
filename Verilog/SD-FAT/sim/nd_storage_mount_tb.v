/****************************************************************************
** nd_storage_mount - open/preload FSM unit testbench                      **
**                                                                         **
** Full path:                                                              **
**   Verilog/SD-FAT/sim/nd_storage_mount_tb.v                              **
**                                                                         **
** WHAT IS VERIFIED                                                        **
**   nd_storage_mount (Verilog/SD-FAT/circuit/nd_storage_mount.v) is the   **
**   FSM the block engine hands every granted open request to. It owns the **
**   SD reader and the SD pin phase while it runs, and it publishes the    **
**   per-client geometry the whole storage stack then trusts. Nothing else **
**   re-derives that geometry, so a wrong slice here is a silent wrong     **
**   answer for every later block request - which is the one failure mode  **
**   nd_storage_status.vh exists to eliminate.                             **
**                                                                         **
**   Checked here:                                                         **
**     - the three FAILURE verdicts are distinguishable at the port, not   **
**       just "something went wrong": out-of-range client (card never      **
**       touched, no status update), no card (mnt_nocard=1, st_val=1),     **
**       card fine but file missing (mnt_nocard=0, st_val=2)               **
**     - the OK verdict publishes size_bytes / first_sector /              **
**       first_cluster / n_blocks into the RIGHT client slice, and does    **
**       not disturb any other client's slice                              **
**     - n_blocks = ceil(size/2048) at the boundaries 0, 1, 2047, 2048,    **
**       2049 - and the DOCUMENTED 128 MiB truncation above that           **
**     - the SD pin phase and reader-reset sequencing: phase_write 1->0    **
**       in M_INIT and back to 1 by mnt_done, rd_run released only after   **
**       the reset window and parked again at mnt_done                     **
**     - mnt_done / st_upd / chk_start / mem_start are single-cycle        **
**       pulses, never levels                                              **
**     - the s_got_geom latch guard: geometry is captured on the FIRST     **
**       file_found cycle and later reader values are ignored              **
**     - a re-open clears that client's open_ok at the M_IDLE handshake    **
**     - the dead preload path stays dead: mem_start never pulses and      **
**       load_fifo_ovf never sets, across the whole run                    **
**     - SDFAT_STORAGE_CHECK build only: the chk_start/chk_done handshake, **
**       the chk_* payload at chk_start, and chk_ok=0 failing the open     **
**                                                                         **
** WHERE THE REFERENCE MODEL CAME FROM                                     **
**   The RTL itself, read line by line - there is no external spec for     **
**   this FSM and none was invented. The expected values are computed in   **
**   the testbench from the stimulus (ceil(size/2048) from an independent  **
**   expression, the driven geometry words, the driven client index), not  **
**   copied out of the DUT. The reader side is a SCRIPTED MODEL: this      **
**   testbench plays the part of sd_file_reader (card_stat, file_found as  **
**   a level, scan_done, the found_ and fs_ words) and of the checker      **
**   (chk_done/chk_ok). Two behaviours are recorded as CHARACTERISATION,   **
**   flagged in-line where they are checked, because the RTL's own         **
**   comments say they are known and deliberate:                           **
**     C1  mem_we is hard-wired 1 (nd_storage_mount.v:226 and the note     **
**         above it) even though the mount no longer writes anything       **
**     C2  n_blocks uses s_size[26:11], so a file >= 2^27 bytes is         **
**         silently mis-sized (nd_storage_mount.v, the r_nblk note)        **
**   and one observation is recorded that the RTL does NOT comment on:     **
**     C3  an out-of-range client cannot set an open_err bit, because      **
**         open_err is only N_CLIENTS wide - the refusal reaches the       **
**         engine through mnt_err alone                                    **
**                                                                         **
** TEST PLAN                                                               **
**   T1   reset: every output quiescent, mem_we=1 (C1)                     **
**   T2   out-of-range client: fails, card untouched, no status update     **
**   T3   no card: watchdog -> mnt_nocard=1, st_val=1                      **
**   T4   card up, scan_done without file_found -> nocard=0, st_val=2      **
**   T5   happy path, client 1: slices, sequencing, pulse widths           **
**   T6   happy path, client 3: client 1's slice undisturbed               **
**   T7   n_blocks boundaries 0/1/2047/2048/2049 and the 2^27 ceiling (C2) **
**   T8   geometry latch guard (values changed after the first match)      **
**   T9   re-open clears open_ok at the handshake                          **
**   T10  M_SCAN watchdog: geometry latched but scan never ends -> fail    **
**   T11  (SDFAT_STORAGE_CHECK build) chk payload, chk_ok=0 fails the open **
**   Continuous: pulse-width discipline, mem_start never fires,            **
**   load_fifo_ovf never sets, no x/z on the verdict outputs.              **
**                                                                         **
** HOW TO RUN                                                              **
**   cd Verilog/SD-FAT/sim                                                 **
**   make test-nds-mountfsm        (both builds)                           **
**   or, by hand, from that directory:                                     **
**     iverilog -g2012 -I../circuit -o nd_storage_mount_fsm_tb.vvp \       **
**              ../circuit/nd_storage_mount.v nd_storage_mount_tb.v        **
**     vvp -N nd_storage_mount_fsm_tb.vvp                                  **
**   and again with -DSDFAT_FORCE_STORAGE_CHECK to build the contiguity    **
**   gate in (sd_fat_features.vh turns that into SDFAT_STORAGE_CHECK).     **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none
`include "sd_fat_features.vh"

module nd_storage_mount_tb;

  localparam integer N_CLIENTS = 5;      // clients 0..4 valid, 5..7 refused
  localparam [31:0]  WD_MAX    = 32'd200;  // short watchdog: the tb must finish

  // -------------------------------------------------------------- clock/reset
  reg clk = 1'b0;
  always #5 clk = ~clk;                  // 100 MHz stand-in for clk_stor
  reg rst_n = 1'b0;

  integer checks = 0;
  integer errors = 0;

  task chk(input cond, input [8*72-1:0] what);
    begin
      checks = checks + 1;
      if (cond !== 1'b1) begin
        errors = errors + 1;
        $display("FAIL @%0t: %0s", $time, what);
      end
    end
  endtask

  task chkv(input cond, input [8*72-1:0] what,
            input [31:0] got, input [31:0] want);
    begin
      checks = checks + 1;
      if (cond !== 1'b1) begin
        errors = errors + 1;
        $display("FAIL @%0t: %0s (got %0d / 0x%08h, want %0d / 0x%08h)",
                 $time, what, got, got, want, want);
      end
    end
  endtask

  // -------------------------------------------------------------- DUT signals
  reg         mnt_start = 1'b0;
  reg  [2:0]  mnt_client = 3'd0;
  wire        mnt_done, mnt_err, mnt_nocard, mnt_busy;

  wire        rd_run, phase_write;
  wire [2:0]  cur_client;
  reg  [3:0]  card_stat = 4'd0;
  reg         file_found = 1'b0;
  reg         scan_done = 1'b0;
  reg  [31:0] found_size = 32'd0;
  reg  [31:0] found_first_sector = 32'd0;
  reg  [31:0] found_cluster = 32'd0;
  reg  [7:0]  fs_cluster_size = 8'd0;
  reg  [31:0] fs_fat0_sector = 32'd0;
  reg         fs_is_fat32 = 1'b0;
  reg         outen = 1'b0;
  reg  [7:0]  outbyte = 8'd0;

  wire        mem_start, mem_we;
  wire [19:0] mem_addr;
  wire [31:0] mem_wdata;
  reg         mem_busy = 1'b0;
  reg         mem_done = 1'b0;

  wire        chk_start;
  reg         chk_done = 1'b0;
  reg         chk_ok = 1'b0;
  wire [31:0] chk_first_cluster;
  wire [7:0]  chk_cluster_size;
  wire [31:0] chk_fat0_sector;
  wire        chk_is_fat32;
  wire [31:0] chk_size;

  wire [N_CLIENTS-1:0]    open_ok, open_err;
  wire [N_CLIENTS*32-1:0] size_bytes, first_sector;
  wire [N_CLIENTS*16-1:0] n_blocks;
  wire [N_CLIENTS*28-1:0] first_cluster;

  wire       st_upd;
  wire [1:0] st_val;
  wire       load_fifo_ovf;

  nd_storage_mount #(
      .N_CLIENTS(N_CLIENTS),
      .WD_MAX   (WD_MAX)
  ) DUT (
      .clk_stor          (clk),
      .rst_stor_n        (rst_n),
      .mnt_start         (mnt_start),
      .mnt_client        (mnt_client),
      .mnt_done          (mnt_done),
      .mnt_err           (mnt_err),
      .mnt_nocard        (mnt_nocard),
      .mnt_busy          (mnt_busy),
      .rd_run            (rd_run),
      .phase_write       (phase_write),
      .cur_client        (cur_client),
      .card_stat         (card_stat),
      .file_found        (file_found),
      .scan_done         (scan_done),
      .found_size        (found_size),
      .found_first_sector(found_first_sector),
      .found_cluster     (found_cluster),
      .fs_cluster_size   (fs_cluster_size),
      .fs_fat0_sector    (fs_fat0_sector),
      .fs_is_fat32       (fs_is_fat32),
      .outen             (outen),
      .outbyte           (outbyte),
      .mem_start         (mem_start),
      .mem_we            (mem_we),
      .mem_addr          (mem_addr),
      .mem_wdata         (mem_wdata),
      .mem_busy          (mem_busy),
      .mem_done          (mem_done),
      .chk_start         (chk_start),
      .chk_done          (chk_done),
      .chk_ok            (chk_ok),
      .chk_first_cluster (chk_first_cluster),
      .chk_cluster_size  (chk_cluster_size),
      .chk_fat0_sector   (chk_fat0_sector),
      .chk_is_fat32      (chk_is_fat32),
      .chk_size          (chk_size),
      .open_ok           (open_ok),
      .open_err          (open_err),
      .size_bytes        (size_bytes),
      .n_blocks          (n_blocks),
      .first_cluster     (first_cluster),
      .first_sector      (first_sector),
      .st_upd            (st_upd),
      .st_val            (st_val),
      .load_fifo_ovf     (load_fifo_ovf)
  );

  // ------------------------------------------------- scripted fatchk model
  // Stands in for nd_storage_fatchk.v: one chk_done pulse a few cycles after
  // each chk_start, carrying the verdict the current test wants. Inert in the
  // build without SDFAT_STORAGE_CHECK, where chk_start never fires.
  reg        chk_ok_next = 1'b1;
  reg        chk_pending = 1'b0;
  reg [3:0]  chk_cnt = 4'd0;
  integer    chk_start_count = 0;

  always @(posedge clk) begin
    if (!rst_n) begin
      chk_done    <= 1'b0;
      chk_ok      <= 1'b0;
      chk_pending <= 1'b0;
      chk_cnt     <= 4'd0;
    end else begin
      chk_done <= 1'b0;
      if (chk_start) begin
        chk_pending <= 1'b1;
        chk_cnt     <= 4'd3;
      end else if (chk_pending) begin
        if (chk_cnt == 4'd0) begin
          chk_done    <= 1'b1;
          chk_ok      <= chk_ok_next;
          chk_pending <= 1'b0;
        end else chk_cnt <= chk_cnt - 4'd1;
      end
    end
  end

  // ------------------------------------------------------------- monitors
  integer st_upd_count   = 0;
  integer mnt_done_count = 0;
  integer mem_start_count = 0;
  reg [1:0] last_st_val  = 2'd0;
  reg       watch_card   = 1'b0;
  reg       card_touched = 1'b0;
  reg       mnt_done_q   = 1'b0;
  reg       st_upd_q     = 1'b0;
  reg       chk_start_q  = 1'b0;

  // chk_* payload captured at the chk_start pulse
  reg [31:0] cap_fclu = 32'd0, cap_fat0 = 32'd0, cap_size = 32'd0;
  reg [7:0]  cap_csz  = 8'd0;
  reg        cap_f32  = 1'b0;

  always @(posedge clk) begin
    #1;
    if (rst_n === 1'b1) begin
      if (st_upd) begin
        st_upd_count = st_upd_count + 1;
        last_st_val  = st_val;
      end
      if (mnt_done)  mnt_done_count  = mnt_done_count + 1;
      if (mem_start) mem_start_count = mem_start_count + 1;
      if (chk_start) begin
        chk_start_count = chk_start_count + 1;
        cap_fclu = chk_first_cluster;
        cap_csz  = chk_cluster_size;
        cap_fat0 = chk_fat0_sector;
        cap_f32  = chk_is_fat32;
        cap_size = chk_size;
      end
      // the card must not be touched while a refusal is being watched
      if (watch_card && (rd_run !== 1'b0 || phase_write !== 1'b1))
        card_touched = 1'b1;
      // pulse discipline: these are contracts, not conveniences
      if (mnt_done && mnt_done_q) begin
        errors = errors + 1;
        $display("FAIL @%0t: mnt_done held for more than one cycle", $time);
      end
      if (st_upd && st_upd_q) begin
        errors = errors + 1;
        $display("FAIL @%0t: st_upd held for more than one cycle", $time);
      end
      if (chk_start && chk_start_q) begin
        errors = errors + 1;
        $display("FAIL @%0t: chk_start held for more than one cycle", $time);
      end
      if (mnt_done === 1'bx || mnt_err === 1'bx || mnt_nocard === 1'bx ||
          st_upd === 1'bx || rd_run === 1'bx || phase_write === 1'bx) begin
        errors = errors + 1;
        $display("FAIL @%0t: an x reached a verdict/control output", $time);
      end
      mnt_done_q  = mnt_done;
      st_upd_q    = st_upd;
      chk_start_q = chk_start;
    end
  end

  // -------------------------------------------------------------- watchdog
  initial begin
    #3_000_000;
    $display("checks=%0d failures=%0d", checks, errors + 1);
    $display("TB_RESULT: FAIL  (watchdog: testbench did not finish)");
    $finish;
  end

  // -------------------------------------------------------------- VCD
  initial begin
    $dumpfile("nd_storage_mount_tb.vcd");
    $dumpvars(0, nd_storage_mount_tb);
  end

  // -------------------------------------------------------------- helpers
  function [31:0] ceil_blocks(input [31:0] sz);   // the INTENDED ceil(sz/2048)
    ceil_blocks = (sz >> 11) + {31'd0, |sz[10:0]};
  endfunction

  task rdr_idle;                                   // reader parked / no card
    begin
      card_stat          = 4'd0;
      file_found         = 1'b0;
      scan_done          = 1'b0;
      found_size         = 32'd0;
      found_first_sector = 32'd0;
      found_cluster      = 32'd0;
      fs_cluster_size    = 8'd0;
      fs_fat0_sector     = 32'd0;
      fs_is_fat32        = 1'b0;
    end
  endtask

  task start_open(input [2:0] c);                  // one-cycle mnt_start pulse
    begin
      @(negedge clk);
      mnt_client = c;
      mnt_start  = 1'b1;
      @(negedge clk);
      mnt_start  = 1'b0;
    end
  endtask

  task wait_rd_run(output integer n);
    begin
      n = 0;
      while (rd_run !== 1'b1 && n < 100) begin
        @(posedge clk);
        #1;
        n = n + 1;
      end
      chk(rd_run === 1'b1, "rd_run was never released");
    end
  endtask

  task wait_done(input integer maxc);
    integer k;
    begin
      k = 0;
      while (mnt_done !== 1'b1 && k < maxc) begin
        @(posedge clk);
        #1;
        k = k + 1;
      end
      chk(mnt_done === 1'b1, "timed out waiting for mnt_done");
    end
  endtask

  // A complete SUCCESSFUL reader script. perturb=1 changes every reader
  // output one cycle AFTER the first file_found edge, to prove the latch
  // guard keeps the first values.
  integer rd_run_cycles;
  task mount_good(input [2:0] c, input [31:0] sz, input [31:0] fsec,
                  input [31:0] fclu, input [7:0] csz, input [31:0] fat0,
                  input isf32, input perturb);
    begin
      rdr_idle;
      start_open(c);
      wait_rd_run(rd_run_cycles);
      repeat (3) @(negedge clk);
      card_stat = 4'd8;                     // card initialised
      repeat (3) @(negedge clk);
      found_size         = sz;
      found_first_sector = fsec;
      found_cluster      = fclu;
      fs_cluster_size    = csz;
      fs_fat0_sector     = fat0;
      fs_is_fat32        = isf32;
      @(negedge clk);
      file_found = 1'b1;                    // LEVEL, as the real reader drives
      repeat (2) @(posedge clk);
      if (perturb) begin
        @(negedge clk);
        found_size         = 32'hDEADBEEF;
        found_first_sector = 32'hFFFF0000;
        found_cluster      = 32'h0FFFFFFF;
        fs_cluster_size    = 8'hFF;
        fs_fat0_sector     = 32'hAAAA5555;
        fs_is_fat32        = ~isf32;
        repeat (2) @(posedge clk);
      end
      @(negedge clk);
      scan_done = 1'b1;                     // reader stops at a clean boundary
      @(negedge clk);
      scan_done = 1'b0;
      wait_done(400);
      rdr_idle;
      @(negedge clk);
    end
  endtask

  // -------------------------------------------------------------- stimulus
  integer  base_st;
  integer  base_mem;
  integer  i;
  reg [31:0] sz_v;
  reg [15:0] nb;

  initial begin
    rdr_idle;
    mnt_start   = 1'b0;
    mnt_client  = 3'd0;
    mem_busy    = 1'b0;
    mem_done    = 1'b0;
    outen       = 1'b0;
    outbyte     = 8'd0;
    chk_ok_next = 1'b1;
    rst_n       = 1'b0;

    // ---- T1: reset -------------------------------------------------------
    repeat (4) @(posedge clk);
    #1;
    chk(mnt_busy    === 1'b0, "T1 mnt_busy not 0 in reset");
    chk(rd_run      === 1'b0, "T1 rd_run not 0 in reset");
    chk(phase_write === 1'b1, "T1 phase_write not 1 in reset (writer owns pins)");
    chk(open_ok  === {N_CLIENTS{1'b0}}, "T1 open_ok not cleared by reset");
    chk(open_err === {N_CLIENTS{1'b0}}, "T1 open_err not cleared by reset");
    chk(mnt_done  === 1'b0, "T1 mnt_done not 0 in reset");
    chk(st_upd    === 1'b0, "T1 st_upd not 0 in reset");
    chk(chk_start === 1'b0, "T1 chk_start not 0 in reset");
    chk(mem_start === 1'b0, "T1 mem_start not 0 in reset");
    chk(load_fifo_ovf === 1'b0, "T1 load_fifo_ovf not 0 in reset");
    // C1 CHARACTERISATION: mem_we is a hard-wired 1 (nd_storage_mount.v:226).
    // The mount no longer writes anything, but the constant is deliberate and
    // is half of a pair with the mux in nd_storage.v - see the RTL note.
    chk(mem_we === 1'b1, "C1 mem_we is not the documented hard-wired 1");

    @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(negedge clk);

    // ---- T2: out-of-range client, card never touched ---------------------
    base_st      = st_upd_count;
    card_touched = 1'b0;
    watch_card   = 1'b1;
    rdr_idle;
    start_open(3'd6);                      // 6 >= N_CLIENTS(5)
    wait_done(40);
    #1;
    chk(mnt_err    === 1'b1, "T2 out-of-range client did not report mnt_err");
    chk(mnt_nocard === 1'b0, "T2 out-of-range client wrongly reported NOCARD");
    chk(card_touched === 1'b0, "T2 the card WAS touched for a refused client");
    chkv(st_upd_count == base_st, "T2 mask-fail issued a status update",
         st_upd_count, base_st);
    // C3 CHARACTERISATION: open_err is only N_CLIENTS wide, so the refusal
    // cannot be recorded in a per-client bit - mnt_err is the only channel.
    chk(open_err === {N_CLIENTS{1'b0}},
        "C3 an out-of-range refusal disturbed an in-range open_err bit");
    watch_card = 1'b0;
    @(negedge clk);
    #1;
    chk(mnt_busy === 1'b0, "T2 mnt_busy did not drop after the refusal");

    // ---- T3: no card -----------------------------------------------------
    base_st = st_upd_count;
    rdr_idle;
    start_open(3'd0);
    wait_done(WD_MAX + 300);
    #1;
    chk(mnt_err    === 1'b1, "T3 no-card open did not report mnt_err");
    chk(mnt_nocard === 1'b1, "T3 no-card open did not report mnt_nocard");
    chk(open_err[0] === 1'b1, "T3 open_err[0] not set by the no-card failure");
    chk(open_ok[0]  === 1'b0, "T3 open_ok[0] set by a failed open");
    chkv(st_upd_count == base_st + 1, "T3 exactly one status update expected",
         st_upd_count, base_st + 1);
    chkv(last_st_val == 2'd1, "T3 st_val is not NOCARD(1)", last_st_val, 1);
    chk(rd_run      === 1'b0, "T3 reader not parked after the failure");
    chk(phase_write === 1'b1, "T3 pins not returned to the writer");
    rdr_idle;
    @(negedge clk);

    // ---- T4: card up, scan ends without a match --------------------------
    base_st = st_upd_count;
    rdr_idle;
    start_open(3'd1);
    wait_rd_run(rd_run_cycles);
    repeat (3) @(negedge clk);
    card_stat = 4'd8;
    repeat (4) @(negedge clk);             // let the FSM settle in M_SCAN
    scan_done = 1'b1;                      // ...and end the scan unmatched
    @(negedge clk);
    scan_done = 1'b0;
    wait_done(200);
    #1;
    chk(mnt_err    === 1'b1, "T4 missing file did not report mnt_err");
    chk(mnt_nocard === 1'b0, "T4 missing file wrongly reported NOCARD");
    chk(open_err[1] === 1'b1, "T4 open_err[1] not set");
    chk(open_ok[1]  === 1'b0, "T4 open_ok[1] set by a failed open");
    chkv(st_upd_count == base_st + 1, "T4 exactly one status update expected",
         st_upd_count, base_st + 1);
    chkv(last_st_val == 2'd2, "T4 st_val is not ERROR(2)", last_st_val, 2);
    rdr_idle;
    @(negedge clk);

    // ---- T5: happy path on client 1 --------------------------------------
    base_st     = st_upd_count;
    chk_ok_next = 1'b1;
    mount_good(3'd1, 32'd2049, 32'h0001_2340, 32'h0000_ABCD,
               8'd8, 32'h0000_0100, 1'b0, 1'b0);
    #1;
    chk(mnt_err   === 1'b0, "T5 good open reported mnt_err");
    chk(open_ok[1]  === 1'b1, "T5 open_ok[1] not set by a good open");
    chk(open_err[1] === 1'b0, "T5 open_err[1] still set after a good open");
    chkv(st_upd_count == base_st + 1, "T5 exactly one status update expected",
         st_upd_count, base_st + 1);
    chkv(last_st_val == 2'd3, "T5 st_val is not OK(3)", last_st_val, 3);
    chkv(size_bytes[32*1 +: 32] === 32'd2049, "T5 size_bytes[1] wrong",
         size_bytes[32*1 +: 32], 32'd2049);
    chkv(first_sector[32*1 +: 32] === 32'h0001_2340, "T5 first_sector[1] wrong",
         first_sector[32*1 +: 32], 32'h0001_2340);
    chkv(first_cluster[28*1 +: 28] === 28'h000_ABCD, "T5 first_cluster[1] wrong",
         {4'd0, first_cluster[28*1 +: 28]}, 32'h0000_ABCD);
    chkv(n_blocks[16*1 +: 16] === 16'd2, "T5 n_blocks[1] != ceil(2049/2048)",
         {16'd0, n_blocks[16*1 +: 16]}, 32'd2);
    chkv(rd_run_cycles == 16, "T5 M_INIT reader-reset window changed length",
         rd_run_cycles, 16);
    chk(rd_run === 1'b0, "T5 reader not parked at mnt_done");
    chk(phase_write === 1'b1, "T5 pins not returned to the writer at mnt_done");
    chk(cur_client === 3'd1, "T5 cur_client is not the mounted client");

    // ---- T6: a second client must not disturb the first ------------------
    mount_good(3'd3, 32'd8192, 32'h0056_7800, 32'h0000_0002,
               8'd4, 32'h0000_0200, 1'b1, 1'b0);
    #1;
    chk(open_ok[3] === 1'b1, "T6 open_ok[3] not set");
    chk(open_ok[1] === 1'b1, "T6 client 1 lost its open_ok");
    chkv(size_bytes[32*3 +: 32] === 32'd8192, "T6 size_bytes[3] wrong",
         size_bytes[32*3 +: 32], 32'd8192);
    chkv(size_bytes[32*1 +: 32] === 32'd2049, "T6 client 1 slice was disturbed",
         size_bytes[32*1 +: 32], 32'd2049);
    chkv(first_sector[32*3 +: 32] === 32'h0056_7800, "T6 first_sector[3] wrong",
         first_sector[32*3 +: 32], 32'h0056_7800);
    chkv(first_sector[32*1 +: 32] === 32'h0001_2340,
         "T6 client 1 first_sector disturbed",
         first_sector[32*1 +: 32], 32'h0001_2340);
    chkv(n_blocks[16*3 +: 16] === 16'd4, "T6 n_blocks[3] != ceil(8192/2048)",
         {16'd0, n_blocks[16*3 +: 16]}, 32'd4);
    chkv(n_blocks[16*1 +: 16] === 16'd2, "T6 client 1 n_blocks disturbed",
         {16'd0, n_blocks[16*1 +: 16]}, 32'd2);
    chkv(size_bytes[32*0 +: 32] === 32'd0, "T6 an unmounted client has a size",
         size_bytes[32*0 +: 32], 32'd0);

    // ---- T7: n_blocks boundaries ----------------------------------------
    for (i = 0; i < 5; i = i + 1) begin
      case (i)
        0: sz_v = 32'd0;
        1: sz_v = 32'd1;
        2: sz_v = 32'd2047;
        3: sz_v = 32'd2048;
        default: sz_v = 32'd2049;
      endcase
      mount_good(3'd4, sz_v, 32'h0000_1000, 32'h0000_0003,
                 8'd8, 32'h0000_0100, 1'b0, 1'b0);
      #1;
      nb = n_blocks[16*4 +: 16];
      chkv({16'd0, nb} === ceil_blocks(sz_v),
           "T7 n_blocks != ceil(size/2048) below the ceiling",
           {16'd0, nb}, ceil_blocks(sz_v));
      chkv(size_bytes[32*4 +: 32] === sz_v, "T7 size_bytes[4] wrong",
           size_bytes[32*4 +: 32], sz_v);
    end

    // C2 CHARACTERISATION: r_nblk takes s_size[26:11], so a file at or above
    // 2^27 bytes (128 MiB) is silently mis-sized. The RTL says so at the
    // r_nblk assignment; this records the ACTUAL numbers so a future widening
    // of the slice/port shows up here as a deliberate change, not a surprise.
    mount_good(3'd4, 32'h0800_0000, 32'h0000_2000, 32'h0000_0004,
               8'd8, 32'h0000_0100, 1'b0, 1'b0);
    #1;
    nb = n_blocks[16*4 +: 16];
    chkv({16'd0, nb} === 32'd0,
         "C2 128 MiB image no longer truncates to 0 blocks", {16'd0, nb}, 0);
    chk(ceil_blocks(32'h0800_0000) !== {16'd0, nb},
        "C2 the 128 MiB truncation seems to have been fixed - update this tb");
    chkv(size_bytes[32*4 +: 32] === 32'h0800_0000,
         "C2 size_bytes is truncated too (it should not be)",
         size_bytes[32*4 +: 32], 32'h0800_0000);

    mount_good(3'd4, 32'h0800_1000, 32'h0000_3000, 32'h0000_0005,
               8'd8, 32'h0000_0100, 1'b0, 1'b0);
    #1;
    nb = n_blocks[16*4 +: 16];
    chkv({16'd0, nb} === 32'd2,
         "C2 (2^27 + 4096) no longer truncates to 2 blocks", {16'd0, nb}, 2);

    // ---- T8: the s_got_geom latch guard ----------------------------------
    mount_good(3'd2, 32'd4096, 32'h0000_9999, 32'h0000_0777,
               8'd16, 32'h0000_0400, 1'b0, 1'b1);   // perturb = 1
    #1;
    chk(open_ok[2] === 1'b1, "T8 open did not succeed");
    chkv(size_bytes[32*2 +: 32] === 32'd4096,
         "T8 a LATER found_size was published instead of the first",
         size_bytes[32*2 +: 32], 32'd4096);
    chkv(first_sector[32*2 +: 32] === 32'h0000_9999,
         "T8 a LATER found_first_sector was published",
         first_sector[32*2 +: 32], 32'h0000_9999);
    chkv(first_cluster[28*2 +: 28] === 28'h000_0777,
         "T8 a LATER found_cluster was published",
         {4'd0, first_cluster[28*2 +: 28]}, 32'h0000_0777);

    // ---- T9: re-open clears open_ok at the handshake ----------------------
    chk(open_ok[2] === 1'b1, "T9 precondition: client 2 should be open");
    rdr_idle;
    start_open(3'd2);
    #1;
    chk(open_ok[2] === 1'b0,
        "T9 a new open_req did not clear open_ok at the M_IDLE handshake");
    // let this one fail (no card) and confirm it stays closed
    wait_done(WD_MAX + 300);
    #1;
    chk(open_ok[2]  === 1'b0, "T9 open_ok[2] came back after a failed re-open");
    chk(open_err[2] === 1'b1, "T9 open_err[2] not set by the failed re-open");
    rdr_idle;
    @(negedge clk);

    // ---- T10: M_SCAN watchdog with the geometry already latched -----------
    base_st = st_upd_count;
    rdr_idle;
    start_open(3'd0);
    wait_rd_run(rd_run_cycles);
    repeat (3) @(negedge clk);
    card_stat = 4'd8;
    repeat (3) @(negedge clk);
    found_size         = 32'd12345;
    found_first_sector = 32'h0000_4444;
    found_cluster      = 32'h0000_0009;
    file_found         = 1'b1;             // matched...
    wait_done(WD_MAX + 300);               // ...but the scan never ends
    #1;
    chk(mnt_err    === 1'b1, "T10 stuck scan did not fail the open");
    chk(mnt_nocard === 1'b0, "T10 stuck scan wrongly reported NOCARD");
    chk(open_ok[0] === 1'b0, "T10 a stuck scan still opened the client");
    chkv(last_st_val == 2'd2, "T10 st_val is not ERROR(2)", last_st_val, 2);
    chk(rd_run === 1'b0, "T10 reader not parked after the stuck scan");
    chk(phase_write === 1'b1, "T10 pins not returned to the writer");
    rdr_idle;
    @(negedge clk);

`ifdef SDFAT_STORAGE_CHECK
    // ---- T11: the contiguity gate (this build only) ----------------------
    // payload at chk_start, then a NOT-OK verdict must fail the open
    chk_start_count = 0;
    chk_ok_next     = 1'b1;
    mount_good(3'd3, 32'd6000, 32'h0007_0000, 32'h0000_1234,
               8'd32, 32'h0000_0800, 1'b1, 1'b0);
    #1;
    chkv(chk_start_count == 1, "T11 chk_start did not pulse exactly once",
         chk_start_count, 1);
    chkv(cap_size === 32'd6000, "T11 chk_size wrong at chk_start",
         cap_size, 32'd6000);
    chkv(cap_fclu === 32'h0000_1234, "T11 chk_first_cluster wrong at chk_start",
         cap_fclu, 32'h0000_1234);
    chkv({24'd0, cap_csz} === 32'd32, "T11 chk_cluster_size wrong at chk_start",
         {24'd0, cap_csz}, 32'd32);
    chkv(cap_fat0 === 32'h0000_0800, "T11 chk_fat0_sector wrong at chk_start",
         cap_fat0, 32'h0000_0800);
    chk(cap_f32 === 1'b1, "T11 chk_is_fat32 wrong at chk_start");
    chk(open_ok[3] === 1'b1, "T11 chk_ok=1 did not open the client");
    chk(mnt_err    === 1'b0, "T11 chk_ok=1 reported an error");

    base_st     = st_upd_count;
    chk_ok_next = 1'b0;                    // fragmented file / FAT read error
    mount_good(3'd3, 32'd6000, 32'h0007_0000, 32'h0000_1234,
               8'd32, 32'h0000_0800, 1'b1, 1'b0);
    #1;
    chk(mnt_err     === 1'b1, "T11 chk_ok=0 did not fail the open");
    chk(open_ok[3]  === 1'b0, "T11 chk_ok=0 left the client open");
    chk(open_err[3] === 1'b1, "T11 chk_ok=0 did not set open_err");
    chk(mnt_nocard  === 1'b0, "T11 a check failure was reported as NOCARD");
    chkv(last_st_val == 2'd2, "T11 st_val is not ERROR(2)", last_st_val, 2);
    chk_ok_next = 1'b1;
`else
    // In this build M_CHK passes straight through: chk_start must NEVER fire.
    chkv(chk_start_count == 0,
         "chk_start pulsed in a build without SDFAT_STORAGE_CHECK",
         chk_start_count, 0);
`endif

    // ---- run-wide invariants ---------------------------------------------
    chk(load_fifo_ovf === 1'b0, "the preload FIFO overflow flag set");
    chkv(mem_start_count == 0,
         "the dead M_LOAD preload path issued a mem write", mem_start_count, 0);
    chk(mem_we === 1'b1, "C1 mem_we changed away from the hard-wired 1");
    chk(mnt_busy === 1'b0, "the FSM did not return to idle");
    chkv(mnt_done_count > 0, "no mount ever completed", mnt_done_count, 1);

    // ---- verdict ----------------------------------------------------------
    repeat (2) @(posedge clk);
    $display("checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire
