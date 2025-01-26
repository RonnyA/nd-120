/********************************************************************************************
** ND120 Shared                                                                            **
**                                                                                         **
**                                                                                         **
**  TMM2018D_25 | 16K bit Static RAM (Used by Cache and Page Tables)                       **
**                                                                                         **
** PDF doc: https://www.alldatasheet.com/datasheet-pdf/view/113475/TOSHIBA/TMM2018AP.html  **
**                                                                                         **
** Last reviewed: 26-JANUARY-2025                                                          **
** Ronny Hansen                                                                            **
*********************************************************************************************/



module TMM2018D_25 #(parameter INSTANCE_NAME = "TMM2018")
(
    // Input signals
    input wire    clk, // Clock input (needed for BLOCK RAM)
    input wire    reset_n, // FPGA Reset input (active low)

    input  wire [10:0] ADDRESS,  // 11 bits address
    input  wire        CS_n,     // When Chip Select goes HIGH the device is deselected is placed in low-power mode
    input  wire        OE_n,     // Output buffer control
    input  wire        W_n,      // Write enable (active low)
    input  wire [ 7:0] D,        // 8 bit data input

    // Output signal
    output wire [ 7:0] D_OUT    // 8 bit data output (when Chip is selected, no write, and output is enabled)
);

//  integer i;

  /*******************************************************************************
** Memory array using block RAM                                               **
*******************************************************************************/
  (* ram_style = "block" *) reg [7:0] memory_array[0:2047];  // 2^11 addresses, each 8-bit wide = 2KB (or 16Kbit)

  always @(posedge clk)
  begin
    if (!reset_n) begin
      /* verilator lint_off BLKSEQ */

      // BLOCK RAM DOESNT SUPPORT INITIALISATION

      // Reset operation: set all memory locations to 0
      //for (i = 0; i < 2047; i = i + 1) begin
      //   memory_array[i] = 8'b00000000; // none delayed initialisation
      //end
      /* verilator lint_on BLKSEQ */
    end
  end

  always @(negedge W_n)
  begin
      if (!CS_n) begin 
          // Write operation: active when chip is selected and write enable is low
          memory_array[ADDRESS] <= D;
          //$display("%s WRITE Address %04h Value %2h", INSTANCE_NAME, ADDRESS, D);
      end
  end

  // Output is enabled when OE_n, but not during write
  assign D_OUT = OE_n ? 8'b0 : W_n ? memory_array[ADDRESS] : 8'b0;

endmodule

