`include "nd_storage_status.vh"
/**************************************************************************
** TESTBENCH: the Winchester binding of nd_storage_disc_adapter             **
**                                                                       **
** WHY THERE IS NO nd_storage_wd_adapter.v                                **
**                                                                       **
** The Winchester needs no adapter of its own. nd_storage_disc_adapter.v   **
** contains nothing SMD-specific: its CHS->LBA is driven entirely by the  **
** GEO_HEADS / GEO_SPT parameters, and its one hard assumption - a        **
** 1024-byte sector, i.e. 512 words, hence the "<< 9" - is equally true   **
** of this card (ND-11.015.01 sec 2.1: "Each sector contains 512 words    **
** (1 Kbytes) of data"). Only the module NAME and its comments say SMD.   **
**                                                                       **
** So the Winchester instantiates the same adapter with its own geometry  **
** (Micropolis 1325 / DISC-74-1: 8 heads, 9 sectors/track), and           **
** ND_WINCHESTER.v packs disk_blkaddr1 as {head b11-8, sector b4-0},      **
** which lands inside the b15-8 / b7-0 fields the adapter reads.          **
**                                                                       **
** That reuse is a CLAIM, and this bench is what makes it a fact. It also **
** closes a real hole: nd_storage_disc_adapter_tb.v instantiates the       **
** adapter twice and both times at the DEFAULT geometry, so the GEO_*     **
** parameterisation was never exercised by anything before this.          **
**                                                                       **
** Covered:                                                               **
**   1. CHS -> word position for Winchester geometry, checked against an  **
**      independently computed expectation, including a cylinder near the **
**      top of the platter (where a wrong multiply shows up but a         **
**      boot-sector-only test would not).                                 **
**   2. The SAME CHS triple gives a DIFFERENT answer under SMD geometry - **
**      proof the parameters are actually reaching the arithmetic and the **
**      bench is not just re-deriving a constant.                         **
**   3. A full aligned block write is accepted.                           **
**   4. A PARTIAL block write is REFUSED with done+err and zero client    **
**      traffic - the deliberate design decision for this card: a single  **
**      512-word Winchester sector write is a partial block, and          **
**      read-modify-write would need a BSRAM that does not exist. The     **
**      controller turns the refusal into an error interrupt, so it is    **
**      visible, never silent corruption.                                 **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
**                                                                       **
** Ronny Hansen                                                          **
***************************************************************************/

`timescale 1ns / 1ps

