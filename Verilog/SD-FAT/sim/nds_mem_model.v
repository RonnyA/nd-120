/****************************************************************************
** Behavioral mem-port model for the nd_storage testbenches               **
**                                                                         **
** Implements the abstract mem port of docs/nd-storage-design.md          **
** section 5.2 (the contract the Tang MEM_RAM_49_SDRAM device port        **
** provides on hardware): start/we/addr/wdata are sampled at the start    **
** pulse, the op completes after a randomized 4..40 cycle latency         **
** (modelling the sync-into-clk2x + leftover-slot wait + 5-cycle op +     **
** sync-back round trip), rdata is valid at the done pulse and held.      **
**                                                                         **
** 1M x 32 array by default; MEM_WORDS can be shrunk for sim speed.       **
** Preload: set INIT_FILE for a $readmemh load at time 0, call the        **
** load_file task, or write mem[] hierarchically from the testbench       **
** (the array is also readable for end-of-test checking).                 **
**                                                                         **
** Simulation model only - never synthesized.                             **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module nds_mem_model #(
    parameter MEM_WORDS = 1048576,       // 1M x 32 = the 4 MB device region
    parameter LAT_MIN   = 4,             // ack latency range, cycles
    parameter LAT_MAX   = 40,
    parameter SEED      = 32'h0005_D00D,
    parameter INIT_FILE = ""             // optional $readmemh preload
) (
    input  wire        clk,       // clk_stor
    input  wire        rst_n,
    input  wire        start,     // 1-cycle pulse, only when busy=0
    input  wire        we,
    input  wire [19:0] addr,      // 32-bit-word address
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,     // valid at done, then held
    output wire        busy,
    output reg         done       // 1-cycle pulse
);

  localparam LAT_SPAN = LAT_MAX - LAT_MIN + 1;

  reg [31:0] mem [0:MEM_WORDS-1];

  integer seed;
  initial begin
    seed = SEED;
    if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
  end

  // testbench hook: load an image at any time
  task load_file(input reg [1023:0] fname);
    begin
      $readmemh(fname, mem);
    end
  endtask

  reg        s_busy;
  reg        s_we_l;
  reg [19:0] s_addr_l;
  reg [31:0] s_wdata_l;
  reg [7:0]  s_cnt;

  assign busy = s_busy;

  always @(posedge clk) begin
    if (!rst_n) begin
      s_busy    <= 1'b0;
      s_we_l    <= 1'b0;
      s_addr_l  <= 20'd0;
      s_wdata_l <= 32'd0;
      s_cnt     <= 8'd0;
      rdata     <= 32'd0;
      done      <= 1'b0;
    end else begin
      done <= 1'b0;
      if (!s_busy) begin
        if (start) begin
          s_busy    <= 1'b1;
          s_we_l    <= we;
          s_addr_l  <= addr;
          s_wdata_l <= wdata;
          s_cnt     <= LAT_MIN[7:0] + ({$random(seed)} % LAT_SPAN);
        end
      end else if (s_cnt > 8'd1) begin
        s_cnt <= s_cnt - 8'd1;
      end else begin
        // commit / fetch at the end of the latency window
        if (s_addr_l < MEM_WORDS) begin
          if (s_we_l) mem[s_addr_l] <= s_wdata_l;
          else rdata <= mem[s_addr_l];
        end else if (!s_we_l) begin
          rdata <= 32'hDEAD_BEEF;  // out-of-model read marker
        end
        done   <= 1'b1;
        s_busy <= 1'b0;
      end
    end
  end

endmodule
