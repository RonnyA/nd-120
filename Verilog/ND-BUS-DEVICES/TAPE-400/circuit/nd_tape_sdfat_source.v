/****************************************************************************
** nd_tape_sdfat_source - board-agnostic BOOT.BPUN byte source for the     **
** ND_TAPE_400 paper-tape device, backed by the SD-FAT storage stack.      **
**                                                                         **
** Packages, in one reusable block for BOTH the Verilator sim and the      **
** Tang hardware top:                                                      **
**   nd_storage             (SD-FAT mount + reader + engine; client 0 =    **
**                           BOOT.BPUN, preloaded into the SDRAM region)   **
**   nd_storage_tape_adapter(serves that file to ND_TAPE_400's byte source **
**                           port, big-endian, read-only)                  **
**   a mount->open sequencer(pulses the adapter's open_start ONCE after    **
**                           the mount reports OK)                         **
**                                                                         **
** The instantiating top supplies the physical backends:                   **
**   - SD pads  (sim: sd_card_model.v with IMAGE=nd_boot_card.img;         **
**               Tang: the real SD card)                                   **
**   - SDRAM device port mem_* (sim: nds_mem_model.v; Tang: the SDRAM      **
**     bridge, same contract as nds_mem_model.v / MEM_RAM_49_SDRAM.v)      **
**   - the byte source port wires straight to ND_TAPE_400 (byte_req /      **
**     byte_valid / byte_data / source_rewind, pin-for-pin).               **
**                                                                         **
** Two clocks (as nd_storage requires): clk_stor (SD/SDRAM domain) and     **
** clk_cpu (the ND-120 bus/client domain). sd_status is 2-FF synchronized  **
** into clk_cpu before it gates the one-shot open.                         **
**                                                                         **
** Only client 0 is used; clients 1-6 are tied idle. PRELOAD_MASK = 1 so   **
** only BOOT.BPUN is preloaded (the boot card carries no other files).     **
**                                                                         **
** Ronny Hansen                                                            **
*****************************************************************************/

