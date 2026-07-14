/**************************************************************************
** ND120 BOARD-INDEPENDENT CORE                                          **
**                                                                       **
** ND3202D CPU board + the optional ND-BUS Verilog device chain.         **
** Contains NO board-specific logic: no PLL/MMCM, no power-on reset, no  **
** LED mapping, no 7-segment, no SDRAM primitive, no heartbeat counter.  **
** Every board (Basys3/sim ND120_TOP, Tang Nano 20K, future boards)      **
** instantiates this and supplies its own clock, reset and I/O.          **
**                                                                       **
** Behaviour-preserving extraction of ND120_TOP.v (14-JUL-2026):         **
** the device chain and the ND3202D instance are moved verbatim; the     **
** `ifdef ND120_VERILOG_DEVICES gate becomes the INCLUDE_* parameters.   **
**                                                                       **
** Clocking: clk_cpu is the ONE net that fed ND3202D.sysclk, CLOCK_1,    **
** CLOCK_2 and the device chain's s_dev_clk in BOTH the sim and the FPGA **
** branch of ND120_TOP, so it collapses to a single core input. The      **
** board decides what drives it (sim: sysclk; Basys3: clk_cpu from the   **
** MMCM; Tang: clk_cpu from the rPLL).                                   **
**                                                                       **
** Storage seam: the core exposes the byte/disk SOURCE ports and knows   **
** nothing of SD-FAT or of the C harness. The board supplies the         **
** implementation (sim: forwarded to ND120_TOP ports, served by the C    **
** model; hardware: nd_storage / nd_tape_sdfat_source).                  **
**                                                                       **
** Ronny Hansen                                                          **
***************************************************************************/

//! @title ND120 board-independent core (ND3202D + ND-BUS device chain)
//! @author Ronny Hansen

