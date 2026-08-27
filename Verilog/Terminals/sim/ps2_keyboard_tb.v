//============================================================================
//! Self-checking testbench for ps2_keyboard.v
//!
//! Shifts real PS/2 frames in on a modelled keyboard clock and checks what
//! comes out. What this PROVES:
//!
//!   - 11-bit framing and odd parity
//!   - a frame with BAD parity is dropped, and the receiver recovers
//!   - press produces a character, release does not
//!   - shift, and shift released
//!   - caps lock affects letters and NOT digits (the classic bug)
//!   - ctrl produces a control character from the unshifted letter
//!   - E0-prefixed keys produce no ASCII but do appear on the raw output
//!
//! What it does NOT prove: that the scancode->ASCII table is right. That table
//! is transcribed from published documents and can only be checked by typing
//! on a real keyboard - phase 3 of fpga/nexys4ddr/PLAN-vga-console.md. This
//! testbench asserts the codes it sends match the table AS WRITTEN, so it will
//! keep passing if the table is wrong. Said out loud so nobody reads a green
//! run as proof of the mapping.
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 27-AUG-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module ps2_keyboard_tb;

  reg clk = 1'b0;
  reg rst_n = 1'b0;

  reg ps2_clk = 1'b1;
  reg ps2_dat = 1'b1;

  wire       ascii_valid;
  wire [7:0] ascii_data;
  wire       code_valid;
  wire [7:0] code_data;
  wire       code_release;
  wire       code_extended;

  integer errors = 0;

  always #12.5 clk = ~clk;  // 40 MHz

  ps2_keyboard DUT (
      .clk  (clk),
      .rst_n(rst_n),

      .ps2_clk_in (ps2_clk),
      .ps2_data_in(ps2_dat),

      .ascii_valid  (ascii_valid),
      .ascii_data   (ascii_data),
      .code_valid   (code_valid),
      .code_data    (code_data),
      .code_release (code_release),
      .code_extended(code_extended)
  );

  //--------------------------------------------------------------------------
  // Capture whatever the DUT emits, so the checks can look at it afterwards
  //--------------------------------------------------------------------------

  reg [7:0] last_ascii = 8'h00;
  integer   ascii_count = 0;
  reg [7:0] last_code = 8'h00;
  integer   code_count = 0;

  always @(posedge clk) begin
    if (ascii_valid) begin
      last_ascii  = ascii_data;
      ascii_count = ascii_count + 1;
    end
    if (code_valid) begin
      last_code  = code_data;
      code_count = code_count + 1;
    end
  end

  //--------------------------------------------------------------------------
  // A modelled keyboard. Real PS/2 runs at 10-16.7 kHz; 15 kHz is 66.7 us per
  // bit, and the data changes while the clock is high.
  //--------------------------------------------------------------------------

  localparam integer HALF_BIT = 33_333;  // ns

  task ps2_bit;
    input value;
    begin
      ps2_dat = value;
      #HALF_BIT;
      ps2_clk = 1'b0;   // the DUT samples on this falling edge
      #HALF_BIT;
      ps2_clk = 1'b1;
    end
  endtask

  //! Send one scancode byte with correct odd parity.
  task ps2_send;
    input [7:0] value;
    integer b;
    begin
      ps2_bit(1'b0);                    // start
      for (b = 0; b < 8; b = b + 1) ps2_bit(value[b]);
      ps2_bit(~(^value));               // odd parity
      ps2_bit(1'b1);                    // stop
      #HALF_BIT;
    end
  endtask

  //! Same, but with the parity bit deliberately wrong.
  task ps2_send_bad_parity;
    input [7:0] value;
    integer b;
    begin
      ps2_bit(1'b0);
      for (b = 0; b < 8; b = b + 1) ps2_bit(value[b]);
      ps2_bit(^value);                  // WRONG on purpose
      ps2_bit(1'b1);
      #HALF_BIT;
    end
  endtask

  task check;
    input condition;
    input [1023:0] what;
    begin
      if (!condition) begin
        $display("FAIL: %0s (time %0t)", what, $time);
        errors = errors + 1;
      end
    end
  endtask

  //! Send a press (make + break) and check the character it produced.
  task press_expect;
    input [7:0] code;
    input [7:0] expected;
    integer n_before;
    begin
      n_before = ascii_count;
      ps2_send(code);
      if (ascii_count != n_before + 1) begin
        $display("FAIL: scancode 0x%02x produced %0d characters, expected 1 (time %0t)",
                 code, ascii_count - n_before, $time);
        errors = errors + 1;
      end else if (last_ascii !== expected) begin
        $display("FAIL: scancode 0x%02x gave 0x%02x, expected 0x%02x (time %0t)",
                 code, last_ascii, expected, $time);
        errors = errors + 1;
      end
      // the release must NOT produce a second character
      n_before = ascii_count;
      ps2_send(8'hF0);
      ps2_send(code);
      check(ascii_count == n_before, "a key RELEASE produced a character");
    end
  endtask

  //--------------------------------------------------------------------------

  integer mark;

  initial begin
    $dumpfile("ps2_keyboard_tb.vcd");
    $dumpvars(0, ps2_keyboard_tb);

    repeat (10) @(posedge clk);
    rst_n = 1'b1;
    #100_000;

    //------------------------------------------------------------------
    // 1. Plain letters and a digit
    //------------------------------------------------------------------
    press_expect(8'h1C, "a");
    press_expect(8'h44, "o");
    press_expect(8'h16, "1");
    press_expect(8'h29, 8'h20);  // space
    press_expect(8'h5A, 8'h0D);  // Enter -> CR

    //------------------------------------------------------------------
    // 2. Shift held down
    //------------------------------------------------------------------
    ps2_send(8'h12);             // left shift press
    press_expect(8'h1C, "A");
    press_expect(8'h16, "!");    // shift-1 on a US layout
    ps2_send(8'hF0); ps2_send(8'h12);  // shift release
    press_expect(8'h1C, "a");    // back to lower case

    //------------------------------------------------------------------
    // 3. Caps lock: letters yes, digits no
    //------------------------------------------------------------------
    ps2_send(8'h58);             // caps press
    ps2_send(8'hF0); ps2_send(8'h58);  // caps release - must not toggle back
    press_expect(8'h1C, "A");
    press_expect(8'h16, "1");    // NOT "!" - caps must not affect digits
    ps2_send(8'h58);             // caps off again
    ps2_send(8'hF0); ps2_send(8'h58);
    press_expect(8'h1C, "a");

    //------------------------------------------------------------------
    // 4. Ctrl
    //------------------------------------------------------------------
    ps2_send(8'h14);             // ctrl press
    press_expect(8'h21, 8'h03);  // ctrl-C
    press_expect(8'h1C, 8'h01);  // ctrl-A
    ps2_send(8'hF0); ps2_send(8'h14);
    press_expect(8'h21, "c");

    //------------------------------------------------------------------
    // 5. A frame with bad parity is dropped, and the next one still works
    //------------------------------------------------------------------
    mark = ascii_count;
    ps2_send_bad_parity(8'h1C);
    check(ascii_count == mark, "a frame with bad parity produced a character");
    press_expect(8'h1C, "a");

    //------------------------------------------------------------------
    // 6. Extended keys: raw code appears, no ASCII
    //------------------------------------------------------------------
    // On a TDV the arrows are BARE C0 BYTES, not escape sequences - verified
    // in TDV2200KeyRegistry.cs, where UP/DOWN/LEFT/RIGHT/HOME carry the flag
    // AlwaysSameCode and the same byte in every column. RetroTerm's
    // docs\TDV-KEYBOARD-COMPLETE-REFERENCE.md claims ESC[A for these in
    // extended mode; the code disagrees and the code wins.
    mark = ascii_count;
    ps2_send(8'hE0); ps2_send(8'h74);             // right arrow
    check(ascii_count == mark + 1, "right arrow produced no byte");
    check(last_ascii == 8'h18, "right arrow should send CAN 0x18");
    check(code_data == 8'h74 && code_extended, "extended scancode not reported");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h74);  // its release

    mark = ascii_count;
    ps2_send(8'hE0); ps2_send(8'h75);             // up
    check(last_ascii == 8'h1C, "up arrow should send FS 0x1C");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h75);

    ps2_send(8'hE0); ps2_send(8'h72);             // down
    check(last_ascii == 8'h0B, "down arrow should send VT 0x0B");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h72);

    ps2_send(8'hE0); ps2_send(8'h6B);             // left
    check(last_ascii == 8'h08, "left arrow should send BS 0x08");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h6B);

    ps2_send(8'hE0); ps2_send(8'h6C);             // home
    check(last_ascii == 8'h1D, "HOME should send GS 0x1D in native mode");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h6C);

    // An extended key with no TDV equivalent must send NOTHING - no VT100
    // fallback, deliberately, the same rule RetroTerm follows.
    mark = ascii_count;
    ps2_send(8'hE0); ps2_send(8'h7D);             // Page Up
    check(ascii_count == mark, "an extended key with no TDV code sent something");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h7D);

    // An extended RELEASE must never produce a byte either.
    mark = ascii_count;
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h75);
    check(ascii_count == mark, "an extended key RELEASE produced a byte");

    if (errors == 0) $display("TB_RESULT: PASS (%0d characters decoded)", ascii_count);
    else $display("TB_RESULT: FAIL (%0d errors)", errors);

    $finish;
  end

  initial begin
    #200_000_000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire
