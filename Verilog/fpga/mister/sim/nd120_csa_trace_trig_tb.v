/*****************************************************************************
 *  nd120_csa_trace_trig_tb.v - the TRIGGERED capture mode                    *
 *                                                                            *
 *  The circular mode is covered by nd120_csa_trace_tb.v. This one checks the  *
 *  mode that matters for the live question on the MiSTer board: arm on a      *
 *  microcode address, record the next DEPTH transitions, then FREEZE.         *
 *                                                                            *
 *  Freezing is the whole point and the thing most likely to be got wrong. The *
 *  event under investigation happens ONCE - MACL calls RIIE1 from 002026 -    *
 *  and the machine then settles into a tight loop. A buffer that kept         *
 *  recording would be overwritten by that loop and would show the steady      *
 *  state again, which is exactly the information we already have and do not   *
 *  need. So this testbench drives traffic AFTER the buffer is full and checks  *
 *  the dump is unaffected by it.                                             *
 *                                                                            *
 *  It also checks the trigger address itself is entry 0, so the dump lines up *
 *  with the microcode listing without an off-by-one.                          *
 *****************************************************************************/

`timescale 1ns / 1ps
`default_nettype none

module nd120_csa_trace_trig_tb;

  localparam integer DEPTH   = 8;
  localparam integer PERLINE = 4;
  localparam integer CLK_HZ  = 400;
  localparam [12:0]  TRIG    = 13'o02026;

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
      .DEPTH(DEPTH), .PERLINE(PERLINE), .CLK_HZ(CLK_HZ),
      .TRIGGERED(1), .TRIGGER_ADDR(TRIG)
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

  integer n_rx = 0;
  reg [7:0] rx [0:255];
  always @(posedge clk) begin
    if (byte_valid && byte_ready && n_rx < 256) begin
      rx[n_rx] = byte_data;
      n_rx     = n_rx + 1;
    end
  end

  // Entry 0 is the trigger itself, then the 7 that follow. Each entry prints
  // as "ccccc:aaaaaa " - the address and the bus sampled WITH it, which is the
  // whole point: a point-against-point comparison with the simulator gave a
  // false answer, so the pair must travel together.
  localparam [8*108:1] EXPECT =
      {"02026:000001 02027:000002 01006:000003 01007:000004 \015\012",
       "01010:000005 01011:000006 01012:000007 01013:000010 \015\012"};

  integer i, errors = 0;
  reg [7:0] want;

  task step;
    input [12:0] v;
    input [15:0] a;
    begin
      csa = v;
      aux = a;
      @(posedge clk_cpu);
      @(posedge clk_cpu);
    end
  endtask

  initial begin
    repeat (4) @(posedge clk);
    cpu_rst_n = 1'b1;
    rst_n     = 1'b1;

    // Traffic BEFORE the trigger must be ignored entirely - including its aux
    // values, which must not leak into the captured window.
    step(13'o01112, 16'o077777); step(13'o01163, 16'o077776);
    step(13'o01167, 16'o077775);

    // The trigger and what follows - this is what must be captured.
    step(TRIG,       16'o000001);
    step(13'o02027,  16'o000002); step(13'o01006, 16'o000003);
    step(13'o01007,  16'o000004); step(13'o01010, 16'o000005);
    step(13'o01011,  16'o000006); step(13'o01012, 16'o000007);
    step(13'o01013,  16'o000010);

    // Overflow traffic AFTER the buffer is full must NOT displace anything.
    step(13'o07777, 16'o066666); step(13'o07776, 16'o066665);
    step(13'o07775, 16'o066664); step(13'o07774, 16'o066663);
    step(13'o07773, 16'o066662); step(13'o07772, 16'o066661);
    step(13'o07771, 16'o066660); step(13'o07770, 16'o066657);

    repeat (5 * CLK_HZ + 800) @(posedge clk);   // one dump only: interval is 5*CLK_HZ

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
