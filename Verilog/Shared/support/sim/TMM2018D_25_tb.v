/****************************************************************************
** TMM2018D_25 (2048 x 8 SRAM) testbench                                   **
**                                                                         **
** Two build modes exist in the RTL, selected by `TMM_ASYNC_READ`:         **
**   default (undefined) - SYNCHRONOUS read: data_out_reg is captured in   **
**     `always @(posedge clk)` when !CS_n && W_n (read mode), and D_OUT    **
**     multiplexes data_out_reg -> ONE CLOCK of latency.                   **
**   `TMM_ASYNC_READ` defined - D_OUT reads tmm_memory_array[ADDRESS]      **
**     DIRECTLY and combinationally -> ZERO latency, address-driven.       **
** This testbench compiles and self-selects its checks with the SAME       **
** `ifdef TMM_ASYNC_READ` the RTL uses, so it is valid for BOTH builds.     **
**                                                                         **
** THE REAL TMM2018D IS AN ASYNCHRONOUS SRAM (no clock pin on the real      **
** part). The default build here (sync) is a DELIBERATE, DOCUMENTED        **
** deviation for FPGA block-RAM inference - see the RTL's own comment at   **
** TMM2018D_25.v lines 68-73, which names the exact failure mode (PAGING   **
** test 3 / Issue D: a one-clock-stale read when the address changes just  **
** before the consuming edge). This testbench does not take a position on **
** which mode is "correct" - it tests whichever mode was compiled in.      **
**                                                                         **
** D_OUT mask expression (both modes): `(!OE_n & !CS_n & W_n) ? ... : 0`.  **
** NOTE: there is NO reset_n term in this expression, unlike Am9150 (whose **
** data_out mask DOES include RESET_n). reset_n here only gates the        **
** internal sequential block (freezes writes/reads, same empty-branch      **
** pattern as the other SRAM models in this directory) - it does not       **
** force D_OUT to 0 and does not clear the memory array. Both properties   **
** are checked explicitly below (this is the finding to report).          **
**                                                                         **
** COVERAGE: address 0, address 2047 (max), 4 scattered addresses,         **
** no-aliasing, read-during-write, and each of CS_n/OE_n/W_n forcing       **
** D_OUT=0 individually (checked with known nonzero data underneath).      **
**                                                                         **
** Run (sync, default):                                                    **
**   cd Verilog/Shared/support/sim && iverilog -g2012 -o tb.vvp            **
**   TMM2018D_25_tb.v ../TMM2018D_25.v && vvp tb.vvp                      **
** Run (async):                                                            **
**   iverilog -g2012 -DTMM_ASYNC_READ -o tb.vvp                           **
**   TMM2018D_25_tb.v ../TMM2018D_25.v && vvp tb.vvp                      **
**                                                                         **
** Last reviewed: 20-AUG-2026                                             **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module TMM2018D_25_tb;

  reg         clk = 0;
  always #5 clk = ~clk;

  reg         reset_n;
  reg  [10:0] ADDRESS;
  reg         CS_n;
  reg         OE_n;
  reg         W_n;
  reg  [7:0]  D;
  wire [7:0]  D_OUT;

  integer errors = 0;
  integer checks = 0;

  TMM2018D_25 DUT (
      .clk    (clk),
      .reset_n(reset_n),
      .ADDRESS(ADDRESS),
      .CS_n   (CS_n),
      .OE_n   (OE_n),
      .W_n    (W_n),
      .D      (D),
      .D_OUT  (D_OUT)
  );

  task do_write(input [10:0] addr, input [7:0] val);
    begin
      ADDRESS = addr; D = val;
      reset_n = 1; CS_n = 0; W_n = 0; OE_n = 1;
      @(posedge clk); #1;
      W_n = 1;
    end
  endtask

  // Read: set up address/enables, then wait for the read to become visible
  // in whichever mode was compiled (0 clocks async, 1 clock sync).
  task expect_read(input [10:0] addr, input [7:0] expected, input [255:0] label);
    begin
      ADDRESS = addr;
      reset_n = 1; CS_n = 0; W_n = 1; OE_n = 0;
`ifdef TMM_ASYNC_READ
      #1;
`else
      @(posedge clk); #1;
`endif
      checks = checks + 1;
      if (D_OUT !== expected) begin
        errors = errors + 1;
        $display("FAIL %0s: addr=%0d D_OUT=%02h expected %02h", label, addr, D_OUT, expected);
      end
    end
  endtask

  initial begin
`ifdef TMM_ASYNC_READ
    $dumpfile("TMM2018D_25_async_tb.vcd");
    $dumpvars(0, TMM2018D_25_tb);
    $display("TMM2018D_25 testbench: ASYNC READ build (TMM_ASYNC_READ defined)");
`else
    $dumpfile("TMM2018D_25_sync_tb.vcd");
    $dumpvars(0, TMM2018D_25_tb);
    $display("TMM2018D_25 testbench: SYNC READ build (default)");
`endif

    reset_n = 0; ADDRESS = 0; CS_n = 1; OE_n = 1; W_n = 1; D = 0;
    @(posedge clk); @(posedge clk); #1;
    reset_n = 1;
    @(posedge clk); #1;

    // ---- short documented sequence (readable in the VCD) ------------------
    do_write(11'd0, 8'hA5);
    expect_read(11'd0, 8'hA5, "doc: addr0=A5");
    do_write(11'd2047, 8'h3C);
    expect_read(11'd2047, 8'h3C, "doc: addr2047=3C");

    $dumpoff;

    // ---- 1. address 0 --------------------------------------------------------
    do_write(11'd0, 8'h11);
    expect_read(11'd0, 8'h11, "addr 0 = 11");

    // ---- 2. address 2047 (max) ------------------------------------------------
    do_write(11'd2047, 8'hFE);
    expect_read(11'd2047, 8'hFE, "addr 2047 = FE");

    // ---- 3. scattered arbitrary addresses --------------------------------------
    do_write(11'd1, 8'h22);
    do_write(11'd1000, 8'h33);
    do_write(11'd2046, 8'h44);
    do_write(11'd777, 8'h55);
    expect_read(11'd1, 8'h22, "addr 1 = 22");
    expect_read(11'd1000, 8'h33, "addr 1000 = 33");
    expect_read(11'd2046, 8'h44, "addr 2046 = 44");
    expect_read(11'd777, 8'h55, "addr 777 = 55");

    // ---- 4. no aliasing ---------------------------------------------------------
    expect_read(11'd2047, 8'hFE, "addr 2047 still FE (unaffected by 2046 write)");
    do_write(11'd2046, 8'h00);
    expect_read(11'd2047, 8'hFE, "addr 2047 STILL FE after flipping 2046 to 00");
    expect_read(11'd2046, 8'h00, "addr 2046 = 00 as just written");

    // Also check addresses 1024 apart (the top address bit) - catches a
    // truncated/dropped MSB in the array index that neighbour-only checks
    // above would miss.
    do_write(11'd100, 8'h91);
    do_write(11'd1124, 8'h6E);   // 100 + 1024
    expect_read(11'd100, 8'h91, "addr 100 = 91 (top-bit-apart pair)");
    expect_read(11'd1124, 8'h6E, "addr 1124 = 6E, independent of addr 100 despite sharing low 10 bits");

    // ---- 5. read-during-write: W_n=0 forces D_OUT=0 -----------------------------
    do_write(11'd0, 8'hAB);
    ADDRESS = 11'd0; D = 8'hCD; reset_n = 1; CS_n = 0; W_n = 0; OE_n = 0;
    #1;
    checks = checks + 1;
    if (D_OUT !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL READ_DURING_WRITE: D_OUT=%02h while W_n=0, expected 00 (masked)", D_OUT);
    end
    @(posedge clk); #1;
    // NOTE: the D=8'hCD, W_n=0 setup above was still active AT the clock
    // edge we just waited through, so that edge performed a REAL write of
    // CD (not AB) into address 0 - the "masked" sample before the edge was
    // read-during-write, but the edge itself commits whatever D/W_n were
    // holding at that instant. Expected value is therefore CD, not the
    // earlier AB.
    W_n = 1;
    expect_read(11'd0, 8'hCD, "addr 0 = CD (the write in progress during the masked sample committed at the edge)");

    // ---- 6. output-mask terms, forced individually -------------------------------
    do_write(11'd10, 8'hD7);
    ADDRESS = 11'd10; W_n = 1; reset_n = 1;

    CS_n = 1; OE_n = 0;
`ifdef TMM_ASYNC_READ
    #1;
`else
    @(posedge clk); #1;
`endif
    checks = checks + 1;
    if (D_OUT !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL MASK_CS_n: D_OUT=%02h with CS_n=1, expected 00", D_OUT);
    end

    CS_n = 0; OE_n = 1;
`ifdef TMM_ASYNC_READ
    #1;
`else
    @(posedge clk); #1;
`endif
    checks = checks + 1;
    if (D_OUT !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL MASK_OE_n: D_OUT=%02h with OE_n=1, expected 00", D_OUT);
    end

    // ---- 7. reset_n: freezes read/write, does NOT gate D_OUT directly, -----------
    //        and does NOT clear the memory array.
    expect_read(11'd10, 8'hD7, "addr 10 = D7 (before reset probe)");
    reset_n = 0;
    ADDRESS = 11'd10; CS_n = 0; W_n = 0; D = 8'h00;   // would-be write, blocked
    @(posedge clk); @(posedge clk); #1;
    // Switch to the READ stance (W_n=1) so the D_OUT mask term is
    // satisfied - this does NOT let data_out_reg update because reset_n is
    // still 0 (that update is fully gated by !reset_n at RTL level), it
    // only lets us OBSERVE whatever data_out_reg is currently holding.
    W_n = 1;
    #1;
    checks = checks + 1;
`ifdef TMM_ASYNC_READ
    // async mode: D_OUT has no reset_n term and reads the array directly,
    // so it is unaffected by reset_n regardless of the frozen write.
    if (D_OUT !== 8'hD7) begin
      errors = errors + 1;
      $display("FAIL RESET_NO_DOUT_GATE_ASYNC: D_OUT=%02h while reset_n=0, expected D7 (no reset_n term in D_OUT mask)", D_OUT);
    end
`else
    // sync mode: reset_n=0 freezes data_out_reg from updating, but does not
    // force it or D_OUT to 0 - the register still shows whatever it last
    // held (D7 from the read above), and D_OUT is not masked by reset_n.
    if (D_OUT !== 8'hD7) begin
      errors = errors + 1;
      $display("FAIL RESET_NO_DOUT_GATE_SYNC: D_OUT=%02h while reset_n=0, expected D7 held in data_out_reg", D_OUT);
    end
`endif
    reset_n = 1; W_n = 1;
    expect_read(11'd10, 8'hD7, "addr 10 STILL D7: reset_n held during an attempted write, write did NOT happen");

    $display("-----------------------------------------------------");
    $display(" TMM2018D_25 testbench");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $finish;
  end

  initial begin
    #100000;
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire
