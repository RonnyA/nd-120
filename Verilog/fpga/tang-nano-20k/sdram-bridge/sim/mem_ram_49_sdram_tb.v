/****************************************************************************
** Testbench for MEM_RAM_49_SDRAM (ND-120 sheet-49 SDRAM backend)          **
**                                                                         **
** Replays the MEASURED ND-120 DRAM protocol (docs/nd120-dram-memory.md    **
** section 4) against the bridge + behavioral SDRAM model:                 **
**   N: RAS rise, row on AA   N+1: column   N+2: CAS rise (+write data)    **
**   read data sampled LATE in cycles N+4 and N+5 (hold check)             **
**   RAS falls N+5, CAS N+6, next access >= N+11                           **
**                                                                         **
** Checks: directed first/last-word per bank, unpopulated BANK1, parity    **
** round-trip (including deliberately wrong parity bits), 2000-access      **
** random soak against a mirror model, idle-watchdog refresh, refresh      **
** cadence (avg interval < 16 us).                                         **
**                                                                         **
** Compile modes (one source, four registry targets):                      **
**   (none)             legacy 18-bit word-per-location; stored parity     **
**                      round-trips, including deliberately BAD parity     **
**   -DND_SDRAM_PACK16  packed 16-bit mode: two ND words per location,     **
**                      DQM lane-masked writes. Pinned contract            **
**                      (docs/nd120-parity-analysis.md section 6):         **
**                      adjacent-word independence, computed parity on     **
**                      read (CORR_n always 1), bad-parity writes absorbed **
**   + -DTB_PART_ROWS=n reduced CPU partition: rows >= n report ABSENT     **
**                      (reads 0, writes dropped), like an empty bank      **
**   + -DND_STORAGE_PORT  nd_storage device port (32-bit locations at      **
**                      {1'b1, mem_addr}, granted only in the idle/tail    **
**                      slots): directed read/write, CPU-alias isolation   **
**                      (a device write can NEVER land in the CPU half),   **
**                      device traffic CONCURRENT with the CPU soak - the  **
**                      soak's late-N+4/N+5 sampling proves the measured   **
**                      CPU protocol timing is untouched - plus idle-slot  **
**                      service and a mirror-model integrity check         **
**                                                                         **
** Prints "TB_RESULT: PASS" on success.                                    **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module mem_ram_49_sdram_tb;

  localparam OSC_PERIOD = 37;  // ~27 MHz

  // CPU partition size in 1K-word rows ({bank, row}); 2048 = full 4 MB
`ifdef TB_PART_ROWS
  localparam TB_ROWS = `TB_PART_ROWS;
`else
  localparam TB_ROWS = 2048;
`endif

  // OSC and 2x clock, edge-aligned (posedge osc == every other posedge clk2x)
  reg clk2x = 1;
  always #(OSC_PERIOD / 4.0) clk2x = ~clk2x;
  reg osc = 1;
  always @(clk2x) if (clk2x) osc = ~osc;  // divide by 2, aligned on clk2x rises

  wire clk2x_sdram = ~clk2x;

  reg sys_rst_n = 0;

  // sheet-49 interface (OSC domain)
  reg [9:0] AA = 0;
  reg BANK0 = 0, BANK1 = 0, BANK2 = 0;
  reg RAS = 0, CAS = 0;
  reg MW_n = 1;
  reg [17:0] DD_IN = 0;
  wire [17:0] DD_OUT;
  wire CORR_n;

`ifdef ND_STORAGE_PORT
  // storage device port (stor_clk domain, deliberately NOT related to OSC
  // to stress the toggle CDC; on Tang it is the same-crystal 27 MHz)
  reg stor_clk = 0;
  always #20.5 stor_clk = ~stor_clk;  // ~24.4 MHz
  reg         stor_rst_n = 0;
  reg         mem_start = 0;
  reg         mem_we = 0;
  reg  [19:0] mem_addr = 0;
  reg  [31:0] mem_wdata = 0;
  wire [31:0] mem_rdata;
  wire        mem_busy, mem_done;
`endif

  // SDRAM pins
  wire sd_clk, sd_cke, sd_cs_n, sd_cas_n, sd_ras_n, sd_wen_n;
  wire [31:0] sd_dq;
  wire [10:0] sd_addr;
  wire [1:0] sd_ba;
  wire [3:0] sd_dqm;

  MEM_RAM_49_SDRAM #(
      .CLK2X_FREQ(54_000_000),
      .CPU_PART_ROWS(TB_ROWS)
  ) dut (
      .sysclk(osc),
      .sys_rst_n(sys_rst_n),
      .AA_9_0(AA),
      .BANK0(BANK0),
      .BANK1(BANK1),
      .BANK2(BANK2),
      .CAS(CAS),
      .RAS(RAS),
      .MWRITE50_n(MW_n),
      .DD_17_0_IN(DD_IN),
      .DD_17_0_OUT(DD_OUT),
      .CORR_n(CORR_n),

      .clk2x(clk2x),
      .clk2x_sdram(clk2x_sdram),

      .O_sdram_clk(sd_clk),
      .O_sdram_cke(sd_cke),
      .O_sdram_cs_n(sd_cs_n),
      .O_sdram_cas_n(sd_cas_n),
      .O_sdram_ras_n(sd_ras_n),
      .O_sdram_wen_n(sd_wen_n),
      .IO_sdram_dq(sd_dq),
      .O_sdram_addr(sd_addr),
      .O_sdram_ba(sd_ba),
      .O_sdram_dqm(sd_dqm)
`ifdef ND_STORAGE_PORT
      ,
      .stor_clk(stor_clk),
      .stor_rst_n(stor_rst_n),
      .mem_start(mem_start),
      .mem_we(mem_we),
      .mem_addr(mem_addr),
      .mem_wdata(mem_wdata),
      .mem_rdata(mem_rdata),
      .mem_busy(mem_busy),
      .mem_done(mem_done)
`endif
  );

  sdram_model u_model (
      .clk(sd_clk),
      .cke(sd_cke),
      .cs_n(sd_cs_n),
      .ras_n(sd_ras_n),
      .cas_n(sd_cas_n),
      .we_n(sd_wen_n),
      .a(sd_addr),
      .ba(sd_ba),
      .dqm(sd_dqm),
      .dq(sd_dq)
  );

  // ---- mirror model (the populated banks BANK0/BANK2 only) ----
  reg [17:0] mirror[0:2097151];
  reg        written[0:2097151];
  integer wi;
  initial for (wi = 0; wi < 2097152; wi = wi + 1) written[wi] = 0;

`ifdef ND_STORAGE_PORT
  // ---- device-region mirror (1M x 32-bit locations, upper chip half) ----
  reg [31:0] dev_mirror[0:1048575];
  reg        dev_written[0:1048575];
  integer dwi;
  initial for (dwi = 0; dwi < 1048576; dwi = dwi + 1) dev_written[dwi] = 0;
`endif

  // ---- refresh cadence monitor ----
  integer refresh_count = 0;
  realtime last_refresh = 0;
  realtime max_refresh_gap = 0;
  always @(posedge clk2x)
    if (dut.s_refresh) begin
      if (refresh_count > 0 && ($realtime - last_refresh) > max_refresh_gap)
        max_refresh_gap = $realtime - last_refresh;
      last_refresh  = $realtime;
      refresh_count = refresh_count + 1;
    end

  integer errors = 0;

  task check(input cond, input [127:0] what);
    if (!cond) begin
      errors = errors + 1;
      $display("FAIL at %0t: %0s", $time, what);
    end
  endtask

  // expected readback of a written 18-bit word
`ifdef ND_SDRAM_PACK16
  // packed mode: 16 data bits stored, parity REGENERATED as odd parity on
  // read - a deliberately-bad stored parity bit is absorbed
  function [17:0] exp_rd(input [17:0] w);
    exp_rd = {~(^w[16:9]), w[16:9], ~(^w[7:0]), w[7:0]};
  endfunction
`else
  // legacy 18-bit mode: all 18 bits (incl. bad parity) round-trip verbatim
  function [17:0] exp_rd(input [17:0] w);
    exp_rd = w;
  endfunction
`endif

  // BANK ORDER (MEM_RAM_49_SDRAM.v lines 375-384, commit 81462c0, 23-JUL-2026):
  // the board decode PAL PAL_44445B wires the three 1M-word banks in PHYSICAL
  // address order BANK0, BANK2, BANK1. The two POPULATED regions are therefore
  // BANK0 (phys 0-1M) and BANK2 (phys 1M-2M); BANK1 is the ABSENT third bank at
  // phys 2M-3M. This is the silicon-validated 4 MB fix - a tb that treats BANK1
  // as populated and BANK2 as absent is testing the pre-fix map.
  //   phys(bank) = the 1-bit physical bank index: BANK0 -> 0, BANK2 -> 1.
  function phys(input [1:0] bank);
    phys = (bank == 2'd2);
  endfunction

  // does this ND address belong to a populated bank AND the CPU partition?
  function present(input [1:0] bank, input [9:0] row);
    present = ((bank == 2'd0) || (bank == 2'd2)) &&
              ({1'b0, phys(bank), row} < TB_ROWS[11:0]);
  endfunction

  // ---- one access with the measured 6-cycle signature ----
  // bank: 0/1/2. For reads, samples DD_OUT/CORR_n late in N+4 AND N+5.
  task access(input [1:0] bank, input [9:0] row, input [9:0] col, input wn,
              input [17:0] wdata);
    reg [17:0] s4, s5, exp;
    reg c4, c5;
    reg [20:0] idx;
    begin
      idx = {phys(bank), row, col};
      @(posedge osc);  // N
      RAS   <= 1;
      AA    <= row;
      MW_n  <= wn;
      BANK0 <= (bank == 0);
      BANK1 <= (bank == 1);
      BANK2 <= (bank == 2);
      @(posedge osc);  // N+1
      AA <= col;
      @(posedge osc);  // N+2: CAS rises. On silicon the write data appears on
      CAS <= 1;        // DD only as a BRIEF mid-window pulse (the AM29833A
      if (!wn) begin   // transceiver drive window); hard zeros otherwise
        #10 DD_IN = wdata;   // pulse start, mid cycle N+2
        #18 DD_IN = 18'b0;   // pulse end (~18 ns, narrower than one clk2x)
      end
      @(posedge osc);  // N+3
      @(posedge osc);  // N+4
      #(OSC_PERIOD - 5);  // late in cycle N+4
      s4 = DD_OUT;
      c4 = CORR_n;
      @(posedge osc);  // N+5
      RAS <= 0;
      #(OSC_PERIOD - 5);  // late in cycle N+5 (CAS tail - hold check)
      s5 = DD_OUT;
      c5 = CORR_n;
      @(posedge osc);  // N+6
      CAS   <= 0;
      AA    <= 0;
      MW_n  <= 1;
      BANK0 <= 0;
      BANK1 <= 0;
      BANK2 <= 0;
      DD_IN <= 0;
      // enforce minimum RAS-to-RAS spacing of 11 (6 so far) + random jitter
      repeat (5 + ({$random} % 8)) @(posedge osc);

      if (wn) begin  // read: verify
        if (!present(bank, row)) begin
          check(s4 === 18'b0, "absent read not 0 (N+4)");
          check(c4 === 1'b1, "absent CORR_n not 1");
        end else if (written[idx]) begin
          exp = exp_rd(mirror[idx]);
          check(s4 === exp, "read data wrong (N+4)");
          check(s5 === exp, "read data not held (N+5)");
          check(c4 === ((^exp[8:0]) & (^exp[17:9])), "CORR_n wrong (N+4)");
          check(c5 === c4, "CORR_n not held (N+5)");
        end
      end else begin  // write: track mirror, DD_OUT must stay 0
        if (present(bank, row)) begin
          mirror[idx]  = wdata;
          written[idx] = 1;
        end
        check(s4 === 18'b0, "DD_OUT not 0 during write");
        check(c4 === 1'b1, "CORR_n not 1 during write");
      end
    end
  endtask

  task wr18(input [1:0] bank, input [9:0] row, input [9:0] col, input [17:0] d);
    access(bank, row, col, 1'b0, d);
  endtask
  task rd18(input [1:0] bank, input [9:0] row, input [9:0] col);
    access(bank, row, col, 1'b1, 18'b0);
  endtask

`ifdef ND_STORAGE_PORT
  // ---- one device-port op (mem-port contract of nd-storage-design 5.2):
  // pulse mem_start when not busy, wait for the mem_done pulse, verify reads
  // against the device mirror. Runs concurrently with the CPU access task.
  integer dev_ops_done = 0;
  task dev_op(input dwe, input [19:0] da, input [31:0] dwd);
    integer dwdg;
    begin
      @(posedge stor_clk);
      while (mem_busy) @(posedge stor_clk);
      mem_we    <= dwe;
      mem_addr  <= da;
      mem_wdata <= dwd;
      mem_start <= 1'b1;
      @(posedge stor_clk);
      mem_start <= 1'b0;
      dwdg = 0;
      while (mem_done !== 1'b1 && dwdg < 100000) begin
        @(posedge stor_clk);
        dwdg = dwdg + 1;
      end
      check(dwdg < 100000, "device op timeout");
      if (dwe) begin
        dev_mirror[da]  = dwd;
        dev_written[da] = 1;
      end else if (dev_written[da]) begin
        check(mem_rdata === dev_mirror[da], "device read data wrong");
      end
      dev_ops_done = dev_ops_done + 1;
    end
  endtask

  // random device traffic: mostly a small hot region (so reads hit written
  // locations), occasionally the top of the 1M-location device space
  task dev_rand_op;
    reg        rw;
    reg [19:0] ra;
    reg [31:0] rd32;
    begin
      if (({$random} % 10) == 0) ra = 20'hFFC00 + ({$random} % 1024);
      else ra = {$random} % 4096;
      rw   = ({$random} % 10) < 5;
      rd32 = $random;
      dev_op(rw, ra, rd32);
    end
  endtask
`endif

  integer i;
  reg [1:0] rb;
  reg [9:0] rrow, rcol;
  reg [17:0] rdat;
  realtime soak_start;

  // CPU-protocol random soak: every access re-checks the measured N+4 data
  // deadline and N+5 hold inside the access task
  task cpu_soak_run;
    begin
      for (i = 0; i < 2000; i = i + 1) begin
        rb   = (({$random} % 2) == 0) ? 2'd0 : 2'd2;  // populated banks only
        rrow = $random;
        rcol = $random;
        rdat = $random;
        if (({$random} % 10) < 4) wr18(rb, rrow, rcol, rdat);
        else rd18(rb, rrow, rcol);
      end
    end
  endtask

`ifdef ND_STORAGE_PORT
  reg soak_running = 0;
  reg [19:0] dpa;
  realtime idle_start;
`endif

  initial begin
    // reset + SDRAM init (200 us at 54 MHz)
    repeat (10) @(posedge osc);
    sys_rst_n = 1;
`ifdef ND_STORAGE_PORT
    stor_rst_n = 1;
`endif
    $display("TB: waiting for SDRAM init...");
    wait (dut.u_sdram.busy === 1'b0);
    repeat (4) @(posedge osc);
    $display("TB: init done at %0t", $time);

    // ---- directed: first/last word of each populated bank ----
    wr18(0, 10'h000, 10'h000, 18'h00001);
    wr18(0, 10'h3FF, 10'h3FF, 18'h2AAAA);
    wr18(2, 10'h000, 10'h000, 18'h15555);
    wr18(2, 10'h3FF, 10'h3FF, 18'h3FFFE);
    rd18(0, 10'h000, 10'h000);
    rd18(0, 10'h3FF, 10'h3FF);
    rd18(2, 10'h000, 10'h000);
    rd18(2, 10'h3FF, 10'h3FF);

    // ---- unpopulated BANK1: write is dropped, read returns 0 ----
    access(1, 10'h012, 10'h034, 1'b0, 18'h12345);
    rd18(1, 10'h012, 10'h034);

    // ---- parity round-trip: even and (deliberately) odd parity words ----
    // legacy mode: stored parity (incl. BAD parity) round-trips verbatim;
    // pack16 mode: parity is recomputed on read, bad parity is absorbed
    // (exp_rd encodes the mode's contract - nd120-parity-analysis.md sec. 6)
    wr18(0, 10'h010, 10'h001, 18'b000000000_000000011);  // BAD low parity (correct = 1)
    wr18(0, 10'h010, 10'h002, 18'b000000001_000000001);  // good parity halves
    rd18(0, 10'h010, 10'h001);
    rd18(0, 10'h010, 10'h002);

`ifdef ND_SDRAM_PACK16
    // ---- pack16: adjacent ND words (even/odd col) share one location ----
    // lane-mask contract: writing one half must NEVER disturb the other
    $display("TB: pack16 adjacent-word independence...");
    wr18(0, 10'h020, 10'h000, 18'h3FFFF);  // even half: all-ones data
    wr18(0, 10'h020, 10'h001, 18'h00000);  // odd half: all-zeros data
    rd18(0, 10'h020, 10'h000);             // even survived the odd write
    rd18(0, 10'h020, 10'h001);
    wr18(0, 10'h020, 10'h000, 18'h00000);  // overwrite even with zeros
    rd18(0, 10'h020, 10'h001);             // odd untouched
    rd18(0, 10'h020, 10'h000);
    wr18(0, 10'h020, 10'h3FF, 18'h15555);  // odd half first this time
    wr18(0, 10'h020, 10'h3FE, 18'h2AAAA);
    rd18(0, 10'h020, 10'h3FF);
    rd18(0, 10'h020, 10'h3FE);
    // read-after-write of the SAME location's other half (stale-DQM check:
    // the write's lane mask must not blank the following read's data window)
    wr18(2, 10'h021, 10'h004, 18'h12345);
    rd18(2, 10'h021, 10'h005);
    rd18(2, 10'h021, 10'h004);

    // ---- partition boundary (reduced-CPU builds): last CPU row present,
    // first storage-reserved row absent (write dropped, reads 0) ----
    if (TB_ROWS < 2048) begin
      $display("TB: pack16 partition boundary at row %0d...", TB_ROWS);
      // physical row index -> ND bank name: phys 0 = BANK0, phys 1 = BANK2
      rb   = (((TB_ROWS - 1) / 1024) == 0) ? 2'd0 : 2'd2;
      rrow = (TB_ROWS - 1) % 1024;
      wr18(rb, rrow, 10'h005, 18'h12345);
      rd18(rb, rrow, 10'h005);
      rb   = ((TB_ROWS / 1024) == 0) ? 2'd0 : 2'd2;
      rrow = TB_ROWS % 1024;
      wr18(rb, rrow, 10'h005, 18'h0AAAA);
      rd18(rb, rrow, 10'h005);
    end
`endif

`ifdef ND_STORAGE_PORT
    // ---- device port, directed: first/last location of the storage region ----
    $display("TB: device port directed read/write...");
    dev_op(1, 20'h00000, 32'h1122_3344);
    dev_op(1, 20'hFFFFF, 32'hA5C3_961E);
    dev_op(0, 20'h00000, 32'h0);
    dev_op(0, 20'hFFFFF, 32'h0);

    // ---- device/CPU isolation: the forced address MSB means device address
    // D lands at location {1,D} (storage half) - it can NEVER reach the CPU
    // alias {0,D} = ND half-words {D,0}/{D,1}. Write the CPU words that WOULD
    // be clobbered if the partition were not enforced, "attempt" the device
    // write on the same 20-bit address, and prove both sides intact.
    $display("TB: device port CPU-partition isolation...");
    dpa = 20'h00123;  // CPU alias {dpa,x} = bank 0, row 0, cols 0x246/0x247
    wr18(0, 10'h000, 10'h246, 18'h12345);
    wr18(0, 10'h000, 10'h247, 18'h0F0F0);
    dev_op(1, dpa, 32'hCAFE_BABE);  // the below-partition write attempt
    rd18(0, 10'h000, 10'h246);      // CPU words untouched (mirror-checked)
    rd18(0, 10'h000, 10'h247);
    dev_op(0, dpa, 32'h0);          // device sees ITS data in the storage half
`endif

    // ---- random soak ----
`ifdef ND_STORAGE_PORT
    // device traffic runs CONCURRENTLY with the CPU protocol replay: every
    // CPU access still checks the N+4 deadline / N+5 hold, proving device
    // arbitration (B_POST/B_TAIL slots here - the idle watchdog guard never
    // opens during the soak) does not shift CPU-observable timing
    $display("TB: random soak (2000 accesses) + concurrent device traffic...");
    soak_start   = $realtime;
    soak_running = 1;
    fork
      begin
        cpu_soak_run;
        soak_running = 0;
      end
      begin
        while (soak_running) dev_rand_op;
      end
    join
    $display("TB: device ops completed so far: %0d", dev_ops_done);
    check(dev_ops_done >= 100, "device port starved during CPU soak");
`else
    $display("TB: random soak (2000 accesses)...");
    soak_start = $realtime;
    cpu_soak_run;
`endif

    // ---- idle stretch: watchdog refresh must keep firing ----
`ifdef ND_STORAGE_PORT
    // device ops during the idle stretch exercise the B_IDLE grant slot
    // (behind the idle_cnt watchdog guard); refresh keeps priority
    $display("TB: idle stretch 200 us + idle-slot device ops...");
    idle_start = $realtime;
    repeat (100) dev_rand_op;
    while (($realtime - idle_start) < 200_000) #1000;
`else
    $display("TB: idle stretch 200 us...");
    #200_000;
`endif
    rd18(0, 10'h000, 10'h000);   // still correct after idle
    rd18(2, 10'h3FF, 10'h3FF);

    // ---- refresh cadence ----
    $display("TB: %0d refreshes, max gap %0t ns", refresh_count, max_refresh_gap);
    check(refresh_count > 50, "too few refreshes");
    check(max_refresh_gap < 20_000, "refresh gap exceeded 20 us");

`ifdef ND_STORAGE_PORT
    $display("TB: %0d device ops total", dev_ops_done);
    check(dev_ops_done >= 200, "too few device ops completed");
`endif

    // ---- 4 MB ADDRESS-SPACE BIT WALK (24-AUG-2026, after the Nexys
    // BLOCKRAM ADDR_BITS=15 truncation broke FILSYS on silicon): a unique
    // tag at physical word 0 and at every power-of-two word index across
    // the FULL 2M-word (4 MB) space - idx = {physbank, row[9:0], col[9:0]},
    // physbank 0 = BANK0, 1 = BANK2 (the silicon-validated map above).
    // Any dropped, swapped, or truncated address bit in the bridge or the
    // SDRAM model aliases at least one pair and fails loudly. Random soaks
    // can miss a single dead bit; this walk cannot. Only walks rows below
    // TB_ROWS when a reduced CPU partition is built (test-pack16-part).
    $display("TB: 4 MB address-space bit walk...");
    begin : space_walk
      integer wb;
      reg [20:0] widx;
      reg [1:0]  wbank;
      wr18(0, 10'd0, 10'd0, 18'o000700);
      for (wb = 0; wb < 21; wb = wb + 1) begin
        widx  = 21'd1 << wb;
        wbank = widx[20] ? 2'd2 : 2'd0;
        if (present(wbank, widx[19:10]))
          wr18(wbank, widx[19:10], widx[9:0], 18'o000100 + wb[17:0]);
      end
      rd18(0, 10'd0, 10'd0);
      for (wb = 0; wb < 21; wb = wb + 1) begin
        widx  = 21'd1 << wb;
        wbank = widx[20] ? 2'd2 : 2'd0;
        if (present(wbank, widx[19:10]))
          rd18(wbank, widx[19:10], widx[9:0]);
      end
      // top-of-space distinctness: the last word of each populated bank
      if (present(0, 10'h3FF)) begin
        wr18(0, 10'h3FF, 10'h3FF, 18'o000711);
        rd18(0, 10'h3FF, 10'h3FF);
      end
      if (present(2, 10'h3FF)) begin
        wr18(2, 10'h3FF, 10'h3FF, 18'o000722);
        rd18(2, 10'h3FF, 10'h3FF);
      end
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  // watchdog
  initial begin
    #20_000_000;  // 20 ms
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule
