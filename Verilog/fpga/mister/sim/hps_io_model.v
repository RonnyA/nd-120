/****************************************************************************
** hps_io_model - the ARM + hps_io block interface, as a testbench model    **
**                                                                         **
** Behaves like the MiSTer HPS serving OSD-mounted image files through     **
** hps_io's sd_* block interface, at the SIGNAL level, so that              **
** nd_storage_hps can be simulated in iverilog against the same handshake  **
** it will meet on the board. Every rule below is taken from the vendored  **
** Verilog/fpga/mister/sys/hps_io.sv and Main_MiSTer/user_io.cpp           **
** (01-SEP-2026), and the model CHECKS the rules the core must obey, not   **
** just the ones it must survive:                                          **
**                                                                         **
**   - The ARM polls: a request (sd_rd/sd_wr bit) is noticed only every    **
**     POLL_CYCLES clk_sys cycles. Between polls a dropped request is       **
**     simply never seen. A request that is still high on the poll after   **
**     its transfer is run AGAIN - the model counts that as a violation.   **
**   - Slot choice among several requests is rotating round-robin.          **
**   - sd_lba / sd_blk_cnt are sampled at the poll, BEFORE ack rises; if    **
**     they change between the poll and the ack, that is a violation.       **
**   - sd_ack[slot] is one-hot and stays high for the whole transaction.    **
**     The core must drop its request on the RISING edge of ack (sd_card.sv **
**     discipline); the model flags a request still high at the END.        **
**   - The stream: (sd_blk_cnt+1) * 256 words (WIDE, 512-byte blocks), one **
**     word every WORD_CYCLES: sd_buff_dout valid, sd_buff_wr for ONE       **
**     cycle, sd_buff_addr incremented two cycles after the strobe          **
**     (hps_io.sv:295-297), saturating.                                     **
**   - Write direction: the ARM samples sd_buff_din on its strobe and       **
**     increments sd_buff_addr in the same cycle (hps_io.sv:411-412).       **
**   - Unmounted slot: the ARM still serves the read with ZEROS and acks;   **
**     a write to it is dropped silently. Short reads past EOF: the bytes   **
**     beyond the file are left as zero here (the real ARM leaves stale     **
**     buffer content - undefined, so a core must never depend on them).    **
**   - Mount: img_size is sent first (a separate transaction), then         **
**     img_mounted[slot] is held high for MOUNT_CYCLES with img_readonly.   **
**     Unmount is the same with size 0 and readonly 1.                      **
**   - The file: bytes. hps_io in WIDE mode hands them over as 16-bit       **
**     LITTLE-ENDIAN words: word w = {byte 2w+1, byte 2w}. That is the      **
**     model's reading of the framework and is what the core's BYTE_SWAP    **
**     undoes; the board test is the final word on it.                      **
**                                                                         **
** Per-slot storage is a plain byte array (IMG_BYTES per slot) so a test   **
** can preload and inspect it directly.                                    **
**                                                                         **
** Ronny Hansen, 01-SEP-2026                                                **
*****************************************************************************/

