/**************************************************************************
** ND120 CPU, MM&M                                                       **
** IO/PANCAL                                                             **
** PANEL PROC & CALENDAR                                                 **
** SHEET 40 of 50                                                        **
**                                                                       **
** Last reviewed: 21-APRIL-2024                                          **
** Ronny Hansen                                                          **
***************************************************************************/

// Statis: Module not working.
// TODO: Implement logic for the MC68705 - 6805 Embedded CPU and the MM58274  - Real Time Clock

module IO_PANCAL_40 (
    // Input signals
    input       CLEAR_n,
    input       EMP_n,
    input       EPANS,
    input       FUL_n,
    input       IONI,
    input       LEV0,
    input       LHIT,
    input       PANOSC,
    input [7:0] PA_7_0,   //! Data from FIFO in DGA
    input [1:0] PCR_1_0,
    input       PONI,     //! Memory Protection ON, PONI=1
    input       VAL,

    // Output and Input signals
    output [15:0] IDB_15_0_OUT,

    // Output signals
    output [4:0] DP_5_1_n,
    output       RMM_n,
    output [1:0] STAT_4_3
);

  // There are some unused signals in this module until we have implemented the missing parts..
  /* verilator lint_off UNUSEDSIGNAL */



  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [ 4:0] s_dp_5_1_n;
  wire [ 4:0] s_ground_bus;
  wire [ 4:0] s_stat_4_0;
  wire [ 1:0] s_pcr_1_0;
  wire [15:0] s_idb_15_0_out;
  wire [ 7:0] s_pa_7_0;
  wire        s_ful_n;
  wire        s_clear_n;
  wire        s_poni;
  wire        s_val;
  wire        s_epans;
  wire        s_ioni;
  wire        s_lhit;
  wire        s_lev0;
  wire        s_emp_n;
  wire        s_panos;
  wire        s_rmm_n;
  wire [15:0] s_idb_15_0_chip_out;

  wire        s_pres;
  wire        s_read;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_pcr_1_0     = PCR_1_0;
  assign s_pa_7_0      = PA_7_0;
  assign s_ful_n       = FUL_n;
  assign s_clear_n     = CLEAR_n;
  assign s_poni        = PONI;
  assign s_val         = VAL;
  assign s_epans       = EPANS;
  assign s_ioni        = IONI;
  assign s_lhit        = LHIT;
  assign s_lev0        = LEV0;
  assign s_emp_n       = EMP_n;
  assign s_panos       = PANOSC;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign DP_5_1_n      = s_dp_5_1_n;
  assign IDB_15_0_OUT  = s_idb_15_0_out;
  assign RMM_n         = s_rmm_n;
  assign STAT_4_3[1:0] = s_stat_4_0[4:3];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Ground
  assign s_ground_bus  = 5'b00000;

  // NOT Gate
  assign s_dp_5_1_n    = ~s_ground_bus;  // Signals coming from 68705 - add in logic later

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  wire s_wmm_n;


  // TTL_74374 CHIP_32B
  TTL_74374 CHIP_32B (
      .CK(s_wmm_n),  // from 68705
      .OE_n(s_epans),
      .D(s_pa_7_0),
      .Q(s_idb_15_0_chip_out[7:0])
  );


  // TTL_74244 CHIP_33B
  TTL_74244 CHIP_33B (
      // Input
      //        1A4                1A3                  1A2                  1A1
      .A1  ({s_stat_4_0[3], s_stat_4_0[2], s_stat_4_0[1], s_stat_4_0[0]}),
      .G1_n(s_epans),

      //        2A4                2A3                  2A2                  2A1
      .A2  ({s_pres, s_ful_n, s_read, s_val}),
      .G2_n(s_epans),


      // Output
      .Y1({
        s_idb_15_0_chip_out[11],
        s_idb_15_0_chip_out[10],
        s_idb_15_0_chip_out[9],
        s_idb_15_0_chip_out[8]
      }),
      .Y2({
        s_idb_15_0_chip_out[15],
        s_idb_15_0_chip_out[14],
        s_idb_15_0_chip_out[13],
        s_idb_15_0_chip_out[12]
      })
  );

  // Output from chip 32B (IDB 7:0) and cip 33B (IDB 15:8)
  assign s_idb_15_0_out[15:0] = s_idb_15_0_chip_out[15:0];




  // TODO:
  // ADD - MM58274  - Real Time Clock
  // ADD - MC68705 - 6805 Embedded CPU

  // Add in logic later
  // Output signals from the MC68705 - 6805 Embedded CPU

  // *** PORT A ***
  // PA0-PA7 connects to bus signal - s_pa_7_0. Unclear if the CPU only reads or writes to this bus..
  // PA[7:0] is data coming from the FIFO in the DGA

  // *** PORT B *** (output)
  assign s_stat_4_0 = 5'b00000;

  assign s_pres = 0;  // STAT7 signal pb7 - negated
  assign s_read = 0;  // READ signal pb6
  // pb5 =stat4
  // pb4 =stat3
  assign s_rmm_n = 1;  // RMM signal pb3
  // pb2 = roclk_n (not connected to anything/not used)
  // pb1 = wrclk_n (not connected to anything/not used)
  assign s_wmm_n = 1;  // WMM signal pb0

  // *** PORT C *** (output)

  // PC0 = STAT0
  // PC1 = STAT1
  // PC2 = STAT2
  // PC3 = DISP1 (to DISPLAY?) goes negated to bus DP_5_1_n)
  // PC4 = DISP2 (to DISPLAY?) goes negated to bus DP_5_1_n)
  // PC5 = DISP3 (to DISPLAY?) goes negated to bus DP_5_1_n)
  // PC6 = DISP4 (to DISPLAY?) goes negated to bus DP_5_1_n)
  // PC7 = DISP5 (to DISPLAY?) goes negated to bus DP_5_1_n)

  // *** PORT D *** (input)
  // PD0 = PCR0
  // PD1 = PCR1
  // PD2 = PONI
  // PD3 = IONI
  // PD4 = LHIT
  // PD5 = LEV0
  // PD6 = gnd
  // PD7 = EMP_n


  // *** OTHER SIGNALS ***
  // TIMER = PANOSC
  // /RESET = CLEAR_n
  // XTAL/EXTAL = connected to 4MHz xtal
  // /INT = VCC (so external interrupt is not used in this design)

endmodule
