/**************************************************************************
** TESTBENCH: ND_SMD - ECC / single-write (NO flip-flop) register model   **
**                                                                       **
** The counterpart to nd_smd_iox_tb.v (which pins the 15 MHz two-write    **
** card). This one leaves HAS_WC_FLIPFLOP at its DEFAULT (0 = ECC /       **
** BIG-DISC), so the Core Address and Word Counter registers load their   **
** full value in a SINGLE write and read back in a single read - there is **
** no HI/LO flip-flop phase. Core Address bits 16-17 come from control-   **
** word bits 5-6 instead of a second write.                              **
**                                                                       **
** The point of this tb is the MASS-STORAGE BOOT primitive: the ND-120    **
** microcode (CSA o2217) writes the Word Counter register ONCE with       **
** 002000 (octal) = 1024. On the flip-flop card that single write lands   **
** in the HI byte (002000 & 0xFF == 0) and the count stays 0, so the GO   **
** transfers nothing. On THIS single-write card the one write loads the   **
** full 1024-word count - which is exactly what makes the SMD image boot. **
**                                                                       **
** Like the IOX conformance tb, NO command is ever GO'd (control bit 2    **
** stays 0), so the transfer engine never leaves E_IDLE and no DMA / disk **
** backend is needed. The full-stack DMA transfer is covered by           **
** nd_smd_tb.v; the flip-flop readback matrix by nd_smd_iox_tb.v.         **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
**                                                                       **
** Ronny Hansen                                                          **
***************************************************************************/

