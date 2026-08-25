/****************************************************************************
** Nexys 4 DDR / Nexys A7-100T top level for the ND-120                     **
**                                                                         **
** Modelled on the Tang Nano 20K top (fpga/tang-nano-20k/src/               **
** ND120_TANG20K_TOP.v): it instantiates ND120_CORE directly - not          **
** ND120_TOP - because the ND-BUS device chain (papertape, floppy,          **
** Winchester) only exists on the core, and hangs nd_storage_devices off    **
** those seams so the devices are served from real images on the microSD    **
** card.                                                                    **
**                                                                         **
** DEVICES INCLUDED                                                         **
**   TAPE-400   papertape at 400   - BOOT.TAP                              **
**   FLOPPY     DMA floppy at 1560 - FLOPPY1.IMG / FLOPPY2.IMG             **
**   WINCHESTER ST506 disc at 500  - WD0.IMG / WD1.IMG                     **
**   (SMD at 1540 is left out - Ronny asked for these three. On the Tang    **
**    SMD and Winchester are mutually exclusive for want of one BSRAM       **
**    block; this part has 135 tiles against the Tang's 46, so that         **
**    constraint does not apply here and SMD could be added later.)         **
**                                                                         **
** STORAGE REGION - CACHED READS, WRITE THROUGH                             **
**   nd_storage's Phase-4 tag directory (SD-FAT/circuit/nd_storage_cache.v) **
**   uses a 4 MB region as a CACHE of arbitrarily large images: the disc    **
**   classes are cached, tape and floppy go direct to the card, and writes  **
**   go through to the card. Same behaviour as the Tang.                    **
**                                                                         **
**   WHERE the region lives is the board difference. The Tang has one SDRAM **
**   chip shared with CPU main memory, so its region is reached through     **
**   MEM_RAM_49_SDRAM's ND_STORAGE_PORT. Here main memory is BRAM and the   **
**   DDR2 is otherwise unused, so the region connects straight to           **
**   ddr2/nd_ddr2_port.v through ddr2/nd_ddr2_storage.v - no detour through **
**   the CPU memory path. When main memory later moves into DDR2,           **
**   nd_ddr2_port is where the two clients get arbitrated.                  **
**                                                                         **
** CLOCKS - one MMCM, VCO 1000 MHz from the 100 MHz oscillator:             **
**   clk_cpu   1000/60 = 16.667 MHz  CPU, bus, OSC and the device chain     **
**   clk_stor  1000/37 = 27.027 MHz  SD/FAT stack, at its proven divisors   **
**   clk200    1000/5  = 200 MHz     the DDR2 controller's input            **
**   The three are declared asynchronous in build.tcl; every crossing is a  **
**   two-flop synchroniser or a toggle handshake.                           **
**                                                                         **
** MAIN MEMORY is BRAM (MAIN_RAM_BLOCKRAM), same as the Basys3 and Cmod     **
** builds. Moving it to DDR2 is EXTENSIONS-PLAN.md stage 2 and is gated on  **
** the read-latency number the SD tool's M command measures.                **
**                                                                         **
** Build: vivado -mode batch -source build.tcl   (see README.md)            **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`default_nettype none

module nd120_nexys4ddr_top (
    input wire clk100,      // E3, 100 MHz oscillator
    input wire cpu_resetn,  // C12, red CPU RESET button (ACTIVE LOW)
    input wire btnc,        // N17, centre button

    input  wire [15:0] sw,  // sw[0] = 7-segment source select
    input  wire        uart_txd_in,   // C4, PC -> FPGA
    output wire        uart_rxd_out,  // D4, FPGA -> PC

    output wire [15:0] led,
    output wire        ca, cb, cc, cd, ce, cf, cg, dp,
    output wire [ 7:0] an,

    // On-board microSD slot
    output wire sd_reset,  // E2, LOW powers the slot
    input  wire sd_cd,     // A1, card detect
    output wire sd_clk,    // B1
    inout  wire sd_cmd,    // C1
    inout  wire sd_dat0,   // C2
    inout  wire sd_dat1,   // E1
    inout  wire sd_dat2,   // F1
    inout  wire sd_dat3,   // D2

    // DDR2 - the storage region
    inout  wire [15:0] ddr2_dq,
    inout  wire [ 1:0] ddr2_dqs_p,
    inout  wire [ 1:0] ddr2_dqs_n,
    output wire [12:0] ddr2_addr,
    output wire [ 2:0] ddr2_ba,
    output wire        ddr2_ras_n,
    output wire        ddr2_cas_n,
    output wire        ddr2_we_n,
    output wire [ 0:0] ddr2_ck_p,
    output wire [ 0:0] ddr2_ck_n,
    output wire [ 0:0] ddr2_cke,
    output wire [ 0:0] ddr2_cs_n,
    output wire [ 1:0] ddr2_dm,
    output wire [ 0:0] ddr2_odt
);

  /**********************************************
  *  Clocks                                     *
  ***********************************************/
  wire clk_cpu_pre, clk_stor_pre, clk200_pre;
  wire clkfb_out, clkfb_in, mmcm_locked;
  wire clk_cpu, clk_stor, clk200;

