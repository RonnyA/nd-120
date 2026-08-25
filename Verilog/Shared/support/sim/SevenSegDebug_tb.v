/****************************************************************************
** SevenSegDebug (Basys3 4-digit 7-segment multiplexer) testbench          **
**                                                                         **
** Read from SevenSegDebug.v: `refresh_counter` is a 17-bit free-running   **
** counter (init 0), and `digit_select = refresh_counter[16:15]`. That     **
** means EACH digit is selected for 2^15 = 32768 clocks, and a full        **
** 4-digit rotation is 4*32768 = 2^17 = 131072 clocks, exactly matching    **
** the RTL's own header comment. seg/an/hex_digit are pure combinational   **
** (`always @(*)`) functions of digit_select and value - no clock latency  **
** once digit_select and value are stable.                                **
**                                                                         **
** COVERAGE:                                                               **
**  1. EXHAUSTIVE hex-decode table: all 16 nibble values checked against   **
**     the RTL's own case statement (transcribed by hand from the source), **
**     and a distinctness check that all 16 resulting 7-bit patterns are   **
**     different from each other (catches a copy-paste duplicate entry).   **
**     Done at digit_select=0 (right after reset, before any clock),       **
**     since the decode table is shared logic - which digit is selected   **
**     does not change how a given nibble decodes.                        **
**  2. Digit rotation: steps the clock in bulk (repeat loops, not one      **
**     edge at a time) to land inside each of the 4 digit windows at a     **
**     point safely away from the transition edges, and checks: exactly   **
**     one anode is low, the anode pattern matches the expected digit      **
**     position, and the nibble it displays matches the corresponding      **
**     nibble of `value`.                                                 **
**                                                                         **
** Run: cd Verilog/Shared/support/sim && iverilog -g2012 -o tb.vvp         **
**      SevenSegDebug_tb.v ../SevenSegDebug.v && vvp tb.vvp               **
**                                                                         **
** Last reviewed: 20-AUG-2026                                             **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module SevenSegDebug_tb;

  reg         clk = 0;
  always #5 clk = ~clk;

  reg  [15:0] value;
  wire [6:0]  seg;
  wire [3:0]  an;

  integer errors = 0;
  integer checks = 0;

  SevenSegDebug DUT (
      .clk  (clk),
      .value(value),
      .seg  (seg),
      .an   (an)
  );

  // Hand-transcribed reference of the RTL's hex->segment case table
  // (SevenSegDebug.v lines 47-64), gfedcba, active LOW.
  function [6:0] ref_seg;
    input [3:0] h;
    begin
      case (h)
        4'h0: ref_seg = 7'b1000000;
        4'h1: ref_seg = 7'b1111001;
        4'h2: ref_seg = 7'b0100100;
        4'h3: ref_seg = 7'b0110000;
        4'h4: ref_seg = 7'b0011001;
        4'h5: ref_seg = 7'b0010010;
        4'h6: ref_seg = 7'b0000010;
        4'h7: ref_seg = 7'b1111000;
        4'h8: ref_seg = 7'b0000000;
        4'h9: ref_seg = 7'b0010000;
        4'hA: ref_seg = 7'b0001000;
        4'hB: ref_seg = 7'b0000011;
        4'hC: ref_seg = 7'b1000110;
        4'hD: ref_seg = 7'b0100001;
        4'hE: ref_seg = 7'b0000110;
        4'hF: ref_seg = 7'b0001110;
      endcase
    end
  endfunction

  integer h;
  reg [6:0] seen[0:15];
  integer j;
  reg dup_found;

  // ---- digit rotation state -------------------------------------------
  // digit_select thresholds (refresh_counter[16:15]):
  //   0: counter 0..32767        an=1110 (rightmost)  nibble = value[3:0]
  //   1: counter 32768..65535    an=1101              nibble = value[7:4]
  //   2: counter 65536..98303    an=1011              nibble = value[11:8]
  //   3: counter 98304..131071   an=0111              nibble = value[15:12]
  localparam integer WINDOW = 32768;

  task check_digit(input [1:0] which, input [3:0] expected_an_active_low,
                    input [3:0] expected_nibble, input [255:0] label);
    reg [3:0] active_low_count;
    integer k;
    begin
      checks = checks + 1;
      if (an !== expected_an_active_low) begin
        errors = errors + 1;
        $display("FAIL %0s: an=%b expected %b", label, an, expected_an_active_low);
      end
      checks = checks + 1;
      active_low_count = 0;
      for (k = 0; k < 4; k = k + 1) if (an[k] === 1'b0) active_low_count = active_low_count + 1;
      if (active_low_count !== 1) begin
        errors = errors + 1;
        $display("FAIL %0s: expected exactly one anode low, an=%b (count=%0d)", label, an, active_low_count);
      end
      checks = checks + 1;
      if (seg !== ref_seg(expected_nibble)) begin
        errors = errors + 1;
        $display("FAIL %0s: seg=%b expected %b for nibble %h", label, seg, ref_seg(expected_nibble), expected_nibble);
      end
    end
  endtask

  initial begin
    $dumpfile("SevenSegDebug_tb.vcd");
    $dumpvars(0, SevenSegDebug_tb);

    // ---- short documented sequence first (readable in the VCD) ----------
    value = 16'h1234;
    #1;
    $display("Doc sequence: value=1234, digit0(rightmost)=%h seg=%b an=%b", value[3:0], seg, an);
    value = 16'hABCD;
    #1;
    $display("Doc sequence: value=ABCD, digit0(rightmost)=%h seg=%b an=%b", value[3:0], seg, an);

    $dumpoff;

    // ---- 1. exhaustive hex decode, all 16 values, at digit_select=0 -------
    //        (refresh_counter is still 0 here - no clock edges needed).
    for (h = 0; h < 16; h = h + 1) begin
      value = {12'h000, h[3:0]};
      #1;
      checks = checks + 1;
      if (seg !== ref_seg(h[3:0])) begin
        errors = errors + 1;
        $display("FAIL HEX_DECODE h=%h: seg=%b expected %b", h, seg, ref_seg(h[3:0]));
      end
      seen[h] = seg;
    end

    // ---- distinctness: no two of the 16 patterns are identical -----------
    dup_found = 1'b0;
    for (h = 0; h < 16; h = h + 1) begin
      for (j = h + 1; j < 16; j = j + 1) begin
        checks = checks + 1;
        if (seen[h] === seen[j]) begin
          dup_found = 1'b1;
          errors = errors + 1;
          $display("FAIL DISTINCT: hex %h and hex %h produced the SAME segment pattern %b", h, j, seen[h]);
        end
      end
    end
    if (!dup_found) $display("All 16 hex segment patterns are distinct.");

    // ---- 2. digit rotation: land inside each window away from the edges --
    value = 16'h4B2E;   // nibble3=4 nibble2=B nibble1=2 nibble0=E, all distinct
    #1;                 // settle: let the combinational seg/an update

    // Window 0 (rightmost, an=1110, nibble = value[3:0] = E): counter starts
    // at 0, we are already inside it.
    check_digit(2'd0, 4'b1110, 4'hE, "window0 rightmost at reset");

    // Advance to the middle of window 0 first, then step to window 1's
    // middle: window0 spans counter 0..32767, window1 32768..65535.
    // window1 shows value[7:4] = 2.
    repeat (WINDOW + WINDOW / 2) @(posedge clk);
    #1;
    check_digit(2'd1, 4'b1101, 4'h2, "window1 (counter ~1.5*WINDOW)");

    // Step to the middle of window 2 (counter ~2.5*WINDOW from origin ->
    // advance one more WINDOW). window2 shows value[11:8] = B.
    repeat (WINDOW) @(posedge clk);
    #1;
    check_digit(2'd2, 4'b1011, 4'hB, "window2 (counter ~2.5*WINDOW)");

    // Step to the middle of window 3.
    repeat (WINDOW) @(posedge clk);
    #1;
    check_digit(2'd3, 4'b0111, 4'h4, "window3 leftmost (counter ~3.5*WINDOW)");

    // Step past the wrap (counter overflows back through window0).
    repeat (WINDOW) @(posedge clk);
    #1;
    check_digit(2'd0, 4'b1110, 4'hE, "window0 again after full rotation wrap");

    $display("-----------------------------------------------------");
    $display(" SevenSegDebug testbench");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $finish;
  end

  initial begin
    #20000000;
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire
