/*****************************************************************************
 *  nd120_sterr_catch_tb.v                                                    *
 *                                                                            *
 *  Proves the STERR catcher before it is trusted on hardware:                 *
 *    - it does not fire on other microcode addresses;                         *
 *    - it captures the register-file B port at the moment CSA hits STERR;     *
 *    - it counts ENTRIES, not clocks, when STERR is held for several cycles   *
 *      (getting this wrong would report a huge count for a single visit and   *
 *      hide the "loader walked past it once" case, which is the whole reason  *
 *      the count exists);                                                     *
 *    - first_capture keeps the FIRST value while last_capture tracks.         *
 *****************************************************************************/

`timescale 1ns / 1ps
`default_nettype none

module nd120_sterr_catch_tb;

  reg clk = 1'b0;
  always #5 clk = ~clk;

  reg         rst_n = 1'b0;
  reg  [12:0] csa   = 13'o00000;
  reg  [19:0] wrfb  = 20'h00000;

  wire        hit;
  wire [7:0]  hit_count;
  wire [19:0] first_capture, last_capture;

  nd120_sterr_catch DUT (
      .clk_cpu      (clk),
      .cpu_rst_n    (rst_n),
      .csa          (csa),
      .wrfb         (wrfb),
      .hit          (hit),
      .hit_count    (hit_count),
      .first_capture(first_capture),
      .last_capture (last_capture)
  );

  integer errors = 0;

  task check;
    input [255:0] what;
    input         ok;
    begin
      if (!ok) begin
        $display("FAIL: %0s", what);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    // Ordinary microcode addresses must not trigger anything.
    csa = 13'o01112; wrfb = 20'hAAAAA; repeat (3) @(posedge clk);
    csa = 13'o02546; wrfb = 20'hBBBBB; repeat (3) @(posedge clk);
    check("no hit before STERR", hit === 1'b0 && hit_count === 8'd0);

    // First STERR visit, HELD for several cycles: LBA=2, R2=0o000007.
    wrfb = {4'd2, 16'o000007};
    csa  = 13'o02156;
    repeat (5) @(posedge clk);
    csa  = 13'o02157;
    repeat (2) @(posedge clk);

    check("hit is set", hit === 1'b1);
    check("held STERR counts as ONE entry", hit_count === 8'd1);
    check("captured R2 = 7", first_capture[15:0] === 16'o000007);
    check("captured LBA = 2", first_capture[19:16] === 4'd2);

    // Second visit with a different value: first_capture must not move.
    wrfb = {4'd2, 16'o000042};
    csa  = 13'o02156;
    repeat (3) @(posedge clk);
    csa  = 13'o01112;
    repeat (2) @(posedge clk);

    check("second entry counted", hit_count === 8'd2);
    check("first_capture unchanged", first_capture[15:0] === 16'o000007);
    check("last_capture updated", last_capture[15:0] === 16'o000042);

    $display("hit=%0d count=%0d first=%06o last=%06o lba=%0d",
             hit, hit_count, first_capture[15:0], last_capture[15:0],
             first_capture[19:16]);

    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

`default_nettype wire
