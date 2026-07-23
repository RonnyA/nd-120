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
    parameter SIMULATE       = 0,  // 1 = short SD init (Verilator), 0 = real card
    parameter INCLUDE_TAPE   = 1,  // 1 = serve BOOT.BPUN to ND_TAPE_400 (client 0)
    parameter INCLUDE_FLOPPY = 0,  // 1 = also serve FLOPPY1.IMG to the DMA floppy
    // client-0 (tape) file name on the card. Default BOOT.BPUN (the boot tape);
    // a tb can point it at another 8.3 name on a shared test image.
    parameter [52*8-1:0] BOOT_NAME = "BOOT.BPUN",
    parameter [7:0]      BOOT_LEN  = 8'd9
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

    // ND_FLOPPY_DMA disk-image backend seam (client 1 = FLOPPY1.IMG). Present
    // regardless; driven only when INCLUDE_FLOPPY=1, tied idle otherwise. Wired
    // pin-for-pin to ND120_CORE's FDISK_*/FDBUF_* (nd_storage_floppy_adapter).
    input  wire        FDISK_REQ,
    input  wire        FDISK_WR,
    input  wire [15:0] FDISK_LSECT,
    input  wire [ 1:0] FDISK_FORMAT,
    input  wire [ 1:0] FDISK_DRIVE,
    input  wire [10:0] FDISK_WORDCOUNT,
    output wire        FDISK_DONE,
    output wire        FDISK_ERR,
    output wire [ 3:0] FDISK_MEDIA_FMT,
    output wire [ 9:0] FDBUF_ADDR,
    output wire [15:0] FDBUF_WDATA,
    output wire        FDBUF_WE,
    input  wire [15:0] FDBUF_RDATA,

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

  // client 1 <-> floppy adapter (driven in the INCLUDE_FLOPPY generate below,
  // tied idle otherwise)
  wire        f_open_req, f_req, f_wr;
  wire [15:0] f_block, f_buf_rdata;

  // drive client 0 (tape) and client 1 (floppy) slices; tie clients 2..6 idle
  assign open_req_w = {{(N-2){1'b0}}, f_open_req,  a_open_req};
  assign req_w      = {{(N-2){1'b0}}, f_req,       a_req};
  assign wr_w       = {{(N-2){1'b0}}, f_wr,        a_wr};
  assign block_w    = {{((N-2)*16){1'b0}}, f_block,      a_block};
  assign buf_rdata_w= {{((N-2)*16){1'b0}}, f_buf_rdata,  a_buf_rdata};

  assign a_open_ok    = open_ok_w[0];
  assign a_open_err   = open_err_w[0];
  assign a_size_bytes = size_bytes_w[31:0];
  assign a_busy       = busy_w[0];
  assign a_done       = done_w[0];
  assign a_err        = err_w[0];
  assign a_buf_addr   = buf_addr_w[9:0];
  assign a_buf_wdata  = buf_wdata_w[15:0];
  assign a_buf_we     = buf_we_w[0];

  // ---- the tape adapter (client 0 -> ND_TAPE_400 byte source), OPTIONAL ----
  // Floppy-only builds (INCLUDE_TAPE=0) drop the tape entirely; the floppy
  // (client 1) then triggers the mount on its own. When both are in, the tape
  // open triggers the mount and the floppy open (held, below) follows.
  generate
    if (INCLUDE_TAPE) begin : gen_tape
      // one-shot open sequencer (clk_cpu). Do NOT gate on sd_status==OK: that
      // deadlocks (no open -> no mount -> status never updates). The mount IS
      // the card bring-up (CMD0/CMD8/ACMD41, FAT scan, preload); pulse open once
      // after reset and check status afterwards, as every proven tb does.
      reg s_opened, s_open_pulse;
      always @(posedge clk_cpu or negedge rst_cpu_n)
        if (!rst_cpu_n) begin s_opened <= 1'b0; s_open_pulse <= 1'b0; end
        else begin
          s_open_pulse <= 1'b0;
          if (!s_opened) begin s_open_pulse <= 1'b1; s_opened <= 1'b1; end
        end

      nd_storage_tape_adapter u_tape_adapter (
          .clk_cpu      (clk_cpu),
          .rst_n        (rst_cpu_n),
          .byte_req     (byte_req),
          .byte_valid   (byte_valid),
          .byte_data    (byte_data),
          .source_rewind(source_rewind),
          .open_start   (s_open_pulse),
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
    end else begin : gen_no_tape
      // tape excluded: client 0 idle, byte source outputs quiet
      assign a_open_req  = 1'b0;
      assign a_req       = 1'b0;
      assign a_wr        = 1'b0;
      assign a_block     = 16'd0;
      assign a_buf_rdata = 16'd0;
      assign byte_valid  = 1'b0;
      assign byte_data   = 8'd0;
    end
  endgenerate

  // ---- the floppy adapter (client 1 -> ND_FLOPPY_DMA disk-image backend) ----
  generate
    if (INCLUDE_FLOPPY) begin : gen_floppy
      // Open FLOPPY1.IMG (client 1). The tape (client 0) and floppy open
      // requests both fire at reset, but nd_storage services only ONE client's
      // open per mount and the adapters only PULSE c_open_req (they do not hold
      // it), so a single floppy pulse coincident with the tape's is lost. HOLD
      // open_start high (the adapter re-pulses c_open_req every cycle) until the
      // client reports open - nd_storage picks it up once it is idle after the
      // tape-triggered mount. No deadlock: the tape open still triggers the mount.
      reg s_fopened;
      always @(posedge clk_cpu or negedge rst_cpu_n)
        if (!rst_cpu_n) s_fopened <= 1'b0;
        else if (open_ok_w[1]) s_fopened <= 1'b1;
      wire s_fopen_pulse = !s_fopened;

      // media format from the FLOPPY1.IMG size, matching the C reference
      // (simDevices/NDBus.cpp / deviceFloppyDMA.c READ FORMAT): 315392 B =
      // 8-inch 512 B/sector -> 0x0; else the 1.2 MB 1024 B/sector double-
      // sided/double-density descriptor -> 0xF. Only READ FORMAT reads it;
      // the 1560& boot forces format 3, so this does not gate boot.
      wire [31:0] f_size = size_bytes_w[63:32];
      assign FDISK_MEDIA_FMT = (f_size == 32'd315392) ? 4'h0 : 4'hF;

      nd_storage_floppy_adapter #(.DRIVE(2'd0)) u_floppy_adapter (
          .clk_cpu       (clk_cpu),
          .rst_n         (rst_cpu_n),
          .disk_req      (FDISK_REQ),
          .disk_wr       (FDISK_WR),
          .disk_lsect    (FDISK_LSECT),
          .disk_format   (FDISK_FORMAT),
          .disk_drive    (FDISK_DRIVE),
          .disk_wordcount(FDISK_WORDCOUNT),
          .disk_done     (FDISK_DONE),
          .disk_err      (FDISK_ERR),
          .dbuf_addr     (FDBUF_ADDR),
          .dbuf_wdata    (FDBUF_WDATA),
          .dbuf_we       (FDBUF_WE),
          .dbuf_rdata    (FDBUF_RDATA),
          .open_start    (s_fopen_pulse),
          .c_open_req    (f_open_req),
          .c_open_ok     (open_ok_w[1]),
          .c_open_err    (open_err_w[1]),
          .c_size_bytes  (f_size),
          .c_req         (f_req),
          .c_wr          (f_wr),
          .c_block       (f_block),
          .c_busy        (busy_w[1]),
          .c_done        (done_w[1]),
          .c_err         (err_w[1]),
          .c_buf_addr    (buf_addr_w[19:10]),
          .c_buf_wdata   (buf_wdata_w[31:16]),
          .c_buf_we      (buf_we_w[1]),
          .c_buf_rdata   (f_buf_rdata)
      );
    end else begin : gen_no_floppy
      // floppy excluded: client 1 idle, backend seam driven to safe defaults
      assign f_open_req      = 1'b0;
      assign f_req           = 1'b0;
      assign f_wr            = 1'b0;
      assign f_block         = 16'd0;
      assign f_buf_rdata     = 16'd0;
      assign FDISK_DONE      = 1'b0;
      assign FDISK_ERR       = 1'b0;
      assign FDISK_MEDIA_FMT = 4'd0;
      assign FDBUF_ADDR      = 10'd0;
      assign FDBUF_WDATA     = 16'd0;
      assign FDBUF_WE        = 1'b0;
    end
  endgenerate

  // ---- the SD-FAT storage engine, BOOT.BPUN as client 0 ----
  nd_storage #(
      .SIMULATE    (SIMULATE),
      // preload the served clients: client 0 (BOOT.BPUN) when tape is in,
      // client 1 (FLOPPY1.IMG) when floppy is in - staged reads from the region
      .PRELOAD_MASK ((INCLUDE_TAPE ? 7'b0000001 : 7'b0000000) |
                     (INCLUDE_FLOPPY ? 7'b0000010 : 7'b0000000)),
      .FILE0_NAME  (BOOT_NAME), .FILE0_LEN(BOOT_LEN)
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