module nd_tape_sdfat_source #(
    parameter SIMULATE = 0   // 1 = short SD init (Verilator), 0 = real card
) (
    input  wire clk_stor,
    input  wire rst_stor_n,
    input  wire clk_cpu,
    input  wire rst_cpu_n,

    // ND_TAPE_400 byte source port (pin-for-pin)
    input  wire       byte_req,
    output wire       byte_valid,
    output wire [7:0] byte_data,
    input  wire       source_rewind,

    // SD pads (single tristate resolved at the top)
    output wire       sd_clk_o,
    input  wire       sd_cmd_i,
    output wire       sd_cmd_o,
    output wire       sd_cmd_oe,
    input  wire       sd_dat0_i,
    output wire       sd_dat0_o,
    output wire       sd_dat0_oe,

    // SDRAM device port (clk_stor domain) - same contract as nds_mem_model.v
    output wire        mem_start,
    output wire        mem_we,
    output wire [19:0] mem_addr,
    output wire [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,
    input  wire        mem_busy,
    input  wire        mem_done,

    // status passthrough (board LEDs / debug)
    output wire [1:0]  sd_status
);

  localparam N = 7;  // nd_storage's fixed client count

  // ---- flattened client-port buses; only client 0 is driven/used ----
  wire [N-1:0]    open_req_w, open_ok_w, open_err_w, req_w, wr_w;
  wire [N-1:0]    busy_w, done_w, err_w, buf_we_w;
  wire [N*32-1:0] size_bytes_w;
  wire [N*16-1:0] block_w, buf_wdata_w, buf_rdata_w;
  wire [N*10-1:0] buf_addr_w;

  // client 0 <-> tape adapter
  wire        a_open_ok, a_open_err;
  wire        a_open_req, a_req, a_wr, a_busy, a_done, a_err;
  wire [31:0] a_size_bytes;
  wire [15:0] a_block, a_buf_wdata, a_buf_rdata;
  wire [9:0]  a_buf_addr;
  wire        a_buf_we;
  wire        a_open_start;

  // drive client 0 slices; tie clients 1..6 idle
  assign open_req_w = {{(N-1){1'b0}}, a_open_req};
  assign req_w      = {{(N-1){1'b0}}, a_req};
  assign wr_w       = {{(N-1){1'b0}}, a_wr};
  assign block_w    = {{((N-1)*16){1'b0}}, a_block};
  assign buf_rdata_w= {{((N-1)*16){1'b0}}, a_buf_rdata};

  assign a_open_ok    = open_ok_w[0];
  assign a_open_err   = open_err_w[0];
  assign a_size_bytes = size_bytes_w[31:0];
  assign a_busy       = busy_w[0];
  assign a_done       = done_w[0];
  assign a_err        = err_w[0];
  assign a_buf_addr   = buf_addr_w[9:0];
  assign a_buf_wdata  = buf_wdata_w[15:0];
  assign a_buf_we     = buf_we_w[0];

  // ---- one-shot open sequencer (clk_cpu domain) ----
  // FIXED 14-JUL-2026 (first time this module was ever instantiated): the
  // open must NOT wait for sd_status == OK. That was a DEADLOCK.
  //
  //   nd_storage_mount M_IDLE "wait for mnt_start" (nd_storage_mount.v:8) -
  //   a mount only runs when a client asserts open_req, and sd_status is only
  //   "updated at every mount end" (nd_storage.v:35). So gating the open on
  //   sd_status==OK meant: no open -> no mount -> status stays NOTCHK(0)
  //   forever -> no open. The SD clock never even toggled.
  //
  // The mount IS the card bring-up (CMD0/CMD8/ACMD41, FAT scan, preload);
  // sd_status is its RESULT, not its precondition. Every proven testbench
  // drives open_start directly and checks status afterwards - do the same:
  // pulse open once, one cycle after reset release.
  reg s_opened, s_open_pulse;
  always @(posedge clk_cpu or negedge rst_cpu_n)
    if (!rst_cpu_n) begin s_opened <= 1'b0; s_open_pulse <= 1'b0; end
    else begin
      s_open_pulse <= 1'b0;
      if (!s_opened) begin
        s_open_pulse <= 1'b1;   // open BOOT.BPUN once; the mount does the rest
        s_opened     <= 1'b1;
      end
    end
  assign a_open_start = s_open_pulse;

  // ---- the tape adapter (client 0 -> ND_TAPE_400 byte source) ----
  nd_storage_tape_adapter u_tape_adapter (
      .clk_cpu      (clk_cpu),
      .rst_n        (rst_cpu_n),
      .byte_req     (byte_req),
      .byte_valid   (byte_valid),
      .byte_data    (byte_data),
      .source_rewind(source_rewind),
      .open_start   (a_open_start),
      .c_open_req   (a_open_req),
      .c_open_ok    (a_open_ok),
      .c_open_err   (a_open_err),
      .c_size_bytes (a_size_bytes),
      .c_req        (a_req),
      .c_wr         (a_wr),
      .c_block      (a_block),
      .c_busy       (a_busy),
      .c_done       (a_done),
      .c_err        (a_err),
      .c_buf_addr   (a_buf_addr),
      .c_buf_wdata  (a_buf_wdata),
      .c_buf_we     (a_buf_we),
      .c_buf_rdata  (a_buf_rdata)
  );

  // ---- the SD-FAT storage engine, BOOT.BPUN as client 0 ----
  nd_storage #(
      .SIMULATE    (SIMULATE),
      .PRELOAD_MASK (7'b0000001),           // preload only client 0 (BOOT.BPUN)
      .FILE0_NAME  ("BOOT.BPUN"), .FILE0_LEN(8'd9)
  ) u_nd_storage (
      .clk_stor  (clk_stor),
      .rst_stor_n(rst_stor_n),
      .clk_cpu   (clk_cpu),
      .rst_cpu_n (rst_cpu_n),
      .sd_clk_o  (sd_clk_o),
      .sd_cmd_i  (sd_cmd_i),
      .sd_cmd_o  (sd_cmd_o),
      .sd_cmd_oe (sd_cmd_oe),
      .sd_dat0_i (sd_dat0_i),
      .sd_dat0_o (sd_dat0_o),
      .sd_dat0_oe(sd_dat0_oe),
      .mem_start (mem_start),
      .mem_we    (mem_we),
      .mem_addr  (mem_addr),
      .mem_wdata (mem_wdata),
      .mem_rdata (mem_rdata),
      .mem_busy  (mem_busy),
      .mem_done  (mem_done),
      .open_req  (open_req_w),
      .open_ok   (open_ok_w),
      .open_err  (open_err_w),
      .size_bytes(size_bytes_w),
      .req       (req_w),
      .wr        (wr_w),
      .block     (block_w),
      .busy      (busy_w),
      .done      (done_w),
      .err       (err_w),
      .buf_addr  (buf_addr_w),
      .buf_wdata (buf_wdata_w),
      .buf_we    (buf_we_w),
      .buf_rdata (buf_rdata_w),
      .sd_status (sd_status),
      .card_type (),
      .fs_type   ()
  );

endmodule
