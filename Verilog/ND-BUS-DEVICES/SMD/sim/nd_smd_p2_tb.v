/**************************************************************************
** TESTBENCH: ND_SMD - SMD campaign phase P2                              **
**            iox_rd STROBE WIDTH + the 15 MHz read-flip-flop side effect **
**                                                                       **
**   scripted CPU bus master -> ND_BUS_SLAVE -> ND_SMD                   **
**                                                                       **
** The SMD P1 tb (nd_smd_iox_tb) drives the device iox_* port directly   **
** and, to make the read flip-flops toggle, has to hold iox_rd HIGH      **
** across a posedge - a NON-STANDARD strobe it constructs by hand. The   **
** real ND_BUS_SLAVE pulses iox_rd for exactly ONE sysclk cycle. P2      **
** proves the 15 MHz flip-flop machinery is correct against THAT real    **
** strobe (CONFORMANCE-style, the SMD analogue of the floppy P2 tb):     **
**                                                                       **
**  1  STROBE WIDTH: the slave pulses iox_rd for exactly one sysclk      **
**       cycle. A wider strobe would toggle mar_ff / wcr_ff TWICE per    **
**       bus read (returning the wrong readback half). Proven by a       **
**       continuous monitor: iox_rd is never high on two consecutive     **
**       sysclk edges over the whole run.                                **
**  2  CORE ADDRESS readback (the toggle under the real strobe): load    **
**       HI then LO via +1, read +0 twice through the bus -> LO then HI. **
**       read2 == HI is the direct double-toggle detector: a 2-cycle     **
**       strobe would leave mar_ff back at 0 and return LO again. Also    **
**       asserted at the flip-flop: exactly one toggle per bus read.     **
**  3  WORD COUNTER readback (CWR=1 mux): load HI/LO via +7, read +0     **
**       twice -> LO then HI, with one wcr_ff toggle per bus read.       **
**  4  STATUS-READ clr_ff: a +4 status read (CWR=0) must reset the read  **
**       flip-flops through the single-cycle strobe, so the following    **
**       +0 read starts at LO again (not the stale HI phase).            **
**                                                                       **
** No GO is ever issued (control bit 2 stays 0): the transfer engine     **
** never leaves E_IDLE, so the DMA master + disk backend are tied idle.  **
** Register-value semantics themselves are P1's job; P2 is about the     **
** strobe and the read side effects seen through the real bus.           **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
***************************************************************************/

