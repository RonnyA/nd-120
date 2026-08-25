/****************************************************************************
** nd_storage_disc_adapter - unit testbench (read-modify-write, reason     **
** codes, and the CHS->LBA map on BOTH served geometries)                  **
**                                                                         **
** Full path:                                                              **
**   Verilog/SD-FAT/sim/nd_storage_disc_adapter_unit_tb.v                  **
**                                                                         **
** WHY THIS EXISTS ALONGSIDE nd_storage_smd_adapter_tb.v                   **
**   That older bench (module nd_storage_disc_adapter_tb, Makefile target  **
**   test-nds-smdadapter) is parked RED and is not in the global registry. **
**   It also predates two changes to the module: the partial-write         **
**   read-modify-write path, and the per-refusal reason code. This bench   **
**   is the small, green, registrable unit bench and deliberately puts its **
**   weight where the old one has nothing. It shares no code with it and   **
**   uses a different module name so both can live in the directory.       **
**                                                                         **
** WHAT IS VERIFIED (all read from the RTL, nothing assumed)               **
**   1. CHS -> LBA -> word position, on BOTH geometries this one adapter   **
**      serves: the SMD 75 MB unit (GEO_HEADS=5, GEO_SPT=18) and the       **
**      Winchester Micropolis 1325 (GEO_HEADS=8, GEO_SPT=9).               **
**        LBA        = (cylinder * GEO_HEADS + head) * GEO_SPT + sector    **
**        word base  = LBA * 512      (1024-byte sector = 512 words)       **
**        c_block    = base[25:10],  block offset = base[9:0]              **
**      Checked as the c_block value actually requested AND as the words   **
**      actually delivered, for base 0, a head/sector maximum, and a high  **
**      cylinder near the top of the platter. A mapping error here reads   **
**      the wrong part of the image and raises no error at all.            **
**   2. READ-MODIFY-WRITE of a partial block - the case that silently      **
**      corrupts data if the staging arithmetic (s_mrg_idx / s_wr_dbuf)    **
**      is wrong. Both halves are covered: 512 words at block offset 0,    **
**      and 512 words at block offset 512. The WHOLE 1024-word block is    **
**      compared word for word against a shadow the testbench keeps, so    **
**      the untouched half must survive byte-exact and the guest's half    **
**      must land in the right place, in the right order.                  **
**   3. Reason codes (nd_storage_status.vh), one per refusal shape:        **
**        c_open_ok=0                        -> NDS_ERR_NOTOPEN            **
**        chunk end past c_size_bytes        -> NDS_ERR_RANGE              **
**        word position at/above 2^26        -> NDS_ERR_RANGE              **
**        multi-block chunk, partial first   -> NDS_ERR_WRALIGN            **
**      Every refusal must still pulse disk_done (never a wedge) and must  **
**      issue ZERO client traffic. The exact-fit boundary (chunk ending    **
**      exactly at c_size_bytes) must be ACCEPTED - one word more refused. **
**   4. Unit filtering: with disk_unit != UNIT the instance does nothing   **
**      and every output is parked at 0 - not z, per the repo rule - so    **
**      per-unit instances can OR their pins together.                     **
**   5. Aligned full-block write (identity address mapping), block-        **
**      spanning read (two client requests in ascending block order),      **
**      wordcount 0 (clean completion, no traffic), c_err pass-through on  **
**      the merge read and on the commit write with the adapter still      **
**      accepting work afterwards, open_start -> c_open_req, and the       **
**      c_busy back-pressure path in S_CREQ.                               **
**   6. CHARACTERISATION - position advance after a PARTIAL write. See     **
**      the T13 comment: the RTL advances by a WHOLE BLOCK. Recorded as    **
**      observed behaviour, reported as a suspected defect, not "fixed".   **
**                                                                         **
** REFERENCE MODEL - where the expected values come from                   **
**   Not from a datasheet and not from how a disk backend "usually" works. **
**   The two models in this file are transcriptions of the port contracts  **
**   documented in the RTL header and visible in its logic:                **
**     nds_dbufmdl   - the device buffer: 1024 x 16 with a REGISTERED      **
**                     read, dbuf_rdata valid one cycle after dbuf_addr    **
**                     (RTL: "registered readout in ND_SMD"). The write    **
**                     pull is therefore address / wait / sample.          **
**     nds_climdl    - the nd_storage client port: c_req is a 1-cycle      **
**                     pulse taken only while !c_busy; a read streams all  **
**                     1024 block words in order on c_buf_we/c_buf_addr/   **
**                     c_buf_wdata and then pulses c_done; a write walks   **
**                     c_buf_addr 0..1023 and samples c_buf_rdata.         **
**   Expected READ data is the client model's own image memory, and        **
**   expected WRITE data is what the testbench itself placed in the device **
**   buffer plus a shadow of the block taken before the operation - so     **
**   nothing is compared against the DUT's own internal state.             **
**                                                                         **
**   The client image is 256 blocks and a block number is folded modulo    **
**   256 into it (a 75 MB image would be 36k blocks). The fold is applied  **
**   identically on both sides of every comparison; the block NUMBER the   **
**   adapter asks for is checked separately and unfolded, so the mapping   **
**   test is not weakened by it.                                           **
**                                                                         **
** TEST PLAN                                                               **
**   T1  open_start -> c_open_req (pulsed and held)                        **
**   T2  unit mismatch: both instances silent, all outputs 0               **
**   T3  NOTOPEN, zero client traffic                                      **
**   T4  RANGE: exact fit accepted, one word past refused                  **
**   T5  RANGE: position at/above 2^26 words, and base overflow            **
**   T6  WRALIGN: multi-block chunk whose first block is partial           **
**   T7  wordcount 0: clean completion, zero traffic                       **
**   T8  READ one block: window forwarded, buffer outside it untouched     **
**   T9  READ spanning two blocks: two requests, ascending, data end to end**
**   T10 WRITE full aligned block: identity mapping                        **
**   T11 RMW partial write at block offset 0   (whole block compared)      **
**   T12 RMW partial write at block offset 512 (whole block compared)      **
**   T13 chunk chaining, and the partial-write position advance            **
**   T14 c_err on the merge read / on the commit write, then retry works   **
**   T15 c_busy back-pressure in S_CREQ                                    **
**   T16 disk_start coincident with disk_req uses the FRESH base           **
**   T17 Winchester geometry (8/9): mapping + data + one RMW write         **
**   Continuous: no x/z on any adapter output from reset release onward.   **
**                                                                         **
** HOW TO RUN                                                              **
**   cd Verilog/SD-FAT/sim && make test-nds-discadapter                    **
**   or:                                                                   **
**   iverilog -g2012 -I../circuit -o nd_storage_disc_adapter_unit_tb.vvp \ **
**       ../circuit/nd_storage_disc_adapter.v \                            **
**       nd_storage_disc_adapter_unit_tb.v                                 **
**   vvp -N nd_storage_disc_adapter_unit_tb.vvp                            **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none
`include "nd_storage_status.vh"

// ---------------------------------------------------------------------------
// Device buffer model: 1024 x 16, REGISTERED read (the ND_SMD sync-read
// BSRAM). rdata is valid one cycle after addr, which is what makes the
// adapter's write pull an address / wait / sample sequence.
// ---------------------------------------------------------------------------
module nds_dbufmdl (
    input  wire        clk,
    input  wire [ 9:0] addr,
    input  wire [15:0] wdata,
    input  wire        we,
    output reg  [15:0] rdata
);
  reg [15:0] mem[0:1023];
  integer i;
  initial begin
    for (i = 0; i < 1024; i = i + 1) mem[i] = 16'h0000;
    rdata = 16'h0000;
  end
  // read-before-write at the same address; the adapter never reads and
  // writes the buffer in the same cycle, so the choice cannot matter here
  always @(posedge clk) begin
    rdata <= mem[addr];
    if (we) mem[addr] <= wdata;
  end
endmodule

// ---------------------------------------------------------------------------
// nd_storage client-port model. One block = 1024 words = 2048 bytes.
//   read  : stream all 1024 words in order on buf_we/buf_addr/buf_wdata
//   write : walk buf_addr 0..1023, sample buf_rdata two cycles later
// err injection: raise arm_err (level). Its RISING edge loads arm_skip,
// the number of accepted operations to let through cleanly before failing.
// ---------------------------------------------------------------------------
module nds_climdl #(
    parameter integer NBLK = 256
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        req,
    input  wire        wr,
    input  wire [15:0] block,
    output wire        busy,
    output reg         done,
    output reg         err,
    output reg  [ 3:0] err_code,
    output reg  [ 9:0] buf_addr,
    output reg  [15:0] buf_wdata,
    output reg         buf_we,
    input  wire [15:0] buf_rdata,
    // testbench controls / observation
    input  wire        force_busy,
    input  wire        arm_err,
    input  wire [ 3:0] arm_code,
    input  wire [ 7:0] arm_skip,
    output reg  [15:0] ops
);
  reg [15:0] img[0:NBLK*1024-1];

  localparam [2:0] C_IDLE = 3'd0, C_LAT = 3'd1, C_RD = 3'd2, C_GAP = 3'd3,
                   C_WA = 3'd4, C_WW = 3'd5, C_WS = 3'd6, C_FIN = 3'd7;

  reg  [ 2:0] st;
  reg         m_busy, m_wr, m_fail, arm_q;
  reg  [ 7:0] skipc;
  reg  [15:0] blk;
  reg  [10:0] idx;
  reg  [ 2:0] lat;
  reg  [17:0] base;

  assign busy = m_busy | force_busy;

  integer k;
  initial begin
    for (k = 0; k < NBLK * 1024; k = k + 1) img[k] = 16'h0000;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= C_IDLE; m_busy <= 1'b0; m_wr <= 1'b0; m_fail <= 1'b0;
      done <= 1'b0; err <= 1'b0; err_code <= `NDS_ERR_NONE;
      buf_addr <= 10'd0; buf_wdata <= 16'd0; buf_we <= 1'b0;
      blk <= 16'd0; idx <= 11'd0; lat <= 3'd0; base <= 18'd0;
      ops <= 16'd0; skipc <= 8'd0; arm_q <= 1'b0;
    end else begin
      done   <= 1'b0;
      err    <= 1'b0;
      buf_we <= 1'b0;
      arm_q  <= arm_err;
      if (arm_err && !arm_q) skipc <= arm_skip;  // rising edge arms

      case (st)
        C_IDLE:
        if (req) begin
          m_wr   <= wr;
          blk    <= block;
          base   <= {block[7:0], 10'd0};
          idx    <= 11'd0;
          lat    <= 3'd3;
          m_busy <= 1'b1;
          if (arm_err && skipc == 8'd0) m_fail <= 1'b1;
          else begin
            m_fail <= 1'b0;
            if (arm_err) skipc <= skipc - 8'd1;
          end
          st <= C_LAT;
        end

        C_LAT:
        if (lat != 3'd0) lat <= lat - 3'd1;
        else if (m_fail) st <= C_FIN;
        else st <= m_wr ? C_WA : C_RD;

        C_RD: begin  // stream the whole block, one word per cycle
          buf_we    <= 1'b1;
          buf_addr  <= idx[9:0];
          buf_wdata <= img[base + {7'd0, idx}];
          if (idx == 11'd1023) begin
            idx <= 11'd0;
            lat <= 3'd2;
            st  <= C_GAP;
          end else idx <= idx + 11'd1;
        end

        C_GAP:  // let the adapter's registered buffer write land
        if (lat != 3'd0) lat <= lat - 3'd1;
        else st <= C_FIN;

        C_WA: begin  // address
          buf_addr <= idx[9:0];
          st <= C_WW;
        end

        C_WW: st <= C_WS;  // wait: the device buffer read is registered

        C_WS: begin  // sample
          img[base + {7'd0, idx}] <= buf_rdata;
          if (idx == 11'd1023) begin
            idx <= 11'd0;
            st  <= C_FIN;
          end else begin
            idx <= idx + 11'd1;
            st  <= C_WA;
          end
        end

        C_FIN: begin
          done     <= 1'b1;
          err      <= m_fail;
          err_code <= m_fail ? arm_code : `NDS_ERR_NONE;
          m_busy   <= 1'b0;
          ops      <= ops + 16'd1;
          st       <= C_IDLE;
        end

        default: st <= C_IDLE;
      endcase
    end
  end
endmodule

// ---------------------------------------------------------------------------
module nd_storage_disc_adapter_unit_tb;

  // -------------------------------------------------------------- clock/reset
  reg clk = 1'b0;
  always #5 clk = ~clk;  // 100 MHz
  reg rst_n = 1'b0;

  integer checks = 0;
  integer errors = 0;

  task chk(input cond, input [8*72-1:0] what);
    begin
      checks = checks + 1;
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL @%0t: %0s", $time, what);
      end
    end
  endtask

  // -------------------------------------------------------------- shared pins
  reg        disk_start = 1'b0;
  reg        disk_req = 1'b0;
  reg        disk_wr = 1'b0;
  reg [15:0] blkaddr1 = 16'd0;   // head b15-8, sector b7-0
  reg [15:0] blkaddr2 = 16'd0;   // cylinder
  reg [ 2:0] disk_unit = 3'd7;
  reg [10:0] wordcount = 11'd0;

  // ---- instance A: SMD 75 MB geometry, unit 3 -------------------------------
  reg         a_open_start = 1'b0, a_open_ok = 1'b1, a_open_err = 1'b0;
  reg  [31:0] a_size = 32'hFFFF_0000;
  reg         a_force_busy = 1'b0, a_arm_err = 1'b0;
  reg  [ 3:0] a_arm_code = `NDS_ERR_NONE;
  reg  [ 7:0] a_arm_skip = 8'd0;

  wire        a_done, a_err, a_bufwe, a_openreq, a_creq, a_cwr, a_cbufwe;
  wire        a_cbusy, a_cdone, a_cerr;
  wire [ 3:0] a_code, a_cerrcode;
  wire [ 9:0] a_bufaddr, a_cbufaddr;
  wire [15:0] a_bufwdata, a_bufrdata, a_cblock, a_cbufwdata, a_cbufrdata;
  wire [15:0] a_ops;

  nd_storage_disc_adapter #(
      .UNIT(3'd3), .GEO_HEADS(16'd5), .GEO_SPT(16'd18)
  ) DUT_A (
      .clk_cpu(clk), .rst_n(rst_n),
      .disk_start(disk_start), .disk_req(disk_req), .disk_wr(disk_wr),
      .disk_blkaddr1(blkaddr1), .disk_blkaddr2(blkaddr2),
      .disk_unit(disk_unit), .disk_wordcount(wordcount),
      .disk_done(a_done), .disk_err(a_err), .disk_err_code(a_code),
      .dbuf_addr(a_bufaddr), .dbuf_wdata(a_bufwdata), .dbuf_we(a_bufwe),
      .dbuf_rdata(a_bufrdata),
      .open_start(a_open_start),
      .c_open_req(a_openreq), .c_open_ok(a_open_ok), .c_open_err(a_open_err),
      .c_size_bytes(a_size),
      .c_req(a_creq), .c_wr(a_cwr), .c_block(a_cblock),
      .c_busy(a_cbusy), .c_done(a_cdone), .c_err(a_cerr),
      .c_err_code(a_cerrcode),
      .c_buf_addr(a_cbufaddr), .c_buf_wdata(a_cbufwdata), .c_buf_we(a_cbufwe),
      .c_buf_rdata(a_cbufrdata)
  );

  nds_dbufmdl BUF_A (
      .clk(clk), .addr(a_bufaddr), .wdata(a_bufwdata), .we(a_bufwe),
      .rdata(a_bufrdata)
  );

  nds_climdl CLI_A (
      .clk(clk), .rst_n(rst_n),
      .req(a_creq), .wr(a_cwr), .block(a_cblock),
      .busy(a_cbusy), .done(a_cdone), .err(a_cerr), .err_code(a_cerrcode),
      .buf_addr(a_cbufaddr), .buf_wdata(a_cbufwdata), .buf_we(a_cbufwe),
      .buf_rdata(a_cbufrdata),
      .force_busy(a_force_busy), .arm_err(a_arm_err), .arm_code(a_arm_code),
      .arm_skip(a_arm_skip), .ops(a_ops)
  );

  // ---- instance B: Winchester Micropolis 1325 geometry, unit 0 --------------
  reg         b_open_start = 1'b0, b_open_ok = 1'b1, b_open_err = 1'b0;
  reg  [31:0] b_size = 32'hFFFF_0000;
  reg         b_force_busy = 1'b0, b_arm_err = 1'b0;
  reg  [ 3:0] b_arm_code = `NDS_ERR_NONE;
  reg  [ 7:0] b_arm_skip = 8'd0;

  wire        b_done, b_err, b_bufwe, b_openreq, b_creq, b_cwr, b_cbufwe;
  wire        b_cbusy, b_cdone, b_cerr;
  wire [ 3:0] b_code, b_cerrcode;
  wire [ 9:0] b_bufaddr, b_cbufaddr;
  wire [15:0] b_bufwdata, b_bufrdata, b_cblock, b_cbufwdata, b_cbufrdata;
  wire [15:0] b_ops;

  nd_storage_disc_adapter #(
      .UNIT(3'd0), .GEO_HEADS(16'd8), .GEO_SPT(16'd9)
  ) DUT_B (
      .clk_cpu(clk), .rst_n(rst_n),
      .disk_start(disk_start), .disk_req(disk_req), .disk_wr(disk_wr),
      .disk_blkaddr1(blkaddr1), .disk_blkaddr2(blkaddr2),
      .disk_unit(disk_unit), .disk_wordcount(wordcount),
      .disk_done(b_done), .disk_err(b_err), .disk_err_code(b_code),
      .dbuf_addr(b_bufaddr), .dbuf_wdata(b_bufwdata), .dbuf_we(b_bufwe),
      .dbuf_rdata(b_bufrdata),
      .open_start(b_open_start),
      .c_open_req(b_openreq), .c_open_ok(b_open_ok), .c_open_err(b_open_err),
      .c_size_bytes(b_size),
      .c_req(b_creq), .c_wr(b_cwr), .c_block(b_cblock),
      .c_busy(b_cbusy), .c_done(b_cdone), .c_err(b_cerr),
      .c_err_code(b_cerrcode),
      .c_buf_addr(b_cbufaddr), .c_buf_wdata(b_cbufwdata), .c_buf_we(b_cbufwe),
      .c_buf_rdata(b_cbufrdata)
  );

  nds_dbufmdl BUF_B (
      .clk(clk), .addr(b_bufaddr), .wdata(b_bufwdata), .we(b_bufwe),
      .rdata(b_bufrdata)
  );

  nds_climdl CLI_B (
      .clk(clk), .rst_n(rst_n),
      .req(b_creq), .wr(b_cwr), .block(b_cblock),
      .busy(b_cbusy), .done(b_cdone), .err(b_cerr), .err_code(b_cerrcode),
      .buf_addr(b_cbufaddr), .buf_wdata(b_cbufwdata), .buf_we(b_cbufwe),
      .buf_rdata(b_cbufrdata),
      .force_busy(b_force_busy), .arm_err(b_arm_err), .arm_code(b_arm_code),
      .arm_skip(b_arm_skip), .ops(b_ops)
  );

  // -------------------------------------------------- request log (per DUT)
  integer a_nreq, b_nreq;
  reg [15:0] a_blklog[0:7];
  reg        a_wrlog [0:7];
  reg [15:0] b_blklog[0:7];

  always @(posedge clk) begin
    if (!rst_n) begin
      a_nreq <= 0; b_nreq <= 0;
    end else begin
      if (a_creq) begin
        if (a_nreq < 8) begin a_blklog[a_nreq] = a_cblock; a_wrlog[a_nreq] = a_cwr; end
        a_nreq <= a_nreq + 1;
      end
      if (b_creq) begin
        if (b_nreq < 8) b_blklog[b_nreq] = b_cblock;
        b_nreq <= b_nreq + 1;
      end
    end
  end

  // -------------------------------------------------- no x/z on any output
  reg armed = 1'b0;
  always @(posedge clk) begin
    #1;
    if (armed) begin
      chk(^{a_done, a_err, a_code, a_bufaddr, a_bufwdata, a_bufwe,
            a_openreq, a_creq, a_cwr, a_cblock} !== 1'bx, "A output went x/z");
      chk(^{b_done, b_err, b_code, b_bufaddr, b_bufwdata, b_bufwe,
            b_openreq, b_creq, b_cwr, b_cblock} !== 1'bx, "B output went x/z");
    end
  end

  // -------------------------------------------------------------- watchdog
  initial begin
    #40_000_000;
    $display("checks=%0d failures=%0d", checks, errors + 1);
    $display("TB_RESULT: FAIL  (watchdog: testbench did not finish)");
    $finish;
  end

  // -------------------------------------------------------------- VCD
  initial begin
    $dumpfile("nd_storage_disc_adapter_unit_tb.vcd");
    $dumpvars(0, nd_storage_disc_adapter_unit_tb);
  end

  // -------------------------------------------------------------- helpers
  integer i, j;
  reg [15:0] shadow[0:1023];   // expected image block content
  reg [31:0] lba, base_w;
  reg [15:0] exp_blk;
  reg        cap_err;
  reg [ 3:0] cap_code;

  function [31:0] lba_of(input [31:0] cyl, input [31:0] hd, input [31:0] sc,
                         input [31:0] heads, input [31:0] spt);
    lba_of = (cyl * heads + hd) * spt + sc;
  endfunction

  function [17:0] cli_idx(input [15:0] blk, input [10:0] w);
    cli_idx = {blk[7:0], 10'd0} + {7'd0, w};
  endfunction

  task fill_image;   // deterministic, distinct per word
    begin
      for (i = 0; i < 256 * 1024; i = i + 1) begin
        CLI_A.img[i] = (i[15:0] ^ {i[7:0], i[15:8]}) + 16'h1234;
        CLI_B.img[i] = (i[15:0] ^ {i[9:2], i[15:8]}) + 16'h4321;
      end
    end
  endtask

  task poison_a;  // mark the whole device buffer so stray writes show up
    begin
      for (i = 0; i < 1024; i = i + 1) BUF_A.mem[i] = 16'hDEAD;
    end
  endtask

  task poison_b;
    begin
      for (i = 0; i < 1024; i = i + 1) BUF_B.mem[i] = 16'hDEAD;
    end
  endtask

  task do_req(input [2:0] unit, input do_start, input wrf,
              input [15:0] ba1, input [15:0] ba2, input [10:0] wc);
    begin
      @(negedge clk);
      a_nreq = 0; b_nreq = 0;
      disk_unit = unit; disk_wr = wrf; blkaddr1 = ba1; blkaddr2 = ba2;
      wordcount = wc; disk_start = do_start; disk_req = 1'b1;
      @(negedge clk);
      disk_start = 1'b0; disk_req = 1'b0;
    end
  endtask

  task wait_a(input integer maxc, input [8*72-1:0] what);
    integer k;
    begin
      k = 0;
      cap_err = 1'bx; cap_code = 4'hx;
      @(posedge clk); #1;
      while (!a_done && k < maxc) begin @(posedge clk); #1; k = k + 1; end
      chk(a_done === 1'b1, what);
      cap_err  = a_err;
      cap_code = a_code;
      @(posedge clk); #1;
      chk(a_done === 1'b0, "A disk_done longer than one cycle");
    end
  endtask

  task wait_b(input integer maxc, input [8*72-1:0] what);
    integer k;
    begin
      k = 0;
      cap_err = 1'bx; cap_code = 4'hx;
      @(posedge clk); #1;
      while (!b_done && k < maxc) begin @(posedge clk); #1; k = k + 1; end
      chk(b_done === 1'b1, what);
      cap_err  = b_err;
      cap_code = b_code;
      @(posedge clk); #1;
      chk(b_done === 1'b0, "B disk_done longer than one cycle");
    end
  endtask

  // -------------------------------------------------------------- stimulus
  integer wc_i;
  reg [15:0] blk0;

  initial begin
    fill_image;
    poison_a;
    poison_b;

    repeat (4) @(posedge clk);
    @(negedge clk) rst_n = 1'b1;
    repeat (2) @(posedge clk);
    armed = 1'b1;

    // ================================================================ T1
    // open_start -> c_open_req (registered, one cycle later)
    @(negedge clk) a_open_start = 1'b1;
    @(posedge clk); #1;
    chk(a_openreq === 1'b1, "T1 c_open_req did not follow open_start");
    @(negedge clk) a_open_start = 1'b0;
    @(posedge clk); #1;
    chk(a_openreq === 1'b0, "T1 c_open_req did not drop with open_start");
    // held for three cycles -> three cycles of c_open_req
    @(negedge clk) a_open_start = 1'b1;
    repeat (3) begin
      @(posedge clk); #1;
      chk(a_openreq === 1'b1, "T1 held open_start lost a c_open_req cycle");
    end
    @(negedge clk) a_open_start = 1'b0;
    chk(b_openreq === 1'b0, "T1 open_start leaked into the other instance");

    // ================================================================ T2
    // Unit mismatch: BOTH instances are still virgin here, so EVERY output
    // must read exactly 0 - the repo rule is that a disabled output drives
    // 0, never z, because per-unit instances OR their pins together.
    do_req(3'd5, 1'b1, 1'b0, 16'h0000, 16'd0, 11'd512);
    repeat (40) @(posedge clk); #1;
    chk(a_done === 1'b0 && b_done === 1'b0, "T2 a mismatched unit answered");
    chk(a_nreq == 0 && b_nreq == 0, "T2 a mismatched unit issued c_req");
    chk(a_err === 1'b0 && a_code === `NDS_ERR_NONE, "T2 A error pins not parked");
    chk(b_err === 1'b0 && b_code === `NDS_ERR_NONE, "T2 B error pins not parked");
    chk(a_bufaddr === 10'd0 && a_bufwdata === 16'd0 && a_bufwe === 1'b0,
        "T2 A device-buffer pins not parked at 0");
    chk(b_bufaddr === 10'd0 && b_bufwdata === 16'd0 && b_bufwe === 1'b0,
        "T2 B device-buffer pins not parked at 0");
    chk(a_creq === 1'b0 && a_cwr === 1'b0 && a_cblock === 16'd0,
        "T2 A client pins not parked at 0");
    chk(b_creq === 1'b0 && b_cwr === 1'b0 && b_cblock === 16'd0,
        "T2 B client pins not parked at 0");

    // ================================================================ T3
    // NOTOPEN, with zero client traffic
    a_open_ok = 1'b0;
    do_req(3'd3, 1'b1, 1'b0, 16'h0000, 16'd0, 11'd512);
    wait_a(200, "T3 NOTOPEN never completed (wedge)");
    chk(cap_err === 1'b1 && cap_code === `NDS_ERR_NOTOPEN, "T3 wrong reason for not-open");
    chk(a_nreq == 0, "T3 not-open still touched the client port");
    chk(b_done === 1'b0, "T3 the other instance answered too");
    // the code is registered and must still be readable afterwards
    repeat (5) @(posedge clk); #1;
    chk(a_code === `NDS_ERR_NOTOPEN, "T3 disk_err_code did not hold");
    a_open_ok = 1'b1;

    // ================================================================ T4
    // RANGE boundary: c_size_bytes = 2048 = exactly one block.
    // end_bytes = (pos + wordcount) * 2, refused only when it EXCEEDS size.
    a_size = 32'd2048;
    do_req(3'd3, 1'b1, 1'b0, 16'h0000, 16'd0, 11'd1025);
    wait_a(200, "T4 over-length chunk never completed");
    chk(cap_err === 1'b1 && cap_code === `NDS_ERR_RANGE, "T4 wrong reason past end of file");
    chk(a_nreq == 0, "T4 out-of-range request still touched the client port");
    poison_a;
    do_req(3'd3, 1'b1, 1'b0, 16'h0000, 16'd0, 11'd1024);   // exact fit
    wait_a(4000, "T4 exact-fit chunk never completed");
    chk(cap_err === 1'b0 && cap_code === `NDS_ERR_NONE, "T4 exact fit was refused");
    chk(a_nreq == 1 && a_blklog[0] === 16'd0, "T4 exact fit read the wrong block");
    a_size = 32'hFFFF_0000;

    // ================================================================ T5
    // RANGE from the position itself. Cylinder 1500 on 5/18 geometry:
    //   LBA = 1500*5*18 = 135000, words = 69,120,000 -> bit 26 set.
    // c_size_bytes is huge here, so this is the s_blk_ovf path alone.
    do_req(3'd3, 1'b1, 1'b0, 16'h0000, 16'd1500, 11'd512);
    wait_a(200, "T5 2^26 position never completed");
    chk(cap_err === 1'b1 && cap_code === `NDS_ERR_RANGE, "T5 wrong reason for a 2^26 position");
    chk(a_nreq == 0, "T5 2^26 position still touched the client port");
    // cylinder 6000: words = 276,480,000 -> above 2^28, the s_base_ovf path
    do_req(3'd3, 1'b1, 1'b0, 16'h0000, 16'd6000, 11'd512);
    wait_a(200, "T5 base-overflow position never completed");
    chk(cap_err === 1'b1 && cap_code === `NDS_ERR_RANGE, "T5 wrong reason for base overflow");
    chk(a_nreq == 0, "T5 base overflow still touched the client port");

    // ================================================================ T6
    // WRALIGN: a WRITE chunk that starts part-way into a block AND runs
    // past the end of it. Sector 1 = word offset 512, 1024 words.
    do_req(3'd3, 1'b1, 1'b1, 16'h0001, 16'd0, 11'd1024);
    wait_a(200, "T6 straddling partial write never completed");
    chk(cap_err === 1'b1 && cap_code === `NDS_ERR_WRALIGN, "T6 wrong reason for a straddling write");
    chk(a_nreq == 0, "T6 refused write still touched the client port");
    // the SAME shape as a READ is legal and must be accepted (T9 does it)

    // ================================================================ T7
    // wordcount 0: clean completion, no traffic
    do_req(3'd3, 1'b1, 1'b0, 16'h0000, 16'd0, 11'd0);
    wait_a(200, "T7 wordcount 0 never completed");
    chk(cap_err === 1'b0 && cap_code === `NDS_ERR_NONE, "T7 wordcount 0 reported an error");
    chk(a_nreq == 0, "T7 wordcount 0 touched the client port");

    // ================================================================ T8
    // READ one block. cyl 0 / head 4 / sector 17 on 5/18:
    //   LBA = (0*5+4)*18+17 = 89, words = 45568 = block 44, offset 512.
    poison_a;
    lba    = lba_of(0, 4, 17, 5, 18);
    base_w = lba * 512;
    exp_blk = base_w[25:10];
    do_req(3'd3, 1'b1, 1'b0, 16'h0411, 16'd0, 11'd512);
    wait_a(4000, "T8 single-block read never completed");
    chk(cap_err === 1'b0, "T8 single-block read reported an error");
    chk(a_nreq == 1, "T8 single-block read did not issue exactly one c_req");
    chk(a_blklog[0] === exp_blk, "T8 wrong c_block for cyl0/head4/sect17");
    chk(a_wrlog[0] === 1'b0, "T8 read issued c_wr=1");
    for (i = 0; i < 512; i = i + 1)
      if (BUF_A.mem[i] !== CLI_A.img[cli_idx(exp_blk, base_w[9:0] + i)]) begin
        chk(1'b0, "T8 forwarded word wrong");
        i = 512;
      end
    checks = checks + 1;  // the loop above counts as one data check
    chk(BUF_A.mem[512] === 16'hDEAD && BUF_A.mem[1023] === 16'hDEAD,
        "T8 wrote outside the chunk window");

    // ================================================================ T9
    // READ spanning two blocks: same base (offset 512), 1024 words.
    poison_a;
    do_req(3'd3, 1'b1, 1'b0, 16'h0411, 16'd0, 11'd1024);
    wait_a(8000, "T9 spanning read never completed");
    chk(cap_err === 1'b0, "T9 spanning read reported an error");
    chk(a_nreq == 2, "T9 spanning read did not issue exactly two c_req");
    chk(a_blklog[0] === exp_blk && a_blklog[1] === exp_blk + 16'd1,
        "T9 spanning read blocks not ascending/consecutive");
    j = 0;
    for (i = 0; i < 512; i = i + 1)
      if (BUF_A.mem[i] !== CLI_A.img[cli_idx(exp_blk, 512 + i)]) j = j + 1;
    for (i = 0; i < 512; i = i + 1)
      if (BUF_A.mem[512 + i] !== CLI_A.img[cli_idx(exp_blk + 16'd1, i)]) j = j + 1;
    chk(j == 0, "T9 spanning read data wrong across the block seam");

    // ================================================================ T10
    // WRITE a full aligned block: identity address mapping.
    // cyl 1 / head 0 / sector 0 on 5/18: LBA 90, words 46080, block 45 off 0.
    lba    = lba_of(1, 0, 0, 5, 18);
    base_w = lba * 512;
    exp_blk = base_w[25:10];
    chk(base_w[9:0] == 10'd0, "T10 chose a base that is not block aligned");
    for (i = 0; i < 1024; i = i + 1) begin
      BUF_A.mem[i] = 16'hC000 + i[15:0];
      shadow[i]    = 16'hC000 + i[15:0];
    end
    do_req(3'd3, 1'b1, 1'b1, 16'h0000, 16'd1, 11'd1024);
    wait_a(8000, "T10 aligned full-block write never completed");
    chk(cap_err === 1'b0, "T10 aligned write reported an error");
    chk(a_nreq == 1 && a_wrlog[0] === 1'b1, "T10 aligned write did not issue one write c_req");
    chk(a_blklog[0] === exp_blk, "T10 wrong c_block for the aligned write");
    j = 0;
    for (i = 0; i < 1024; i = i + 1)
      if (CLI_A.img[cli_idx(exp_blk, i)] !== shadow[i]) j = j + 1;
    chk(j == 0, "T10 aligned write did not land identity-mapped");

    // ================================================================ T11
    // READ-MODIFY-WRITE, guest half at block offset 0 (512 words).
    // The whole 1024-word block is compared: the top half must survive.
    lba    = lba_of(2, 0, 0, 5, 18);      // LBA 180, words 92160, block 90 off 0
    base_w = lba * 512;
    exp_blk = base_w[25:10];
    chk(base_w[9:0] == 10'd0, "T11 chose a base that is not block aligned");
    for (i = 0; i < 1024; i = i + 1) shadow[i] = CLI_A.img[cli_idx(exp_blk, i)];
    poison_a;
    for (i = 0; i < 512; i = i + 1) begin
      BUF_A.mem[i] = 16'h7000 + i[15:0];
      shadow[i]    = 16'h7000 + i[15:0];   // guest replaces the LOW half
    end
    do_req(3'd3, 1'b1, 1'b1, 16'h0000, 16'd2, 11'd512);
    wait_a(20000, "T11 RMW write at offset 0 never completed");
    chk(cap_err === 1'b0, "T11 RMW write at offset 0 reported an error");
    chk(a_nreq == 2, "T11 RMW did not do read-then-write (two c_req)");
    chk(a_wrlog[0] === 1'b0 && a_wrlog[1] === 1'b1, "T11 RMW order is not read then write");
    chk(a_blklog[0] === exp_blk && a_blklog[1] === exp_blk, "T11 RMW touched the wrong block");
    j = 0;
    for (i = 0; i < 1024; i = i + 1)
      if (CLI_A.img[cli_idx(exp_blk, i)] !== shadow[i]) j = j + 1;
    chk(j == 0, "T11 RMW at offset 0 corrupted the block");

    // ================================================================ T12
    // READ-MODIFY-WRITE, guest half at block offset 512 (512 words). The
    // guest's words still start at device-buffer word 0 (chunk relative)
    // but belong at block words 512..1023; the merge stages the block's
    // low half above them. This is the arithmetic that silently corrupts.
    lba    = lba_of(2, 0, 1, 5, 18);      // LBA 181 -> offset 512 of block 90
    base_w = lba * 512;
    exp_blk = base_w[25:10];
    chk(base_w[9:0] == 10'd512, "T12 chose a base that is not at offset 512");
    for (i = 0; i < 1024; i = i + 1) shadow[i] = CLI_A.img[cli_idx(exp_blk, i)];
    poison_a;
    for (i = 0; i < 512; i = i + 1) begin
      BUF_A.mem[i]     = 16'h9000 + i[15:0];
      shadow[512 + i]  = 16'h9000 + i[15:0];  // guest replaces the HIGH half
    end
    do_req(3'd3, 1'b1, 1'b1, 16'h0001, 16'd2, 11'd512);
    wait_a(20000, "T12 RMW write at offset 512 never completed");
    chk(cap_err === 1'b0, "T12 RMW write at offset 512 reported an error");
    chk(a_nreq == 2 && a_wrlog[0] === 1'b0 && a_wrlog[1] === 1'b1,
        "T12 RMW at offset 512 is not read then write");
    j = 0;
    for (i = 0; i < 1024; i = i + 1)
      if (CLI_A.img[cli_idx(exp_blk, i)] !== shadow[i]) j = j + 1;
    chk(j == 0, "T12 RMW at offset 512 corrupted the block");

    // ================================================================ T13
    // Chunk chaining. disk_start latches the base; each accepted chunk
    // advances the running position by itself.
    lba    = lba_of(3, 0, 0, 5, 18);      // LBA 270, words 138240, block 135
    base_w = lba * 512;
    exp_blk = base_w[25:10];
    poison_a;
    do_req(3'd3, 1'b1, 1'b0, 16'h0000, 16'd3, 11'd512);   // chunk 1: offset 0
    wait_a(4000, "T13 chained read chunk 1 never completed");
    chk(a_nreq == 1 && a_blklog[0] === exp_blk, "T13 chunk 1 wrong block");
    poison_a;
    do_req(3'd3, 1'b0, 1'b0, 16'h0000, 16'd3, 11'd512);   // chunk 2: no start
    wait_a(4000, "T13 chained read chunk 2 never completed");
    chk(a_nreq == 1 && a_blklog[0] === exp_blk, "T13 chunk 2 left the block");
    j = 0;
    for (i = 0; i < 512; i = i + 1)                        // must be the TOP half
      if (BUF_A.mem[i] !== CLI_A.img[cli_idx(exp_blk, 512 + i)]) j = j + 1;
    chk(j == 0, "T13 chunk 2 did not advance to block offset 512");

    // CHARACTERISATION, not a specification. nd_storage_disc_adapter.v line
    // 372 does `s_pos <= s_p + 28'd1024` when a WRITE completes, whatever
    // the chunk length was. So a 512-word partial write leaves the running
    // position a WHOLE BLOCK further on, and the next chunk without a fresh
    // disk_start starts one block too high - it skips the other half of the
    // block it just merged into. Recorded here as observed behaviour and
    // reported as a suspected defect; a read chunk of the same length
    // advances by 512, as the two checks below show side by side.
    lba    = lba_of(4, 0, 0, 5, 18);      // block-aligned base
    base_w = lba * 512;
    exp_blk = base_w[25:10];
    for (i = 0; i < 512; i = i + 1) BUF_A.mem[i] = 16'h2500 + i[15:0];
    do_req(3'd3, 1'b1, 1'b1, 16'h0000, 16'd4, 11'd512);   // partial write, offset 0
    wait_a(20000, "T13 partial write for the advance check never completed");
    chk(cap_err === 1'b0, "T13 partial write for the advance check errored");
    do_req(3'd3, 1'b0, 1'b0, 16'h0000, 16'd4, 11'd512);   // next chunk, no start
    wait_a(4000, "T13 follow-on chunk never completed");
    chk(a_blklog[0] === exp_blk + 16'd1,
        "T13 CHARACTERISATION: partial write advanced by 1024 words, not 512");

    // ================================================================ T14
    // c_err pass-through, on the merge READ and on the commit WRITE, and
    // the adapter must take work again afterwards (retryable, no wedge).
    a_arm_code = `NDS_ERR_CARDIO;
    a_arm_skip = 8'd0;            // fail the FIRST op = the merge read
    @(negedge clk) a_arm_err = 1'b1;
    do_req(3'd3, 1'b1, 1'b1, 16'h0000, 16'd2, 11'd512);
    wait_a(20000, "T14 merge-read failure never completed");
    chk(cap_err === 1'b1 && cap_code === `NDS_ERR_CARDIO, "T14 merge-read reason not passed through");
    chk(a_nreq == 1, "T14 merge-read failure still issued the commit write");
    @(negedge clk) a_arm_err = 1'b0;

    a_arm_code = `NDS_ERR_FATCHAIN;
    a_arm_skip = 8'd1;            // let the merge read pass, fail the write
    @(negedge clk) a_arm_err = 1'b1;
    do_req(3'd3, 1'b1, 1'b1, 16'h0000, 16'd2, 11'd512);
    wait_a(20000, "T14 commit-write failure never completed");
    chk(cap_err === 1'b1 && cap_code === `NDS_ERR_FATCHAIN, "T14 commit-write reason not passed through");
    chk(a_nreq == 2, "T14 commit-write failure did not reach the write");
    @(negedge clk) a_arm_err = 1'b0;

    // plain read failure, then a clean read: proves it is retryable
    a_arm_code = `NDS_ERR_TIMEOUT;
    a_arm_skip = 8'd0;
    @(negedge clk) a_arm_err = 1'b1;
    do_req(3'd3, 1'b1, 1'b0, 16'h0000, 16'd1, 11'd512);
    wait_a(8000, "T14 read failure never completed");
    chk(cap_err === 1'b1 && cap_code === `NDS_ERR_TIMEOUT, "T14 read reason not passed through");
    @(negedge clk) a_arm_err = 1'b0;
    poison_a;
    lba    = lba_of(1, 0, 0, 5, 18);
    base_w = lba * 512;
    exp_blk = base_w[25:10];
    do_req(3'd3, 1'b1, 1'b0, 16'h0000, 16'd1, 11'd512);
    wait_a(8000, "T14 retry after an error never completed");
    chk(cap_err === 1'b0 && cap_code === `NDS_ERR_NONE, "T14 retry after an error still failed");
    j = 0;
    for (i = 0; i < 512; i = i + 1)
      if (BUF_A.mem[i] !== CLI_A.img[cli_idx(exp_blk, i)]) j = j + 1;
    chk(j == 0, "T14 retry delivered wrong data");

    // ================================================================ T15
    // c_busy back-pressure: the adapter must WAIT in S_CREQ (a c_req while
    // the port is busy would simply be lost) and then still complete.
    poison_a;
    @(negedge clk) a_force_busy = 1'b1;
    do_req(3'd3, 1'b1, 1'b0, 16'h0000, 16'd1, 11'd512);
    repeat (30) @(posedge clk); #1;
    chk(a_nreq == 0, "T15 c_req was issued while the client port was busy");
    chk(a_done === 1'b0, "T15 completed while the client port was busy");
    @(negedge clk) a_force_busy = 1'b0;
    wait_a(8000, "T15 never completed after c_busy released");
    chk(cap_err === 1'b0 && a_nreq == 1, "T15 back-pressured request went wrong");
    j = 0;
    for (i = 0; i < 512; i = i + 1)
      if (BUF_A.mem[i] !== CLI_A.img[cli_idx(exp_blk, i)]) j = j + 1;
    chk(j == 0, "T15 back-pressured read delivered wrong data");

    // ================================================================ T16
    // disk_start in the SAME cycle as disk_req must use the FRESH base,
    // not the position left over from the previous chunk.
    lba    = lba_of(5, 2, 3, 5, 18);      // LBA (5*5+2)*18+3 = 489
    base_w = lba * 512;
    exp_blk = base_w[25:10];
    poison_a;
    do_req(3'd3, 1'b1, 1'b0, 16'h0203, 16'd5, 11'd512);
    wait_a(8000, "T16 start-coincident request never completed");
    chk(a_blklog[0] === exp_blk, "T16 start-coincident request used a stale position");
    j = 0;
    for (i = 0; i < 512; i = i + 1)
      if (BUF_A.mem[i] !== CLI_A.img[cli_idx(exp_blk, base_w[9:0] + i)]) j = j + 1;
    chk(j == 0, "T16 start-coincident request delivered the wrong words");

    // ================================================================ T17
    // The SAME adapter on Winchester geometry (8 heads, 9 sectors/track).
    // Mapping, data, and one read-modify-write, on unit 0.
    // cyl 0 / head 7 / sector 8: LBA 71, words 36352 = block 35 offset 512.
    lba    = lba_of(0, 7, 8, 8, 9);
    base_w = lba * 512;
    exp_blk = base_w[25:10];
    poison_b;
    do_req(3'd0, 1'b1, 1'b0, 16'h0708, 16'd0, 11'd512);
    wait_b(8000, "T17 Winchester read never completed");
    chk(cap_err === 1'b0, "T17 Winchester read reported an error");
    chk(b_nreq == 1 && b_blklog[0] === exp_blk, "T17 wrong c_block for WD cyl0/head7/sect8");
    chk(a_done === 1'b0, "T17 the SMD instance answered a unit-0 request");
    j = 0;
    for (i = 0; i < 512; i = i + 1)
      if (BUF_B.mem[i] !== CLI_B.img[cli_idx(exp_blk, base_w[9:0] + i)]) j = j + 1;
    chk(j == 0, "T17 Winchester read delivered the wrong words");

    // high cylinder near the top of the platter: cyl 1023 / head 7 / sect 8
    lba    = lba_of(1023, 7, 8, 8, 9);    // LBA 73727, words 37,748,224
    base_w = lba * 512;
    exp_blk = base_w[25:10];
    poison_b;
    do_req(3'd0, 1'b1, 1'b0, 16'h0708, 16'd1023, 11'd512);
    wait_b(8000, "T17 high-cylinder Winchester read never completed");
    chk(cap_err === 1'b0, "T17 high-cylinder read reported an error");
    chk(b_nreq == 1 && b_blklog[0] === exp_blk, "T17 wrong c_block at cylinder 1023");
    j = 0;
    for (i = 0; i < 512; i = i + 1)
      if (BUF_B.mem[i] !== CLI_B.img[cli_idx(exp_blk, base_w[9:0] + i)]) j = j + 1;
    chk(j == 0, "T17 high-cylinder read delivered the wrong words");

    // Winchester RMW at block offset 512 (SINTRAN's one-sector write shape)
    for (i = 0; i < 1024; i = i + 1) shadow[i] = CLI_B.img[cli_idx(exp_blk, i)];
    poison_b;
    for (i = 0; i < 512; i = i + 1) begin
      BUF_B.mem[i]    = 16'hB000 + i[15:0];
      shadow[512 + i] = 16'hB000 + i[15:0];
    end
    do_req(3'd0, 1'b1, 1'b1, 16'h0708, 16'd1023, 11'd512);
    wait_b(20000, "T17 Winchester RMW write never completed");
    chk(cap_err === 1'b0, "T17 Winchester RMW write reported an error");
    j = 0;
    for (i = 0; i < 1024; i = i + 1)
      if (CLI_B.img[cli_idx(exp_blk, i)] !== shadow[i]) j = j + 1;
    chk(j == 0, "T17 Winchester RMW corrupted the block");

    // ---- verdict ----------------------------------------------------------
    repeat (4) @(posedge clk);
    $display("checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire
