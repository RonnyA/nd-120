/**************************************************************************
** ND120 Shared                                                          **
** SC2661 UART - receive-register overrun regression                    **
**                                                                       **
** 31-AUG-2026. regReceiveHoldingRegister used to be both the live       **
** shift-in register AND the CPU-visible holding register. A new start   **
** bit cleared it immediately, then shifted the incoming byte in live -  **
** a CPU read landing mid-shift got a torn value matching neither the    **
** old nor the new byte. Measured on real hardware: "PED\r" sent with no **
** inter-character gap landed at the ND-120 as a single byte 0x28 '(' -  **
** not P, E, D or CR. Fixed by adding a separate regRxShift register and **
** only transferring a complete byte into the CPU-visible register       **
** atomically at end-of-frame.                                           **
**                                                                       **
** Uses local loopback (TXD internally wired to RXD) to drive real       **
** back-to-back receive frames with zero gap, same as the failure.       **
**                                                                       **
** TEST 1: one character, read before the next one starts - must read    **
**         back exactly what was sent, no overrun flagged.               **
** TEST 2: two characters back-to-back, held WITHOUT reading the first - **
**         RHR must end up holding the SECOND byte exactly (not torn,    **
**         not the first byte), and Overrun (status bit 4) must be set.  **
** TEST 3: read RHR repeatedly WHILE the second byte is still shifting   **
**         in (the actual failure mode: a CPU read landing mid-frame).   **
**         Every value seen before the frame completes must be either   **
**         the first byte, unchanged - never a value that is neither    **
**         byte (the pre-fix bug cleared RHR at the new start bit, then  **
**         built the torn value live in the same register the CPU reads).**
**                                                                       **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL (run_all_tests.sh entry     **
** test-uart-rxoverrun).                                                 **
***************************************************************************/
`timescale 1ns / 1ps

module SC2661_RX_OVERRUN_tb;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  reg [1:0] address = 2'b00;
  reg reset = 0;
  reg ce_n = 1;
  reg read_n = 1;      // 1 = write access when chip enabled
  reg [7:0] d_in = 8'h00;

  wire [7:0] d_out;
  wire rxdrdy_n, txdrdy_n, txemt_n;

  integer errors = 0;

  // No defines -> DELAY_FRAMES = 100e6/115200 = 868 clocks/bit (see other UART tbs).
  localparam integer BITCLKS = 868;
  localparam integer FRAMECLKS = 10 * BITCLKS; // start + 8 data + stop

  SC2661_UART dut (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .ADDRESS(address),
      .BRCLK(1'b0),
      .RESET(reset),
      .CE_n(ce_n),
      .READ_n(read_n),
      .CTS_n(1'b0),
      .DCD_n(1'b0),
      .DSR_n(1'b0),
      .DTR_n(),
      .RTS_n(),
      .D(d_in),
      .D_OUT(d_out),
      .RXC_n(1'b0),
      .RXD(1'b1),   // unused: local loopback feeds TXD -> receiver internally
      .RXDRDY_n(rxdrdy_n),
      .TXC_n(1'b0),
      .TXD(),
      .TXDRDY_n(txdrdy_n),
      .TXEMT_n(txemt_n)
  );

  always #5 sysclk = ~sysclk;

  task uart_write(input [1:0] a, input [7:0] v);
    begin
      @(negedge sysclk);
      address = a; d_in = v; read_n = 1; ce_n = 0;
      @(negedge sysclk);
      ce_n = 1;
      @(negedge sysclk);
    end
  endtask

  task uart_read(input [1:0] a, output [7:0] v);
    begin
      @(negedge sysclk);
      address = a; read_n = 0; ce_n = 0;
      @(negedge sysclk);
      v = d_out;
      ce_n = 1;
      read_n = 1;
      @(negedge sysclk);
    end
  endtask

  reg [7:0] rhr;
  reg [7:0] status;

  initial begin
    // reset
    repeat (4) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (4) @(negedge sysclk);

    // Command register: TxEN=bit0, RxEN=bit2, OperatingMode=bits7:6=10 (Local Loopback)
    uart_write(2'b11, 8'b1000_0101);
    repeat (8) @(negedge sysclk);

    // ---- TEST 1: single char, read before the next one starts
    uart_write(2'b00, 8'h41); // THR = 'A'
    // one full TX frame + one full RX frame to land in RHR, plus margin
    repeat (2 * FRAMECLKS + 4 * BITCLKS) @(posedge sysclk);

    uart_read(2'b01, status);
    if (status[1] !== 1'b1) begin
      $display("TEST1 FAIL: RXRDY not set after one character (status=%02x)", status);
      errors = errors + 1;
    end else begin
      uart_read(2'b00, rhr);
      if (rhr === 8'h41 && status[4] === 1'b0) begin
        $display("TEST1 PASS: single char round-tripped clean (got=%02x, overrun=%0d)", rhr, status[4]);
      end else begin
        $display("TEST1 FAIL: got=%02x overrun=%0d (expected 41, 0)", rhr, status[4]);
        errors = errors + 1;
      end
    end

    repeat (4 * BITCLKS) @(posedge sysclk);

    // ---- TEST 2: two chars back-to-back, RHR never read until both are
    // fully done. Queue 'B' then 'D' one right after the other via THR,
    // polling TxRDY (status bit0) so the second write lands the instant
    // the transmitter accepts it - reproducing the zero-gap "PED\r" burst.
    uart_write(2'b00, 8'h42); // THR = 'B'
    // wait for TxRDY (THR empty again, i.e. shifted into the tx shift reg)
    status = 8'h00;
    while (status[0] !== 1'b1) begin
      uart_read(2'b01, status);
    end
    uart_write(2'b00, 8'h44); // THR = 'D', queued back-to-back with no gap

    // let both frames fully transmit and receive, no reads in between
    repeat (3 * FRAMECLKS + 4 * BITCLKS) @(posedge sysclk);

    uart_read(2'b01, status);
    uart_read(2'b00, rhr);

    if (rhr === 8'h44 && status[4] === 1'b1) begin
      $display("TEST2 PASS: RHR holds the LAST byte (44) clean, Overrun flagged (status=%02x)", status);
    end else begin
      $display("TEST2 FAIL: got=%02x status=%02x (expected 44 with overrun bit4 set, pre-fix RTL produced a torn value matching neither B nor D)", rhr, status);
      errors = errors + 1;
    end

    repeat (4 * BITCLKS) @(posedge sysclk);

    // ---- TEST 3: a FRESH byte pair ('X' then 'Y'), this time polling RHR
    // repeatedly WHILE the second byte is still shifting in - the actual
    // failure mode measured on hardware: a CPU read landing mid-frame.
    // The pre-fix RTL cleared regReceiveHoldingRegister the instant the
    // new start bit arrived, then shifted bits into that SAME CPU-visible
    // register live, so a read mid-shift saw neither the old nor the new
    // byte. Every read here (which itself clears RXRDY, same as real CPU
    // polling) must return a whole byte, never a torn value.
    uart_write(2'b00, 8'h58); // THR = 'X'
    status = 8'h00;
    while (status[0] !== 1'b1) begin
      uart_read(2'b01, status);
    end
    uart_write(2'b00, 8'h59); // THR = 'Y', queued back-to-back with no gap

    begin : t3
      integer i;
      reg [7:0] v;
      reg torn;
      torn = 0;
      // second RX frame starts roughly one TX-frame-time after the first
      // THR write; sample across a window spanning its start bit through
      // its data bits.
      repeat (FRAMECLKS - 4 * BITCLKS) @(posedge sysclk);
      for (i = 0; i < 12; i = i + 1) begin
        uart_read(2'b00, v);
        if (v !== 8'h58 && v !== 8'h59) begin
          $display("TEST3 FAIL: mid-shift read got a torn value %02x (neither 58 nor 59)", v);
          torn = 1;
          errors = errors + 1;
        end
        repeat (BITCLKS) @(posedge sysclk);
      end
      if (!torn) $display("TEST3 PASS: every mid-shift read was a whole byte (58 or 59), never torn");
    end

    // let the second frame finish fully
    repeat (2 * FRAMECLKS) @(posedge sysclk);

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