`timescale 1ns / 1ps

module nd_smd_p2_tb;

  localparam [15:0] BASE = 16'o001540;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  always #10 sysclk = ~sysclk;

  // ---- CPU-side bus (IOX master) ----
  reg  [23:0] bd_out = 24'hFFFFFF;
  wire [23:0] bd_in;
  reg  bapr_n = 1, bioxe_n = 1, binack_n = 1, outident_n = 1;
  wire binput_n, bdap_n, bdry_n;
  wire bint10_n, bint11_n, bint12_n, bint13_n;

  wire [15:0] iox_addr, iox_wdata, iox_rdata;
  wire iox_wr, iox_rd;
  wire ident_strobe;
  wire [3:0] ident_level;
  wire [3:0] intp;
  wire ident_hit;
  wire [15:0] ident_code;

  ND_BUS_SLAVE u_slave (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .BD_23_0_n_OUT(bd_out), .BD_23_0_n_IN(bd_in),
      .BAPR_n(bapr_n), .BIOXE_n(bioxe_n), .BINACK_n(binack_n),
      .OUTIDENT_n(outident_n),
      .BINPUT_n(binput_n), .BDAP_n(bdap_n), .BDRY_n(bdry_n),
      .BINT10_n(bint10_n), .BINT11_n(bint11_n),
      .BINT12_n(bint12_n), .BINT13_n(bint13_n),
      .iox_addr(iox_addr), .iox_wr(iox_wr), .iox_wdata(iox_wdata),
      .iox_rd(iox_rd), .iox_rdata(iox_rdata),
      .int_pending(intp),
      .ident_strobe(ident_strobe), .ident_level(ident_level),
      .ident_hit(ident_hit), .ident_code(ident_code)
  );

  // ---- ND_SMD; DMA master + disk backend tied idle (no GO issued) ----
  wire        dma_req, dma_wr;
  wire [23:0] dma_addr;
  wire [15:0] dma_wdata;
  wire        disk_start, disk_req, disk_wr;
  wire [15:0] disk_blkaddr1, disk_blkaddr2;
  wire [2:0]  disk_unit;
  wire [10:0] disk_wordcount;
  wire [15:0] dbuf_rdata;
  wire        ident_grant_out;

  ND_SMD u_smd (
      .sysclk        (sysclk),
      .sys_rst_n     (sys_rst_n),
      .iox_addr      (iox_addr),
      .iox_wr        (iox_wr),
      .iox_wdata     (iox_wdata),
      .iox_rd        (iox_rd),
      .iox_rdata     (iox_rdata),
      .int_pending   (intp),
      .ident_strobe  (ident_strobe),
      .ident_level   (ident_level),
      .ident_grant_in(1'b1),
      .ident_grant_out(ident_grant_out),
      .ident_hit     (ident_hit),
      .ident_code    (ident_code),
      .dma_req       (dma_req),
      .dma_wr        (dma_wr),
      .dma_addr      (dma_addr),
      .dma_wdata     (dma_wdata),
      .dma_rdata     (16'd0),
      .dma_ack       (1'b0),
      .dma_err       (1'b0),
      .dma_busy      (1'b0),
      .disk_start    (disk_start),
      .disk_req      (disk_req),
      .disk_wr       (disk_wr),
      .disk_blkaddr1 (disk_blkaddr1),
      .disk_blkaddr2 (disk_blkaddr2),
      .disk_unit     (disk_unit),
      .disk_wordcount(disk_wordcount),
      .disk_done     (1'b0),
      .disk_err_in   (1'b0),
      .dbuf_addr     (10'd0),
      .dbuf_wdata    (16'd0),
      .dbuf_we       (1'b0),
      .dbuf_rdata    (dbuf_rdata)
  );

  // ---- STROBE-WIDTH monitor: iox_rd must never be high on two
  //      consecutive sysclk edges (single-cycle => single toggle). --------
  integer rd_run = 0, rd_run_max = 0;
  always @(posedge sysclk) begin
    if (iox_rd) rd_run = rd_run + 1;
    else        rd_run = 0;
    if (rd_run > rd_run_max) rd_run_max = rd_run;
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

  // ---- CPU-side IOX tasks (same framing as the floppy bus tbs) ----
  task bus_apr(input [15:0] addr);
    begin
      @(negedge sysclk); bd_out = ~{8'd0, addr}; bapr_n = 0;
      @(negedge sysclk); @(negedge sysclk);
      bapr_n = 1; bd_out = 24'hFFFFFF; @(negedge sysclk);
    end
  endtask

  task iox_write(input [15:0] addr, input [15:0] data);
    integer guard;
    begin
      bus_apr(addr | 16'd1);
      bd_out  = ~{8'd0, data}; bioxe_n = 0; guard = 0;
      while (bdry_n !== 1'b0 && guard < 50) begin @(negedge sysclk); guard = guard + 1; end
      check(bdry_n === 1'b0, "iox_write: BDRY_n never asserted");
      @(negedge sysclk); bioxe_n = 1; bd_out = 24'hFFFFFF;
      @(negedge sysclk); @(negedge sysclk);
    end
  endtask

  task iox_read(input [15:0] addr, output [15:0] data);
    integer guard;
    begin
      bus_apr(addr & 16'hFFFE);
      bioxe_n = 0; guard = 0;
      while (binput_n !== 1'b0 && guard < 50) begin @(negedge sysclk); guard = guard + 1; end
      check(binput_n === 1'b0, "iox_read: BINPUT_n never asserted");
      binack_n = 0; guard = 0;
      while (bdry_n !== 1'b0 && guard < 50) begin @(negedge sysclk); guard = guard + 1; end
      check(bdry_n === 1'b0, "iox_read: BDRY_n never asserted");
      data = ~bd_in[15:0];
      binack_n = 1; bioxe_n = 1; @(negedge sysclk); @(negedge sysclk);
    end
  endtask

  // Non-GO Load Control Word (+5, b2 = 0): leave boot mode, pick CWR + unit.
  task ctrl_word(input cwr, input [2:0] unit);
    reg [15:0] cw;
    begin
      cw = 16'd0;
      cw[9:7] = unit;   // b9 = 0 -> unit selected
      cw[15]  = cwr;
      iox_write(BASE + 16'd5, cw);
    end
  endtask

  reg [15:0] r, r2;
  reg        mar_a, mar_b, mar_c;
  reg        wcr_a, wcr_b;

  initial begin
`ifdef DUMPFILE
    $dumpfile("nd_smd_p2_tb.vcd");
    $dumpvars(0, nd_smd_p2_tb);
