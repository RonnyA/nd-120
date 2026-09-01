//============================================================================
//! Self-checking testbench for ps2_keyboard_tdv.v
//!
//! Sibling of ps2_keyboard_tb.v - same PS/2 frame modelling (protocol,
//! parity-drop, shift/caps/ctrl are already proven there and are IDENTICAL
//! logic here, just re-checked with a couple of representative cases). What
//! this one is FOR: proving the TDV-specific table wiring end to end -
//! bare C0 bytes for arrows/Home/Delete with NO marker at all (unlike
//! VT100's markers for the same keys), and the ESC[nn_ marker for F-keys.
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 31-AUG-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module ps2_keyboard_tdv_tb;

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

  ps2_keyboard_tdv DUT (
      .clk  (clk),
      .rst_n(rst_n),

      .ps2_clk_in (ps2_clk),
      .ps2_data_in(ps2_dat),
      .layout_no  (1'b0),

      .ascii_valid  (ascii_valid),
      .ascii_data   (ascii_data),
      .code_valid   (code_valid),
      .code_data    (code_data),
      .code_release (code_release),
      .code_extended(code_extended)
  );

  reg [7:0] last_ascii = 8'h00;
  integer   ascii_count = 0;

  always @(posedge clk) begin
    if (ascii_valid) begin
      last_ascii  = ascii_data;
      ascii_count = ascii_count + 1;
    end
  end

  localparam integer HALF_BIT = 33_333;  // ns, ~15 kHz PS/2 clock

  task ps2_bit;
    input value;
    begin
      ps2_dat = value;
      #HALF_BIT;
      ps2_clk = 1'b0;
      #HALF_BIT;
      ps2_clk = 1'b1;
    end
  endtask

  task ps2_send;
    input [7:0] value;
    integer b;
    begin
      ps2_bit(1'b0);
      for (b = 0; b < 8; b = b + 1) ps2_bit(value[b]);
      ps2_bit(~(^value));
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
      n_before = ascii_count;
      ps2_send(8'hF0);
      ps2_send(code);
      check(ascii_count == n_before, "a key RELEASE produced a character");
    end
  endtask

  integer mark;

  initial begin
    $dumpfile("ps2_keyboard_tdv_tb.vcd");
    $dumpvars(0, ps2_keyboard_tdv_tb);

    repeat (10) @(posedge clk);
    rst_n = 1'b1;
    #100_000;

    // Plain letters, unaffected by which table is TDV vs VT100.
    press_expect(8'h1C, "a");
    press_expect(8'h5A, 8'h0D);  // Enter -> CR

    //------------------------------------------------------------------
    // Extended keys: TDV sends BARE C0 BYTES, not markers - no expansion
    // needed at all. This is the key structural difference from VT100.
    //------------------------------------------------------------------
    mark = ascii_count;
    ps2_send(8'hE0); ps2_send(8'h75);             // up
    check(ascii_count == mark + 1, "up arrow produced no byte");
    check(last_ascii == 8'h1C, "Up should send bare FS 0x1C, not a marker");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h75);

    ps2_send(8'hE0); ps2_send(8'h72);             // down
    check(last_ascii == 8'h0B, "Down should send bare VT 0x0B");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h72);

    ps2_send(8'hE0); ps2_send(8'h6B);             // left
    check(last_ascii == 8'h08, "Left should send bare BS 0x08");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h6B);

    ps2_send(8'hE0); ps2_send(8'h74);             // right
    check(last_ascii == 8'h18, "Right should send bare CAN 0x18");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h74);

    ps2_send(8'hE0); ps2_send(8'h6C);             // home
    check(last_ascii == 8'h1D, "Home should send bare GS 0x1D (confirmed on real PED)");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h6C);

    ps2_send(8'hE0); ps2_send(8'h71);             // delete
    check(last_ascii == 8'h7F, "Delete should send bare DEL 0x7F");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h71);

    //------------------------------------------------------------------
    // F-keys DO need the marker (they expand to 5 bytes downstream).
    //------------------------------------------------------------------
    mark = ascii_count;
    ps2_send(8'h05);                              // F1
    check(ascii_count == mark + 1, "F1 produced no byte");
    check(last_ascii == (8'h80 | 8'd50), "F1 should send marker for ESC[50_");
    ps2_send(8'hF0); ps2_send(8'h05);

    // Shifted F1 must be the +1 variant, not the same marker (unlike VT100).
    ps2_send(8'h12);                              // shift down
    ps2_send(8'h05);
    check(last_ascii == (8'h80 | 8'd51), "shift-F1 must send the +1 marker (ESC[51_)");
    ps2_send(8'hF0); ps2_send(8'h05);
    ps2_send(8'hF0); ps2_send(8'h12);

    // Windows/GUI key (E0 1F) -> FUNK, same marker as F10 (01-SEP-2026,
    // user-requested second entry point - real Left GUI keycode).
    mark = ascii_count;
    ps2_send(8'hE0); ps2_send(8'h1F);             // left GUI / Windows
    check(ascii_count == mark + 1, "Windows key produced no byte");
    check(last_ascii == (8'h80 | 8'd42), "Windows key should send the FUNK marker (ESC[42_)");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h1F);

    // A dead extended key still sends nothing (E0 77, no TDV equivalent).
    mark = ascii_count;
    ps2_send(8'hE0); ps2_send(8'h77);
    check(ascii_count == mark, "a dead extended key sent something");
    ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h77);

    //------------------------------------------------------------------
    // Alt+key: a dedicated marker, not the plain letter underneath - and
    // holding Alt over a key with NO binding sends nothing at all (not
    // the plain letter either), so Alt+typing cannot leak stray text.
    //------------------------------------------------------------------
    ps2_send(8'h11);                              // Alt down
    mark = ascii_count;
    ps2_send(8'h33);                              // 'h' scancode
    check(ascii_count == mark + 1, "Alt+H produced no byte");
    check(last_ascii == 8'hE0, "Alt+H should send the HELP marker (0xE0), not 'h'");
    ps2_send(8'hF0); ps2_send(8'h33);

    mark = ascii_count;
    ps2_send(8'h1C);                              // 'a' scancode -> Alt+A MARK
    check(last_ascii == 8'hEB, "Alt+A should send the MARK marker (0xEB)");
    ps2_send(8'hF0); ps2_send(8'h1C);

    // A key with no Alt binding (e.g. 'z') sends nothing while Alt is held.
    mark = ascii_count;
    ps2_send(8'h1A);                              // 'z', no Alt binding
    check(ascii_count == mark, "Alt+Z (no binding) sent something");
    ps2_send(8'hF0); ps2_send(8'h1A);

    ps2_send(8'hF0); ps2_send(8'h11);             // Alt up

    // Alt released: 'a' goes back to being a plain letter.
    press_expect(8'h1C, "a");

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
