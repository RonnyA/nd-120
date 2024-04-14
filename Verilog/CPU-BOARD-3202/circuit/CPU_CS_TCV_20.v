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
                      input [63:0] CSBITS,
                      output [63:0] CSBITS_OUT,
                      input [15:0] IDB_15_0,
                      output [15:0] IDB_15_0_OUT,
                      input ECSL_n,
                      input WCS_n,
                      input [3:0]   EW_3_0_n // output enable signals                                      
                      );

   

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_csbits_15_0;
   wire [15:0] s_csbits_31_16;
   wire [15:0] s_csbits_47_32;
   wire [15:0] s_csbits_63_48;

   wire [15:0] s_idb_15_0_out;


   // WCS_n decices is its DIR-ection of the data from CSBITS => IDB or CSBITS <= IDB

   // IDB IN

   // Write to CSBITS from IDB
   assign s_csbits_15_0  = (WCS_n & !EW_3_0_n[0]) ? IDB_15_0 : CSBITS[15:0];
   assign s_csbits_31_16 = (WCS_n & !EW_3_0_n[1]) ? IDB_15_0 : CSBITS[31:16];
   assign s_csbits_47_32 = (WCS_n & !EW_3_0_n[2]) ? IDB_15_0 : CSBITS[47:32]; 
   assign s_csbits_63_48 = (WCS_n & !EW_3_0_n[3]) ? IDB_15_0 : CSBITS[63:48];

   assign CSBITS_OUT = {s_csbits_63_48, s_csbits_47_32, s_csbits_31_16, s_csbits_15_0};

   // Write to IDB from CSBITS
   assign s_idb_15_0_out = EW_3_0_n[0] ? 16'bz : CSBITS[15:0];   
   assign s_idb_15_0_out = EW_3_0_n[1] ? 16'bz : CSBITS[31:16];   
   assign s_idb_15_0_out = EW_3_0_n[2] ? 16'bz : CSBITS[47:32];
   assign s_idb_15_0_out = EW_3_0_n[3] ? 16'bz : CSBITS[63:48];

   // ECSL_n decides if the data should be enabled out on the IDB bus   
   assign IDB_15_0_OUT = ECSL_n ? 16'bz : s_idb_15_0_out;   

   


endmodule
