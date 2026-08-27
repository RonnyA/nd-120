//============================================================================
//! Self-checking testbench for term_banner.v - the power-on message sender
//!
//! WHAT THIS PROVES, and what it deliberately does not.
//!
//! It does NOT re-list the message and compare byte for byte. The message
//! lives in a GENERATED file (font/make_banner.py -> rtl/term_banner_rom.v);
//! a testbench holding a second copy would just be a second thing to forget to
//! update, and comparing the ROM against a copy of the ROM proves nothing
//! about the sender. What it checks instead are the properties that must hold
//! whatever the text says:
//!
//!   1. it starts with "ND-120"        - the message is really being read, in
//!                                       order, from address 0
//!   2. it never emits 0x00            - the terminator must never reach the
//!                                       terminal. This is a REGRESSION TEST:
//!                                       the first version registered `valid`
//!                                       and offered the NUL for one cycle,
//!                                       which would have printed a stray
//!                                       glyph after the message
//!   3. backpressure is honoured       - with ready held low nothing advances
//!                                       and no byte is lost
//!   4. it finishes                    - done goes high
//!   5. it then shuts up FOREVER       - valid never rises again, so the
//!                                       machine's own output cannot collide
//!                                       with the banner
//!
//! Point 5 is the one worth the gates: a banner that can speak again later
//! would corrupt the console at an unpredictable moment, and that is a bug
//! that would only ever show up on hardware.
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 28-AUG-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module term_banner_tb;

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg ready = 1'b0;

  wire       valid;
  wire [7:0] data;
  wire       done;

  integer errors = 0;
  integer taken = 0;          //! bytes actually accepted
  integer nul_seen = 0;
  integer after_done_valid = 0;

  reg [7:0] first_bytes[0:5];
  integer i;

  always #12.5 clk = ~clk;    // 40 MHz

  term_banner DUT (
      .clk  (clk),
      .rst_n(rst_n),
      .valid(valid),
      .data (data),
      .ready(ready),
      .done (done)
  );

  //--------------------------------------------------------------------------
  // Watch the stream. Everything below is checked on the accepted bytes only -
  // a byte that is offered but not taken has not been sent.
  //--------------------------------------------------------------------------

  always @(posedge clk) begin
    if (rst_n) begin
      // The terminator must never even be OFFERED, taken or not. Checking the
      // offer rather than the acceptance is stricter on purpose: this is the
      // exact bug that existed, and it only bit when ready happened to be high.
      if (valid && data == 8'h00) nul_seen = nul_seen + 1;

      if (valid && ready) begin
        if (taken < 6) first_bytes[taken] = data;
        taken = taken + 1;
      end

      // Once done, silence. Forever.
      if (done && valid) after_done_valid = after_done_valid + 1;
    end
  end

  //--------------------------------------------------------------------------

  initial begin
    $dumpfile("term_banner_tb.vcd");
    $dumpvars(0, term_banner_tb);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    //------------------------------------------------------------------
    // 3. Backpressure: hold ready low for a good long while and nothing
    //    may move. If the sender free-runs, it will have marched through
    //    the whole message here and `taken` will still be 0 while `done`
    //    goes high - which the check below catches.
    //------------------------------------------------------------------
    ready = 1'b0;
    repeat (500) @(posedge clk);

    if (taken != 0) begin
      $display("FAIL: %0d bytes were accepted while ready was LOW", taken);
      errors = errors + 1;
    end
    if (done) begin
      $display("FAIL: banner finished without ever being read - it is ignoring ready");
      errors = errors + 1;
    end
    if (!valid) begin
      $display("FAIL: banner is not offering anything after reset");
      errors = errors + 1;
    end
    $display("-- backpressure: %0d bytes moved in 500 clocks with ready low (want 0)", taken);

    //------------------------------------------------------------------
    // Now let it run. Accept everything.
    //
    // ready is raised on the NEGEDGE, and that detail is load-bearing. Driving
    // it at a posedge puts the change in the same time step as both the DUT's
    // clocked block and this testbench's monitor, and the two can evaluate on
    // either side of it. The first version of this testbench did exactly that
    // and reported "message starts D-120" with 317 of 318 bytes - the DUT had
    // correctly sent the N while the monitor, having already run, never saw
    // it. A race in the observer looks precisely like a dropped byte in the
    // design, which is the trap: the RTL was never wrong.
    //------------------------------------------------------------------
    @(negedge clk);
    ready = 1'b1;

    i = 0;
    while (!done && i < 20000) begin
      @(posedge clk);
      i = i + 1;
    end

    if (!done) begin
      $display("FAIL: banner never finished (%0d clocks, %0d bytes taken)", i, taken);
      errors = errors + 1;
    end else begin
      $display("-- sent %0d bytes in %0d clocks", taken, i);
    end

    //------------------------------------------------------------------
    // 1. It really read the message from the start.
    //------------------------------------------------------------------
    if (taken >= 6) begin
      if (first_bytes[0] !== "N" || first_bytes[1] !== "D" ||
          first_bytes[2] !== "-" || first_bytes[3] !== "1" ||
          first_bytes[4] !== "2" || first_bytes[5] !== "0") begin
        $display("FAIL: message starts %c%c%c%c%c%c, expected ND-120",
                 first_bytes[0], first_bytes[1], first_bytes[2],
                 first_bytes[3], first_bytes[4], first_bytes[5]);
        errors = errors + 1;
      end else begin
        $display("-- starts with ND-120, so the ROM is being walked from address 0");
      end
    end else begin
      $display("FAIL: only %0d bytes sent - too short to be the message", taken);
      errors = errors + 1;
    end

    //------------------------------------------------------------------
    // 2. The terminator never escaped.
    //------------------------------------------------------------------
    if (nul_seen != 0) begin
      $display("FAIL: 0x00 was offered to the terminal %0d times - the NUL leak is back",
               nul_seen);
      errors = errors + 1;
    end else begin
      $display("-- 0x00 never offered");
    end

    //------------------------------------------------------------------
    // 5. Silence afterwards. Run a long time with ready high, which is the
    //    condition under which a leaky sender would speak.
    //------------------------------------------------------------------
    repeat (5000) @(posedge clk);

    if (after_done_valid != 0) begin
      $display("FAIL: banner asserted valid %0d times AFTER done - it can corrupt the console",
               after_done_valid);
      errors = errors + 1;
    end else begin
      $display("-- silent for 5000 clocks after done, with ready high throughout");
    end

    if (errors == 0) $display("TB_RESULT: PASS (%0d bytes, no NUL, silent after done)", taken);
    else $display("TB_RESULT: FAIL (%0d errors)", errors);

    $finish;
  end

  initial begin
    #10_000_000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire
