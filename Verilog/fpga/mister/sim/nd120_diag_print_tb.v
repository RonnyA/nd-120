/*****************************************************************************
 *  nd120_diag_print_tb.v                                                     *
 *                                                                            *
 *  Proves the CPU liveness probe prints the values it is given, BEFORE it is *
 *  trusted on hardware. The whole point of that module is to be believed     *
 *  when it says "the CPU clock is dead" or "the microcode is stuck at this   *
 *  address" - a probe that formats its own fields wrongly would send the     *
 *  debugging off in the wrong direction, which has already happened twice on *
 *  this project with the MIPS tap.                                           *
 *                                                                            *
 *  Checks the exact expected line for a known set of inputs, including the   *
 *  octal digit splitting, which is the part most likely to be wrong.         *
 *****************************************************************************/

`timescale 1ns / 1ps
`default_nettype none

module nd120_diag_print_tb;

  // A short second, so the testbench does not have to simulate 40 million
  // cycles to see one line.
  localparam integer CLK_HZ = 1000;

  reg clk = 1'b0;
  always #5 clk = ~clk;

  reg         rst_n = 1'b0;
  reg  [15:0] cpu_ticks = 16'o123456;
  reg  [12:0] csa       = 13'o12345;
  reg  [ 3:0] pil       = 4'o13;
  reg  [15:0] actlv     = 16'o102040;
  reg         sterr_hit   = 1'b1;
  reg  [ 7:0] sterr_count = 8'o003;
  reg  [15:0] sterr_r2    = 16'o000007;
  reg  [ 3:0] sterr_lba   = 4'o12;
  reg  [15:0] ireq        = 16'o004000;
  reg         pie_hit     = 1'b1;
  reg  [ 7:0] pie_count   = 8'o002;
  reg  [15:0] pie         = 16'o000377;
  reg         cpu_rst_n = 1'b1;
  reg         run_n     = 1'b0;

  wire        byte_valid;
  wire [7:0]  byte_data;
  reg         byte_ready = 1'b1;

  nd120_diag_print #(.CLK_HZ(CLK_HZ)) DUT (
      .clk       (clk),
      .rst_n     (rst_n),
      .cpu_ticks (cpu_ticks),
      .csa       (csa),
      .pil       (pil),
      .actlv     (actlv),
      .sterr_hit  (sterr_hit),
      .sterr_count(sterr_count),
      .sterr_r2   (sterr_r2),
      .sterr_lba  (sterr_lba),
      .ireq       (ireq),
      .pie_hit    (pie_hit),
      .pie_count  (pie_count),
      .pie        (pie),
      .cpu_rst_n (cpu_rst_n),
      .run_n     (run_n),
      .byte_valid(byte_valid),
      .byte_data (byte_data),
      .byte_ready(byte_ready)
  );

  // Collect what the module emits.
  integer n_rx = 0;
  reg [7:0] rx [0:127];

  always @(posedge clk) begin
    if (byte_valid && byte_ready && n_rx < 128) begin
      rx[n_rx] = byte_data;
      n_rx     = n_rx + 1;
    end
  end

  // cpu_ticks 16'o123456 -> the 16 bits split as 1 + 3+3+3+3+3
  //   binary 1 010 011 100 101 110  ->  digits 1 2 3 4 5 6
  // csa 13'o12345 -> 1 + 3+3+3+3 -> 1 2 3 4 5
  // pil 4'o13 -> 2 digits "13"; actlv 16'o102040 -> 6 digits "102040"
  localparam [8*98:1] EXPECT =
      {"CK 123456 CSA 12345 PIL 13 AL 102040 R 1 N 0\015\012",
       "ST 1/003 R2 000007 LB 12 IQ 004000 PE 1/002 000377\015\012"};

  integer i;
  integer errors = 0;
  reg [7:0] want;

  initial begin
    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    // Wait for the tick, then for both lines to be shifted out. Each byte
    // takes about three clocks (assert valid, see ready, step), so 82 bytes
    // need ~250 clocks - the old +200 slack silently truncated the second line.
    repeat (CLK_HZ + 900) @(posedge clk);

    if (n_rx != 98) begin
      $display("FAIL: expected 98 bytes, got %0d", n_rx);
      errors = errors + 1;
    end else begin
      for (i = 0; i < 98; i = i + 1) begin
        want = EXPECT[8*(98-i) -: 8];
        if (rx[i] !== want) begin
          $display("FAIL: byte %0d is 0x%02h ('%c'), expected 0x%02h ('%c')",
                   i, rx[i], rx[i], want, want);
          errors = errors + 1;
        end
      end
    end

    $write("Emitted: ");
    for (i = 0; i < n_rx; i = i + 1)
      if (rx[i] >= 8'h20) $write("%c", rx[i]);
    $write("\n");

    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

`default_nettype wire
