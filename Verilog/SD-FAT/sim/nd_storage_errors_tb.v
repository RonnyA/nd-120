/****************************************************************************
** ERROR-CODE testbench for the SD-FAT storage stack (iverilog)            **
**                                                                         **
** Every other testbench in this tree proves the stack WORKS. This one     **
** proves it FAILS HONESTLY: that each way a storage operation can go      **
** wrong produces a completion (never a wedge), with err=1 (never a silent **
** success), carrying the RIGHT reason code from                           **
** Verilog/SD-FAT/circuit/nd_storage_status.vh.                            **
**                                                                         **
** WHY IT EXISTS: until 09-AUG-2026 every failure in this stack arrived at **
** the guest as one anonymous bit, and one failure - a block request for a **
** client that never mounted - was not reported at all: no busy, no done,  **
** so a controller waited forever for a completion that could never come.  **
** Both are checked here by name.                                          **
**                                                                         **
** THE FAULTS ARE REAL, NOT SIMULATED SIGNALS. Nothing here drives an      **
** error input by hand; each case creates the actual physical condition    **
** and lets the stack discover it:                                         **
**                                                                         **
**   NO SD CARD          DUT B runs with NO card model instantiated at     **
**                       all - CMD and DAT sit at the bus pullup exactly   **
**                       as with an empty slot.                            **
**   FILE NOT ON CARD    client 2 asks for FLOPPY2.IMG, which              **
**                       make_storage_image.sh deliberately never writes   **
**                       to nds_storage.img.                               **
**   NEVER OPENED        a block request for a client whose open was never **
**                       issued at all (the silent-drop regression).       **
**   PAST END OF IMAGE   block 2 of a 4096-byte (2-block) file.            **
**   CARD STOPS ANSWERING  the card model is told to answer the next read  **
**                       command and then send nothing (fail_next_reads).  **
**   CORRUPT FILESYSTEM  nds_badfat.img, whose BADFAT.IMG has a FAT chain  **
**                       cut at hop 2 by make_storage_image.sh.            **
**   NO PROGRESS         the mem port is frozen mid-operation so the       **
**                       engine watchdog is the only thing that can end    **
**                       the request.                                      **
**                                                                         **
** EVERY case is run BOTH DIRECTIONS - read and write - wherever the       **
** stack accepts both, because a write that reports success while the data **
** never left is worse than a read that returns zeros.                     **
**                                                                         **
** Each case also asserts the CONTROL: that the same stack, same instant,  **
** still completes a good request with err=0 and NDS_ERR_NONE. A bench     **
** where everything fails proves nothing.                                  **
**                                                                         **
** FOUR nd_storage INSTANCES, each clock-gated until its own phase so an  **
** instance costs nothing before it is used:                               **
**   dutA  good card, nds_storage.img   - cases 1-4                        **
**   dutB  NO card model at all         - case 5                           **
**   dutC  good card, frozen mem port   - case 6                           **
**   dutF  good card, nds_badfat.img    - case 7                           **
**                                                                         **
** A NOTE ON THE FAT-CHAIN CASE: the mount-time contiguity gate            **
** (SDFAT_STORAGE_CHECK) is OFF by default - it was retired 07-AUG-2026    **
** because the engine walks the chain per request anyway - so the broken   **
** file OPENS fine here and the failure lands where it belongs, in         **
** nd_storage_engine.v's own FAT walk. Nothing is stripped to make this    **
** work. (A build that forces the gate back on with                        **
** -DSDFAT_FORCE_STORAGE_CHECK would fail the open instead, which is also  **
** correct and is what nd_storage_fatchk_tb.v covers.)                     **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Ronny Hansen, 09-AUG-2026                                               **
*****************************************************************************/
`timescale 1ns / 1ps
`include "nd_storage_status.vh"

