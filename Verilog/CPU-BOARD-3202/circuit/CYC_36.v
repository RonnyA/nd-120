/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CYC                                                                   **
** CYCLE CONTROL                                                         **
** SHEET 36 of 50                                                        **
**                                                                       **
** Last reviewed: 9-NOVEMBER-2024                                        **
** Ronny Hansen                                                          **
***************************************************************************/


module CYC_36(
/* verilator lint_off UNUSEDSIGNAL */
               input sysclk, // System clock in FPGA
               input sys_rst_n, // System reset in FPGA
/* verilator lint_on UNUSEDSIGNAL */

               input OSC,

               input ACOND_n,
               input BRK_n,
               input CGNTCACT_n,
               input CSALUI7,
               input CSALUI8,
               input CSALUM0,
               input CSALUM1,
               input [1:0] CSDELAY_1_0,
               input CSDLY,
               input CSECOND,
               input CSLOOP,
               input FORM_n,
               input HIT,
               input IORQ_n,
               input LBA0,
               input LBA1,
               input LBA3,
               input LSHADOW,
               input LUA12,
               input MREQ_n,
               input MR_n,
               input PD1,
               input PD4,
               input RRF_n,
               input RT_n,
               input RWCS_n,
               input SHORT_n,
               input SLOW_n,
               input TRAP_n,
               input VEX,

               // Outputs
               output ALUCLK,
               output CLK,
               output MACLK,
               output MCLK,
               output UCLK,
               output WRFSTB,
               output CYD,
               output [2:0]  CC_3_1_n,
               output TERM_n,
               output MAP_n,
               output CX_n,
               output EORF_n,
               output ETRAP_n,
               output LCS_n
);

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [1:0] s_csdelay_1_0;
   wire [2:0] s_cc_3_1_n;

   // not used - uncomment if needed in the future
   // wire       s_dlshadow;
   // wire       s_DMA12_n;
   // wire       S_DMAP_n;
   // wire       s_nowrite_n;
   // wire       s_MDLY_n;

   wire       c_csdly;
   wire       s_acond_n;
   wire       s_aluclk;
   wire       s_brk_n;
   wire       s_cc0_n;
   wire       s_cgntcact_n;
   wire       s_clk;
   wire       s_csalui7;
   wire       s_csalui8;
   wire       s_csalum0;
   wire       s_csalum1;
   wire       s_csecond;
   wire       s_csloop;
   wire       s_cx_n;
   wire       s_cyd;
   wire       s_dly0_n;
   wire       s_dly1_n;
   wire       s_eorf_n;
   wire       s_etrap_n;
   wire       s_form_n;
   wire       s_hit;
   wire       s_iorq_n;
   wire       s_lba0;
   wire       s_lba1;
   wire       s_lba3;
   wire       s_lcs_n;
   wire       s_lcs;
   wire       s_lshadow;
   wire       s_lua12;
   wire       s_maclk_n;
   wire       s_maclk_out;
   wire       s_map_n;
   wire       s_mclk_n;
   wire       s_mclk;
   wire       s_mr_n;
   wire       s_mreq_n_or_lshadow;
   wire       s_mreq_n;
   wire       s_osc;
   wire       s_out25h_pin6;
   wire       s_pd1;
   wire       s_pd4;
   wire       s_RRF_n;
   wire       s_rt_n_or_lshadow;
   wire       s_rt_n;
   wire       s_rwcs_n;
   wire       s_short_n;
   wire       s_slcond_n;
   wire       s_slow_n;
   wire       s_term_n;
   wire       s_trap_n;
   wire       s_uclk_out;
   wire       s_uclk;
   wire       s_vex;
   wire       s_wait1;
   wire       s_wait2;
   wire       s_wrfstb;


   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign c_csdly             = CSDLY;
   assign s_acond_n           = ACOND_n;
   assign s_brk_n             = BRK_n;
   assign s_cgntcact_n        = CGNTCACT_n;
   assign s_csalui7           = CSALUI7;
   assign s_csalui8           = CSALUI8;
   assign s_csalum0           = CSALUM0;
   assign s_csalum1           = CSALUM1;
   assign s_csdelay_1_0[1:0]  = CSDELAY_1_0[1:0];
   assign s_csecond           = CSECOND;
   assign s_csloop            = CSLOOP;
   assign s_form_n            = FORM_n;
   assign s_hit               = HIT;
   assign s_iorq_n            = IORQ_n;
   assign s_lba0              = LBA0;
   assign s_lba1              = LBA1;
   assign s_lba3              = LBA3;
   assign s_lshadow           = LSHADOW;
   assign s_lua12             = LUA12;
   assign s_mr_n              = MR_n;
   assign s_mreq_n            = MREQ_n;
   assign s_osc               = OSC;
   assign s_pd1               = PD1;
   assign s_pd4               = PD4;
   assign s_RRF_n             = RRF_n;
   assign s_rt_n              = RT_n;
   assign s_rwcs_n            = RWCS_n;
   assign s_short_n           = SHORT_n;
   assign s_slow_n            = SLOW_n;
   assign s_trap_n            = TRAP_n;
   assign s_vex               = VEX;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign ALUCLK   = s_aluclk;
   assign CC_3_1_n = s_cc_3_1_n[2:0];
   assign CLK      = s_clk;
   assign CX_n     = s_cx_n;
   assign CYD      = s_cyd;
   assign EORF_n   = s_eorf_n;
   assign ETRAP_n  = s_etrap_n;
   assign LCS_n    = s_lcs_n;
   assign MACLK    = s_maclk_out;
   assign MAP_n    = s_map_n;
   assign MCLK     = s_mclk;
   assign TERM_n   = s_term_n;
   assign UCLK     = s_uclk_out;
   assign WRFSTB   = s_wrfstb;

   /*******************************************************************************
   ** Refactored all gates to use Verilog code for and/or/not                    **
   *******************************************************************************/
   assign s_lcs         = ~s_lcs_n;
   assign s_clk         = ~s_term_n;
   assign s_aluclk      = ~(s_term_n | s_lcs);
   assign s_mclk        = ~(s_term_n & s_mclk_n);
   assign s_maclk_out   = ~(s_term_n & s_maclk_n);
   assign s_uclk_out    =  (s_term_n & s_uclk);


   assign s_rt_n_or_lshadow   =  (s_lshadow | s_rt_n);
   assign s_mreq_n_or_lshadow =  (s_mreq_n | s_lshadow);
   assign s_out25h_pin6       = ~(s_mreq_n_or_lshadow & s_iorq_n);

   assign s_wait1  =  (s_mr_n & s_out25h_pin6);
   assign s_wait2  = ~(s_iorq_n & s_rt_n_or_lshadow);

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   PAL_44601B   PAL_44601_UCYCFSM
   (
      .CK(s_osc),                 //CK
      .OE_n(s_pd4),               //OE_n

      //I0-I7
      .DLY1_n(s_dly1_n),           //I0
      .DLY0_n(s_dly0_n),           //I1
      .CSDELAY0(s_csdelay_1_0[0]), //I2
      .WAIT1(s_wait1),             //I3
      .WAIT2(s_wait2),             //I4
      .CGNTCACT_n(s_cgntcact_n),   //I5
      .HIT(s_hit),                 //I6
      .BRK_n(s_brk_n),             //I7

      // B0-B1
      .SLOW_n(s_slow_n),           //B0
      .SHORT_n(s_short_n),         //B1

      //Q0-Q5 (clocked and 3-state)
      .CX_n(s_cx_n),               //Q0
      .TERM_n(s_term_n),           //Q1
      .CC0_n(s_cc0_n),             //Q2
      .CC1_n(s_cc_3_1_n[0]),       //Q3
      .CC2_n(s_cc_3_1_n[1]),       //Q4
      .CC3_n(s_cc_3_1_n[2])        //Q5
   );

   PAL_44307C   PAL_44307_UCYCLK
   (
      .TERM_n(s_term_n),          // I0
      .CC0_n(s_cc0_n),            // I1
      .CC1_n(s_cc_3_1_n[0]),      // I2
      .CC2_n(s_cc_3_1_n[1]),      // I3
      .CC3_n(s_cc_3_1_n[2]),      // I4
      .FORM_n(s_form_n),          // I5
      .BRK_n(s_brk_n),            // I6
      .RWCS_n(s_rwcs_n),          // I7
      .TRAP_n(s_trap_n),          // I8
      .VEX(s_vex),                // I9
      .MCLK_n(s_mclk_n),          // Y0_n
      .MACLK_n(s_maclk_n),        // Y1_n
      .WRFSTB(s_wrfstb),          // B0_n
      .CYD(s_cyd),                // B1_n
      .EORF_n(s_eorf_n),          // B2_n
      .UCLK(s_uclk),              // B3_n
      .ETRAP_n(s_etrap_n),        // B4_n
      .MAP_n(s_map_n)             // B5_n
   );

 /* verilator lint_off PINMISSING */
   PAL_44403C   PAL_44403_UCYIN0
   (
      .CLK(s_clk),                  //CK
      .OE_n(s_pd1),                 //OE_n


      .CSDELAY0(s_csdelay_1_0[0]),  //I0
      .CSDLY(c_csdly),              //I1
      .CSECOND(s_csecond),          //I2
      .CSLOOP(s_csloop),            //I3
      .ACOND_n(s_acond_n),          //I4
      .MR_n(s_mr_n),                //I5
      .LUA12(s_lua12),              //I6
      .MAP_n(s_map_n),              //I7

      //Q0-Q3 (clocked and 3-state)
      .LCS_n(s_lcs_n),              //Q0_n
      //.MDLY_n(s_MDLY_n),          //Q1_n  (not used)
      //.DMA12_n(s_DMA12_n),        //Q2_n  (not used)
      //.DMA12_n(),                 //Q2_n  (not used)
      //.DMAP_n(s_DMAP_n),          //Q3_n  (not used)

      .DLY0_n(s_dly0_n),            //B0_n
      .SLCOND_n(s_slcond_n)         //B2_n

   );

   PAL_44404C   PAL_44404_UCYIN1
   (
      .CLK(s_clk),                 //CK
      .OE_n(s_pd1),                //OE_n

      .CSDELAY1(s_csdelay_1_0[1]),  //I0
      .CSALUM1(s_csalum1),          //I1
      .CSALUM0(s_csalum0),          //I2
      .CSALUI8(s_csalui8),          //I3
      .CSALUI7(s_csalui7),          //I4
      .LBA3(s_lba3),                //I5
      .LBA1(s_lba1),                //I6
      .LBA0(s_lba0),                //I7

      //Q0-Q3 (clocked and 3-state)
      //.NOWRIT_n(s_nowrite_n),     //Q0_n (not used)
      //.DLSHADOW(s_dlshadow),      //Q1_n (not used)

      .RRF_n(s_RRF_n),              // B0_n
      .LSHADOW(s_lshadow ),         // B1_n
      .SLCOND_n(s_slcond_n),        // B2_n
      .DLY1_n(s_dly1_n)             // B3_n
   );

endmodule