`ifndef ND120_N4DDR_MMCM_DIV
  `define ND120_N4DDR_MMCM_DIV 60.0
`endif

  MMCME2_BASE #(
      .BANDWIDTH       ("OPTIMIZED"),
      .CLKFBOUT_MULT_F (10.0),   // VCO = 100 * 10 = 1000 MHz
      .CLKIN1_PERIOD   (10.0),
      .CLKOUT0_DIVIDE_F(`ND120_N4DDR_MMCM_DIV),  // CPU / bus
      .CLKOUT1_DIVIDE  (37),     // 27.027 MHz - SD/FAT stack
      .CLKOUT2_DIVIDE  (5),      // 200 MHz    - DDR2 controller
      .DIVCLK_DIVIDE   (1),
      .STARTUP_WAIT    ("FALSE")
  ) mmcm (
      .CLKIN1  (clk100),
      .CLKFBIN (clkfb_in),
      .CLKFBOUT(clkfb_out),
      .CLKOUT0 (clk_cpu_pre),
      .CLKOUT1 (clk_stor_pre),
      .CLKOUT2 (clk200_pre),
      .LOCKED  (mmcm_locked),
      .PWRDWN  (1'b0),
      .RST     (1'b0)
  );
  BUFG bufg_fb  (.I(clkfb_out),    .O(clkfb_in));
  BUFG bufg_cpu (.I(clk_cpu_pre),  .O(clk_cpu));
  BUFG bufg_st  (.I(clk_stor_pre), .O(clk_stor));
  // MIG's project sets SystemClock = "No Buffer", so this must arrive buffered
  BUFG bufg_200 (.I(clk200_pre),   .O(clk200));

  /**********************************************
  *  Reset                                      *
  *  Held while either button is down or the    *
  *  MMCM is unlocked, then released after a    *
  *  counter in each domain.                    *
  ***********************************************/
  wire rst_req_n = cpu_resetn & ~btnc & mmcm_locked;

  reg [7:0] por_cpu = 8'd0;
  reg       sys_rst_n_r = 1'b0;
  always @(posedge clk_cpu) begin
    if (!rst_req_n) begin
      por_cpu     <= 8'd0;
      sys_rst_n_r <= 1'b0;
    end else if (por_cpu != 8'hFF) begin
      por_cpu <= por_cpu + 8'd1;
    end else begin
      sys_rst_n_r <= 1'b1;
    end
  end
  wire sys_rst_n = sys_rst_n_r;

  reg [7:0] por_stor = 8'd0;
  reg       rst_stor_n_r = 1'b0;
  always @(posedge clk_stor) begin
    if (!rst_req_n) begin
      por_stor     <= 8'd0;
      rst_stor_n_r <= 1'b0;
    end else if (por_stor != 8'hFF) begin
      por_stor <= por_stor + 8'd1;
    end else begin
      rst_stor_n_r <= 1'b1;
    end
  end
  wire rst_stor_n = rst_stor_n_r;

  /**********************************************
  *  ND-BUS tie-offs: no external bus here      *
  ***********************************************/
  wire        BREQ_n = 1'b1, POWSENSE_n = 1'b1;
  wire        BINT10_n = 1'b1, BINT11_n = 1'b1, BINT12_n = 1'b1;
  wire        BINT13_n = 1'b1, BINT15_n = 1'b1;
  wire [23:0] BD_23_0_n_IN = 24'hFFFFFF;
  wire        SEMRQ_n_IN = 1'b1, BINPUT_n_IN = 1'b1, BDAP_n_IN = 1'b1;
  wire        BDRY_n_IN = 1'b1, BAPR_n_IN = 1'b1;

  /**********************************************
  *  Device seams between the core and storage  *
  ***********************************************/
  wire        TAPE_BYTE_REQ, TAPE_REWIND;
  wire        s_tape_byte_valid;
  wire [ 7:0] s_tape_byte_data;

  wire        FDISK_REQ, FDISK_WR, FDISK_DONE, FDISK_ERR, FDBUF_WE;
  wire [15:0] FDISK_LSECT, FDBUF_WDATA, FDBUF_RDATA;
  wire [ 1:0] FDISK_FORMAT, FDISK_DRIVE;
  wire [10:0] FDISK_WORDCOUNT;
  wire [ 3:0] FDISK_ERR_CODE, FDISK_MEDIA_FMT;
  wire [ 9:0] FDBUF_ADDR;

  wire        WDISK_START, WDISK_REQ, WDISK_WR, WDISK_DONE, WDISK_ERR, WDBUF_WE;
  wire [15:0] WDISK_BLKADDR1, WDISK_BLKADDR2, WDBUF_WDATA, WDBUF_RDATA;
  wire [ 2:0] WDISK_UNIT;
  wire [10:0] WDISK_WORDCOUNT;
  wire [ 3:0] WDISK_ERR_CODE;
  wire [ 9:0] WDBUF_ADDR;

  // SMD is not built into this bitstream; its seam is tied inactive
  wire        SDISK_START, SDISK_REQ, SDISK_WR;
  wire [15:0] SDISK_BLKADDR1, SDISK_BLKADDR2, SDBUF_RDATA;
  wire [ 2:0] SDISK_UNIT;
  wire [10:0] SDISK_WORDCOUNT;

  /**********************************************
  *  Status / debug                             *
  ***********************************************/
  wire [ 6:0] s_cpu_led;
  wire        s_run;
  wire [12:0] CSA_12_0;
  wire [ 3:0] s_pil;
  wire [13:0] s_debug_la_23_10;
  wire [ 9:0] s_debug_ca_9_0;
  wire [ 4:0] s_debug_cc_term;
  wire        s_debug_mclk, s_debug_lcs_n, s_debug_fetch;
  wire        s_debug_mr_n, s_debug_clear_n, s_debug_refrq_n;
  wire        s_debug_intrq_n, s_debug_powfail_n;
  wire [15:0] s_debug_fidbo, s_ireq_15_0_n, s_xmic_dbg;
`ifdef ND120_ILA_MARK_DEBUG
  (* mark_debug = "true" *)   // keep the name for the ILA (build.tcl ila flag)
`endif
  wire        cpu_txd;
  wire [15:0] DMA_RDATA;
  wire        DMA_ACK, DMA_ERR, DMA_BUSY;

  assign uart_rxd_out = cpu_txd;

  /**********************************************
  *  The ND-120 core with its device chain      *
  ***********************************************/
  ND120_CORE #(
      .INCLUDE_TAPE  (1),
      .INCLUDE_FLOPPY(1),
      .INCLUDE_SMD   (0),
      .INCLUDE_WD    (1)
  ) CORE (
      .clk_cpu  (clk_cpu),
      .sys_rst_n(sys_rst_n),

      .BREQ_n       (BREQ_n),
      .BINT10_n     (BINT10_n),
      .BINT11_n     (BINT11_n),
      .BINT12_n     (BINT12_n),
      .BINT13_n     (BINT13_n),
      .BINT15_n     (BINT15_n),
      .POWSENSE_n   (POWSENSE_n),
      .BD_23_0_n_IN (BD_23_0_n_IN),
      .BD_23_0_n_OUT(),
      .SEMRQ_n_IN   (SEMRQ_n_IN),
      .SEMRQ_n_OUT  (),
      .BINPUT_n_IN  (BINPUT_n_IN),
      .BINPUT_n_OUT (),
      .BDAP_n_IN    (BDAP_n_IN),
      .BDAP_n_OUT   (),
      .BDRY_n_IN    (BDRY_n_IN),
      .BDRY_n_OUT   (),
      .BAPR_n_IN    (BAPR_n_IN),
      .BAPR_n_OUT   (),
      .BREF_n       (),
      .BERROR_n     (),
      .BINACK_n     (),
      .BIOXE_n      (),
      .BMEM_n       (),
      .OUTGRANT_n   (),
      .OUTIDENT_n   (),
      .MCL          (),

      .RXD(uart_txd_in),
      .TXD(cpu_txd),

      .TAPE_BYTE_REQ  (TAPE_BYTE_REQ),
      .TAPE_BYTE_VALID(s_tape_byte_valid),
      .TAPE_BYTE_DATA (s_tape_byte_data),
      .TAPE_REWIND    (TAPE_REWIND),

      .DMA_REQ  (1'b0),
      .DMA_WR   (1'b0),
      .DMA_ADDR (24'd0),
      .DMA_WDATA(16'd0),
      .DMA_RDATA(DMA_RDATA),
      .DMA_ACK  (DMA_ACK),
      .DMA_ERR  (DMA_ERR),
      .DMA_BUSY (DMA_BUSY),

      .FDISK_REQ      (FDISK_REQ),
      .FDISK_WR       (FDISK_WR),
      .FDISK_LSECT    (FDISK_LSECT),
      .FDISK_FORMAT   (FDISK_FORMAT),
      .FDISK_DRIVE    (FDISK_DRIVE),
      .FDISK_WORDCOUNT(FDISK_WORDCOUNT),
      .FDISK_DONE     (FDISK_DONE),
      .FDISK_ERR      (FDISK_ERR),
      .FDISK_ERR_CODE (FDISK_ERR_CODE),
      .FDISK_MEDIA_FMT(FDISK_MEDIA_FMT),
      .FDBUF_ADDR     (FDBUF_ADDR),
      .FDBUF_WDATA    (FDBUF_WDATA),
      .FDBUF_WE       (FDBUF_WE),
      .FDBUF_RDATA    (FDBUF_RDATA),

      // SMD absent from this build: outputs left open, inputs inactive
      .SDISK_START    (SDISK_START),
      .SDISK_REQ      (SDISK_REQ),
      .SDISK_WR       (SDISK_WR),
      .SDISK_BLKADDR1 (SDISK_BLKADDR1),
      .SDISK_BLKADDR2 (SDISK_BLKADDR2),
      .SDISK_UNIT     (SDISK_UNIT),
      .SDISK_WORDCOUNT(SDISK_WORDCOUNT),
      .SDISK_DONE     (1'b0),
      .SDISK_ERR      (1'b0),
      .SDISK_ERR_CODE (4'd0),
      .SDBUF_ADDR     (10'd0),
      .SDBUF_WDATA    (16'd0),
      .SDBUF_WE       (1'b0),
      .SDBUF_RDATA    (SDBUF_RDATA),

      .WDISK_START    (WDISK_START),
      .WDISK_REQ      (WDISK_REQ),
      .WDISK_WR       (WDISK_WR),
      .WDISK_BLKADDR1 (WDISK_BLKADDR1),
      .WDISK_BLKADDR2 (WDISK_BLKADDR2),
      .WDISK_UNIT     (WDISK_UNIT),
      .WDISK_WORDCOUNT(WDISK_WORDCOUNT),
      .WDISK_DONE     (WDISK_DONE),
      .WDISK_ERR      (WDISK_ERR),
      .WDISK_ERR_CODE (WDISK_ERR_CODE),
      .WDBUF_ADDR     (WDBUF_ADDR),
      .WDBUF_WDATA    (WDBUF_WDATA),
      .WDBUF_WE       (WDBUF_WE),
      .WDBUF_RDATA    (WDBUF_RDATA),

      .LED              (s_cpu_led),
      .RUN_n            (s_run),
      .CSA_12_0         (CSA_12_0),
      .PIL              (s_pil),
      .LA_23_10         (s_debug_la_23_10),
      .CA_9_0           (s_debug_ca_9_0),
      .DEBUG_CC_TERM    (s_debug_cc_term),
      .DEBUG_MCLK       (s_debug_mclk),
      .DEBUG_LCS_n      (s_debug_lcs_n),
      .DEBUG_FETCH      (s_debug_fetch),
      .DEBUG_MR_n       (s_debug_mr_n),
      .DEBUG_CLEAR_n    (s_debug_clear_n),
      .DEBUG_REFRQ_n    (s_debug_refrq_n),
      .DEBUG_INTRQ_n    (s_debug_intrq_n),
      .DEBUG_POWFAIL_n  (s_debug_powfail_n),
      .DEBUG_FIDBO_15_0 (s_debug_fidbo),
      .DEBUG_IREQ_15_0_N(s_ireq_15_0_n),
      .XMIC_DBG_15_0    (s_xmic_dbg)
  );

  /**********************************************
  *  Storage: images on the microSD card        *
  ***********************************************/
  // The slot's power gate. Reference manual section 12: after configuration
  // the on-board microcontroller releases the SD bus and SD_RESET must be
  // driven LOW by the FPGA to power the slot. Without this nothing mounts.
  assign sd_reset = 1'b0;

  wire s_sd_clk_o;
  wire s_sd_cmd_o, s_sd_cmd_oe;
  wire s_sd_dat0_o, s_sd_dat0_oe;
  wire [1:0] s_sd_status;

  wire        mem_start, mem_we, mem_busy, mem_done;
  wire [19:0] mem_addr;
  wire [31:0] mem_wdata, mem_rdata;

  nd_storage_devices #(
      .SIMULATE      (0),
      .INCLUDE_TAPE  (1),
      .INCLUDE_FLOPPY(1),
      .INCLUDE_SMD   (0),
      .INCLUDE_WD    (1),
      // 8.3 name: ".BPUN" is a 4-character extension that FAT can only hold
      // through a VFAT long-name entry, and the floppy/WD builds strip long-
      // name parsing. Same choice the Tang makes.
      .BOOT_NAME("BOOT.TAP"),
      .BOOT_LEN (8'd8)
  ) STORAGE (
      .clk_stor  (clk_stor),
      .rst_stor_n(rst_stor_n),
      .clk_cpu   (clk_cpu),
      .rst_cpu_n (sys_rst_n),

      .byte_req      (TAPE_BYTE_REQ),
      .byte_valid    (s_tape_byte_valid),
      .byte_data     (s_tape_byte_data),
      .source_rewind (TAPE_REWIND),
      .TDISK_FAULT   (),
      .TDISK_ERR_CODE(),

      .FDISK_REQ      (FDISK_REQ),
      .FDISK_WR       (FDISK_WR),
      .FDISK_LSECT    (FDISK_LSECT),
      .FDISK_FORMAT   (FDISK_FORMAT),
      .FDISK_DRIVE    (FDISK_DRIVE),
      .FDISK_WORDCOUNT(FDISK_WORDCOUNT),
      .FDISK_DONE     (FDISK_DONE),
      .FDISK_ERR      (FDISK_ERR),
      .FDISK_ERR_CODE (FDISK_ERR_CODE),
      .FDISK_MEDIA_FMT(FDISK_MEDIA_FMT),
      .FDBUF_ADDR     (FDBUF_ADDR),
      .FDBUF_WDATA    (FDBUF_WDATA),
      .FDBUF_WE       (FDBUF_WE),
      .FDBUF_RDATA    (FDBUF_RDATA),

      .SDISK_START    (SDISK_START),
      .SDISK_REQ      (SDISK_REQ),
      .SDISK_WR       (SDISK_WR),
      .SDISK_BLKADDR1 (SDISK_BLKADDR1),
      .SDISK_BLKADDR2 (SDISK_BLKADDR2),
      .SDISK_UNIT     (SDISK_UNIT),
      .SDISK_WORDCOUNT(SDISK_WORDCOUNT),
      .SDISK_DONE     (),
      .SDISK_ERR      (),
      .SDISK_ERR_CODE (),
      .SDBUF_ADDR     (),
      .SDBUF_WDATA    (),
      .SDBUF_WE       (),
      .SDBUF_RDATA    (SDBUF_RDATA),

      .WDISK_START    (WDISK_START),
      .WDISK_REQ      (WDISK_REQ),
      .WDISK_WR       (WDISK_WR),
      .WDISK_BLKADDR1 (WDISK_BLKADDR1),
      .WDISK_BLKADDR2 (WDISK_BLKADDR2),
      .WDISK_UNIT     (WDISK_UNIT),
      .WDISK_WORDCOUNT(WDISK_WORDCOUNT),
      .WDISK_DONE     (WDISK_DONE),
      .WDISK_ERR      (WDISK_ERR),
      .WDISK_ERR_CODE (WDISK_ERR_CODE),
      .WDBUF_ADDR     (WDBUF_ADDR),
      .WDBUF_WDATA    (WDBUF_WDATA),
      .WDBUF_WE       (WDBUF_WE),
      .WDBUF_RDATA    (WDBUF_RDATA),

      .sd_clk_o  (s_sd_clk_o),
      .sd_cmd_i  (sd_cmd),
      .sd_cmd_o  (s_sd_cmd_o),
      .sd_cmd_oe (s_sd_cmd_oe),
      .sd_dat0_i (sd_dat0),
      .sd_dat0_o (s_sd_dat0_o),
      .sd_dat0_oe(s_sd_dat0_oe),

      .mem_start(mem_start),
      .mem_we   (mem_we),
      .mem_addr (mem_addr),
      .mem_wdata(mem_wdata),
      .mem_rdata(mem_rdata),
      .mem_busy (mem_busy),
      .mem_done (mem_done),

      .DBG_STATE   (),
      .DBG_LBA     (),
      .DBG_WDATA   (),
      .DBG_RDATA   (),
      .DBG_BUFW    (),
      .DBG_BUFWE   (),
      .DBG_FSEC    (),
      .DBG_RX_STB  (),
      .DBG_RX_RAW  (),
      .DBG_RX_BYTE (),
      .DBG_PAST_EOF(),
      .DBG_GRANT   (),
      .sd_status   (s_sd_status)
  );

  // The ONLY tristate drivers in the design sit here at the pads (repo rule:
  // no 'z' inside the fabric). DAT1-3 are parked high: the stack runs 1-bit,
  // and DAT3 high at CMD0 is what keeps the card out of SPI mode.
  assign sd_clk  = s_sd_clk_o;
  assign sd_cmd  = s_sd_cmd_oe  ? s_sd_cmd_o  : 1'bz;
  assign sd_dat0 = s_sd_dat0_oe ? s_sd_dat0_o : 1'bz;
  assign sd_dat1 = 1'bz;
  assign sd_dat2 = 1'bz;
  assign sd_dat3 = 1'bz;

  /**********************************************
  *  The storage region, held in DDR2           *
  ***********************************************/
  wire          ui_clk, ui_rst, calib_done;
  wire          req_valid, req_we, req_ready, rsp_valid;
  wire [ 26:0]  req_addr;
  wire [127:0]  req_wdata, rsp_rdata;
  wire [ 15:0]  req_wmask;

  nd_ddr2_storage u_region (
      .stor_clk  (clk_stor),
      .stor_rst_n(rst_stor_n),
      .mem_start (mem_start),
      .mem_we    (mem_we),
      .mem_addr  (mem_addr),
      .mem_wdata (mem_wdata),
      .mem_rdata (mem_rdata),
      .mem_busy  (mem_busy),
      .mem_done  (mem_done),

      .ui_clk   (ui_clk),
      .ui_rst   (ui_rst),
      .req_valid(req_valid),
      .req_we   (req_we),
      .req_addr (req_addr),
      .req_wdata(req_wdata),
      .req_wmask(req_wmask),
      .req_ready(req_ready),
      .rsp_valid(rsp_valid),
      .rsp_rdata(rsp_rdata)
  );

  nd_ddr2_port u_ddr2 (
      .sys_clk_200(clk200),
      .rst_n      (rst_req_n),
      .ui_clk     (ui_clk),
      .ui_rst     (ui_rst),
      .calib_done (calib_done),

      .req_valid(req_valid),
      .req_we   (req_we),
      .req_addr (req_addr),
      .req_wdata(req_wdata),
      .req_wmask(req_wmask),
      .req_ready(req_ready),
      .rsp_valid(rsp_valid),
      .rsp_rdata(rsp_rdata),

      .ddr2_dq   (ddr2_dq),
      .ddr2_dqs_p(ddr2_dqs_p),
      .ddr2_dqs_n(ddr2_dqs_n),
      .ddr2_addr (ddr2_addr),
      .ddr2_ba   (ddr2_ba),
      .ddr2_ras_n(ddr2_ras_n),
      .ddr2_cas_n(ddr2_cas_n),
      .ddr2_we_n (ddr2_we_n),
      .ddr2_ck_p (ddr2_ck_p),
      .ddr2_ck_n (ddr2_ck_n),
      .ddr2_cke  (ddr2_cke),
      .ddr2_cs_n (ddr2_cs_n),
      .ddr2_dm   (ddr2_dm),
      .ddr2_odt  (ddr2_odt)
  );

  /**********************************************
  *  LEDs - the Basys3 map, plus storage status *
  ***********************************************/
  reg [26:0] ticks;
  always @(posedge clk_cpu) ticks <= ticks + 27'd1;

  assign led[0]  = ~s_cpu_led[0];       // CPU RED   (master clear active)
  assign led[1]  = ~s_cpu_led[1];       // CPU GREEN (init complete)
  assign led[2]  = ~s_run;              // running
  assign led[3]  = sys_rst_n;           // reset released
  assign led[4]  = ~cpu_txd;            // UART TX activity
  assign led[5]  = ticks[26];           // heartbeat
  assign led[6]  = s_debug_mclk;
  assign led[7]  = ~s_debug_lcs_n;      // microcode loaded
  assign led[8]  = s_debug_mr_n;
  assign led[9]  = calib_done;          // DDR2 calibrated
  assign led[10] = s_sd_status[0];      // SD stack status
  assign led[11] = ~s_debug_cc_term[0];
  assign led[12] = ~s_debug_cc_term[1];
  assign led[13] = ~s_debug_cc_term[2];
  assign led[14] = ~s_debug_cc_term[3];
  assign led[15] = ~s_debug_cc_term[4];

  /**********************************************
  *  7-segment display                          *
  *  sw[15:14] = 00: sw[0] picks CSA / LA (as before)                       *
  *  sw[15:14] = 01: {FDISK req count[7:0], done count[7:0]}                *
  *  sw[15:14] = 10: {err count[7:0], first err code, last err code}        *
  *  sw[15:14] = 11: first FDISK_LSECT requested                            *
  *  Floppy-DMA debug taps (22-AUG-2026): counts every FDISK_REQ /          *
  *  FDISK_DONE / FDISK_ERR on the seam between ND_FLOPPY_DMA and           *
  *  nd_storage_floppy_adapter, latches the first error code, the last      *
  *  error code and the first requested logical sector. Observation only.   *
  ***********************************************/
  reg [7:0]  dbg_freq_cnt  = 8'd0;
  reg [7:0]  dbg_fdone_cnt = 8'd0;
  reg [7:0]  dbg_ferr_cnt  = 8'd0;
  reg [3:0]  dbg_code_first = 4'd0, dbg_code_last = 4'd0;
  reg [15:0] dbg_lsect_first = 16'd0;
  reg        dbg_have_lsect = 1'b0, dbg_have_code = 1'b0;
  always @(posedge clk_cpu) begin
    if (FDISK_REQ) begin
      dbg_freq_cnt <= dbg_freq_cnt + 8'd1;
      if (!dbg_have_lsect) begin
        dbg_lsect_first <= FDISK_LSECT;
        dbg_have_lsect  <= 1'b1;
      end
    end
    if (FDISK_DONE) dbg_fdone_cnt <= dbg_fdone_cnt + 8'd1;
    if (FDISK_DONE && FDISK_ERR) begin
      dbg_ferr_cnt  <= dbg_ferr_cnt + 8'd1;
      dbg_code_last <= FDISK_ERR_CODE;
      if (!dbg_have_code) begin
        dbg_code_first <= FDISK_ERR_CODE;
        dbg_have_code  <= 1'b1;
      end
    end
  end

  wire [15:0] seg_value =
      (sw[15:14] == 2'b01) ? {dbg_freq_cnt, dbg_fdone_cnt} :
      (sw[15:14] == 2'b10) ? {dbg_ferr_cnt, dbg_code_first, dbg_code_last} :
      (sw[15:14] == 2'b11) ? dbg_lsect_first :
      sw[0] ? {2'b0, s_debug_la_23_10}
            : {3'b0, CSA_12_0};
  wire [6:0] nd_seg;
  wire [3:0] nd_an;

  SevenSegDebug SEVEN_SEG (
      .clk  (clk100),
      .value(seg_value),
      .seg  (nd_seg),
      .an   (nd_an)
  );

  assign {cg, cf, ce, cd, cc, cb, ca} = nd_seg;
  assign dp = 1'b1;                 // decimal points off (active low)
  assign an = {4'b1111, nd_an};     // only the right-hand four digits

  /* verilator lint_off UNUSEDSIGNAL */
  wire _unused = &{1'b0, sw[15:1], sd_cd, s_pil, s_debug_ca_9_0,
                   s_debug_fetch, s_debug_clear_n, s_debug_refrq_n,
                   s_debug_intrq_n, s_debug_powfail_n, s_debug_fidbo,
                   s_ireq_15_0_n, s_xmic_dbg, s_cpu_led[6:2], s_sd_status[1],
                   DMA_RDATA, DMA_ACK, DMA_ERR, DMA_BUSY, calib_done, 1'b0};
  /* verilator lint_on UNUSEDSIGNAL */

endmodule

`default_nettype wire
