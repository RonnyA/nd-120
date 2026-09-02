/*****************************************************************************
 *  nd120_csa_trace_tb.v                                                      *
 *                                                                            *
 *  Feeds a KNOWN repeating microcode sequence in and checks the module dumps  *
 *  it back in the right order, oldest first, five octal digits per entry.     *
 *                                                                            *
 *  This matters more than it looks. The whole point of the trace buffer is    *
 *  to be diffed against the simulator's csa_trace.csv to find where the board *
 *  first deviates - so an off-by-one in the ordering, or digits split wrong,  *
 *  would point at the wrong microinstruction entirely. The previous probe on  *
 *  this board already produced one wrong conclusion by being read too         *
 *  trustingly (a once-a-second sampler aliasing against a tight loop).        *
 *****************************************************************************/

`timescale 1ns / 1ps
`default_nettype none

module nd120_csa_trace_tb;

  localparam integer DEPTH   = 8;
  localparam integer PERLINE = 4;
  localparam integer CLK_HZ  = 400;   // short interval so the dump comes quickly

  reg clk_cpu = 1'b0;
  always #3 clk_cpu = ~clk_cpu;

  reg clk = 1'b0;
  always #5 clk = ~clk;

  reg        cpu_rst_n = 1'b0;
  reg        rst_n     = 1'b0;
  reg [12:0] csa       = 13'o00000;
  reg [15:0] aux       = 16'o000000;

  wire       byte_valid;
  wire [7:0] byte_data;
  reg        byte_ready = 1'b1;

  nd120_csa_trace #(
      .DEPTH(DEPTH), .PERLINE(PERLINE), .CLK_HZ(CLK_HZ)
  ) DUT (
      .clk_cpu   (clk_cpu),
      .cpu_rst_n (cpu_rst_n),
      .csa       (csa),
      .aux       (aux),
      .clk       (clk),
      .rst_n     (rst_n),
      .byte_valid(byte_valid),
      .byte_data (byte_data),
      .byte_ready(byte_ready)
  );

  // Drive a known walk of DEPTH distinct addresses, then hold still, so the
  // buffer contains exactly those DEPTH values in order.
  integer step = 0;
  reg [12:0] seq [0:DEPTH-1];
  initial begin
    seq[0] = 13'o01112; seq[1] = 13'o01114; seq[2] = 13'o01116; seq[3] = 13'o01163;
    seq[4] = 13'o01165; seq[5] = 13'o01167; seq[6] = 13'o01171; seq[7] = 13'o01012;
  end

  always @(posedge clk_cpu) begin
    if (cpu_rst_n && step < DEPTH) begin
      csa  <= seq[step];
      // A distinct aux per entry, so a pairing mistake (aux from the wrong
      // entry) shows up rather than looking plausible.
      aux  <= 16'o000001 + step[15:0];
      step <= step + 1;
    end
  end

  // Collect the dump.
  integer n_rx = 0;
  reg [7:0] rx [0:255];
  always @(posedge clk) begin
    if (byte_valid && byte_ready && n_rx < 256) begin
      rx[n_rx] = byte_data;
      n_rx     = n_rx + 1;
    end
  end

  // 8 entries x 13 chars ("01112:000001 ") = 104, plus 2 lines x CRLF -> 108.
  // aux runs 000001..000010 with the sequence, so a pairing mistake shows.
  localparam [8*108:1] EXPECT =
      {"01112:000001 01114:000002 01116:000003 01163:000004 \015\012",
       "01165:000005 01167:000006 01171:000007 01012:000010 \015\012"};

  integer i, errors = 0;
  reg [7:0] want;

  initial begin
    repeat (4) @(posedge clk);
    cpu_rst_n = 1'b1;
    rst_n     = 1'b1;

    // The dump fires every 5 * CLK_HZ clocks, so wait past that plus enough
    // time for the whole buffer to be shifted out one character at a time.
    repeat (5 * CLK_HZ + 1500) @(posedge clk);

    if (n_rx != 108) begin
      $display("FAIL: expected 108 bytes, got %0d", n_rx);
      errors = errors + 1;
    end else begin
      for (i = 0; i < 108; i = i + 1) begin
        want = EXPECT[8*(108-i) -: 8];
        if (rx[i] !== want) begin
          $display("FAIL: byte %0d is 0x%02h ('%c'), expected 0x%02h ('%c')",
                   i, rx[i], rx[i], want, want);
          errors = errors + 1;
        end
      end
    end

    $write("Emitted: ");
    for (i = 0; i < n_rx; i = i + 1)
      if (rx[i] >= 8'h20) $write("%c", rx[i]); else $write(".");
    $write("\n");

    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

`default_nettype wire