module nd_winchester_adapter_tb;

  // Micropolis 1325 (the DISC-74-1), the drive SINTRAN boots from.
  localparam [15:0] WD_HEADS = 16'd8;
  localparam [15:0] WD_SPT   = 16'd9;

  reg clk_cpu = 0;
  reg rst_n   = 0;
  always #5 clk_cpu = ~clk_cpu;

  // ---- device-side backend port (what ND_WINCHESTER drives) ----
  reg         disk_start = 1'b0;
  reg         disk_req   = 1'b0;
  reg         disk_wr    = 1'b0;
  reg  [15:0] disk_blkaddr1 = 16'd0;
  reg  [15:0] disk_blkaddr2 = 16'd0;
  reg  [ 2:0] disk_unit  = 3'd0;
  reg  [10:0] disk_wordcount = 11'd0;
  wire        disk_done, disk_err;
  wire [ 3:0] disk_err_code;     // WHY it was refused (nd_storage_status.vh)
  wire [ 9:0] dbuf_addr;
  wire [15:0] dbuf_wdata;
  wire        dbuf_we;

  // ---- nd_storage client port (modelled below) ----
  wire        c_open_req;
  reg         c_open_ok  = 1'b1;
  reg         c_open_err = 1'b0;
  reg  [31:0] c_size_bytes = 32'd75_497_472;  // the 1325's full capacity
  wire        c_req, c_wr;
  wire [15:0] c_block;
  reg         c_busy = 1'b0;
  reg         c_done = 1'b0;
  reg         c_err  = 1'b0;
  reg  [ 3:0] c_err_code = 4'd0;
  reg  [ 9:0] c_buf_addr = 10'd0;
  reg  [15:0] c_buf_wdata = 16'd0;
  reg         c_buf_we = 1'b0;
  wire [15:0] c_buf_rdata;

  nd_storage_disc_adapter #(
      .UNIT(3'd0),
      .GEO_HEADS(WD_HEADS),
      .GEO_SPT  (WD_SPT)
  ) dut (
      .clk_cpu       (clk_cpu),
      .rst_n         (rst_n),
      .disk_start    (disk_start),
      .disk_req      (disk_req),
      .disk_wr       (disk_wr),
      .disk_blkaddr1 (disk_blkaddr1),
      .disk_blkaddr2 (disk_blkaddr2),
      .disk_unit     (disk_unit),
      .disk_wordcount(disk_wordcount),
      .disk_done     (disk_done),
      .disk_err      (disk_err),
      .disk_err_code (disk_err_code),
      .dbuf_addr     (dbuf_addr),
      .dbuf_wdata    (dbuf_wdata),
      .dbuf_we       (dbuf_we),
      .dbuf_rdata    (16'd0),
      .open_start    (1'b1),
      .c_open_req    (c_open_req),
      .c_open_ok     (c_open_ok),
      .c_open_err    (c_open_err),
      .c_size_bytes  (c_size_bytes),
      .c_req         (c_req),
      .c_wr          (c_wr),
      .c_block       (c_block),
      .c_busy        (c_busy),
      .c_done        (c_done),
      .c_err         (c_err),
      .c_err_code    (c_err_code),
      .c_buf_addr    (c_buf_addr),
      .c_buf_wdata   (c_buf_wdata),
      .c_buf_we      (c_buf_we),
      .c_buf_rdata   (c_buf_rdata)
  );

  // A second instance at the SMD default geometry, so the bench can show the
  // SAME inputs give a DIFFERENT position - i.e. the parameters really reach
  // the arithmetic.
  reg  [15:0] ref_blk1 = 16'd0, ref_blk2 = 16'd0;
  wire [31:0] ref_lba;

  nd_storage_disc_adapter #(
      .UNIT(3'd0)          // default geometry: 5 heads, 18 sectors/track
  ) ref_smd (
      .clk_cpu(clk_cpu), .rst_n(rst_n),
      .disk_start(1'b0), .disk_req(1'b0), .disk_wr(1'b0),
      .disk_blkaddr1(ref_blk1), .disk_blkaddr2(ref_blk2),
      .disk_unit(3'd0), .disk_wordcount(11'd0),
      .disk_done(), .disk_err(), .disk_err_code(),
      .dbuf_addr(), .dbuf_wdata(), .dbuf_we(), .dbuf_rdata(16'd0),
      .open_start(1'b0),
      .c_open_req(), .c_open_ok(1'b1), .c_open_err(1'b0),
      .c_size_bytes(32'hFFFF_FFFF),
      .c_req(), .c_wr(), .c_block(), .c_busy(1'b0),
      .c_done(1'b0), .c_err(1'b0), .c_err_code(4'd0),
      .c_buf_addr(10'd0), .c_buf_wdata(16'd0), .c_buf_we(1'b0),
      .c_buf_rdata()
  );
  assign ref_lba = ref_smd.s_lba;

  integer errors = 0;
  integer checks = 0;

  task check_eq32(input [31:0] got, input [31:0] want, input [1023:0] msg);
    begin
      checks = checks + 1;
      if (got !== want) begin
        errors = errors + 1;
        $display("  FAIL: %0s - expected %0d, got %0d", msg, want, got);
      end
    end
  endtask

  task check(input cond, input [1023:0] msg);
    begin
      checks = checks + 1;
      if (!cond) begin
        errors = errors + 1;
        $display("  FAIL: %0s", msg);
      end
    end
  endtask

  // Present a CHS the way ND_WINCHESTER packs it and report the adapter's LBA.
  task set_chs(input [15:0] cyl, input [3:0] head, input [4:0] sect);
    begin
      disk_blkaddr1 = {4'd0, head, 3'd0, sect};
      disk_blkaddr2 = cyl;
      #1;
    end
  endtask

  function [31:0] want_lba(input [31:0] cyl, input [31:0] head, input [31:0] sect);
    begin
      want_lba = (cyl * WD_HEADS + head) * WD_SPT + sect;
    end
  endfunction

  // Minimal nd_storage client: accept a request and complete it next cycle.
  // inject_code != NONE makes it complete with err=1 and THAT reason, so the
  // bench can prove a failure from inside nd_storage arrives at the
  // controller as its own reason rather than being flattened by the adapter.
  reg [3:0] inject_code = `NDS_ERR_NONE;
  reg c_pending = 1'b0;
  integer client_ops = 0;
  always @(posedge clk_cpu) begin
    c_done <= 1'b0;
    if (c_req && !c_pending) begin
      c_pending  <= 1'b1;
      c_busy     <= 1'b1;
      client_ops <= client_ops + 1;
    end else if (c_pending) begin
      c_pending  <= 1'b0;
      c_busy     <= 1'b0;
      c_done     <= 1'b1;
      c_err      <= (inject_code != `NDS_ERR_NONE);
      c_err_code <= inject_code;
    end
  end

  // One read that the client port fails with a given reason; the adapter
  // must hand that exact reason to the controller.
  task check_passthrough(input [3:0] code, input [1023:0] name);
    integer k;
    begin
      inject_code = code;
      set_chs(16'd0, 4'd0, 5'd0);
      disk_wordcount = 11'd1024;
      disk_wr        = 1'b0;
      @(negedge clk_cpu);
      disk_start = 1'b1; disk_req = 1'b1;
      @(negedge clk_cpu);
      disk_start = 1'b0; disk_req = 1'b0;
      k = 0;
      while (!disk_done && k < 1000) begin @(negedge clk_cpu); k = k + 1; end
      check(disk_done === 1'b1, {"a failed client op COMPLETES: ", name});
      check(disk_err  === 1'b1, {"a failed client op is an error: ", name});
      check(disk_err_code === code,
            {"the storage reason reaches the controller unchanged: ", name});
      inject_code = `NDS_ERR_NONE;
      @(negedge clk_cpu);
    end
  endtask

  integer i;

  initial begin
    $display("=== Winchester binding of nd_storage_disc_adapter ===");
    repeat (4) @(negedge clk_cpu);
    rst_n = 1'b1;
    repeat (2) @(negedge clk_cpu);

    // ---- 1. CHS -> LBA under WINCHESTER geometry ---------------------
    set_chs(16'd0, 4'd0, 5'd0);
    check_eq32(dut.s_lba, want_lba(0, 0, 0), "CHS(0,0,0) -> LBA 0");
    check_eq32(dut.s_base32, want_lba(0, 0, 0) * 512, "CHS(0,0,0) -> word 0");

    set_chs(16'd0, 4'd0, 5'd4);
    check_eq32(dut.s_lba, want_lba(0, 0, 4), "CHS(0,0,4) -> LBA 4");

    set_chs(16'd0, 4'd3, 5'd5);
    check_eq32(dut.s_lba, want_lba(0, 3, 5), "CHS(0,3,5) - head term");

    set_chs(16'd1, 4'd0, 5'd0);
    check_eq32(dut.s_lba, want_lba(1, 0, 0),
               "CHS(1,0,0) - one cylinder = heads*spt = 72 sectors");

    // A cylinder near the TOP of the platter. This is the one that matters:
    // the SINTRAN main directory on WD0-M.IMG lives around cylinder 910, and
    // a wrong multiply is invisible in a boot-sector-only test.
    set_chs(16'd910, 4'd7, 5'd8);
    check_eq32(dut.s_lba, want_lba(910, 7, 8), "CHS(910,7,8) - near the top");
    check_eq32(dut.s_base32, want_lba(910, 7, 8) * 512,
               "CHS(910,7,8) -> word position");

    // The last addressable sector of the 1325.
    set_chs(16'd1023, 4'd7, 5'd8);
    check_eq32(dut.s_lba, want_lba(1023, 7, 8), "last sector of the platter");
    check(dut.s_base32 < 32'd37_748_736, "last sector stays inside 75 MB of words");

    // ---- 2. the geometry parameters really reach the arithmetic -------
    ref_blk1 = 16'd0; ref_blk2 = 16'd910; #1;
    set_chs(16'd910, 4'd0, 5'd0);
    check(dut.s_lba !== ref_lba,
          "the SAME cylinder gives a DIFFERENT LBA under SMD geometry");
    check_eq32(ref_lba, (32'd910 * 5 + 0) * 18 + 0,
               "the reference instance really is at 5 heads / 18 spt");

    // ---- 3. a FULL ALIGNED block write is accepted -------------------
    client_ops = 0;
    set_chs(16'd0, 4'd0, 5'd0);          // word position 0 - block aligned
    disk_wordcount = 11'd1024;
    disk_wr        = 1'b1;
    @(negedge clk_cpu);
    disk_start = 1'b1; disk_req = 1'b1;
    @(negedge clk_cpu);
    disk_start = 1'b0; disk_req = 1'b0;

    i = 0;
    while (!disk_done && i < 1000) begin @(negedge clk_cpu); i = i + 1; end
    check(disk_done === 1'b1, "a full aligned block write completes");
    check(disk_err  === 1'b0, "a full aligned block write is NOT an error");
    check(disk_err_code === `NDS_ERR_NONE,
          "a successful write reports reason code NONE");
    check(client_ops > 0, "a full aligned block write reached the client");
    @(negedge clk_cpu);

    // ---- 4. a PARTIAL block write is SERVED by read-modify-write -------
    // One Winchester sector is 512 words; a storage block is 1024. This used
    // to be REFUSED with WRALIGN, on the reasoning that a visible refusal beat
    // a read-modify-write. That decision was wrong, and silicon said so on
    // 10-AUG-2026: SINTRAN writes one 1024-byte sector at a time - 512 words,
    // the natural unit for this card - so EVERY write it issued was refused
    // and the boot died with "DISC TRANSFER ERROR IN SEGMENT HANDLING".
    //
    // The adapter now fetches the block, keeps the words outside the guest's
    // window, and writes the merged block back. That costs TWO client
    // operations - a read then a write - where a full aligned block costs one.
    client_ops = 0;
    set_chs(16'd0, 4'd0, 5'd0);
    disk_wordcount = 11'd512;            // ONE sector - a partial block
    disk_wr        = 1'b1;
    @(negedge clk_cpu);
    disk_start = 1'b1; disk_req = 1'b1;
    @(negedge clk_cpu);
    disk_start = 1'b0; disk_req = 1'b0;

    i = 0;
    while (!disk_done && i < 1000) begin @(negedge clk_cpu); i = i + 1; end
    check(disk_done === 1'b1, "a partial block write COMPLETES");
    check(disk_err  === 1'b0, "a partial block write is SERVED, not refused");
    check(disk_err_code === `NDS_ERR_NONE,
          "a served partial write reports reason code NONE");
    check_eq32(client_ops, 32'd2,
               "a partial write costs TWO client ops: the merge read, then the write");
    @(negedge clk_cpu);

    // An UNALIGNED FULL-LENGTH write is still refused, and deliberately: 1024
    // words starting at offset 512 SPANS TWO blocks, so the first block is
    // partial AND there is a second. The merged words are staged in the device
    // buffer above the guest's own chunk, and a chunk that already fills the
    // buffer leaves nowhere to put them. Refusing is correct here; serving it
    // would need somewhere else to stage. SINTRAN never asks for this.
    client_ops = 0;
    set_chs(16'd0, 4'd0, 5'd1);          // sector 1 -> word 512, not aligned
    disk_wordcount = 11'd1024;
    disk_wr        = 1'b1;
    @(negedge clk_cpu);
    disk_start = 1'b1; disk_req = 1'b1;
    @(negedge clk_cpu);
    disk_start = 1'b0; disk_req = 1'b0;

    i = 0;
    while (!disk_done && i < 1000) begin @(negedge clk_cpu); i = i + 1; end
    check(disk_err === 1'b1, "an UNALIGNED full-length write is refused too");
    check(disk_err_code === `NDS_ERR_WRALIGN,
          "the unaligned refusal also says WRALIGN");
    check_eq32(client_ops, 32'd0, "the unaligned refusal is also traffic-free");

    // ---- 5. the reason code from BELOW is passed through unchanged -----
    // A failure inside nd_storage (no card, missing file, dead card...)
    // must arrive at the controller as ITS OWN reason, not be flattened
    // into whatever the adapter would have said. Drive one read that the
    // client port fails with a specific code and check it comes out.
    check_passthrough(`NDS_ERR_NOCARD,   "NOCARD");
    check_passthrough(`NDS_ERR_CARDIO,   "CARDIO");
    check_passthrough(`NDS_ERR_FATCHAIN, "FATCHAIN");
    check_passthrough(`NDS_ERR_TIMEOUT,  "TIMEOUT");

    // ---- 6. asking past the end of the image says RANGE ----------------
    // c_size_bytes is the 1325's capacity; a cylinder past it is out of
    // range for the drive, and the controller must be told THAT, not
    // "media fault".
    client_ops = 0;
    set_chs(16'd9999, 4'd0, 5'd0);
    disk_wordcount = 11'd1024;
    disk_wr        = 1'b0;
    @(negedge clk_cpu);
    disk_start = 1'b1; disk_req = 1'b1;
    @(negedge clk_cpu);
    disk_start = 1'b0; disk_req = 1'b0;
    i = 0;
    while (!disk_done && i < 1000) begin @(negedge clk_cpu); i = i + 1; end
    check(disk_done === 1'b1, "an out-of-range read still COMPLETES");
    check(disk_err  === 1'b1, "an out-of-range read is an error");
    check(disk_err_code === `NDS_ERR_RANGE,
          "the out-of-range refusal says RANGE");
    check_eq32(client_ops, 32'd0, "the out-of-range refusal is traffic-free");

    // ---- 7. the file is not mounted: NOTOPEN, not a media fault --------
    c_open_ok = 1'b0;
    client_ops = 0;
    set_chs(16'd0, 4'd0, 5'd0);
    disk_wordcount = 11'd1024;
    disk_wr        = 1'b0;
    @(negedge clk_cpu);
    disk_start = 1'b1; disk_req = 1'b1;
    @(negedge clk_cpu);
    disk_start = 1'b0; disk_req = 1'b0;
    i = 0;
    while (!disk_done && i < 1000) begin @(negedge clk_cpu); i = i + 1; end
    check(disk_done === 1'b1, "a read with no mounted file still COMPLETES");
    check(disk_err  === 1'b1, "a read with no mounted file is an error");
    check(disk_err_code === `NDS_ERR_NOTOPEN,
          "no mounted file says NOTOPEN");
    c_open_ok = 1'b1;

    if (errors == 0)
      $display("=== %0d checks passed ===\nTB_RESULT: PASS", checks);
    else
      $display("=== %0d of %0d checks FAILED ===\nTB_RESULT: FAIL", errors, checks);
    $finish;
  end

  initial begin
    #5_000_000;
    $display("  FAIL: testbench watchdog - the adapter wedged");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
