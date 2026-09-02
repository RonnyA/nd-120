/*****************************************************************************
**  nd_avalon_port_tb.v                                                     **
**                                                                          **
**  Full path: Verilog/fpga/mega65/sim/nd_avalon_port_tb.v                  **
**                                                                          **
**  nd_avalon_port (the R3 HyperRAM backend behind the Nexys cache seam)    **
**  against an Avalon-MM slave model that behaves like a memory with a mind **
**  of its own: waitrequest for a random 0..4 clocks per command, read data  **
**  after a random 2..24 clocks, bursts answered word by word. The model     **
**  also CHECKS the Avalon rules the port must obey - signals held while     **
**  waitrequest is high, never read and write together, never an address    **
**  outside the core's window, burstcount 1 only when told it cannot burst. **
**                                                                          **
**  Two DUTs: the default (8-beat burst reads) and the single-beat fallback  **
**  (G_BURST = 0) on a slave that refuses bursts. Both must pass the same    **
**  checks:                                                                  **
**   (1) a line write with one word enabled writes exactly that word, with  **
**       byteenable 11, and touches nothing else;                           **
**   (2) a line write with two words enabled is two single-beat writes;     **
**   (3) a fully masked write moves nothing and still answers;              **
**   (4) a byte-masked write (one byte of a word) uses byteenable 01/10;    **
**   (5) a line read returns the 8 words low word first;                    **
**   (6) 300 random ops against a reference array, back to back, one        **
**       outstanding, rsp_valid exactly once per op.                        **
**                                                                          **
**  Verdict: TB_RESULT: PASS / TB_RESULT: FAIL                              **
*****************************************************************************/

`timescale 1ns / 1ps
`default_nettype none

