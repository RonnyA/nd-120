/**************************************************************************
** ND120 DGA                                                             **
** DECODE/DGA/POW                                                        **
**                                                                       **
**  Page 8 DECODE - DECODE_DGA_POW- Sheet 1 of 3                         **
**  Page 9 DECODE - DECODE_DGA_POW- Sheet 2 of 3                         **
**  Page 10 DECODE - DECODE_DGA_POW- Sheet 3 of 3                        **
**                                                                       **
** Last reviewed: 14-DEC-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module DECODE_DGA_POW (
    // Inputs
    input BDRY50N,
    input CLOSC,        //! Clear Oscilator signal (From IO_DCD_38) - Is 1 during a very short time at power-on. Then goes to 0 and stays there.
    input CLRTIN,       //! Clear Real Time Clock
    input CONTINUEN,    //! Continue Enable
    input EMCLN,        //! Enable Master Clear
    input LOADN,        //! Load
    input POWSENSE,     //! Power Sense. If high, power is good. If low, will trigger POWFAILN after some clock cycles. (1.2s delay?)
    input PRQN,         //! Panel Request
    input PWCL,         //! Power Control
    input REFN,         //! Refresh
    input RESET,        //! Reset
    input RTOSC,        //! Real Time Oscillator
    input SEL5MSN,  //! Select 5ms (if active will trigger RTC after 5 ms, not 20ms)
    input SSTOPN,   //! Set Stop Flip-Flop (When next FETCH is performed the microcproram is forced to microaddress 16 (Panel Interrupt) - Microcode command 14
    input STARTN,   //! Start
    input STOPN,    //! Stop
    input TESTE,    //! Test Enable

    // Outputs
    output CLEAR,     //! Clear signal
    output IDB0,      //! IDB 0
    output IDB1,      //! IDB 1
    output IDB2,      //! IDB 2
    output MCL,       //! Master Clear
    output PANN,      //! Panel Interrupt Vector
    output PANOSC,    //! Panel Oscillator
    output POWFAILN,  //! Power Fail
    output REFRQN,    //! Refresh Request
    output STPN,      //! Stop
    output TESTO,     //! Test Output
    output TOUT       //! Time Out
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire a580_nand_out;
  wire a590_nand_out;
  wire a592_nand_out;
  wire a597_nand_out;
  wire a598_nand_out;
  wire a599_nand_out;
  wire a609_nand_out;
  wire s_a578_out_n;
  wire s_a579_out_n;
  wire s_a591_q_n;
  wire s_a593_q_n;
  wire s_a594_q_n;
  wire s_a596_q_n;
  wire s_a601_y;
  wire s_a602_q_n;
  wire s_a605_q_n;
  wire s_a616_q;
  wire s_a617_q_n;
  wire s_a618_q_n;
  wire s_a618_q;
  wire s_a620_y;
  wire s_a621_q_n;
  wire s_a622_q_n;
  wire s_a623_q_n;
  wire s_a624_q_n;
  wire s_ms20;
  wire s_a626_q_n;
  wire s_a627_q_n;
  wire s_a631_q;
  wire s_a632_q_n;
  wire s_a634_q_n;
  wire s_bdry50_n;
  wire s_clear_n;
  wire s_clear;
  wire s_closc;
  wire s_clrti_n;
  wire s_clrti;
  wire s_conn_n;
  wire s_conn;
  wire s_continue_n;
  wire s_continue;
  wire s_emcl_n;
  wire s_esload_n;
  wire s_gnd;
  wire s_idb0;
  wire s_idb1;
  wire s_idb2;
  wire s_load_n;
  wire s_load;
  wire s_lod_n;
  wire s_lrst;
  wire s_mcl_n;
  wire s_mcl;
  wire s_pan_n;
  wire s_panosc;
  wire s_powfail_n;
  wire s_powfail;
  wire s_pows_n;
  wire s_powsense;
  wire s_prq_n;
  wire s_prq;
  wire s_pwcl_n;
  wire s_pwcl;
  wire s_ref_n;
  wire s_refrq_n;
  wire s_rescl_n;
  wire s_rescl;
  wire s_reset;
  wire s_rfclk;
  wire s_rst_n;
  wire s_rtc_n;
  wire s_rtc;
  wire s_rtosc;
  wire s_sel5ms_n;
  wire s_sstop_n;
  wire s_start_n;
  wire s_start;
  wire s_stop_n;
  wire s_stp_n;
  wire s_stp;
  wire s_test_enable;
  wire s_testo;
  wire s_tout;
  wire s_vcc;
  wire s_zz0;
  wire s_zz1;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_bdry50_n = BDRY50N;
  assign s_closc = CLOSC;
  assign s_clrti_n = CLRTIN;
  assign s_continue_n = CONTINUEN;
  assign s_emcl_n = EMCLN;
  assign s_load_n = LOADN;
  assign s_powsense = POWSENSE;
  assign s_prq_n = PRQN;
  assign s_pwcl = PWCL;
  assign s_ref_n = REFN;
  assign s_reset = RESET;
  assign s_rtosc = RTOSC;
  assign s_sel5ms_n = SEL5MSN;
  assign s_sstop_n = SSTOPN;
  assign s_start_n = STARTN;
  assign s_stop_n = STOPN;
  assign s_test_enable = TESTE;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign CLEAR = s_clear;
  assign IDB0 = s_idb0;
  assign IDB1 = s_idb1;
  assign IDB2 = s_idb2;
  assign MCL = s_mcl;
  assign PANN = s_pan_n;
  assign PANOSC = s_panosc;
  assign POWFAILN = s_powfail_n;
  assign REFRQN = s_refrq_n;
  assign STPN = s_stp_n;
  assign TESTO = s_testo;
  assign TOUT = s_tout;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Ground and power
  assign s_gnd = 1'b0;
  assign s_vcc = 1'b1;

  // NOT Gate's
  assign s_clear = ~s_clear_n;
  assign s_clrti = ~s_clrti_n;
  assign s_conn = ~s_conn_n;
  assign s_continue = ~s_continue_n;
  assign s_load = ~s_load_n;
  assign s_mcl_n = ~s_mcl;
  assign s_powfail_n = ~s_powfail;
  assign s_prq = ~s_prq_n;
  assign s_pwcl_n = ~s_pwcl;
  assign s_rtc = ~s_rtc_n;
  assign s_start = ~s_start_n;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/

  // A597 NAND_GATE_3_INPUTS
  assign a597_nand_out = ~(s_conn_n & s_lod_n & s_prq);

  //A609 NAND_GATE_3_INPUTS
  assign a609_nand_out = ~(s_conn_n & s_lod_n & s_zz0);

  // A598 NAND_GATE
  assign a598_nand_out = ~(s_rst_n & s_conn);

  // A599 NAND_GATE_4_INPUTS
  assign a599_nand_out = ~(s_rtc & s_prq_n & s_lod_n & s_rst_n);

  // A590 NAND_GATE_3_INPUTS
  assign a590_nand_out = ~(s_zz0 & s_lod_n & s_rst_n);

  // A580 NAND_GATE_3_INPUTS
  assign a580_nand_out = ~(s_sstop_n & s_clear_n & s_stop_n);

  // A606 NAND_GATE_4_INPUTS
  assign s_idb2 = ~(s_lod_n & s_conn_n & s_rst_n & s_mcl_n);

  //A592 NAND_GATE_8_INPUTS
  assign a592_nand_out = ~(s_mcl_n & s_rst_n & s_conn_n & s_lod_n & s_zz1 & s_prq_n & s_rtc_n & s_stp_n);

  // A603 NAND_GATE_4_INPUTS
  assign s_idb1 = ~(a597_nand_out & s_rst_n & s_mcl_n & a609_nand_out);

  // A604 NAND_GATE_4_INPUTS
  assign s_idb0 = ~(s_mcl_n & a598_nand_out & a599_nand_out & a590_nand_out);

  // A595 NAND_GATE
  assign s_pan_n = ~(s_sstop_n & a592_nand_out);

  //A573 NAND_GATE
  assign s_mcl = ~(s_emcl_n & s_clear_n);

  // A611 NOR_GATE
  assign s_pows_n = ~(s_powsense | s_pwcl);

  assign s_tout = ~(s_a631_q | s_rfclk);

  // A635 NOR_GATE
  assign s_rescl_n = ~(s_closc | s_reset);

  // A578 NAND_GATE
  assign s_a578_out_n = ~(s_stp_n & s_pwcl_n);

  // A579 NAND_GATE_3_INPUTS
  assign s_a579_out_n = ~(s_mcl_n & s_clrti_n & s_stp);

  J_K_FLIPFLOP #(
      .InvertClockEnable(0)
  ) A616 (
      .clock(s_a624_q_n),
      .j(s_a618_q_n),
      .k(s_vcc),
      .preset(s_gnd),
      .q(s_a616_q),
      .qBar(),
      .reset(s_rescl),
      .tick(1'b1)
  );

  J_K_FLIPFLOP #(
      .InvertClockEnable(0)
  ) A618 (
      .clock(s_a624_q_n),
      .j(s_a616_q),
      .k(s_vcc),
      .preset(s_gnd),
      .q(s_a618_q),
      .qBar(s_a618_q_n),
      .reset(s_rescl),
      .tick(1'b1)
  );

  J_K_FLIPFLOP #(
      .InvertClockEnable(0)
  ) A617 (
      .clock(s_a624_q_n),
      .j(s_a618_q),
      .k(s_a618_q),
      .preset(s_gnd),
      .q(),
      .qBar(s_a617_q_n),
      .reset(s_rescl),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) A572 (
      .clock(s_clear_n),
      .d(s_esload_n),
      .preset(s_clrti),
      .q(),
      .qBar(s_lrst),
      .reset(s_zz0),  //negated zz1
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) A577 (
      .clock(s_ms20),
      .d(s_gnd),
      .preset(s_clrti),
      .q(s_rtc_n),
      .qBar(),
      .reset(s_zz0),  //negated zz1
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) A600 (
      .clock(s_a605_q_n),
      .d(s_gnd),
      .preset(~s_pows_n),
      .q(s_powfail),
      .qBar(),
      .reset(~s_powfail),  // Q signal (POWFAIL) is fed back to reset (which has negated input in the original drawing)
      .tick(1'b1)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  F714 A623 (
      .H01_T (s_rtosc),
      .H02_R (s_rescl),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a623_q_n)
  );

  F714 A633 (
      .H01_T (s_rtosc),
      .H02_R (s_closc),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_rfclk)
  );


  // Connected all F091 (A637 and A613) to this F091
  F091 A613B (
      .N01(s_zz1),  // N01 = Always 1
      .N02(s_zz0)
  );  // N02 = Always 0

  F714 A596 (
      .H01_T (s_a601_y),
      .H02_R (s_powsense),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a596_q_n)
  );

  F714 A632 (
      .H01_T (s_a623_q_n),
      .H02_R (s_rescl),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a632_q_n)
  );

  F714 A629 (
      .H01_T (s_rfclk),
      .H02_R (s_closc),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_panosc)
  );

  F714 A602 (
      .H01_T (s_a596_q_n),
      .H02_R (s_powsense),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a602_q_n)
  );

  F714 A634 (
      .H01_T (s_a632_q_n),
      .H02_R (s_rescl),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a634_q_n)
  );

  F595 A570 (
      .H01_S (s_stp_n),
      .H02_R (s_pwcl),
      .H03_G (s_zz1),
      .N01_Q (),
      .N02_QB(s_esload_n)
  );

  F595 A571 (
      .H01_S (a580_nand_out),
      .H02_R (s_start),
      .H03_G (s_zz1),
      .N01_Q (s_stp),
      .N02_QB(s_stp_n)
  );

  F714 A593 (
      .H01_T (s_a602_q_n),
      .H02_R (s_powsense),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a593_q_n)
  );

  F714 A621 (
      .H01_T (s_a634_q_n),
      .H02_R (s_rescl),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a621_q_n)
  );

  F714 A594 (
      .H01_T (s_a593_q_n),
      .H02_R (s_powsense),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a594_q_n)
  );

  F714 A622 (
      .H01_T (s_a621_q_n),
      .H02_R (s_rescl),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a622_q_n)
  );

  F617 A630 (
      .H01_D (s_zz0),
      .H02_C (s_rfclk),
      .H03_RB(s_vcc),
      .H04_SB(s_ref_n),
      .N01_Q (s_refrq_n),
      .N02_QB()
  );

  F714 A619 (
      .H01_T (s_a622_q_n),
      .H02_R (s_rescl),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_testo)
  );

  F714 A591 (
      .H01_T (s_a594_q_n),
      .H02_R (s_powsense),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a591_q_n)
  );

  F714 A627 (
      .H01_T (s_a617_q_n),
      .H02_R (s_rescl),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a627_q_n)
  );

  F714 A605 (
      .H01_T (s_a591_q_n),
      .H02_R (s_powsense),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a605_q_n)
  );

  F617 A631 (
      .H01_D (s_refrq_n),
      .H02_C (s_rfclk),
      .H03_RB(s_vcc),
      .H04_SB(s_bdry50_n),
      .N01_Q (s_a631_q),
      .N02_QB()
  );

  F571 A620 (
      .A(s_test_enable),
      .D0(s_testo),
      .D1(s_rtosc),
      .ENB_N(s_gnd),
      .Y(s_a620_y)
  );

  F714 A626 (
      .H01_T (s_a627_q_n),
      .H02_R (s_rescl),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a626_q_n)
  );

  F714 A624 (
      .H01_T (s_a620_y),
      .H02_R (s_rescl),
      .H03_S (s_gnd),
      .N01_Q (),
      .N02_QB(s_a624_q_n)
  );

  F571 A625 (
      .A(s_sel5ms_n),
      .D0(s_a617_q_n),
      .D1(s_a626_q_n),
      .ENB_N(s_gnd),
      .Y(s_ms20)
  );

  F103 A628 (
      .F_IN (s_rescl_n),
      .F_OUT(s_rescl)
  );

  F571 A601 (
      .A(s_test_enable),
      .D0(s_ms20),
      .D1(s_rtosc),
      .ENB_N(s_gnd),
      .Y(s_a601_y)
  );

  F595 A576 (
      .H01_S (s_load),
      .H02_R (s_a579_out_n),
      .H03_G (s_zz1),
      .N01_Q (),
      .N02_QB(s_lod_n)
  );

  F595 A574 (
      .H01_S (s_lrst),
      .H02_R (s_a579_out_n),
      .H03_G (s_zz1),
      .N01_Q (),
      .N02_QB(s_rst_n)
  );

  /*  H01_S signal loops back vis STPN from A571. Verilator doesnt like it, Vivado does not complain */
  /* verilator lint_off UNOPTFLAT */  // <=== This didnt fix verilator lint error, so I added it into the F595 module for everyone..
  F595 A569 (
      .H01_S (s_a578_out_n),
      .H02_R (s_powfail_n),
      .H03_G (s_zz1),
      .N01_Q (),
      .N02_QB(s_clear_n)
  );
  /* verilator lint_on UNOPTFLAT */

  F595 A575 (
      .H01_S (s_continue),
      .H02_R (s_a579_out_n),
      .H03_G (s_zz1),
      .N01_Q (),
      .N02_QB(s_conn_n)
  );

endmodule
