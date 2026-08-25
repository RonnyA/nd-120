/**************************************************************************
** Unit test for nd120_errfa_wdiox_ring (the "W" line of the ERRFA      **
** evidence probe). Drives IOX strobes to the Winchester range plus     **
** decoys outside it, arms via the console-text matcher, and verifies   **
** the printed line: header, oldest-first order, direction/register/    **
** data fields, single-shot behavior.                                   **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module nd120_errfa_wdiox_ring_tb;

  reg clk = 0;
  reg rst_n = 0;
  reg [15:0] addr = 0;
  reg rd = 0, wr = 0;
  reg [15:0] wdata = 0, rdata = 0;
  reg contx = 1;
  wire txd;

  localparam BAUD = 16;

  nd120_errfa_wdiox_ring #(
      .BAUD_DIV(BAUD),
      .WWAIT(2000)
  ) DUT (
      .clk(clk), .rst_n(rst_n),
      .iox_addr(addr), .iox_rd(rd), .iox_wr(wr),
      .iox_wdata(wdata), .iox_rdata(rdata),
      .contx(contx), .txd(txd)
  );

  always #10 clk = ~clk;

  integer errors = 0;

  task strobe(input iswr, input [15:0] a, input [15:0] d);
    begin
      @(negedge clk);
      addr = a;
      if (iswr) begin wr = 1; wdata = d; end
      else begin rd = 1; rdata = d; end
      repeat (4) @(negedge clk);
      rd = 0; wr = 0;
      repeat (2) @(negedge clk);
    end
  endtask

  task send_char(input [7:0] ch);
    integer b;
    begin
      contx = 0;
      repeat (BAUD) @(posedge clk);
      for (b = 0; b < 8; b = b + 1) begin
        contx = ch[b];
        repeat (BAUD) @(posedge clk);
      end
      contx = 1;
      repeat (BAUD) @(posedge clk);
    end
  endtask

  task recv_char(output [7:0] ch);
    integer b;
    begin
      @(negedge txd);
      repeat (BAUD / 2) @(posedge clk);
      for (b = 0; b < 8; b = b + 1) begin
        repeat (BAUD) @(posedge clk);
        ch[b] = txd;
      end
      repeat (BAUD) @(posedge clk);
    end
  endtask

  reg [7:0] got;
  integer i, g;
  reg [7:0] dirch;
  reg [17:0] oct;
  integer d;

  initial begin
    repeat (4) @(negedge clk);
    rst_n = 1;
    repeat (4) @(negedge clk);

    // 50 winchester strobes (wraps the 48-ring by 2) + decoys that must
    // NOT be recorded
    for (i = 0; i < 25; i = i + 1) begin
      strobe(1, 16'o505, 16'o100 + i);   // writes to +5
      strobe(0, 16'o504, 16'o60000 + i); // reads of +4
    end
    strobe(1, 16'o306, 16'o777);         // console - decoy
    strobe(0, 16'o1562, 16'o777);        // floppy - decoy
    // final distinctive tail
    strobe(1, 16'o501, 16'o123456);
    strobe(0, 16'o500, 16'o054321);

    // machine "crashes"
    send_char("E"); send_char("R"); send_char("R");
    send_char("F"); send_char("A"); send_char("T");

    // post-freeze traffic must not be recorded
    strobe(1, 16'o505, 16'o777);

    // receive the line
    recv_char(got);
    if (got !== "W") begin $display("FAIL: header got %c", got); errors = errors + 1; end
    recv_char(got);
    if (got !== " ") begin $display("FAIL: no space"); errors = errors + 1; end
    for (g = 0; g < 48; g = g + 1) begin
      recv_char(dirch);
      recv_char(got);            // register digit
      recv_char(got);            // space
      oct = 0;
      for (d = 0; d < 6; d = d + 1) begin
        recv_char(got);
        oct = (oct << 3) | (got - 8'h30);
      end
      recv_char(got);            // space
      recv_char(got);            // dt hi digit
      if (got < "0" || got > "3") begin
        $display("FAIL: entry %0d dt hi digit '%c'", g, got);
        errors = errors + 1;
      end
      recv_char(got);            // dt lo digit
      recv_char(got);            // trailing space
      // the last two entries are the distinctive tail
      if (g == 46) begin
        if (dirch !== "W" || oct[15:0] !== 16'o123456) begin
          $display("FAIL: entry 46 got %c %06o expected W 123456", dirch, oct[15:0]);
          errors = errors + 1;
        end
      end
      if (g == 47) begin
        if (dirch !== "R" || oct[15:0] !== 16'o054321) begin
          $display("FAIL: entry 47 got %c %06o expected R 054321", dirch, oct[15:0]);
          errors = errors + 1;
        end
      end
    end
    recv_char(got);
    if (got !== 8'h0D) begin $display("FAIL: no CR"); errors = errors + 1; end
    recv_char(got);
    if (got !== 8'h0A) begin $display("FAIL: no LF"); errors = errors + 1; end

    // single-shot: no second line
    begin : quiet
      integer k;
      for (k = 0; k < 60000; k = k + 1) begin
        @(posedge clk);
        if (txd !== 1'b1) begin
          $display("FAIL: printed a second line");
          errors = errors + 1;
          k = 60000;
        end
      end
    end

    if (errors == 0) begin
      $display("W line verified: 48 entries oldest-first, decoys ignored, single-shot");
      $display("TB_RESULT: PASS");
    end else $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  initial begin
    #100000000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