`timescale 1ns / 1ps

module nd_smd_ecc_tb;

  localparam [15:0] BASE = 16'o001540;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  always #10 sysclk = ~sysclk;

  // ---- DUT IOX slave side ----
  reg  [15:0] iox_addr  = 16'd0;
  reg         iox_wr    = 1'b0;
  reg  [15:0] iox_wdata = 16'd0;
  reg         iox_rd    = 1'b0;
  wire [15:0] iox_rdata;
  wire [3:0]  int_pending;
  reg         ident_strobe   = 1'b0;
  reg  [3:0]  ident_level    = 4'd0;
  reg         ident_grant_in = 1'b0;
  wire        ident_grant_out;
  wire        ident_hit;
  wire [15:0] ident_code;

  // ---- DMA + disk backend left idle (no GO is ever issued) ----
  wire        dma_req, dma_wr;
  wire [23:0] dma_addr;
  wire [15:0] dma_wdata;
  wire        disk_start, disk_req, disk_wr;
  wire [15:0] disk_blkaddr1, disk_blkaddr2;
  wire [2:0]  disk_unit;
  wire [10:0] disk_wordcount;
  wire [15:0] dbuf_rdata;

  // DEFAULT parameters -> HAS_WC_FLIPFLOP = 0 (the ECC / single-write card).
  ND_SMD dut (
      .sysclk        (sysclk),
      .sys_rst_n     (sys_rst_n),
      .iox_addr      (iox_addr),
      .iox_wr        (iox_wr),
      .iox_wdata     (iox_wdata),
      .iox_rd        (iox_rd),
      .iox_rdata     (iox_rdata),
      .int_pending   (int_pending),
      .ident_strobe  (ident_strobe),
      .ident_level   (ident_level),
      .ident_grant_in(ident_grant_in),
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

  // ---- checking ----
  integer errors = 0;
  task check(input cond, input [1023:0] msg);
    begin
      if (!cond) begin
        errors = errors + 1;
        $display("  FAIL: %0s", msg);
      end
    end
  endtask

  // IOX read held HIGH across one posedge. On the single-write card the +0
  // read has NO flip-flop side effect, so the value is stable read-to-read;
  // we still clock one edge to match a real IOX strobe.
  task iox_read(input [15:0] a, output [15:0] d);
    begin
      @(negedge sysclk);
      iox_addr = a;
      iox_rd   = 1'b1;
      #1 d = iox_rdata;
      @(posedge sysclk);
      @(negedge sysclk);
      iox_rd   = 1'b0;
    end
  endtask

  // clocked IOX write (one full cycle, like a real IOX store)
  task iox_write(input [15:0] a, input [15:0] data);
    begin
      @(negedge sysclk);
      iox_addr  = a;
      iox_wdata = data;
      iox_wr    = 1'b1;
      @(negedge sysclk);
      iox_wr    = 1'b0;
    end
  endtask

  // A non-GO Load Control Word (b2 = 0): leave boot mode, pick CWR + unit.
  // unit 0..3 (b9 = 0) selects a disk. bits 5-6 = core-address 16-17 on the
  // single-write card (passed through so the addr-hi routing can be checked).
  task ctrl_word(input cwr, input [1:0] addr_hi, input [2:0] unit);
    reg [15:0] cw;
    begin
      cw       = 16'd0;
      cw[6:5]  = addr_hi;
      cw[9:7]  = unit;
      cw[15]   = cwr;
      iox_write(BASE + 16'd5, cw);
    end
  endtask

  reg [15:0] r, r2;

  initial begin
    sys_rst_n = 1'b0;
    repeat (4) @(negedge sysclk);
    sys_rst_n = 1'b1;
    repeat (2) @(negedge sysclk);

    // =================================================================
    // 1. Boot mode at reset is strap-independent: +2 returns the boot
    //    status form (RFT in b3 = 0x0008).
    // =================================================================
    iox_read(BASE + 16'd2, r);
    check(r === 16'h0008, "boot: +2 status form must have RFT in b3 (0x0008)");

    // =================================================================
    // 2. First Load Control Word leaves boot mode + selects unit 0.
    //    status: b14 on-cyl=1, b3 RFT=1 -> 0x4008.
    // =================================================================
    ctrl_word(1'b0, 2'd0, 3'd0);
    iox_read(BASE + 16'd4, r);
    check(r === 16'h4008, "select unit0: status must be 0x4008");

    // =================================================================
    // 3. Core Address is a SINGLE write: ONE +1 write loads the full 16
    //    bits, and the +0 read (CWR=0) returns it - the SAME value on a
    //    second read (there is NO HI phase / no mar_ff toggle).
    // =================================================================
    iox_write(BASE + 16'd1, 16'hCDEF);   // ONE write loads the full LO 16
    iox_read (BASE + 16'd0, r);          // read returns the full value
    iox_read (BASE + 16'd0, r2);         // second read: SAME value (no toggle)
    check(r  === 16'hCDEF, "single-write core addr readback must be 0xCDEF");
    check(r2 === 16'hCDEF, "single-write core addr must NOT alternate to a HI byte");

    // =================================================================
    // 4. Word Counter is a SINGLE write: ONE +7 write (CWR=0) loads the
    //    full 16 bits; switch CWR=1 and +0 returns it, stable read-to-read.
    // =================================================================
    ctrl_word(1'b0, 2'd0, 3'd0);         // ensure CWR=0 for Load Word Counter
    iox_write(BASE + 16'd7, 16'h3456);   // ONE +7 write loads the full count
    ctrl_word(1'b1, 2'd0, 3'd0);         // CWR=1 to read the Word Counter on +0
    iox_read (BASE + 16'd0, r);
    iox_read (BASE + 16'd0, r2);
    check(r  === 16'h3456, "single-write word count readback must be 0x3456");
    check(r2 === 16'h3456, "single-write word count must NOT alternate to a HI byte");

    // =================================================================
    // 5. THE BOOT PRIMITIVE. The mass-storage microcode writes the Word
    //    Counter ONCE with 002000 (octal) = 1024. On this single-write
    //    card that one write loads the full 1024, NOT 0. This is the whole
    //    reason the SMD image boots.
    // =================================================================
    ctrl_word(1'b0, 2'd0, 3'd0);         // CWR=0 = Load Word Counter
    iox_write(BASE + 16'd7, 16'o002000); // the microcode's single boot write
    ctrl_word(1'b1, 2'd0, 3'd0);         // CWR=1 to read it back
    iox_read (BASE + 16'd0, r);
    check(r === 16'o002000, "BOOT: single +7 write of 002000 must load 1024, not 0");

    // =================================================================
    // 6. ECC Control (+7, CWR=1) is also a single write: one write with
    //    bit 1 set forces a hardware (parity) error -> status b7. On the
    //    flip-flop card this needs a second (LO) write; here one suffices.
    // =================================================================
    iox_write(BASE + 16'd7, 16'h0002);   // ONE ECC-control write, force-parity
    ctrl_word(1'b0, 2'd0, 3'd0);         // back to CWR=0 to read the status
    iox_read (BASE + 16'd4, r);
    check(r[7] === 1'b1, "single-write ECC control (bit1) must set status b7 in ONE write");

    // ---- verdict ----
    if (errors == 0) $display("TB_RESULT: PASS");
    else begin
      $display("%0d errors", errors);
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

  // global watchdog
  initial begin
    #5000000;
    $display("TIMEOUT");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
