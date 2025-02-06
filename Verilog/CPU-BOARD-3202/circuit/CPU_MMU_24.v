/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CPU/MMU                                                               **
** MMU TOP LEVEL                                                         **
** SHEET 24 of 50                                                        **
**                                                                       **
** Last reviewed: 2-FEB-2025                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module CPU_MMU_24 (
    input sysclk,    // System clock in FPGA
    input sys_rst_n, // System reset in FPGA

    input        BRK_n,          //! CPU Break signal
    input [10:0] CA_10_0,        //! Cache address, 11 bits
    input        CC2_n,          //! Cycle clock 2
    input        CCLR_n,         //! Cache clear
    input        CUP,            //! Cache updated
    input        CWR,            //! Cache write
    input        CYD,            //! Cycle done
    input        DOUBLE,         //! Extended Adressing Mode (SEXI)
    input        DT_n,           //! Data transfer
    input        DVACC_n,        //! Data valid acknowledge
    input        ECSR_n,         //! Enable cache status register
    input        EDO_n,          //! Enable data output
    input        EMCL_n,         //! Enable master clear
    input        EMPID_n,        //! Interrupt disable
    input        EORF_n,         //! End of Read Flag
    input        ESTOF_n,        //! Enable store of Fault
    input        FMISS,          //! Force miss
    input [10:0] LA_20_10,       //! Logical address, 11 bits
    input        LCS_n,          //! Load control store
    input        LSHADOW,        //! Load shadow signal
    input        PD2,            //! Power down 2
    input        RT_n,           //! Return
    input        STP,            //! Stop signal
    input        SW1_CONSOLE,    //! Switch on the console (on/off)
    input        UCLK,           //! User clock
    input        WCHIM_n,        //! Write cache inhibit
    input        WRITE,          //! Write enable

    input  [15:0] IDB_15_0_IN,   //! Internal data bus input, 16 bits
    output [15:0] IDB_15_0_OUT,  //! Internal data bus output, 16 bits

    input  [15:0] CD_15_0_IN,    //! Cache data input, 16 bits
    output [15:0] CD_15_0_OUT,   //! Cache data output, 16 bits

    input  [15:0] PPN_25_10_IN,  //! Physical page number input, 16 bits
    output [15:0] PPN_25_10_OUT, //! Physical page number output, 16 bits

    output BEDO_n,               //! Buffered Enable IDB "data out" from CGA
    output BEMPID_n,             //! Buffered EMPID - Interrupt Disable (EPIC.LDMPIE->set mask reg:inh all ints)
    output BLCS_n,               //! Bus LCS (Load Control Store)
    output BSTP,                 //! Bus Stop
    output HIT,                  //! Cache hit signal, indicates a successful cache lookup
    output LAPA_n,               //! Latch Page Address, controls latching of the page address
    output [6:0] PT_15_9_OUT,    //! Page Table data output, top 7 bits
    output WCA_n,                //! Write Cache Address, controls writing to the cache address register
    output LED1                  //! Cache enabled ?
);


  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [10:0] s_la_20_10;
  wire [15:0] s_idb_15_0_out;

  wire [13:0] s_hit_cpn_23_10_in;
  wire [10:0] s_ca_10_0;

  wire [ 1:0] s_hit_1_0_n;

  wire        s_ecd_n;
  wire        s_bstp;
  wire        s_bedo_n;
  wire        s_con;
  wire        s_ept_n;
  wire        s_empid_n;
  wire        s_lcs_n;
  wire        s_ecsr_n;
  wire        s_lapa_n;
  wire        s_wclim_n;
  wire        s_uclk;
  wire        s_cwr;
  wire        s_wchim_n;
  wire        s_hit;
  wire        s_eipur_n;
  wire        s_eipl_n;
  wire        s_con_n;
  wire        s_cyd;
  wire        s_pd2;
  wire        s_sw1_console;
  wire        s_wcinh_n;
  wire        s_eipu_n;
  wire        s_eorf_n;
  wire        s_epmap_n;
  wire        s_estof_n;
  wire        s_cup;
  wire        s_dvacc_n;
  wire        s_emcl_n;
  wire        s_epti_n;
  wire        s_bempid_n;
  wire        s_blcs_n;
  wire        s_stp;
  wire        s_edo_n;
  wire        s_dt_n;
  wire        s_brk_n;
  wire        s_wmap_n;
  wire        s_rt_n;
  wire        s_cc2_n;
  wire        s_cclr_n;
  wire        s_fmiss;
  wire        s_double;
  wire        s_write;
  wire        s_lshadow;
  wire        s_wca_n;
  wire        s_led1;

  // PPN
  wire [15:0] s_ppn_25_10_in;

  // PT
  // PT PPN
  wire [15:0] s_pt_ppn_25_10_out;
  wire [15:0] s_pt_ppn_25_10_in;

  // PT PT
  wire [15:0] s_pt_pt_15_0_out;
  wire [15:0] s_pt_pt_15_0_in;



  // CPN
  wire [13:0] s_cache_cpn_23_10_out;
  wire [13:0] s_cache_cpn_23_10_in;

  wire [15:0] s_cache_cd_15_0_in;
  wire [15:0] s_cache_cd_15_0_out;

  // PTIDB
  wire [15:0] s_ptidb_pt_15_0_in;
  wire [15:0] s_ptidb_pt_15_0_out;

  wire [15:0] s_ptidb_idb_15_0_in;
  wire [15:0] s_ptidb_idb_15_0_out;

  // PPNX
  wire [15:0] s_ppnx_idb_15_0_in;
  wire [15:0] s_ppnx_idb_15_0_out;

  wire [15:0] s_ppnx_ppn_25_10_in;
  wire [15:0] s_ppnx_ppn_25_10_out;

  // WCA
  wire [13:0] s_wca_ppn_23_10_in;
  wire [13:0] s_wca_cpn_23_10_out;

  // CSR
  wire [ 3:0] s_csr_idb_3_0_out;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/


  assign s_la_20_10[10:0] = LA_20_10;
  assign s_ca_10_0[10:0] = CA_10_0;
  assign s_empid_n = EMPID_n;
  assign s_lcs_n = LCS_n;
  assign s_ecsr_n = ECSR_n;
  assign s_uclk = UCLK;
  assign s_cwr = CWR;
  assign s_wchim_n = WCHIM_n;
  assign s_cyd = CYD;
  assign s_pd2 = PD2;
  assign s_sw1_console = SW1_CONSOLE;
  assign s_eorf_n = EORF_n;
  assign s_estof_n = ESTOF_n;
  assign s_cup = CUP;
  assign s_dvacc_n = DVACC_n;
  assign s_emcl_n = EMCL_n;
  assign s_stp = STP;
  assign s_edo_n = EDO_n;
  assign s_dt_n = DT_n;
  assign s_brk_n = BRK_n;
  assign s_rt_n = RT_n;
  assign s_cc2_n = CC2_n;
  assign s_cclr_n = CCLR_n;
  assign s_fmiss = FMISS;
  assign s_double = DOUBLE;
  assign s_write = WRITE;
  assign s_lshadow = LSHADOW;
  assign s_ppn_25_10_in = PPN_25_10_IN;
  assign s_cache_cd_15_0_in = CD_15_0_IN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign BEDO_n = s_bedo_n;
  assign BEMPID_n = s_bempid_n;
  assign BLCS_n = s_blcs_n;
  assign BSTP = s_bstp;
  assign CD_15_0_OUT = s_cache_cd_15_0_out[15:0];
  assign HIT = s_hit;
  assign IDB_15_0_OUT = s_idb_15_0_out[15:0];
  assign LAPA_n = s_lapa_n;
  assign PPN_25_10_OUT = s_pt_ppn_25_10_out | s_ppnx_ppn_25_10_out;
  assign PT_15_9_OUT = s_pt_pt_15_0_out[15:9] | s_ptidb_pt_15_0_out[15:9];
  assign WCA_n = s_wca_n;
  assign LED1 = s_led1;

  // Connect PT[15:0] between PT and PDIDB components
  assign s_pt_pt_15_0_in = s_ptidb_pt_15_0_out | s_ptidb_idb_15_0_in;
  assign s_ptidb_pt_15_0_in = s_pt_pt_15_0_out;

  // Connect PPN INPUT signals from PPN IN or with (PT or PPNX out)
  assign s_pt_ppn_25_10_in = s_ppn_25_10_in | s_ppnx_ppn_25_10_out;
  assign s_ppnx_ppn_25_10_in = s_ppn_25_10_in | s_pt_ppn_25_10_out;

  // Assign input and output signals for IDB
  assign s_ptidb_idb_15_0_in = IDB_15_0_IN;
  assign s_ppnx_idb_15_0_in = IDB_15_0_IN;

  assign s_idb_15_0_out[15:0] =
        s_ppnx_idb_15_0_out  |
        s_ptidb_idb_15_0_out |
        {12'b0, s_csr_idb_3_0_out[3:0]};


  // BUS SIGNALS
  assign s_wca_ppn_23_10_in =
         s_ppn_25_10_in[13:0]       | // Input to module
         s_ppnx_ppn_25_10_out[13:0] |  // output from PPNX module
         s_pt_ppn_25_10_out[13:0];     // output from PPN module

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  assign s_wclim_n = s_wchim_n | s_eorf_n;
  assign s_wmap_n = ~(s_lshadow & s_write & s_cyd);

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  // HIT DETECTOR MODULE: This module, CPU_MMU_HIT_27, is responsible for determining cache hit status.
  // It compares the provided physical page number (PPN) and cache page number (CPN) inputs to detect
  // if there is a match, indicating a cache hit. The module takes in 14-bit inputs for both PPN and CPN,
  // along with control signals LSHADOW, FMISS, and CON_n. It outputs two signals, HIT0_n and HIT1_n,
  // which represent the negated hit status for different conditions. A low output on these signals
  // indicates a cache hit, while a high output indicates a miss.
  CPU_MMU_HIT_27 MMU_HIT
  (
    // Input signals
    .CPN_23_10_IN(s_hit_cpn_23_10_in[13:0]),
    .PPN_23_10_IN(s_ppn_25_10_in[13:0]),

    .LSHADOW(s_lshadow),
    .FMISS  (s_fmiss),
    .CON_n  (s_con_n),

    // Output signals
    .HIT0_n(s_hit_1_0_n[0]),
    .HIT1_n(s_hit_1_0_n[1])
  );

  // The CPU_MMU_PPNX_28 module is responsible for handling the translation and manipulation
  // of the Physical Page Number (PPN) and the Internal Data Bus (IDB) signals. It takes in
  // control signals such as EIPL_n, EIPUR_n, EIPU_n, and ESTOF_n to determine the direction
  // and conditions under which data is transferred between the PPN and IDB. The module
  // outputs the modified PPN and IDB values, facilitating the interaction between the
  // memory management unit and other components of the CPU.
  CPU_MMU_PPNX_28 PPNX
  (
    // Input signals
    .EIPL_n(s_eipl_n),
    .EIPUR_n(s_eipur_n),
    .EIPU_n(s_eipu_n),
    .ESTOF_n(s_estof_n),

     // Bus signals (in and out)
    .IDB_15_0_IN(s_ppnx_idb_15_0_in[15:0]),
    .IDB_15_0_OUT(s_ppnx_idb_15_0_out[15:0]),

    .PPN_25_10_IN(s_ppnx_ppn_25_10_in[15:0]),
    .PPN_25_10_OUT(s_ppnx_ppn_25_10_out[15:0])
  );

  // The CPU_MMU_PTIDB_30 module is responsible for interfacing between the Page Table (PT) and the Internal Data Bus (IDB).
  // It manages the data flow between these components, allowing for the reading and writing of page table entries.
  // The module takes in control signals such as EPTI_n and WRITE to determine the operation mode, and it handles
  // 16-bit data inputs and outputs for both the IDB and PT. This module is crucial for maintaining the integrity
  // and efficiency of memory management operations within the CPU.
  CPU_MMU_PTIDB_30 PTIDB
  (
    .WRITE(s_write), // Direction
    .EPTI_n(s_epti_n), // Output enable

    // Bus signals (in and out)
    .IDB_15_0_IN(s_ptidb_idb_15_0_in[15:0]),
    .IDB_15_0_OUT(s_ptidb_idb_15_0_out[15:0]),

    .PT_15_0_IN(s_ptidb_pt_15_0_in),
    .PT_15_0_OUT(s_ptidb_pt_15_0_out)
  );



  // CPU_MMU_WCA_31.v is replaced by this line
  // if s_lapa_n is high, output is high-impedance
  assign s_wca_cpn_23_10_out[13:0] = s_wca_n ? 14'b0 : s_wca_ppn_23_10_in[13:0];

  // Combine the CPN output from WCA and CACHE
  assign s_hit_cpn_23_10_in = s_wca_cpn_23_10_out | s_cache_cpn_23_10_out;

  // Assign the correct bits to the CACHE cpn in bits
  assign s_cache_cpn_23_10_in = s_wca_cpn_23_10_out;

  // Cache Status Register (CSR)
  //
  // The CPU_MMU_CSR_26 module serves as the Cache Status Register (CSR) within the Memory Management Unit (MMU).
  // It is responsible for managing and outputting various status signals related to cache operations.
  // The module takes several input signals, including STP, EMPID_n, EDO_n, LCS_n, PD2, CUP, CON, and ECSR_n,
  // which represent different control and status conditions of the CPU and cache system.
  // Based on these inputs, the CSR module generates output signals such as BSTP, BEMPID_n, BEDO_n, BLCS_n,
  // and a 4-bit IDB output (IDB_3_0), which are used to control and monitor the cache's behavior and status.
  CPU_MMU_CSR_26 CSR
  (
    // Input signals
    .STP(s_stp),
    .EMPID_n(s_empid_n),
    .EDO_n(s_edo_n),
    .LCS_n(s_lcs_n),
    .PD2(s_pd2),

    .CUP(s_cup),
    .CON(s_con),
    .ECSR_n(s_ecsr_n),

    // Output signals
    .BSTP(s_bstp),
    .BEMPID_n(s_bempid_n),
    .BEDO_n(s_bedo_n),
    .BLCS_n(s_blcs_n),
    .IDB_3_0(s_csr_idb_3_0_out[3:0])
  );

  // Cache
  //
  // The CPU_MMU_CACHE_25 module is responsible for managing the cache operations within the Memory Management Unit (MMU).
  // It interfaces with various input signals such as system clock, reset, and control signals like BRK_n, CWR, and FMISS,
  // which are crucial for cache control and data flow. The module handles both input and output bus signals, including
  // CD_15_0 and CPN_23_10, to facilitate data transfer between the cache and other components. Additionally, it generates
  // output signals like CON, HIT, and LED1, which indicate the cache's operational status and hit/miss results. This module
  // plays a vital role in optimizing memory access times by storing frequently accessed data, thereby improving overall
  // system performance.
  CPU_MMU_CACHE_25 CACHE
  (
    .sysclk   (sysclk),    // System clock in FPGA
    .sys_rst_n(sys_rst_n), // System reset in FPGA

    // Input signals
    .BRK_n(s_brk_n),
    .CA_10_0(s_ca_10_0[10:0]),
    .CCLR_n(s_cclr_n),
    .CWR(s_cwr),
    .CYD(s_cyd),
    .DT_n(s_dt_n),
    .ECD_n(s_ecd_n),
    .FMISS(s_fmiss),
    .HIT_1_0_n(s_hit_1_0_n[1:0]),
    .LSHADOW(s_lshadow),
    .PD2(s_pd2),
    .RT_n(s_rt_n),
    .SW1_CONSOLE(s_sw1_console),
    .UCLK(s_uclk),
    .WCINH_n(s_wcinh_n),

    // Bus signals (in and out)
    .CD_15_0_IN(s_cache_cd_15_0_in),
    .CD_15_0_OUT(s_cache_cd_15_0_out),

    .CPN_23_10_IN(s_cache_cpn_23_10_in[13:0]),
    .CPN_23_10_OUT(s_cache_cpn_23_10_out[13:0]),

    // Output signals
    .CON(s_con),
    .CON_n(s_con_n),
    .HIT(s_hit),
    .WCA_n(s_wca_n),
    .LED1(s_led1)
  );

  // The PAL_44306A module, labeled as PAL_44306_UNOCTL, is a programmable array logic component
  // that manages various control signals within the Memory Management Unit (MMU). It takes multiple
  // input signals, such as cache address, write enable, and data valid acknowledge, to generate
  // specific output control signals. These outputs, like ECD_n and LAPA_n, are crucial for coordinating
  // the operations of the MMU, including enabling or disabling certain functions and managing data flow.
  // The module plays a key role in ensuring the correct sequencing and control of memory operations.
  PAL_44306A PAL_44306_UNOCTL (
      .EIPUR_n(s_eipur_n),     //B0
      .EIPU_n (s_eipu_n),      //B1
      .EIPL_n (s_eipl_n),      //B2
      .EPTI_n (s_epti_n),      //B3
      .EPMAP_n(s_epmap_n),     //B4
      .EPT_n  (s_ept_n),       //B5
      .CA0    (s_ca_10_0[0]),  //I0
      .WRITE  (s_write),       //I1
      .DVACC_n(s_dvacc_n),     //I2
      .RT_n   (s_rt_n),        //I3
      .WCHIM_n(s_wchim_n),     //I4
      .DOUBLE (s_double),      //I5
      .EMCL_n (s_emcl_n),      //I6
      .CC2_n  (s_cc2_n),       //I7
      .WCA_n  (s_wca_n),       //I8
      .LSHADOW(s_lshadow),     //I9
      .ECD_n  (s_ecd_n),       //Y0
      .LAPA_n (s_lapa_n)       //Y1
  );

  // Page Table (PT)
  //
  // This module, CPU_MMU_PT_29, is responsible for managing the Page Table (PT) operations within the Memory Management Unit (MMU).
  // It interfaces with the system clock and reset signals to ensure synchronized operations.
  // The module handles 11-bit addressing for PT chips, enabling or disabling the EPMAP and PT chips based on control signals.
  // It manages write operations to RAM chips, specifically targeting the high bit of the Page Physical Number (PPN).
  // The module also processes bidirectional signals for both PPN and PT data buses, facilitating data flow in and out.
  // Additionally, it outputs a write control inhibit signal, which is active low, to regulate write operations.
  CPU_MMU_PT_29 PT
  (
    // Inputs
    .sysclk(sysclk),             // System clock in FPGA
    .sys_rst_n(sys_rst_n),       // System reset in FPGA
    .LA_20_10(s_la_20_10[10:0]), // 11 bit addressing into PT chips
    .EPMAP_n(s_epmap_n),         // Enable EPMAP chips (Extended map?)
    .EPT_n(s_ept_n),             // Enable PT chips (Chip select for PT chips)
    .WCLIM_n(s_wclim_n),         // Write to RAM chip with 1 bit Data being PPN hi bit (bit ppn 25)
    .WMAP_n(s_wmap_n),           // Write MAPPING signal

    // Bus signals (in and out)
    .PPN_25_10_IN(s_pt_ppn_25_10_in[15:0]), // Bidirectional PPN (in)
    .PPN_25_10_OUT(s_pt_ppn_25_10_out[15:0]), // Bidirectional PPN (out)

    .PT_15_0_IN(s_pt_pt_15_0_in), // Bidirectional PT (in)
    .PT_15_0_OUT(s_pt_pt_15_0_out), // Bidirectional PT (out)

    // Outputs
    .WCINH_n(s_wcinh_n)         // Write control inhibit (active low)
  );

endmodule
