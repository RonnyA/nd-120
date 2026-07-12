/**************************************************************************
** ND-100 FLOPPY DISK CONTROLLER, DMA INTERFACE (3112 / "new controller")**
**                                                                       **
** Register core matching the C reference model                          **
** nd100x src/devices/floppy/deviceFloppyDMA.{h,c} (the controller       **
** registered by default there; SINTRAN detects it via status bit 15).   **
** Semantics reference: docs/nd100x-device-semantics.md.                 **
**                                                                       **
** IOX 1560+0 R  read data (test mode; outside boot mode the C model    **
**               returns the constant 0x0001)                            **
**         +2 R  read status register 1:                                 **
**               b1 intEnabled, b2 deviceActive, b3 readyForTransfer,    **
**               b4 inclusiveOrBits, b5 deletedRecord, b6 retry,         **
**               b7 hardError, b8-14 errorCode, b15 dualDensity = 1      **
**               ALWAYS (tells the driver this is the DMA controller)    **
**         +3 W  control word: b1 enableInterrupt, b2 activateAutoload,  **
**               b3 testMode, b4 deviceClear, b5 enableStreamer,         **
**               b8 executeCommand                                       **
**         +4 R  read status register 2: b0-1 bytesPrSector,             **
**               b2 doubleSided, b3 doubleDensity, b8-9 selected unit    **
**               (latched at command decode; READ FORMAT loads the       **
**               media format from disk_media_fmt)                       **
**         +5 W  load pointer HIGH (command block address bits 16-23)    **
**         +7 W  load pointer LOW  (command block address bits 0-15)     **
**                                                                       **
** Command block, 12 words in ND memory at the pointer (DMA-fetched):    **
**   w0 command word: b0-5 function, b6-7 drive, b8-9 format,            **
**      b10 doubleSided, b11 doubleDensity                               **
**   w1 disk address (logical sector), w2 memAddr high (b23-16),         **
**   w3 memAddr low, w4 options (b15 = word-count select),               **
**   w5 word/sector count, w6 status1 (written back), w7 status2         **
**   (written back), w8/w9 last memory address (written back),           **
**   w10/w11 remaining words (written back)                              **
**                                                                       **
** Functions implemented (enough for boot + basic driver use):           **
**   0x00 READ DATA:  disk -> ND memory by DMA                           **
**   0x01 WRITE DATA: ND memory -> disk by DMA                           **
**   0x22 READ FORMAT: media format (disk_media_fmt) into status 2       **
**   0x38 IDENTIFY / others: no-op completion (status writeback only),   **
**        mirroring the C model's TODO stubs                             **
**                                                                       **
** Completion mirrors the C model's ReadEnd: after the E_WBACK status    **
** writeback (still busy/not-ready, like the C model's first write) and  **
** the completion delay, a FINAL DMA write re-writes CB+6 with the       **
** completed status (READY = 1, BUSY = 0) - a driver waiting on FSTA1    **
** in memory sees the controller go ready.                               **
**   BOOT MODE (control b2, used by '1560&'): the microcode mass boot    **
**        is the BPUN loader pointed at the device - per byte it writes  **
**        the control word (bit 2 = activate), polls status +2 for the   **
**        ready bit, and reads the next boot-stream WORD from +0 (the    **
**        diskette stores one stream byte per 16-bit word, low byte).    **
**        The controller serves the boot stream from its buffer,         **
**        refilling a 512-word chunk from the image whenever the         **
**        pointer crosses a chunk boundary. Reading +0 clears ready;     **
**        the next activate re-arms it. Device clear or a real           **
**        executeCommand leaves boot mode. Verified empirically: the     **
**        'DMA the block to memory 0' interpretation was WRONG (the      **
**        CPU never jumped; the microcode wants to read the stream).     **
**                                                                       **
** All memory traffic goes through the ND_DMA_MASTER client port         **
** (dma_*): the command-block fetch, the sector data both directions,    **
** and the status writeback - one word per bus allocation, exactly like  **
** the real controller.                                                  **
**                                                                       **
** Sector geometry per format (deviceFloppyDMA.c): 0 = 512, 1 = 256,     **
** 2 = 128, 3 = 1024 bytes per sector; 8 sectors per track model.        **
** Disk backend: same style as the PIO core - the backend moves one      **
** sector between the image and the internal buffer.                     **
**                                                                       **
** Ident code 021 (octal), interrupt level 11; interrupt on completion   **
** when enableInterrupt is set; IDENT clears pending + enable.           **
**                                                                       **
** Last reviewed: 12-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module ND_FLOPPY_DMA #(
    parameter [15:0] BASE_ADDR   = 16'o001560,
    parameter [15:0] IDENT_CODE  = 16'o000021,
    parameter [3:0]  INT_LEVEL   = 4'd11,
    parameter [15:0] DELAY_TICKS = 16'd300  // nd100x IODELAY_FLOPPY
) (
    input wire sysclk,
    input wire sys_rst_n,

    // Device bus (from ND_BUS_SLAVE) - IOX slave side
    input  wire [15:0] iox_addr,
    input  wire        iox_wr,
    input  wire [15:0] iox_wdata,
    input  wire        iox_rd,
    output reg  [15:0] iox_rdata,
    output wire [3:0]  int_pending,
    input  wire        ident_strobe,
    input  wire [3:0]  ident_level,
    input  wire        ident_grant_in,
    output wire        ident_grant_out,
    output wire        ident_hit,
    output wire [15:0] ident_code,

    // DMA master client port (to ND_DMA_MASTER) - bus master side
    output reg         dma_req,
    output reg         dma_wr,
    output reg  [23:0] dma_addr,
    output reg  [15:0] dma_wdata,
    input  wire [15:0] dma_rdata,
    input  wire        dma_ack,
    input  wire        dma_err,
    input  wire        dma_busy,

    // Disk image backend (one sector per request, same style as the PIO)
    output reg         disk_req,
    output reg         disk_wr,        // 0 = image -> buffer, 1 = buffer -> image
    output wire [15:0] disk_lsect,     // logical sector (disk address word)
    output wire [1:0]  disk_format,
    output wire [1:0]  disk_drive,
    output wire [10:0] disk_wordcount, // words per sector
    input  wire        disk_done,
    input  wire        disk_err_in,
    // Media format of the mounted image, derived from the image size by
    // the backend exactly like deviceFloppyDMA.c ExecuteFloppyGo/READ
    // FORMAT: {doubleDensity, doubleSided, bytesPerSector[1:0]}.
    // Size 315392 (8-inch) -> 4'b0000; size >= 1261568 (5.25" 1.2MB)
    // -> 4'b1111. Tie to 4'b1111 if unknown.
    input  wire [3:0]  disk_media_fmt,
    input  wire [9:0]  dbuf_addr,
    input  wire [15:0] dbuf_wdata,
    input  wire        dbuf_we,
    output reg  [15:0] dbuf_rdata
);

  // ---- registers ----
  reg        s_int_enabled;   // RSR1 b1
  reg        s_active;        // RSR1 b2
  reg        s_rft;           // RSR1 b3
  reg        s_hard_err;      // RSR1 b7
  reg [6:0]  s_err_code;      // RSR1 b8-14
  reg [7:0]  s_ptr_hi;        // command block address b23-16
  reg [15:0] s_ptr_lo;        // command block address b15-0
  reg        s_test_mode;

  wire [15:0] s_rsr1 = {1'b1,            // b15 dualDensity: ALWAYS 1
                        s_err_code,      // b14-8
                        s_hard_err,      // b7
                        1'b0,            // b6 retry
                        1'b0,            // b5 deleted
                        (s_err_code != 7'd0) | s_hard_err, // b4 OR bits
                        s_rft,           // b3
                        s_active,        // b2
                        s_int_enabled,   // b1
                        1'b0};           // b0

  // command block fields (fetched by DMA)
  reg [15:0] s_cb[0:5];       // w0-w5 (w6-w11 are write-back only)
  wire [5:0] s_func     = s_cb[0][5:0];
  wire [1:0] s_cb_drive = s_cb[0][7:6];
  wire [1:0] s_cb_fmt   = s_cb[0][9:8];
  wire [15:0] s_disk_addr = s_cb[1];
  wire [23:0] s_mem_addr0 = {s_cb[2][7:0], s_cb[3]};
  wire [15:0] s_count     = s_cb[5];

  // STATUS 2 (format word): a real latched register, NOT an echo of the
  // command-word format bits. Loaded at command decode with the selected
  // unit in bits 8-9 (deviceFloppyDMA.c line 371); READ FORMAT (0x22)
  // additionally loads the media format bits 0-3 from disk_media_fmt
  // (deviceFloppyDMA.c lines 528-540).
  reg [15:0] s_status2;

  // geometry: bytes per sector by format -> words per sector
  wire [10:0] s_words_per_sector = (s_cb_fmt == 2'd0) ? 11'd256 :
                                   (s_cb_fmt == 2'd1) ? 11'd128 :
                                   (s_cb_fmt == 2'd2) ? 11'd64  : 11'd512;

  // ---- internal sector buffer (BRAM) ----
  reg [15:0] s_buffer[0:1023];
  always @(*) dbuf_rdata = s_buffer[dbuf_addr];

  // ---- address decode ----
  wire s_addressed = (iox_addr[15:3] == BASE_ADDR[15:3]);
  wire [2:0] s_reg = iox_addr[2:0];
  wire s_wr_here = iox_wr && s_addressed;

  // ---- interrupt / ident (standard pattern) ----
  wire s_pending = s_int_enabled && s_rft;
  assign int_pending = {(INT_LEVEL == 4'd13) && s_pending,
                        (INT_LEVEL == 4'd12) && s_pending,
                        (INT_LEVEL == 4'd11) && s_pending,
                        (INT_LEVEL == 4'd10) && s_pending};
  wire s_ident_answer = ident_strobe && ident_grant_in &&
                        (ident_level == INT_LEVEL) && s_pending;
  assign ident_hit       = s_ident_answer;
  assign ident_code      = s_ident_answer ? IDENT_CODE : 16'd0;
  assign ident_grant_out = ident_grant_in && !s_ident_answer;

  // ---- IOX read mux ----
  always @(*) begin
    iox_rdata = 16'd0;
    if (iox_rd && s_addressed) begin
      case (s_reg)
        // +0 outside boot mode: the C model returns the constant 0x0001
        3'd0: iox_rdata = s_boot_active ? s_buffer[s_bootptr] : 16'd1;
        3'd2: iox_rdata = s_rsr1;
        3'd4: iox_rdata = s_status2;
        default: iox_rdata = 16'd0;
      endcase
    end
  end

  // ---- command engine ----
  localparam E_IDLE     = 4'd0;
  localparam E_CB_FETCH = 4'd1;   // DMA-read command block words 0-5
  localparam E_DISK_RD  = 4'd2;   // backend: image sector -> buffer
  localparam E_MEM_WR   = 4'd3;   // DMA-write buffer -> ND memory
  localparam E_MEM_RD   = 4'd4;   // DMA-read ND memory -> buffer
  localparam E_DISK_WR  = 4'd5;   // backend: buffer -> image sector
  localparam E_WBACK    = 4'd6;   // DMA-write status words 6-11
  localparam E_DELAY    = 4'd7;   // completion delay -> interrupt
  localparam E_FINAL    = 4'd8;   // re-write CB+6 with completed status
                                  // (READY=1, BUSY=0) - C model ReadEnd

  reg [3:0]  s_eng;
  reg [2:0]  s_cb_idx;      // command-block word index during fetch
  reg [15:0] s_words_left;  // total transfer words remaining
  reg [10:0] s_sec_idx;     // word index within the current sector
  reg [15:0] s_lsect;       // current logical sector
  reg [23:0] s_mem_ptr;     // current ND memory address
  reg [2:0]  s_wb_idx;      // writeback word index (0-5 -> w6-w11)
  reg [15:0] s_delay_cnt;
  reg        s_dma_wait;    // a dma_req is outstanding
  reg        s_autoload;    // a boot-chunk fetch is in flight
  reg        s_boot_active; // boot byte-server engaged
  reg [9:0]  s_bootptr;     // word index into the current boot chunk
  reg        s_final_wb;    // command block present: E_DELAY -> E_FINAL

  assign disk_lsect     = s_lsect;
  assign disk_format    = s_cb_fmt;
  assign disk_drive     = s_cb_drive;
  assign disk_wordcount = s_words_per_sector;

  // words in the CURRENT sector transfer - latched at sector start
  // (computing it from the live word counter would shrink it mid-sector)
  reg [10:0] s_chunk_q;

  // one-clock req pulse toward the DMA master; response by dma_ack
  task automatic dma_issue(input wr, input [23:0] a, input [15:0] d);
    begin
      dma_req    <= 1'b1;
      dma_wr     <= wr;
      dma_addr   <= a;
      dma_wdata  <= d;
      s_dma_wait <= 1'b1;
    end
  endtask

  always @(posedge sysclk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
      s_int_enabled <= 1'b0;
      s_active      <= 1'b0;
      s_rft         <= 1'b1;
      s_hard_err    <= 1'b0;
      s_err_code    <= 7'd0;
      s_ptr_hi      <= 8'd0;
      s_ptr_lo      <= 16'd0;
      s_test_mode   <= 1'b0;
      s_eng         <= E_IDLE;
      s_cb_idx      <= 3'd0;
      s_words_left  <= 16'd0;
      s_sec_idx     <= 11'd0;
      s_lsect       <= 16'd0;
      s_mem_ptr     <= 24'd0;
      s_wb_idx      <= 3'd0;
      s_delay_cnt   <= 16'd0;
      s_chunk_q     <= 11'd0;
      s_dma_wait    <= 1'b0;
      s_autoload    <= 1'b0;
      s_boot_active <= 1'b0;
      s_bootptr     <= 10'd0;
      s_final_wb    <= 1'b0;
      s_status2     <= 16'd0;
      dma_req       <= 1'b0;
      dma_wr        <= 1'b0;
      dma_addr      <= 24'd0;
      dma_wdata     <= 16'd0;
      disk_req      <= 1'b0;
      disk_wr       <= 1'b0;
    end else begin
      dma_req  <= 1'b0;
      disk_req <= 1'b0;

      // backend writes into the sector buffer (disk read fill)
      if (dbuf_we) s_buffer[dbuf_addr] <= dbuf_wdata;

      // boot stream readout: +0 read consumes the word, clears ready
      if (s_boot_active && iox_rd && s_addressed && (s_reg == 3'd0)) begin
        s_bootptr <= s_bootptr + 10'd1;
        s_rft     <= 1'b0;
      end

      // ---- IOX register writes ----
      if (s_wr_here) begin
        case (s_reg)
          3'd3: begin  // control word
            s_int_enabled <= iox_wdata[1];
            s_test_mode   <= iox_wdata[3];
            if (iox_wdata[4]) begin  // device clear
              s_rft         <= 1'b1;
              s_active      <= 1'b0;
              s_hard_err    <= 1'b0;
              s_err_code    <= 7'd0;
              s_boot_active <= 1'b0;
              s_eng         <= E_IDLE;
              s_dma_wait    <= 1'b0;
            end
            // autoload has PRIORITY over execute when both bits are set
            // (C model if/else order in FloppyDMA_Write)
            if (iox_wdata[2] && s_eng == E_IDLE) begin
              // BOOT MODE activate: arm the next boot-stream word
              if (!s_boot_active) begin
                // first activate: fetch chunk 0 into the buffer
                s_boot_active <= 1'b1;
                s_bootptr     <= 10'd0;
                s_active      <= 1'b1;
                s_rft         <= 1'b0;
                s_hard_err    <= 1'b0;
                s_err_code    <= 7'd0;
                s_autoload    <= 1'b1;
                s_cb[0]       <= 16'h0300;  // format 3 (1024 B/sector)
                s_lsect       <= 16'd0;
                s_chunk_q     <= 11'd512;
                disk_req      <= 1'b1;
                disk_wr       <= 1'b0;
                s_eng         <= E_DISK_RD;
              end else if (s_bootptr == 10'd512) begin
                // chunk exhausted: fetch the next one (re-assert the
                // boot geometry - a normal command may have changed
                // the format field in between)
                s_bootptr  <= 10'd0;
                s_active   <= 1'b1;
                s_rft      <= 1'b0;
                s_autoload <= 1'b1;
                s_cb[0]    <= 16'h0300;
                s_lsect    <= s_lsect + 16'd1;
                s_chunk_q  <= 11'd512;
                disk_req   <= 1'b1;
                disk_wr    <= 1'b0;
                s_eng      <= E_DISK_RD;
              end else begin
                s_rft <= 1'b1;  // next word already buffered
              end
            end else if (iox_wdata[8] && s_eng == E_IDLE) begin  // execute
              s_boot_active <= 1'b0;
              s_active   <= 1'b1;
              s_rft      <= 1'b0;
              s_hard_err <= 1'b0;
              s_err_code <= 7'd0;
              s_autoload <= 1'b0;
              s_cb_idx   <= 3'd0;
              s_eng      <= E_CB_FETCH;
            end
          end
          3'd5: s_ptr_hi <= iox_wdata[7:0];
          3'd7: s_ptr_lo <= iox_wdata;
          default: ;
        endcase
      end

      // ---- engine ----
      case (s_eng)
        E_IDLE: ;

        // fetch command block words 0-5 by DMA
        E_CB_FETCH: begin
          if (!s_dma_wait && !dma_busy && s_cb_idx < 3'd6) begin
            dma_issue(1'b0, {s_ptr_hi, s_ptr_lo} + {21'd0, s_cb_idx}, 16'd0);
          end else if (s_dma_wait && dma_ack) begin
            s_dma_wait <= 1'b0;
            if (dma_err) begin
              s_hard_err <= 1'b1;
              s_err_code <= 7'd1;
              s_eng      <= E_WBACK;
              s_wb_idx   <= 3'd0;
            end else begin
              s_cb[s_cb_idx[2:0]] <= dma_rdata;
              s_cb_idx <= s_cb_idx + 3'd1;  // idx 6 = decode cycle below
            end
          end
          // decode once the last word has landed (registered s_cb ready
          // the cycle after the final ack)
          if (s_cb_idx == 3'd6) begin
            s_lsect      <= s_disk_addr;
            s_mem_ptr    <= s_mem_addr0;
            s_words_left <= s_count;
            // status 2: selected unit in bits 8-9 (C model command setup);
            // READ FORMAT loads the media format bits on top - the 8-inch
            // format (all-zero descriptor) is a plain assignment in the C
            // model, so the unit bits are cleared for that case too
            if (s_func == 6'h22)
              s_status2 <= (disk_media_fmt == 4'b0000) ? 16'd0 :
                           ({6'd0, s_cb_drive, 8'd0} | {12'd0, disk_media_fmt});
            else
              s_status2 <= {6'd0, s_cb_drive, 8'd0};
            s_chunk_q    <= (s_count > {5'd0, s_words_per_sector}) ?
                            s_words_per_sector : s_count[10:0];
            s_sec_idx    <= 11'd0;
            if (s_func == 6'h00 && s_count != 16'd0) begin
              disk_req <= 1'b1;
              disk_wr  <= 1'b0;
              s_eng    <= E_DISK_RD;
            end else if (s_func == 6'h01 && s_count != 16'd0) begin
              s_eng <= E_MEM_RD;
            end else begin
              // IDENTIFY and the other functions: complete with clean
              // status (the C model's stubs do the same)
              s_eng    <= E_WBACK;
              s_wb_idx <= 3'd0;
            end
          end
        end

        // wait for the backend to fill the buffer with one sector
        E_DISK_RD: begin
          if (disk_done) begin
            if (disk_err_in) begin
              s_hard_err <= 1'b1;
              s_err_code <= 7'd2;
              if (s_autoload) begin
                s_autoload  <= 1'b0;
                s_delay_cnt <= DELAY_TICKS;
                s_final_wb  <= 1'b0;  // boot path: no command block
                s_eng       <= E_DELAY;
              end else begin
                s_eng    <= E_WBACK;
                s_wb_idx <= 3'd0;
              end
            end else if (s_autoload) begin
              // boot chunk buffered: serve it via +0 reads
              s_autoload <= 1'b0;
              s_active   <= 1'b0;
              s_rft      <= 1'b1;
              s_eng      <= E_IDLE;
            end else begin
              s_sec_idx <= 11'd0;
              s_eng     <= E_MEM_WR;
            end
          end
        end

        // DMA-write the buffered sector words to ND memory
        E_MEM_WR: begin
          if (!s_dma_wait && !dma_busy) begin
            dma_issue(1'b1, s_mem_ptr, s_buffer[s_sec_idx[9:0]]);
          end else if (s_dma_wait && dma_ack) begin
            s_dma_wait   <= 1'b0;
            s_mem_ptr    <= s_mem_ptr + 24'd1;
            s_words_left <= s_words_left - 16'd1;
            if (s_sec_idx + 11'd1 >= s_chunk_q || s_words_left == 16'd1) begin
              if (s_words_left == 16'd1) begin
                if (s_autoload) begin
                  s_delay_cnt <= DELAY_TICKS;
                  s_final_wb  <= 1'b0;  // boot path: no command block
                  s_eng       <= E_DELAY;
                end else begin
                  s_eng    <= E_WBACK;
                  s_wb_idx <= 3'd0;
                end
              end else begin
                s_lsect   <= s_lsect + 16'd1;
                s_chunk_q <= ((s_words_left - 16'd1) > {5'd0, s_words_per_sector}) ?
                             s_words_per_sector : s_words_left[10:0] - 11'd1;
                disk_req  <= 1'b1;
                disk_wr   <= 1'b0;
                s_eng     <= E_DISK_RD;
              end
            end else begin
              s_sec_idx <= s_sec_idx + 11'd1;
            end
          end
        end

        // DMA-read ND memory words into the buffer (write function)
        E_MEM_RD: begin
          if (!s_dma_wait && !dma_busy) begin
            dma_issue(1'b0, s_mem_ptr, 16'd0);
          end else if (s_dma_wait && dma_ack) begin
            s_dma_wait <= 1'b0;
            s_buffer[s_sec_idx[9:0]] <= dma_rdata;
            s_mem_ptr    <= s_mem_ptr + 24'd1;
            s_words_left <= s_words_left - 16'd1;
            if (s_sec_idx + 11'd1 >= s_chunk_q || s_words_left == 16'd1) begin
              disk_req <= 1'b1;
              disk_wr  <= 1'b1;
              s_eng    <= E_DISK_WR;
            end else begin
              s_sec_idx <= s_sec_idx + 11'd1;
            end
          end
        end

        // wait for the backend to write the buffer to the image
        E_DISK_WR: begin
          if (disk_done) begin
            if (disk_err_in) begin
              s_hard_err <= 1'b1;
              s_err_code <= 7'd2;
              s_eng      <= E_WBACK;
              s_wb_idx   <= 3'd0;
            end else if (s_words_left == 16'd0) begin
              s_eng    <= E_WBACK;
              s_wb_idx <= 3'd0;
            end else begin
              s_lsect   <= s_lsect + 16'd1;
              s_sec_idx <= 11'd0;
              s_chunk_q <= (s_words_left > {5'd0, s_words_per_sector}) ?
                           s_words_per_sector : s_words_left[10:0];
              s_eng     <= E_MEM_RD;
            end
          end
        end

        // DMA-write status words w6-w11 back into the command block
        E_WBACK: begin
          if (!s_dma_wait && !dma_busy) begin
            case (s_wb_idx)
              3'd0: dma_issue(1'b1, {s_ptr_hi, s_ptr_lo} + 24'd6, s_rsr1);
              3'd1: dma_issue(1'b1, {s_ptr_hi, s_ptr_lo} + 24'd7, s_status2);
              3'd2: dma_issue(1'b1, {s_ptr_hi, s_ptr_lo} + 24'd8,
                              {8'd0, s_mem_ptr[23:16]});
              3'd3: dma_issue(1'b1, {s_ptr_hi, s_ptr_lo} + 24'd9,
                              s_mem_ptr[15:0]);
              3'd4: dma_issue(1'b1, {s_ptr_hi, s_ptr_lo} + 24'd10, 16'd0);
              default: dma_issue(1'b1, {s_ptr_hi, s_ptr_lo} + 24'd11,
                                 s_words_left);
            endcase
          end else if (s_dma_wait && dma_ack) begin
            s_dma_wait <= 1'b0;
            if (s_wb_idx == 3'd5) begin
              s_delay_cnt <= DELAY_TICKS;
              s_final_wb  <= 1'b1;  // re-write CB+6 after the delay
              s_eng       <= E_DELAY;
            end
            s_wb_idx <= s_wb_idx + 3'd1;
          end
        end

        // completion delay, then ready + interrupt condition; a normal
        // command (s_final_wb) goes on to re-write CB+6 with the
        // completed status, like the C model's ReadEnd
        E_DELAY: begin
          if (s_delay_cnt != 16'd0) s_delay_cnt <= s_delay_cnt - 16'd1;
          else begin
            s_active <= 1'b0;
            s_rft    <= 1'b1;
            s_eng    <= s_final_wb ? E_FINAL : E_IDLE;
          end
        end

        // final status re-write (C model ReadEnd): one DMA write of
        // CB+6 with s_rsr1 now evaluating READY=1, BUSY=0, bit15=1
        E_FINAL: begin
          if (!s_dma_wait && !dma_busy) begin
            dma_issue(1'b1, {s_ptr_hi, s_ptr_lo} + 24'd6, s_rsr1);
          end else if (s_dma_wait && dma_ack) begin
            s_dma_wait <= 1'b0;
            s_final_wb <= 1'b0;
            s_eng      <= E_IDLE;
          end
        end

        default: s_eng <= E_IDLE;
      endcase

      // IDENT answered: clear the enable bit (standard rule)
      if (s_ident_answer) begin
        s_int_enabled <= 1'b0;
      end
    end
  end

endmodule
