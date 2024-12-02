
/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component : IMS1403_25                                                **
** 16K x 1 Static RAM                                                    **
**                                                                       **
** Last reviewed: 1-DEC-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module IMS1403_25 (
    input wire    clk, // Clock input (needed for BLOCK RAM)
    input wire    reset_n, // FPGA Reset input (active low)

    input  [13:0] ADDRESS,  // 14 bits address
    input         CE_n,
    input         D,
    input         W_n,
    output        Q
);


  integer i;

  /*******************************************************************************
   ** Signals                                                                    **
   *******************************************************************************/
  reg  data_out;    // Output data register
  wire data_in;     // Input data from the bus

  assign data_in = D;  // Connect input data

  assign Q  = (!CE_n && W_n) ? data_out : 1'b0;  //Q is high impedance when W_n (write) is active and when chip is not selected



  // Define the memory array


  /*******************************************************************************
   ** Memory array using block RAM                                               **
   *******************************************************************************/
  (* ram_style = "block" *) reg memory_array[0:16383];


  always @(posedge clk) begin

    if (!reset_n) begin
      /* verilator lint_off BLKANDNBLK */
      /* verilator lint_off BLKSEQ */

      //TODO: Find a reset method that VIVADO likes
      // Reset operation: set all memory locations to 0
      //for (i = 0; i < 16383; i = i + 1) begin
      ///  memory_array[i] = 1'b0; // none delayed initialisation
      //end
      /* verilator lint_on BLKSEQ */
    end else begin
      if (!CE_n) begin
        if (!W_n) begin
          memory_array[ADDRESS] <= data_in;  // Write operation
        end else begin
          data_out <= memory_array[ADDRESS];  // Read operation
        end
      end
    end
  end

endmodule
