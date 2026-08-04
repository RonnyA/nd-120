/****************************************************************************
** nd_storage - multi-client storage facade (top level)                    **
**                                                                         **
** THE one instance that owns the SD card and the SDRAM device region     **
** and serves N_CLIENTS client ports, each bound to one fixed root file   **
** on the FAT card (spec: docs/nd-storage-interface-spec.md; design:      **
** docs/nd-storage-design.md sections 2.1 and 5.1). Feature flag:         **
** SDFAT_STORAGE in sd_fat_features.vh (needs SDFAT_WRITE).               **
**                                                                         **
** Owns, exactly like the proven sd_fat_test_top arrangement:             **
**   - sd_file_reader: held in reset except while a mount runs (rstn =    **
**     rst & mount's rd_run) - every open is a full card re-init, the     **
**     proven rewind/card-swap recovery. target_name/target_len are       **
**     muxed from the FILEn_NAME/LEN parameters by the granted client.    **
**   - sd_writer: always alive; the engine's write-through path drives    **
**     its single-sector CMD24 interface (burst_len=0, rca=0 - the burst  **
**     interface is a later step). Under SDFAT_STORAGE_CHECK the mount-   **
**     time contiguity checker (nd_storage_fatchk.v) owns the writer's    **
**     command pins (start/sector, rd_mode=1) while chk_busy - the mount  **
**     FSM guarantees the engine and the checker never contend: the       **
**     check runs inside the mount's exclusive card phase (after M_PARK   **
**     set phase_write=1) while the engine is parked in E_OPEN.           **
**   - SD pin mux by phase_write (mount FSM owned): reader owns the pins  **
**     while a mount runs, the writer otherwise. Only _i/_o/_oe ports -   **
**     the single tristate lives at the board top (repo rule).            **
**   - mem port mux: the mount FSM owns the device port while mnt_busy    **
**     (the engine is parked in E_OPEN then); the engine otherwise.       **
**                                                                         **
** Client map (04-AUG-2026): 0 = TAPE.BPUN (tape-400), 1/2 = FLOPPY1/2.  **
** IMG, 3..5 = SMD0..2.IMG, 6/7 = WD0/WD1.IMG (the ST506/8-inch           **
** Winchester, ND_WINCHESTER.v). Winchester images are WDn.IMG, NEVER     **
** SMDn.IMG. SMD3 was dropped to make room: the grant index is THREE bits **
** so 8 clients is the ceiling, and the slot map must end at block 2048   **
** because s_blk_abs in nd_storage_engine is [10:0]. PRELOAD_MASK selects **
** clients get the v1 full-slot preload; the SMD clients (slots are       **
** Phase-4 cache windows) are OUTSIDE the default mask and answer         **
** open_err immediately, with zero card traffic.                          **
**                                                                         **
** Status outputs: sd_status 0=NOTCHK 1=NOCARD 2=ERROR 3=OK (updated at   **
** every mount end, degraded to ERROR by an engine watchdog or a card     **
** write error; a later successful open restores OK). card_type/fs_type   **
** are LATCHED from the reader while it runs (the reader's own copies     **
** reset when the mount FSM parks it).                                    **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`include "sd_fat_features.vh"

module nd_storage #(
    parameter            N_CLIENTS    = 8,
    parameter [2:0]      RD_CLK_DIV   = 3'd2,          // sd_file_reader (25-50 MHz clk)
    parameter [7:0]      WR_CLKDIV    = 8'd5,          // sd_writer bit clock divider
    parameter [31:0]     WD_MAX       = 32'd270_000_000,
    parameter            SIMULATE     = 0,             // short SD init in sim
    parameter [7:0]      PRELOAD_MASK = 8'b00000111,   // v1 full preload: clients 0..2
    parameter [52*8-1:0] FILE0_NAME   = "TAPE.BPUN",   parameter [7:0] FILE0_LEN = 8'd9,
    parameter [52*8-1:0] FILE1_NAME   = "FLOPPY1.IMG", parameter [7:0] FILE1_LEN = 8'd11,
    parameter [52*8-1:0] FILE2_NAME   = "FLOPPY2.IMG", parameter [7:0] FILE2_LEN = 8'd11,
    parameter [52*8-1:0] FILE3_NAME   = "SMD0.IMG",    parameter [7:0] FILE3_LEN = 8'd8,
    parameter [52*8-1:0] FILE4_NAME   = "SMD1.IMG",    parameter [7:0] FILE4_LEN = 8'd8,
    parameter [52*8-1:0] FILE5_NAME   = "SMD2.IMG",    parameter [7:0] FILE5_LEN = 8'd8,
    parameter [52*8-1:0] FILE6_NAME   = "WD0.IMG",     parameter [7:0] FILE6_LEN = 8'd7,
    parameter [52*8-1:0] FILE7_NAME   = "WD1.IMG",     parameter [7:0] FILE7_LEN = 8'd7,
    // slot map in 2048-byte blocks (design section 1.3 defaults)
    parameter [31:0] SLOT0_BASE_BLK = 32'd0,    parameter [31:0] SLOT0_SIZE_BLK = 32'd32,
    parameter [31:0] SLOT1_BASE_BLK = 32'd32,   parameter [31:0] SLOT1_SIZE_BLK = 32'd640,
    parameter [31:0] SLOT2_BASE_BLK = 32'd672,  parameter [31:0] SLOT2_SIZE_BLK = 32'd640,
    parameter [31:0] SLOT3_BASE_BLK = 32'd1312, parameter [31:0] SLOT3_SIZE_BLK = 32'd160,
    parameter [31:0] SLOT4_BASE_BLK = 32'd1472, parameter [31:0] SLOT4_SIZE_BLK = 32'd160,
    parameter [31:0] SLOT5_BASE_BLK = 32'd1632, parameter [31:0] SLOT5_SIZE_BLK = 32'd160,
    // The map MUST end at block 2048 or lower: nd_storage_engine's s_blk_abs
    // is [10:0] and feeds mem_addr = {blk_abs, word}, so anything past block
    // 2047 aliases silently back over the start of the region. The two
    // Winchester slots are 128 blocks each, which lands the end exactly on
    // 2048. There is NO headroom left - a ninth client needs a wider
    // s_blk_abs and mem_addr, which reaches into ND120_CORE, ND3202D, MEM_43
    // and the SDRAM bridge.
    parameter [31:0] SLOT6_BASE_BLK = 32'd1792, parameter [31:0] SLOT6_SIZE_BLK = 32'd128,
    parameter [31:0] SLOT7_BASE_BLK = 32'd1920, parameter [31:0] SLOT7_SIZE_BLK = 32'd128
) (
    input  wire clk_stor,
    input  wire rst_stor_n,
    input  wire clk_cpu,
    input  wire rst_cpu_n,

    // ---- SD pads (single tristate at the board top, repo rule) ----
    output wire sd_clk_o,
    input  wire sd_cmd_i,
    output wire sd_cmd_o,
    output wire sd_cmd_oe,
    input  wire sd_dat0_i,
    output wire sd_dat0_o,
    output wire sd_dat0_oe,

    // ---- SDRAM device port (clk_stor domain, design section 5.2) ----
    output wire        mem_start,   // 1-cycle pulse, only when mem_busy=0
    output wire        mem_we,
    output wire [19:0] mem_addr,    // 32-bit-word address inside the region
    output wire [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,   // valid at mem_done, then held
    input  wire        mem_busy,
    input  wire        mem_done,    // 1-cycle pulse

    // ---- client ports (clk_cpu domain, flattened; spec section 4) ----
    input  wire [N_CLIENTS-1:0]    open_req,
    output wire [N_CLIENTS-1:0]    open_ok,
    output wire [N_CLIENTS-1:0]    open_err,
    output wire [N_CLIENTS*32-1:0] size_bytes,
    input  wire [N_CLIENTS-1:0]    req,
    input  wire [N_CLIENTS-1:0]    wr,
    input  wire [N_CLIENTS*16-1:0] block,
    output wire [N_CLIENTS-1:0]    busy,
    output wire [N_CLIENTS-1:0]    done,
    output wire [N_CLIENTS-1:0]    err,
    output wire [N_CLIENTS*10-1:0] buf_addr,
    output wire [N_CLIENTS*16-1:0] buf_wdata,
    output wire [N_CLIENTS-1:0]    buf_we,
    input  wire [N_CLIENTS*16-1:0] buf_rdata,

    // ---- status (board LEDs / console, spec section 7) ----
    output reg  [1:0] sd_status,    // 0 NOTCHK, 1 NOCARD, 2 ERROR, 3 OK
    output reg  [1:0] card_type,    // latched: 1 SDv1, 2 SDv2, 3 SDHCv2
    output reg  [1:0] fs_type       // latched: 2 FAT16, 3 FAT32
);

  // ------------------------------------------------------- target file names
  // FILEn_NAME literals are left-justified; the reader wants byte 0 in the
  // low byte. Same reversal generate as sd_fat_test_top's g_target_names.
  wire [52*8-1:0] tgt0, tgt1, tgt2, tgt3, tgt4, tgt5, tgt6, tgt7;
  generate
    genvar tk;
    for (tk = 0; tk < 52; tk = tk + 1) begin : g_target_names
      assign tgt0[8*tk+:8] = (tk < FILE0_LEN) ? FILE0_NAME[8*(FILE0_LEN-1-tk)+:8] : 8'h00;
      assign tgt1[8*tk+:8] = (tk < FILE1_LEN) ? FILE1_NAME[8*(FILE1_LEN-1-tk)+:8] : 8'h00;
      assign tgt2[8*tk+:8] = (tk < FILE2_LEN) ? FILE2_NAME[8*(FILE2_LEN-1-tk)+:8] : 8'h00;
      assign tgt3[8*tk+:8] = (tk < FILE3_LEN) ? FILE3_NAME[8*(FILE3_LEN-1-tk)+:8] : 8'h00;
      assign tgt4[8*tk+:8] = (tk < FILE4_LEN) ? FILE4_NAME[8*(FILE4_LEN-1-tk)+:8] : 8'h00;
      assign tgt5[8*tk+:8] = (tk < FILE5_LEN) ? FILE5_NAME[8*(FILE5_LEN-1-tk)+:8] : 8'h00;
      assign tgt6[8*tk+:8] = (tk < FILE6_LEN) ? FILE6_NAME[8*(FILE6_LEN-1-tk)+:8] : 8'h00;
      assign tgt7[8*tk+:8] = (tk < FILE7_LEN) ? FILE7_NAME[8*(FILE7_LEN-1-tk)+:8] : 8'h00;
    end
  endgenerate

  wire [2:0] s_cur_client;  // mount FSM's latched client (stable per open)

  reg [52*8-1:0] s_target_name;
  reg [7:0]      s_target_len;
  always @(*) begin
    case (s_cur_client)
      3'd0:    begin s_target_name = tgt0; s_target_len = FILE0_LEN; end
      3'd1:    begin s_target_name = tgt1; s_target_len = FILE1_LEN; end
      3'd2:    begin s_target_name = tgt2; s_target_len = FILE2_LEN; end
      3'd3:    begin s_target_name = tgt3; s_target_len = FILE3_LEN; end
      3'd4:    begin s_target_name = tgt4; s_target_len = FILE4_LEN; end
      3'd5:    begin s_target_name = tgt5; s_target_len = FILE5_LEN; end
      3'd6:    begin s_target_name = tgt6; s_target_len = FILE6_LEN; end
      default: begin s_target_name = tgt7; s_target_len = FILE7_LEN; end
    endcase
  end

  // ------------------------------------------------------------- SD reader
  wire        s_rd_run;      // mount FSM: release the reader's reset
  wire        s_phase_write; // mount FSM: writer owns the SD pins
  wire        rd_rstn = rst_stor_n & s_rd_run;

  wire        rd_sdclk;
  wire        rd_cmd_o, rd_cmd_oe;
  wire [3:0]  rd_card_stat;
  wire [1:0]  rd_card_type;
  wire [1:0]  rd_fs_type;
  wire        rd_file_found;
  wire        rd_outen;
  wire [7:0]  rd_outbyte;
  wire        rd_scan_done;
  wire [31:0] rd_file_size;
  wire [31:0] rd_first_sector;
  wire [7:0]  rd_fs_cs;
  wire [31:0] rd_fs_fat0;
  wire [31:0] rd_found_cluster;

  sd_file_reader #(
      .CLK_DIV (RD_CLK_DIV),
      .SIMULATE(SIMULATE)
  ) u_reader (
      .rstn                   (rd_rstn),
      .clk                    (clk_stor),
      .sdclk                  (rd_sdclk),
      .sdcmd_i                (sd_cmd_i),
      .sdcmd_o                (rd_cmd_o),
      .sdcmd_oe               (rd_cmd_oe),
      .sddat0                 (sd_dat0_i),
      .card_stat              (rd_card_stat),
      .card_type              (rd_card_type),
      .filesystem_type        (rd_fs_type),
      .file_found             (rd_file_found),
      .outen                  (rd_outen),
      .outbyte                (rd_outbyte),
      .scan_done              (rd_scan_done),
      .found_file_size        (rd_file_size),
      .target_name            (s_target_name),
      .target_len             (s_target_len),
      .dir_entry_valid        (),
      .dir_entry_name         (),
      .dir_entry_len          (),
      .dir_entry_size         (),
      .dir_entry_date         (),
      .dir_entry_cluster      (),
      .dir_entry_is_dir       (),
      .found_file_first_sector(rd_first_sector),
      .fs_cluster_size        (rd_fs_cs),
      .fs_fat0_sector         (rd_fs_fat0),
      .fs_sectors_per_fat     (),
      .fs_num_fats            (),
      .fs_data_base_sector    (),
      .fs_total_sectors       (),
      .fs_root_cluster        (),
      .found_dir_entry_sector (),
      .found_dir_entry_index  (),
      .found_file_cluster     (rd_found_cluster)
  );

  // ------------------------------------------------------------- SD writer
  // Engine write-through path, single-sector CMD24 API. burst_len/rca are
  // tied off (bursts are a later optimization). The command pins are muxed:
  // the fatchk contiguity checker owns them (rd_mode=1, CMD17 FAT reads)
  // while chk_busy, the engine otherwise - never both (mount FSM contract).
  wire        wr_sdclk;
  wire        wr_cmd_o, wr_cmd_oe, wr_dat0_o, wr_dat0_oe;
  wire        sdw_start, sdw_rd_mode, sdw_busy, sdw_done, sdw_err;
  wire [31:0] sdw_sector;
  wire [8:0]  sdw_rd_addr;
  wire [7:0]  sdw_rd_data;
  wire        sdw_rx_we;
  wire [8:0]  sdw_rx_addr;
  wire [7:0]  sdw_rx_data;
  wire        e_sdw_start;             // engine's command set
  wire [31:0] e_sdw_sector;

  sd_writer #(
      .CLKDIV(WR_CLKDIV)
  ) u_writer (
      .clk       (clk_stor),
      .rst_n     (rst_stor_n),
      .sd_clk_o  (wr_sdclk),
      .sd_cmd_i  (sd_cmd_i),
      .sd_cmd_o  (wr_cmd_o),
      .sd_cmd_oe (wr_cmd_oe),
      .sd_dat0_i (sd_dat0_i),
      .sd_dat0_o (wr_dat0_o),
      .sd_dat0_oe(wr_dat0_oe),
      .start     (sdw_start),
      .rd_mode   (sdw_rd_mode),
      .sector    (sdw_sector),
      .busy      (sdw_busy),
      .done      (sdw_done),
      .err       (sdw_err),
      .burst_len (9'd0),
      .rca       (16'd0),
      .block_next(),
      .rd_addr   (sdw_rd_addr),
      .rd_data   (sdw_rd_data),
      .rx_we     (sdw_rx_we),
      .rx_addr   (sdw_rx_addr),
      .rx_data   (sdw_rx_data)
  );

  // ------------------------------------------------------------- SD pin mux
  // The ONLY consumers of the pads; the tristate stays at the board top.
  assign sd_clk_o   = s_phase_write ? wr_sdclk  : rd_sdclk;
  assign sd_cmd_o   = s_phase_write ? wr_cmd_o  : rd_cmd_o;
  assign sd_cmd_oe  = s_phase_write ? wr_cmd_oe : rd_cmd_oe;
  assign sd_dat0_o  = wr_dat0_o;
  assign sd_dat0_oe = s_phase_write & wr_dat0_oe;

  // ------------------------------------------------------------- mount FSM
  wire        mnt_start, mnt_done, mnt_err, mnt_busy;
  wire [2:0]  mnt_client;
  wire        m_mem_start;
  wire [19:0] m_mem_addr;
  wire [31:0] m_mem_wdata;
  wire        mnt_st_upd;
  wire [1:0]  mnt_st_val;

  wire [N_CLIENTS-1:0]    s_open_ok_stor;
  wire [N_CLIENTS-1:0]    s_open_err_stor;
  wire [N_CLIENTS*32-1:0] s_size_stor;
  wire [N_CLIENTS*16-1:0] s_n_blocks;
  wire [N_CLIENTS*32-1:0] s_first_sector;

  // fatchk handoff (driven/consumed below; tied off when the flag is off)
  wire        m_chk_start, m_chk_done, m_chk_ok;
  wire [31:0] m_chk_first_cluster, m_chk_fat0_sector, m_chk_size;
  wire [7:0]  m_chk_cluster_size;
  wire        m_chk_is_fat32;

  nd_storage_mount #(
      .N_CLIENTS     (N_CLIENTS),
      .WD_MAX        (WD_MAX),
      .PRELOAD_MASK  (PRELOAD_MASK),
      .SLOT0_BASE_BLK(SLOT0_BASE_BLK), .SLOT0_SIZE_BLK(SLOT0_SIZE_BLK),
      .SLOT1_BASE_BLK(SLOT1_BASE_BLK), .SLOT1_SIZE_BLK(SLOT1_SIZE_BLK),
      .SLOT2_BASE_BLK(SLOT2_BASE_BLK), .SLOT2_SIZE_BLK(SLOT2_SIZE_BLK),
      .SLOT3_BASE_BLK(SLOT3_BASE_BLK), .SLOT3_SIZE_BLK(SLOT3_SIZE_BLK),
      .SLOT4_BASE_BLK(SLOT4_BASE_BLK), .SLOT4_SIZE_BLK(SLOT4_SIZE_BLK),
      .SLOT5_BASE_BLK(SLOT5_BASE_BLK), .SLOT5_SIZE_BLK(SLOT5_SIZE_BLK),
      .SLOT6_BASE_BLK(SLOT6_BASE_BLK), .SLOT6_SIZE_BLK(SLOT6_SIZE_BLK),
      .SLOT7_BASE_BLK(SLOT7_BASE_BLK), .SLOT7_SIZE_BLK(SLOT7_SIZE_BLK)
  ) u_mount (
      .clk_stor          (clk_stor),
      .rst_stor_n        (rst_stor_n),
      .mnt_start         (mnt_start),
      .mnt_client        (mnt_client),
      .mnt_done          (mnt_done),
      .mnt_err           (mnt_err),
      .mnt_busy          (mnt_busy),
      .rd_run            (s_rd_run),
      .phase_write       (s_phase_write),
      .cur_client        (s_cur_client),
      .card_stat         (rd_card_stat),
      .file_found        (rd_file_found),
      .scan_done         (rd_scan_done),
      .found_size        (rd_file_size),
      .found_first_sector(rd_first_sector),
      .found_cluster     (rd_found_cluster),
      .fs_cluster_size   (rd_fs_cs),
      .fs_fat0_sector    (rd_fs_fat0),
      .fs_is_fat32       (rd_fs_type == 2'd3),
      .outen             (rd_outen),
      .outbyte           (rd_outbyte),
      .mem_start         (m_mem_start),
      .mem_we            (),
      .mem_addr          (m_mem_addr),
      .mem_wdata         (m_mem_wdata),
      .mem_busy          (mem_busy),
      .mem_done          (mem_done),
      .chk_start         (m_chk_start),
      .chk_done          (m_chk_done),
      .chk_ok            (m_chk_ok),
      .chk_first_cluster (m_chk_first_cluster),
      .chk_cluster_size  (m_chk_cluster_size),
      .chk_fat0_sector   (m_chk_fat0_sector),
      .chk_is_fat32      (m_chk_is_fat32),
      .chk_size          (m_chk_size),
      .open_ok           (s_open_ok_stor),
      .open_err          (s_open_err_stor),
      .size_bytes        (s_size_stor),
      .n_blocks          (s_n_blocks),
      .first_sector      (s_first_sector),
      .st_upd            (mnt_st_upd),
      .st_val            (mnt_st_val),
      .load_fifo_ovf     ()
  );

  // ------------------------------------------------------------- engine
  wire        e_mem_start, e_mem_we;
  wire [19:0] e_mem_addr;
  wire [31:0] e_mem_wdata;
  wire        eng_wd_err;

  nd_storage_engine #(
      .N_CLIENTS     (N_CLIENTS),
      .WD_MAX        (WD_MAX),
      .SLOT0_BASE_BLK(SLOT0_BASE_BLK),
      .SLOT1_BASE_BLK(SLOT1_BASE_BLK),
      .SLOT2_BASE_BLK(SLOT2_BASE_BLK),
      .SLOT3_BASE_BLK(SLOT3_BASE_BLK),
      .SLOT4_BASE_BLK(SLOT4_BASE_BLK),
      .SLOT5_BASE_BLK(SLOT5_BASE_BLK),
      .SLOT6_BASE_BLK(SLOT6_BASE_BLK),
      .SLOT7_BASE_BLK(SLOT7_BASE_BLK)
  ) u_engine (
      .clk_stor       (clk_stor),
      .rst_stor_n     (rst_stor_n),
      .clk_cpu        (clk_cpu),
      .rst_cpu_n      (rst_cpu_n),
      .mem_start      (e_mem_start),
      .mem_we         (e_mem_we),
      .mem_addr       (e_mem_addr),
      .mem_wdata      (e_mem_wdata),
      .mem_rdata      (mem_rdata),
      .mem_busy       (mem_busy),
      .mem_done       (mem_done),
      .mnt_start      (mnt_start),
      .mnt_client     (mnt_client),
      .mnt_done       (mnt_done),
      .mnt_err        (mnt_err),
      .open_ok_stor   (s_open_ok_stor),
      .open_err_stor  (s_open_err_stor),
      .size_bytes_stor(s_size_stor),
      .n_blocks       (s_n_blocks),
      .first_sector   (s_first_sector),
      .sdw_start      (e_sdw_start),
      .sdw_sector     (e_sdw_sector),
      .sdw_busy       (sdw_busy),
      .sdw_done       (sdw_done),
      .sdw_err        (sdw_err),
      .sdw_rd_addr    (sdw_rd_addr),
      .sdw_rd_data    (sdw_rd_data),
      .eng_wd_err     (eng_wd_err),
      .open_req       (open_req),
      .open_ok        (open_ok),
      .open_err       (open_err),
      .size_bytes     (size_bytes),
      .req            (req),
      .wr             (wr),
      .block          (block),
      .busy           (busy),
      .done           (done),
      .err            (err),
      .buf_addr       (buf_addr),
      .buf_wdata      (buf_wdata),
      .buf_we         (buf_we),
      .buf_rdata      (buf_rdata)
  );

  // ------------------------------------------------------------- fatchk
  // Mount-time contiguity checker (design section 2.4): owns the sd_writer
  // command pins in read mode while chk_busy; runs only from the mount's
  // M_CHK state, after M_PARK set phase_write=1 - by construction it never
  // contends with the engine's write-through path.
`ifdef SDFAT_STORAGE_CHECK
  wire        f_chk_busy;
  wire        f_sdw_start;
  wire [31:0] f_sdw_sector;

  nd_storage_fatchk #(
      .WD_MAX(WD_MAX)
  ) u_fatchk (
      .clk_stor     (clk_stor),
      .rst_stor_n   (rst_stor_n),
      .chk_start    (m_chk_start),
      .chk_busy     (f_chk_busy),
      .chk_done     (m_chk_done),
      .chk_ok       (m_chk_ok),
      .fs_is_fat32  (m_chk_is_fat32),
      .cluster_size (m_chk_cluster_size),
      .fat0_sector  (m_chk_fat0_sector),
      .first_cluster(m_chk_first_cluster),
      .size_bytes   (m_chk_size),
      .sdw_start    (f_sdw_start),
      .sdw_sector   (f_sdw_sector),
      .sdw_done     (sdw_done),
      .sdw_err      (sdw_err),
      .sdw_rx_we    (sdw_rx_we),
      .sdw_rx_addr  (sdw_rx_addr),
      .sdw_rx_data  (sdw_rx_data)
  );

  assign sdw_start   = f_chk_busy ? f_sdw_start  : e_sdw_start;
  assign sdw_rd_mode = f_chk_busy;
  assign sdw_sector  = f_chk_busy ? f_sdw_sector : e_sdw_sector;
`else
  // feature stripped: the engine is the only sd_writer master and the
  // mount's M_CHK state passes straight through (no checker to answer)
  assign sdw_start   = e_sdw_start;
  assign sdw_rd_mode = 1'b0;
  assign sdw_sector  = e_sdw_sector;
  assign m_chk_done  = 1'b0;
  assign m_chk_ok    = 1'b0;
`endif

  // ------------------------------------------------------------- mem port mux
  // Mount and engine are mutually exclusive by arbiter construction (the
  // engine sits in E_OPEN while mnt_busy); returns fan out to both.
  assign mem_start = mnt_busy ? m_mem_start : e_mem_start;
  assign mem_we    = mnt_busy ? 1'b1        : e_mem_we;
  assign mem_addr  = mnt_busy ? m_mem_addr  : e_mem_addr;
  assign mem_wdata = mnt_busy ? m_mem_wdata : e_mem_wdata;

  // ------------------------------------------------------------- status
  // card_type/fs_type: latch while the reader runs (its copies reset when
  // the mount FSM parks it again)
  always @(posedge clk_stor) begin
    if (!rst_stor_n) begin
      card_type <= 2'd0;
      fs_type   <= 2'd0;
    end else begin
      if (rd_card_type != 2'd0) card_type <= rd_card_type;
      if (rd_fs_type >= 2'd2)   fs_type   <= rd_fs_type;
    end
  end

  // sd_status: mount verdicts win, card-touching errors degrade to ERROR
  reg s_wd_err_q;
  always @(posedge clk_stor) begin
    if (!rst_stor_n) begin
      sd_status  <= 2'd0;  // NOTCHK
      s_wd_err_q <= 1'b0;
    end else begin
      s_wd_err_q <= eng_wd_err;
      if (mnt_st_upd)                             sd_status <= mnt_st_val;
      else if ((eng_wd_err && !s_wd_err_q) || sdw_err) sd_status <= 2'd2;
    end
  end

endmodule