`endif
    repeat (5) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (5) @(negedge sysclk);

    // Leave boot mode + select unit 0 (CWR=0) so the normal register model
    // and the read flip-flops are live.
    ctrl_word(1'b0, 3'd0);

    // ============ Test 2: CORE ADDRESS readback under the real strobe ====
    // Load HI (0xAB) then LO (0xCDEF); read +0 twice -> LO then HI. mar_ff
    // starts at 0 (LO). Each bus read must toggle mar_ff exactly once.
    iox_write(BASE + 16'd1, 16'h00AB);   // +1 first write  = HI byte
    iox_write(BASE + 16'd1, 16'hCDEF);   // +1 second write = LO 16
    mar_a = u_smd.s_mar_ff;
    iox_read(BASE + 16'd0, r);           // first +0 read = LO
    mar_b = u_smd.s_mar_ff;
    iox_read(BASE + 16'd0, r2);          // second +0 read = HI
    mar_c = u_smd.s_mar_ff;
    check(r  === 16'hCDEF, "T2: core-addr LO via real bus strobe must be 0xCDEF");
    check(r2 === 16'h00AB,
          "T2: core-addr HI must be 0x00AB (read2==HI proves single toggle)");
    check(mar_b !== mar_a, "T2: first bus +0 read must toggle mar_ff exactly once");
    check(mar_c !== mar_b, "T2: second bus +0 read must toggle mar_ff exactly once");

    // ============ Test 4: STATUS READ resets the read flip-flops =========
    // mar_ff is now back at 0 after two toggles. Toggle it once more with a
    // +0 read (mar_ff -> 1), then a +4 status read (CWR=0) must clr_ff it
    // back to 0, so the next +0 read starts at LO again.
    iox_read(BASE + 16'd0, r);           // returns LO (mar_ff was 0), mar_ff -> 1
    check(u_smd.s_mar_ff === 1'b1, "T4: a +0 read leaves mar_ff = 1");
    iox_read(BASE + 16'd4, r);           // +4 status read, CWR=0 -> clr_ff
    check(u_smd.s_mar_ff === 1'b0, "T4: +4 status read must reset mar_ff (clr_ff)");
    iox_read(BASE + 16'd0, r);           // starts at LO again
    check(r === 16'hCDEF, "T4: after status-read reset, +0 must return LO again");

    // ============ Test 3: WORD COUNTER readback (CWR=1 mux) ==============
    // Load HI (0x12) then LO (0x3456) via +7 (CWR=0), switch CWR=1, read +0
    // twice -> LO then HI, one wcr_ff toggle per bus read.
    ctrl_word(1'b0, 3'd0);               // ensure CWR=0 for the +7 loads
    iox_write(BASE + 16'd7, 16'h0012);   // +7 first write  = WC HI byte
    iox_write(BASE + 16'd7, 16'h3456);   // +7 second write = WC LO 16
    ctrl_word(1'b1, 3'd0);               // switch to CWR=1, unit0 (wcr_ff still 0)
    wcr_a = u_smd.s_wcr_ff;
    iox_read(BASE + 16'd0, r);           // +0 CWR=1 first read = WC LO
    wcr_b = u_smd.s_wcr_ff;
    iox_read(BASE + 16'd0, r2);          // +0 CWR=1 second read = WC HI
    check(r  === 16'h3456, "T3: word-count LO (CWR=1 mux) must be 0x3456");
    check(r2 === 16'h0012, "T3: word-count HI must be 0x0012 (single wcr_ff toggle)");
    check(wcr_b !== wcr_a, "T3: first CWR=1 +0 read must toggle wcr_ff exactly once");

    // ============ Test 1: STROBE WIDTH verdict ==========================
    check(rd_run_max == 1,
          "T1: iox_rd must be a single-cycle strobe (no double-toggle)");
    $display("NOTE: max consecutive iox_rd-high sysclk edges = %0d (must be 1)", rd_run_max);

    if (errors == 0) $display("TB_RESULT: PASS");
    else begin
      $display("%0d errors", errors);
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

  initial begin
    #20000000;
    $display("TIMEOUT");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
