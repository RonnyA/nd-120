/**************************************************************************
** ND120 CPU, MM&M                                                       **
** IO                                                                    **
** IO TOP LEVEL                                                          **
** SHEET 37 of 50                                                        **
**                                                                       **
** Last reviewed: 22-MAR-2025                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module IO_37(

   input sysclk,      // System clock in FPGA
   input sys_rst_n,   // System reset in FPGA

   input [3:0] BAUD_RATE_SWITCH,
   input       BDRY50_n,
   input       BRK_n,
   input       CLK,
   input       CONSOLE_n,
   input [4:0] CSCOMM_4_0,  //! Control Store Command (5 bits)
   input [4:0] CSIDBS_4_0,  //! Control Store IDB Source (5 bits)
   input [1:0] CSMIS_1_0,   //! Control Store MIS signal (2 bits)
   input [1:0] MIS_1_0,     //! Clocked CSMIS (2 bits)
   input       CX_n,
   input       DAP_n,
   input       EAUTO_n,
   input       EORF_n,
   input       HIT,
   input       ICONTIN_n,
   input       ILOAD_n,
   input [7:0] INR_7_0,
   input       IONI,
   input       ISTOP_n,
   input       LCS_n,
   input       LEV0,
   input       LOCK_n,
   input       LSHADOW,
   input [1:0] OC_1_0,
   input       OPCLCS,
   input       OSCCL_n,
   input [1:0] PCR_1_0,
   input       PONI,         //! Memory Protection ON, PONI=1
   input       POWSENSE_n,
   input       REF_n,
   input       RXD,
   input       SEL5MS_n,
   input       SWMCL_n,
   input       UCLK,
   input       XTAL1,
   input       XTAL2,
   input       XTR,

   // Input and Output signals
   input  [7:0]  IDB_7_0_IN,
   output [15:0] IDB_15_0_OUT,


   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output       BINT10_n,
   output       BINT12_n,
   output       BINT13_n,
   output       CA10,
   output       CCLR_n,
   output       CLEAR_n,

   output [4:0] DP_5_1_n,
   output       DT_n,
   output       DVACC_n,
   output       ECREQ,
   output       ECSR_n,
   output       EDO_n,
   output       EMCL_n,
   output       EMPID_n,
   output       ESTOF_n,
   output       FETCH,
   output       FMISS,
   output       FORM_n,
   output       IORQ_n,
   output       MCL,
   output       MREQ_n,
   output       OSC,
   output       PAN_n,
   output       PA_n,
   output       POWFAIL_n,
   output       PS_n,
   output       REFRQ_n,
   output       RT_n,
   output       RWCS_n,
   output       SHORT_n,
   output       SLOW_n,
   output       SSEMA_n,
   output       STOC_n,
   output       STP,
   output       TOUT,
   output       TXD,
   output       WCHIM_n,
   output       WRITE,
   output [1:0] IOLED // 0=RED,1=GREEN
);



   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_idb_15_0_uart_out;
   wire [15:0] s_idb_15_0_pancal_out;
   wire [15:0] s_idb_15_0_reg_out;

   wire [7:0]  s_idb_7_0_in;


   wire [7:0]  s_pa_7_0;
   wire [1:0]  s_oc_1_0;
   wire [1:0]  s_stat_4_3;
   wire [4:0]  s_cscomm_4_0;
   wire [4:0]  s_dp_5_1_n;

   wire [4:0]  s_csidbs_4_0;
   wire [1:0]  s_pcr_1_0;
   wire [1:0]  s_mis_1_0;
   wire [1:0]  s_csmis_1_0;
   wire [7:0]  s_inr_7_0;
   wire        s_traald_n;
   wire        s_osc;
   wire        s_eauto_n;
   wire        s_write;
   wire        s_emcl_n;
   wire        s_pposc;
   wire        s_sioc_n;
   wire        s_xtal2;
   wire        s_eior_n;
   wire        s_tbmt_n;
   wire        s_bint12_n;
   wire        s_pan_n;
   wire        s_iorq_n;
   wire        s_ps_n;
   wire        s_ecreq;
   wire        s_ioni;
   wire        s_swmcl_n;
   wire        s_rinr_n;
   wire        s_ceuart_n;
   wire        s_lcs_n;
   wire        s_refrq_n;
   wire        s_epans_n;
   wire        s_ref_n;
   wire        s_uclk;
   wire        s_stoc_n;
   wire        s_da_n;
   wire        s_empid_n;
   wire        s_dvacc_n;
   wire        s_form_n;
   wire        s_pa_n;
   wire        s_ca10;
   wire        s_iload_n;
   wire        s_ruart_n;
   wire        s_powfail_n;
   wire        s_xtal1;
   wire        s_mcl;
   wire        s_lev0;
   wire        s_osccl_n;
   wire        s_dap_n;
   wire        s_poni;
   wire        s_ssema_n;
   wire        s_lhit;
   wire        s_rwcs_n;
   wire        s_fetch;
   wire        s_tout;
   wire        s_rmm_n;
   wire        s_hit;
   wire        s_emp_n;
   wire        s_bdry50_n;
   wire        s_cx_n;
   wire        s_lock_n;
   wire        s_ecsr_n;
   wire        s_eorf_n;
   wire        s_istop_n;
   wire        s_stp;
   wire        s_cclr_n;
   wire        s_estof_n;
   wire        s_slow_n;
   wire        s_powsense_n;
   wire        s_icontin_n;
   wire        s_clear_n;
   wire        s_dt_n;
   wire        s_console_n;
   wire        s_io_console_n;
   wire        s_uart_console_n;
   wire        s_bint10_n;
   wire        s_bint13_n;
   wire        s_fmiss;
   wire        s_mreq_n;
   wire        s_rt_n;
   wire        s_ful_n;
   wire        s_val;
   wire        s_edo_n;
   wire        s_rxd;
   wire        s_txd;
   wire        s_lshadow;
   wire        s_sel5ms_n;
   wire        s_panosc;
   wire        s_brk_n;
   wire        s_opclcs;
   wire        s_xtr;
   wire        s_clk;
   wire        s_short_n;
   wire        s_wchim_n;
   wire  [7:0] s_idb_7_0_dcd_out; // output from DGA module (submodule dga_pow)



   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/

   assign s_cscomm_4_0[4:0]   = CSCOMM_4_0;
   assign s_csidbs_4_0[4:0]   = CSIDBS_4_0;
   assign s_csmis_1_0[1:0]    = CSMIS_1_0;
   assign s_mis_1_0[1:0]      = MIS_1_0;
   assign s_idb_7_0_in[7:0]   = IDB_7_0_IN[7:0];
   assign s_inr_7_0[7:0]      = INR_7_0[7:0];
   assign s_oc_1_0[1:0]       = OC_1_0;
   assign s_pcr_1_0[1:0]      = PCR_1_0;

   assign s_eauto_n           = EAUTO_n;
   assign s_xtal2             = XTAL2;
   assign s_ioni              = IONI;
   assign s_swmcl_n           = SWMCL_n;
   assign s_lcs_n             = LCS_n;
   assign s_ref_n             = REF_n;
   assign s_uclk              = UCLK;
   assign s_iload_n           = ILOAD_n;
   assign s_xtal1             = XTAL1;
   assign s_lev0              = LEV0;
   assign s_osccl_n           = OSCCL_n;
   assign s_dap_n             = DAP_n;
   assign s_poni              = PONI;
   assign s_hit               = HIT;
   assign s_bdry50_n          = BDRY50_n;
   assign s_cx_n              = CX_n;
   assign s_lock_n            = LOCK_n;
   assign s_eorf_n            = EORF_n;
   assign s_istop_n           = ISTOP_n;
   assign s_powsense_n        = POWSENSE_n;
   assign s_icontin_n         = ICONTIN_n;
   assign s_rxd               = RXD;
   assign s_lshadow           = LSHADOW;
   assign s_sel5ms_n          = SEL5MS_n;
   assign s_brk_n             = BRK_n;
   assign s_opclcs            = OPCLCS;
   assign s_xtr               = XTR;
   assign s_clk               = CLK;
   assign s_console_n         = CONSOLE_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BINT10_n   = s_bint10_n;
   assign BINT12_n   = s_bint12_n;
   assign BINT13_n   = s_bint13_n;
   assign CA10       = s_ca10;
   assign CCLR_n     = s_cclr_n;
   assign CLEAR_n    = s_clear_n;
   assign DP_5_1_n   = s_dp_5_1_n[4:0];
   assign DT_n       = s_dt_n;
   assign DVACC_n    = s_dvacc_n;
   assign ECREQ      = s_ecreq;
   assign ECSR_n     = s_ecsr_n;
   assign EDO_n      = s_edo_n;
   assign EMCL_n     = s_emcl_n;
   assign EMPID_n    = s_empid_n;
   assign ESTOF_n    = s_estof_n;
   assign FETCH      = s_fetch;
   assign FMISS      = s_fmiss;
   assign FORM_n     = s_form_n;

   assign IDB_15_0_OUT[15:0] =
      s_idb_15_0_uart_out[15:0]     |
      s_idb_15_0_pancal_out[15:0]   |
      s_idb_15_0_reg_out[15:0]      |
      {8'b00000000, s_idb_7_0_dcd_out[7:0]};

   assign IORQ_n     = s_iorq_n;
   assign MCL        = s_mcl;
   assign MREQ_n     = s_mreq_n;
   assign OSC        = s_osc;
   assign PAN_n      = s_pan_n;
   assign PA_n       = s_pa_n;
   assign POWFAIL_n  = s_powfail_n;
   assign PS_n       = s_ps_n;
   assign REFRQ_n    = s_refrq_n;
   assign RT_n       = s_rt_n;
   assign RWCS_n     = s_rwcs_n;
   assign SHORT_n    = s_short_n;
   assign SLOW_n     = s_slow_n;
   assign SSEMA_n    = s_ssema_n;
   assign STOC_n     = s_stoc_n;
   assign STP        = s_stp;
   assign TOUT       = s_tout;
   assign TXD        = s_txd;
   assign WCHIM_n    = s_wchim_n;
   assign WRITE      = s_write;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   // Or together console_n signal from IO_REG and from Port A.
   // Negate "console_n" to get "console" - that way OR will work as expected.
   assign s_uart_console_n = ~(!s_io_console_n | !s_console_n);

   IO_REG_41   REG_MODULE (.BINT10_n(s_bint10_n),
                           .BINT12_n(s_bint12_n),
                           .BINT13_n(s_bint13_n),
                           .CLEAR_n(s_clear_n),
                           .CONSOLE_n(s_io_console_n),
                           .CX_n(s_cx_n),
                           .DA_n(s_da_n),
                           .EMCL_n(s_emcl_n),
                           .IDB_7_0_IN(s_idb_7_0_in[7:0]),
                           .IDB_15_0_OUT(s_idb_15_0_reg_out[15:0]),
                           .INR_7_0(s_inr_7_0[7:0]),
                           .RINR_n(s_rinr_n),
                           .SIOC_n(s_sioc_n),
                           .TBMT_n(s_tbmt_n),
                           .TRAALD_n(s_traald_n),
                           .IOLED(IOLED[1:0]));

   IO_PANCAL_40   PANCAL
   (
      .CLEAR_n(s_clear_n),
      .DP_5_1_n(s_dp_5_1_n[4:0]),
      .EMP_n(s_emp_n),
      .EPANS(s_epans_n),
      .FUL_n(s_ful_n),
      .IDB_15_0_OUT(s_idb_15_0_pancal_out[15:0]),
      .IONI(s_ioni),
      .LEV0(s_lev0),
      .LHIT(s_lhit),
      .PANOSC(s_panosc),
      .PA_7_0(s_pa_7_0[7:0]),
      .PCR_1_0(s_pcr_1_0[1:0]),
      .PONI(s_poni),
      .RMM_n(s_rmm_n),
      .STAT_4_3(s_stat_4_3[1:0]),
      .VAL(s_val)
   );

   IO_UART_42   UART
   (
      .sysclk(sysclk), // System clock in FPGA
      .sys_rst_n(sys_rst_n), // System reset in FPGA

      // Input signals
      .CEUART_n(s_ceuart_n),
      .CLK(s_clk),
      .CONSOLE_n(s_uart_console_n),
      .EAUTO_n(s_eauto_n),
      .EIOR_n(s_eior_n),
      .LCS_n(s_lcs_n),
      .LOCK_n(s_lock_n),
      .MIS_1_0(s_mis_1_0[1:0]),
      .PPOSC(s_pposc),
      .RUART_n(s_ruart_n),
      .XTR(s_xtr),

      // RS232 RX/TX signals
      .RXD(s_rxd),
      .TXD(s_txd),

      // Baud dare settings
      .BAUD_RATE_SWITCH(BAUD_RATE_SWITCH),

      // Input and output signals
      .IDB_7_0_IN(s_idb_7_0_in[7:0]),
      .IDB_15_0_OUT(s_idb_15_0_uart_out[15:0]),

      // Output signals
       .DA_n(s_da_n),
      .TBMT_n(s_tbmt_n)
   );




   IO_DCD_38   DCD
   (
      .sysclk(sysclk), // System clock in FPGA
      .sys_rst_n(sys_rst_n), // System reset in FPGA

      .BDRY50_n(s_bdry50_n),
      .BRK_n(s_brk_n),
      .CA10(s_ca10),
      .CCLR_n(s_cclr_n),
      .CEUART_n(s_ceuart_n),
      .CLEAR_n(s_clear_n),
      .CLK(s_clk),
      .CSCOMM_4_0(s_cscomm_4_0[4:0]),
      .CSIDBS_4_0(s_csidbs_4_0[4:0]),
      .CSMIS_1_0(s_csmis_1_0[1:0]),
      .DAP_n(s_dap_n),
      .DT_n(s_dt_n),
      .DVACC_n(s_dvacc_n),
      .ECREQ(s_ecreq),
      .ECSR_n(s_ecsr_n),
      .EDO_n(s_edo_n),
      .EIOR_n(s_eior_n),
      .EMPID_n(s_empid_n),
      .EMP_n(s_emp_n),
      .EORF_n(s_eorf_n),

      /* verilator lint_off PINMISSING */
      //.EPAN_n(s_epan_n),              // <== EPAN NOT CONNECTED (maybe read from PAL?)
      .EPAN_n(), //EPAN is unused
      /* verilator lint_on PINMISSING */

      .EPANS_n(s_epans_n),
      .ESTOF_n(s_estof_n),
      .FETCH(s_fetch),
      .FMISS(s_fmiss),
      .FORM_n(s_form_n),
      .FUL_n(s_ful_n),
      .HIT(s_hit),
      .ICONTIN_n(s_icontin_n),
      .IDB_7_0_IN(s_idb_7_0_in[7:0]),
      .IDB_7_0_OUT(s_idb_7_0_dcd_out[7:0]),
      .ILOAD_n(s_iload_n),
      .IORQ_n(s_iorq_n),
      .ISTOP_n(s_istop_n),
      .LCS_n(s_lcs_n),
      .LHIT(s_lhit),
      .LSHADOW(s_lshadow),
      .MCL(s_mcl),
      .MREQ_n(s_mreq_n),
      .OC_1_0(s_oc_1_0[1:0]),
      .OPCLCS(s_opclcs),
      .OSC(s_osc),
      .OSCCL_n(s_osccl_n),
      .PANOSC(s_panosc),
      .PAN_n(s_pan_n),
      .PA_7_0(s_pa_7_0[7:0]),
      .PA_n(s_pa_n),
      .PONI(s_poni),
      .POWFAIL_n(s_powfail_n),
      .POWSENSE_n(s_powsense_n),
      .PPOSC(s_pposc),
      .PS_n(s_ps_n),
      .REFRQ_n(s_refrq_n),
      .REF_n(s_ref_n),
      .RINR_n(s_rinr_n),
      .RMM_n(s_rmm_n),
      .RT_n(s_rt_n),
      .RUART_n(s_ruart_n),
      .RWCS_n(s_rwcs_n),
      .SEL5MS_n(s_sel5ms_n),
      .SHORT_n(s_short_n),
      .SIOC_n(s_sioc_n),
      .SLOW_n(s_slow_n),
      .SSEMA_n(s_ssema_n),
      .STAT_4_3(s_stat_4_3[1:0]),
      .STOC_n(s_stoc_n),
      .STP(s_stp),
      .SWMCL_n(s_swmcl_n),
      .TOUT(s_tout),
      .TRAALD_n(s_traald_n),
      .UCLK(s_uclk),
      .VAL(s_val),
      .WCHIM_n(s_wchim_n),
      .WRITE(s_write),
      .XTAL1(s_xtal1),
      .XTAL2(s_xtal2)
   );

endmodule
