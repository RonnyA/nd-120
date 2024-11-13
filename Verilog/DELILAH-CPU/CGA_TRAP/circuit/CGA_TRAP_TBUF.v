/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/TRAP/TBUF                                                        **
** TRAP BUFFERS                                                          **
**                                                                       **
** Page 101                                                              **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_TRAP_TBUF (
    input       FETCHN,   //! FETCH_n (Fetch instruction, negate)
    input       INDN,     //! IDN_n
    input       INTRQN,   //! INTRQ_n
    input       PANN,     //! PAN_n
    input [1:0] PCR_1_0,  //! PCR[1:0]
    input [6:0] PT_15_9,  //! PT[15:9]
    input       VACCN,    //! VACC_n
    input       WRITEN,   //! WRITE_n

    output       IFETCH,
    output       IFETCHN,
    output       IIND,
    output       IINDN,
    output       INTRQ,
    output [1:0] IPCR_1_0,
    output [1:0] IPCR_1_0_N,
    output [6:0] IPT_15_9,
    output [6:0] IPT_15_9_N,
    output       IWRITE,
    output       IWRITEN,
    output       PAN,
    output       VACC
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [1:0] s_ipcr_1_0_out;
  wire [6:0] s_ipt_15_9_out;
  wire [6:0] s_ipt_15_9_n_out;
  wire [1:0] s_ipcr_1_0_n_out;
  wire [1:0] s_pcr_1_0;
  wire [6:0] s_pt_15_9;
  wire       s_fetch_n;
  wire       s_ifetch_n_out;
  wire       s_ifetch_out;
  wire       s_iind_n_out;
  wire       s_iind_out;
  wire       s_ind_n;
  wire       s_intrq_n;
  wire       s_intrq_out;
  wire       s_iwrite_n_out;
  wire       s_iwrite_out;
  wire       s_pan_n;
  wire       s_pan_out;
  wire       s_vacc_n;
  wire       s_vacc;
  wire       s_write_n;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_pcr_1_0[1:0]        = PCR_1_0[1:0];
  assign s_pt_15_9[6:0]        = PT_15_9[6:0];
  assign s_pan_n               = PANN;
  assign s_vacc_n              = VACCN;
  assign s_ind_n               = INDN;
  assign s_intrq_n             = INTRQN;
  assign s_fetch_n             = FETCHN;
  assign s_write_n             = WRITEN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign IFETCH                = s_ifetch_out;
  assign IFETCHN               = s_ifetch_n_out;
  assign IIND                  = s_iind_out;
  assign IINDN                 = s_iind_n_out;
  assign INTRQ                 = s_intrq_out;
  assign IPCR_1_0[1:0]         = s_ipcr_1_0_out[1:0];
  assign IPCR_1_0_N[1:0]       = s_ipcr_1_0_n_out[1:0];
  assign IPT_15_9[6:0]         = s_ipt_15_9_out[6:0];
  assign IPT_15_9_N[6:0]       = s_ipt_15_9_n_out[6:0];
  assign IWRITE                = s_iwrite_out;
  assign IWRITEN               = s_iwrite_n_out;
  assign PAN                   = s_pan_out;
  assign VACC                  = s_vacc;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_ifetch_n_out        = ~s_ifetch_out;
  assign s_ifetch_out          = ~s_fetch_n;
  assign s_iind_n_out          = ~s_iind_out;
  assign s_iind_out            = ~s_ind_n;
  assign s_intrq_out           = ~s_intrq_n;

  assign s_ipcr_1_0_n_out[1:0] = ~s_pcr_1_0[1:0];
  assign s_ipcr_1_0_out[1:0]   = ~s_ipcr_1_0_n_out[1:0];

  assign s_ipt_15_9_n_out[6:0] = ~s_pt_15_9[6:0];

  assign s_ipt_15_9_out[0]     = ~s_ipt_15_9_n_out[0];
  assign s_ipt_15_9_out[1]     = ~s_ipt_15_9_n_out[1];
  assign s_ipt_15_9_out[4]     = ~s_ipt_15_9_n_out[4];
  assign s_ipt_15_9_out[6]     = ~s_ipt_15_9_n_out[6];

  assign s_iwrite_n_out        = ~s_iwrite_out;
  assign s_iwrite_out          = ~s_write_n;
  assign s_pan_out             = ~s_pan_n;
  assign s_vacc                = ~s_vacc_n;

endmodule
