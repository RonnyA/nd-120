/**************************************************************************
** TESTBENCH: ND_DMA_MASTER (two chained masters) against a BCU +        **
** memory model built from ND-06.016.01 chapter V / docs/nd100-bus-dma.md**
**                                                                       **
** The model plays the Bus Control Unit and the memory system:          **
**   BREQ (wired-OR) -> BMEM (freezes requests) -> OUTGRANT token ->     **
**   granted master runs the memory reference (BAPR address, BINPUT      **
**   direction, BDAP data strobe, BDRY reply); BDRY leading edge kills   **
**   the grant, trailing edge releases the bus. One word per allocation. **
**                                                                       **
** Two ND_DMA_MASTER instances share the bus: master A is the chain      **
** head, master B receives A's OUTGRANT as its INGRANT. Covered:         **
**   single word write + readback, 64-word block via re-requests,       **
**   simultaneous requests (chain priority: A first, B next, both        **
**   complete), grant under bus-busy delay, local timeout (memory        **
**   never answers), data integrity across masters, and the request     **
**   freeze: a chain-head request raised AFTER the BMEM leading edge    **
**   must pass the token to the frozen downstream requester.            **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
**                                                                       **
** Last reviewed: 11-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

`timescale 1ns / 1ps

module nd_dma_master_tb;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  always #10 sysclk = ~sysclk;

  // ---- client side, master A ----
  reg         a_req = 0, a_wr = 0;
  reg  [23:0] a_addr = 0;
  reg  [15:0] a_wdata = 0;
  wire [15:0] a_rdata;
  wire        a_ack, a_err, a_busy;

  // ---- client side, master B ----
  reg         b_req = 0, b_wr = 0;
  reg  [23:0] b_addr = 0;
  reg  [15:0] b_wdata = 0;
  wire [15:0] b_rdata;
  wire        b_ack, b_err, b_busy;

  // ---- shared bus ----
  wire        a_breq_n, b_breq_n;
  wire        breq_bus_n = a_breq_n & b_breq_n;  // wired-OR request line
  reg         bmem_n = 1;
  reg         grant_head_n = 1;    // BCU's OUTGRANT -> master A INGRANT
  wire        grant_ab_n;          // A OUTGRANT -> B INGRANT
  wire [23:0] a_bd_out_n, b_bd_out_n;
  reg  [23:0] mem_bd_n = 24'hFFFFFF;
  wire [23:0] bd_bus_n = a_bd_out_n & b_bd_out_n & mem_bd_n;  // wired bus
  wire        a_bapr_n, b_bapr_n;
  wire        bapr_bus_n = a_bapr_n & b_bapr_n;
  wire        a_binput_n, b_binput_n;
  wire        binput_bus_n = a_binput_n & b_binput_n;
  wire        a_bdap_n, b_bdap_n;
  wire        bdap_bus_n = a_bdap_n & b_bdap_n;
  reg         bdry_n = 1;

  ND_DMA_MASTER #(.TIMEOUT_TICKS(16'd200), .BINPUT_HOLD(0),
                  .EARLY_REREQ(1)) u_master_a (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .dma_req(a_req), .dma_wr(a_wr), .dma_addr(a_addr), .dma_wdata(a_wdata),
      .dma_rdata(a_rdata), .dma_ack(a_ack), .dma_err(a_err), .dma_busy(a_busy),
      .BREQ_n(a_breq_n),
      .INGRANT_n(grant_head_n), .OUTGRANT_n(grant_ab_n),
      .BMEM_n(bmem_n),
      .BD_23_0_n_OUT(a_bd_out_n), .BD_23_0_n_IN(bd_bus_n),
      .BAPR_n(a_bapr_n), .BINPUT_n(a_binput_n), .BDAP_n(a_bdap_n),
      .BDRY_n(bdry_n)
  );

  ND_DMA_MASTER #(.TIMEOUT_TICKS(16'd200), .BINPUT_HOLD(1),
                  .EARLY_REREQ(0)) u_master_b (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .dma_req(b_req), .dma_wr(b_wr), .dma_addr(b_addr), .dma_wdata(b_wdata),
      .dma_rdata(b_rdata), .dma_ack(b_ack), .dma_err(b_err), .dma_busy(b_busy),
      .BREQ_n(b_breq_n),
      .INGRANT_n(grant_ab_n), .OUTGRANT_n(),
      .BMEM_n(bmem_n),
      .BD_23_0_n_OUT(b_bd_out_n), .BD_23_0_n_IN(bd_bus_n),
      .BAPR_n(b_bapr_n), .BINPUT_n(b_binput_n), .BDAP_n(b_bdap_n),
      .BDRY_n(bdry_n)
  );

  // -------- BCU + memory model --------
  reg        model_enable = 1;   // 0 = memory dead (timeout test)
  reg [3:0]  arb_delay = 4'd2;   // cycles from BREQ to BMEM
  reg [15:0] memory [0:65535];
  reg [23:0] m_addr;
  reg        m_write;            // BINPUT captured at BAPR
  reg [3:0]  m_state = 0;
  reg [3:0]  m_cnt = 0;

  localparam M_IDLE  = 4'd0;
  localparam M_ARB   = 4'd1;   // arbitration delay, then BMEM+grant
  localparam M_WAITA = 4'd2;   // wait BAPR (address cycle)
  localparam M_WAITD = 4'd3;   // wait BDAP (data cycle)
  localparam M_REPLY = 4'd4;   // BDRY asserted, wait BDAP release
  localparam M_REL   = 4'd5;   // release everything

  always @(posedge sysclk) begin
    case (m_state)
      M_IDLE: begin
        if (breq_bus_n == 1'b0 && model_enable) begin
          m_cnt   <= arb_delay;
          m_state <= M_ARB;
        end
      end
      M_ARB: begin
        if (m_cnt != 0) m_cnt <= m_cnt - 4'd1;
        else begin
          bmem_n       <= 1'b0;  // freeze request status, enable memory
          grant_head_n <= 1'b0;  // start the grant search
          m_state      <= M_WAITA;
        end
      end
      M_WAITA: begin
        if (bapr_bus_n == 1'b0) begin
          m_addr  <= ~bd_bus_n;
          m_write <= (binput_bus_n == 1'b0);
          m_state <= M_WAITD;
        end
      end
      M_WAITD: begin
        if (bdap_bus_n == 1'b0) begin
          if (m_write) begin
            // direction was latched at BAPR; a BINPUT_HOLD=0 master must
            // have released BINPUT before the data phase (all writes in
            // this tb come from master A, the HOLD=0 variant)
            check(a_binput_n === 1'b1,
                  "BINPUT still active in data phase (HOLD=0 master)");
            memory[m_addr[15:0]] <= ~bd_bus_n[15:0];
          end else begin
            mem_bd_n <= ~{8'd0, memory[m_addr[15:0]]};
          end
          bdry_n       <= 1'b0;  // data ready / accepted
          grant_head_n <= 1'b1;  // BDRY leading edge kills the grant
          m_state      <= M_REPLY;
        end
      end
      M_REPLY: begin
        if (bdap_bus_n == 1'b1) begin
          bdry_n   <= 1'b1;      // trailing edge releases the bus
          mem_bd_n <= 24'hFFFFFF;
          bmem_n   <= 1'b1;
          m_state  <= M_REL;
        end
      end
      M_REL: begin
        m_state <= M_IDLE;
      end
      default: m_state <= M_IDLE;
    endcase
  end

  integer errors = 0;

  task check(input cond, input [255:0] what);
    begin
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL: %0s (time %0t)", what, $time);
      end
    end
  endtask

  // one word via master A
  task a_xfer(input wr, input [23:0] addr, input [15:0] wdata);
    integer guard;
    begin
      @(negedge sysclk);
      a_wr = wr; a_addr = addr; a_wdata = wdata; a_req = 1;
      @(negedge sysclk);
      a_req = 0;
      guard = 0;
      while (a_ack !== 1'b1 && guard < 500) begin
        @(negedge sysclk); guard = guard + 1;
      end
      check(a_ack === 1'b1, "master A transfer never completed");
      @(negedge sysclk);
    end
  endtask

  integer i, guard;
  reg a_done_seen, b_done_seen;
  reg [31:0] a_done_time, b_done_time;

  initial begin
`ifdef DUMPFILE
    $dumpfile("nd_dma_master_tb.vcd");
    $dumpvars(0, nd_dma_master_tb);
`endif
    for (i = 0; i < 65536; i = i + 1) memory[i] = 16'hDEAD;

    repeat (5) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (5) @(negedge sysclk);

    // 1: single word write, then read back
    a_xfer(1'b1, 24'o00001234, 16'o123456);
    check(a_err === 1'b0, "write flagged error");
    check(memory[16'o1234] === 16'o123456, "memory word not written");
    a_xfer(1'b0, 24'o00001234, 16'd0);
    check(a_rdata === 16'o123456, "readback value wrong");
    check(a_err === 1'b0, "read flagged error");

    // 2: 64-word block via re-requests (the device's word-counter role)
    for (i = 0; i < 64; i = i + 1)
      a_xfer(1'b1, 24'o00002000 + i, 16'hA000 + i[15:0]);
    for (i = 0; i < 64; i = i + 1) begin
      a_xfer(1'b0, 24'o00002000 + i, 16'd0);
      check(a_rdata === (16'hA000 + i[15:0]), "block readback wrong");
    end

    // 3: simultaneous requests -> chain priority: A wins, B follows,
    //    both complete with correct data
    memory[16'o3000] = 16'h1111;
    memory[16'o3001] = 16'h2222;
    a_done_seen = 0; b_done_seen = 0;
    @(negedge sysclk);
    a_wr = 0; a_addr = 24'o3000; a_req = 1;
    b_wr = 0; b_addr = 24'o3001; b_req = 1;
    @(negedge sysclk);
    a_req = 0; b_req = 0;
    guard = 0;
    while ((!a_done_seen || !b_done_seen) && guard < 2000) begin
      @(negedge sysclk);
      if (a_ack === 1'b1 && !a_done_seen) begin
        a_done_seen = 1; a_done_time = $time;
        check(a_rdata === 16'h1111, "master A concurrent read wrong");
      end
      if (b_ack === 1'b1 && !b_done_seen) begin
        b_done_seen = 1; b_done_time = $time;
        check(b_rdata === 16'h2222, "master B concurrent read wrong");
      end
      guard = guard + 1;
    end
    check(a_done_seen === 1'b1, "master A never completed (concurrent)");
    check(b_done_seen === 1'b1, "master B never completed (concurrent)");
    if (a_done_seen && b_done_seen)
      check(a_done_time < b_done_time, "chain priority violated (B before A)");

    // 4: grant under longer arbitration delay (bus busy)
    arb_delay = 4'd9;
    a_xfer(1'b1, 24'o00004000, 16'h5A5A);
    check(memory[16'o4000] === 16'h5A5A, "delayed-grant write lost");
    arb_delay = 4'd2;

    // 5: dead memory -> local timeout error, bus released
    model_enable = 0;
    @(negedge sysclk);
    a_wr = 0; a_addr = 24'o5000; a_req = 1;
    @(negedge sysclk);
    a_req = 0;
    guard = 0;
    while (a_ack !== 1'b1 && guard < 500) begin
      @(negedge sysclk); guard = guard + 1;
    end
    check(a_ack === 1'b1, "timeout never completed");
    check(a_err === 1'b1, "timeout not flagged as error");
    check(a_breq_n === 1'b1, "BREQ stuck after timeout");
    model_enable = 1;

    // 7 (run before 6's final check block): request freeze - B
    // (downstream) requests; after the BMEM leading edge A (chain
    // head) requests LATE. A must pass the token (not steal the
    // grant); B completes this round, A the next round.
    arb_delay = 4'd6;
    memory[16'o7000] = 16'h7777;
    memory[16'o7001] = 16'h8888;
    a_done_seen = 0; b_done_seen = 0;
    @(negedge sysclk);
    b_wr = 0; b_addr = 24'o7001; b_req = 1;
    @(negedge sysclk);
    b_req = 0;
    guard = 0;
    while (bmem_n !== 1'b0 && guard < 100) begin
      @(negedge sysclk); guard = guard + 1;
    end
    check(bmem_n === 1'b0, "BMEM never fell in freeze test");
    a_wr = 0; a_addr = 24'o7000; a_req = 1;  // too late for this round
    @(negedge sysclk);
    a_req = 0;
    guard = 0;
    while ((!a_done_seen || !b_done_seen) && guard < 3000) begin
      @(negedge sysclk);
      if (b_ack === 1'b1 && !b_done_seen) begin
        b_done_seen = 1;
        check(b_rdata === 16'h8888, "B freeze-test read wrong");
        check(a_done_seen == 0, "A stole the grant despite late request");
      end
      if (a_ack === 1'b1 && !a_done_seen) begin
        a_done_seen = 1;
        check(a_rdata === 16'h7777, "A freeze-test read wrong");
      end
      guard = guard + 1;
    end
    check(b_done_seen === 1'b1, "B never completed (freeze test)");
    check(a_done_seen === 1'b1, "A never completed after freeze round");
    arb_delay = 4'd2;

    // 6: recovery after timeout: normal transfer works again
    a_xfer(1'b1, 24'o00006000, 16'hC0DE);
    check(memory[16'o6000] === 16'hC0DE, "post-timeout write lost");
    check(a_err === 1'b0, "post-timeout transfer flagged error");

    // 8: early re-request (EARLY_REREQ=1 on master A): queue word 2
    //    while word 1 is still on the bus; BREQ overlaps the cycle
    //    tail; both words must land correctly
    @(negedge sysclk);
    a_wr = 1; a_addr = 24'o10000; a_wdata = 16'h1A1A; a_req = 1;
    @(negedge sysclk);
    // word 1 in flight: immediately queue word 2
    a_addr = 24'o10001; a_wdata = 16'h2B2B;
    @(negedge sysclk);
    a_req = 0;
    guard = 0; i = 0;
    while (i < 2 && guard < 1000) begin
      @(negedge sysclk);
      if (a_ack === 1'b1) i = i + 1;
      guard = guard + 1;
    end
    check(i == 2, "early re-request: did not get two acks");
    check(memory[16'o10000] === 16'h1A1A, "early re-request word 1 lost");
    check(memory[16'o10001] === 16'h2B2B, "early re-request word 2 lost");

    if (errors == 0) $display("TB_RESULT: PASS");
    else begin
      $display("%0d errors", errors);
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

  initial begin
    #10000000;
    $display("TIMEOUT");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
