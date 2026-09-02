/****************************************************************************
** vdrives_model - MiSTer2MEGA65's vdrives + QNICE firmware as a testbench **
**                 model                                                   **
**                                                                         **
** Full path: Verilog/fpga/mega65/sim/vdrives_model.v                      **
**                                                                         **
** The MEGA65 counterpart of fpga/mister/sim/hps_io_model.v: the same       **
** MiSTer sd_* block protocol, served here by the QNICE soft CPU's firmware **
** through the framework's vdrives.vhd (m2m/M2M/vhdl/vdrives.vhd, whose    **
** header rules 1-8 this model follows), at the signal level, so           **
** nd_storage_vdrives can be simulated in iverilog against the handshake   **
** it will meet on the board. It CHECKS the rules the core must obey:      **
**                                                                         **
**   - The firmware polls: a request (sd_rd/sd_wr bit) is noticed only     **
**     every POLL_CYCLES clk_qnice cycles; slot choice is round-robin.       **
**   - sd_lba / sd_blk_cnt are read after the poll, before ack; changing   **
**     them in between is a violation. The request must be dropped once    **
**     ack is up and must not still be there at the end (it would run       **
**     again) - both violations.                                            **
**   - sd_ack[slot] is a firmware register: one-hot, high for the whole     **
**     transaction.                                                          **
**   - The stream is BYTE wide, in file order. Read: for each byte the      **
**     firmware sets sd_buff_addr (a byte index 0..2047) and sd_buff_dout,  **
**     then writes sd_buff_wr = 1 and later 0 - so wr is HIGH FOR SEVERAL   **
**     CLOCKS (register writes are separate instructions), unlike hps_io's  **
**     one-cycle pulse. Write: the firmware sets sd_buff_addr and reads     **
**     sd_buff_din some clocks later.                                        **
**   - (sd_blk_cnt+1) * 512 bytes per transaction.                          **
**   - Unmounted slot: never requested by a correct core (vdrives.vhd rule  **
**     3 says the firmware warns); the model serves zeros and counts it.    **
**   - Mount: img_size and img_readonly are set BEFORE img_mounted[slot] is **
**     strobed for MOUNT_CYCLES (rule 2). Unmount = size 0.                  **
**                                                                         **
** Per-slot storage is a plain byte array (IMG_BYTES per slot).            **
**                                                                         **
** Ronny Hansen, 02-SEP-2026                                                **
*****************************************************************************/
`timescale 1ns / 1ps
module vdrives_model #(
    parameter integer VDNUM        = 5,
    parameter integer IMG_BYTES    = 65536,   // per slot
    parameter integer POLL_CYCLES  = 40,      // clk_qnice cycles between polls
    parameter integer BYTE_CYCLES  = 8,       // clk_qnice cycles per streamed byte (firmware pace)
    parameter integer MOUNT_CYCLES = 4
) (
    input  wire                clk_qnice,
    output reg  [VDNUM-1:0]    img_mounted,
    output reg                 img_readonly,
    output reg  [31:0]         img_size,
    input  wire [VDNUM*32-1:0] sd_lba,
    input  wire [VDNUM*6-1:0]  sd_blk_cnt,
    input  wire [VDNUM-1:0]    sd_rd,
    input  wire [VDNUM-1:0]    sd_wr,
    output reg  [VDNUM-1:0]    sd_ack,
    output reg  [13:0]         sd_buff_addr,
    output reg  [7:0]          sd_buff_dout,
    input  wire [7:0]          sd_buff_din,
    output reg                 sd_buff_wr,

    // bookkeeping for the testbench
    output integer n_reads,
    output integer n_writes,
    output integer violations,
    output integer unmounted_requests
);

  reg [7:0]  img[0:VDNUM*IMG_BYTES-1];
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
    unmounted_requests = 0;
    for (i = 0; i < VDNUM; i = i + 1) begin
      size[i] = 0;
      ro[i]   = 0;
    end
  end

  // ---- mount / unmount, driven by the testbench (vdrives.vhd rule 2) ------
  task mount(input integer slot, input [31:0] sz, input readonly);
    begin
      size[slot] = sz;
      ro[slot]   = readonly;
      @(posedge clk_qnice);
      img_size     <= sz;               // values first ...
      img_readonly <= readonly;
      repeat (3) @(posedge clk_qnice);
      img_mounted[slot] <= 1'b1;        // ... then the strobe
      repeat (MOUNT_CYCLES) @(posedge clk_qnice);
      img_mounted[slot] <= 1'b0;
      @(posedge clk_qnice);
    end
  endtask

  task unmount(input integer slot);
    begin
      mount(slot, 32'd0, 1'b1);
    end
  endtask

  // ---- the poll + transaction loop, the firmware's way -------------------
  reg [3:0]  rrb;
  integer    slot, b, nbytes;
  reg [31:0] lba;
  reg [5:0]  bcnt;
  reg        is_wr;
  reg [31:0] byte_base;

  initial rrb = 0;

  always begin
    repeat (POLL_CYCLES) @(posedge clk_qnice);
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
      nbytes = (bcnt + 1) * 512;
      byte_base = lba * 512;
      if (size[slot] == 0) unmounted_requests = unmounted_requests + 1;

      // the firmware takes a while to get around to the data phase
      repeat (POLL_CYCLES / 2) @(posedge clk_qnice);

      if (!(is_wr ? sd_wr[slot] : sd_rd[slot])) begin
        $display("VDRIVES MODEL: request on slot %0d dropped before ack - VIOLATION", slot);
        violations = violations + 1;
      end
      if (sd_lba[slot*32 +: 32] != lba) begin
        $display("VDRIVES MODEL: sd_lba changed between poll and ack on slot %0d - VIOLATION", slot);
        violations = violations + 1;
      end

      sd_ack[slot] <= 1'b1;
      repeat (3) @(posedge clk_qnice);

      if (!is_wr) begin
        n_reads = n_reads + 1;
        for (b = 0; b < nbytes; b = b + 1) begin
          // set address and data (two register writes), then wr=1, then wr=0
          sd_buff_addr <= b[13:0];
          @(posedge clk_qnice);
          if ((size[slot] != 0) && (byte_base + b < size[slot]) && (byte_base + b < IMG_BYTES))
            sd_buff_dout <= img[slot*IMG_BYTES + byte_base + b];
          else
            sd_buff_dout <= 8'd0;          // unmounted / past EOF: zeros
          @(posedge clk_qnice);
          sd_buff_wr <= 1'b1;
          repeat (3) @(posedge clk_qnice);   // held: separate instructions
          sd_buff_wr <= 1'b0;
          repeat (BYTE_CYCLES - 5) @(posedge clk_qnice);
        end
      end else begin
        n_writes = n_writes + 1;
        for (b = 0; b < nbytes; b = b + 1) begin
          sd_buff_addr <= b[13:0];
          repeat (BYTE_CYCLES - 1) @(posedge clk_qnice);
          // the MMIO read of sd_buff_din, several clocks after the address
          if ((size[slot] != 0) && (byte_base + b < size[slot]) && (byte_base + b < IMG_BYTES))
            img[slot*IMG_BYTES + byte_base + b] = sd_buff_din;
          @(posedge clk_qnice);
        end
      end

      if (is_wr ? sd_wr[slot] : sd_rd[slot]) begin
        $display("VDRIVES MODEL: request on slot %0d still high at end of transfer - VIOLATION (would run twice)", slot);
        violations = violations + 1;
      end
      @(posedge clk_qnice);
      sd_ack[slot] <= 1'b0;
      @(posedge clk_qnice);
    end
  end

endmodule
