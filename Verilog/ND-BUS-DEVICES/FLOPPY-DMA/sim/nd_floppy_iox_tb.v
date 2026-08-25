/**************************************************************************
** TESTBENCH: ND_FLOPPY_DMA - IOX register / status / control conformance **
**  (floppy campaign phase P1 - CONFORMANCE.md sec 9 item 3)             **
**                                                                       **
** Asserts the register/status/control MATRIX of CONFORMANCE.md sec 1-3  **
** and sec 6 directly at the device IOX slave interface. This is a       **
** UNIT test of ND_FLOPPY_DMA in isolation: the DUT's iox_* port is      **
** driven directly (NOT through ND_BUS_SLAVE) so the register semantics  **
** are checked without any bus-strobe timing in the way - the strobe     **
** width / boot-consume behaviour is P2's job (CONFORMANCE.md sec 9.4,   **
** via ND_BUS_SLAVE).                                                    **
**                                                                       **
** Scaffolding kept deliberately minimal:                               **
**   - a trivial DMA responder (acks every dma_req one cycle later with  **
**     rdata 0, never busy/err) so the command-block fetch address can   **
**     be observed - this is the only way to prove the +5/+7 pointer     **
**     registers latch and that +5 is byte-masked (sec 1 pointer rows).  **
**   - the disk backend is left idle (disk_done never asserts) so a boot **
**     activate parks in E_DISK_RD with active=1/rft=0 - exactly the     **
**     register state we want to observe, then recover by device-clear.  **
**                                                                       **
** Matrix covered (origin tags reference CONFORMANCE.md):               **
**   sec1 +0 idle constant = 1; +1/+5/+6/+7 read = 0; +2 == +4 (Note 1); **
**        +5 pointer HIGH byte-masked, +7 pointer LOW -> CB fetch addr    **
**   sec2 hardware status word bit layout: b15 dualDensity ALWAYS 1,     **
**        b3 RFT, b2 active, b1 intEnabled; RFT=1 at power-on (the       **
**        DEVIATE vs the C oracle - asserted "our way" per sec 9.3)      **
**   sec3 control word: b1 int-enable stored every write; b4 device      **
**        clear -> RFT=1/active=0/err=0 and leaves boot mode             **
**   sec6 interrupt is level-sensitive (enabled && RFT); IDENT answers   **
**        level 11 code 021 and clears the enable bit                    **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
**                                                                       **
** Last reviewed: 25-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

`timescale 1ns / 1ps

module nd_floppy_iox_tb;

  // device base address + ident (must match ND_FLOPPY_DMA defaults)
  localparam [15:0] BASE = 16'o001560;
  localparam [15:0] IDENT = 16'o000021;   // octal 21 = 0x0011

  reg sysclk = 0;
  reg sys_rst_n = 0;
  always #10 sysclk = ~sysclk;

  // ---- DUT IOX slave side (driven directly by the tb) ----
  reg  [15:0] iox_addr = 16'd0;
  reg         iox_wr   = 1'b0;
  reg  [15:0] iox_wdata= 16'd0;
  reg         iox_rd   = 1'b0;
  wire [15:0] iox_rdata;
  wire [3:0]  int_pending;
  reg         ident_strobe   = 1'b0;
  reg  [3:0]  ident_level    = 4'd0;
  reg         ident_grant_in = 1'b0;
  wire        ident_grant_out;
  wire        ident_hit;
  wire [15:0] ident_code;

  // ---- DMA master client port (tb responder) ----
  wire        dma_req;
  wire        dma_wr;
  wire [23:0] dma_addr;
  wire [15:0] dma_wdata;
  reg  [15:0] dma_rdata = 16'd0;
  reg         dma_ack   = 1'b0;
  reg         dma_err   = 1'b0;
  reg         dma_busy  = 1'b0;

  // ---- disk backend (left idle: never completes) ----
  wire        disk_req;
  wire        disk_wr;
  wire [15:0] disk_lsect;
  wire [1:0]  disk_format;
  wire [1:0]  disk_drive;
  wire [10:0] disk_wordcount;
  reg         disk_done    = 1'b0;
  reg         disk_err_in  = 1'b0;
  reg  [3:0]  disk_media_fmt = 4'b1111;
  wire [15:0] dbuf_rdata;

  ND_FLOPPY_DMA dut (
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
      .dma_rdata     (dma_rdata),
      .dma_ack       (dma_ack),
      .dma_err       (dma_err),
      .dma_busy      (dma_busy),
      .disk_req      (disk_req),
      .disk_wr       (disk_wr),
      .disk_lsect    (disk_lsect),
      .disk_format   (disk_format),
      .disk_drive    (disk_drive),
      .disk_wordcount(disk_wordcount),
      .disk_done     (disk_done),
      .disk_err_in   (disk_err_in),
      .disk_media_fmt(disk_media_fmt),
      .dbuf_addr     (10'd0),
      .dbuf_wdata    (16'd0),
      .dbuf_we       (1'b0),
      .dbuf_rdata    (dbuf_rdata)
  );

  // ---- trivial DMA responder + first-address capture -------------------
  // ND_FLOPPY_DMA issues a one-clock dma_req pulse and waits for dma_ack.
  // Ack one cycle later, rdata = 0, never busy/err. cap_arm latches the
  // FIRST dma_addr seen (the E_CB_FETCH pointer) so the pointer registers
  // can be verified - there is no register readback for them.
  reg        cap_arm  = 1'b0;
  reg        cap_done = 1'b0;
  reg [23:0] cap_addr = 24'd0;
  always @(posedge sysclk) begin
    dma_ack <= 1'b0;
    if (dma_req && !dma_ack) begin
      dma_ack   <= 1'b1;
      dma_rdata <= 16'd0;
    end
    if (dma_req && cap_arm && !cap_done) begin
      cap_addr <= dma_addr;
      cap_done <= 1'b1;
      cap_arm  <= 1'b0;
    end
  end

  // ---- checking ---------------------------------------------------------
  integer errors = 0;
  task check(input cond, input [1023:0] msg);
    begin
      if (!cond) begin
        errors = errors + 1;
        $display("  FAIL: %0s", msg);
      end
    end
  endtask

  // combinational IOX read: assert address+rd, sample, release - deliberately
  // held for less than a clock so a boot-mode +0 read cannot double-consume
  // (that strobe-width interaction is P2's concern, not this test's).
  task iox_read(input [15:0] a, output [15:0] d);
    begin
      @(negedge sysclk);
      iox_addr = a;
      iox_rd   = 1'b1;
      #1 d = iox_rdata;
      iox_rd   = 1'b0;
    end
  endtask

  // clocked IOX write (one cycle, like a real IOX store)
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

  reg [15:0] r;

  initial begin
    // ---- reset ----
    sys_rst_n = 1'b0;
    repeat (4) @(negedge sysclk);
    sys_rst_n = 1'b1;
    repeat (2) @(negedge sysclk);

    // =================================================================
    // sec2: hardware status word at power-on (RFT=1 "our way")
    //   b15 dualDensity=1, b3 RFT=1, b2 active=0, b1 intEnabled=0
    //   => 16'b1000_0000_0000_1000 = 16'h8008
    // =================================================================
    iox_read(BASE + 16'd2, r);
    check(r === 16'h8008, "+2 power-on hwstat must be 0x8008 (b15 dd=1, b3 rft=1)");
    check(r[15] === 1'b1, "sec2: b15 dualDensity must be 1 (SINTRAN 3112 detect)");
    check(r[3]  === 1'b1, "sec2: b3 RFT must be 1 at power-on (DEVIATE vs oracle)");
    check(r[2]  === 1'b0, "sec2: b2 active must be 0 at power-on");
    check(r[1]  === 1'b0, "sec2: b1 intEnabled must be 0 at power-on");

    // sec1 Note 1: +2 and +4 return the SAME hardware status word
    iox_read(BASE + 16'd4, r);
    check(r === 16'h8008, "+4 must equal +2 (sec1 Note 1: same status word)");

    // =================================================================
    // sec1: +0 idle constant = 1; +1/+5/+6/+7 read = 0
    // =================================================================
    iox_read(BASE + 16'd0, r);
    check(r === 16'd1, "+0 read (idle) must be constant 1");
    iox_read(BASE + 16'd1, r);
    check(r === 16'd0, "+1 read must be 0");
    iox_read(BASE + 16'd5, r);
    check(r === 16'd0, "+5 read must be 0");
    iox_read(BASE + 16'd6, r);
    check(r === 16'd0, "+6 read must be 0");
    iox_read(BASE + 16'd7, r);
    check(r === 16'd0, "+7 read must be 0");

    // =================================================================
    // sec3: control word b1 int-enable is stored on EVERY write and shows
    //       through hwstat b1
    // =================================================================
    iox_write(BASE + 16'd3, 16'h0002);       // b1 = 1
    iox_read (BASE + 16'd2, r);
    check(r === 16'h800A, "sec3: +3 b1=1 must set hwstat b1 (0x800A)");
    iox_write(BASE + 16'd3, 16'h0000);       // b1 = 0
    iox_read (BASE + 16'd2, r);
    check(r === 16'h8008, "sec3: +3 b1=0 must clear hwstat b1 (0x8008)");

    // =================================================================
    // sec6: interrupt is level-sensitive (pending = enabled && RFT). At
    //       power-on RFT=1, so enabling interrupts alone raises the level-11
    //       request immediately. int_pending mapping = {L13,L12,L11,L10};
    //       INT_LEVEL=11 -> bit[1].
    // =================================================================
    iox_write(BASE + 16'd3, 16'h0002);       // enable interrupt, RFT still 1
    @(negedge sysclk);
    check(int_pending === 4'b0010, "sec6: enable+RFT must assert level-11 int_pending");

    // IDENT: level 11, grant in -> answer with code 021, and clear enable
    @(negedge sysclk);
    ident_level    = 4'd11;
    ident_grant_in = 1'b1;
    ident_strobe   = 1'b1;
    #1;
    check(ident_hit  === 1'b1,  "sec6: IDENT must hit on level 11 while pending");
    check(ident_code === IDENT, "sec6: IDENT code must be 021 (octal)");
    @(negedge sysclk);                       // clock the enable-clear
    ident_strobe   = 1'b0;
    ident_grant_in = 1'b0;
    @(negedge sysclk);
    check(int_pending === 4'b0000, "sec6: IDENT must clear the enable bit (int gone)");

    // =================================================================
    // sec1 pointer rows: +5 pointer HIGH (byte-masked) + +7 pointer LOW
    //   latch and drive the command-block fetch address. Observe via the
    //   first DMA request of an execute, then abort with device-clear.
    // =================================================================
    // ptr = 0x00AB_CDEF: +5 = 0x00AB (hi byte 0xAB), +7 = 0xCDEF
    iox_write(BASE + 16'd5, 16'h00AB);
    iox_write(BASE + 16'd7, 16'hCDEF);
    cap_done = 1'b0; cap_arm = 1'b1;
    iox_write(BASE + 16'd3, 16'h0100);       // b8 = execute
    wait (cap_done);
    check(cap_addr === 24'hABCDEF, "sec1: CB-fetch addr must be {ptrHi,ptrLo} = 0xABCDEF");
    iox_write(BASE + 16'd3, 16'h0010);       // b4 device clear (abort)
    repeat (3) @(negedge sysclk);

    // +5 byte-mask: write 0x01FF -> only low byte 0xFF is kept, so the fetch
    // address high byte is 0xFF (not 0x01FF worth of address).
    iox_write(BASE + 16'd5, 16'h01FF);
    iox_write(BASE + 16'd7, 16'h0000);
    cap_done = 1'b0; cap_arm = 1'b1;
    iox_write(BASE + 16'd3, 16'h0100);       // execute
    wait (cap_done);
    check(cap_addr[23:16] === 8'hFF, "sec1: +5 must be byte-masked (hi=0xFF, junk bits dropped)");
    check(cap_addr[15:0]  === 16'h0000, "sec1: +7=0 -> low half of fetch addr 0");
    iox_write(BASE + 16'd3, 16'h0010);       // device clear
    repeat (3) @(negedge sysclk);

    // =================================================================
    // sec3: b2 boot activate register effect + device-clear recovery.
    //   Activate from idle -> active=1, rft=0 (parks in E_DISK_RD; the disk
    //   backend never completes here). Device clear returns to idle and
    //   leaves boot mode, so +0 reads the idle constant 1 again (not stale
    //   buffer).
    // =================================================================
    iox_write(BASE + 16'd3, 16'h0004);       // b2 = activate autoload
    @(negedge sysclk);
    iox_read(BASE + 16'd2, r);
    check(r[2] === 1'b1, "sec3: boot activate must set active (b2)");
    check(r[3] === 1'b0, "sec3: boot activate must clear RFT (b3) until chunk ready");

    iox_write(BASE + 16'd3, 16'h0010);       // b4 device clear
    @(negedge sysclk);
    iox_read(BASE + 16'd2, r);
    check(r === 16'h8008, "sec3: device clear -> idle hwstat 0x8008 (rft=1,active=0)");
    iox_read(BASE + 16'd0, r);
    check(r === 16'd1, "sec3: +0 after clear must return idle 1 (boot mode left)");

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
