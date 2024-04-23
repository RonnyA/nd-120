/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CPU/CS/TCV                                                            **
** CS TRANSCEIVERS                                                       **
** SHEET 20 of 50                                                        **
**                                                                       ** 
** Last reviewed: 14-APRIL-2024                                          **
** Ronny Hansen                                                          **               
***************************************************************************/

module CPU_CS_TCV_20(
                      input  [63:0] CSBITS,
                      output [63:0] CSBITS_OUT,

                      input  [15:0] IDB_15_0_IN,
                      output [15:0] IDB_15_0_OUT,

                      input         ECSL_n,
                      input         WCS_n,
                      input [3:0]   EW_3_0_n // output enable signals                                      
                      );

   

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   reg [63:0] regCSBITS;
   reg [15:0] regIDB;

   reg [2:0] selector;

   // WCS_n decides is its DIR-ection of the data from CSBITS => IDB or CSBITS <= IDB

   
   always @(*) begin
      
      if (EW_3_0_n[0] == 0) begin         
         selector = 1;
      end else if (EW_3_0_n[1] == 0) begin         
         selector = 2;
      end else if (EW_3_0_n[2] == 0) begin         
         selector = 3;
      end else if (EW_3_0_n[3] == 0) begin         
         selector = 4;
      end else begin        
         selector = 0;
      end         
   

      if (!WCS_n) begin
         // Write to CSBITS from IDB               
         case (selector)
            1: regCSBITS[15:0]  = IDB_15_0_IN;
            2: regCSBITS[31:16] = IDB_15_0_IN;
            3: regCSBITS[47:32] = IDB_15_0_IN;
            4: regCSBITS[63:48] = IDB_15_0_IN;
         endcase

      end else begin
         // Write to IDB from CSBITS         

         case (selector)
            1: regIDB = CSBITS[15:0];
            2: regIDB = CSBITS[31:16];
            3: regIDB = CSBITS[47:32];
            4: regIDB = CSBITS[63:48];            
         endcase
      end
   end


   // Write to CSBITS from IDB
   //assign s_csbits_15_0  = (!WCS_n & !EW_3_0_n[0]) ? IDB_15_0_IN : CSBITS[15:0];
   //assign s_csbits_31_16 = (!WCS_n & !EW_3_0_n[1]) ? IDB_15_0_IN : CSBITS[31:16];
   //assign s_csbits_47_32 = (!WCS_n & !EW_3_0_n[2]) ? IDB_15_0_IN : CSBITS[47:32]; 
   //assign s_csbits_63_48 = (!WCS_n & !EW_3_0_n[3]) ? IDB_15_0_IN : CSBITS[63:48];

   

   // Write to IDB from CSBITS
   //assign regidb = EW_3_0_n[0] ? 16'bz : CSBITS[15:0];   
   //assign regidb = EW_3_0_n[1] ? 16'bz : CSBITS[31:16];   
   //assign regidb = EW_3_0_n[2] ? 16'bz : CSBITS[47:32];
   //assign regidb = EW_3_0_n[3] ? 16'bz : CSBITS[63:48];
 


   // ECSL_n decides if the data should be enabled out on the IDB bus   
   assign IDB_15_0_OUT = (ECSL_n & !WCS_n) ? 16'bz : regIDB[15:0];   
   assign CSBITS_OUT = regCSBITS;

endmodule
