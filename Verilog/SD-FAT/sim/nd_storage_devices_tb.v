/****************************************************************************
** nd_storage_devices - wrapper wiring and tie-off testbench               **
**                                                                         **
** Full path:                                                              **
**   Verilog/SD-FAT/sim/nd_storage_devices_tb.v                            **
**                                                                         **
** WHAT THIS IS - AND WHAT IT IS NOT                                       **
**                                                                         **
** nd_storage_devices (Verilog/SD-FAT/circuit/nd_storage_devices.v) is a   **
** WRAPPER. It contains no datapath of its own: it instantiates            **
** nd_storage, three kinds of adapter, and four INCLUDE_* generate blocks  **
** that either wire a backend seam to a live adapter or drive that seam to **
** a safe constant. Everything that can go wrong in a wrapper is a WIRING  **
** fault - a seam left dangling, a seam driven by the wrong adapter, a     **
** tie-off that ties the wrong thing, a one-shot that fires twice or never **
** at all.                                                                 **
**                                                                         **
** So this is a WIRING AND TIE-OFF BENCH, NOT A DATA-PATH BENCH. It runs   **
** with NO SD CARD (sd_cmd_i / sd_dat0_i tied high) and no memory model,   **
** so no client ever mounts and no block ever moves. That is deliberate:   **
** every property below is observable without a transfer, and the whole    **
** run costs microseconds instead of waiting out card init. The transfer   **
** paths are covered by the benches that DO have a card model              **
** (test-nds-mount, test-nds-tape, test-nds-floppy, test-storage).         **
**                                                                         **
** NOT DUPLICATED HERE: client bus SLICE CONTINUITY (the flat per-client   **
** concatenations feeding nd_storage) is already proven by                 **
** Verilog/SD-FAT/sim/nd_storage_clientbus_tb.v - read its header before   **
** adding anything about buf_rdata_w here.                                 **
**                                                                         **
** WHERE THE REFERENCE MODEL COMES FROM                                    **
**                                                                         **
** There is no external specification to model. Every expectation below is **
** read directly out of the RTL of the wrapper and of the adapter it       **
** instantiates, and the file:line is named at each check:                 **
**   - the "excluded" constants are the gen_no_* branches of the four      **
**     generates in nd_storage_devices.v (byte_valid/byte_data/TDISK_*,    **
**     the FDISK, SDISK and WDISK groups and their buffer pins)            **
**   - NDS_ERR_NOTOPEN as the answer to a request on an un-opened client   **
**     is the s_bad decode in nd_storage_disc_adapter.v (S_IDLE) and in    **
**     nd_storage_floppy_adapter.v (F_IDLE), and the sticky fault pair in  **
**     nd_storage_tape_adapter.v (A_IDLE); the code values are             **
**     Verilog/SD-FAT/circuit/nd_storage_status.vh                         **
**   - unit/drive filtering is the (disk_unit == UNIT) / (disk_drive ==    **
**     DRIVE) guard in those same two adapters                             **
**   - the one-shot and held-open sequencers are the four small always     **
**     blocks inside the generates of the wrapper itself                   **
**                                                                         **
** A DISABLED OUTPUT IN THIS PROJECT DRIVES 0, NEVER z. The excluded-      **
** configuration checks therefore assert === 0, which fails on x and z as  **
** well as on a wrong value - one comparison covering both hazards.        **
**                                                                         **
** WHITE-BOX CHECKS (stated openly, they read wrapper internals):          **
**   u_on.gen_tape.s_open_pulse        one-shot tape open                  **
**   u_on.a_open_req                   ...as seen leaving the tape adapter **
**   u_on.gen_floppy.s_fopen_pulse     held floppy open                    **
**   u_on.gen_smd.s_mopen_pulse        held SMD open                       **
**   u_on.gen_wd.s_wopen_pulse         held Winchester open                **
**   u_on.f_open_req / m_open_req / w_open_req                             **
**   u_on.u_nd_storage.<flat ports>    client-count agreement ($bits)      **
** They are bench-only observations; nothing is driven from the outside.   **
**                                                                         **
** TEST PLAN                                                               **
**   Two wrappers are elaborated side by side and fed the SAME stimulus:   **
**     u_off  INCLUDE_TAPE/FLOPPY/SMD/WD = 0 0 0 0                         **
**     u_on   INCLUDE_TAPE/FLOPPY/SMD/WD = 1 1 1 1                         **
**   Feeding both the same requests is the point: every request that makes **
**   u_on answer is a request u_off must ignore completely.                **
**                                                                         **
**   T1  u_off: all 21 backend outputs are exactly 0 on EVERY clk_cpu edge **
**       of the whole run, while the inputs are being wiggled and while    **
**       u_on is answering requests (continuous, sampled per edge)         **
**   T2  u_on: the tape one-shot fires exactly ONCE after reset, and the   **
**       tape adapter's c_open_req pulses exactly once with it             **
**   T3  u_on: the floppy/SMD/WD held-open requests are STILL asserted     **
**       hundreds of cycles later, because no client ever reports open     **
**   T4  u_on: SDISK_REQ on the matching unit answers done+err+NOTOPEN,    **
**       and WDISK_DONE / FDISK_DONE stay silent throughout (independence) **
**   T5  u_on: WDISK_REQ likewise, with SDISK_DONE / FDISK_DONE silent     **
**   T6  u_on: FDISK_REQ likewise, with SDISK_DONE / WDISK_DONE silent     **
**   T7  u_on: unit/drive mismatch (SDISK_UNIT=5, WDISK_UNIT=5,            **
**       FDISK_DRIVE=1) produces NO done at all                            **
**   T8  u_on: byte_req with nothing mounted raises the sticky TDISK_FAULT **
**       with NOTOPEN and keeps byte_valid low (the tape has no error      **
**       register, so this seam is the only place the reason appears)      **
**   T9  u_on: FDISK_MEDIA_FMT is the 1.2 MB descriptor 4'hF for a size of **
**       0 (characterisation of the size decode in gen_floppy), while      **
**       u_off holds it at 4'h0 - the two generates really are different   **
**   T10 structural: the wrapper's flat client buses and nd_storage's      **
**       ports are the SAME WIDTH, so the N localparam agrees with         **
**       nd_storage's N_CLIENTS. A mismatch pads or truncates in silence.  **
**                                                                         **
** HOW TO RUN                                                              **
**   cd Verilog/SD-FAT/sim                                                 **
**   iverilog -g2012 -I../circuit -o nd_storage_devices_tb.vvp \           **
**     ../circuit/nds_sync.v ../circuit/nd_storage_engine.v \              **
**     ../circuit/nd_storage_mount.v ../circuit/nd_storage_cache.v \       **
**     ../circuit/nd_storage_fatchk.v ../circuit/nd_storage.v \            **
**     ../circuit/nd_storage_tape_adapter.v \                              **
**     ../circuit/nd_storage_floppy_adapter.v \                            **
**     ../circuit/nd_storage_disc_adapter.v \                              **
**     ../circuit/sd_file_reader.v ../circuit/sd_writer.v \                **
**     ../circuit/nd_storage_devices.v nd_storage_devices_tb.v             **
**   vvp -N nd_storage_devices_tb.vvp                                      **
**   (the CLIENTBUS_SRCS list of the Makefile, plus this bench)            **
**                                                                         **
** SELF-CHECK OF THE BENCH ITSELF: every family of checks above was        **
** mutation-tested - the expected value was deliberately falsified in a    **
** scratch copy and the bench was confirmed to FAIL - so none of them      **
** passes vacuously.                                                       **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

`include "nd_storage_status.vh"

module nd_storage_devices_tb;

  // -------------------------------------------------------------- clocks
  // Two unrelated clocks, as the wrapper requires (clk_stor for the SD /
  // SDRAM side, clk_cpu for the client side). Skewed on purpose.
  reg clk_stor = 1'b0;
  reg clk_cpu  = 1'b0;
  always #9  clk_stor = ~clk_stor;
  always #11 clk_cpu  = ~clk_cpu;

  reg rst_n = 1'b0;

  integer checks = 0;
  integer errors = 0;

  // AUTOMATIC on purpose: this task is called from the continuous T1
  // monitor and from the stimulus block, and both can land on the same
  // clock edge. A static task re-entered that way reports the same failure
  // twice and miscounts - measured here before it was made automatic.
  task automatic chk(input cond, input [8*64-1:0] what);
    begin
      checks = checks + 1;
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL @%0t: %0s", $time, what);
      end
    end
  endtask

  // ------------------------------------------------- shared stimulus regs
  // BOTH wrappers see exactly the same inputs. Anything that makes u_on
  // answer is something u_off must ignore.
  reg        byte_req = 1'b0;
  reg        source_rewind = 1'b0;

  reg        FDISK_REQ = 1'b0;
  reg        FDISK_WR = 1'b0;
  reg [15:0] FDISK_LSECT = 16'd0;
  reg [ 1:0] FDISK_FORMAT = 2'd0;
  reg [ 1:0] FDISK_DRIVE = 2'd0;
  reg [10:0] FDISK_WORDCOUNT = 11'd0;
  reg [15:0] FDBUF_RDATA = 16'd0;

  reg        SDISK_START = 1'b0;
  reg        SDISK_REQ = 1'b0;
  reg        SDISK_WR = 1'b0;
  reg [15:0] SDISK_BLKADDR1 = 16'd0;
  reg [15:0] SDISK_BLKADDR2 = 16'd0;
  reg [ 2:0] SDISK_UNIT = 3'd0;
  reg [10:0] SDISK_WORDCOUNT = 11'd0;
  reg [15:0] SDBUF_RDATA = 16'd0;

  reg        WDISK_START = 1'b0;
  reg        WDISK_REQ = 1'b0;
  reg        WDISK_WR = 1'b0;
  reg [15:0] WDISK_BLKADDR1 = 16'd0;
  reg [15:0] WDISK_BLKADDR2 = 16'd0;
  reg [ 2:0] WDISK_UNIT = 3'd0;
  reg [10:0] WDISK_WORDCOUNT = 11'd0;
  reg [15:0] WDBUF_RDATA = 16'd0;

  // ------------------------------------------------- u_off outputs (all 0)
  wire        off_byte_valid;
  wire [ 7:0] off_byte_data;
  wire        off_TDISK_FAULT;
  wire [ 3:0] off_TDISK_ERR_CODE;
  wire        off_FDISK_DONE, off_FDISK_ERR;
  wire [ 3:0] off_FDISK_ERR_CODE, off_FDISK_MEDIA_FMT;
  wire [ 9:0] off_FDBUF_ADDR;
  wire [15:0] off_FDBUF_WDATA;
  wire        off_FDBUF_WE;
  wire        off_SDISK_DONE, off_SDISK_ERR;
  wire [ 3:0] off_SDISK_ERR_CODE;
  wire [ 9:0] off_SDBUF_ADDR;
  wire [15:0] off_SDBUF_WDATA;
  wire        off_SDBUF_WE;
  wire        off_WDISK_DONE, off_WDISK_ERR;
  wire [ 3:0] off_WDISK_ERR_CODE;
  wire [ 9:0] off_WDBUF_ADDR;
  wire [15:0] off_WDBUF_WDATA;
  wire        off_WDBUF_WE;

  // ------------------------------------------------- u_on outputs
  wire        on_byte_valid;
  wire [ 7:0] on_byte_data;
  wire        on_TDISK_FAULT;
  wire [ 3:0] on_TDISK_ERR_CODE;
  wire        on_FDISK_DONE, on_FDISK_ERR;
  wire [ 3:0] on_FDISK_ERR_CODE, on_FDISK_MEDIA_FMT;
  wire [ 9:0] on_FDBUF_ADDR;
  wire [15:0] on_FDBUF_WDATA;
  wire        on_FDBUF_WE;
  wire        on_SDISK_DONE, on_SDISK_ERR;
  wire [ 3:0] on_SDISK_ERR_CODE;
  wire [ 9:0] on_SDBUF_ADDR;
  wire [15:0] on_SDBUF_WDATA;
  wire        on_SDBUF_WE;
  wire        on_WDISK_DONE, on_WDISK_ERR;
  wire [ 3:0] on_WDISK_ERR_CODE;
  wire [ 9:0] on_WDBUF_ADDR;
  wire [15:0] on_WDBUF_WDATA;
  wire        on_WDBUF_WE;

  // ------------------------------------------------------------- DUT: OFF
  nd_storage_devices #(
      .SIMULATE      (1),
      .INCLUDE_TAPE  (0),
      .INCLUDE_FLOPPY(0),
      .INCLUDE_SMD   (0),
      .INCLUDE_WD    (0)
  ) u_off (
      .clk_stor      (clk_stor),
      .rst_stor_n    (rst_n),
      .clk_cpu       (clk_cpu),
      .rst_cpu_n     (rst_n),

      .byte_req      (byte_req),
      .byte_valid    (off_byte_valid),
      .byte_data     (off_byte_data),
      .source_rewind (source_rewind),
      .TDISK_FAULT   (off_TDISK_FAULT),
      .TDISK_ERR_CODE(off_TDISK_ERR_CODE),

      .FDISK_REQ      (FDISK_REQ),
      .FDISK_WR       (FDISK_WR),
      .FDISK_LSECT    (FDISK_LSECT),
      .FDISK_FORMAT   (FDISK_FORMAT),
      .FDISK_DRIVE    (FDISK_DRIVE),
      .FDISK_WORDCOUNT(FDISK_WORDCOUNT),
      .FDISK_DONE     (off_FDISK_DONE),
      .FDISK_ERR      (off_FDISK_ERR),
      .FDISK_ERR_CODE (off_FDISK_ERR_CODE),
      .FDISK_MEDIA_FMT(off_FDISK_MEDIA_FMT),
      .FDBUF_ADDR     (off_FDBUF_ADDR),
      .FDBUF_WDATA    (off_FDBUF_WDATA),
      .FDBUF_WE       (off_FDBUF_WE),
      .FDBUF_RDATA    (FDBUF_RDATA),

      .SDISK_START    (SDISK_START),
      .SDISK_REQ      (SDISK_REQ),
      .SDISK_WR       (SDISK_WR),
      .SDISK_BLKADDR1 (SDISK_BLKADDR1),
      .SDISK_BLKADDR2 (SDISK_BLKADDR2),
      .SDISK_UNIT     (SDISK_UNIT),
      .SDISK_WORDCOUNT(SDISK_WORDCOUNT),
      .SDISK_DONE     (off_SDISK_DONE),
      .SDISK_ERR      (off_SDISK_ERR),
      .SDISK_ERR_CODE (off_SDISK_ERR_CODE),
      .SDBUF_ADDR     (off_SDBUF_ADDR),
      .SDBUF_WDATA    (off_SDBUF_WDATA),
      .SDBUF_WE       (off_SDBUF_WE),
      .SDBUF_RDATA    (SDBUF_RDATA),

      .WDISK_START    (WDISK_START),
      .WDISK_REQ      (WDISK_REQ),
      .WDISK_WR       (WDISK_WR),
      .WDISK_BLKADDR1 (WDISK_BLKADDR1),
      .WDISK_BLKADDR2 (WDISK_BLKADDR2),
      .WDISK_UNIT     (WDISK_UNIT),
      .WDISK_WORDCOUNT(WDISK_WORDCOUNT),
      .WDISK_DONE     (off_WDISK_DONE),
      .WDISK_ERR      (off_WDISK_ERR),
      .WDISK_ERR_CODE (off_WDISK_ERR_CODE),
      .WDBUF_ADDR     (off_WDBUF_ADDR),
      .WDBUF_WDATA    (off_WDBUF_WDATA),
      .WDBUF_WE       (off_WDBUF_WE),
      .WDBUF_RDATA    (WDBUF_RDATA),

      .sd_clk_o  (), .sd_cmd_i(1'b1), .sd_cmd_o(), .sd_cmd_oe(),
      .sd_dat0_i (1'b1), .sd_dat0_o(), .sd_dat0_oe(),

      .mem_start (), .mem_we(), .mem_addr(), .mem_wdata(),
      .mem_rdata (32'd0), .mem_busy(1'b0), .mem_done(1'b0),

      .DBG_STATE(), .DBG_LBA(), .DBG_WDATA(), .DBG_RDATA(), .DBG_BUFW(),
      .DBG_BUFWE(), .DBG_FSEC(), .DBG_RX_STB(), .DBG_RX_RAW(),
      .DBG_RX_BYTE(), .DBG_PAST_EOF(), .DBG_GRANT(),
      .sd_status ()
  );

  // -------------------------------------------------------------- DUT: ON
  nd_storage_devices #(
      .SIMULATE      (1),
      .INCLUDE_TAPE  (1),
      .INCLUDE_FLOPPY(1),
      .INCLUDE_SMD   (1),
      .INCLUDE_WD    (1)
  ) u_on (
      .clk_stor      (clk_stor),
      .rst_stor_n    (rst_n),
      .clk_cpu       (clk_cpu),
      .rst_cpu_n     (rst_n),

      .byte_req      (byte_req),
      .byte_valid    (on_byte_valid),
      .byte_data     (on_byte_data),
      .source_rewind (source_rewind),
      .TDISK_FAULT   (on_TDISK_FAULT),
      .TDISK_ERR_CODE(on_TDISK_ERR_CODE),

      .FDISK_REQ      (FDISK_REQ),
      .FDISK_WR       (FDISK_WR),
      .FDISK_LSECT    (FDISK_LSECT),
      .FDISK_FORMAT   (FDISK_FORMAT),
      .FDISK_DRIVE    (FDISK_DRIVE),
      .FDISK_WORDCOUNT(FDISK_WORDCOUNT),
      .FDISK_DONE     (on_FDISK_DONE),
      .FDISK_ERR      (on_FDISK_ERR),
      .FDISK_ERR_CODE (on_FDISK_ERR_CODE),
      .FDISK_MEDIA_FMT(on_FDISK_MEDIA_FMT),
      .FDBUF_ADDR     (on_FDBUF_ADDR),
      .FDBUF_WDATA    (on_FDBUF_WDATA),
      .FDBUF_WE       (on_FDBUF_WE),
      .FDBUF_RDATA    (FDBUF_RDATA),

      .SDISK_START    (SDISK_START),
      .SDISK_REQ      (SDISK_REQ),
      .SDISK_WR       (SDISK_WR),
      .SDISK_BLKADDR1 (SDISK_BLKADDR1),
      .SDISK_BLKADDR2 (SDISK_BLKADDR2),
      .SDISK_UNIT     (SDISK_UNIT),
      .SDISK_WORDCOUNT(SDISK_WORDCOUNT),
      .SDISK_DONE     (on_SDISK_DONE),
      .SDISK_ERR      (on_SDISK_ERR),
      .SDISK_ERR_CODE (on_SDISK_ERR_CODE),
      .SDBUF_ADDR     (on_SDBUF_ADDR),
      .SDBUF_WDATA    (on_SDBUF_WDATA),
      .SDBUF_WE       (on_SDBUF_WE),
      .SDBUF_RDATA    (SDBUF_RDATA),

      .WDISK_START    (WDISK_START),
      .WDISK_REQ      (WDISK_REQ),
      .WDISK_WR       (WDISK_WR),
      .WDISK_BLKADDR1 (WDISK_BLKADDR1),
      .WDISK_BLKADDR2 (WDISK_BLKADDR2),
      .WDISK_UNIT     (WDISK_UNIT),
      .WDISK_WORDCOUNT(WDISK_WORDCOUNT),
      .WDISK_DONE     (on_WDISK_DONE),
      .WDISK_ERR      (on_WDISK_ERR),
      .WDISK_ERR_CODE (on_WDISK_ERR_CODE),
      .WDBUF_ADDR     (on_WDBUF_ADDR),
      .WDBUF_WDATA    (on_WDBUF_WDATA),
      .WDBUF_WE       (on_WDBUF_WE),
      .WDBUF_RDATA    (WDBUF_RDATA),

      .sd_clk_o  (), .sd_cmd_i(1'b1), .sd_cmd_o(), .sd_cmd_oe(),
      .sd_dat0_i (1'b1), .sd_dat0_o(), .sd_dat0_oe(),

      .mem_start (), .mem_we(), .mem_addr(), .mem_wdata(),
      .mem_rdata (32'd0), .mem_busy(1'b0), .mem_done(1'b0),

      .DBG_STATE(), .DBG_LBA(), .DBG_WDATA(), .DBG_RDATA(), .DBG_BUFW(),
      .DBG_BUFWE(), .DBG_FSEC(), .DBG_RX_STB(), .DBG_RX_RAW(),
      .DBG_RX_BYTE(), .DBG_PAST_EOF(), .DBG_GRANT(),
      .sd_status ()
  );

  // =====================================================================
  // T1 - the excluded wrapper never moves. Sampled on EVERY clk_cpu edge
  // for the whole run, while the shared stimulus is being wiggled and the
  // included wrapper is answering. === 0 fails on x and z as well, which
  // is the second half of the repo rule (a disabled output drives 0).
  // Reference: the gen_no_tape / gen_no_floppy / gen_no_smd / gen_no_wd
  // branches of nd_storage_devices.v.
  // =====================================================================
  reg t1_armed = 1'b0;

  always @(posedge clk_cpu) if (t1_armed) begin
    chk(off_byte_valid      === 1'b0,  "T1 off byte_valid moved");
    chk(off_byte_data       === 8'd0,  "T1 off byte_data moved");
    chk(off_TDISK_FAULT     === 1'b0,  "T1 off TDISK_FAULT moved");
    chk(off_TDISK_ERR_CODE  === 4'd0,  "T1 off TDISK_ERR_CODE moved");
    chk(off_FDISK_DONE      === 1'b0,  "T1 off FDISK_DONE moved");
    chk(off_FDISK_ERR       === 1'b0,  "T1 off FDISK_ERR moved");
    chk(off_FDISK_ERR_CODE  === 4'd0,  "T1 off FDISK_ERR_CODE moved");
    chk(off_FDISK_MEDIA_FMT === 4'd0,  "T1 off FDISK_MEDIA_FMT moved");
    chk(off_FDBUF_ADDR      === 10'd0, "T1 off FDBUF_ADDR moved");
    chk(off_FDBUF_WDATA     === 16'd0, "T1 off FDBUF_WDATA moved");
    chk(off_FDBUF_WE        === 1'b0,  "T1 off FDBUF_WE moved");
    chk(off_SDISK_DONE      === 1'b0,  "T1 off SDISK_DONE moved");
    chk(off_SDISK_ERR       === 1'b0,  "T1 off SDISK_ERR moved");
    chk(off_SDISK_ERR_CODE  === 4'd0,  "T1 off SDISK_ERR_CODE moved");
    chk(off_SDBUF_ADDR      === 10'd0, "T1 off SDBUF_ADDR moved");
    chk(off_SDBUF_WDATA     === 16'd0, "T1 off SDBUF_WDATA moved");
    chk(off_SDBUF_WE        === 1'b0,  "T1 off SDBUF_WE moved");
    chk(off_WDISK_DONE      === 1'b0,  "T1 off WDISK_DONE moved");
    chk(off_WDISK_ERR       === 1'b0,  "T1 off WDISK_ERR moved");
    chk(off_WDISK_ERR_CODE  === 4'd0,  "T1 off WDISK_ERR_CODE moved");
    chk(off_WDBUF_ADDR      === 10'd0, "T1 off WDBUF_ADDR moved");
    chk(off_WDBUF_WDATA     === 16'd0, "T1 off WDBUF_WDATA moved");
    chk(off_WDBUF_WE        === 1'b0,  "T1 off WDBUF_WE moved");
  end

  // ------------------------- open-request observation (white box, u_on)
  integer tape_pulse_cnt = 0;   // gen_tape.s_open_pulse high cycles
  integer tape_creq_cnt  = 0;   // a_open_req high cycles
  reg     obs_armed = 1'b0;

  always @(posedge clk_cpu) if (obs_armed) begin
    if (u_on.gen_tape.s_open_pulse === 1'b1) tape_pulse_cnt = tape_pulse_cnt + 1;
    if (u_on.a_open_req            === 1'b1) tape_creq_cnt  = tape_creq_cnt  + 1;
  end

  // ------------------- done-pulse counters, for the independence checks
  integer sd_done_cnt = 0, wd_done_cnt = 0, fd_done_cnt = 0;
  always @(posedge clk_cpu) begin
    if (on_SDISK_DONE === 1'b1) sd_done_cnt = sd_done_cnt + 1;
    if (on_WDISK_DONE === 1'b1) wd_done_cnt = wd_done_cnt + 1;
    if (on_FDISK_DONE === 1'b1) fd_done_cnt = fd_done_cnt + 1;
  end

  // -------------------------------------------------------------- VCD
  initial begin
    $dumpfile("nd_storage_devices_tb.vcd");
    $dumpvars(0, nd_storage_devices_tb);
  end

  // -------------------------------------------------------------- watchdog
  initial begin
    #400_000;
    $display("checks=%0d failures=%0d", checks, errors + 1);
    $display("TB_RESULT: FAIL  (watchdog: testbench did not finish)");
    $finish;
  end

  // -------------------------------------------------------------- helpers
  integer wcount;

  // one-cycle request pulse on the shared SMD seam
  task smd_req(input [2:0] unit, input [15:0] cyl, input [15:0] hs,
               input [10:0] wc, input wr);
    begin
      @(negedge clk_cpu);
      SDISK_UNIT      = unit;
      SDISK_BLKADDR2  = cyl;
      SDISK_BLKADDR1  = hs;
      SDISK_WORDCOUNT = wc;
      SDISK_WR        = wr;
      SDISK_START     = 1'b1;
      SDISK_REQ       = 1'b1;
      @(negedge clk_cpu);
      SDISK_START = 1'b0;
      SDISK_REQ   = 1'b0;
    end
  endtask

  task wd_req(input [2:0] unit, input [15:0] cyl, input [15:0] hs,
              input [10:0] wc, input wr);
    begin
      @(negedge clk_cpu);
      WDISK_UNIT      = unit;
      WDISK_BLKADDR2  = cyl;
      WDISK_BLKADDR1  = hs;
      WDISK_WORDCOUNT = wc;
      WDISK_WR        = wr;
      WDISK_START     = 1'b1;
      WDISK_REQ       = 1'b1;
      @(negedge clk_cpu);
      WDISK_START = 1'b0;
      WDISK_REQ   = 1'b0;
    end
  endtask

  task flp_req(input [1:0] drive, input [15:0] lsect, input [10:0] wc,
               input wr);
    begin
      @(negedge clk_cpu);
      FDISK_DRIVE     = drive;
      FDISK_LSECT     = lsect;
      FDISK_WORDCOUNT = wc;
      FDISK_WR        = wr;
      FDISK_FORMAT    = 2'd3;
      FDISK_REQ       = 1'b1;
      @(negedge clk_cpu);
      FDISK_REQ = 1'b0;
    end
  endtask

  // -------------------------------------------------------------- stimulus
  integer bits_wrapper, bits_storage;

  initial begin
    // ---- reset -----------------------------------------------------------
    repeat (4) @(posedge clk_cpu);
    @(negedge clk_cpu);
    rst_n    = 1'b1;
    t1_armed = 1'b1;      // the excluded wrapper is policed from here on
    obs_armed = 1'b1;

    // ---- T2: the tape one-shot fires exactly once ------------------------
    // nd_storage_devices.v gen_tape: s_open_pulse is set on the first clock
    // out of reset and s_opened latches, so it must never fire again.
    repeat (300) @(posedge clk_cpu);
    chk(tape_pulse_cnt == 1, "T2 tape open one-shot did not fire exactly once");
    chk(tape_creq_cnt  == 1, "T2 tape c_open_req did not pulse exactly once");

    // ---- T3: the held opens are still asserted ---------------------------
    // No card, so open_ok never arrives and s_fopened/s_mopened/s_wopened
    // stay 0: the pulse wires must still be high, and the adapters must
    // still be re-issuing c_open_req every cycle. A single lost pulse is
    // the bug those comments in the wrapper describe.
    chk(u_on.gen_floppy.s_fopen_pulse === 1'b1, "T3 floppy open request dropped");
    chk(u_on.gen_smd.s_mopen_pulse    === 1'b1, "T3 SMD open request dropped");
    chk(u_on.gen_wd.s_wopen_pulse     === 1'b1, "T3 Winchester open request dropped");
    chk(u_on.f_open_req === 1'b1, "T3 floppy c_open_req not held");
    chk(u_on.m_open_req === 1'b1, "T3 SMD c_open_req not held");
    chk(u_on.w_open_req === 1'b1, "T3 Winchester c_open_req not held");

    // ---- T4: SMD request on the matching unit ----------------------------
    // nd_storage_disc_adapter.v S_IDLE: !c_open_ok is the first refusal, so
    // NDS_ERR_NOTOPEN wins over the range test even though c_size_bytes = 0.
    sd_done_cnt = 0; wd_done_cnt = 0; fd_done_cnt = 0;
    smd_req(3'd0, 16'd0, 16'd0, 11'd1024, 1'b0);
    wcount = 0;
    while (!on_SDISK_DONE && wcount < 200) begin
      @(posedge clk_cpu);
      wcount = wcount + 1;
    end
    chk(on_SDISK_DONE === 1'b1, "T4 SMD request never completed");
    chk(on_SDISK_ERR  === 1'b1, "T4 SMD request did not report err");
    chk(on_SDISK_ERR_CODE === `NDS_ERR_NOTOPEN, "T4 SMD code is not NOTOPEN");
    repeat (10) @(posedge clk_cpu);
    chk(sd_done_cnt == 1, "T4 SMD done did not pulse exactly once");
    chk(wd_done_cnt == 0, "T4 an SMD request raised WDISK_DONE (cross-wired)");
    chk(fd_done_cnt == 0, "T4 an SMD request raised FDISK_DONE (cross-wired)");

    // ---- T5: Winchester request on the matching unit ---------------------
    sd_done_cnt = 0; wd_done_cnt = 0; fd_done_cnt = 0;
    wd_req(3'd0, 16'd0, 16'd0, 11'd1024, 1'b0);
    wcount = 0;
    while (!on_WDISK_DONE && wcount < 200) begin
      @(posedge clk_cpu);
      wcount = wcount + 1;
    end
    chk(on_WDISK_DONE === 1'b1, "T5 Winchester request never completed");
    chk(on_WDISK_ERR  === 1'b1, "T5 Winchester request did not report err");
    chk(on_WDISK_ERR_CODE === `NDS_ERR_NOTOPEN, "T5 Winchester code is not NOTOPEN");
    repeat (10) @(posedge clk_cpu);
    chk(wd_done_cnt == 1, "T5 Winchester done did not pulse exactly once");
    chk(sd_done_cnt == 0, "T5 a Winchester request raised SDISK_DONE (cross-wired)");
    chk(fd_done_cnt == 0, "T5 a Winchester request raised FDISK_DONE (cross-wired)");

    // ---- T6: floppy request on the matching drive ------------------------
    // nd_storage_floppy_adapter.v F_IDLE: same refusal order, s_notopen first.
    sd_done_cnt = 0; wd_done_cnt = 0; fd_done_cnt = 0;
    flp_req(2'd0, 16'd0, 11'd1024, 1'b0);
    wcount = 0;
    while (!on_FDISK_DONE && wcount < 200) begin
      @(posedge clk_cpu);
      wcount = wcount + 1;
    end
    chk(on_FDISK_DONE === 1'b1, "T6 floppy request never completed");
    chk(on_FDISK_ERR  === 1'b1, "T6 floppy request did not report err");
    chk(on_FDISK_ERR_CODE === `NDS_ERR_NOTOPEN, "T6 floppy code is not NOTOPEN");
    repeat (10) @(posedge clk_cpu);
    chk(fd_done_cnt == 1, "T6 floppy done did not pulse exactly once");
    chk(sd_done_cnt == 0, "T6 a floppy request raised SDISK_DONE (cross-wired)");
    chk(wd_done_cnt == 0, "T6 a floppy request raised WDISK_DONE (cross-wired)");

    // ---- T7: unit / drive mismatch is ignored completely -----------------
    // Both disc instances are UNIT 0 and the floppy is DRIVE 0, so unit 5 /
    // drive 1 must produce nothing at all - not even an error completion.
    sd_done_cnt = 0; wd_done_cnt = 0; fd_done_cnt = 0;
    smd_req(3'd5, 16'd7, 16'd3, 11'd1024, 1'b0);
    repeat (60) @(posedge clk_cpu);
    chk(sd_done_cnt == 0, "T7 SMD answered a request for another unit");

    wd_req(3'd5, 16'd7, 16'd3, 11'd1024, 1'b0);
    repeat (60) @(posedge clk_cpu);
    chk(wd_done_cnt == 0, "T7 Winchester answered a request for another unit");

    flp_req(2'd1, 16'd0, 11'd1024, 1'b0);
    repeat (60) @(posedge clk_cpu);
    chk(fd_done_cnt == 0, "T7 floppy answered a request for another drive");

    // ---- T8: the tape's sticky diagnostic seam ---------------------------
    // nd_storage_tape_adapter.v A_IDLE: a byte request with nothing mounted
    // is answered with SILENCE towards ND_TAPE_400 and the reason on the
    // TDISK_* pair - the only place a tape fault can be seen at all.
    chk(on_TDISK_FAULT === 1'b0, "T8 TDISK_FAULT set before any byte request");
    @(negedge clk_cpu) byte_req = 1'b1;
    @(negedge clk_cpu) byte_req = 1'b0;
    repeat (20) @(posedge clk_cpu);
    chk(on_TDISK_FAULT === 1'b1, "T8 TDISK_FAULT did not latch");
    chk(on_TDISK_ERR_CODE === `NDS_ERR_NOTOPEN, "T8 TDISK_ERR_CODE is not NOTOPEN");
    chk(on_byte_valid === 1'b0, "T8 byte_valid asserted with nothing mounted");

    // ---- T9: the media-format decode really is in the generate -----------
    // gen_floppy computes it from the client's size; with no mount the size
    // is 0, which is not the 315392-byte 8-inch image, so the 1.2 MB
    // descriptor 4'hF is what the RTL produces. Characterisation of that
    // decode - and proof the two generates differ, since u_off holds 4'h0
    // (that half is already policed continuously by T1).
    chk(on_FDISK_MEDIA_FMT === 4'hF, "T9 included FDISK_MEDIA_FMT is not 4'hF");

    // ---- T10: client-count agreement -------------------------------------
    // The wrapper's N and nd_storage's N_CLIENTS are separate numbers joined
    // by a named port connection, so a mismatch pads or truncates silently.
    // Comparing the widths catches it at elaboration value, not by luck.
    bits_wrapper = $bits(u_on.size_bytes_w);
    bits_storage = $bits(u_on.u_nd_storage.size_bytes);
    chk(bits_wrapper == bits_storage,
        "T10 size_bytes width differs between wrapper and nd_storage");
    chk($bits(u_on.open_ok_w) == $bits(u_on.u_nd_storage.open_ok),
        "T10 open_ok width differs between wrapper and nd_storage");
    chk($bits(u_on.buf_addr_w) == $bits(u_on.u_nd_storage.buf_addr),
        "T10 buf_addr width differs between wrapper and nd_storage");
    chk($bits(u_on.err_code_w) == $bits(u_on.u_nd_storage.err_code),
        "T10 err_code width differs between wrapper and nd_storage");
    chk(bits_wrapper == 8 * 32, "T10 client count is not 8");

    // ---- verdict ----------------------------------------------------------
    repeat (4) @(posedge clk_cpu);
    $display("checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire
