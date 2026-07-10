/****************************************************************************
** Tang Nano 20K SD + FAT test (Milestone 1 of the SD-BPUN device plan)    **
**                                                                         **
** Interactive UART menu (BL616 USB serial, 9600 8N1) over the reusable    **
** SD/FAT library in Verilog/SD-FAT/:                                      **
**                                                                         **
**   SD: OK                     (persistent card status)                   **
**   1=LIST 2=DUMP BOOT.BPUN 3=COPY TO TEST.TXT H=HELP                     **
**   #                                                                     **
**                                                                         **
**   1  re-init the card, mount FAT16/FAT32, list the root directory:      **
**      size (or <DIR>), date and name of every file and subdirectory      **
**             2342  10-JAN-2025  BOOT.BPUN                                **
**            <DIR>  11-JUL-2026  HDD                                      **
**   2  find BOOT.BPUN, buffer it (64 KB BRAM) and hex/octal-dump it       **
**   3  COPY: read BOOT.BPUN into the buffer, then rewrite the data        **
**      sectors of the PRE-CREATED TEST.TXT in place (Route B of           **
**      SD-FAT/README.md - the card recipe pre-creates a contiguous        **
**      TEST.TXT of sufficient size; no FAT metadata is touched, so the    **
**      filesystem stays consistent). Uses the project sd_writer (CMD24).  **
**   4  WRBLK1: write a counter pattern (1024 big-endian 16-bit words,     **
**      word[w] = w) into 1-kiloword block 1 of BOOT.BPUN. ND-120 block    **
**      framing: 1 block = 1024 words = 2048 bytes = 4 SD sectors; block   **
**      N of a file lives at file_first_sector + 4*N. Refuses when the     **
**      file is smaller than (N+1)*2048 bytes (a shorter file's cluster    **
**      chain ends inside the block - writing there would corrupt the      **
**      NEXT file). Validate with 2 (DUMP): block 1 shows the pattern,     **
**      blocks 0 and 2 are untouched.                                      **
**   H  detailed help; any other key reprints the menu                     **
**   S1 full reset                                                         **
**                                                                         **
** Robustness: every wait state has a watchdog - no card, no file,         **
** unmountable filesystem, stuck reads and failed writes all print an      **
** ERROR line and fall back to the menu; the menu SD: line shows           **
** NOT CHECKED / NO CARD / ERROR / OK.                                     **
**                                                                         **
** SD pins per the Sipeed Tang Nano 20K schematic (verified against       **
** sipeed/TangNano-20K-example, nestang and snestang constraint files):    **
** CLK=83 CMD=82 DAT0=84 DAT1=85 DAT2=80 DAT3=81. CMD and DAT0 are         **
** bidirectional per the SD specification; the ONLY tristate drivers sit   **
** here at the top-level pads (repo rule: no 'z' inside the FPGA fabric).  **
**                                                                         **
** LEDs (active low): [0] alive  [1] FS mounted  [2] file found            **
**                    [3] command done  [4] truncated  [5] error           **
**                                                                         **
** Single 27 MHz clock domain - no PLL, no derived clocks (the SD          **
** library and sd_writer divide their bus clocks with enable-style         **
** dividers).                                                              **
**                                                                         **
** Design plan: Verilog/docs/sd-bpun-device-plan.md (section 9).           **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/

module sd_fat_test_top #(
    parameter            CLK_FREQ      = 27_000_000,   // crystal, used directly
    parameter            BAUD          = 9600,
    parameter            SIMULATE      = 0,            // 1: shorter SD init (sim only)
    parameter [31:0]     WD_MAX        = 270_000_000,  // watchdog: 10 s at 27 MHz
    parameter            FILE_NAME_LEN = 9,
    parameter [52*8-1:0] FILE_NAME     = "BOOT.BPUN",
    parameter            FILE2_LEN     = 8,
    parameter [52*8-1:0] FILE2_NAME    = "TEST.TXT",   // COPY target (pre-created)
    parameter            BUF_AW        = 16            // 2^16 = 64 KB buffer
) (
    input  sys_clk,   // 27 MHz crystal
    input  s1,        // S1 push button - full reset
    input  uart_rxp,  // from BL616 USB serial
    output uart_txp,  // to BL616 USB serial

    // microSD slot, SD-native 1-bit mode (DAT1-3 parked high)
    output sd_clk,
    inout  sd_cmd,    // bidirectional: host commands / card responses
    inout  sd_dat0,   // bidirectional: card read data / host write data
    output sd_dat1,
    output sd_dat2,
    output sd_dat3,

    output [5:0] led  // active low
);

  localparam DELAY_FRAMES = CLK_FREQ / BAUD;

  wire clk = sys_clk;  // single 27 MHz domain, no PLL

  assign sd_dat1 = 1'b1;  // keep the card in SD-native (non-SPI) mode
  assign sd_dat2 = 1'b1;
  assign sd_dat3 = 1'b1;

  /*******************************************************************************
   ** Reset: power-on counter, reloaded by S1 = full restart                     **
   *******************************************************************************/
  reg s1_r1, s1_r2, s1_r3;
  always @(posedge clk) begin
    s1_r1 <= s1;
    s1_r2 <= s1_r1;
    s1_r3 <= s1_r2;
  end
  wire s1_press = s1_r2 & ~s1_r3;

  reg [10:0] rst_cnt = 0;
  wire sys_rst_n = rst_cnt[10];

  always @(posedge clk) begin
    if (s1_press) rst_cnt <= 0;
    else if (!rst_cnt[10]) rst_cnt <= rst_cnt + 1;
  end

  // The SD reader is held in reset between commands; each menu command
  // releases it for a full init+mount+scan run (= the future tape rewind).
  // COPY resets it a second time (rdrst_cnt) to re-scan for TEST.TXT, and
  // parks it (phase_write) while the sd_writer owns the card.
  reg       cmd_running;
  reg [4:0] rdrst_cnt;
  reg       phase_write;
  wire sd_rst_n = sys_rst_n & cmd_running & (rdrst_cnt == 0) & ~phase_write;

  /*******************************************************************************
   ** Command mode and runtime target file name                                 **
   *******************************************************************************/
  localparam M_DUMP = 2'd0;
  localparam M_LIST = 2'd1;
  localparam M_COPY = 2'd2;
  localparam M_BLK  = 2'd3;  // write the test pattern into 1KW block 1

  localparam [8:0] BLK_NO = 9'd1;  // the block the menu command updates

  reg [1:0] mode;
  reg       copy_phase;  // COPY: 0 = read BOOT.BPUN, 1 = locate TEST.TXT
  wire      mode_list = (mode == M_LIST);

  wire [52*8-1:0] tgt_boot, tgt_test;
  generate
    genvar tk;
    for (tk = 0; tk < 52; tk = tk + 1) begin : g_target_names
      assign tgt_boot[8*tk+:8] =
          (tk < FILE_NAME_LEN) ? FILE_NAME[8*(FILE_NAME_LEN-1-tk)+:8] : 8'h00;
      assign tgt_test[8*tk+:8] =
          (tk < FILE2_LEN) ? FILE2_NAME[8*(FILE2_LEN-1-tk)+:8] : 8'h00;
    end
  endgenerate

  wire copy2 = (mode == M_COPY) && copy_phase;
  wire [52*8-1:0] target_name = copy2 ? tgt_test : tgt_boot;
  wire [7:0] target_len = mode_list ? 8'd0 : (copy2 ? FILE2_LEN[7:0] : FILE_NAME_LEN[7:0]);

  /*******************************************************************************
   ** SD card + FAT filesystem library (Verilog/SD-FAT/, board-independent)     **
   *******************************************************************************/
  wire        rd_sdclk;
  wire        rd_cmd_o, rd_cmd_oe;
  wire [3:0]  card_stat;
  wire [1:0]  card_type;
  wire [1:0]  fs_type;
  wire        file_found;
  wire        f_outen;
  wire [7:0]  f_outbyte;
  wire        scan_done;
  wire [31:0] file_size;
  wire        dir_valid;
  wire [52*8-1:0] dir_name;
  wire [7:0]  dir_len;
  wire [31:0] dir_size;
  wire [15:0] dir_date;
  wire        dir_isdir;
  wire [31:0] file_first_sector;

  sd_file_reader #(
      .CLK_DIV (3'd2),      // 27 MHz input clock -> /2 divider class
      .SIMULATE(SIMULATE)
  ) u_sd (
      .rstn           (sd_rst_n),
      .clk            (clk),
      .sdclk          (rd_sdclk),
      .sdcmd_i        (sd_cmd),
      .sdcmd_o        (rd_cmd_o),
      .sdcmd_oe       (rd_cmd_oe),
      .sddat0         (sd_dat0),
      .card_stat      (card_stat),
      .card_type      (card_type),
      .filesystem_type(fs_type),
      .file_found     (file_found),
      .outen          (f_outen),
      .outbyte        (f_outbyte),
      .scan_done      (scan_done),
      .found_file_size(file_size),
      .target_name    (target_name),
      .target_len     (target_len),
      .dir_entry_valid(dir_valid),
      .dir_entry_name (dir_name),
      .dir_entry_len  (dir_len),
      .dir_entry_size (dir_size),
      .dir_entry_date (dir_date),
      .dir_entry_is_dir(dir_isdir),
      .found_file_first_sector(file_first_sector)
  );

  // card init done = sector-read FSM reached its CMD17 idle state (8) or beyond
  wire card_ready = (card_stat >= 4'd8);

  /*******************************************************************************
   ** SD sector writer (project code, MIT) - owns the card during COPY writes   **
   *******************************************************************************/
  reg             wr_start;
  reg  [31:0]     tgt_sector;
  reg  [8:0]      nsec, seccnt;
  reg  [BUF_AW:0] copy_len;

  wire       wr_sdclk, wr_cmd_o, wr_cmd_oe, wr_dat0_o, wr_dat0_oe;
  wire       wr_busy, wr_done, wr_err;
  wire [8:0] wr_rd_addr;
  wire [7:0] wr_data_in;

  sd_writer #(
      .CLKDIV(8'd5)  // 27 MHz / 10 = 2.7 MHz write clock (same class as the reader)
  ) u_wr (
      .clk       (clk),
      .rst_n     (sys_rst_n),
      .sd_clk_o  (wr_sdclk),
      .sd_cmd_i  (sd_cmd),
      .sd_cmd_o  (wr_cmd_o),
      .sd_cmd_oe (wr_cmd_oe),
      .sd_dat0_i (sd_dat0),
      .sd_dat0_o (wr_dat0_o),
      .sd_dat0_oe(wr_dat0_oe),
      .start     (wr_start),
      .sector    (tgt_sector + {23'b0, seccnt}),
      .busy      (wr_busy),
      .done      (wr_done),
      .err       (wr_err),
      .rd_addr   (wr_rd_addr),
      .rd_data   (wr_data_in)
  );

  /*******************************************************************************
   ** SD pin muxes - the ONLY tristate drivers, at the pads (repo rule)         **
   *******************************************************************************/
  assign sd_clk = phase_write ? wr_sdclk : rd_sdclk;
  wire cmd_oe = phase_write ? wr_cmd_oe : rd_cmd_oe;
  wire cmd_o  = phase_write ? wr_cmd_o : rd_cmd_o;
  assign sd_cmd  = cmd_oe ? cmd_o : 1'bz;
  assign sd_dat0 = (phase_write && wr_dat0_oe) ? wr_dat0_o : 1'bz;

  /*******************************************************************************
   ** LIST mode: pack "      size  DD-MMM-YYYY  NAME" lines into the buffer     **
   *******************************************************************************/
  function [31:0] pow10(input [3:0] i);
    case (i)
      4'd0: pow10 = 32'd1;
      4'd1: pow10 = 32'd10;
      4'd2: pow10 = 32'd100;
      4'd3: pow10 = 32'd1000;
      4'd4: pow10 = 32'd10000;
      4'd5: pow10 = 32'd100000;
      4'd6: pow10 = 32'd1000000;
      4'd7: pow10 = 32'd10000000;
      4'd8: pow10 = 32'd100000000;
      default: pow10 = 32'd1000000000;
    endcase
  endfunction

  function [23:0] month3(input [3:0] m);
    case (m)
      4'd1:  month3 = "JAN";
      4'd2:  month3 = "FEB";
      4'd3:  month3 = "MAR";
      4'd4:  month3 = "APR";
      4'd5:  month3 = "MAY";
      4'd6:  month3 = "JUN";
      4'd7:  month3 = "JUL";
      4'd8:  month3 = "AUG";
      4'd9:  month3 = "SEP";
      4'd10: month3 = "OCT";
      4'd11: month3 = "NOV";
      4'd12: month3 = "DEC";
      default: month3 = "???";
    endcase
  endfunction

  localparam S_DIRPAD = "     <DIR>";  // 10 chars, right-aligned like the sizes

  localparam PK_IDLE   = 4'd0;
  localparam PK_DEC    = 4'd1;  // decimal emit engine (size / day / year)
  localparam PK_DIRSTR = 4'd2;
  localparam PK_SPA    = 4'd3;  // two spaces after the size column
  localparam PK_DASH1  = 4'd4;
  localparam PK_MON    = 4'd5;
  localparam PK_DASH2  = 4'd6;
  localparam PK_SPB    = 4'd7;  // two spaces after the date column
  localparam PK_WR     = 4'd8;  // the name
  localparam PK_CR     = 4'd9;
  localparam PK_LF     = 4'd10;

  reg [3:0]      pk_state, pk_ret;
  reg [52*8-1:0] pk_name;
  reg [7:0]      pk_len, pk_i;
  reg [15:0]     pk_date;
  reg            pk_we;
  reg [7:0]      pk_byte;
  reg [31:0]     pk_dval;    // decimal engine value
  reg [3:0]      pk_dpow;    // current power-of-ten index
  reg [3:0]      pk_ddig;    // current digit
  reg            pk_dpad;    // 1 = zero-pad (day/year), 0 = space-pad (size)
  reg            pk_dstart;  // a nonzero digit has been emitted

  wire pk_print_num = pk_dpad || pk_dstart || (pk_ddig != 0) || (pk_dpow == 0);

  always @(posedge clk) begin
    if (!sd_rst_n) begin
      pk_state  <= PK_IDLE;
      pk_ret    <= PK_IDLE;
      pk_name   <= 0;
      pk_len    <= 0;
      pk_i      <= 0;
      pk_date   <= 0;
      pk_we     <= 1'b0;
      pk_byte   <= 8'h00;
      pk_dval   <= 0;
      pk_dpow   <= 0;
      pk_ddig   <= 0;
      pk_dpad   <= 1'b0;
      pk_dstart <= 1'b0;
    end else begin
      pk_we <= 1'b0;
      case (pk_state)
        PK_IDLE:
        if (mode_list && dir_valid && dir_len != 0) begin
          pk_name <= dir_name;
          pk_len  <= dir_len;
          pk_date <= dir_date;
          pk_i    <= 0;
          if (dir_isdir) begin
            pk_state <= PK_DIRSTR;
          end else begin
            pk_dval   <= dir_size;
            pk_dpow   <= 4'd9;
            pk_ddig   <= 0;
            pk_dpad   <= 1'b0;
            pk_dstart <= 1'b0;
            pk_ret    <= PK_SPA;
            pk_state  <= PK_DEC;
          end
        end

        PK_DEC:  // one decimal number, MSD first, one char per emit cycle
        if (pk_dval >= pow10(pk_dpow)) begin
          pk_dval <= pk_dval - pow10(pk_dpow);
          pk_ddig <= pk_ddig + 4'd1;
        end else begin
          pk_byte   <= pk_print_num ? (8'h30 + {4'b0, pk_ddig}) : 8'h20;
          pk_we     <= 1'b1;
          pk_dstart <= pk_dstart | (pk_ddig != 0);
          pk_ddig   <= 0;
          if (pk_dpow == 0) pk_state <= pk_ret;
          else pk_dpow <= pk_dpow - 4'd1;
        end

        PK_DIRSTR: begin
          pk_byte <= S_DIRPAD[8*(9-pk_i)+:8];
          pk_we   <= 1'b1;
          if (pk_i == 8'd9) begin
            pk_i     <= 0;
            pk_state <= PK_SPA;
          end else pk_i <= pk_i + 8'd1;
        end

        PK_SPA: begin
          pk_byte <= 8'h20;
          pk_we   <= 1'b1;
          if (pk_i == 8'd1) begin
            // load the day (2 digits, zero-padded)
            pk_i     <= 0;
            pk_dval  <= {27'b0, pk_date[4:0]};
            pk_dpow  <= 4'd1;
            pk_ddig  <= 0;
            pk_dpad  <= 1'b1;
            pk_ret   <= PK_DASH1;
            pk_state <= PK_DEC;
          end else pk_i <= pk_i + 8'd1;
        end

        PK_DASH1: begin
          pk_byte  <= "-";
          pk_we    <= 1'b1;
          pk_i     <= 0;
          pk_state <= PK_MON;
        end

        PK_MON: begin
          pk_byte <= month3(pk_date[8:5]) >> (8 * (2 - pk_i));
          pk_we   <= 1'b1;
          if (pk_i == 8'd2) begin
            pk_i     <= 0;
            pk_state <= PK_DASH2;
          end else pk_i <= pk_i + 8'd1;
        end

        PK_DASH2: begin
          pk_byte  <= "-";
          pk_we    <= 1'b1;
          // load the year (4 digits, zero-padded; FAT epoch 1980)
          pk_dval  <= 32'd1980 + {25'b0, pk_date[15:9]};
          pk_dpow  <= 4'd3;
          pk_ddig  <= 0;
          pk_dpad  <= 1'b1;
          pk_ret   <= PK_SPB;
          pk_state <= PK_DEC;
        end

        PK_SPB: begin
          pk_byte <= 8'h20;
          pk_we   <= 1'b1;
          if (pk_i == 8'd1) begin
            pk_i     <= 0;
            pk_state <= PK_WR;
          end else pk_i <= pk_i + 8'd1;
        end

        PK_WR:
        if (pk_i < pk_len) begin
          pk_byte <= pk_name[8*pk_i+:8];
          pk_we   <= 1'b1;
          pk_i    <= pk_i + 8'd1;
        end else pk_state <= PK_CR;

        PK_CR: begin
          pk_byte  <= 8'h0D;
          pk_we    <= 1'b1;
          pk_state <= PK_LF;
        end

        PK_LF: begin
          pk_byte  <= 8'h0A;
          pk_we    <= 1'b1;
          pk_state <= PK_IDLE;
        end

        default: pk_state <= PK_IDLE;
      endcase
    end
  end

  /*******************************************************************************
   ** 64 KB byte buffer (BRAM): file bytes (DUMP/COPY) or list lines (LIST) in, **
   ** hex_dumper / buf_text_printer / sd_writer out                             **
   *******************************************************************************/
  reg [7:0] file_buf[0:(1 << BUF_AW)-1];

  reg [BUF_AW:0] wptr;
  reg            trunc;

  // COPY phase 1 (locating TEST.TXT) must not disturb the buffered file
  wire       wr_gate = (mode == M_COPY) && copy_phase;
  wire [7:0] wr_byte = mode_list ? pk_byte : f_outbyte;
  wire       wr_req  = !wr_gate && (mode_list ? pk_we : f_outen);
  wire       buf_we  = wr_req && !wptr[BUF_AW];

  always @(posedge clk) begin
    if (buf_we) file_buf[wptr[BUF_AW-1:0]] <= wr_byte;
  end

  always @(posedge clk) begin
    if (!sd_rst_n) begin
      wptr  <= 0;
      trunc <= 0;
    end else begin
      if (buf_we) wptr <= wptr + 1;
      if (wr_req && wptr[BUF_AW]) trunc <= 1;
    end
  end

  wire [BUF_AW:0]   widx = {seccnt[BUF_AW-9:0], 9'b0} + {8'b0, wr_rd_addr};
  wire [BUF_AW-1:0] dump_addr, text_addr;
  reg  [7:0]        buf_rdata;
  wire              tp_busy;
  wire [BUF_AW-1:0] rd_addr = phase_write ? widx[BUF_AW-1:0]
                                          : (tp_busy ? text_addr : dump_addr);
  always @(posedge clk) buf_rdata <= file_buf[rd_addr];

  // COPY: buffer bytes, zero-filled past the file end (real tapes had zero
  // trailers). WRBLK1: counter pattern - 1024 big-endian 16-bit words,
  // word[w] = w, so every sector of the block is distinct and a misplaced
  // write cannot pass the dump check.
  wire [10:0] blk_off  = widx[10:0];              // byte offset inside the block
  wire [9:0]  blk_word = blk_off[10:1];           // word index 0..1023
  wire [7:0]  blk_pat  = blk_off[0] ? blk_word[7:0] : {6'b0, blk_word[9:8]};
  assign wr_data_in = (mode == M_BLK) ? blk_pat
                    : (widx < copy_len) ? buf_rdata : 8'h00;

  /*******************************************************************************
   ** UART: rx = menu keys, tx shared by the three printers                     **
   *******************************************************************************/
  wire [7:0] rx_data;
  wire       rx_valid;

  uart_rx #(
      .DELAY_FRAMES(DELAY_FRAMES)
  ) u_rx (
      .clk(clk),
      .rst_n(sys_rst_n),
      .rxd(uart_rxp),
      .rx_data(rx_data),
      .rx_valid(rx_valid)
  );

  reg        sp_start;
  reg  [4:0] sp_msg;
  wire       sp_busy;
  wire [7:0] sp_tx_data;
  wire       sp_tx_valid;

  status_printer u_sp (
      .clk(clk),
      .rst_n(sys_rst_n),
      .start(sp_start),
      .msg(sp_msg),
      .busy(sp_busy),
      .tx_data(sp_tx_data),
      .tx_valid(sp_tx_valid),
      .tx_busy(tx_busy)
  );

  reg        hd_start;
  wire       hd_busy;
  wire [7:0] hd_tx_data;
  wire       hd_tx_valid;

  hex_dumper #(
      .ADDR_W(BUF_AW)
  ) u_dump (
      .clk(clk),
      .rst_n(sys_rst_n),
      .start(hd_start),
      .length(wptr),
      .busy(hd_busy),
      .mem_addr(dump_addr),
      .mem_data(buf_rdata),
      .tx_data(hd_tx_data),
      .tx_valid(hd_tx_valid),
      .tx_busy(tx_busy)
  );

  reg        tp_start;
  wire [7:0] tp_tx_data;
  wire       tp_tx_valid;

  buf_text_printer #(
      .ADDR_W(BUF_AW)
  ) u_text (
      .clk(clk),
      .rst_n(sys_rst_n),
      .start(tp_start),
      .length(wptr),
      .busy(tp_busy),
      .mem_addr(text_addr),
      .mem_data(buf_rdata),
      .tx_data(tp_tx_data),
      .tx_valid(tp_tx_valid),
      .tx_busy(tx_busy)
  );

  // the FSM serializes the printers; the pulse selects whose byte is latched
  wire [7:0] tx_data = hd_tx_valid ? hd_tx_data : tp_tx_valid ? tp_tx_data : sp_tx_data;
  wire       tx_valid = hd_tx_valid | tp_tx_valid | sp_tx_valid;
  wire       tx_busy;

  uart_tx #(
      .DELAY_FRAMES(DELAY_FRAMES)
  ) u_tx (
      .clk(clk),
      .rst_n(sys_rst_n),
      .tx_data(tx_data),
      .tx_valid(tx_valid),
      .tx_busy(tx_busy),
      .txd(uart_txp)
  );

  /*******************************************************************************
   ** Menu FSM                                                                  **
   *******************************************************************************/
  // status_printer message codes (must match status_printer.v)
  localparam MSG_BANNER      = 5'd0;
  localparam MSG_FS_UNKNOWN  = 5'd6;
  localparam MSG_FILE_FOUND  = 5'd7;
  localparam MSG_FILE_NOTFND = 5'd8;
  localparam MSG_ERR_CARD_TO = 5'd9;
  localparam MSG_ERR_SCAN_TO = 5'd10;
  localparam MSG_ERR_TRUNC   = 5'd11;
  localparam MSG_MENU        = 5'd12;
  localparam MSG_SD_STATUS0  = 5'd14;  // + sd_status
  localparam MSG_COPYING     = 5'd18;
  localparam MSG_COPY_DONE   = 5'd19;
  localparam MSG_ERR_NOTGT   = 5'd20;
  localparam MSG_ERR_SMALL   = 5'd21;
  localparam MSG_ERR_WRITE   = 5'd22;
  localparam MSG_BLK_WRITING = 5'd23;
  localparam MSG_BLK_DONE    = 5'd24;
  localparam MSG_ERR_RANGE   = 5'd25;
  localparam MSG_HELP1       = 5'd26;  // ..MSG_HELP4 = 29, printed in sequence

  localparam ST_BANNER   = 5'd0;
  localparam ST_MENU     = 5'd1;   // print the SD status line, then
  localparam ST_MENU2    = 5'd15;  // print the menu itself
  localparam ST_KEY      = 5'd2;
  localparam ST_CARD     = 5'd3;
  localparam ST_FS       = 5'd4;
  localparam ST_FILE     = 5'd5;
  localparam ST_STREAM   = 5'd6;
  localparam ST_DUMP     = 5'd7;
  localparam ST_DUMP_W   = 5'd8;
  localparam ST_LSCAN    = 5'd9;
  localparam ST_LPRINT   = 5'd10;
  localparam ST_LPRINT_W = 5'd11;
  localparam ST_CMD_END  = 5'd12;
  localparam ST_PRINT    = 5'd13;  // pulse sp_start, then
  localparam ST_PRINT_W  = 5'd14;  // wait for the message to finish
  localparam ST_C_FIND   = 5'd16;  // COPY: wait for the TEST.TXT scan
  localparam ST_C_WRITE  = 5'd17;  // COPY/WRBLK1: kick one sector write
  localparam ST_C_NEXT   = 5'd18;  // COPY/WRBLK1: wait for the sector to finish
  localparam ST_HELP     = 5'd19;  // print MSG_HELP1..4 in sequence

  // persistent SD status shown in the menu (survives between commands)
  localparam SD_NOTCHK = 2'd0;
  localparam SD_NOCARD = 2'd1;
  localparam SD_ERROR  = 2'd2;
  localparam SD_OK     = 2'd3;

  reg [4:0]  state;
  reg [4:0]  next_after_print;
  reg [1:0]  sd_status;
  reg [31:0] wd;  // watchdog for the waiting states
  reg        err_flag, done_flag;

  assign led = ~{err_flag,               // led[5] error (last command)
                 trunc,                  // led[4] truncated
                 done_flag,              // led[3] last command completed
                 file_found,             // led[2] file found
                 fs_type[1],             // led[1] FS mounted
                 sys_rst_n};             // led[0] alive

  always @(posedge clk) begin
    if (!sys_rst_n) begin
      state            <= ST_BANNER;
      next_after_print <= ST_BANNER;
      cmd_running      <= 1'b0;
      rdrst_cnt        <= 0;
      phase_write      <= 1'b0;
      mode             <= M_DUMP;
      copy_phase       <= 1'b0;
      copy_len         <= 0;
      tgt_sector       <= 0;
      nsec             <= 0;
      seccnt           <= 0;
      wr_start         <= 1'b0;
      sp_start         <= 1'b0;
      sp_msg           <= MSG_BANNER;
      hd_start         <= 1'b0;
      tp_start         <= 1'b0;
      wd               <= 0;
      err_flag         <= 1'b0;
      done_flag        <= 1'b0;
      sd_status        <= SD_NOTCHK;
    end else begin
      sp_start <= 1'b0;
      hd_start <= 1'b0;
      tp_start <= 1'b0;
      wr_start <= 1'b0;
      if (rdrst_cnt != 0) rdrst_cnt <= rdrst_cnt - 5'd1;

      case (state)
        ST_BANNER: begin
          sp_msg           <= MSG_BANNER;
          next_after_print <= ST_MENU;
          state            <= ST_PRINT;
        end

        ST_MENU: begin
          cmd_running      <= 1'b0;
          phase_write      <= 1'b0;
          copy_phase       <= 1'b0;
          sp_msg           <= MSG_SD_STATUS0 + {3'b000, sd_status};
          next_after_print <= ST_MENU2;
          state            <= ST_PRINT;
        end

        ST_MENU2: begin
          sp_msg           <= MSG_MENU;
          next_after_print <= ST_KEY;
          state            <= ST_PRINT;
        end

        ST_KEY:
        if (rx_valid) begin
          err_flag   <= 1'b0;
          done_flag  <= 1'b0;
          wd         <= 0;
          copy_phase <= 1'b0;
          case (rx_data)
            "1": begin
              mode        <= M_LIST;
              cmd_running <= 1'b1;
              state       <= ST_CARD;
            end
            "2": begin
              mode        <= M_DUMP;
              cmd_running <= 1'b1;
              state       <= ST_CARD;
            end
            "3": begin
              mode        <= M_COPY;
              cmd_running <= 1'b1;
              state       <= ST_CARD;
            end
            "4": begin
              mode        <= M_BLK;
              cmd_running <= 1'b1;
              state       <= ST_CARD;
            end
            "H", "h", "?": begin
              sp_msg           <= MSG_HELP1;
              next_after_print <= ST_HELP;
              state            <= ST_PRINT;
            end
            default: state <= ST_MENU;  // anything else: reprint the menu
          endcase
        end

        ST_CARD:
        if (card_ready) begin
          // card_type 1/2/3 maps directly onto MSG_CARD_SDV1/SDV2/SDHC
          sp_msg           <= {3'b000, card_type};
          next_after_print <= ST_FS;
          state            <= ST_PRINT;
        end else if (wd == WD_MAX) begin
          sp_msg           <= MSG_ERR_CARD_TO;
          err_flag         <= 1'b1;
          sd_status        <= SD_NOCARD;
          next_after_print <= ST_MENU;
          state            <= ST_PRINT;
        end else wd <= wd + 1;

        ST_FS:
        if (fs_type[1]) begin
          // fs_type 2/3 maps onto MSG_FS_FAT16/FAT32 (= fs_type + 2)
          sp_msg           <= 5'd2 + {3'b000, fs_type};
          sd_status        <= SD_OK;
          next_after_print <= mode_list ? ST_LSCAN : ST_FILE;
          state            <= ST_PRINT;
        end else if (scan_done) begin
          sp_msg           <= MSG_FS_UNKNOWN;
          err_flag         <= 1'b1;
          sd_status        <= SD_ERROR;
          next_after_print <= ST_MENU;
          state            <= ST_PRINT;
        end else if (wd == WD_MAX) begin
          sp_msg           <= MSG_ERR_SCAN_TO;
          err_flag         <= 1'b1;
          sd_status        <= SD_ERROR;
          next_after_print <= ST_MENU;
          state            <= ST_PRINT;
        end else wd <= wd + 1;

        // ---- DUMP / COPY phase 0: read BOOT.BPUN into the buffer -------
        ST_FILE:
        if (file_found) begin
          sp_msg           <= MSG_FILE_FOUND;
          next_after_print <= ST_STREAM;
          state            <= ST_PRINT;
        end else if (scan_done) begin
          sp_msg           <= MSG_FILE_NOTFND;
          err_flag         <= 1'b1;
          next_after_print <= ST_MENU;
          state            <= ST_PRINT;
        end else if (wd == WD_MAX) begin
          sp_msg           <= MSG_ERR_SCAN_TO;
          err_flag         <= 1'b1;
          sd_status        <= SD_ERROR;
          next_after_print <= ST_MENU;
          state            <= ST_PRINT;
        end else wd <= wd + 1;

        ST_STREAM:
        if (scan_done) begin
          if (trunc) begin
            // DUMP: still dump what fit; COPY: abort (never write a
            // truncated copy)
            sp_msg           <= MSG_ERR_TRUNC;
            err_flag         <= (mode == M_COPY);
            next_after_print <= (mode == M_COPY) ? ST_MENU : ST_DUMP;
            state            <= ST_PRINT;
          end else if (mode == M_COPY) begin
            // phase 1: re-scan for TEST.TXT while announcing the copy
            copy_len         <= wptr;
            copy_phase       <= 1'b1;
            rdrst_cnt        <= 5'd31;
            sp_msg           <= MSG_COPYING;
            next_after_print <= ST_C_FIND;
            state            <= ST_PRINT;
          end else if (mode == M_BLK) begin
            // 1KW block write: the block must lie entirely inside the file
            // (past its end = inside the NEXT file's clusters)
            if (file_size < ({23'b0, BLK_NO} + 32'd1) * 32'd2048) begin
              sp_msg           <= MSG_ERR_RANGE;
              err_flag         <= 1'b1;
              next_after_print <= ST_MENU;
              state            <= ST_PRINT;
            end else begin
              // capture BEFORE phase_write parks the reader (same edge)
              tgt_sector       <= file_first_sector + {25'b0, BLK_NO, 2'b00};
              nsec             <= 9'd4;  // 1 block = 4 SD sectors
              seccnt           <= 0;
              phase_write      <= 1'b1;
              sp_msg           <= MSG_BLK_WRITING;
              next_after_print <= ST_C_WRITE;
              state            <= ST_PRINT;
            end
          end else begin
            state <= ST_DUMP;
          end
        end else if (wd == WD_MAX) begin
          sp_msg           <= MSG_ERR_SCAN_TO;
          err_flag         <= 1'b1;
          sd_status        <= SD_ERROR;
          next_after_print <= ST_MENU;
          state            <= ST_PRINT;
        end else wd <= wd + 1;

        ST_DUMP: begin
          hd_start <= 1'b1;
          state    <= ST_DUMP_W;
        end

        ST_DUMP_W: if (!hd_start && !hd_busy) state <= ST_CMD_END;

        // ---- LIST -------------------------------------------------------
        ST_LSCAN:
        if (scan_done && pk_state == PK_IDLE) begin
          state <= ST_LPRINT;
        end else if (wd == WD_MAX) begin
          sp_msg           <= MSG_ERR_SCAN_TO;
          err_flag         <= 1'b1;
          sd_status        <= SD_ERROR;
          next_after_print <= ST_MENU;
          state            <= ST_PRINT;
        end else wd <= wd + 1;

        ST_LPRINT: begin
          tp_start <= 1'b1;
          state    <= ST_LPRINT_W;
        end

        ST_LPRINT_W: if (!tp_start && !tp_busy) state <= ST_CMD_END;

        // ---- HELP: MSG_HELP1..4 then back to the menu --------------------
        ST_HELP:
        if (sp_msg == MSG_HELP1 + 3) begin
          state <= ST_MENU;
        end else begin
          sp_msg           <= sp_msg + 5'd1;
          next_after_print <= ST_HELP;
          state            <= ST_PRINT;
        end

        // ---- COPY phases 1-2: locate TEST.TXT, rewrite it in place ------
        ST_C_FIND:
        if (scan_done) begin
          if (!file_found) begin
            sp_msg           <= MSG_ERR_NOTGT;
            err_flag         <= 1'b1;
            next_after_print <= ST_MENU;
            state            <= ST_PRINT;
          end else if (file_size < {{(31 - BUF_AW){1'b0}}, copy_len}) begin
            sp_msg           <= MSG_ERR_SMALL;
            err_flag         <= 1'b1;
            next_after_print <= ST_MENU;
            state            <= ST_PRINT;
          end else begin
            // capture BEFORE phase_write parks the reader (same edge)
            tgt_sector  <= file_first_sector;
            nsec        <= (copy_len + 17'd511) >> 9;
            seccnt      <= 0;
            phase_write <= 1'b1;
            wd          <= 0;
            state       <= ST_C_WRITE;
          end
        end else if (wd == WD_MAX) begin
          sp_msg           <= MSG_ERR_SCAN_TO;
          err_flag         <= 1'b1;
          sd_status        <= SD_ERROR;
          next_after_print <= ST_MENU;
          state            <= ST_PRINT;
        end else wd <= wd + 1;

        ST_C_WRITE:
        if (seccnt >= nsec) begin
          phase_write      <= 1'b0;
          sp_msg           <= (mode == M_BLK) ? MSG_BLK_DONE : MSG_COPY_DONE;
          next_after_print <= ST_CMD_END;
          state            <= ST_PRINT;
        end else if (!wr_busy && !wr_start) begin
          wr_start <= 1'b1;
          wd       <= 0;
          state    <= ST_C_NEXT;
        end

        ST_C_NEXT:
        if (wr_done) begin
          seccnt <= seccnt + 9'd1;
          state  <= ST_C_WRITE;
        end else if (wr_err || wd == WD_MAX) begin
          phase_write      <= 1'b0;
          sp_msg           <= MSG_ERR_WRITE;
          err_flag         <= 1'b1;
          sd_status        <= SD_ERROR;
          next_after_print <= ST_MENU;
          state            <= ST_PRINT;
        end else wd <= wd + 1;

        // ---- common tail ------------------------------------------------
        ST_CMD_END: begin
          done_flag <= 1'b1;
          state     <= ST_MENU;
        end

        ST_PRINT: begin
          sp_start <= 1'b1;
          wd       <= 0;
          state    <= ST_PRINT_W;
        end

        ST_PRINT_W: if (!sp_start && !sp_busy) state <= next_after_print;

        default: state <= ST_BANNER;
      endcase
    end
  end

endmodule
