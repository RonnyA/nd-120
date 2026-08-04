/**************************************************************************
** FIFO_8BIT self-checking testbench (DEPTH=13)                           **
**                                                                        **
** Replaces the old FIFO_8BIT_TB/FIFO_tb.v, which never connected the     **
** DUT clk port (the FIFO never clocked) and had no checks. This tb       **
** drives one write/read per clock and checks:                            **
**   1. reset state (empty=1, full=0)                                     **
**   2. write then in-order readback                                      **
**   3. mid-stream reset clears the FIFO                                  **
**   4. fill to DEPTH -> full=1; write-when-full is ignored               **
**   5. full readback in order, then empty=1                              **
**   6. read-when-empty drives data_out=0                                 **
**                                                                        **
** Verdict: TB_RESULT: PASS (<n> checks) with a fixed expected count.     **
***************************************************************************/
`timescale 1ns / 1ps

module FIFO_testbench;

  parameter DEPTH = 13;
  localparam integer CHECKS_EXPECTED = 25;

  reg        clk = 0;
  reg        rst;
  reg        wr_en;
  reg        rd_en;
  reg  [7:0] data_in;
  wire [7:0] data_out;
  wire       full;
  wire       empty;

  integer errors = 0;
  integer checks = 0;
  integer i;

  FIFO_8BIT #(
      .DEPTH(DEPTH)
  ) fifo_inst (
      .clk(clk),
      .rst(rst),
      .wr_en(wr_en),
      .rd_en(rd_en),
      .data_in(data_in),
      .data_out(data_out),
      .full(full),
      .empty(empty)
  );

  always #5 clk = ~clk;

  task chk(input [7:0] got, input [7:0] exp, input [255:0] label);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        $display("  FAIL: %0s  got=%02x expected=%02x", label, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  // One-clock write: drive on negedge so the posedge sample is unambiguous.
  task fifo_write(input [7:0] value);
    begin
      @(negedge clk);
      data_in = value;
      wr_en   = 1'b1;
      @(negedge clk);
      wr_en = 1'b0;
    end
  endtask

  // One-clock read: data_out is registered on the intervening posedge.
  task fifo_read;
    begin
      @(negedge clk);
      rd_en = 1'b1;
      @(negedge clk);
      rd_en = 1'b0;
    end
  endtask

  initial begin
    rst     = 1;
    wr_en   = 0;
    rd_en   = 0;
    data_in = 8'b0;
    repeat (2) @(negedge clk);
    rst = 0;
    @(negedge clk);

    // 1. Reset state
    chk({7'b0, empty}, 8'h01, "after reset: empty=1");
    chk({7'b0, full}, 8'h00, "after reset: full=0");

    // 2. Write two, read them back in order
    fifo_write(8'hA5);
    fifo_write(8'h5A);
    chk({7'b0, empty}, 8'h00, "after 2 writes: empty=0");
    fifo_read;
    chk(data_out, 8'hA5, "readback word 1 = A5");
    fifo_read;
    chk(data_out, 8'h5A, "readback word 2 = 5A");
    chk({7'b0, empty}, 8'h01, "after 2 reads: empty=1");

    // 3. Mid-stream reset clears the FIFO
    fifo_write(8'hB5);
    fifo_write(8'h6B);
    @(negedge clk);
    rst = 1;
    @(negedge clk);
    rst = 0;
    @(negedge clk);
    chk({7'b0, empty}, 8'h01, "after mid-stream reset: empty=1");
    chk({7'b0, full}, 8'h00, "after mid-stream reset: full=0");

    // 4. Fill to DEPTH -> full; an extra write must be ignored
    for (i = 0; i < DEPTH; i = i + 1) fifo_write(8'hF0 + i[7:0]);
    chk({7'b0, full}, 8'h01, "after DEPTH writes: full=1");
    fifo_write(8'hEE);  // must be dropped (full)
    chk({7'b0, full}, 8'h01, "write-when-full ignored: still full=1");

    // 5. Read everything back in order
    for (i = 0; i < DEPTH; i = i + 1) begin
      fifo_read;
      chk(data_out, 8'hF0 + i[7:0], "full readback in order");
    end
    chk({7'b0, empty}, 8'h01, "after full readback: empty=1");

    // 6. Read on empty drives data_out to 0
    fifo_read;
    chk(data_out, 8'h00, "read-when-empty: data_out=0");

    @(negedge clk);
    if (errors == 0 && checks == CHECKS_EXPECTED)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors / %0d checks, expected %0d)",
               errors, checks, CHECKS_EXPECTED);
    $finish;
  end

  initial begin
    #100000;
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule
