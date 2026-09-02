`timescale 1ns / 1ps
//! Full MiSTer keyboard chain: a real PS/2 set-2 scancode into
//! nd120_console_mister (ps2_decoder_tdv + key_tdv2200) -> the byte it hands
//! the machine. 02-SEP-2026, hunting the v56 "keyboard dead" regression.
module kbd_chain_tb;
  reg clk = 0; always #12.5 clk = ~clk;   // 40 MHz
  reg rst_n = 0;
  reg [10:0] ps2_key = 0;
  wire       kbd_valid;
  wire       kbd_data_ready;   // real backpressure from console_uart_tx
  wire       txd_cpu;
  wire [7:0] kbd_data;
  wire [2:0] colour; wire panel_active, pixel, hsync, vsync, de, bell, cpu_ready;

  nd120_console_mister #(.FONT_FILE("../../../Terminals/font/font8x16.hex"),
                         .LOCAL_ECHO(0)) DUT (
      .clk(clk), .rst_n(rst_n), .ps2_key(ps2_key), .layout_no(1'b0),
      .cpu_byte_valid(1'b0), .cpu_byte_data(8'h00), .cpu_byte_ready(cpu_ready),
      .panel_enable(1'b0), .panel_pil(4'd0), .panel_actlv(16'd0), .panel_mips(16'd0),
      .panel_cpu_red(1'b0), .panel_cpu_green(1'b0), .panel_lev0(1'b0), .panel_hit(1'b0),
      .panel_ring(2'd0), .panel_paging_on(1'b0), .panel_interrupt_on(1'b0),
      .panel_running(1'b0), .panel_hdd_rd(1'b0), .panel_hdd_wr(1'b0),
      .panel_flp_rd(1'b0), .panel_flp_wr(1'b0),
      .kbd_valid(kbd_valid), .kbd_data(kbd_data), .kbd_ready(kbd_data_ready),
      .colour(colour), .panel_active(panel_active),
      .pixel(pixel), .hsync(hsync), .vsync(vsync), .de(de), .bell(bell)
  );

  console_uart_tx #(.CLK_HZ(40_000_000), .BAUD(115_200), .DATA_BITS(8),
                    .PARITY(1'b0), .PARITY_ODD(1'b0)) TX (
      .clk(clk), .rst_n(rst_n), .divisor_ovr(16'd0),
      .byte_valid(kbd_valid), .byte_data(kbd_data), .ready(kbd_data_ready), .txd(txd_cpu)
  );

  // frame-aware byte counter on the serial line to the CPU
  integer got = 0; reg [7:0] first; integer i;
  localparam integer BITNS = 8681;
  initial forever begin
    @(negedge txd_cpu);
    if (rst_n) begin
      got = got + 1;
      #(BITNS + BITNS/2);
      for (i = 0; i < 8; i = i + 1) begin if (got==1) first[i] = txd_cpu; #(BITNS); end
      #(BITNS);
    end
  end

  // one PS/2 key event: flip the toggle, set pressed/extended/scancode
  task key(input pressed, input ext, input [7:0] code);
    begin @(negedge clk); ps2_key = {~ps2_key[10], pressed, ext, code}; repeat(4) @(negedge clk); end
  endtask

  integer errors = 0;
  initial begin
    repeat (5) @(posedge clk); rst_n = 1; repeat (5) @(posedge clk);
    key(1'b1, 1'b0, 8'h1C);           // press 'A' (set-2 0x1C)
    #(BITNS*14);
    key(1'b0, 1'b0, 8'h1C);           // release
    #(BITNS*14);
    $display("bytes to machine: %0d, first = 0x%02x ('%0s')", got, first, first);
    if (got == 0) begin errors=errors+1; $display("  FAIL: no byte - decoder/expander produced nothing"); end
    else if (got > 1) begin errors=errors+1; $display("  FAIL: %0d bytes for one keypress", got); end
    else if (first != "a") begin errors=errors+1; $display("  FAIL: wrong byte 0x%02x, expected 0x61", first); end
    if (errors==0) $display("TB_RESULT: PASS"); else $display("TB_RESULT: FAIL (%0d)", errors);
    $finish;
  end
  initial begin #5_000_000; $display("TB_RESULT: FAIL (watchdog)"); $finish; end
endmodule
