//============================================================================
//! Self-checking testbench for m65_keys_to_ps2.v, run THROUGH the shared
//! ps2_decoder_tdv so what is checked is the character that reaches the
//! terminal, not the PS/2 code in between.
//!
//! Full path: Verilog/fpga/mega65/sim/m65_keys_to_ps2_tb.v
//!
//! The framework's keyboard is modelled the way matrix_to_keynum.vhdl
//! presents it: key_num sweeps 0..79, each key held for a dwell, and
//! key_pressed_n is the debounced state of THAT key during its dwell. A
//! `down` vector is the physical keyboard; the test changes it between
//! sweeps exactly as fingers would.
//!
//! What must come out is what the MEGA65 KEYCAPS say - the whole point of
//! the synthetic-shift scheme - so the checks are on C64-layout pairs the
//! PS/2 US table does not have: 2", 6&, 7', 8(, 9), :[, ;], the lone + @ *
//! = keys, plus the ordinary letters/ctrl/caps/cursor/function paths that
//! must keep working through the same sequencer.
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 02-SEP-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module m65_keys_to_ps2_tb;

  localparam integer DWELL = 64;   //! clocks per key in the scan (real: ~555 at 40 MHz)

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  always #12.5 clk = ~clk;   // 40 MHz

  reg [6:0] key_num = 7'd0;
  reg       key_pressed_n = 1'b1;
  reg [79:0] down = 80'd0;   //! the physical keyboard, 1 = held

  wire       code_valid;
  wire [7:0] code_data;
  wire       code_release;
  wire       code_extended;

  m65_keys_to_ps2 DUT (
      .clk          (clk),
      .rst_n        (rst_n),
      .key_num      (key_num),
      .key_pressed_n(key_pressed_n),
      .code_valid   (code_valid),
      .code_data    (code_data),
      .code_release (code_release),
      .code_extended(code_extended)
  );

  wire       ascii_valid;
  wire [7:0] ascii_data;

  ps2_decoder_tdv DECODER (
      .clk  (clk),
      .rst_n(rst_n),
      .code_valid   (code_valid),
      .code_data    (code_data),
      .code_release (code_release),
      .code_extended(code_extended),
      .layout_no    (1'b0),
      .ascii_valid  (ascii_valid),
      .ascii_data   (ascii_data),
      .shift_active (),
      .ctrl_active  (),
      .caps_active  (),
      .alt_active   ()
  );

  //--------------------------------------------------------------------------
  // Collect everything the decoder produces
  //--------------------------------------------------------------------------
  reg [7:0] got [0:63];
  integer   ngot = 0;
  always @(posedge clk) begin
    if (ascii_valid) begin
      if (ngot < 64) got[ngot] <= ascii_data;
      ngot <= ngot + 1;
    end
  end

  integer errors = 0;

  //! One full sweep of the keyboard, the framework's way.
  task sweep;
    integer k;
    begin
      for (k = 0; k < 80; k = k + 1) begin
        @(negedge clk);
        key_num       = k[6:0];
        key_pressed_n = ~down[k];
        repeat (DWELL - 1) @(negedge clk);
      end
    end
  endtask

  //! Expect exactly the listed bytes since the last flush.
  task expect1;
    input [7:0] a;
    input [8*40-1:0] what;
    begin
      if (ngot != 1 || got[0] !== a) begin
        $display("FAIL: %0s: expected %02x, got %0d byte(s), first %02x", what, a, ngot, got[0]);
        errors = errors + 1;
      end else begin
        $display("-- %0s -> %02x", what, a);
      end
      ngot = 0;
    end
  endtask

  task expect_none;
    input [8*40-1:0] what;
    begin
      if (ngot != 0) begin
        $display("FAIL: %0s: expected nothing, got %0d byte(s), first %02x", what, ngot, got[0]);
        errors = errors + 1;
      end else begin
        $display("-- %0s -> nothing, as it should", what);
      end
      ngot = 0;
    end
  endtask

  //! Press key k (with the modifiers already in `down`), sweep, release, sweep.
  task tap;
    input integer k;
    begin
      down[k] = 1'b1;
      sweep();
      down[k] = 1'b0;
      sweep();
    end
  endtask

  // MEGA65 key numbers used below (CORE/vhdl/keyboard.vhd of the framework)
  localparam K_INS_DEL = 0,  K_RETURN = 1,  K_HORZ = 2,  K_F7 = 3,  K_F1 = 4,
             K_VERT = 7,     K_3 = 8,       K_A = 10,    K_LSHIFT = 15,
             K_6 = 19,       K_C = 20,      K_7 = 24,    K_8 = 27,  K_B = 28,
             K_9 = 32,       K_0 = 35,      K_PLUS = 40, K_MINUS = 43,
             K_COLON = 45,   K_AT = 46,     K_COMMA = 47, K_STAR = 49,
             K_SEMI = 50,    K_HOME = 51,   K_RSHIFT = 52, K_EQUAL = 53,
             K_UPARROW = 54, K_1 = 56,      K_LEFTARROW = 57, K_CTRL = 58,
             K_2 = 59,       K_SPACE = 60,  K_MEGA = 61, K_TAB = 65,
             K_ALT = 66,     K_HELP = 67,   K_ESC = 71,  K_CAPS = 72,
             K_UP = 73,      K_LEFT = 74,   K_RUNSTOP = 63, K_X = 23;

  initial begin
    $dumpfile("m65_keys_to_ps2_tb.vcd");
    $dumpvars(1, m65_keys_to_ps2_tb);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    sweep();            // settle: nothing down, nothing must come out
    expect_none("idle sweep");

    // --- plain keys --------------------------------------------------------
    tap(K_A);        expect1("a", "a");
    tap(K_1);        expect1("1", "1");
    tap(K_2);        expect1("2", "2");
    tap(K_SPACE);    expect1(" ", "space");
    tap(K_RETURN);   expect1(8'h0D, "RETURN");
    tap(K_INS_DEL);  expect1(8'h7F, "INST/DEL -> DEL");
    tap(K_ESC);      expect1(8'h1B, "ESC");
    tap(K_TAB);      expect1(8'h09, "TAB");

    // --- the C64 keycaps the PS/2 table does not have ---------------------
    tap(K_COLON);    expect1(":", "colon key");
    tap(K_SEMI);     expect1(";", "semicolon key");
    tap(K_PLUS);     expect1("+", "plus key");
    tap(K_MINUS);    expect1("-", "minus key");
    tap(K_EQUAL);    expect1("=", "equal key");
    tap(K_AT);       expect1("@", "at key");
    tap(K_STAR);     expect1("*", "star key");
    tap(K_UPARROW);  expect1("^", "up-arrow key");
    tap(K_LEFTARROW);expect1("_", "left-arrow key");

    // --- shifted legends ---------------------------------------------------
    down[K_LSHIFT] = 1'b1; sweep(); expect_none("left shift down");
    tap(K_A);        expect1("A", "shift a");
    tap(K_2);        expect1(8'h22, "shift 2 -> quote");
    tap(K_6);        expect1("&", "shift 6");
    tap(K_7);        expect1("'", "shift 7");
    tap(K_8);        expect1("(", "shift 8");
    tap(K_9);        expect1(")", "shift 9");
    tap(K_0);        expect1("0", "shift 0");
    tap(K_COLON);    expect1("[", "shift colon");
    tap(K_SEMI);     expect1("]", "shift semicolon");
    tap(K_COMMA);    expect1("<", "shift comma");
    tap(K_1);        expect1("!", "shift 1");
    tap(K_3);        expect1("#", "shift 3");
    // after a forced-off legend the user's shift must be back for the next key
    tap(K_COLON);    expect1("[", "shift colon again");
    tap(K_B);        expect1("B", "shift b after a forced key");
    tap(K_HORZ);     expect1(8'h08, "shift + C64 horizontal = Left");
    tap(K_VERT);     expect1(8'h1C, "shift + C64 vertical = Up");
    tap(K_F1);       expect1(8'h80 | 8'd52, "shift F1 = F2");
    down[K_LSHIFT] = 1'b0; sweep(); expect_none("left shift up");
    tap(K_A);        expect1("a", "a after shift released");
    tap(K_COLON);    expect1(":", "colon after shift released");

    // right shift is a shift too; releasing one while the other is held is not
    down[K_RSHIFT] = 1'b1; sweep();
    down[K_LSHIFT] = 1'b1; sweep();
    down[K_RSHIFT] = 1'b0; sweep(); expect_none("shift juggling");
    tap(K_A);        expect1("A", "a with the remaining shift");
    down[K_LSHIFT] = 1'b0; sweep(); expect_none("both shifts up");

    // --- cursor and function keys -----------------------------------------
    tap(K_HORZ);     expect1(8'h18, "C64 horizontal = Right (CAN)");
    tap(K_VERT);     expect1(8'h0B, "C64 vertical = Down (VT)");
    tap(K_UP);       expect1(8'h1C, "Up key (FS)");
    tap(K_LEFT);     expect1(8'h08, "Left key (BS)");
    tap(K_HOME);     expect1(8'h1D, "CLR/HOME = Home (GS)");
    tap(K_F1);       expect1(8'h80 | 8'd50, "F1");
    tap(K_F7);       expect1(8'h80 | 8'd64, "F7");
    tap(K_HELP);     expect1(8'h80 | 8'd46, "HELP = HJELP");

    // --- EXIT (SLUTT, ESC[48_) two ways (04-SEP-2026) ----------------------
    // RUN/STOP goes out as the PC End key; the decoder turns that into the
    // SLUTT marker 0x80|48, which key_tdv2200 expands to ESC[48_ (the
    // console tb checks the full sequence). Shift is forced off, so a held
    // shift must not turn it into the shifted variant 49.
    tap(K_RUNSTOP);  expect1(8'h80 | 8'd48, "RUN/STOP = EXIT (SLUTT)");
    down[K_LSHIFT] = 1'b1; sweep(); expect_none("shift down for RUN/STOP");
    tap(K_RUNSTOP);  expect1(8'h80 | 8'd48, "shift RUN/STOP = still EXIT");
    down[K_LSHIFT] = 1'b0; sweep(); expect_none("shift up after RUN/STOP");
    // Alt+X: the decoder's Alt map emits the ALTM_EXIT marker 0xE3, which
    // key_tdv2200 expands to the same ESC[48_.
    down[K_ALT] = 1'b1; sweep(); expect_none("alt down");
    tap(K_X);        expect1(8'hE3, "alt X = EXIT marker");
    down[K_ALT] = 1'b0; sweep(); expect_none("alt up");
    tap(K_X);        expect1("x", "x after alt released");

    // --- control ------------------------------------------------------------
    down[K_CTRL] = 1'b1; sweep(); expect_none("ctrl down");
    tap(K_C);        expect1(8'h03, "ctrl C");
    down[K_CTRL] = 1'b0; sweep(); expect_none("ctrl up");
    tap(K_C);        expect1("c", "c after ctrl");

    // --- caps lock: a latching key ----------------------------------------
    down[K_CAPS] = 1'b1; sweep(); expect_none("caps locked");
    tap(K_A);        expect1("A", "a with caps");
    tap(K_1);        expect1("1", "1 with caps (digits unaffected)");
    down[K_CAPS] = 1'b0; sweep(); expect_none("caps unlocked");
    tap(K_A);        expect1("a", "a after caps");

    // --- keys that mean nothing here ---------------------------------------
    tap(K_MEGA);     expect_none("MEGA key");
    down[K_LSHIFT] = 1'b1; sweep();
    tap(K_HOME);     expect_none("shift CLR/HOME");
    down[K_LSHIFT] = 1'b0; sweep(); expect_none("shift up");

    // --- holding a key types it once ---------------------------------------
    down[K_A] = 1'b1;
    sweep(); sweep(); sweep();
    down[K_A] = 1'b0; sweep();
    expect1("a", "held a, three sweeps");

    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

`default_nettype wire
