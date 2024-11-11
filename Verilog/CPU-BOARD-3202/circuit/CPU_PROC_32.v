// TODO: Validate that the IDB in and out signals are mapped correctly!

/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CPU/PROC                                                              **
** PROCESSOR TOP LEVEL                                                   **
** SHEET 32 of 50                                                        **
**                                                                       **
** Last reviewed: 18-MAY-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CPU_PROC_32 (
    input sysclk,    // System clock in FPGA
    input sys_rst_n, // System reset in FPGA

    input        ALUCLK,
    input        BEDO_n,
    input        BEMPID_n,
    input        BSTP,
    input [15:0] CD_15_0_IN,
    input        CLK,
    input [63:0] CSBITS,
    input        ESTOF_n,
    input        ETRAP_n,
    input        EWCA_n,
    input        IBINT10_n,
    input        IBINT11_n,
    input        IBINT12_n,
    input        IBINT13_n,
    input        IBINT15_n,
    input        IOXERR_n,
    input        LCS_n,
    input        MAP_n,
    input        MCLK,
    input        MOR_n,
    input        MREQ_n,
    input        MR_n,
    input        PAN_n,
    input        PARERR_n,
    input        PD1,
    input        POWFAIL_n,
    input [ 6:0] PT_15_9,
    input        TERM_n,
    input        UCLK,
    input        WCA_n,
    input        WRFSTB,
    input [ 2:0] SEL_TESTMUX, // Selects testmux signals to output on TEST_4_0

    /*******************************************************************************
   ** The IN and OUT are define here                                            **
   *******************************************************************************/


    input  [15:0] IDB_15_0_IN,
    output [15:0] IDB_15_0_OUT,

    /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
    output ACOND_n,
    output BRK_n,
    output [9:0] CA_9_0,
    output [12:0] CSA_12_0,
    output [9:0] CSCA_9_0,
    output CUP,
    output CWR,
    output DOUBLE,
    output ECCR,
    output IONI,
    output [13:0] LA_23_10,
    output [3:0] LBA_3_0,
    output LEV0,
    output LSHADOW,
    output OPCLCS,
    output [1:0] PCR_1_0,
    output [3:0] PIL_3_0,
    output PONI,
    output [1:0] RF_1_0,
    output RRF_n,
    output RT_n,     //! This signal is not in the PAL 44408B, but in the PAL 444608 (VXFIX). Use  RT_n signal from DGA until we find out what the 44608A does with this signal.
    output LDEXM_n,  //! use signal from DGA
    output RWCS_n,
    output [4:0] TEST_4_0,
    output TP1_INTRQ_n,
    output TRAP,
    output VEX,
    output WCS_n
);


  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [63:0] s_csbits;



  wire [15:0] s_fidb_cga_IN;  // Out from B side of CHIP32 and 33, and IN to CGA
  wire [15:0] s_fidb_cga_OUT;  // Input signal to B side of CHIP32 and 33, and OUT from CGA

  wire [15:0] s_fidb_A_IN;  // Input signal to A side of CHIP32 and 33
  wire [15:0] s_fidb_A_OUT;  // Out from A side of CHIP32 and 33
  wire [15:0] s_fidb_B_OUT;  // Out from B side of CHIP32 and 33

  wire [15:0] s_idb_erf_in;  // 16 bit-input signal from RAM Chip34 and 35, controlled by ERF_n
  wire [15:0] s_idb_erf_out;  // 16 bit-output signal from RAM Chip34 and 35, controlled by ERF_n

  wire [15:0] s_IDB_15_0_OUT;


  wire [ 1:0] s_csmis_1_0;
  wire [ 1:0] s_pcr_1_0;
  wire [ 1:0] s_rf_1_0;
  wire [10:0] s_address_10_0;
  wire [12:0] s_csa_12_0;
  wire [13:0] s_la_23_10;
  wire [15:0] s_cd_15_0_in;
  wire [ 3:0] s_laa_3_0;
  wire [ 3:0] s_lba_3_0;
  wire [ 3:0] s_pil_3_0;
  wire [ 4:0] s_cscomm_4_0;
  wire [ 4:0] s_csidbs_4_0;
  wire [ 4:0] s_test_4_0;
  wire [ 6:0] s_pt_15_9;
  wire [ 9:0] s_ca_9_0;
  wire [ 9:0] s_csca_9_0;



  wire        s_idb2;  //IDB2 input signal to CMDDEC
  wire        s_acond_n;
  wire        s_aluclk;
  wire        s_bedo_n;
  wire        s_bempid_n;
  wire        s_brk_n;
  wire        s_bstp;
  wire        s_cgabrk_n;
  wire        s_clk;
  wire        s_cup;
  wire        s_cwr;
  wire        s_double;
  wire        s_eccr;
  wire        s_erf_n_org;  // Original signal from CGA. Not used after fix has been applied
  wire        s_erf_n;
  wire        s_estof_n;
  wire        s_etrap_n;
  wire        s_ewca_n;
  wire        s_ibint10_n;
  wire        s_ibint11_n;
  wire        s_ibint12_n;
  wire        s_ibint13_n;
  wire        s_ibint15_n;
  wire        s_ioni;
  wire        s_ioxerr_n;
  wire        s_lcs_n;
  wire        s_ledexm;
  wire        s_lev0;
  wire        s_lshadow;
  wire        s_map_n;
  wire        s_mclk;
  wire        s_mor_n;
  wire        s_mr_n;
  wire        s_mreq_n;
  wire        s_opclcs;
  wire        s_pan_n;
  wire        s_parerr_n;
  wire        s_pd1;
  wire        s_poni;
  wire        s_powfail_n;
  wire        s_rrf_n;
  wire        s_rt_n;
  wire        s_rwcs_n;
  wire        s_term_n;
  wire        s_tp1_intrq_n;
  wire        s_trap;
  wire        s_twrf_n;
  wire        s_uclk;
  wire        s_vex;
  wire        s_wca_n;
  wire        s_wcs_n;
  wire        s_wrfstb;
  wire        s_wrtrf;




  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/
  assign s_cscomm_4_0[4:0]  = s_csbits[36:32];
  assign s_csidbs_4_0[4:0]  = s_csbits[41:37];
  assign s_csmis_1_0[1:0]   = s_csbits[43:42];

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_csbits[63:0]     = CSBITS;
  assign s_pt_15_9[6:0]     = PT_15_9;
  assign s_cd_15_0_in[15:0] = CD_15_0_IN;
  assign s_ibint11_n        = IBINT11_n;
  assign s_uclk             = UCLK;
  assign s_ioxerr_n         = IOXERR_n;
  assign s_etrap_n          = ETRAP_n;
  assign s_aluclk           = ALUCLK;
  assign s_map_n            = MAP_n;
  assign s_ibint13_n        = IBINT13_n;
  assign s_ibint10_n        = IBINT10_n;
  assign s_bempid_n         = BEMPID_n;
  assign s_bstp             = BSTP;
  assign s_ibint15_n        = IBINT15_n;
  assign s_lcs_n            = LCS_n;
  assign s_mclk             = MCLK;
  assign s_powfail_n        = POWFAIL_n;
  assign s_parerr_n         = PARERR_n;
  assign s_wrfstb           = WRFSTB;
  assign s_pan_n            = PAN_n;
  assign s_bedo_n           = BEDO_n;
  assign s_pd1              = PD1;
  assign s_mreq_n           = MREQ_n;
  assign s_term_n           = TERM_n;
  assign s_clk              = CLK;
  assign s_mr_n             = MR_n;
  assign s_ewca_n           = EWCA_n;
  assign s_ibint12_n        = IBINT12_n;
  assign s_mor_n            = MOR_n;
  assign s_estof_n          = ESTOF_n;
  assign s_wca_n            = WCA_n;



  // s_twrf_n = low, write to memory from IDB
  wire ram_read;  // boolean to know if we are reading from RAM
  assign ram_read = !s_erf_n & s_wrtrf & s_twrf_n;  // Read from RAM


  assign s_fidb_A_IN = IDB_15_0_IN | (ram_read) ? s_idb_erf_out : 0;


  assign s_fidb_cga_IN = s_fidb_B_OUT;

  assign s_idb2 = s_fidb_A_IN[2];

  // Not 100% sure where data to the RAM may come from, so expect it to com from IDB and via Chip32F/33F
  assign s_idb_erf_in = IDB_15_0_IN | ((!ESTOF_n & !BEDO_n) ? s_fidb_A_OUT : 0);

  // use LOGIC to select
  assign IDB_15_0_OUT = ram_read ? s_idb_erf_out[15:0] : ( (!ESTOF_n & !BEDO_n) ? s_fidb_A_OUT[15:0] : 16'b0);
  // use OR to combine singals
  //assign IDB_15_0_OUT =  s_idb_erf_inout[15:0] |  s_fidb_A_OUT[15:0];

  assign s_address_10_0[10] = 1'b0;  // Ground
  assign s_address_10_0[9:8] = s_rf_1_0[1:0];
  assign s_address_10_0[7:4] = s_lba_3_0[3:0];
  assign s_address_10_0[3:0] = s_laa_3_0[3:0];

  assign s_twrf_n = ~(s_wrtrf & s_wrfstb & s_term_n);

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign ACOND_n = s_acond_n;
  assign BRK_n = s_brk_n;
  assign CA_9_0 = s_ca_9_0[9:0];
  assign CSA_12_0 = s_csa_12_0[12:0];
  assign CSCA_9_0 = s_csca_9_0[9:0];
  assign CUP = s_cup;
  assign CWR = s_cwr;
  assign DOUBLE = s_double;
  assign ECCR = s_eccr;
  assign IONI = s_ioni;
  assign LA_23_10 = s_la_23_10[13:0];
  assign LBA_3_0 = s_lba_3_0;
  assign LEV0 = s_lev0;
  assign LSHADOW = s_lshadow;
  assign OPCLCS = s_opclcs;
  assign PCR_1_0 = s_pcr_1_0[1:0];
  assign PIL_3_0 = s_pil_3_0[3:0];
  assign PONI = s_poni;
  assign RF_1_0 = s_rf_1_0[1:0];
  assign RRF_n = s_rrf_n;
  assign RT_n = s_rt_n;
  assign LDEXM_n = s_ledexm;
  assign RWCS_n = s_rwcs_n;
  assign TEST_4_0 = s_test_4_0[4:0];
  assign TP1_INTRQ_n = s_tp1_intrq_n;
  assign TRAP = s_trap;
  assign VEX = s_vex;
  assign WCS_n = s_wcs_n;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/




  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  AM29841 CHIP_25F (
      .D(s_csca_9_0),
      .LE(s_mclk),
      .OE_n(s_pd1),
      .Y(s_ca_9_0)
  );

  CPU_PROC_CMDDEC_34 CMDDEC (
      .BRK_n(s_brk_n),
      .CGABRK_n(s_cgabrk_n),
      .CLK(s_clk),
      .CSCOMM_4_0(s_cscomm_4_0[4:0]),
      .CSIDBS_4_0(s_csidbs_4_0[4:0]),
      .CSMIS_1_0(s_csmis_1_0[1:0]),
      .CUP(s_cup),
      .CWR(s_cwr),
      .ERF_n(s_erf_n),  // output from PAL_44407_UERFIX
      .IDB2(s_idb2),
      .LCS_n(s_lcs_n),
      .LEV0(s_lev0),
      .MREQ_n(s_mreq_n),
      .OPCLCS(s_opclcs),
      .PD1(s_pd1),
      .PIL_3_0(s_pil_3_0[3:0]),
      .RRF_n(s_rrf_n),
      .RT_n(s_rt_n),
      .RWCS_n(s_rwcs_n),
      .LDEXM_n(s_ledexm),
      .VEX(s_vex),
      .WCA_n(s_wca_n),
      .WRTRF(s_wrtrf)
  );

  TTL_74245 CHIP_32F (
      .A(s_fidb_A_IN[7:0]),  //
      .A_OUT(s_fidb_A_OUT[7:0]),
      .B(s_fidb_cga_OUT[7:0]),
      .B_OUT(s_fidb_B_OUT[7:0]),
      .DIR(s_bedo_n),
      .OE_n(s_estof_n)
  );


  TTL_74245 CHIP_33F (
      .A(s_fidb_A_IN[15:8]),
      .A_OUT(s_fidb_A_OUT[15:8]),
      .B(s_fidb_cga_OUT[15:8]),
      .B_OUT(s_fidb_B_OUT[15:8]),
      .DIR(s_bedo_n),
      .OE_n(s_estof_n)
  );


  TMM2018D_25 CHIP_34F (
      .clk(sysclk),  // System clock in FPGA
      .reset_n(sys_rst_n),  // System reset in FPGA

      .ADDRESS(s_address_10_0[10:0]),
      .CS_n   (s_erf_n),
      .D      (s_idb_erf_in[7:0]),     // IN
      .D_OUT  (s_idb_erf_out[7:0]),    // OUT
      .OE_n   (s_wrtrf),
      .W_n    (s_twrf_n)
  );


  TMM2018D_25 CHIP_35F (
      .clk(sysclk),  // System clock in FPGA
      .reset_n(sys_rst_n),  // System reset in FPGA

      .ADDRESS(s_address_10_0[10:0]),
      .CS_n   (s_erf_n),
      .D      (s_idb_erf_in[15:8]),    // IN
      .D_OUT  (s_idb_erf_out[15:8]),   // OUT
      .OE_n   (s_wrtrf),
      .W_n    (s_twrf_n)
  );




  CPU_PROC_CGA_33 CGA (
      .ACOND_n(s_acond_n),
      .ALUCLK(s_aluclk),
      .BEDO_n(s_bedo_n),
      .BEMPID_n(s_bempid_n),
      .BSTP(s_bstp),
      .CD_15_0(s_cd_15_0_in[15:0]),
      .CGABRK_n(s_cgabrk_n),
      .CSA_12_0(s_csa_12_0[12:0]),
      .CSBITS(s_csbits[63:0]),
      .CSCA_9_0(s_csca_9_0[9:0]),
      .DOUBLE(s_double),
      .ECCR(s_eccr),
      .ETRAP_n(s_etrap_n),
      .EWCA_n(s_ewca_n),
      .FIDB_15_0_IN(s_fidb_cga_IN[15:0]),
      .FIDB_15_0_OUT(s_fidb_cga_OUT[15:0]),
      .IBINT10_n(s_ibint10_n),
      .IBINT11_n(s_ibint11_n),
      .IBINT12_n(s_ibint12_n),
      .IBINT13_n(s_ibint13_n),
      .IBINT15_n(s_ibint15_n),
      .INTRQ_n_tp1(s_tp1_intrq_n),
      .ERF_n(s_erf_n_org),  // original ERF_N from CGA (submodule DCD), fixed with PAL_44407_UERFIX (signal replaced, so wire is not used)
      .IONI(s_ioni),
      .IOXERR_n(s_ioxerr_n),
      .LAA_3_0(s_laa_3_0[3:0]),
      .LA_23_10(s_la_23_10[13:0]),
      .LBA_3_0(s_lba_3_0[3:0]),
      .LCS_n(s_lcs_n),
      .LSHADOW(s_lshadow),
      .MAP_n(s_map_n),
      .MCLK(s_mclk),
      .MOR_n(s_mor_n),
      .MR_n(s_mr_n),
      .PAN_n(s_pan_n),
      .PARERR_n(s_parerr_n),
      .PCR_1_0(s_pcr_1_0[1:0]),
      .PIL_3_0(s_pil_3_0[3:0]),
      .PONI(s_poni),
      .POWFAIL_n(s_powfail_n),
      .PT_15_9(s_pt_15_9[6:0]),
      .RF_1_0(s_rf_1_0),
      .SEL_TESTMUX(SEL_TESTMUX),
      .TEST_4_0(s_test_4_0[4:0]),
      .TRAP_n(s_trap),
      .UCLK(s_uclk),
      .WCS_n(s_wcs_n),
      .WRTRF(s_wrtrf)
  );

endmodule
