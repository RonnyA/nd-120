/**************************************************************************
** ND120 CPU, MM&M                                                       **
** MEM                                                                   **
** MEMORY TOP LEVEL                                                      **
** SHEET 43 of 50                                                        **
**                                                                       **
** Last reviewed: 11-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module MEM_43 (

    // Input signals

    input sysclk,    // System clock in FPGA
    input sys_rst_n, // System reset in FPGA

    input       BDAP50_n,    //! BUS DAta Present (Delayed 50ns)
    input       BDRY50_n,    //! BUS Data ReadY (Delayed 50ns)
    input [4:0] BD_23_19_n,  //! Bus Data and Address (bits 23:19 negated)
    input       BIOXE_n,     //! BUS IOX Enable
    input       BMEM_n,      //! BUS MEMORY Enable
    input       DBAPR,       //! BUS Address Present
    input       ECCR,        //! BUS ECC Request
    input       ECREQ,       //! BUS ECC Request
    input       FETCH,       //! Bus Fetch
    input       GNT_n,       //! Bus Grant
    input       IBINPUT_n,   //! Bus Input Enable
    input       IORQ_n,      //! Bus Input/Output Request
    input       MOR_n,       //! Memory Error
    input       MR_n,        //! Master Reset
    input       OSC,         //! Oscillator
    input       PA_n,        //! Parity Error Address (PEA)
    input       PD1,         //! Power Down 1
    input       PD3,         //! Power Down 3
    input       PD4,         //! Power Down 4
    input [4:0] PPN_23_19,   //! Physical Page Number Bits 23:19
    input       PS_n,        //! Parity Error Signal (PES)
    input       REFRQ_n,     //! Refresh Request
    input       REF_n,       //! Refresh
    input       RERR_n,      //! Refresh Error
    input       SEMRQ50_n,   //! Semaphore Request
    input       SSEMA_n,     //! Semaphore
    input       WRITE,       //! Write

    input [23:0] LBD_23_0_IN,  //! Local Bus Address and Data 23:0 (IN) -  Address and Data for RAM
    output [23:0] LBD_23_0_OUT,  //! Local Bus Address and Data 23:0 (OUT) - Data from from RAM (15:0)

    // Output signals

    output        BDRY_n,        //! Bus Data Ready
    output        BGNT50_n,      //! Bus Grant (Delayed 50ns)
    output        BGNT_n,        //! Bus Grant
    output        CGNT50_n,      //! CPU Grant (Delayed 50ns)
    output        CGNT_n,        //! CPU Grant
    output        CRQ_n,         //! CPU Request
    output        GNT50_n,       //! CPU Grant (Delayed 50ns)
    output [15:0] IDB_15_0_OUT,  //! Bus Data 15:0
    output        LERR_n,        //! Local Error
    output        LPERR_n,       //! Local Parity Error
    output        MOFF_n,        //! Memory Off
    output        MOR25_n,       //! Memory Request (Delayed 25ns)
    output        MWRITE_n,      //! Memory Write
    output        LED4,          //! LED4_RED_PARITY_ERROR
    output        LED_CPU_GI,    //! LED_CPU_GRANT_INDICATOR
    output        LED_BUS_GI     // LED_BUS_GRANT_INDICATOR
);


  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [ 2:0] s_bank_2_0;
  wire [ 4:0] s_bus_bd;
  wire [ 4:0] s_bus_ppn;
  wire [ 9:0] s_aa_9_0;
  wire [15:0] s_idb_15_0_out;

  wire [17:0] s_data_dd_in;
  wire [17:0] s_data_dd_out;

  wire [17:0] s_ram_dd_17_0_in;  // INPUT TO MEM_DATA
  wire [17:0] s_ram_dd_17_0_out;  // OUTPUT FROM MEM_DATA

  wire [23:0] s_lbd_23_0_in;  // RAM DATA 16 bits and ADDRESS 24 bits
  wire [15:0] s_lbd_15_0_out;  // RAM DATA 16 bits

  wire        s_bcgnt50;
  wire        s_bcgnt50r_n;
  wire        s_bdap50_n;
  wire        s_bdry;
  wire        s_bdry50_n;
  wire        s_bgnt_n;
  wire        s_bgnt25_n;
  wire        s_bcgnt25;
  wire        s_bgnt50_n;
  wire        s_bioxe_n;
  wire        s_bioxl_n;
  wire        s_blockl_n;
  wire        s_blockl25;
  wire        s_blrq_n;
  wire        s_blrq50_n;
  wire        s_bmem_n;
  wire        s_cas;
  wire        s_cgnt_n;
  wire        s_cgnt25_n;
  wire        s_cgnt50_n;
  wire        s_clrq_n;
  wire        s_corr_n;
  wire        s_crq_n;
  wire        s_dbapr;
  wire        s_eccr;
  wire        s_ecreq;
  wire        s_fetch;
  wire        s_gnt_n;
  wire        s_gnt50_n;
  wire        s_hien_n;
  wire        s_hierr;
  wire        s_ibinput_n;
  wire        s_iorq_n;
  wire        s_lerr_n;
  wire        s_loen_n;
  wire        s_loerr;
  wire        s_lperr_n;
  wire        s_moff_n;
  wire        s_mor_n;
  wire        s_mor25_n;
  wire        s_mr_n;
  wire        s_mwrite_n;
  wire        s_mwrite50_n;
  wire        s_osc;
  wire        s_pa_n;
  wire        s_pd1;
  wire        s_pd3;
  wire        s_pd4;
  wire        s_ps_n;
  wire        s_qd_n;
  wire        s_ras;
  wire        s_rdata;
  wire        s_rdata25;
  wire        s_ref_n;
  wire        s_refrq_n;
  wire        s_rerr_n;
  wire        s_rgnt_n;
  wire        s_rlrq_n;
  wire        s_semreq50_n;
  wire        s_ssema_n;
  wire        s_write;



  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_bus_bd[4:0]       = BD_23_19_n;
  assign s_bus_ppn[4:0]      = PPN_23_19;
  assign s_lbd_23_0_in[23:0] = LBD_23_0_IN[23:0];
  assign s_ibinput_n         = IBINPUT_n;
  assign s_pd3               = PD3;
  assign s_dbapr             = DBAPR;
  assign s_ref_n             = REF_n;
  assign s_pa_n              = PA_n;
  assign s_iorq_n            = IORQ_n;
  assign s_ecreq             = ECREQ;
  assign s_pd1               = PD1;
  assign s_semreq50_n        = SEMRQ50_n;
  assign s_gnt_n             = GNT_n;
  assign s_ssema_n           = SSEMA_n;
  assign s_ps_n              = PS_n;
  assign s_bmem_n            = BMEM_n;
  assign s_bioxe_n           = BIOXE_n;
  assign s_bdry50_n          = BDRY50_n;
  assign s_bdap50_n          = BDAP50_n;
  assign s_eccr              = ECCR;
  assign s_mor_n             = MOR_n;
  assign s_mr_n              = MR_n;
  assign s_refrq_n           = REFRQ_n;
  assign s_rerr_n            = RERR_n;
  assign s_osc               = OSC;
  assign s_fetch             = FETCH;
  assign s_pd4               = PD4;
  assign s_write             = WRITE;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign BDRY_n              = s_bdry;
  assign BGNT50_n            = s_bgnt50_n;
  assign BGNT_n              = s_bgnt_n;
  assign CGNT50_n            = s_cgnt50_n;
  assign CGNT_n              = s_cgnt_n;
  assign CRQ_n               = s_crq_n;
  assign GNT50_n             = s_gnt50_n;
  assign IDB_15_0_OUT        = s_idb_15_0_out[15:0];
  assign LERR_n              = s_lerr_n;
  assign LPERR_n             = s_lperr_n;
  assign MOFF_n              = s_moff_n;
  assign MOR25_n             = s_mor25_n;
  assign MWRITE_n            = s_mwrite_n;
  assign LBD_23_0_OUT        = {8'b00000000, s_lbd_15_0_out};


  /*******************************************************************************
   ** Here all internal busses are connected                                     **
   *******************************************************************************/
  assign s_data_dd_in        = s_ram_dd_17_0_out;
  assign s_ram_dd_17_0_in    = s_data_dd_out;

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  /*
   * Memory address decoder for the ND120 CPU system.
   * Decodes the address bus and generates the address for the memory module.
   * Also handles the memory control signals and error handling.
   */
  MEM_ADEC_45 ADEC (
      // Inputs
      .BMEM_n(s_bmem_n),
      .DBAPR(s_dbapr),
      .ECREQ(s_ecreq),
      .IBINPUT_n(s_ibinput_n),
      .IORQ_n(s_iorq_n),
      .PD4(s_pd4),
      .PPN19(s_bus_ppn[0]),
      .PPN20(s_bus_ppn[1]),
      .PPN21(s_bus_ppn[2]),
      .PPN22(s_bus_ppn[3]),
      .PPN23(s_bus_ppn[4]),
      .REFRQ_n(s_refrq_n),
      .RGNT_n(s_rgnt_n),
      .WRITE(s_write),

      // Outputs
      .BANK_2_0(s_bank_2_0[2:0]),
      .BD19_n(s_bus_bd[0]),
      .BD20_n(s_bus_bd[1]),
      .BD21_n(s_bus_bd[2]),
      .BD22_n(s_bus_bd[3]),
      .BD23_n(s_bus_bd[4]),
      .BGNT_n(s_bgnt_n),
      .BLRQ_n(s_blrq_n),
      .CGNT_n(s_cgnt_n),
      .CLRQ_n(s_clrq_n),
      .CRQ_n(s_crq_n),
      .MOFF_n(s_moff_n),
      .MWRITE_n(s_mwrite_n),
      .RLRQ_n(s_rlrq_n)
  );

  /*
   * Memory local bus interface for the ND120 CPU system.
   * Handles the local bus interface and memory control signals.
   */
  MEM_LBDIF_48 LBDIF (
      // Input signals
      .BDAP50_n(s_bdap50_n),
      .BGNT25_n(s_bgnt25_n),
      .BGNT50_n(s_bgnt50_n),
      .BGNT_n(s_bgnt_n),
      .BIOXE_n(s_bioxe_n),
      .BLRQ50_n(s_blrq50_n),
      .BLRQ_n(s_blrq_n),
      .CGNT25_n(s_cgnt25_n),
      .CGNT50_n(s_cgnt50_n),
      .CGNT_n(s_cgnt_n),
      .ECCR(s_eccr),
      .GNT50_n(s_gnt50_n),
      .GNT_n(s_gnt_n),
      .MOR_n(s_mor_n),
      .MR_n(s_mr_n),
      .MWRITE_n(s_mwrite_n),
      .OSC(s_osc),
      .PD4(s_pd4),
      .REF_n(s_ref_n),

      // Output signals
      .BCGNT25(s_bcgnt25),
      .BCGNT50(s_bcgnt50),
      .BCGNT50R_n(s_bcgnt50r_n),
      .BDRY_n(s_bdry),
      .BIOXL_n(s_bioxl_n),
      .BLOCKL25_n(s_blockl25),
      .BLOCKL_n(s_blockl_n),
      .HIEN_n(s_hien_n),
      .LOEN_n(s_loen_n),
      .MOR25_n(s_mor25_n),
      .MWRITE50_n(s_mwrite50_n),
      .RAS(s_ras),
      .RDATA(s_rdata),
      .RDATA25(s_rdata25)
  );

  /*
   * Memory data handling module for the ND120 CPU system.
   * Handles data transfer between the memory and the CPU.
   */
  MEM_DATA_46 DATA (
      // Input signals
      .BCGNT50R_n(s_bcgnt50r_n),
      .BIOXL_n(s_bioxl_n),
      .DD_17_0_IN(s_data_dd_in[17:0]),
      .ECCR(s_eccr),
      .HIEN_n(s_hien_n),
      .LBD_15_0_IN(s_lbd_23_0_in[15:0]),
      .MR_n(s_mr_n),
      .MWRITE_n(s_mwrite_n),
      .PA_n(s_pa_n),
      .QD_n(s_qd_n),
      .RDATA(s_rdata),

      // Output signals
      .DD_17_0_OUT(s_data_dd_out[17:0]),
      .HIERR(s_hierr),
      .LBD_15_0_OUT(s_lbd_15_0_out[15:0]),
      .LED4(LED4),
      .LERR_n(s_lerr_n),
      .LOERR(s_loerr),
      .LPERR_n(s_lperr_n)
  );

  /*
   * Memory error handling module for the ND120 CPU system.
   * Handles memory error detection and reporting.
   */
  MEM_ERROR_47 ERROR (
      // Input signals
      .BCGNT50(s_bcgnt50),
      .BLOCKL25(s_blockl25),
      .BLOCKL_n(s_blockl_n),
      .CGNT50_n(s_cgnt50_n),
      .CORR_n(s_corr_n),
      .FETCH(s_fetch),
      .LBD_23_0_IN(s_lbd_23_0_in[23:0]),
      .MR_n(s_mr_n),
      .PA_n(s_pa_n),
      .PD4(s_pd4),
      .PS_n(s_ps_n),
      .RDATA25(s_rdata25),
      .RERR_n(s_rerr_n),

      // Output signals
      .HIERR(s_hierr),
      .IDB_15_0_OUT(s_idb_15_0_out[15:0]),
      .LERR_n(s_lerr_n),
      .LOERR(s_loerr)
  );

  /*
   * Memory RAM control module for the ND120 CPU system.
   * Handles memory control signals and error handling.
   */
  MEM_RAMC_50 RAMC (
      // Input signals
      .BDAP50_n(s_bdap50_n),
      .BDRY50_n(s_bdry50_n),
      .BCGNT25(s_bcgnt25),
      .BGNT25_n(s_bgnt25_n),
      .BGNT_n(s_bgnt_n),
      .BLRQ50_n(s_blrq50_n),
      .CAS(s_cas),
      .CGNT25_n(s_cgnt25_n),
      .CGNT_n(s_cgnt_n),
      .CLRQ_n(s_clrq_n),
      .HIEN_n(s_hien_n),
      .LOEN_n(s_loen_n),
      .MR_n(s_mr_n),
      .OSC(s_osc),
      .PD1(s_pd1),
      .PD3(s_pd3),
      .QD_n(s_qd_n),
      .RAS(s_ras),
      .RGNT_n(s_rgnt_n),
      .RLRQ_n(s_rlrq_n),
      .SEMRQ50_n(s_semreq50_n),
      .SSEMA_n(s_ssema_n),

      // Output signals
      .LED_CPU_GI(LED_CPU_GI),
      .LED_BUS_GI(LED_BUS_GI)
  );

  /*
   * Memory address decoder for the ND120 CPU system.
   * Decodes the address bus and generates the address for the memory module.
   * Also handles the memory control signals and error handling.
   */
  MEM_ADDR_44 ADDR (
      // Input signals
      .BCGNT50(s_bcgnt25), // Need to latch address earlier before it goes away. Thats why this is changed to BCGNT25 (Ronny 7.12.2024)
      .HIEN_n(s_hien_n),
      .LBD_19_0(s_lbd_23_0_in[19:0]),
      .LOEN_n(s_loen_n),
      .PD4(s_pd4),

      // Output signals
      .AA_9_0(s_aa_9_0[9:0])
  );

  /*
   * Top level memory module for the ND120 CPU system.
   * Handles memory operations and interfaces with the system bus.
   * Provides memory access, control and error handling functionality.
   */
  MEM_RAM_49 RAM (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      // Input signals
      .AA_9_0(s_aa_9_0[9:0]),
      .BANK0(s_bank_2_0[0]),
      .BANK1(s_bank_2_0[1]),
      .BANK2(s_bank_2_0[2]),
      .CAS(s_cas),
      .CORR_n(s_corr_n),
      .DD_17_0_IN(s_ram_dd_17_0_in[17:0]),
      .MWRITE50_n(s_mwrite50_n),
      .RAS(s_ras),

      // Output signals
      .DD_17_0_OUT(s_ram_dd_17_0_out[17:0])
  );
endmodule