module ND120_CORE #(
    // Device chain population. Each device is instantiated in a generate
    // block; when absent its shared-net contributions are tied inactive so
    // the OR-buses, the IDENT chain, the DMA grant chain and the bus
    // wired-AND all stay valid expressions (graceful degradation).
    parameter INCLUDE_TAPE   = 0,  //! ND_TAPE_400 papertape at 400
    parameter INCLUDE_FLOPPY = 0,  //! ND_FLOPPY_DMA floppy 1560 (DMA flavor)
    parameter INCLUDE_SMD    = 0   //! ND_SMD disk at 1540
) (
    /***************************************************
     *  (a) CLOCK / RESET                              *
     ***************************************************/
    input wire clk_cpu,    //! CPU + bus + device domain (ND3202D sysclk/CLOCK_1/CLOCK_2)
    input wire sys_rst_n,  //! Active-low reset, from the board's power-on reset

    /***************************************************
     *  (e) ND-100 C-PLUG BUS                          *
     *  Always present on the core; the board either   *
     *  drives it (sim harness) or ties it off (FPGA). *
     ***************************************************/
    input  wire        BREQ_n,      //! Bus Request  C-C12
    input  wire        BINT10_n,    //! Bus Interrupt 10 C-A15
    input  wire        BINT11_n,    //! Bus Interrupt 11 C-C15
    input  wire        BINT12_n,    //! Bus Interrupt 12 C-A16
    input  wire        BINT13_n,    //! Bus Interrupt 13 C-C16
    input  wire        BINT15_n,    //! Bus Interrupt 15 C-C17
    input  wire        POWSENSE_n,  //! Power Sense

    input  wire [23:0] BD_23_0_n_IN,   //! Bus address/data in (active low, pulled high)
    output wire [23:0] BD_23_0_n_OUT,  //! Bus address/data out

    input  wire        SEMRQ_n_IN,   //! C-PLUG A17 SEMREQ~ in
    output wire        SEMRQ_n_OUT,  //! C-PLUG A17 SEMREQ~ out
    input  wire        BINPUT_n_IN,  //! C-PLUG A18 BINPUT~ in
    output wire        BINPUT_n_OUT, //! C-PLUG A18 BINPUT~ out
    input  wire        BDAP_n_IN,    //! C-PLUG C18 BDAP~ in
    output wire        BDAP_n_OUT,   //! C-PLUG C18 BDAP~ out
    input  wire        BDRY_n_IN,    //! C-PLUG A19 BDRY~ in
    output wire        BDRY_n_OUT,   //! C-PLUG A19 BDRY~ out
    input  wire        BAPR_n_IN,    //! C-PLUG A20 BAPR~ in
    output wire        BAPR_n_OUT,   //! C-PLUG A20 BAPR~ out

    output wire        BREF_n,      //! C-PLUG B12 BREF~
    output wire        BERROR_n,    //! C-PLUG B21 BERROR~
    output wire        BINACK_n,    //! C-PLUG B19 BINACK~
    output wire        BIOXE_n,     //! C-PLUG C19 BIOXE~
    output wire        BMEM_n,      //! C-PLUG C28 BMEM~
    output wire        OUTGRANT_n,  //! C-PLUG C23 OUTGRANT~ (DMA grant chain head)
    output wire        OUTIDENT_n,  //! C-PLUG C22 OUTIDENT~
    output wire        MCL,         //! C-PLUG B20 MCL~ (after negation)

    /***************************************************
     *  (d) UART (A-PLUG console)                      *
     ***************************************************/
    input  wire        RXD,  //! UART Receive  A-C8
    output wire        TXD,  //! UART Transmit A-C7

    /***************************************************
     *  (c) STORAGE BACKEND SOURCE PORTS               *
     *  Meaningful only for the devices the INCLUDE_*  *
     *  parameters populate; the rest read as tied-off *
     *  outputs and ignored inputs. (Verilog cannot    *
     *  make a port list depend on a parameter, so the *
     *  ports are declared unconditionally and the     *
     *  generate-else drives the outputs inactive.)    *
     ***************************************************/

    // Papertape byte source (INCLUDE_TAPE)
    output wire        TAPE_BYTE_REQ,    //! pulse: fetch next tape byte
    input  wire        TAPE_BYTE_VALID,  //! pulse: TAPE_BYTE_DATA is the byte
    input  wire [7:0]  TAPE_BYTE_DATA,
    output wire        TAPE_REWIND,      //! pulse: rewind the tape source

    // DMA test client (INCLUDE_FLOPPY || INCLUDE_SMD: it is the grant-chain head)
    input  wire        DMA_REQ,    //! pulse: one word transfer
    input  wire        DMA_WR,     //! 0 = memory read, 1 = memory write
    input  wire [23:0] DMA_ADDR,   //! physical memory address
    input  wire [15:0] DMA_WDATA,
    output wire [15:0] DMA_RDATA,
    output wire        DMA_ACK,
    output wire        DMA_ERR,
    output wire        DMA_BUSY,

    // Floppy disk-image backend (INCLUDE_FLOPPY)
    output wire        FDISK_REQ,
    output wire        FDISK_WR,
    output wire [15:0] FDISK_LSECT,
    output wire [1:0]  FDISK_FORMAT,
    output wire [1:0]  FDISK_DRIVE,
    output wire [10:0] FDISK_WORDCOUNT,
    input  wire        FDISK_DONE,
    input  wire        FDISK_ERR,
    //! media format from the image size (deviceFloppyDMA.c READ FORMAT):
    //! {doubleDensity, doubleSided, bytesPerSector[1:0]}
    input  wire [3:0]  FDISK_MEDIA_FMT,
    input  wire [9:0]  FDBUF_ADDR,
    input  wire [15:0] FDBUF_WDATA,
    input  wire        FDBUF_WE,
    output wire [15:0] FDBUF_RDATA,

    // SMD disk backend (INCLUDE_SMD)
    output wire        SDISK_START,
    output wire        SDISK_REQ,
    output wire        SDISK_WR,
    output wire [15:0] SDISK_BLKADDR1,
    output wire [15:0] SDISK_BLKADDR2,
    output wire [2:0]  SDISK_UNIT,
    output wire [10:0] SDISK_WORDCOUNT,
    input  wire        SDISK_DONE,
    input  wire        SDISK_ERR,
    input  wire [9:0]  SDBUF_ADDR,
    input  wire [15:0] SDBUF_WDATA,
    input  wire        SDBUF_WE,
    output wire [15:0] SDBUF_RDATA,

    /***************************************************
     *  (f) DEBUG / STATUS (all outputs)               *
     ***************************************************/
    output wire [6:0]  LED,        //! ND3202D LED bundle (see ND3202D.v port comment)
    output wire        RUN_n,      //! low while the CPU is running
    output wire [12:0] CSA_12_0,   //! Microcode address
    output wire [13:0] LA_23_10,   //! MAC upper address (XLA 23:10)
    output wire [9:0]  CA_9_0,     //! MAC lower address (XCA 9:0)
    output wire [4:0]  DEBUG_CC_TERM,    //! {TERM_n, CC3_n, CC2_n, CC1_n, CC0_n}
    output wire        DEBUG_MCLK,       //! Memory clock
    output wire        DEBUG_LCS_n,      //! 0 = loading microcode, 1 = loaded
    output wire        DEBUG_FETCH,
    output wire        DEBUG_MR_n,       //! Master Reset
    output wire        DEBUG_CLEAR_n,
    output wire        DEBUG_REFRQ_n,    //! Refresh Request
    output wire        DEBUG_INTRQ_n,    //! Interrupt Request
    output wire        DEBUG_POWFAIL_n,  //! Power Fail
    output wire [15:0] DEBUG_FIDBO_15_0  //! FIDBO internal data bus

`ifdef MAIN_RAM_SDRAM
    /***************************************************
     *  (b) RAM BACKEND - SDRAM PHY pass-through only  *
     *  RAM lives INSIDE ND3202D (MEM_43 -> MEM_RAM_49);*
     *  under MAIN_RAM_SDRAM the PHY pins are threaded  *
     *  up through ND3202D and out to the board.        *
     *  Absent entirely on sim/Basys3 (on-chip BRAM).   *
     ***************************************************/
    ,
    input  wire        clk2x,        //! 2x clk_cpu, same PLL, edge-aligned
    input  wire        clk2x_sdram,  //! 180 degrees from clk2x, to the SDRAM chip
    output wire        O_sdram_clk,
    output wire        O_sdram_cke,
    output wire        O_sdram_cs_n,
    output wire        O_sdram_cas_n,
    output wire        O_sdram_ras_n,
    output wire        O_sdram_wen_n,
    inout  wire [31:0] IO_sdram_dq,
    output wire [10:0] O_sdram_addr,
    output wire [ 1:0] O_sdram_ba,
    output wire [ 3:0] O_sdram_dqm,
    output wire [15:0] DBG_MEMW      //! write-path debug bus from MEM_43
`endif
);

  /**********************************************
  *  Constants that used to live in ND120_TOP   *
  ***********************************************/

  // Installation number (read using IDB Source = 035)
  wire [7:0] installation_number = 8'd123;

  wire s_high = 1'b1;
  wire s_low  = 1'b0;

  wire [1:0] oc_select = 2'b11;  // 11 = clock input XTAL1 (full speed)

  wire [2:0] s_SEL_TESTMUX = 3'b000;  // 000 = TESTMUX = 0

  // 8 = 9600 baud (ref BAUDV page 158 in microcode)
  wire [3:0] s_baud_rate_switch = 4'b1000;

  /**********************************************
  *  CPU-board debug wires kept alive           *
  *  (Run120.cpp reads s_csbits hierarchically) *
  ***********************************************/
  (* keep = "true", DONT_TOUCH = "true" *) wire [4:0]  s_test_4_0;    // Test pads
  (* keep = "true", DONT_TOUCH = "true" *) wire [4:0]  s_dp_5_1_n;    // Datapath 5-1
  (* keep = "true", DONT_TOUCH = "true" *) wire        s_tp1_intrq_n; // TP1 INTRQ_n
  (* keep = "true", DONT_TOUCH = "true" *) wire [63:0] s_csbits;      // Microcode CPU BITS

  /**********************************************
  *  Verilog external-bus devices (optional)    *
  *  ND-BUS-DEVICES: bus slave + papertape 400  *
  *  + floppy 1560 + SMD 1540 and their DMA     *
  *  masters. Wired-AND onto the active-low bus *
  *  inputs of the CPU board.                   *
  ***********************************************/

  localparam ANY_DEVICE = (INCLUDE_TAPE != 0) || (INCLUDE_FLOPPY != 0) || (INCLUDE_SMD != 0);
  // The DMA test master is the head of the DMA grant chain (its INGRANT_n is
  // the CPU's OUTGRANT_n), so it must exist whenever any bus master exists.
  localparam ANY_DMA_MASTER = (INCLUDE_FLOPPY != 0) || (INCLUDE_SMD != 0);

  // Every device shares this one clock with the CPU board.
  wire s_dev_clk = clk_cpu;

  // Bus-slave contributions onto the CPU's bus inputs (active low)
  wire [23:0] s_dev_bd_n;
  wire        s_dev_binput_n, s_dev_bdap_n, s_dev_bdry_n;
  wire        s_dev_bint10_n, s_dev_bint11_n, s_dev_bint12_n, s_dev_bint13_n;

  // IOX fan-out from the bus slave to the device cores
  wire [15:0] s_dev_iox_addr, s_dev_iox_wdata;
  wire        s_dev_iox_wr, s_dev_iox_rd;
  wire        s_dev_ident_strobe;
  wire [3:0]  s_dev_ident_level;

  // OR-bus contributions per device core (tape, floppy, SMD)
  wire [15:0] s_tape_rdata, s_flp_rdata, s_smd_rdata;
  wire [3:0]  s_tape_intp, s_flp_intp, s_smd_intp;
  wire        s_tape_hit, s_flp_hit, s_smd_hit;
  wire [15:0] s_tape_code, s_flp_code, s_smd_code;

  // IDENT daisy chain: head -> tape -> floppy -> SMD (absent stage = pass-through)
  wire        s_grant_tape_flp;  // ident chain: tape -> floppy
  wire        s_grant_flp_smd;   // ident chain: floppy -> SMD

  wire [15:0] s_dev_iox_rdata   = s_tape_rdata | s_flp_rdata | s_smd_rdata;
  wire [3:0]  s_dev_int_pending = s_tape_intp  | s_flp_intp  | s_smd_intp;
  wire        s_dev_ident_hit   = s_tape_hit   | s_flp_hit   | s_smd_hit;
  wire [15:0] s_dev_ident_code  = s_tape_code  | s_flp_code  | s_smd_code;

  // DMA grant chain (active low): CPU OUTGRANT_n -> test master -> floppy
  // master -> SMD master. Declared up front: s_grant_fdma_smdm_n is used by
  // the floppy master before the SMD master is instantiated.
  wire        s_grant_dma_fdma_n;   // grant chain: test DMA master -> floppy master
  wire        s_grant_fdma_smdm_n;  // grant chain: floppy master  -> SMD master

  // Per-master bus contributions (active low; tied high when the master is absent)
  wire [23:0] s_dma_bd_n,   s_fdmam_bd_n,   s_smdm_bd_n;
  wire        s_dma_breq_n, s_fdmam_breq_n, s_smdm_breq_n;
  wire        s_dma_bapr_n, s_fdmam_bapr_n, s_smdm_bapr_n;
  wire        s_dma_binput_n, s_fdmam_binput_n, s_smdm_binput_n;
  wire        s_dma_bdap_n, s_fdmam_bdap_n, s_smdm_bdap_n;

  /*---------------------------------------------
  *  ND-BUS slave shell (present with any device)
  *--------------------------------------------*/
  generate
    if (ANY_DEVICE) begin : gen_bus_slave
      ND_BUS_SLAVE BUS_SLAVE (
          .sysclk(s_dev_clk),
          .sys_rst_n(sys_rst_n),
          .BD_23_0_n_OUT(BD_23_0_n_OUT),
          .BD_23_0_n_IN(s_dev_bd_n),
          .BAPR_n(BAPR_n_OUT),
          .BIOXE_n(BIOXE_n),
          .BINACK_n(BINACK_n),
          .OUTIDENT_n(OUTIDENT_n),
          .BINPUT_n(s_dev_binput_n),
          .BDAP_n(s_dev_bdap_n),
          .BDRY_n(s_dev_bdry_n),
          .BINT10_n(s_dev_bint10_n),
          .BINT11_n(s_dev_bint11_n),
          .BINT12_n(s_dev_bint12_n),
          .BINT13_n(s_dev_bint13_n),
          .iox_addr(s_dev_iox_addr),
          .iox_wr(s_dev_iox_wr),
          .iox_wdata(s_dev_iox_wdata),
          .iox_rd(s_dev_iox_rd),
          .iox_rdata(s_dev_iox_rdata),
          .int_pending(s_dev_int_pending),
          .ident_strobe(s_dev_ident_strobe),
          .ident_level(s_dev_ident_level),
          .ident_hit(s_dev_ident_hit),
          .ident_code(s_dev_ident_code)
      );
    end else begin : gen_no_bus_slave
      // No devices: contribute nothing to the wired-AND, drive no IOX.
      assign s_dev_bd_n         = 24'hFFFFFF;
      assign s_dev_binput_n     = 1'b1;
      assign s_dev_bdap_n       = 1'b1;
      assign s_dev_bdry_n       = 1'b1;
      assign s_dev_bint10_n     = 1'b1;
      assign s_dev_bint11_n     = 1'b1;
      assign s_dev_bint12_n     = 1'b1;
      assign s_dev_bint13_n     = 1'b1;
      assign s_dev_iox_addr     = 16'd0;
      assign s_dev_iox_wdata    = 16'd0;
      assign s_dev_iox_wr       = 1'b0;
      assign s_dev_iox_rd       = 1'b0;
      assign s_dev_ident_strobe = 1'b0;
      assign s_dev_ident_level  = 4'd0;
    end
  endgenerate

  /*---------------------------------------------
  *  Papertape reader 400 (byte source on board)
  *--------------------------------------------*/
  generate
    if (INCLUDE_TAPE != 0) begin : gen_tape
      ND_TAPE_400 #(
          .BASE_ADDR (16'o000400),
          .IDENT_CODE(16'o000002),
          .INT_LEVEL (4'd12)
      ) TAPE_400 (
          .sysclk(s_dev_clk),
          .sys_rst_n(sys_rst_n),
          .iox_addr(s_dev_iox_addr),
          .iox_wr(s_dev_iox_wr),
          .iox_wdata(s_dev_iox_wdata),
          .iox_rd(s_dev_iox_rd),
          .iox_rdata(s_tape_rdata),
          .int_pending(s_tape_intp),
          .ident_strobe(s_dev_ident_strobe),
          .ident_level(s_dev_ident_level),
          .ident_grant_in(1'b1),                // chain head
          .ident_grant_out(s_grant_tape_flp),
          .ident_hit(s_tape_hit),
          .ident_code(s_tape_code),
          .byte_req(TAPE_BYTE_REQ),
          .byte_valid(TAPE_BYTE_VALID),
          .byte_data(TAPE_BYTE_DATA),
          .source_rewind(TAPE_REWIND)
      );
    end else begin : gen_no_tape
      assign s_tape_rdata     = 16'd0;
      assign s_tape_intp      = 4'd0;
      assign s_tape_hit       = 1'b0;
      assign s_tape_code      = 16'd0;
      assign s_grant_tape_flp = 1'b1;  // pass the chain head through
      assign TAPE_BYTE_REQ    = 1'b0;
      assign TAPE_REWIND      = 1'b0;
    end
  endgenerate

  /*---------------------------------------------
  *  Floppy 1560, DMA flavor (Ronny's choice
  *  11-JUL): the controller masters the bus
  *  through its own ND_DMA_MASTER, second in the
  *  grant chain behind the DMA test master.
  *--------------------------------------------*/
  generate
    if (INCLUDE_FLOPPY != 0) begin : gen_floppy
      wire        s_fdma_req, s_fdma_wr;
      wire [23:0] s_fdma_addr;
      wire [15:0] s_fdma_wdata, s_fdma_rdata;
      wire        s_fdma_ack, s_fdma_err, s_fdma_busy;

      ND_FLOPPY_DMA #(
          .BASE_ADDR (16'o001560),
          .IDENT_CODE(16'o000021),
          .INT_LEVEL (4'd11)
      ) FLOPPY_1560 (
          .sysclk(s_dev_clk),
          .sys_rst_n(sys_rst_n),
          .iox_addr(s_dev_iox_addr),
          .iox_wr(s_dev_iox_wr),
          .iox_wdata(s_dev_iox_wdata),
          .iox_rd(s_dev_iox_rd),
          .iox_rdata(s_flp_rdata),
          .int_pending(s_flp_intp),
          .ident_strobe(s_dev_ident_strobe),
          .ident_level(s_dev_ident_level),
          .ident_grant_in(s_grant_tape_flp),
          .ident_grant_out(s_grant_flp_smd),
          .ident_hit(s_flp_hit),
          .ident_code(s_flp_code),
          .dma_req(s_fdma_req),
          .dma_wr(s_fdma_wr),
          .dma_addr(s_fdma_addr),
          .dma_wdata(s_fdma_wdata),
          .dma_rdata(s_fdma_rdata),
          .dma_ack(s_fdma_ack),
          .dma_err(s_fdma_err),
          .dma_busy(s_fdma_busy),
          .disk_req(FDISK_REQ),
          .disk_wr(FDISK_WR),
          .disk_lsect(FDISK_LSECT),
          .disk_format(FDISK_FORMAT),
          .disk_drive(FDISK_DRIVE),
          .disk_wordcount(FDISK_WORDCOUNT),
          .disk_done(FDISK_DONE),
          .disk_err_in(FDISK_ERR),
          .disk_media_fmt(FDISK_MEDIA_FMT),
          .dbuf_addr(FDBUF_ADDR),
          .dbuf_wdata(FDBUF_WDATA),
          .dbuf_we(FDBUF_WE),
          .dbuf_rdata(FDBUF_RDATA)
      );

      ND_DMA_MASTER #(
          .TIMEOUT_TICKS(16'd8192)
      ) FLOPPY_DMA_MASTER (
          .sysclk(s_dev_clk),
          .sys_rst_n(sys_rst_n),
          .dma_req(s_fdma_req),
          .dma_wr(s_fdma_wr),
          .dma_addr(s_fdma_addr),
          .dma_wdata(s_fdma_wdata),
          .dma_rdata(s_fdma_rdata),
          .dma_ack(s_fdma_ack),
          .dma_err(s_fdma_err),
          .dma_busy(s_fdma_busy),
          .BREQ_n(s_fdmam_breq_n),
          .INGRANT_n(s_grant_dma_fdma_n),
          .OUTGRANT_n(s_grant_fdma_smdm_n),
          .BMEM_n(BMEM_n),
          .BD_23_0_n_OUT(s_fdmam_bd_n),
          .BD_23_0_n_IN(BD_23_0_n_OUT),
          .BAPR_n(s_fdmam_bapr_n),
          .BINPUT_n(s_fdmam_binput_n),
          .BDAP_n(s_fdmam_bdap_n),
          .BDRY_n(BDRY_n_OUT)
      );
    end else begin : gen_no_floppy
      assign s_flp_rdata          = 16'd0;
      assign s_flp_intp           = 4'd0;
      assign s_flp_hit            = 1'b0;
      assign s_flp_code           = 16'd0;
      assign s_grant_flp_smd      = s_grant_tape_flp;      // ident chain pass-through
      assign s_grant_fdma_smdm_n  = s_grant_dma_fdma_n;    // DMA grant pass-through
      assign s_fdmam_bd_n         = 24'hFFFFFF;
      assign s_fdmam_breq_n       = 1'b1;
      assign s_fdmam_bapr_n       = 1'b1;
      assign s_fdmam_binput_n     = 1'b1;
      assign s_fdmam_bdap_n       = 1'b1;
      assign FDISK_REQ            = 1'b0;
      assign FDISK_WR             = 1'b0;
      assign FDISK_LSECT          = 16'd0;
      assign FDISK_FORMAT         = 2'd0;
      assign FDISK_DRIVE          = 2'd0;
      assign FDISK_WORDCOUNT      = 11'd0;
      assign FDBUF_RDATA          = 16'd0;
    end
  endgenerate

  /*---------------------------------------------
  *  SMD disk controller at 1540 with its own bus
  *  master, third in the grant chain
  *  (test master -> floppy master -> SMD master)
  *--------------------------------------------*/
  generate
    if (INCLUDE_SMD != 0) begin : gen_smd
      wire        s_smd_req, s_smd_wr;
      wire [23:0] s_smd_addr;
      wire [15:0] s_smd_wdata, s_smd_rdata_dma;
      wire        s_smd_ack, s_smd_err, s_smd_busy;

      ND_SMD #(
          .BASE_ADDR (16'o001540),
          .IDENT_CODE(16'o000017),
          .INT_LEVEL (4'd11)
      ) SMD_1540 (
          .sysclk(s_dev_clk),
          .sys_rst_n(sys_rst_n),
          .iox_addr(s_dev_iox_addr),
          .iox_wr(s_dev_iox_wr),
          .iox_wdata(s_dev_iox_wdata),
          .iox_rd(s_dev_iox_rd),
          .iox_rdata(s_smd_rdata),
          .int_pending(s_smd_intp),
          .ident_strobe(s_dev_ident_strobe),
          .ident_level(s_dev_ident_level),
          .ident_grant_in(s_grant_flp_smd),
          .ident_grant_out(),
          .ident_hit(s_smd_hit),
          .ident_code(s_smd_code),
          .dma_req(s_smd_req),
          .dma_wr(s_smd_wr),
          .dma_addr(s_smd_addr),
          .dma_wdata(s_smd_wdata),
          .dma_rdata(s_smd_rdata_dma),
          .dma_ack(s_smd_ack),
          .dma_err(s_smd_err),
          .dma_busy(s_smd_busy),
          .disk_start(SDISK_START),
          .disk_req(SDISK_REQ),
          .disk_wr(SDISK_WR),
          .disk_blkaddr1(SDISK_BLKADDR1),
          .disk_blkaddr2(SDISK_BLKADDR2),
          .disk_unit(SDISK_UNIT),
          .disk_wordcount(SDISK_WORDCOUNT),
          .disk_done(SDISK_DONE),
          .disk_err_in(SDISK_ERR),
          .dbuf_addr(SDBUF_ADDR),
          .dbuf_wdata(SDBUF_WDATA),
          .dbuf_we(SDBUF_WE),
          .dbuf_rdata(SDBUF_RDATA)
      );

      ND_DMA_MASTER #(
          .TIMEOUT_TICKS(16'd8192)
      ) SMD_DMA_MASTER (
          .sysclk(s_dev_clk),
          .sys_rst_n(sys_rst_n),
          .dma_req(s_smd_req),
          .dma_wr(s_smd_wr),
          .dma_addr(s_smd_addr),
          .dma_wdata(s_smd_wdata),
          .dma_rdata(s_smd_rdata_dma),
          .dma_ack(s_smd_ack),
          .dma_err(s_smd_err),
          .dma_busy(s_smd_busy),
          .BREQ_n(s_smdm_breq_n),
          .INGRANT_n(s_grant_fdma_smdm_n),
          .OUTGRANT_n(),
          .BMEM_n(BMEM_n),
          .BD_23_0_n_OUT(s_smdm_bd_n),
          .BD_23_0_n_IN(BD_23_0_n_OUT),
          .BAPR_n(s_smdm_bapr_n),
          .BINPUT_n(s_smdm_binput_n),
          .BDAP_n(s_smdm_bdap_n),
          .BDRY_n(BDRY_n_OUT)
      );
    end else begin : gen_no_smd
      assign s_smd_rdata      = 16'd0;
      assign s_smd_intp       = 4'd0;
      assign s_smd_hit        = 1'b0;
      assign s_smd_code       = 16'd0;
      assign s_smdm_bd_n      = 24'hFFFFFF;
      assign s_smdm_breq_n    = 1'b1;
      assign s_smdm_bapr_n    = 1'b1;
      assign s_smdm_binput_n  = 1'b1;
      assign s_smdm_bdap_n    = 1'b1;
      assign SDISK_START      = 1'b0;
      assign SDISK_REQ        = 1'b0;
      assign SDISK_WR         = 1'b0;
      assign SDISK_BLKADDR1   = 16'd0;
      assign SDISK_BLKADDR2   = 16'd0;
      assign SDISK_UNIT       = 3'd0;
      assign SDISK_WORDCOUNT  = 11'd0;
      assign SDBUF_RDATA      = 16'd0;
    end
  endgenerate

  /*---------------------------------------------
  *  DMA bus master (full-RTL DMA validation):
  *  requests the bus from the REAL arbiter
  *  (PAL_44801A via BIF) and runs real memory
  *  cycles. Chain head is the CPU's OUTGRANT.
  *  Present whenever any master exists, since it
  *  is the head of the grant chain.
  *--------------------------------------------*/
  generate
    if (ANY_DMA_MASTER) begin : gen_dma_master
      ND_DMA_MASTER #(
          .TIMEOUT_TICKS(16'd8192)
      ) DMA_MASTER (
          .sysclk(s_dev_clk),
          .sys_rst_n(sys_rst_n),
          .dma_req(DMA_REQ),
          .dma_wr(DMA_WR),
          .dma_addr(DMA_ADDR),
          .dma_wdata(DMA_WDATA),
          .dma_rdata(DMA_RDATA),
          .dma_ack(DMA_ACK),
          .dma_err(DMA_ERR),
          .dma_busy(DMA_BUSY),
          .BREQ_n(s_dma_breq_n),
          .INGRANT_n(OUTGRANT_n),
          .OUTGRANT_n(s_grant_dma_fdma_n),
          .BMEM_n(BMEM_n),
          .BD_23_0_n_OUT(s_dma_bd_n),
          .BD_23_0_n_IN(BD_23_0_n_OUT),
          .BAPR_n(s_dma_bapr_n),
          .BINPUT_n(s_dma_binput_n),
          .BDAP_n(s_dma_bdap_n),
          .BDRY_n(BDRY_n_OUT)
      );
    end else begin : gen_no_dma_master
      assign s_grant_dma_fdma_n = OUTGRANT_n;  // grant chain pass-through
      assign s_dma_bd_n         = 24'hFFFFFF;
      assign s_dma_breq_n       = 1'b1;
      assign s_dma_bapr_n       = 1'b1;
      assign s_dma_binput_n     = 1'b1;
      assign s_dma_bdap_n       = 1'b1;
      assign DMA_RDATA          = 16'd0;
      assign DMA_ACK            = 1'b0;
      assign DMA_ERR            = 1'b0;
      assign DMA_BUSY           = 1'b0;
    end
  endgenerate

  /*---------------------------------------------
  *  Wired-AND with the external (C-harness /
  *  board tie-off) bus inputs. Absent devices
  *  contribute all-ones, so the AND is exactly
  *  the ND120_TOP no-device pass-through.
  *--------------------------------------------*/
  wire [23:0] s_bus_bd_in_n     = BD_23_0_n_IN & s_dev_bd_n & s_dma_bd_n & s_fdmam_bd_n & s_smdm_bd_n;
  wire        s_bus_breq_n      = BREQ_n & s_dma_breq_n & s_fdmam_breq_n & s_smdm_breq_n;
  wire        s_bus_bapr_in_n   = BAPR_n_IN & s_dma_bapr_n & s_fdmam_bapr_n & s_smdm_bapr_n;
  wire        s_bus_binput_in_n = BINPUT_n_IN & s_dev_binput_n & s_dma_binput_n & s_fdmam_binput_n & s_smdm_binput_n;
  wire        s_bus_bdap_in_n   = BDAP_n_IN & s_dev_bdap_n & s_dma_bdap_n & s_fdmam_bdap_n & s_smdm_bdap_n;
  wire        s_bus_bdry_in_n   = BDRY_n_IN & s_dev_bdry_n;
  wire        s_bus_bint10_n    = BINT10_n & s_dev_bint10_n;
  wire        s_bus_bint11_n    = BINT11_n & s_dev_bint11_n;
  wire        s_bus_bint12_n    = BINT12_n & s_dev_bint12_n;
  wire        s_bus_bint13_n    = BINT13_n & s_dev_bint13_n;

  /**********************************************
  *  The CPU board                              *
  ***********************************************/

  ND3202D CPU_BOARD (
      .sysclk(clk_cpu),   // CPU core, OSC and bus all share one domain
      .sys_rst_n(sys_rst_n),
      .CLOCK_1(clk_cpu),  // XTAL1 = 39.3216MHZ on the real board
      .CLOCK_2(clk_cpu),  // XTAL2 = 35 MHZ (for slow operations?)

      // Signal from C-PLUG to CPU Board (and some signals duplicated on A-PLUG)
      .LOAD_n(s_high),        // Load button  C-B12, A-C15
      .BREQ_n(s_bus_breq_n),  // Bus Request  C-C12 (wired-AND with DMA masters)
      .CONTINUE_n(s_high),    // Continue button C-B15
      .STOP_n(s_high),        // Stop button C-B16, A-C17

      .BINT10_n(s_bus_bint10_n),  // Bus Interrupt 10 C-A15 (wired-AND with Verilog devices)
      .BINT11_n(s_bus_bint11_n),  // Bus Interrupt 11 C-C15
      .BINT12_n(s_bus_bint12_n),  // Bus Interrupt 12 C-A16
      .BINT13_n(s_bus_bint13_n),  // Bus Interrupt 13 C-C16
      .BINT15_n(BINT15_n),        // Bus Interrupt 15 C-C17

      .POWSENSE_n(POWSENSE_n),  // Power Sense

      .BD_23_0_n_IN(s_bus_bd_in_n),  // Bus address and data from bus (wired-AND with Verilog devices)
      .BD_23_0_n_OUT(BD_23_0_n_OUT),

      // Bidirectional signals
      .SEMRQ_n_IN(SEMRQ_n_IN),         //! Input-signal from "C PLUG", signal A17 SEMREQ~ (SEMaphore REQest)
      .SEMRQ_n_OUT(SEMRQ_n_OUT),       //! Output-signal to "C PLUG", signal A17 SEMREQ~ (SEMaphore REQest)
      .BINPUT_n_IN(s_bus_binput_in_n), //! Input-signal from "C PLUG", signal A18 BINPUT~ (Bus INPUT)
      .BINPUT_n_OUT(BINPUT_n_OUT),     //! Output-signal to "C PLUG", signal A18 BINPUT~ (Bus INPUT)
      .BDAP_n_IN(s_bus_bdap_in_n),     //! Input-signal from "C PLUG", signal C18 BDAP~ (Bus DAta Present)
      .BDAP_n_OUT(BDAP_n_OUT),         //! Output-signal to "C PLUG", signal C18 BDAP~ (Bus DAta Present)
      .BDRY_n_IN(s_bus_bdry_in_n),     //! Input-signal from "C PLUG", signal A19 BDRY~ (Bus Data ReadY)
      .BDRY_n_OUT(BDRY_n_OUT),         //! Output-signal to "C PLUG", signal A19 BDRY~ (Bus Data ReadY)
      .BAPR_n_IN(s_bus_bapr_in_n),     //! Input-signal from "C PLUG", signal A20 BAPR~ (Bus Address PResent)
      .BAPR_n_OUT(BAPR_n_OUT),         //! Output-signal to "C PLUG", signal A20 BAPR~ (Bus Address PResent)

      // Signals from CPU board to C-PLUG
      .BREF_n(BREF_n),          // Output-signal to "C PLUG", signal B12 BREF~
      .BERROR_n(BERROR_n),      // Output-signal to "C PLUG", signal B21 BERROR~
      .BINACK_n(BINACK_n),      // Output-signal to "C PLUG", signal B19 BINACK~
      .BIOXE_n(BIOXE_n),        // Output-signal to "C PLUG", signal C19 BIOXE~
      .BMEM_n(BMEM_n),          // Output-signal to "C PLUG", signal C28 BMEM~
      .OUTGRANT_n(OUTGRANT_n),  // Output-signal to "C PLUG", signal C23 OUTGRANT~
      .OUTIDENT_n(OUTIDENT_n),  // Output-signal to "C PLUG", signal C22 OUTIDENT~
      .MCL(MCL),                // Output-signal to "C PLUG", signal B20 MCL~ (after negation)

      // Signals from B-PLUG to CPU Board
      .INR_7_0(installation_number), // INR 7:0, signal B-> B15, B4, B5, B17, B8, B7, B13, B6. (Installation number, read using IDB Source = 035)
      .EBUS(1'b1),     // EBUS, signal B-B3 (Pulled high with through resistor network RN13)
      .SEL5MS_n(1'b1), // SEL 5ms, signal B-B14 (Pulled high with 1kohm resistor R4)

      // Signals from CPU to B-PLUG
      .PIL(),         // XPIL3=B-C8, PIL2=B-B12. PIL1=B-B10, PIL0=B-B9
      .LUA_12_0(),    // XLUA 12:0
      .IDB_15_0(),    // XIDB 15:0
      .CSCOMM_4_0(),  //
      .MIS_1_0(),     // MIS1=B-C14, MIS0=B-A14
      .CD_15_0(),     // CD 15:0
      .LBD_15_0(),    // LBD 15:0
      .LA_23_10(LA_23_10),  // XLA 23:10 (MAC upper address)
      .CA_9_0(CA_9_0),      // CA 9:0 (MAC lower address)

      // Signals from A-PLUG to CPU board
      .OSCCL_n  (s_high),     // Oscillator Clock
      .OC_1_0   (oc_select),  // Oscillator Clock Select
      .XTR      (s_low),      // External Transmit/Receive Clock (not used)
      .LOCK_n   (s_high),     // Lock signal (from key)
      .CONSOLE_n(s_high),     // Console signal (from key)
      .SWMCL_n  (s_high),     // Software Master Clear (MCL)
      .EAUTO_n  (s_high),     // External Auto
      .RXD      (RXD),        // UART Receive A-C8

      // Signals from CPU Board to C-PLUG
      .RUN_n      (RUN_n),    // Run C-B14 (driven by Stop flip-flop: low while CPU is running)

      // Signals from CPU Board to A-PLUG
      .TXD        (TXD),          // UART Transmit TXD A-C7
      .DP_5_1_n   (s_dp_5_1_n),   // Data Path 5-1 A-> 1=C25, 2=C26, 3=C27, 4=C28, 5=C29

      /* Configuration switches (input to ND3202D board) */
      .SW1_CONSOLE     (s_high),             // Console switch
      .SEL_TESTMUX     (s_SEL_TESTMUX),      // Test MUX (select signals to test pads)
      .BAUD_RATE_SWITCH(s_baud_rate_switch), // Baud rate switch

      // outputs
      .CSBITS     (s_csbits),       // Microcode CPU BITS
      .TEST_4_0   (s_test_4_0),     // Test pads
      .TP1_INTRQ_n(s_tp1_intrq_n),  // TP1 Interrupt
      .CSA_12_0   (CSA_12_0),       // Microcode Address (for debugging)
      .LED        (LED[6:0]),       // 7 bit LED signals
      .DEBUG_CC_TERM(DEBUG_CC_TERM), // {TERM_n, CC3_n, CC2_n, CC1_n, CC0_n}
      .DEBUG_MCLK(DEBUG_MCLK),       // Memory clock
      .DEBUG_LCS_n(DEBUG_LCS_n),     // LCS_n: 0=loading, 1=loaded
      .DEBUG_FETCH(DEBUG_FETCH),
      .DEBUG_MR_n(DEBUG_MR_n),
      .DEBUG_CLEAR_n(DEBUG_CLEAR_n),
      .DEBUG_REFRQ_n(DEBUG_REFRQ_n),
      .DEBUG_INTRQ_n(DEBUG_INTRQ_n),
      .DEBUG_POWFAIL_n(DEBUG_POWFAIL_n),
      .DEBUG_FIDBO_15_0(DEBUG_FIDBO_15_0)

`ifdef MAIN_RAM_SDRAM
      // SDRAM main memory (threaded down to MEM_43 -> MEM_RAM_49_SDRAM)
      ,
      .clk2x(clk2x),
      .clk2x_sdram(clk2x_sdram),
      .O_sdram_clk(O_sdram_clk),
      .O_sdram_cke(O_sdram_cke),
      .O_sdram_cs_n(O_sdram_cs_n),
      .O_sdram_cas_n(O_sdram_cas_n),
      .O_sdram_ras_n(O_sdram_ras_n),
      .O_sdram_wen_n(O_sdram_wen_n),
      .IO_sdram_dq(IO_sdram_dq),
      .O_sdram_addr(O_sdram_addr),
      .O_sdram_ba(O_sdram_ba),
      .O_sdram_dqm(O_sdram_dqm),
      .DBG_MEMW(DBG_MEMW)
`endif
  );

endmodule
