/**************************************************************************
** FIFO 8 bit                                                            **
**                                                                       **
**                                                                       **
** Last reviewed: 9-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

// Turn of warning/error for mixed block and none-blocking assignments as its valid verilog
// verilator lint_off BLKANDNBLK
// https://verilator.org/guide/latest/warnings.html#cmdoption-arg-BLKANDNBLK

module FIFO_8BIT #(
    parameter byte DEPTH = 13  // Depth of the FIFO (maximum 16, default 13)
) (
    input            rst,       // Asynchronous reset
    input            wr_en,     // Write enable
    input            rd_en,     // Read enable
    input      [7:0] data_in,   // Data input
    output reg [7:0] data_out,  // Data output
    output           full,      // FIFO full flag
    output           empty      // FIFO empty flag
);

  /* verilator lint_off LATCH */
  /* verilator lint_off BLKSEQ */
  /* verilator lint_off UNOPTFLAT */

  // Calculate address width based on depth
  localparam int AddressWidth = $clog2(DEPTH + 1);

  reg [7:0] mem[DEPTH-1];  // Memory array
  reg [AddressWidth-1:0] wr_ptr;  // Write pointer
  reg [AddressWidth-1:0] rd_ptr;  // Read pointer
  reg [AddressWidth:0] fifo_count;  // Counter for number of elements in the FIFO

  always @(posedge rd_en or posedge wr_en or posedge rst) begin
    if (rst) begin
      wr_ptr = 0;
      rd_ptr = 0;
      data_out = 8'b0;
      fifo_count = 0;
    end else if (wr_en && !full) begin
      mem[wr_ptr] <= data_in;
      wr_ptr <= (wr_ptr == (DEPTH - 1)) ? 0 : wr_ptr + 1;
      fifo_count <= fifo_count + 1;
    end else if (rd_en) begin
      if (!empty) begin
        data_out <= mem[rd_ptr];
        rd_ptr <= (rd_ptr == (DEPTH - 1)) ? 0 : rd_ptr + 1;
        fifo_count <= fifo_count - 1;
      end else begin
        data_out <= 8'b0;
      end
    end
  end

  assign full  = (fifo_count == DEPTH);
  assign empty = (fifo_count == 0);

endmodule
