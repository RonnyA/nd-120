/**************************************************************************
** ND-100 SMD DISK CONTROLLER (10 MHz SMD interface, DMA)                **
**                                                                       **
** Register core matching the C reference model                          **
** nd100x src/devices/smd/deviceSMD.{h,c}; semantics summary in          **
** docs/nd100x-device-semantics.md. Unlike the floppy DMA controller     **
** there is no command block in memory: the controller holds its own     **
** registers and the driver loads them by IOX, then issues GO via the    **
** control word. All data traffic runs through ND_DMA_MASTER, one word   **
** per bus allocation.                                                   **
**                                                                       **
** Register map (offset from base 1540, multiplexed by control bit 15,   **
** the "register multiplex bit", mirrored in status bit 15):             **
**   +0 R  core address (CWR=0) / word counter (CWR=1)                   **
**   +1 W  load core address (CWR=0) / count memory address (CWR=1)      **
**   +2 R  seek condition (CWR=0) / ECC count (CWR=1, reads 0)           **
**   +3 W  load block address I (CWR=0) / block address II (CWR=1)       **
**   +4 R  status (CWR=0) / ECC pattern (CWR=1, reads 0)                 **
**   +5 W  load control word                                             **
**   +6 R  block address I (CWR=0) / block address II (CWR=1)            **
**   +7 W  load word count (CWR=0) / ECC control (CWR=1, ignored)        **
**                                                                       **
** Control word: b0 enable interrupt (on not active), b1 enable error    **
** interrupt, b2 ACTIVE (GO), b3 test mode, b4 device clear, b5-6 core   **
** address bits 16-17, b7-9 unit select, b10 marginal recovery,          **
** b11-14 device operation, b15 register multiplex bit.                  **
**                                                                       **
** Status: b0 intEnabled, b1 errIntEnabled, b2 active, b3 ready for      **
** transfer, b4 hardware error (OR), b5 illegal load, b6 timeout,        **
** b7 hw error 2, b8 address mismatch, b10 compare error, b13 unit not   **
** ready, b14 on cylinder, b15 register multiplex bit.                   **
**                                                                       **
** BOOT MODE ('1540&'): the microcode mass-storage loader is device-    **
** agnostic - it writes a control word to base+3 and polls base+2 for   **
** the ready bit (the classic controller layout). On the SMD's native   **
** map those are Load Block Address and Read Seek Condition, so a       **
** bootable controller must answer the boot handshake: from reset (or   **
** device clear) until the FIRST Load Control Word, the '&' loader IS   **
** the BPUN loader pointed at the device - per byte it writes +3 with   **
** bit 2 (activate), polls +2 for ready, and reads the next boot-      **
** stream WORD from +0 (the disk stores one stream byte per 16-bit     **
** word). The controller byte-serves its buffer, refilling 1024-word   **
** chunks from the image; +2 returns {error<<4, ready<<3}. The first   **
** real control-word write leaves boot mode and the registers take     **
** their native SMD meaning.                                            **
**                                                                       **
** Operations: M0 read transfer (disk -> memory), M1 write transfer      **
** (memory -> disk), M4 initiate seek (on-cylinder after delay),         **
** M6 seek complete search, M7 return to zero, M9 select release;        **
** M2/M3/M5/M8 complete as clean stubs (the C model treats most of       **
** them as simple completions too).                                      **
**                                                                       **
** The disk backend receives the raw block address registers and the    **
** unit at transfer start and serves word chunks through the internal    **
** 1K-word buffer - the backend owns the CHS-to-image mapping (the       **
** geometry lives with the image, as in nd100x's callbacks).             **
**                                                                       **
** Ident code 017 (octal), interrupt level 11.                           **
**                                                                       **
** Last reviewed: 11-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module ND_SMD #(
    parameter [15:0] BASE_ADDR   = 16'o001540,
    parameter [15:0] IDENT_CODE  = 16'o000017,
    parameter [3:0]  INT_LEVEL   = 4'd11,
    parameter [15:0] DELAY_TICKS = 16'd10  // nd100x IODELAY_HDD_SMD
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

    // DMA master client port (to ND_DMA_MASTER)
    output reg         dma_req,
    output reg         dma_wr,
    output reg  [23:0] dma_addr,
    output reg  [15:0] dma_wdata,
    input  wire [15:0] dma_rdata,
    input  wire        dma_ack,
    input  wire        dma_err,
    input  wire        dma_busy,

    // Disk backend: chunk transfers through the internal buffer.
    // disk_start pulses once per GO with the address registers valid;
    // per chunk, disk_req moves disk_wordcount words image<->buffer
    // and the backend advances its own position.
    output reg         disk_start,
    output reg         disk_req,
    output reg         disk_wr,
    output wire [15:0] disk_blkaddr1,  // block address I (head/sector)
    output wire [15:0] disk_blkaddr2,  // block address II (cylinder)
    output wire [2:0]  disk_unit,
    output wire [10:0] disk_wordcount, // words in the current chunk
    input  wire        disk_done,
    input  wire        disk_err_in,
    input  wire [9:0]  dbuf_addr,
    input  wire [15:0] dbuf_wdata,
    input  wire        dbuf_we,
    output reg  [15:0] dbuf_rdata
);

  localparam BUF_WORDS = 11'd1024;

  // ---- controller registers ----
  reg [15:0] s_core_addr;     // ND memory address, low 16
  reg [1:0]  s_core_hi;       // bits 17:16 (control b5-6)
  reg [15:0] s_word_cnt;      // words remaining (loaded by driver)
  reg [15:0] s_blkaddr1;      // block address I
  reg [15:0] s_blkaddr2;      // block address II (cylinder)
  reg [2:0]  s_unit;
  reg        s_cwr;           // register multiplex bit (control b15)
  reg        s_int_en;        // control b0
  reg        s_errint_en;     // control b1
  reg        s_active;        // status b2
  reg        s_rft;           // status b3
  reg        s_illegal;       // status b5
  reg        s_hw_err;        // status b7
  reg        s_on_cyl;        // status b14
  reg [3:0]  s_op;
  reg        s_boot_mode;    // reset..first control word: boot handshake
  reg        s_boot_fetch;   // a boot-chunk fetch is in flight
  reg        s_boot_loaded;  // a chunk is in the buffer
  reg [10:0] s_bootptr;      // word index into the current boot chunk

  wire s_any_err = s_illegal | s_hw_err;
  wire [15:0] s_status = {s_cwr, s_on_cyl, 1'b0, 3'd0, 1'b0, 1'b0,
                          s_hw_err, 1'b0, s_illegal, s_any_err,
                          s_rft, s_active, s_errint_en, s_int_en};

  assign disk_blkaddr1 = s_blkaddr1;
  assign disk_blkaddr2 = s_blkaddr2;
  assign disk_unit     = s_unit;

  // ---- internal buffer ----
  reg [15:0] s_buffer[0:1023];
  always @(*) dbuf_rdata = s_buffer[dbuf_addr];

  // ---- decode ----
  wire s_addressed = (iox_addr[15:3] == BASE_ADDR[15:3]);
  wire [2:0] s_reg = iox_addr[2:0];
  wire s_wr_here = iox_wr && s_addressed;

  // ---- interrupt / ident ----
  wire s_pending = s_int_en && s_rft;
  assign int_pending = {(INT_LEVEL == 4'd13) && s_pending,
                        (INT_LEVEL == 4'd12) && s_pending,
                        (INT_LEVEL == 4'd11) && s_pending,
                        (INT_LEVEL == 4'd10) && s_pending};
  wire s_ident_answer = ident_strobe && ident_grant_in &&
                        (ident_level == INT_LEVEL) && s_pending;
  assign ident_hit       = s_ident_answer;
  assign ident_code      = s_ident_answer ? IDENT_CODE : 16'd0;
  assign ident_grant_out = ident_grant_in && !s_ident_answer;

  // ---- IOX read mux (CWR-multiplexed) ----
  always @(*) begin
    iox_rdata = 16'd0;
    if (iox_rd && s_addressed) begin
      case (s_reg)
        3'd0: iox_rdata = s_boot_mode ? s_buffer[s_bootptr[9:0]]
                          : (s_cwr ? s_word_cnt : s_core_addr);
        3'd2: iox_rdata = s_boot_mode
                          ? {11'd0, s_any_err | s_hw_err, s_rft, 3'd0}
                          : (s_cwr ? 16'd0    // ECC count
                                   : {1'b0, s_on_cyl, 14'd0});  // seek cond
        3'd4: iox_rdata = s_cwr ? 16'd0 : s_status;  // ECC pattern / status
        3'd6: iox_rdata = s_cwr ? s_blkaddr2 : s_blkaddr1;
        default: iox_rdata = 16'd0;
      endcase
    end
  end

  // ---- transfer engine ----
  localparam E_IDLE    = 3'd0;
  localparam E_DISK_RD = 3'd1;  // backend: image chunk -> buffer
  localparam E_MEM_WR  = 3'd2;  // DMA: buffer -> ND memory
  localparam E_MEM_RD  = 3'd3;  // DMA: ND memory -> buffer
  localparam E_DISK_WR = 3'd4;  // backend: buffer -> image chunk
  localparam E_DELAY   = 3'd5;  // completion delay

  reg [2:0]  s_eng;
  reg [10:0] s_chunk_q;
  reg [10:0] s_sec_idx;
  reg [15:0] s_delay_cnt;
  reg        s_dma_wait;

  assign disk_wordcount = s_chunk_q;

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
      s_core_addr <= 16'd0;
      s_core_hi   <= 2'd0;
      s_word_cnt  <= 16'd0;
      s_blkaddr1  <= 16'd0;
      s_blkaddr2  <= 16'd0;
      s_unit      <= 3'd0;
      s_cwr       <= 1'b0;
      s_int_en    <= 1'b0;
      s_errint_en <= 1'b0;
      s_active    <= 1'b0;
      s_rft       <= 1'b1;
      s_illegal   <= 1'b0;
      s_hw_err    <= 1'b0;
      s_on_cyl    <= 1'b0;
      s_op        <= 4'd0;
      s_boot_mode <= 1'b1;
      s_boot_fetch<= 1'b0;
      s_boot_loaded <= 1'b0;
      s_bootptr   <= 11'd0;
      s_eng       <= E_IDLE;
      s_chunk_q   <= 11'd0;
      s_sec_idx   <= 11'd0;
      s_delay_cnt <= 16'd0;
      s_dma_wait  <= 1'b0;
      dma_req     <= 1'b0;
      dma_wr      <= 1'b0;
      dma_addr    <= 24'd0;
      dma_wdata   <= 16'd0;
      disk_start  <= 1'b0;
      disk_req    <= 1'b0;
      disk_wr     <= 1'b0;
    end else begin
      dma_req    <= 1'b0;
      disk_start <= 1'b0;
      disk_req   <= 1'b0;

      if (dbuf_we) s_buffer[dbuf_addr] <= dbuf_wdata;

      // boot stream readout: +0 read consumes the word, clears ready
      if (s_boot_mode && iox_rd && s_addressed && (s_reg == 3'd0)) begin
        s_bootptr <= s_bootptr + 11'd1;
        s_rft     <= 1'b0;
      end

      // ---- IOX register writes ----
      if (s_wr_here) begin
        case (s_reg)
          3'd1: begin
            if (s_cwr) s_core_addr <= s_core_addr + 16'd1;  // count mem addr
            else       s_core_addr <= iox_wdata;            // load core addr
          end
          3'd3: begin
            if (s_boot_mode && iox_wdata[2] && s_eng == E_IDLE) begin
              // BOOT byte-server: arm the next boot-stream word
              if (!s_boot_loaded && !s_boot_fetch) begin
                // first activate: fetch chunk 0 (position from the
                // zeroed block address registers)
                s_active   <= 1'b1;
                s_hw_err   <= 1'b0;
                s_illegal  <= 1'b0;
                s_boot_fetch <= 1'b1;
                s_blkaddr1 <= 16'd0;
                s_blkaddr2 <= 16'd0;
                s_chunk_q  <= 11'd1024;
                disk_start <= 1'b1;
                disk_req   <= 1'b1;
                disk_wr    <= 1'b0;
                s_eng      <= E_DISK_RD;
              end else if (s_bootptr == 11'd1024) begin
                // chunk exhausted: refill (backend position advances
                // linearly on its own)
                s_bootptr  <= 11'd0;
                s_active   <= 1'b1;
                s_rft      <= 1'b0;
                s_boot_fetch <= 1'b1;
                s_chunk_q  <= 11'd1024;
                disk_req   <= 1'b1;
                disk_wr    <= 1'b0;
                s_eng      <= E_DISK_RD;
              end else begin
                s_rft <= 1'b1;  // next word already buffered
              end
            end else if (s_cwr) s_blkaddr2 <= iox_wdata;
            else                s_blkaddr1 <= iox_wdata;
          end
          3'd5: begin  // control word (leaves boot mode)
            s_boot_mode <= 1'b0;
            s_int_en    <= iox_wdata[0];
            s_errint_en <= iox_wdata[1];
            s_core_hi   <= iox_wdata[6:5];
            s_unit      <= iox_wdata[9:7];
            s_cwr       <= iox_wdata[15];
            if (iox_wdata[4]) begin  // device clear
              s_active  <= 1'b0;
              s_rft     <= 1'b1;
              s_illegal <= 1'b0;
              s_hw_err  <= 1'b0;
              s_eng     <= E_IDLE;
              s_dma_wait<= 1'b0;
            end
            if (iox_wdata[2] && s_eng == E_IDLE) begin  // ACTIVE: GO
              s_op     <= iox_wdata[14:11];
              s_active <= 1'b1;
              s_rft    <= 1'b0;
              s_hw_err <= 1'b0;
              s_illegal<= 1'b0;
              case (iox_wdata[14:11])
                4'd0: begin  // M0 read transfer
                  disk_start <= 1'b1;
                  disk_req   <= 1'b1;
                  disk_wr    <= 1'b0;
                  s_chunk_q  <= (s_word_cnt > {5'd0, BUF_WORDS}) ?
                                BUF_WORDS : s_word_cnt[10:0];
                  s_sec_idx  <= 11'd0;
                  s_eng      <= E_DISK_RD;
                end
                4'd1: begin  // M1 write transfer
                  disk_start <= 1'b1;
                  s_chunk_q  <= (s_word_cnt > {5'd0, BUF_WORDS}) ?
                                BUF_WORDS : s_word_cnt[10:0];
                  s_sec_idx  <= 11'd0;
                  s_eng      <= E_MEM_RD;
                end
                4'd4: begin  // M4 initiate seek
                  s_on_cyl    <= 1'b1;  // after the delay
                  s_delay_cnt <= DELAY_TICKS;
                  s_eng       <= E_DELAY;
                end
                4'd7: begin  // M7 return to zero
                  s_blkaddr1  <= 16'd0;
                  s_blkaddr2  <= 16'd0;
                  s_on_cyl    <= 1'b1;
                  s_delay_cnt <= DELAY_TICKS;
                  s_eng       <= E_DELAY;
                end
                default: begin  // M2/M3/M5/M6/M8/M9: stub completion
                  s_delay_cnt <= DELAY_TICKS;
                  s_eng       <= E_DELAY;
                end
              endcase
            end
          end
          3'd7: begin
            if (!s_cwr) s_word_cnt <= iox_wdata;  // load word count
            // CWR=1: ECC control - ignored
          end
          default: ;
        endcase
      end

      // ---- engine ----
      case (s_eng)
        E_IDLE: ;

        E_DISK_RD: begin
          if (disk_done) begin
            if (disk_err_in) begin
              s_hw_err     <= 1'b1;
              s_boot_fetch <= 1'b0;
              s_delay_cnt  <= DELAY_TICKS;
              s_eng        <= E_DELAY;
            end else if (s_boot_fetch) begin
              // boot chunk buffered: serve it via +0 reads
              s_boot_fetch  <= 1'b0;
              s_boot_loaded <= 1'b1;
              s_active      <= 1'b0;
              s_rft         <= 1'b1;
              s_eng         <= E_IDLE;
            end else begin
              s_sec_idx <= 11'd0;
              s_eng     <= E_MEM_WR;
            end
          end
        end

        E_MEM_WR: begin
          if (!s_dma_wait && !dma_busy) begin
            dma_issue(1'b1, {6'd0, s_core_hi, s_core_addr},
                      s_buffer[s_sec_idx[9:0]]);
          end else if (s_dma_wait && dma_ack) begin
            s_dma_wait  <= 1'b0;
            if (dma_err) begin
              // bus/memory fault during the DMA cycle (timeout / no memory
              // contact) - abort as a hard error, like disk_err_in above.
              // Mirrors ND_FLOPPY_DMA's dma_err handling; without this the
              // transfer would "complete" with garbage (SMD review C3).
              s_hw_err    <= 1'b1;
              s_delay_cnt <= DELAY_TICKS;
              s_eng       <= E_DELAY;
            end else begin
              s_core_addr <= s_core_addr + 16'd1;
              s_word_cnt  <= s_word_cnt - 16'd1;
              if (s_sec_idx + 11'd1 >= s_chunk_q || s_word_cnt == 16'd1) begin
                if (s_word_cnt == 16'd1) begin
                  s_delay_cnt <= DELAY_TICKS;
                  s_eng       <= E_DELAY;
                end else begin
                  s_chunk_q <= ((s_word_cnt - 16'd1) > {5'd0, BUF_WORDS}) ?
                               BUF_WORDS : s_word_cnt[10:0] - 11'd1;
                  disk_req  <= 1'b1;
                  disk_wr   <= 1'b0;
                  s_eng     <= E_DISK_RD;
                end
              end else begin
                s_sec_idx <= s_sec_idx + 11'd1;
              end
            end
          end
        end

        E_MEM_RD: begin
          if (!s_dma_wait && !dma_busy) begin
            dma_issue(1'b0, {6'd0, s_core_hi, s_core_addr}, 16'd0);
          end else if (s_dma_wait && dma_ack) begin
            s_dma_wait <= 1'b0;
            if (dma_err) begin
              // bus/memory fault reading a word for the disk write - abort
              // as a hard error (SMD review C3: dma_err was ignored here).
              s_hw_err    <= 1'b1;
              s_delay_cnt <= DELAY_TICKS;
              s_eng       <= E_DELAY;
            end else begin
              s_buffer[s_sec_idx[9:0]] <= dma_rdata;
              s_core_addr <= s_core_addr + 16'd1;
              s_word_cnt  <= s_word_cnt - 16'd1;
              if (s_sec_idx + 11'd1 >= s_chunk_q || s_word_cnt == 16'd1) begin
                disk_req <= 1'b1;
                disk_wr  <= 1'b1;
                s_eng    <= E_DISK_WR;
              end else begin
                s_sec_idx <= s_sec_idx + 11'd1;
              end
            end
          end
        end

        E_DISK_WR: begin
          if (disk_done) begin
            if (disk_err_in) begin
              s_hw_err    <= 1'b1;
              s_delay_cnt <= DELAY_TICKS;
              s_eng       <= E_DELAY;
            end else if (s_word_cnt == 16'd0) begin
              s_delay_cnt <= DELAY_TICKS;
              s_eng       <= E_DELAY;
            end else begin
              s_chunk_q <= (s_word_cnt > {5'd0, BUF_WORDS}) ?
                           BUF_WORDS : s_word_cnt[10:0];
              s_sec_idx <= 11'd0;
              s_eng     <= E_MEM_RD;
            end
          end
        end

        E_DELAY: begin
          if (s_delay_cnt != 16'd0) s_delay_cnt <= s_delay_cnt - 16'd1;
          else begin
            s_active <= 1'b0;
            s_rft    <= 1'b1;
            s_eng    <= E_IDLE;
          end
        end

        default: s_eng <= E_IDLE;
      endcase

      if (s_ident_answer) begin
        s_int_en <= 1'b0;
      end
    end
  end

endmodule
