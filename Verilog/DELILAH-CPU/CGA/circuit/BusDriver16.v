
/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CPU/PROC/CGA                                                          **
**  BusDriver16                                                          **
**                                                                       ** 
** SHEET 4 of 8 (Page 5 in PDF)                                          **
**                                                                       ** 
** Last reviewed: 15-JAN-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/



module BusDriver16(
       input wire        EN,            // Enable = FALSE => A to IO, Enable=TRUE => IO to ZI
       input wire        TN,            // Test enable

       input wire[15:0]  A_15_0,        // Data inputA (Connect to internal FIDBO data bus))         

       inout wire[15:0]  IO_15_0,       // IN and OUT to XFIDB data bus (Connect to EXTERNAL _XFIDB_ data bus)

       output wire[15:0] ZI_15_0        // Z output  (Connect to internal XFIDBI data bus)
   );

   reg [15:0] IO_reg; // Internal data register
   reg [15:0] ZI_reg; // Internal data register


   //assign ZI_15_0 = TN ?  IO_15_0 : 16'bZ; // Probably the correct implementation ? In test moode we should be isolated ?
   //assign ZI_15_0 = TN ?  internalData : 16'bZ; // Probably the correct implementation ? In test moode we should be isolated ?

   always @(*) begin
      if (EN == 1'b0) begin
         // Write A to IO
         IO_reg  = A_15_0;         
      end
      else begin
         // Read IO to ZI 
         ZI_reg = IO_15_0;
      end
   end

   // Bidirectional data operation
   assign IO_15_0 = TN ? ((EN == 1'b0) ? IO_reg : 16'bz) : 16'bz;     
   assign ZI_15_0 = ZI_reg;


endmodule