module nd_storage_errors_tb;

  localparam STOR_HALF = 18.5;  // ~27.03 MHz
  localparam CPU_HALF  = 21.7;  // ~23.04 MHz
  localparam N         = 8;

  localparam integer FLP_BYTES   = 4096;          // FLOPPY1.IMG: exactly 2 blocks
  localparam IMG_BYTES   = 4 * 1024 * 1024;
  localparam IMG_SECTORS = IMG_BYTES / 512;

  reg clk_stor = 0;
  always #STOR_HALF clk_stor = ~clk_stor;
  reg clk_cpu = 0;
  always #CPU_HALF clk_cpu = ~clk_cpu;

  reg rst_n = 0;

  integer fails = 0;
  integer cases = 0;

  task fail(input [1023:0] why);
    begin
      fails = fails + 1;
      $display("TB_RESULT: FAIL %0s", why);
    end
  endtask

  // human-readable reason code, so a failure message says what went wrong
  function [95:0] codename(input [3:0] c);
    case (c)
      `NDS_ERR_NONE:     codename = "NONE    ";
      `NDS_ERR_NOCARD:   codename = "NOCARD  ";
      `NDS_ERR_CARDIO:   codename = "CARDIO  ";
      `NDS_ERR_NOTOPEN:  codename = "NOTOPEN ";
      `NDS_ERR_RANGE:    codename = "RANGE   ";
      `NDS_ERR_FATCHAIN: codename = "FATCHAIN";
      `NDS_ERR_TIMEOUT:  codename = "TIMEOUT ";
      `NDS_ERR_WRPROT:   codename = "WRPROT  ";
      `NDS_ERR_WRALIGN:  codename = "WRALIGN ";
      default:           codename = "????????";
    endcase
  endfunction


  // ------------------------------------------------------------- DUT A
  // Good card, real image. Everything except "no card" and the watchdog.
  wire        sdA_clk, sdA_cmd_o, sdA_cmd_oe, sdA_dat0_o, sdA_dat0_oe;
  wire        cA_cmd_o, cA_cmd_oe, cA_dat0_o, cA_dat0_oe;
  wire        sdA_cmd  = sdA_cmd_oe  ? sdA_cmd_o  : (cA_cmd_oe  ? cA_cmd_o  : 1'b1);
  wire        sdA_dat0 = sdA_dat0_oe ? sdA_dat0_o : (cA_dat0_oe ? cA_dat0_o : 1'b1);

  wire        memA_start, memA_we, memA_busy, memA_done;
  wire [19:0] memA_addr;
  wire [31:0] memA_wdata, memA_rdata;

  reg  [N-1:0]    a_open_req = 0;
  reg  [N-1:0]    a_req = 0;
  reg  [N-1:0]    a_wr = 0;
  reg  [N*16-1:0] a_block = 0;
  wire [N-1:0]    a_open_ok, a_open_err, a_busy, a_done, a_err, a_buf_we;
  wire [N*4-1:0]  a_err_code;
  wire [N*32-1:0] a_size_bytes;
  wire [N*10-1:0] a_buf_addr;
  wire [N*16-1:0] a_buf_wdata;

  nd_storage #(
      .N_CLIENTS (N),
      .RD_CLK_DIV(3'd1),
      .WR_CLKDIV (8'd2),
      .WD_MAX    (32'd5_000_000),
      .SIMULATE  (1)
  ) dutA (
      .clk_stor  (clk_stor),   .rst_stor_n(rst_n),
      .clk_cpu   (clk_cpu),    .rst_cpu_n (rst_n),
      .sd_clk_o  (sdA_clk),
      .sd_cmd_i  (sdA_cmd),    .sd_cmd_o  (sdA_cmd_o),  .sd_cmd_oe (sdA_cmd_oe),
      .sd_dat0_i (sdA_dat0),   .sd_dat0_o (sdA_dat0_o), .sd_dat0_oe(sdA_dat0_oe),
      .mem_start (memA_start),  .mem_we   (memA_we),
      .mem_addr  (memA_addr),   .mem_wdata(memA_wdata), .mem_rdata(memA_rdata),
      .mem_busy  (memA_busy),   .mem_done (memA_done),
      .open_req  (a_open_req),  .open_ok  (a_open_ok),  .open_err (a_open_err),
      .size_bytes(a_size_bytes),
      .req       (a_req),       .wr       (a_wr),       .block    (a_block),
      .busy      (a_busy),      .done     (a_done),     .err      (a_err),
      .err_code  (a_err_code),
      .buf_addr  (a_buf_addr),  .buf_wdata(a_buf_wdata), .buf_we  (a_buf_we),
      .buf_rdata ({N{16'd0}}),
      .sd_status (), .card_type (), .fs_type ()
  );

  nds_mem_model #(.MEM_WORDS(32768)) u_memA (
      .clk  (clk_stor), .rst_n(rst_n),
      .start(memA_start), .we(memA_we), .addr(memA_addr),
      .wdata(memA_wdata), .rdata(memA_rdata),
      .busy (memA_busy),  .done (memA_done)
  );

  sd_card_model #(
      .IMAGE           ("nds_storage.img"),
      .MAX_BYTES       (IMG_BYTES),
      .LEGAL_MIN_SECTOR(IMG_SECTORS)   // any card write at all is illegal here
  ) cardA (
      .sd_clk   (sdA_clk),
      .sd_cmd_i (sdA_cmd),  .sd_cmd_o (cA_cmd_o),  .sd_cmd_oe (cA_cmd_oe),
      .sd_dat0_i(sdA_dat0), .sd_dat0_o(cA_dat0_o), .sd_dat0_oe(cA_dat0_oe),
      .sd_dat1_i(1'b1), .sd_dat1_o(), .sd_dat1_oe(),
      .sd_dat2_i(1'b1), .sd_dat2_o(), .sd_dat2_oe(),
      .sd_dat3_i(1'b1), .sd_dat3_o(), .sd_dat3_oe()
  );

  // ------------------------------------------------------------- DUT B
  // NO CARD MODEL AT ALL: an empty slot. CMD/DAT idle at the bus pullup.
  // Clock-gated until its phase so it costs nothing before that.
  reg  dutB_en = 0;
  reg  rstB_n  = 0;
  wire clk_storB = clk_stor & dutB_en;
  wire clk_cpuB  = clk_cpu  & dutB_en;

  wire        sdB_clk, sdB_cmd_o, sdB_cmd_oe, sdB_dat0_o, sdB_dat0_oe;
  wire        sdB_cmd  = sdB_cmd_oe  ? sdB_cmd_o  : 1'b1;   // pullup only
  wire        sdB_dat0 = sdB_dat0_oe ? sdB_dat0_o : 1'b1;

  wire        memB_start, memB_we, memB_busy, memB_done;
  wire [19:0] memB_addr;
  wire [31:0] memB_wdata, memB_rdata;

  reg  [N-1:0]    b_open_req = 0;
  reg  [N-1:0]    b_req = 0;
  reg  [N-1:0]    b_wr = 0;
  wire [N-1:0]    b_open_ok, b_open_err, b_busy, b_done, b_err;
  wire [N*4-1:0]  b_err_code;

  // WD_MAX is deliberately SMALL here. With no card, nd_storage_mount.v's
  // M_CARD state has nothing to wait for but its own watchdog, so WD_MAX is
  // literally the cost of this case: at 5,000,000 it was 185 ms of simulated
  // time, 48% of this whole bench, for one verdict. Shrinking it does NOT
  // weaken the case - the card never initialises whatever the budget, and
  // the verdict comes from s_nocard <= !scan_done, not from the timer's
  // value. 300,000 is comfortably above a SUCCESSFUL mount: dutC below
  // mounts FLOPPY1.IMG with only 200,000.
  nd_storage #(
      .N_CLIENTS (N),
      .RD_CLK_DIV(3'd1),
      .WR_CLKDIV (8'd2),
      .WD_MAX    (32'd300_000),
      .SIMULATE  (1)
  ) dutB (
      .clk_stor  (clk_storB),  .rst_stor_n(rstB_n),
      .clk_cpu   (clk_cpuB),   .rst_cpu_n (rstB_n),
      .sd_clk_o  (sdB_clk),
      .sd_cmd_i  (sdB_cmd),    .sd_cmd_o  (sdB_cmd_o),  .sd_cmd_oe (sdB_cmd_oe),
      .sd_dat0_i (sdB_dat0),   .sd_dat0_o (sdB_dat0_o), .sd_dat0_oe(sdB_dat0_oe),
      .mem_start (memB_start),  .mem_we   (memB_we),
      .mem_addr  (memB_addr),   .mem_wdata(memB_wdata), .mem_rdata(memB_rdata),
      .mem_busy  (memB_busy),   .mem_done (memB_done),
      .open_req  (b_open_req),  .open_ok  (b_open_ok),  .open_err (b_open_err),
      .size_bytes(),
      .req       (b_req),       .wr       (b_wr),       .block    ({N{16'd0}}),
      .busy      (b_busy),      .done     (b_done),     .err      (b_err),
      .err_code  (b_err_code),
      .buf_addr  (), .buf_wdata(), .buf_we(), .buf_rdata({N{16'd0}}),
      .sd_status (), .card_type (), .fs_type ()
  );

  nds_mem_model #(.MEM_WORDS(64)) u_memB (
      .clk  (clk_storB), .rst_n(rstB_n),
      .start(memB_start), .we(memB_we), .addr(memB_addr),
      .wdata(memB_wdata), .rdata(memB_rdata),
      .busy (memB_busy),  .done (memB_done)
  );

  // ------------------------------------------------------------- DUT C
  // Watchdog case: a good card, but the MEM PORT is frozen once armed, so
  // nothing can finish the operation except the engine's own watchdog.
  // WD_MAX is small here (and only here) so the timeout costs little time.
  reg  dutC_en   = 0;
  reg  rstC_n    = 0;
  reg  memC_hang = 0;      // 1 = swallow mem transactions, never answer
  wire clk_storC = clk_stor & dutC_en;
  wire clk_cpuC  = clk_cpu  & dutC_en;

  wire        sdC_clk, sdC_cmd_o, sdC_cmd_oe, sdC_dat0_o, sdC_dat0_oe;
  wire        cC_cmd_o, cC_cmd_oe, cC_dat0_o, cC_dat0_oe;
  wire        sdC_cmd  = sdC_cmd_oe  ? sdC_cmd_o  : (cC_cmd_oe  ? cC_cmd_o  : 1'b1);
  wire        sdC_dat0 = sdC_dat0_oe ? sdC_dat0_o : (cC_dat0_oe ? cC_dat0_o : 1'b1);

  wire        memC_start, memC_we, memC_busy_m, memC_done_m;
  wire [19:0] memC_addr;
  wire [31:0] memC_wdata, memC_rdata;
  // frozen: the port neither accepts nor completes anything
  wire        memC_busy = memC_hang ? 1'b1 : memC_busy_m;
  wire        memC_done = memC_hang ? 1'b0 : memC_done_m;

  reg  [N-1:0]    c_open_req = 0;
  reg  [N-1:0]    c_req = 0;
  reg  [N-1:0]    c_wr = 0;
  reg  [N*16-1:0] c_block = 0;
  wire [N-1:0]    c_open_ok, c_open_err, c_busy, c_done, c_err;
  wire [N*4-1:0]  c_err_code;

  nd_storage #(
      .N_CLIENTS (N),
      .RD_CLK_DIV(3'd1),
      .WR_CLKDIV (8'd2),
      .WD_MAX    (32'd200_000),   // small: this DUT exists to hit it
      .SIMULATE  (1)
  ) dutC (
      .clk_stor  (clk_storC),  .rst_stor_n(rstC_n),
      .clk_cpu   (clk_cpuC),   .rst_cpu_n (rstC_n),
      .sd_clk_o  (sdC_clk),
      .sd_cmd_i  (sdC_cmd),    .sd_cmd_o  (sdC_cmd_o),  .sd_cmd_oe (sdC_cmd_oe),
      .sd_dat0_i (sdC_dat0),   .sd_dat0_o (sdC_dat0_o), .sd_dat0_oe(sdC_dat0_oe),
      .mem_start (memC_start),  .mem_we   (memC_we),
      .mem_addr  (memC_addr),   .mem_wdata(memC_wdata), .mem_rdata(memC_rdata),
      .mem_busy  (memC_busy),   .mem_done (memC_done),
      .open_req  (c_open_req),  .open_ok  (c_open_ok),  .open_err (c_open_err),
      .size_bytes(),
      .req       (c_req),       .wr       (c_wr),       .block    (c_block),
      .busy      (c_busy),      .done     (c_done),     .err      (c_err),
      .err_code  (c_err_code),
      .buf_addr  (), .buf_wdata(), .buf_we(), .buf_rdata({N{16'd0}}),
      .sd_status (), .card_type (), .fs_type ()
  );

  nds_mem_model #(.MEM_WORDS(32768)) u_memC (
      .clk  (clk_storC), .rst_n(rstC_n),
      .start(memC_start & ~memC_hang), .we(memC_we), .addr(memC_addr),
      .wdata(memC_wdata), .rdata(memC_rdata),
      .busy (memC_busy_m), .done(memC_done_m)
  );

  sd_card_model #(
      .IMAGE    ("nds_storage.img"),
      .MAX_BYTES(IMG_BYTES)
  ) cardC (
      .sd_clk   (sdC_clk),
      .sd_cmd_i (sdC_cmd),  .sd_cmd_o (cC_cmd_o),  .sd_cmd_oe (cC_cmd_oe),
      .sd_dat0_i(sdC_dat0), .sd_dat0_o(cC_dat0_o), .sd_dat0_oe(cC_dat0_oe),
      .sd_dat1_i(1'b1), .sd_dat1_o(), .sd_dat1_oe(),
      .sd_dat2_i(1'b1), .sd_dat2_o(), .sd_dat2_oe(),
      .sd_dat3_i(1'b1), .sd_dat3_o(), .sd_dat3_oe()
  );

  // ------------------------------------------------------------- helpers
  // One block request on DUT A, waited to completion. NEVER-COMPLETING is
  // itself a failure here (that is the silent-drop bug), so the wait is
  // bounded and reports what it saw.
  task a_request(input integer cl, input [15:0] blk, input wr_op,
                 input [1023:0] label,
                 input want_err, input [3:0] want_code);
    integer guard;
    begin
      cases = cases + 1;
      @(posedge clk_cpu);
      a_block[cl*16 +: 16] <= blk;
      a_wr[cl]  <= wr_op;
      a_req[cl] <= 1'b1;
      @(posedge clk_cpu);
      a_req[cl] <= 1'b0;
      guard = 0;
      while (!a_done[cl] && guard < 4_000_000) begin
        @(posedge clk_cpu);
        guard = guard + 1;
      end
      if (!a_done[cl]) begin
        fail({label, " NEVER COMPLETED - the silent-drop failure"});
      end else if (a_err[cl] !== want_err) begin
        fail({label, " wrong err bit"});
        $display("       want err=%b got err=%b code=%0s",
                 want_err, a_err[cl], codename(a_err_code[cl*4 +: 4]));
      end else if (a_err_code[cl*4 +: 4] !== want_code) begin
        fail({label, " wrong reason code"});
        $display("       want %0s got %0s",
                 codename(want_code), codename(a_err_code[cl*4 +: 4]));
      end else begin
        $display("  ok   %0s -> err=%b %0s",
                 label, a_err[cl], codename(a_err_code[cl*4 +: 4]));
      end
      a_wr[cl] <= 1'b0;
    end
  endtask

  task b_request(input integer cl, input wr_op, input [1023:0] label,
                 input [3:0] want_code);
    integer guard;
    begin
      cases = cases + 1;
      @(posedge clk_cpuB);
      b_wr[cl]  <= wr_op;
      b_req[cl] <= 1'b1;
      @(posedge clk_cpuB);
      b_req[cl] <= 1'b0;
      guard = 0;
      while (!b_done[cl] && guard < 4_000_000) begin
        @(posedge clk_cpuB);
        guard = guard + 1;
      end
      if (!b_done[cl]) fail({label, " NEVER COMPLETED (no done pulse)"});
      else if (!b_err[cl]) fail({label, " reported SUCCESS with no card"});
      else if (b_err_code[cl*4 +: 4] !== want_code) begin
        fail({label, " wrong reason code"});
        $display("       want %0s got %0s",
                 codename(want_code), codename(b_err_code[cl*4 +: 4]));
      end else
        $display("  ok   %0s -> err=1 %0s",
                 label, codename(b_err_code[cl*4 +: 4]));
      b_wr[cl] <= 1'b0;
    end
  endtask

  task a_open(input integer cl);
    integer guard;
    begin
      @(posedge clk_cpu);
      a_open_req[cl] <= 1'b1;
      @(posedge clk_cpu);
      a_open_req[cl] <= 1'b0;
      guard = 0;
      while (!a_open_ok[cl] && !a_open_err[cl] && guard < 4_000_000) begin
        @(posedge clk_cpu);
        guard = guard + 1;
      end
      // SETTLE. open_ok/open_err rise BEFORE the open's own done pulse and
      // before r_busy falls, and a req while busy is ignored by contract -
      // so issuing straight after open_ok would drop the request and then
      // catch the OPEN's completion instead, reading as a spurious success.
      // Wait for the port to go idle, then a couple more cycles for the
      // size latch.
      guard = 0;
      while (a_busy[cl] && guard < 100_000) begin
        @(posedge clk_cpu);
        guard = guard + 1;
      end
      repeat (8) @(posedge clk_cpu);
    end
  endtask

  // ------------------------------------------------------------- sequence
  integer guard;
  initial begin
    $display("=== SD-FAT storage stack: error reporting ===");
    rst_n = 0;
    repeat (20) @(posedge clk_stor);
    rst_n = 1;

    // ---- CASE 0: the CONTROL. A good open and a good read must still
    // succeed with err=0 and NDS_ERR_NONE, or nothing below means anything.
    a_open(1);
    if (!a_open_ok[1]) begin
      fail("control: FLOPPY1.IMG did not open - the rest proves nothing");
      $display("TB_RESULT: FAIL control open");
      $finish;
    end
    if (a_size_bytes[1*32 +: 32] !== FLP_BYTES) begin
      fail("control: FLOPPY1.IMG size is wrong");
      $display("       want %0d got %0d", FLP_BYTES, a_size_bytes[1*32 +: 32]);
    end
    a_request(1, 16'd0, 1'b0, "control  read  blk 0 (good file)",
              1'b0, `NDS_ERR_NONE);

    // ---- CASE 1: a block request for a client that was NEVER OPENED.
    // Before 09-AUG-2026 the engine dropped this on the floor: no busy,
    // no done, and the controller waited forever. It must COMPLETE.
    a_request(5, 16'd0, 1'b0, "never opened   read  (client 5)",
              1'b1, `NDS_ERR_NOTOPEN);
    a_request(5, 16'd0, 1'b1, "never opened   write (client 5)",
              1'b1, `NDS_ERR_NOTOPEN);

    // ---- CASE 2: the file is NOT ON THE CARD. FLOPPY2.IMG (client 2) is
    // deliberately absent from nds_storage.img.
    a_open(2);
    if (a_open_ok[2]) fail("FLOPPY2.IMG is absent but reported open_ok");
    if (!a_open_err[2]) fail("FLOPPY2.IMG absent but no open_err");
    a_request(2, 16'd0, 1'b0, "missing file   read  (FLOPPY2.IMG)",
              1'b1, `NDS_ERR_NOTOPEN);
    a_request(2, 16'd0, 1'b1, "missing file   write (FLOPPY2.IMG)",
              1'b1, `NDS_ERR_NOTOPEN);

    // ---- CASE 3: PAST THE END of the image. FLOPPY1.IMG is 4096 bytes =
    // blocks 0 and 1 only.
    a_request(1, 16'd2, 1'b0, "out of range   read  blk 2 of 2",
              1'b1, `NDS_ERR_RANGE);
    a_request(1, 16'd2, 1'b1, "out of range   write blk 2 of 2",
              1'b1, `NDS_ERR_RANGE);

    // control again: the stack is still healthy after those refusals
    a_request(1, 16'd1, 1'b0, "control  read  blk 1 (after refusals)",
              1'b0, `NDS_ERR_NONE);

    // ---- CASE 4: the CARD STOPS ANSWERING mid-operation. The model
    // answers the read command and then sends nothing at all; only the
    // host's read watchdog can end this.
    //
    // SLOW BUILD ONLY (-DNDS_ERR_TB_SLOW, target test-nds-errors-slow).
    // That watchdog is sd_writer.v's TO_DATA = 2,000,000 sdclk, which at
    // this bench's 13.5 MHz sdclk is 148 ms of simulated time - measured
    // 09-AUG-2026 as 40% of the entire run for this ONE case. TO_DATA is a
    // real device timeout, not a test knob, so it is not shortened to suit
    // a testbench; the case moves to the heavy tier instead. Everything
    // else here stays in the fail-fast tier, where it runs every day.
`ifdef NDS_ERR_TB_SLOW
    cardA.fail_next_reads = 32'd1;
    a_request(1, 16'd0, 1'b0, "card silent    read  blk 0",
              1'b1, `NDS_ERR_CARDIO);
    cardA.fail_next_reads = 32'd0;

    // and it must RECOVER: a fault is not allowed to poison the client
    a_request(1, 16'd1, 1'b0, "control  read  blk 1 (after card fault)",
              1'b0, `NDS_ERR_NONE);
`else
    $display("  skip card silent    read  blk 0 (slow tier: test-nds-errors-slow)");
`endif

    // ---- CASE 5: NO SD CARD IN THE SLOT (DUT B, no card model at all).
    $display("  -- no-card DUT: card init must fail, not hang -- (t=%0t)", $time);
    dutB_en = 1;
    repeat (20) @(posedge clk_stor);
    rstB_n = 1;
    @(posedge clk_cpuB);
    b_open_req[1] <= 1'b1;
    @(posedge clk_cpuB);
    b_open_req[1] <= 1'b0;
    guard = 0;
    while (!b_open_ok[1] && !b_open_err[1] && guard < 8_000_000) begin
      @(posedge clk_cpuB);
      guard = guard + 1;
    end
    guard = 0;                      // settle - see the note in a_open
    while (b_busy[1] && guard < 100_000) begin
      @(posedge clk_cpuB);
      guard = guard + 1;
    end
    repeat (8) @(posedge clk_cpuB);
    cases = cases + 1;
    if (b_open_ok[1]) fail("no card, yet the open reported SUCCESS");
    else if (!b_open_err[1]) fail("no card: the open never finished (hang)");
    else $display("  ok   no card       open  -> open_err");
    b_request(1, 1'b0, "no card        read  (client 1)", `NDS_ERR_NOCARD);
    b_request(1, 1'b1, "no card        write (client 1)", `NDS_ERR_NOCARD);
    dutB_en = 0;

    // ---- CASE 6: NO PROGRESS. Freeze the mem port after a good mount so
    // only the engine watchdog can end the request (DUT C, small WD_MAX).
    $display("  -- watchdog DUT: frozen mem port -- (t=%0t)", $time);
    dutC_en = 1;
    repeat (20) @(posedge clk_stor);
    rstC_n = 1;
    @(posedge clk_cpuC);
    c_open_req[1] <= 1'b1;
    @(posedge clk_cpuC);
    c_open_req[1] <= 1'b0;
    guard = 0;
    while (!c_open_ok[1] && !c_open_err[1] && guard < 4_000_000) begin
      @(posedge clk_cpuC);
      guard = guard + 1;
    end
    guard = 0;                      // settle - see the note in a_open
    while (c_busy[1] && guard < 100_000) begin
      @(posedge clk_cpuC);
      guard = guard + 1;
    end
    repeat (8) @(posedge clk_cpuC);
    if (!c_open_ok[1]) begin
      fail("watchdog DUT: FLOPPY1.IMG did not open (setup, not the case)");
    end else begin
      memC_hang = 1;
      cases = cases + 1;
      @(posedge clk_cpuC);
      c_block[1*16 +: 16] <= 16'd0;
      c_req[1] <= 1'b1;
      @(posedge clk_cpuC);
      c_req[1] <= 1'b0;
      guard = 0;
      while (!c_done[1] && guard < 4_000_000) begin
        @(posedge clk_cpuC);
        guard = guard + 1;
      end
      if (!c_done[1])
        fail("frozen mem port: NEVER COMPLETED - watchdog did not fire");
      else if (!c_err[1])
        fail("frozen mem port: reported SUCCESS while nothing moved");
      else if (c_err_code[1*4 +: 4] !== `NDS_ERR_TIMEOUT) begin
        fail("frozen mem port: wrong reason code");
        $display("       want TIMEOUT  got %0s",
                 codename(c_err_code[1*4 +: 4]));
      end else
        $display("  ok   frozen mem     read  -> err=1 TIMEOUT");
    end
    dutC_en = 0;

    // ---- card health: no test above may have provoked a card write or a
    // command CRC error
    if (cardA.crc_errors != 0)
      fail("card A saw command CRC7 errors");
    if (cardA.illegal_writes != 0)
      fail("card A was WRITTEN to - no case here may write the card");

    run_fatchain_phase;

    $display("=== %0d cases, %0d failures === (t=%0t)", cases, fails, $time);
    if (fails == 0) $display("TB_RESULT: PASS");
    $finish;
  end

  // ------------------------------------------------------------- DUT F
  // CORRUPT FILESYSTEM. nds_badfat.img holds BADFAT.IMG, whose FAT chain
  // make_storage_image.sh cut at hop 2 (the second cluster's entry set to
  // free) while leaving FLOPPY1.IMG on the same image whole. The directory
  // entry still claims the full 4096 bytes, so the engine's per-request FAT
  // walk runs off the end of the chain before it reaches the sector asked
  // for. Clock-gated until its phase.
  reg  dutF_en = 0;
  reg  rstF_n  = 0;
  wire clk_storF = clk_stor & dutF_en;
  wire clk_cpuF  = clk_cpu  & dutF_en;

  wire        sdF_clk, sdF_cmd_o, sdF_cmd_oe, sdF_dat0_o, sdF_dat0_oe;
  wire        cF_cmd_o, cF_cmd_oe, cF_dat0_o, cF_dat0_oe;
  wire        sdF_cmd  = sdF_cmd_oe  ? sdF_cmd_o  : (cF_cmd_oe  ? cF_cmd_o  : 1'b1);
  wire        sdF_dat0 = sdF_dat0_oe ? sdF_dat0_o : (cF_dat0_oe ? cF_dat0_o : 1'b1);

  wire        memF_start, memF_we, memF_busy, memF_done;
  wire [19:0] memF_addr;
  wire [31:0] memF_wdata, memF_rdata;

  reg  [N-1:0]    f_open_req = 0;
  reg  [N-1:0]    f_req = 0;
  reg  [N*16-1:0] f_block = 0;
  wire [N-1:0]    f_open_ok, f_open_err, f_busy, f_done, f_err;
  wire [N*4-1:0]  f_err_code;
  wire [N*32-1:0] f_size_bytes;

  // client 0 = BADFAT.IMG (broken), client 1 = FLOPPY1.IMG (the control)
  nd_storage #(
      .N_CLIENTS (N),
      .FILE0_NAME("BADFAT.IMG"), .FILE0_LEN(8'd10),
      .RD_CLK_DIV(3'd1),
      .WR_CLKDIV (8'd2),
      .WD_MAX    (32'd5_000_000),
      .SIMULATE  (1)
  ) dutF (
      .clk_stor  (clk_storF),  .rst_stor_n(rstF_n),
      .clk_cpu   (clk_cpuF),   .rst_cpu_n (rstF_n),
      .sd_clk_o  (sdF_clk),
      .sd_cmd_i  (sdF_cmd),    .sd_cmd_o  (sdF_cmd_o),  .sd_cmd_oe (sdF_cmd_oe),
      .sd_dat0_i (sdF_dat0),   .sd_dat0_o (sdF_dat0_o), .sd_dat0_oe(sdF_dat0_oe),
      .mem_start (memF_start),  .mem_we   (memF_we),
      .mem_addr  (memF_addr),   .mem_wdata(memF_wdata), .mem_rdata(memF_rdata),
      .mem_busy  (memF_busy),   .mem_done (memF_done),
      .open_req  (f_open_req),  .open_ok  (f_open_ok),  .open_err (f_open_err),
      .size_bytes(f_size_bytes),
      .req       (f_req),       .wr       ({N{1'b0}}),  .block    (f_block),
      .busy      (f_busy),      .done     (f_done),     .err      (f_err),
      .err_code  (f_err_code),
      .buf_addr  (), .buf_wdata(), .buf_we(), .buf_rdata({N{16'd0}}),
      .sd_status (), .card_type (), .fs_type ()
  );

  nds_mem_model #(.MEM_WORDS(32768)) u_memF (
      .clk  (clk_storF), .rst_n(rstF_n),
      .start(memF_start), .we(memF_we), .addr(memF_addr),
      .wdata(memF_wdata), .rdata(memF_rdata),
      .busy (memF_busy),  .done (memF_done)
  );

  sd_card_model #(
      .IMAGE    ("nds_badfat.img"),
      .MAX_BYTES(IMG_BYTES)
  ) cardF (
      .sd_clk   (sdF_clk),
      .sd_cmd_i (sdF_cmd),  .sd_cmd_o (cF_cmd_o),  .sd_cmd_oe (cF_cmd_oe),
      .sd_dat0_i(sdF_dat0), .sd_dat0_o(cF_dat0_o), .sd_dat0_oe(cF_dat0_oe),
      .sd_dat1_i(1'b1), .sd_dat1_o(), .sd_dat1_oe(),
      .sd_dat2_i(1'b1), .sd_dat2_o(), .sd_dat2_oe(),
      .sd_dat3_i(1'b1), .sd_dat3_o(), .sd_dat3_oe()
  );

  task f_open(input integer cl);
    integer guard;
    begin
      @(posedge clk_cpuF);
      f_open_req[cl] <= 1'b1;
      @(posedge clk_cpuF);
      f_open_req[cl] <= 1'b0;
      guard = 0;
      while (!f_open_ok[cl] && !f_open_err[cl] && guard < 4_000_000) begin
        @(posedge clk_cpuF);
        guard = guard + 1;
      end
      // settle - see the note in a_open
      guard = 0;
      while (f_busy[cl] && guard < 100_000) begin
        @(posedge clk_cpuF);
        guard = guard + 1;
      end
      repeat (8) @(posedge clk_cpuF);
    end
  endtask

  task f_read(input integer cl, input [15:0] blk, input [1023:0] label,
              input want_err, input [3:0] want_code);
    integer guard;
    begin
      cases = cases + 1;
      @(posedge clk_cpuF);
      f_block[cl*16 +: 16] <= blk;
      f_req[cl] <= 1'b1;
      @(posedge clk_cpuF);
      f_req[cl] <= 1'b0;
      guard = 0;
      while (!f_done[cl] && guard < 4_000_000) begin
        @(posedge clk_cpuF);
        guard = guard + 1;
      end
      if (!f_done[cl]) fail({label, " NEVER COMPLETED (no done pulse)"});
      else if (f_err[cl] !== want_err) begin
        fail({label, " wrong err bit"});
        $display("       want err=%b got err=%b code=%0s",
                 want_err, f_err[cl], codename(f_err_code[cl*4 +: 4]));
      end else if (f_err_code[cl*4 +: 4] !== want_code) begin
        fail({label, " wrong reason code"});
        $display("       want %0s got %0s",
                 codename(want_code), codename(f_err_code[cl*4 +: 4]));
      end else
        $display("  ok   %0s -> err=%b %0s",
                 label, f_err[cl], codename(f_err_code[cl*4 +: 4]));
    end
  endtask

  // ---- CASE 7: CORRUPT FILESYSTEM (dutF, nds_badfat.img)
  task run_fatchain_phase;
    begin
    $display("  -- corrupt-FAT DUT: nds_badfat.img -- (t=%0t)", $time);
    dutF_en = 1;
    repeat (20) @(posedge clk_stor);
    rstF_n = 1;

    // control: the intact file on the SAME broken card must still work,
    // so a pass cannot come from the whole image being unreadable
    f_open(1);
    if (!f_open_ok[1]) begin
      fail("control: FLOPPY1.IMG did not open on nds_badfat.img");
    end else begin
    f_read(1, 16'd0, "control  read  blk 0 (intact file)",
           1'b0, `NDS_ERR_NONE);

    // the broken file: the open succeeds (the directory entry is fine and
    // the contiguity gate is stripped in this build), the READ must not
    f_open(0);
    if (!f_open_ok[0]) begin
      fail("BADFAT.IMG did not open - the FAT walk case cannot run");
    end else begin
      f_read(0, 16'd0, "broken chain   read  blk 0",
             1'b1, `NDS_ERR_FATCHAIN);
      f_read(0, 16'd1, "broken chain   read  blk 1",
             1'b1, `NDS_ERR_FATCHAIN);
    end

    // and the intact file still works afterwards
    f_read(1, 16'd1, "control  read  blk 1 (after chain fault)",
           1'b0, `NDS_ERR_NONE);
    end

    if (cardF.crc_errors != 0) fail("card F saw command CRC7 errors");
    dutF_en = 0;
    end
  endtask

  // absolute backstop: a hang here is itself the bug this bench hunts
  initial begin
    #500_000_000;
    $display("TB_RESULT: FAIL testbench wall-clock timeout (the stack hung)");
    $finish;
  end

endmodule