`timescale 1ns / 1ps

module hps_io_model #(
    parameter integer VDNUM       = 5,
    parameter integer IMG_BYTES   = 65536,   // per slot
    parameter integer POLL_CYCLES = 40,      // clk_sys cycles between polls
    parameter integer WORD_CYCLES = 6,       // clk_sys cycles per streamed word
    parameter integer MOUNT_CYCLES = 4
) (
    input  wire              clk_sys,
    output reg  [VDNUM-1:0]  img_mounted,
    output reg               img_readonly,
    output reg  [63:0]       img_size,
    input  wire [VDNUM*32-1:0] sd_lba,
    input  wire [VDNUM*6-1:0]  sd_blk_cnt,
    input  wire [VDNUM-1:0]  sd_rd,
    input  wire [VDNUM-1:0]  sd_wr,
    output reg  [VDNUM-1:0]  sd_ack,
    output reg  [12:0]       sd_buff_addr,
    output reg  [15:0]       sd_buff_dout,
    input  wire [15:0]       sd_buff_din,
    output reg               sd_buff_wr,

    // bookkeeping for the testbench
    output integer n_reads,
    output integer n_writes,
    output integer violations
);

  reg [7:0] img[0:VDNUM*IMG_BYTES-1];
  reg [31:0] size[0:VDNUM-1];
  reg        ro[0:VDNUM-1];

  integer i;
  initial begin
    img_mounted  = 0;
    img_readonly = 0;
    img_size     = 0;
    sd_ack       = 0;
    sd_buff_addr = 0;
    sd_buff_dout = 0;
    sd_buff_wr   = 0;
    n_reads      = 0;
    n_writes     = 0;
    violations   = 0;
    for (i = 0; i < VDNUM; i = i + 1) begin
      size[i] = 0;
      ro[i]   = 0;
    end
  end

  // ---- mount / unmount, driven by the testbench --------------------------
  task mount(input integer slot, input [31:0] sz, input readonly);
    begin
      size[slot] = sz;
      ro[slot]   = readonly;
      @(posedge clk_sys);
      img_size <= {32'd0, sz};          // the size goes first (cmd 0x1d)
      repeat (3) @(posedge clk_sys);
      img_readonly      <= readonly;    // then the mount word (cmd 0x1c)
      img_mounted[slot] <= 1'b1;
      repeat (MOUNT_CYCLES) @(posedge clk_sys);
      img_mounted[slot] <= 1'b0;
      @(posedge clk_sys);
    end
  endtask

  task unmount(input integer slot);
    begin
      mount(slot, 32'd0, 1'b1);
    end
  endtask

  // ---- the poll + transaction loop ---------------------------------------
  reg [3:0]  rrb;
  integer    slot, w, nwords;
  reg [31:0] lba, lba_now;
  reg [5:0]  bcnt;
  reg        is_wr;
  reg [31:0] byte_base;
  reg [15:0] word;

  initial rrb = 0;

  always begin
    repeat (POLL_CYCLES) @(posedge clk_sys);
    // hps_io's pick: highest-priority-rotated slot with a request
    slot = -1;
    for (i = VDNUM - 1; i >= 0; i = i - 1) begin : pk
      integer nn;
      nn = i + rrb;
      if (nn >= VDNUM) nn = nn - VDNUM;
      if (sd_wr[nn] | sd_rd[nn]) slot = nn;
    end
    rrb = (rrb == VDNUM - 1) ? 0 : rrb + 1;

    if (slot >= 0) begin
      is_wr = sd_wr[slot];
      lba   = sd_lba[slot*32 +: 32];
      bcnt  = sd_blk_cnt[slot*6 +: 6];
      nwords = (bcnt + 1) * 256;
      byte_base = lba * 512;

      // the ARM takes a while to get around to the data phase
      repeat (POLL_CYCLES / 2) @(posedge clk_sys);

      // the request must still be there, unchanged
      if (!(is_wr ? sd_wr[slot] : sd_rd[slot])) begin
        $display("HPS MODEL: request on slot %0d dropped before ack - VIOLATION", slot);
        violations = violations + 1;
      end
      if (sd_lba[slot*32 +: 32] != lba) begin
        $display("HPS MODEL: sd_lba changed between poll and ack on slot %0d - VIOLATION", slot);
        violations = violations + 1;
      end

      sd_ack[slot] <= 1'b1;
      sd_buff_addr <= 13'd0;
      @(posedge clk_sys);

      if (!is_wr) begin
        n_reads = n_reads + 1;
        for (w = 0; w < nwords; w = w + 1) begin
          if ((size[slot] != 0) && (byte_base + 2*w + 1 < size[slot]) &&
              (byte_base + 2*w + 1 < IMG_BYTES))
            word = {img[slot*IMG_BYTES + byte_base + 2*w + 1],
                    img[slot*IMG_BYTES + byte_base + 2*w]};
          else
            word = 16'd0;                 // unmounted / past EOF: zeros
          sd_buff_dout <= word;
          sd_buff_wr   <= 1'b1;
          @(posedge clk_sys);
          sd_buff_wr   <= 1'b0;
          @(posedge clk_sys);
          @(posedge clk_sys);
          if (sd_buff_addr != 13'h1FFF) sd_buff_addr <= sd_buff_addr + 1'b1;
          repeat (WORD_CYCLES - 3) @(posedge clk_sys);
        end
      end else begin
        n_writes = n_writes + 1;
        for (w = 0; w < nwords; w = w + 1) begin
          repeat (WORD_CYCLES) @(posedge clk_sys);
          // the strobe: sample sd_buff_din, bump the address
          if ((size[slot] != 0) && (byte_base + 2*w + 1 < size[slot]) &&
              (byte_base + 2*w + 1 < IMG_BYTES)) begin
            img[slot*IMG_BYTES + byte_base + 2*w]     = sd_buff_din[7:0];
            img[slot*IMG_BYTES + byte_base + 2*w + 1] = sd_buff_din[15:8];
          end
          if (sd_buff_addr != 13'h1FFF) sd_buff_addr <= sd_buff_addr + 1'b1;
        end
      end

      // the request must have been dropped on the rising edge of ack
      if (is_wr ? sd_wr[slot] : sd_rd[slot]) begin
        $display("HPS MODEL: request on slot %0d still high at end of transfer - VIOLATION (would run twice)", slot);
        violations = violations + 1;
      end
      @(posedge clk_sys);
      sd_ack[slot] <= 1'b0;
      @(posedge clk_sys);
    end
  end

endmodule