//----------------------------------------------------------------------------
// The slave model
//----------------------------------------------------------------------------
module avalon_slave_model #(
    parameter [31:0]  BASE     = 32'h0020_0000,
    parameter integer WORDS    = 2*1024*1024,
    parameter integer CAN_BURST = 1
) (
    input  wire        clk,
    input  wire        write,
    input  wire        read,
    input  wire [31:0] address,
    input  wire [15:0] writedata,
    input  wire [1:0]  byteenable,
    input  wire [7:0]  burstcount,
    output reg  [15:0] readdata,
    output reg         readdatavalid,
    output reg         waitrequest,
    output integer     violations,
    output integer     n_writes,
    output integer     n_read_cmds
);
  reg [15:0] mem[0:WORDS-1];

  // random waitrequest: stays high 0..4 clocks after a command appears
  integer hold;
  initial begin
    waitrequest = 1'b1; readdata = 0; readdatavalid = 0; violations = 0; n_writes = 0; n_read_cmds = 0;
    hold = 0;
  end

  // pending read burst
  integer rd_pending;      // words still to deliver
  integer rd_addr;
  integer rd_delay;
  initial begin rd_pending = 0; rd_addr = 0; rd_delay = 0; end

  // stability check: snapshot while waiting
  reg        w_d, r_d; reg [31:0] a_d; reg [15:0] wd_d; reg [1:0] be_d; reg [7:0] bc_d; reg wait_d;
  initial begin w_d = 0; r_d = 0; wait_d = 1; end

  always @(posedge clk) begin
    // rules
    if (write && read) begin
      $display("AVALON MODEL: read and write asserted together - VIOLATION"); violations = violations + 1;
    end
    if (wait_d && (w_d || r_d) && (write || read)) begin
      if (w_d != write || r_d != read || a_d != address || (w_d && (wd_d != writedata || be_d != byteenable)) || bc_d != burstcount) begin
        $display("AVALON MODEL: command changed while waitrequest was high - VIOLATION"); violations = violations + 1;
      end
    end
    if ((write || read) && ((address < BASE) || (address + burstcount > BASE + WORDS))) begin
      $display("AVALON MODEL: address %08x (burst %0d) outside the window - VIOLATION", address, burstcount); violations = violations + 1;
    end
    if ((write || read) && (CAN_BURST == 0) && (burstcount != 8'd1)) begin
      $display("AVALON MODEL: burstcount %0d on a slave that cannot burst - VIOLATION", burstcount); violations = violations + 1;
    end
    if (write && burstcount != 8'd1) begin
      $display("AVALON MODEL: burst write (%0d) - not expected from this port - VIOLATION", burstcount); violations = violations + 1;
    end
    w_d <= write; r_d <= read; a_d <= address; wd_d <= writedata; be_d <= byteenable; bc_d <= burstcount;
    wait_d <= waitrequest;

    // waitrequest behaviour
    if (write || read) begin
      if (waitrequest) begin
        if (hold == 0) hold = $urandom % 5;
        if (hold == 0) waitrequest <= 1'b0;
        else hold = hold - 1;
        if (hold == 0 && waitrequest) ; // will drop next edge
      end else begin
        // accepted this cycle
        if (write) begin
          n_writes = n_writes + 1;
          if (byteenable[0]) mem[address - BASE][7:0]  = writedata[7:0];
          if (byteenable[1]) mem[address - BASE][15:8] = writedata[15:8];
        end else begin
          n_read_cmds = n_read_cmds + 1;
          if (rd_pending != 0) begin
            $display("AVALON MODEL: new read while a burst is still being delivered - the port should not do that"); violations = violations + 1;
          end
          rd_pending = burstcount;
          rd_addr    = address - BASE;
          rd_delay   = 2 + ($urandom % 23);
        end
        waitrequest <= 1'b1;   // next command waits again
        hold = 0;
      end
    end else begin
      waitrequest <= 1'b1;
      hold = 0;
    end

    // read data delivery
    readdatavalid <= 1'b0;
    if (rd_pending != 0) begin
      if (rd_delay != 0) rd_delay = rd_delay - 1;
      else begin
        readdata      <= mem[rd_addr];
        readdatavalid <= 1'b1;
        rd_addr       = rd_addr + 1;
        rd_pending    = rd_pending - 1;
        if (($urandom % 3) == 0) rd_delay = 1 + ($urandom % 3);  // gaps inside a burst
      end
    end
  end
endmodule

//----------------------------------------------------------------------------
// The bench
//----------------------------------------------------------------------------
module nd_avalon_port_tb;

  localparam [31:0] BASE = 32'h0020_0000;

  reg clk = 0;
  always #5 clk = ~clk;   // 100 MHz
  reg rst = 1;

  integer errors = 0;

  // two DUT/model pairs
  reg          req_valid[0:1];
  reg          req_we[0:1];
  reg  [26:0]  req_addr[0:1];
  reg  [127:0] req_wdata[0:1];
  reg  [15:0]  req_wmask[0:1];
  wire         req_ready[0:1];
  wire         rsp_valid[0:1];
  wire [127:0] rsp_rdata[0:1];
  wire         avm_write[0:1], avm_read[0:1], avm_rdv[0:1], avm_wait[0:1];
  wire [31:0]  avm_addr[0:1];
  wire [15:0]  avm_wdata[0:1], avm_rdata[0:1];
  wire [1:0]   avm_be[0:1];
  wire [7:0]   avm_bc[0:1];
  integer      violations[0:1], n_writes[0:1], n_read_cmds[0:1];

  genvar gi;
  generate
    for (gi = 0; gi < 2; gi = gi + 1) begin : g
      nd_avalon_port #(.BASE_WORDS(BASE), .G_BURST(gi == 0 ? 1 : 0)) dut (
          .clk(clk), .rst(rst),
          .req_valid(req_valid[gi]), .req_we(req_we[gi]), .req_addr(req_addr[gi]),
          .req_wdata(req_wdata[gi]), .req_wmask(req_wmask[gi]), .req_ready(req_ready[gi]),
          .rsp_valid(rsp_valid[gi]), .rsp_rdata(rsp_rdata[gi]),
          .avm_write(avm_write[gi]), .avm_read(avm_read[gi]), .avm_address(avm_addr[gi]),
          .avm_writedata(avm_wdata[gi]), .avm_byteenable(avm_be[gi]), .avm_burstcount(avm_bc[gi]),
          .avm_readdata(avm_rdata[gi]), .avm_readdatavalid(avm_rdv[gi]), .avm_waitrequest(avm_wait[gi])
      );
      avalon_slave_model #(.BASE(BASE), .CAN_BURST(gi == 0 ? 1 : 0)) slave (
          .clk(clk),
          .write(avm_write[gi]), .read(avm_read[gi]), .address(avm_addr[gi]),
          .writedata(avm_wdata[gi]), .byteenable(avm_be[gi]), .burstcount(avm_bc[gi]),
          .readdata(avm_rdata[gi]), .readdatavalid(avm_rdv[gi]), .waitrequest(avm_wait[gi]),
          .violations(violations[gi]), .n_writes(n_writes[gi]), .n_read_cmds(n_read_cmds[gi])
      );
    end
  endgenerate

  // count rsp_valid pulses per DUT
  integer rsp_count[0:1];
  always @(posedge clk) begin
    if (rsp_valid[0]) rsp_count[0] = rsp_count[0] + 1;
    if (rsp_valid[1]) rsp_count[1] = rsp_count[1] + 1;
  end

  task check(input cond, input [1023:0] what);
    begin
      if (!cond) begin errors = errors + 1; $display("  FAIL: %0s", what); end
    end
  endtask

  // one op on DUT d, wait for its response (rsp captured into last_rdata)
  reg [127:0] last_rdata;
  integer     cyc;
  task op(input integer d, input we, input [26:0] addr, input [127:0] wdata, input [15:0] wmask);
    begin
      @(posedge clk);
      req_valid[d] <= 1'b1; req_we[d] <= we; req_addr[d] <= addr; req_wdata[d] <= wdata; req_wmask[d] <= wmask;
      @(posedge clk);
      while (!req_ready[d]) @(posedge clk);   // accepted when ready was high at a posedge with valid high
      req_valid[d] <= 1'b0;
      cyc = 0;
      while (!rsp_valid[d] && cyc < 5000) begin @(posedge clk); cyc = cyc + 1; end
      check(rsp_valid[d], "rsp_valid never came");
      last_rdata = rsp_rdata[d];
      @(posedge clk);
    end
  endtask

  // reference memory for the random test
  reg [15:0] refm[0:8191];   // words 0..8191 of the window
  integer i, d, k, w;
  reg [127:0] wd; reg [15:0] wm; reg [26:0] ad; reg we;
  integer bad, base_w, base_r;

  initial begin
    for (d = 0; d < 2; d = d + 1) begin
      req_valid[d] = 0; req_we[d] = 0; req_addr[d] = 0; req_wdata[d] = 0; req_wmask[d] = 16'hFFFF; rsp_count[d] = 0;
    end
    for (i = 0; i < 8192; i = i + 1) begin refm[i] = 16'h0000; g[0].slave.mem[i] = 16'h0000; g[1].slave.mem[i] = 16'h0000; end
    repeat (3) @(posedge clk);
    rst = 0;
    repeat (3) @(posedge clk);

    for (d = 0; d < 2; d = d + 1) begin
      $display("=== DUT %0d (%0s) ===", d, d == 0 ? "burst reads" : "single-beat fallback");

      // (1) one word enabled
      $display("(1) line write, word 3 only");
      base_w = (d == 0) ? g[0].slave.n_writes : g[1].slave.n_writes;
      wd = {8{16'h1111}}; wd[63:48] = 16'hBEEF;
      op(d, 1'b1, 27'd16, wd, 16'hFFFF & ~(16'h0003 << 6));   // units 16..23 = words 16..23, word 3 => unit 19
      check(((d == 0) ? g[0].slave.n_writes : g[1].slave.n_writes) - base_w == 1, "exactly one Avalon write");
      check(((d == 0) ? g[0].slave.mem[19] : g[1].slave.mem[19]) == 16'hBEEF, "word 19 written");
      check(((d == 0) ? g[0].slave.mem[18] : g[1].slave.mem[18]) == 16'h0000 &&
            ((d == 0) ? g[0].slave.mem[20] : g[1].slave.mem[20]) == 16'h0000, "neighbours untouched");

      // (2) two words enabled
      $display("(2) line write, words 0 and 7");
      base_w = (d == 0) ? g[0].slave.n_writes : g[1].slave.n_writes;
      wd = 128'd0; wd[15:0] = 16'hA0A0; wd[127:112] = 16'h7777;
      op(d, 1'b1, 27'd32, wd, 16'hFFFF & ~16'h0003 & ~16'hC000);
      check(((d == 0) ? g[0].slave.n_writes : g[1].slave.n_writes) - base_w == 2, "exactly two Avalon writes");
      check(((d == 0) ? g[0].slave.mem[32] : g[1].slave.mem[32]) == 16'hA0A0 &&
            ((d == 0) ? g[0].slave.mem[39] : g[1].slave.mem[39]) == 16'h7777, "both words written");

      // (3) nothing enabled
      $display("(3) fully masked write");
      base_w = (d == 0) ? g[0].slave.n_writes : g[1].slave.n_writes;
      op(d, 1'b1, 27'd48, {8{16'hDEAD}}, 16'hFFFF);
      check(((d == 0) ? g[0].slave.n_writes : g[1].slave.n_writes) - base_w == 0, "no Avalon traffic");
      check(((d == 0) ? g[0].slave.mem[48] : g[1].slave.mem[48]) == 16'h0000, "memory untouched");

      // (4) one byte of one word
      $display("(4) byte-masked write");
      if (d == 0) g[0].slave.mem[64+2] = 16'h1234; else g[1].slave.mem[64+2] = 16'h1234;
      wd = 128'd0; wd[47:32] = 16'hAB55;
      op(d, 1'b1, 27'd64, wd, 16'hFFFF & ~(16'h0002 << 4));   // word 2, high byte only (mask bit 5)
      check(((d == 0) ? g[0].slave.mem[66] : g[1].slave.mem[66]) == 16'hAB34, "only the high byte changed");

      // (5) line read
      $display("(5) line read");
      for (k = 0; k < 8; k = k + 1) if (d == 0) g[0].slave.mem[80+k] = 16'h0100 * k + 16'h0055; else g[1].slave.mem[80+k] = 16'h0100 * k + 16'h0055;
      base_r = (d == 0) ? g[0].slave.n_read_cmds : g[1].slave.n_read_cmds;
      op(d, 1'b0, 27'd80, 128'd0, 16'h0000);
      bad = 0;
      for (k = 0; k < 8; k = k + 1) if (last_rdata[k*16 +: 16] != 16'h0100 * k + 16'h0055) bad = bad + 1;
      check(bad == 0, "8 words, low word first");
      if (bad) $display("  got %032x", last_rdata);
      check(((d == 0) ? g[0].slave.n_read_cmds : g[1].slave.n_read_cmds) - base_r == (d == 0 ? 1 : 8), "one burst / eight singles");

      // (6) random ops vs reference
      $display("(6) 300 random ops vs a reference array");
      for (i = 0; i < 8192; i = i + 1) begin refm[i] = 16'h0000; if (d == 0) g[0].slave.mem[i] = 16'h0000; else g[1].slave.mem[i] = 16'h0000; end
      rsp_count[d] = 0;
      for (i = 0; i < 300; i = i + 1) begin
        we = $urandom % 2;
        ad = ($urandom % 1024) * 8;           // lines within words 0..8191
        wd = {$urandom, $urandom, $urandom, $urandom};
        wm = 16'hFFFF;
        if (we) begin
          // the cache's shape: one word enabled, sometimes two, sometimes a single byte
          k = $urandom % 8;
          wm = wm & ~(16'h0003 << (k*2));
          if (($urandom % 4) == 0) begin w = $urandom % 8; wm = wm & ~(16'h0003 << (w*2)); end
          if (($urandom % 5) == 0) wm = wm | (16'h0001 << (k*2));   // drop the low byte of word k
          for (w = 0; w < 8; w = w + 1) begin
            if (!wm[w*2])   refm[ad + w][7:0]  = wd[w*16 +: 8];
            if (!wm[w*2+1]) refm[ad + w][15:8] = wd[w*16+8 +: 8];
          end
          op(d, 1'b1, ad, wd, wm);
        end else begin
          op(d, 1'b0, ad, 128'd0, 16'h0000);
          bad = 0;
          for (w = 0; w < 8; w = w + 1) if (last_rdata[w*16 +: 16] != refm[ad + w]) bad = bad + 1;
          if (bad) begin errors = errors + 1; $display("  FAIL: random read at %0d mismatched (%0d words)", ad, bad); end
        end
      end
      check(rsp_count[d] == 300, "exactly one rsp_valid per op");
      bad = 0;
      for (i = 0; i < 8192; i = i + 1) if (((d == 0) ? g[0].slave.mem[i] : g[1].slave.mem[i]) != refm[i]) bad = bad + 1;
      check(bad == 0, "slave memory equals the reference after 300 ops");
      check(((d == 0) ? g[0].slave.violations : g[1].slave.violations) == 0, "Avalon rules violated (see AVALON MODEL lines)");
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d)", errors);
    $finish;
  end

  initial begin
    #50_000_000;
    $display("TB_RESULT: FAIL (watchdog)");
    $finish;
  end

endmodule

`default_nettype wire
