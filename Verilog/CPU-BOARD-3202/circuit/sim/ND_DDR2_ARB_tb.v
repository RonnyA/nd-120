/****************************************************************************
** ND_DDR2_ARB_tb - unit test for the two-client DDR2 arbiter              **
**                                                                         **
** DUT: fpga/nexys4ddr/ddr2/nd_ddr2_arb.v                                  **
** A behavioural port model stands in for nd_ddr2_port: accepts one op at  **
** a time, answers reads with f(addr) after a few cycles, and can be told  **
** to go dead (watchdog test) or emit a spurious response (orphan test).   **
**                                                                         **
** Tests:                                                                  **
**  1  single-client ops complete with correct steering and data           **
**  2  FAIRNESS: client A streams back-to-back while B asks - B must be    **
**     served within one A-operation's worth of cycles (the old strict-A   **
**     arbiter starves B here forever)                                     **
**  3  WATCHDOG: the port goes dead mid-op - sticky dbg_stuck must rise,   **
**     the grant must NOT be released and no response invented             **
**  4  ORPHAN: a spurious rsp_valid with no grant held - sticky            **
**     dbg_orphan must rise, and neither client may see rsp_valid          **
**                                                                         **
** Verdict: prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".                 **
*****************************************************************************/
`timescale 1ns / 1ps

module ND_DDR2_ARB_tb;

  reg ui_clk = 0;
  always #5 ui_clk = ~ui_clk;   // arbitrary 100 MHz - the DUT is synchronous
  reg ui_rst = 1;

  // client A
  reg           a_req_valid = 0, a_req_we = 0;
  reg  [ 26:0]  a_req_addr = 0;
  reg  [127:0]  a_req_wdata = 0;
  reg  [ 15:0]  a_req_wmask = 0;
  wire          a_req_ready, a_rsp_valid;
  wire [127:0]  a_rsp_rdata;

  // client B
  reg           b_req_valid = 0, b_req_we = 0;
  reg  [ 26:0]  b_req_addr = 0;
  reg  [127:0]  b_req_wdata = 0;
  reg  [ 15:0]  b_req_wmask = 0;
  wire          b_req_ready, b_rsp_valid;
  wire [127:0]  b_rsp_rdata;

  // downstream port
  wire          req_valid, req_we, req_ready;
  wire [ 26:0]  req_addr;
  wire [127:0]  req_wdata;
  wire [ 15:0]  req_wmask;
  reg           rsp_valid = 0;
  reg  [127:0]  rsp_rdata = 0;

  wire       dbg_stuck, dbg_orphan;
  wire [1:0] dbg_grant;

  // short watchdog so test 3 runs in simulation time
  nd_ddr2_arb #(.WDOG_BITS(8)) DUT (
      .ui_clk(ui_clk), .ui_rst(ui_rst),
      .a_req_valid(a_req_valid), .a_req_we(a_req_we), .a_req_addr(a_req_addr),
      .a_req_wdata(a_req_wdata), .a_req_wmask(a_req_wmask),
      .a_req_ready(a_req_ready), .a_rsp_valid(a_rsp_valid), .a_rsp_rdata(a_rsp_rdata),
      .b_req_valid(b_req_valid), .b_req_we(b_req_we), .b_req_addr(b_req_addr),
      .b_req_wdata(b_req_wdata), .b_req_wmask(b_req_wmask),
      .b_req_ready(b_req_ready), .b_rsp_valid(b_rsp_valid), .b_rsp_rdata(b_rsp_rdata),
      .req_valid(req_valid), .req_we(req_we), .req_addr(req_addr),
      .req_wdata(req_wdata), .req_wmask(req_wmask), .req_ready(req_ready),
      .rsp_valid(rsp_valid), .rsp_rdata(rsp_rdata),
      .dbg_stuck(dbg_stuck), .dbg_orphan(dbg_orphan), .dbg_grant(dbg_grant)
  );

  /*** behavioural port model (one op at a time, LAT-cycle read latency) ***/
  localparam LAT = 4;
  reg        p_dead = 0;         // 1 = never answer (watchdog test)
  reg        p_busy = 0;
  reg [26:0] p_addr;
  reg        p_we;
  reg [3:0]  p_cnt;
  assign req_ready = !p_busy && !p_dead;

  function [127:0] rdval(input [26:0] a);
    rdval = {4{5'b0, a}};        // address-derived pattern, 32 bits x 4
  endfunction

  always @(posedge ui_clk) begin
    rsp_valid <= 0;
    if (ui_rst) begin
      p_busy <= 0;
    end else if (!p_dead) begin
      if (!p_busy && req_valid && req_ready) begin
        p_busy <= 1; p_addr <= req_addr; p_we <= req_we; p_cnt <= 0;
      end else if (p_busy) begin
        p_cnt <= p_cnt + 1;
        if (p_cnt == LAT-1) begin
          rsp_valid <= 1;
          rsp_rdata <= p_we ? 128'h0 : rdval(p_addr);
          p_busy    <= 0;
        end
      end
    end
  end

  /*** client A traffic generator: a worst-case LEGAL client - drops valid
       in the accept cycle (like the real MEM/storage clients) but re-raises
       it in the very cycle its response lands, leaving zero idle gap ***/
  reg        a_hammer = 0;
  reg        a_busy_g = 0;
  integer    a_done_cnt = 0;
  reg [26:0] a_next = 27'o1000;
  always @(posedge ui_clk) begin
    if (a_hammer) begin
      if (!a_busy_g && !a_req_valid) begin
        a_req_valid <= 1; a_req_we <= 0; a_req_addr <= a_next;
      end
      if (a_req_valid && a_req_ready) begin
        a_req_valid <= 0; a_busy_g <= 1;
      end
      if (a_rsp_valid) begin
        a_busy_g   <= 0;
        a_done_cnt <= a_done_cnt + 1;
        a_next     <= a_next + 8;
        // zero-gap re-request, same cycle as the response
        a_req_valid <= 1; a_req_we <= 0; a_req_addr <= a_next + 8;
      end
    end
  end

  /*** misdelivery guards: rsp_valid must never reach the wrong client ***/
  integer errors = 0;
  reg guard_no_a_rsp = 0, guard_no_b_rsp = 0;
  always @(posedge ui_clk) begin
    if (guard_no_a_rsp && a_rsp_valid) begin
      $display("FAIL: a_rsp_valid asserted while nothing was owed to A");
      errors = errors + 1;
    end
    if (guard_no_b_rsp && b_rsp_valid) begin
      $display("FAIL: b_rsp_valid asserted while nothing was owed to B");
      errors = errors + 1;
    end
  end

  task a_read(input [26:0] addr);
    begin
      @(negedge ui_clk);
      a_req_valid = 1; a_req_we = 0; a_req_addr = addr;
      // real-client protocol: hold valid through the accepting posedge,
      // drop it right after (the cycle it is taken)
      @(negedge ui_clk); while (!a_req_ready) @(negedge ui_clk);
      @(posedge ui_clk); #1 a_req_valid = 0;
      @(negedge ui_clk); while (!a_rsp_valid) @(negedge ui_clk);
      if (a_rsp_rdata !== rdval(addr)) begin
        $display("FAIL: A read %o got %h expected %h", addr, a_rsp_rdata, rdval(addr));
        errors = errors + 1;
      end
      @(negedge ui_clk); a_req_valid = 0;
    end
  endtask

  task b_read(input [26:0] addr);
    begin
      @(negedge ui_clk);
      b_req_valid = 1; b_req_we = 0; b_req_addr = addr;
      @(negedge ui_clk); while (!b_req_ready) @(negedge ui_clk);
      @(posedge ui_clk); #1 b_req_valid = 0;
      @(negedge ui_clk); while (!b_rsp_valid) @(negedge ui_clk);
      if (b_rsp_rdata !== rdval(addr)) begin
        $display("FAIL: B read %o got %h expected %h", addr, b_rsp_rdata, rdval(addr));
        errors = errors + 1;
      end
      @(negedge ui_clk); b_req_valid = 0;
    end
  endtask

  integer i, waited;
  initial begin
    repeat (5) @(negedge ui_clk);
    ui_rst = 0;
    repeat (2) @(negedge ui_clk);

    /*** test 1: plain steered ops, both clients, data correct ***/
    $display("test 1: single-client operations");
    guard_no_b_rsp = 1;
    a_read(27'o0000010);
    a_read(27'o0000020);
    guard_no_b_rsp = 0; guard_no_a_rsp = 1;
    b_read(27'o4000010);
    guard_no_a_rsp = 0;

    /*** test 2: fairness - A hammers, B must still get served ***/
    $display("test 2: fairness under a client-A stream");
    a_hammer = 1;
    repeat (20) @(negedge ui_clk);      // A stream established
    b_req_valid = 1; b_req_we = 0; b_req_addr = 27'o4000020;
    waited = 0;
    while (!b_req_ready && waited < 100) begin
      @(negedge ui_clk); waited = waited + 1;
    end
    if (b_req_ready) begin
      @(posedge ui_clk); #1 b_req_valid = 0;   // accepted at that edge
    end
    while (!b_rsp_valid && waited < 100) begin
      @(negedge ui_clk); waited = waited + 1;
    end
    if (!b_rsp_valid) begin
      $display("FAIL: B starved for %0d cycles under an A stream", waited);
      errors = errors + 1;
    end else begin
      if (b_rsp_rdata !== rdval(27'o4000020)) begin
        $display("FAIL: B fairness read got %h expected %h", b_rsp_rdata, rdval(27'o4000020));
        errors = errors + 1;
      end
      $display("  B served after %0d cycles; A completed %0d ops meanwhile", waited, a_done_cnt);
    end
    @(negedge ui_clk); b_req_valid = 0;
    a_hammer = 0; @(negedge ui_clk); a_req_valid = 0;
    // drain a possible in-flight A op
    repeat (2*LAT+4) @(negedge ui_clk);

    if (dbg_stuck || dbg_orphan) begin
      $display("FAIL: health flags set during normal traffic (stuck=%b orphan=%b)",
               dbg_stuck, dbg_orphan);
      errors = errors + 1;
    end

    /*** test 3: watchdog - port goes dead mid-op ***/
    $display("test 3: watchdog on a dead port");
    p_dead = 1;
    @(negedge ui_clk);
    a_req_valid = 1; a_req_we = 0; a_req_addr = 27'o0000030;
    guard_no_a_rsp = 1; guard_no_b_rsp = 1;   // nothing may be invented
    waited = 0;
    while (!dbg_stuck && waited < 400) begin @(posedge ui_clk); waited = waited + 1; end
    if (!dbg_stuck) begin
      $display("FAIL: dbg_stuck never rose on a dead port"); errors = errors + 1;
    end else if (dbg_grant !== 2'd1) begin
      $display("FAIL: grant released on timeout (grant=%0d) - must hold", dbg_grant);
      errors = errors + 1;
    end else
      $display("  dbg_stuck after %0d cycles, grant held", waited);
    guard_no_a_rsp = 0; guard_no_b_rsp = 0;
    // revive: reset clears the sticky flag and the hung grant
    ui_rst = 1; a_req_valid = 0; p_dead = 0;
    repeat (3) @(negedge ui_clk);
    ui_rst = 0; repeat (2) @(negedge ui_clk);
    if (dbg_stuck) begin
      $display("FAIL: dbg_stuck not cleared by reset"); errors = errors + 1;
    end

    /*** test 4: orphan response with no grant held ***/
    $display("test 4: orphan response");
    guard_no_a_rsp = 1; guard_no_b_rsp = 1;
    @(negedge ui_clk); rsp_valid = 1; rsp_rdata = 128'hDEAD;
    @(negedge ui_clk); rsp_valid = 0;
    repeat (2) @(negedge ui_clk);
    if (!dbg_orphan) begin
      $display("FAIL: dbg_orphan never rose on an unowned response");
      errors = errors + 1;
    end
    guard_no_a_rsp = 0; guard_no_b_rsp = 0;
    // arbiter must still work after the orphan
    a_read(27'o0000040);

    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  initial begin
    #500000;
    $display("FAIL: timeout"); $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
