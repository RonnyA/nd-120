/**************************************************************************
** ND WINCHESTER DISC CONTROLLER, 5 1/4 inch ST506 (3041) / 8 inch (3038) **
**                                                                       **
** DMA block device, IOX 500-507, ident 1, interrupt level 11.           **
**                                                                       **
** Register core made 1:1 faithful to two host-gated C implementations   **
** that are themselves proven byte-identical against each other:         **
**   nd100x  src/devices/winchester/deviceWinchester.c (synchronous)     **
**   portable lib/NDDeviceCore/src/nd_winchester.c     (phase machine)   **
** A shared conformance sequence drives both and the traces are diffed;  **
** this RTL follows the same decisions. Primary source for every rule    **
** below is ND-11.015.01, sections 2.1 and 3.1-3.5 plus 4.1.             **
**                                                                       **
** ---------------------------------------------------------------------- **
** WHY THIS CARD EXISTS ALONGSIDE ND_SMD.v                               **
**                                                                       **
** The families differ in how the 24-bit memory address and the word      **
** count are loaded, and that is what tells them apart:                   **
**                                                                       **
**   NORD-10 large disc   address ONE access,   word count ONE access    **
**   ECC (ND 558/559)     address ONE access,   word count ONE access    **
**   15 MHz SMD (ND 632)  address TWO accesses, word count TWO accesses  **
**   Winchester (this)    address TWO accesses, word count ONE access    **
**                                                                       **
** The ND-120's own MASS STORAGE LOAD microcode (PROM listing, CSA       **
** 002221-002227) writes the core address TWICE and the word count ONCE. **
** That is the Winchester pattern exactly - which is why this core needs **
** NO boot-mode special case at all. ND_SMD.v carries one (s_boot_mode,  **
** the BPUN byte-server plus the "a +1 or +7 write leaves boot mode"     **
** escape) precisely because the microcode's protocol does NOT match its **
** registers. Here the microcode drives the normal register path and a   **
** normal GO, so there is nothing to special-case.                       **
**                                                                       **
** There is also NO register multiplex bit (no CWR): every IOX offset    **
** means exactly one thing, and there is no controller-type strap - the  **
** loading protocol is fixed.                                            **
**                                                                       **
** Register map (offset from base, sec 3.1):                             **
**   +0 R  Read memory address     LO 16 first, then HI 8                **
**   +1 W  Load memory address     HI 8 first, then LO 16                **
**   +2 R  NOT USED - reads 0 ("IOX 502 Not used" in the sec 3.1 table)  **
**   +3 W  Load block address      cylinder b15-5, sector b4-0           **
**   +4 R  Read status register    READING IT RESETS THE FLIP-FLOPS      **
**   +5 W  Load control word       GO / opcode                           **
**   +6 R  Read block address      unconditional - the sec 3.1 table has **
**                                 no test-mode qualifier                **
**   +7 W  Load word count / step count   SINGLE access                  **
**                                                                       **
** NOTE the deliberate asymmetry at +0/+1: address WRITES go HI then LO, **
** address READS come back LO then HI (sec 3.2).                         **
**                                                                       **
** The upper/lower selection flip-flop is reset by ANY of four events    **
** (sec 3.2), all four implemented here: master clear, programmed device **
** clear (control b4), a status register read, and activation (b2).      **
**                                                                       **
** Control word (+5, sec 3.4):                                          **
**   b0 int-enable (on NOT active), b1 error-int enable, b2 ACTIVE (GO), **
**   b3 test mode, b4 device clear, b5-8 head, b9 unit (ONE bit - hence  **
**   two units maximum), b10 unused, b11-13 operation M0..M7,            **
**   b14 seek direction (ZERO = towards cylinder 0), b15 bad track.      **
**                                                                       **
** Status (+4, sec 3.5):                                                 **
**   b0 int-enabled        b1 error-int-enabled   b2 active              **
**   b3 finished with a device operation          b4 inclusive OR (b5-13)**
**   b5 3041: r/w during RTZ  b6 timeout  b7 disk fault                  **
**   b8 address mismatch   b9 CRC error   b10 compare error              **
**   b11 FIFO over/under-run or DMA channel error                        **
**   b12 always 0          b13 3041: always 1 / 3038: r/w gate active    **
**   b14 on cylinder       b15 always 0 - distinguishes this card from   **
**                             the 10 Mb controller                      **
**                                                                       **
** INTERRUPT (sec 4.1), the rule TPE CONFIGURATION probes with:          **
**   "If the controller is ready for an operation (status bit 3 = 1),    **
**    and interrupt is enabled (status bit 0 has been set by control bit **
**    0 = 1), the interrupt signal BINT11 will be active ... The IDENT   **
**    code may now be read by an IDENT PL11 instruction."                **
**   A CONDITION on the current status, not a pulse: activation drops    **
**   b3 and therefore drops the line, which returns at completion. The C **
**   port shipped once without this and TPE reported "No identcode found **
**   on level 11D, expected identcode : 1B".                             **
**                                                                       **
** HARDWARE-CONSTRAINED DIVERGENCE, same as ND_SMD.v: the C models       **
** pre-check that a unit is ATTACHED and (for writes) not WRITE-         **
** PROTECTED using media metadata. This core has no backend metadata     **
** port, so those two faults arrive as disk_err_in during the transfer   **
** and become the same terminated-with-error result. The address-        **
** mismatch bound (b8) IS pre-checked against the GEO_* parameters.      **
**                                                                       **
** MEDIA FILES: this card's images are WDn.IMG, NEVER SMDn.IMG.          **
**                                                                       **
** Thumbwheels (both level 11, sec 3.1):                                 **
**   tw0 disk system 1, base 00500 ident 001                             **
**   tw1 disk system 2, base 00510 ident 005                             **
**   500-507 is the SAME block as the CDC cartridge disc - a machine has **
**   one card or the other, never both.                                  **
**                                                                       **
** Ronny Hansen                                                          **
***************************************************************************/

module ND_WINCHESTER #(
    parameter [15:0] BASE_ADDR   = 16'o000500,
    parameter [15:0] IDENT_CODE  = 16'o000001,
    parameter [3:0]  INT_LEVEL   = 4'd11,
    // How long the controller stays ACTIVE after a GO before it reports
    // completion, in sysclk cycles. Do NOT set this by hand at an
    // instantiation: it is a TIME, so the board wrapper computes it from its
    // own clock frequency. The module default stays small so the unit
    // testbenches run fast. Same rule as ND_SMD.v's DELAY_TICKS.
    parameter [31:0] DELAY_TICKS = 32'd10,
    // Geometry for the address-mismatch bound. Default = the Micropolis 1325
    // (the DISC-74-1): 8 heads, 9 sectors/track, 1024 cylinders, 1024-byte
    // sectors. That is the drive SINTRAN boots from, and the default both C
    // implementations use. A backend owning a different drive passes its own.
    parameter [15:0] GEO_HEADS   = 16'd8,
    parameter [15:0] GEO_SPT     = 16'd9,
    parameter [15:0] GEO_MAX_CYL = 16'd1024,
    // Card model. 0 = 3041 (5 1/4 inch ST506), whose status b13 reads a
    // constant 1; 1 = 3038 (8 inch), whose b13 is the live read/write gate.
    // A parameter rather than an input for the same reason as ND_SMD.v's
    // strap: an unwired input floats and would read as 0 anyway.
    parameter IS_3038 = 0
) (
    input wire sysclk,
    input wire sys_rst_n,

    // Device bus (from ND_BUS_SLAVE) - IOX slave side
    input  wire [15:0] iox_addr,
    input  wire        iox_wr,
    input  wire [15:0] iox_wdata,
    input  wire        iox_rd,
    output reg  [15:0] iox_rdata,
    output wire        iox_sel,         // 1 = this core owns the captured IOX address
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

    // Disk backend: chunk transfers through the internal buffer. Same port
    // shape as ND_SMD.v so the nd_storage adapter pattern carries over; the
    // block address is split into the two words the adapter expects.
    output reg         disk_start,
    output reg         disk_req,
    output reg         disk_wr,
    output wire [15:0] disk_blkaddr1,  // head b15-8, sector b7-0
    output wire [15:0] disk_blkaddr2,  // cylinder
    output wire [2:0]  disk_unit,      // only bit 0 is used - two units
    output wire [10:0] disk_wordcount, // words in the current chunk
    input  wire        disk_done,
    input  wire        disk_err_in,
    input  wire [9:0]  dbuf_addr,
    input  wire [15:0] dbuf_wdata,
    input  wire        dbuf_we,
    output reg  [15:0] dbuf_rdata
);

  localparam [10:0] BUF_WORDS = 11'd1024;

  // Device operation codes, control word b11-13 (sec 3.4).
  localparam [2:0] OP_READ       = 3'd0;  // M0
  localparam [2:0] OP_WRITE      = 3'd1;  // M1
  localparam [2:0] OP_READ_PAR   = 3'd2;  // M2
  localparam [2:0] OP_COMPARE    = 3'd3;  // M3
  localparam [2:0] OP_SEEK       = 3'd4;  // M4 - step count in +7
  localparam [2:0] OP_WR_FORMAT  = 3'd5;  // M5
  localparam [2:0] OP_LOAD_CTRL  = 3'd6;  // M6 - 3038 only, NOT activated
  localparam [2:0] OP_RTZ        = 3'd7;  // M7

  // ---- controller registers ----
  reg [15:0] s_mem_addr_lo;   // memory address bits 0-15
  reg [7:0]  s_mem_addr_hi;   // memory address bits 16-23
  reg [15:0] s_word_cnt;      // word count, ALSO the M4 step count
  reg [15:0] s_blkaddr;       // cylinder b15-5, sector b4-0

  wire [10:0] w_cyl    = s_blkaddr[15:5];
  wire [4:0]  w_sector = s_blkaddr[4:0];

  // ---- unit selection + per-unit state ----
  reg        s_sel_unit;      // control word b9 - ONE bit, two units
  reg [3:0]  s_head;          // control word b5-8
  reg        s_seek_dir;      // control word b14: 0 = towards cylinder 0
  reg        s_bad_track;     // control word b15
  reg [1:0]  s_on_cyl;        // per-unit on-cylinder (status b14)

  // M4 is a RELATIVE STEP seek, so each arm's position must be remembered.
  reg [15:0] s_cyl_pos [0:1];

  // ---- status flags (sec 3.5) ----
  reg        s_int_en;        // b0
  reg        s_errint_en;     // b1
  reg        s_active;        // b2
  reg        s_rft;           // b3  finished with a device operation
  reg        s_rtz_viol;      // b5
  reg        s_time_out;      // b6
  reg        s_disk_fault;    // b7
  reg        s_addr_mismatch; // b8
  reg        s_crc_err;       // b9
  reg        s_compare_err;   // b10
  reg        s_dma_ch_err;    // b11
  reg        s_rw_gate;       // b13 on the 3038 only
  reg        s_test_mode;     // control b3

  // ---- the upper/lower selection flip-flops (sec 3.2) ----
  reg        s_ma_write_ff;
  reg        s_ma_read_ff;

  reg        s_irq;           // latched level-11 interrupt line

  assign disk_blkaddr1 = {4'd0, s_head, 3'd0, w_sector};
  assign disk_blkaddr2 = {5'd0, w_cyl};
  assign disk_unit     = {2'd0, s_sel_unit};

  // ---- internal buffer ----
  // Async-read arrays do NOT map to Gowin BSRAM, so this is a simple dual-port
  // RAM: one muxed write port, one registered read port whose address follows
  // the active consumer. Same refactor as ND_SMD.v and ND_FLOPPY_DMA.
  reg [15:0] s_buffer[0:1023];

  // ---- decode ----
  wire s_addressed = (iox_addr[15:3] == BASE_ADDR[15:3]);
  assign iox_sel   = s_addressed;
  wire [2:0] s_reg = iox_addr[2:0];
  wire s_wr_here = iox_wr && s_addressed;
  wire s_rd_here = iox_rd && s_addressed;

  // ---- status assembly (sec 3.5) ----
  // Bit 4 is the inclusive OR of the error bits. Bit 13 is EXCLUDED even
  // though the manual's wording says "bits 5-13": on a 3041 b13 is always 1,
  // so including it would make the error OR permanently set.
  wire s_incl_or = s_rtz_viol | s_time_out | s_disk_fault | s_addr_mismatch |
                   s_crc_err  | s_compare_err | s_dma_ch_err;

  // Bit 13 is the card identity: the 3041 always reads 1 ("Used to distinguish
  // the 3038 from the 3041"), the 3038 reports its live read/write gate.
  wire s_contr_id = IS_3038 ? s_rw_gate : 1'b1;

  wire [15:0] s_status =
      { 1'b0,             // b15 always 0 - not the 10 Mb controller
        s_on_cyl[s_sel_unit], // b14 on cylinder
        s_contr_id,       // b13 card identity
        1'b0,             // b12 always 0
        s_dma_ch_err,     // b11 FIFO over/under-run or DMA channel error
        s_compare_err,    // b10 compare error
        s_crc_err,        // b9  CRC error
        s_addr_mismatch,  // b8  address mismatch
        s_disk_fault,     // b7  disk fault or missing clocks
        s_time_out,       // b6  timeout
        s_rtz_viol,       // b5  r/w attempted during RTZ (3041)
        s_incl_or,        // b4  inclusive OR of b5-13
        s_rft,            // b3  finished with a device operation
        s_active,         // b2  controller active
        s_errint_en,      // b1  error interrupt enabled
        s_int_en };       // b0  controller-not-active interrupt enabled

  // ---- interrupt / ident (latched line) ----
  assign int_pending = {(INT_LEVEL == 4'd13) && s_irq,
                        (INT_LEVEL == 4'd12) && s_irq,
                        (INT_LEVEL == 4'd11) && s_irq,
                        (INT_LEVEL == 4'd10) && s_irq};
  wire s_ident_answer = ident_strobe && ident_grant_in &&
                        (ident_level == INT_LEVEL) && s_irq;
  assign ident_hit       = s_ident_answer;
  assign ident_code      = s_ident_answer ? IDENT_CODE : 16'd0;
  assign ident_grant_out = ident_grant_in && !s_ident_answer;

  // ---- IOX read mux ----
  // Reads are NOT gated on a selected unit. These are CONTROLLER registers -
  // they exist whether or not a drive is selected, and a probe must be able to
  // tell an absent card from an idle one. Both C implementations shipped a
  // "return 0 when no disk selected" gate here; it was a bug in all of them.
  always @(*) begin
    iox_rdata = 16'd0;
    if (s_rd_here) begin
      case (s_reg)
        // Sec 3.2: the reads are the OPPOSITE order to the writes - the first
        // IOX 500 returns the LOW 16 bits, the second the UPPER 8.
        3'd0: iox_rdata = s_ma_read_ff ? {8'd0, s_mem_addr_hi} : s_mem_addr_lo;
        // +2: "IOX 502 Not used" in the sec 3.1 table. There is no
        // programmer-visible sector counter on this card - the sector counters
        // named in the hardware description are internal. Both C models had a
        // readable counter here until the cross-check sent us to the table.
        3'd2: iox_rdata = 16'd0;
        3'd4: iox_rdata = s_status;
        // +6: "IOX 506 Read Block (disk) address register", with NO test-mode
        // qualifier, so it reads back unconditionally.
        3'd6: iox_rdata = s_blkaddr;
        default: iox_rdata = 16'd0;   // +1/+3/+5/+7 are write-only
      endcase
    end
  end

  // ---- transfer engine ----
  localparam E_IDLE    = 3'd0;
  localparam E_DISK_RD = 3'd1;  // backend: image chunk -> buffer
  localparam E_MEM_WR  = 3'd2;  // DMA: buffer -> ND memory
  localparam E_MEM_RD  = 3'd3;  // DMA: ND memory -> buffer
  localparam E_DISK_WR = 3'd4;  // backend: buffer -> image chunk
  localparam E_DELAY   = 3'd5;  // completion delay -> FinishOperation

  reg [2:0]  s_eng;
  reg [10:0] s_chunk_q;
  reg [10:0] s_sec_idx;
  reg [31:0] s_delay_cnt;
  reg        s_dma_wait;
  reg [23:0] s_dma_addr_r;   // running ND word address
  reg [23:0] s_words_left;   // words still to move
  reg        s_unit;         // selected drive for this command

  assign disk_wordcount = s_chunk_q;

  // CHS -> LBA, the same formula the SMD core and both C models use.
  function [31:0] chs2lba;
    input [15:0] cyl;
    input [15:0] head;
    input [15:0] sector;
    begin
      chs2lba = (({16'd0, cyl} * {16'd0, GEO_HEADS}) + {16'd0, head})
                * {16'd0, GEO_SPT} + {16'd0, sector};
    end
  endfunction

  // GO-time address decode (registers are stable outside a control write).
  wire [31:0] w_lba     = chs2lba({5'd0, w_cyl}, {12'd0, s_head}, {11'd0, w_sector});
  wire [31:0] w_max_lba = chs2lba(GEO_MAX_CYL, GEO_HEADS, GEO_SPT);
  wire [23:0] w_words   = {8'd0, s_word_cnt};

  task dma_issue(input wr, input [23:0] a, input [15:0] d);
    begin
      dma_req    <= 1'b1;
      dma_wr     <= wr;
      dma_addr   <= a;
      dma_wdata  <= d;
      s_dma_wait <= 1'b1;
    end
  endtask

  // The four flip-flop reset conditions all call this (sec 3.2).
  task clr_ff;
    begin
      s_ma_write_ff <= 1'b0;
      s_ma_read_ff  <= 1'b0;
    end
  endtask

  // Terminate an operation in error. The specific status bit is set by the
  // caller first. The operation still FINISHES (b3 goes to 1) because the
  // manual's b3 is "finished with a device operation", not "finished
  // successfully" - and because leaving b3 low would wedge a guest waiting on
  // an interrupt that the sec 4.1 condition can then never produce.
  task err_active;
    begin
      s_active <= 1'b0;
      s_rft    <= 1'b1;
      clr_ff;
      s_on_cyl[s_unit] <= 1'b0;
      s_eng      <= E_IDLE;
      s_dma_wait <= 1'b0;
      if (s_errint_en) s_irq <= 1'b1;
      else             s_irq <= s_int_en;   // sec 4.1: ready && enabled
    end
  endtask

  // ---- buffer RAM ports (BSRAM-mappable: sync write + sync read) ----------
  wire        s_memrd_commit = (s_eng == E_MEM_RD) && s_dma_wait &&
                               dma_ack && !dma_err;
  wire        s_buf_we    = dbuf_we | s_memrd_commit;
  wire [ 9:0] s_buf_waddr = dbuf_we ? dbuf_addr : s_sec_idx[9:0];
  wire [15:0] s_buf_wdata = dbuf_we ? dbuf_wdata : dma_rdata;
  wire [ 9:0] s_buf_raddr = (s_eng == E_MEM_WR)  ? s_sec_idx[9:0] :
                            (s_eng == E_DISK_WR) ? dbuf_addr      :
                                                   10'd0;
  reg  [15:0] s_buf_dout;
  reg  [ 9:0] s_buf_raddr_q;
  wire        s_buf_valid = (s_buf_raddr_q == s_buf_raddr);

  always @(posedge sysclk) begin
    if (s_buf_we) s_buffer[s_buf_waddr] <= s_buf_wdata;
    s_buf_dout    <= s_buffer[s_buf_raddr];
    s_buf_raddr_q <= s_buf_raddr;
  end

  always @(*) dbuf_rdata = s_buf_dout;

  always @(posedge sysclk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
      s_mem_addr_lo  <= 16'd0;
      s_mem_addr_hi  <= 8'd0;
      s_word_cnt     <= 16'd0;
      s_blkaddr      <= 16'd0;
      s_sel_unit     <= 1'b0;
      s_head         <= 4'd0;
      s_seek_dir     <= 1'b0;
      s_bad_track    <= 1'b0;
      s_on_cyl       <= 2'd0;
      s_cyl_pos[0]   <= 16'd0;
      s_cyl_pos[1]   <= 16'd0;
      s_int_en       <= 1'b0;
      s_errint_en    <= 1'b0;
      s_active       <= 1'b0;
      s_rft          <= 1'b0;
      s_rtz_viol     <= 1'b0;
      s_time_out     <= 1'b0;
      s_disk_fault   <= 1'b0;
      s_addr_mismatch<= 1'b0;
      s_crc_err      <= 1'b0;
      s_compare_err  <= 1'b0;
      s_dma_ch_err   <= 1'b0;
      s_rw_gate      <= 1'b0;
      s_test_mode    <= 1'b0;
      s_ma_write_ff  <= 1'b0;   // master clear is reset condition #1 (sec 3.2)
      s_ma_read_ff   <= 1'b0;
      s_irq          <= 1'b0;
      s_eng          <= E_IDLE;
      s_chunk_q      <= 11'd0;
      s_sec_idx      <= 11'd0;
      s_delay_cnt    <= 32'd0;
      s_dma_wait     <= 1'b0;
      s_dma_addr_r   <= 24'd0;
      s_words_left   <= 24'd0;
      s_unit         <= 1'b0;
      dma_req        <= 1'b0;
      dma_wr         <= 1'b0;
      dma_addr       <= 24'd0;
      dma_wdata      <= 16'd0;
      disk_start     <= 1'b0;
      disk_req       <= 1'b0;
      disk_wr        <= 1'b0;
    end else begin
      dma_req    <= 1'b0;
      disk_start <= 1'b0;
      disk_req   <= 1'b0;

      // ---- read-strobe side effects ----
      if (s_rd_here) begin
        case (s_reg)
          // Successive +0 reads alternate LO then HI (sec 3.2).
          3'd0: s_ma_read_ff <= ~s_ma_read_ff;
          // A status read is flip-flop reset condition #3 (sec 3.2).
          3'd4: clr_ff;
          default: ;
        endcase
      end

      // ---- IOX register writes ----
      if (s_wr_here) begin
        case (s_reg)
          // +1  Load memory address: TWO accesses, HI 8 then LO 16 (sec 3.2).
          3'd1: begin
            if (s_ma_write_ff) begin
              s_mem_addr_lo <= iox_wdata;          // second write: LO 16
              s_ma_write_ff <= 1'b0;
            end else begin
              s_mem_addr_hi <= iox_wdata[7:0];     // first write: HI 8
              s_ma_write_ff <= 1'b1;
            end
          end

          // +3  Load block address: cylinder b15-5, sector b4-0 (sec 3.3).
          3'd3: s_blkaddr <= iox_wdata;

          // +5  Load control word (GO / opcode), sec 3.4.
          3'd5: begin
            s_int_en    <= iox_wdata[0];
            s_errint_en <= iox_wdata[1];
            s_test_mode <= iox_wdata[3];
            s_head      <= iox_wdata[8:5];
            s_sel_unit  <= iox_wdata[9];
            s_seek_dir  <= iox_wdata[14];
            s_bad_track <= iox_wdata[15];

            // Device clear (b4). Sec 3.4: "To clear the disk drive, it may be
            // necessary to execute two consecutive device clear before reading
            // a correct status."
            //
            // Processed INLINE - it must NOT skip the ready/interrupt update
            // below, because a single control word may carry device clear AND
            // the interrupt enable together, which is how a probe usually
            // opens. Both C models take the same shape, following the
            // paper-tape reader's "processed inline, does NOT break".
            if (iox_wdata[4]) begin
              s_active       <= 1'b0;
              s_mem_addr_lo  <= 16'd0;
              s_mem_addr_hi  <= 8'd0;
              s_word_cnt     <= 16'd0;
              s_blkaddr      <= 16'd0;
              s_rtz_viol     <= 1'b0;
              s_time_out     <= 1'b0;
              s_disk_fault   <= 1'b0;
              s_addr_mismatch<= 1'b0;
              s_crc_err      <= 1'b0;
              s_compare_err  <= 1'b0;
              s_dma_ch_err   <= 1'b0;
              clr_ff;
              s_eng          <= E_IDLE;
              s_dma_wait     <= 1'b0;
              s_irq          <= 1'b0;
            end

            // Activation (b2). Sec 3.4: every operation code is activated by
            // loading the code with the activate bit, EXCEPT M6.
            //
            // M6 only sets additional control bits (3038 only) - it is a
            // control-bit load, not an operation - so a control word carrying
            // it takes the NON-activating path below and leaves the card
            // ready. The manual never says what the hardware does if you
            // activate M6 anyway ("no activation should be made" is guidance
            // to the programmer); both C models make the same choice, and the
            // cross-check trace keeps all three from drifting apart.
            if (iox_wdata[2] && iox_wdata[13:11] != OP_LOAD_CTRL) begin
              // Activation is flip-flop reset condition #4 (sec 3.2).
              clr_ff;
              s_active <= 1'b1;
              s_rft    <= 1'b0;
              s_unit   <= iox_wdata[9];
              s_on_cyl[iox_wdata[9]] <= 1'b1;

              s_rtz_viol      <= 1'b0;
              s_time_out      <= 1'b0;
              s_disk_fault    <= 1'b0;
              s_addr_mismatch <= 1'b0;
              s_crc_err       <= 1'b0;
              s_compare_err   <= 1'b0;
              s_dma_ch_err    <= 1'b0;

              // Sec 4.1 is a condition on the CURRENT status: activation drops
              // b3, so the line drops with it and returns at completion.
              s_irq <= 1'b0;

              s_dma_addr_r <= {s_mem_addr_hi, s_mem_addr_lo};
              s_words_left <= w_words;

              case (iox_wdata[13:11])
                OP_SEEK: begin
                  // M4 is a RELATIVE STEP seek (sec 3.4.5): step count in the
                  // word-count register, direction in b14 where ZERO means
                  // towards cylinder 0. Clamped at both stops - running the
                  // arm past either one is not a status-reported error, the
                  // drive simply stops.
                  if (!iox_wdata[14]) begin
                    s_cyl_pos[iox_wdata[9]] <=
                        (s_cyl_pos[iox_wdata[9]] > s_word_cnt) ?
                        (s_cyl_pos[iox_wdata[9]] - s_word_cnt) : 16'd0;
                  end else begin
                    s_cyl_pos[iox_wdata[9]] <=
                        ((s_cyl_pos[iox_wdata[9]] + s_word_cnt) > GEO_MAX_CYL ||
                         (s_cyl_pos[iox_wdata[9]] + s_word_cnt) <
                          s_cyl_pos[iox_wdata[9]]) ?
                        GEO_MAX_CYL : (s_cyl_pos[iox_wdata[9]] + s_word_cnt);
                  end
                  s_delay_cnt <= DELAY_TICKS;
                  s_eng       <= E_DELAY;
                end

                OP_RTZ: begin
                  s_cyl_pos[iox_wdata[9]] <= 16'd0;
                  s_rtz_viol  <= 1'b0;
                  s_delay_cnt <= DELAY_TICKS;
                  s_eng       <= E_DELAY;
                end

                OP_READ, OP_WRITE: begin
                  // Test mode bypasses the bounds check (sec 3.4).
                  if (!iox_wdata[3] &&
                      ((w_lba > w_max_lba) ||
                       ({11'd0, s_head}  >= GEO_HEADS) ||
                       ({11'd0, w_sector} >= GEO_SPT))) begin
                    s_addr_mismatch <= 1'b1;
                    s_active <= 1'b0;
                    s_rft    <= 1'b1;
                    s_on_cyl[iox_wdata[9]] <= 1'b0;
                    s_eng      <= E_IDLE;
                    s_dma_wait <= 1'b0;
                    if (iox_wdata[1]) s_irq <= 1'b1;
                    else              s_irq <= iox_wdata[0];
                  end else if (w_words != 24'd0) begin
                    s_chunk_q <= (w_words > {13'd0, BUF_WORDS}) ?
                                 BUF_WORDS : w_words[10:0];
                    s_sec_idx <= 11'd0;
                    if (iox_wdata[13:11] == OP_READ) begin
                      disk_start <= 1'b1;
                      disk_req   <= 1'b1;
                      disk_wr    <= 1'b0;
                      s_eng      <= E_DISK_RD;
                    end else begin
                      disk_start <= 1'b1;
                      s_eng      <= E_MEM_RD;
                    end
                  end else begin
                    // A zero-length transfer still completes.
                    s_delay_cnt <= DELAY_TICKS;
                    s_eng       <= E_DELAY;
                  end
                end

                default: begin
                  // M2 read-parity / M3 compare / M5 write-format: documented
                  // stubs, acknowledged as no-data completions so the guest
                  // proceeds. A compare never reports a mismatch and a format
                  // writes nothing - same choice as both C models.
                  s_delay_cnt <= DELAY_TICKS;
                  s_eng       <= E_DELAY;
                end
              endcase

            end else if (!iox_wdata[4]) begin
              // A control word that does NOT activate (and is not a device
              // clear, which handled its own interrupt above): the controller
              // stays idle and is by definition ready for an operation, so
              // status b3 goes to 1 and the sec 4.1 condition is re-evaluated.
              // THIS is what makes TPE CONFIGURATION find the card.
              s_rft <= 1'b1;
              s_irq <= iox_wdata[0];
            end else begin
              // Device clear AND the interrupt enable in one word: the clear
              // ran above; still evaluate sec 4.1 with ready now true.
              s_rft <= 1'b1;
              s_irq <= iox_wdata[0];
            end
          end

          // +7  Load word count / step count - a SINGLE access.
          // THE register that differs from the 15 MHz SMD card, and the reason
          // the ND-120 mass-load microcode works here: it writes the word count
          // once, with 002000 (1024 words). For M4 the same register carries
          // the STEP COUNT (sec 3.4.5).
          3'd7: s_word_cnt <= iox_wdata;

          default: ;
        endcase
      end

      // ---- transfer engine ----
      case (s_eng)
        E_IDLE: ;

        E_DISK_RD: begin
          if (disk_done) begin
            if (disk_err_in) begin
              // A media read fault is a CRC error on this card - the drive
              // could not return good data.
              s_crc_err <= 1'b1;
              err_active;
            end else begin
              s_sec_idx <= 11'd0;
              s_eng     <= E_MEM_WR;
            end
          end
        end

        E_MEM_WR: begin
          // s_buf_valid: wait the one read-latency cycle after entering the
          // state / advancing s_sec_idx so s_buf_dout holds THIS word.
          if (!s_dma_wait && !dma_busy && s_buf_valid) begin
            dma_issue(1'b1, s_dma_addr_r, s_buf_dout);
          end else if (s_dma_wait && dma_ack) begin
            s_dma_wait <= 1'b0;
            if (dma_err) begin
              s_dma_ch_err <= 1'b1;   // b11: the fault came from the ND bus
              err_active;
            end else begin
              s_dma_addr_r <= s_dma_addr_r + 24'd1;
              s_words_left <= s_words_left - 24'd1;
              if (s_sec_idx + 11'd1 >= s_chunk_q || s_words_left == 24'd1) begin
                if (s_words_left == 24'd1) begin
                  s_delay_cnt <= DELAY_TICKS;
                  s_eng       <= E_DELAY;
                end else begin
                  s_chunk_q <= ((s_words_left - 24'd1) > {13'd0, BUF_WORDS}) ?
                               BUF_WORDS : (s_words_left[10:0] - 11'd1);
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
            dma_issue(1'b0, s_dma_addr_r, 16'd0);
          end else if (s_dma_wait && dma_ack) begin
            s_dma_wait <= 1'b0;
            if (dma_err) begin
              s_dma_ch_err <= 1'b1;
              err_active;
            end else begin
              // The buffer write happens through the muxed RAM write port
              // (s_memrd_commit mirrors this exact condition).
              s_dma_addr_r <= s_dma_addr_r + 24'd1;
              s_words_left <= s_words_left - 24'd1;
              if (s_sec_idx + 11'd1 >= s_chunk_q || s_words_left == 24'd1) begin
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
              // A media write fault is a disk fault (b7). Note the adapter
              // refuses a partial-block write by design, so an unaligned
              // Winchester write arrives here as a clean, visible error
              // rather than silent corruption.
              s_disk_fault <= 1'b1;
              err_active;
            end else if (s_words_left == 24'd0) begin
              s_delay_cnt <= DELAY_TICKS;
              s_eng       <= E_DELAY;
            end else begin
              s_chunk_q <= (s_words_left > {13'd0, BUF_WORDS}) ?
                           BUF_WORDS : s_words_left[10:0];
              s_sec_idx <= 11'd0;
              s_eng     <= E_MEM_RD;
            end
          end
        end

        // Completion delay, then FinishOperation.
        E_DELAY: begin
          if (s_delay_cnt != 32'd0) begin
            s_delay_cnt <= s_delay_cnt - 32'd1;
          end else begin
            s_active <= 1'b0;
            s_rft    <= 1'b1;
            clr_ff;
            s_mem_addr_lo <= s_dma_addr_r[15:0];
            s_mem_addr_hi <= s_dma_addr_r[23:16];
            s_word_cnt    <= 16'd0;
            s_on_cyl[s_unit] <= 1'b1;
            s_eng         <= E_IDLE;
            // Sec 4.1 with ready now true: the line follows the enable.
            s_irq         <= s_int_en;
          end
        end

        default: s_eng <= E_IDLE;
      endcase

      // IDENT answered: clear interrupt-enable and drop the line.
      if (s_ident_answer) begin
        s_int_en <= 1'b0;
        s_irq    <= 1'b0;
      end
    end
  end

endmodule
