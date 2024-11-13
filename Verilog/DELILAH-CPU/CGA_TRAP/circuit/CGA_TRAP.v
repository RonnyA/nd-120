/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/TRAP                                                             **
** Trap                                                                  **
**                                                                       **
** Page 100                                                              **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_TRAP (
    input CBRKN,
    input DSTOPN,
    input ETRAPN,
    input FETCHN,
    input FTRAPN,
    input INDN,
    input INTRQN,
    input PANN,
    input [1:0] PCR_1_0,
    input PONI,
    input [6:0] PT_15_9,
    input TCLK,
    input VACCN,
    input VTRAPN,
    input WRITEN,

    output BRKN,
    output PVIOL,
    output RESTR,
    output TRAPN,
    output [3:0] TVEC_3_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [1:0] s_ipcr_1_0;
  wire [1:0] s_ipcr_1_0_n;
  wire [3:0] s_tvec_3_0_out;
  wire [1:0] s_pcr_1_0;
  wire [6:0] s_pt_15_9;
  wire [6:0] s_ipt_15_9_n;
  wire [6:0] s_ipt_15_9;
  wire       s_brk_n_out;
  wire       s_cbrk_n;
  wire       s_dstop_n;
  wire       s_etrap_n;
  wire       s_fetch_n;
  wire       s_ftrap_n;
  wire       s_ifetch_n;
  wire       s_ifetch;
  wire       s_iind_n;
  wire       s_iind;
  wire       s_ind_n;
  wire       s_intrq_n;
  wire       s_intrq;
  wire       s_iwrite_n;
  wire       s_iwrite;
  wire       s_pan_n;
  wire       s_pan;
  wire       s_poni;
  wire       s_pviol_out;
  wire       s_restr_out;
  wire       s_tclk;
  wire       s_trap_n_out;
  wire       s_vacc_n;
  wire       s_vacc;
  wire       s_vtrap_n;
  wire       s_write_n;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_pcr_1_0[1:0] = PCR_1_0;
  assign s_pt_15_9[6:0] = PT_15_9;
  assign s_cbrk_n       = CBRKN;
  assign s_dstop_n      = DSTOPN;
  assign s_etrap_n      = ETRAPN;
  assign s_fetch_n      = FETCHN;
  assign s_ftrap_n      = FTRAPN;
  assign s_ind_n        = INDN;
  assign s_intrq_n      = INTRQN;
  assign s_pan_n        = PANN;
  assign s_poni         = PONI;
  assign s_tclk         = TCLK;
  assign s_vacc_n       = VACCN;
  assign s_vtrap_n      = VTRAPN;
  assign s_write_n      = WRITEN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign BRKN           = s_brk_n_out;
  assign PVIOL          = s_pviol_out;
  assign RESTR          = s_restr_out;
  assign TRAPN          = s_trap_n_out;
  assign TVEC_3_0       = s_tvec_3_0_out[3:0];

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  CGA_TRAP_TVGEN TVGEN (
      .DSTOPN(s_dstop_n),
      .FTRAPN(s_ftrap_n),
      .IFETCH(s_ifetch),
      .IFETCHN(s_ifetch_n),
      .IIND(s_iind),
      .IINDN(s_iind_n),
      .INTRQ(s_intrq),
      .IPCR_1_0(s_ipcr_1_0[1:0]),
      .IPCR_1_0_N(s_ipcr_1_0_n[1:0]),
      .IPT_15_9(s_ipt_15_9[6:0]),
      .IPT_15_9_N(s_ipt_15_9_n[6:0]),
      .IWRITE(s_iwrite),
      .IWRITEN(s_iwrite_n),
      .PAN(s_pan),
      .PONI(s_poni),
      .PVIOL(s_pviol_out),
      .RESTR(s_restr_out),
      .TCLK(s_tclk),
      .TVEC_3_0(s_tvec_3_0_out[3:0]),
      .VACC(s_vacc),
      .VTRAPN(s_vtrap_n)
  );

  CGA_TRAP_BRKDET BRKDET (
      .BRKN(s_brk_n_out),
      .CBRKN(s_cbrk_n),
      .ETRAPN(s_etrap_n),
      .FTRAPN(s_ftrap_n),
      .IFETCH(s_ifetch),
      .IFETCHN(s_ifetch_n),
      .IINDN(s_iind_n),
      .INTRQ(s_intrq),
      .IPCR_1_0(s_ipcr_1_0_n[1:0]),
      .IPCR_1_0_N(s_ipcr_1_0[1:0]),
      .IPT_15_9(s_ipt_15_9_n[6:0]),
      .IPT_15_9_N(s_ipt_15_9[6:0]),
      .IWRITE(s_iwrite),
      .IWRITEN(s_iwrite_n),
      .TRAPN(s_trap_n_out),
      .VACC(s_vacc),
      .VTRAPN(s_vtrap_n)
  );

  CGA_TRAP_TBUF TBUF (
      .FETCHN(s_fetch_n),
      .IFETCH(s_ifetch),
      .IFETCHN(s_ifetch_n),
      .IIND(s_iind),
      .IINDN(s_iind_n),
      .INDN(s_ind_n),
      .INTRQ(s_intrq),
      .INTRQN(s_intrq_n),
      .IPCR_1_0(s_ipcr_1_0_n[1:0]),
      .IPCR_1_0_N(s_ipcr_1_0[1:0]),
      .IPT_15_9(s_ipt_15_9_n[6:0]),
      .IPT_15_9_N(s_ipt_15_9[6:0]),
      .IWRITE(s_iwrite),
      .IWRITEN(s_iwrite_n),
      .PAN(s_pan),
      .PANN(s_pan_n),
      .PCR_1_0(s_pcr_1_0[1:0]),
      .PT_15_9(s_pt_15_9[6:0]),
      .VACC(s_vacc),
      .VACCN(s_vacc_n),
      .WRITEN(s_write_n)
  );

endmodule
