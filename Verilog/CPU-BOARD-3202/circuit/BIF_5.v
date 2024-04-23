/**************************************************************************
** ND120 CPU, MM&M                                                       **
** BIF/BCTL                                                              **
** BUS INTERFACE                                                         **
** SHEET 5  of 50                                                        **
**                                                                       ** 
** Last reviewed: 21-APRIL-2024                                          **
** Ronny Hansen                                                          **               
***************************************************************************/

// TODO: MAP IN and OUT signals for _io signals

module BIF_5( 

    // FPGA signals
    input        sysclk,      // System clock in FPGA
    input        sys_rst_n,   // System reset in FPGA
 
    // Inputs signals

    input        BGNT50_n,
    input        BGNT_n,
    input [9:0]  CA_9_0,
    input        CC2_n,
    input        CGNT50_n,
    input        CGNT_n,
    input        CLEAR_n,
    input        CRQ_n,
    input        EBUS_n,
    input        ECRQ,
    input        FETCH,
    input        GNT50_n,
    input        IBAPR_n,
    input        IBDAP_n,
    input        IBDRY_n,
    input        IBINPUT_n,
    input        IBPERR_n,
    input        IBREQ_n,
    input        IORQ_n,
    input        ISEMRQ_n,
    input        LERR_n,
    input        LPRERR_n,
    input        MIS0,
    input        MOFF_n,
    input        MOR25_n,
    input        MWRITE_n,
    input        OSC,
    input        PA_n,
    input        PD1,
    input        PD3,
    input [13:0] PPN_23_10,
    input        PS_n,
    input        REFRQ_n,
    input        RT_n,
    input        SSEMA_n,
    input        TERM_n,
    input        TOUT,
    input        WRITE,
 
    // INPUTS and OUTPUTS here

    inout  [23:0] BD_23_0_n_IN,
    output [23:0] BD_23_0_n_OUT,

    
    input  [15:0] CD_15_0_IN,
    output [15:0] CD_15_0_OUT,


    input  [23:0] LBD_23_0_IN,
    output [23:0] LBD_23_0_OUT,

    // OUTPUT signals
    output [15:0] IDB_15_0_OUT,


    output        BAPR_n,
    output        BDAP50_n,
    output        BDAP_n,
    output        BDRY50_n,
    output        BDRY_n,    
    output        BERROR_n,
    output        BINACK_n,
    output        BINPUT_n,
    output        BIOXE_n,
    output        BMEM_n,
    output        BREF_n,
    
    output        CGNCACT_n,
    output        DAP_n,
    output        DBAPR,
    output        GNT_n,
    
    output        IOXERR_n,    
    output        MOR_n,
    output        MR_n,
    output        OUTGRANT_n,
    output        OUTIDENT_n,
    output        PARERR_n,
    output        REF_n,
    output        RERR_n,
    output        SEMRQ50_n,
    output        SEMRQ_n
);

   
   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [13:0] s_logisimBus10;
   wire [2:0]  s_logisimBus13;
   wire [15:0] s_cd_15_0_out;
   wire [15:0] s_idb_15_0_out;
   wire [9:0]  s_logisimBus54;
   wire [23:0] s_lbd_23_0_out;
   wire [23:0] s_bd_23_0_n_out;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet18;
   wire        s_logisimNet19;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet21;
   wire        s_logisimNet22;
   wire        s_logisimNet23;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
   wire        s_logisimNet3;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet35;
   wire        s_logisimNet36;
   wire        s_logisimNet37;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet40;
   wire        s_logisimNet41;
   wire        s_logisimNet42;
   wire        s_logisimNet43;
   wire        s_logisimNet44;
   wire        s_logisimNet45;
   wire        s_logisimNet46;
   wire        s_logisimNet47;
   wire        s_logisimNet48;
   wire        s_logisimNet49;
   wire        s_logisimNet5;
   wire        s_logisimNet50;
   wire        s_logisimNet51;
   wire        s_logisimNet52;
   wire        s_logisimNet53;
   wire        s_logisimNet55;
   wire        s_logisimNet56;
   wire        s_logisimNet57;
   wire        s_logisimNet58;
   wire        s_logisimNet59;
   wire        s_logisimNet6;
   wire        s_logisimNet60;
   wire        s_logisimNet61;
   wire        s_logisimNet62;
   wire        s_logisimNet63;
   wire        s_logisimNet64;
   wire        s_logisimNet65;
   wire        s_logisimNet66;
   wire        s_logisimNet67;
   wire        s_logisimNet7;
   wire        s_logisimNet70;
   wire        s_logisimNet71;
   wire        s_logisimNet72;
   wire        s_logisimNet73;
   wire        s_logisimNet74;
   wire        s_logisimNet75;
   wire        s_logisimNet76;
   wire        s_logisimNet77;
   wire        s_logisimNet78;
   wire        s_logisimNet79;
   wire        s_logisimNet8;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus10[13:0] = PPN_23_10;
   assign s_logisimBus54[9:0]  = CA_9_0;
   assign s_logisimNet0        = WRITE;
   assign s_logisimNet1        = BGNT50_n;
   assign s_logisimNet11       = ECRQ;
   assign s_logisimNet12       = IBREQ_n;
   assign s_logisimNet14       = IBAPR_n;
   assign s_logisimNet17       = MIS0;
   assign s_logisimNet19       = CC2_n;
   assign s_logisimNet2        = PD3;
   assign s_logisimNet20       = IBPERR_n;
   assign s_logisimNet21       = CGNT50_n;
   assign s_logisimNet22       = IORQ_n;
   assign s_logisimNet24       = IBDAP_n;
   assign s_logisimNet26       = PD1;
   assign s_logisimNet27       = CGNT_n;
   assign s_logisimNet31       = IBINPUT_n;
   assign s_logisimNet41       = ISEMRQ_n;
   assign s_logisimNet42       = LPRERR_n;
   assign s_logisimNet43       = PS_n;
   assign s_logisimNet44       = TOUT;
   assign s_logisimNet45       = CRQ_n;
   assign s_logisimNet46       = REFRQ_n;
   assign s_logisimNet48       = MWRITE_n;
   assign s_logisimNet49       = EBUS_n;
   assign s_logisimNet5        = TERM_n;
   assign s_logisimNet52       = BGNT_n;
   assign s_logisimNet53       = IBDRY_n;
   assign s_logisimNet55       = FETCH;
   assign s_logisimNet7        = MOFF_n;
   assign s_logisimNet70       = SSEMA_n;
   assign s_logisimNet73       = MOR25_n;
   assign s_logisimNet74       = LERR_n;
   assign s_logisimNet75       = PA_n;
   assign s_logisimNet77       = OSC;
   assign s_logisimNet78       = GNT50_n;
   assign s_logisimNet79       = CLEAR_n;
   assign s_logisimNet8        = RT_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BAPR_n       = s_logisimNet29;
   assign BDAP50_n     = s_logisimNet23;
   assign BDAP_n       = s_logisimNet30;
   assign BDRY50_n     = s_logisimNet15;
   assign BDRY_n       = s_logisimNet66;
   assign BD_23_0_n_OUT = s_bd_23_0_n_out[23:0];
   assign BERROR_n     = s_logisimNet62;
   assign BINACK_n     = s_logisimNet60;
   assign BINPUT_n     = s_logisimNet64;
   assign BIOXE_n      = s_logisimNet63;
   assign BMEM_n       = s_logisimNet47;
   assign BREF_n       = s_logisimNet50;
   assign CD_15_0_OUT  = s_cd_15_0_out[15:0];
   assign CGNCACT_n    = s_logisimNet58;
   assign DAP_n        = s_logisimNet67;
   assign DBAPR        = s_logisimNet61;
   assign GNT_n        = s_logisimNet6;
   assign IDB_15_0_OUT = s_idb_15_0_out[15:0];
   assign IOXERR_n     = s_logisimNet71;
   assign LBD_23_0_OUT = s_lbd_23_0_out[23:0];
   assign MOR_n        = s_logisimNet72;
   assign MR_n         = s_logisimNet39;
   assign OUTGRANT_n   = s_logisimNet76;
   assign OUTIDENT_n   = s_logisimNet59;
   assign PARERR_n     = s_logisimNet16;
   assign REF_n        = s_logisimNet32;
   assign RERR_n       = s_logisimNet57;
   assign SEMRQ50_n    = s_logisimNet56;
   assign SEMRQ_n      = s_logisimNet65;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   BIF_DPATH_9   DPATH (.BDAP50_n(s_logisimNet23),
                        .BDRY25_n(s_logisimNet40),
                        .BDRY50_n(s_logisimNet15),
                        .BD_23_0_n_io(s_bd_23_0_n_out[23:0]),
                        .BGNT50_n(s_logisimNet1),
                        .BGNT_n(s_logisimNet52),
                        .BINPUT50_n(s_logisimNet3),
                        .CACT_n(s_logisimNet9),
                        .CA_9_0(s_logisimBus54[9:0]),
                        .CBWRITE_n(s_logisimNet38),
                        .CC2_n(s_logisimNet19),
                        .CD_15_0_io(s_cd_15_0_out[15:0]),
                        .CGNT50_n(s_logisimNet21),
                        .CGNTCACT_n(s_logisimNet58),
                        .CGNT_n(s_logisimNet27),
                        .DBAPR(s_logisimNet61),
                        .EADDR_n(s_logisimNet28),
                        .EBUS_n(s_logisimNet49),
                        .ECREQ(s_logisimNet11),
                        .EPEA_n(s_logisimNet35),
                        .EPES_n(s_logisimNet25),
                        .FETCH(s_logisimNet55),
                        .GNT_n(s_logisimNet6),
                        .IBAPR_n(s_logisimNet14),
                        .IDB_15_0_OUT(s_idb_15_0_out[15:0]),
                        .IOD_n(s_logisimNet37),
                        .IORQ_n(s_logisimNet22),
                        .LBD_23_0_io(s_lbd_23_0_out[23:0]),
                        .MIS0(s_logisimNet17),
                        .MWRITE_n(s_logisimNet48),
                        .PD1(s_logisimNet26),
                        .PD3(s_logisimNet2),
                        .PPN_23_10(s_logisimBus10[13:0]),
                        .Q0_n(s_logisimBus13[0]),
                        .Q2_n(s_logisimBus13[2]),
                        .RT_n(s_logisimNet8),
                        .SPEA(s_logisimNet51),
                        .SPES(s_logisimNet36),
                        .TERM_n(s_logisimNet5),
                        .WRITE(s_logisimNet0));

   BIF_BCTL_6   BCTL (.BAPR_n(s_logisimNet29),
                      .BDAP50_n(s_logisimNet23),
                      .BDAP_n(s_logisimNet30),
                      .BDRY25_n(s_logisimNet40),
                      .BDRY50_n(s_logisimNet15),
                      .BDRY_n(s_logisimNet66),
                      .BERROR_n(s_logisimNet62),
                      .BINACK_n(s_logisimNet60),
                      .BINPUT50_n(s_logisimNet3),
                      .BINPUT_n(s_logisimNet64),
                      .BIOXE_n(s_logisimNet63),
                      .BMEM_n(s_logisimNet47),
                      .BREF_n(s_logisimNet50),
                      .CACT_n(s_logisimNet9),
                      .CBWRITE_n(s_logisimNet38),
                      .CC2_n(s_logisimNet19),
                      .CGNT50_n(s_logisimNet21),
                      .CGNT_n(s_logisimNet27),
                      .CLEAR_n(s_logisimNet79),
                      .CRQ_n(s_logisimNet45),
                      .DAP_n(s_logisimNet67),
                      .DBAPR(s_logisimNet61),
                      .EADR_n(s_logisimNet28),
                      .EPEA_n(s_logisimNet35),
                      .EPES_n(s_logisimNet25),
                      .GNT50_n(s_logisimNet78),
                      .GNT_n(s_logisimNet6),
                      .IBDAP_n(s_logisimNet24),
                      .IBDRY_n(s_logisimNet53),
                      .IBINPUT_n(s_logisimNet31),
                      .IBPERR_n(s_logisimNet20),
                      .IBREQ_n(s_logisimNet12),
                      .IOD_n(s_logisimNet37),
                      .IORQ_n(s_logisimNet22),
                      .IOXERR_n(s_logisimNet71),
                      .ISEMRQ_n(s_logisimNet41),
                      .LERR_n(s_logisimNet74),
                      .LPERR_n(s_logisimNet42),
                      .MIS0(s_logisimNet17),
                      .MOFF_n(s_logisimNet7),
                      .MOR25_n(s_logisimNet73),
                      .MOR_n(s_logisimNet72),
                      .MR_n(s_logisimNet39),
                      .OSC(s_logisimNet77),
                      .OUTGRANT_n(s_logisimNet76),
                      .OUTIDENT_n(s_logisimNet59),
                      .PARERR_n(s_logisimNet16),
                      .PA_n(s_logisimNet75),
                      .PD1(s_logisimNet26),
                      .PD3(s_logisimNet2),
                      .PS_n(s_logisimNet43),
                      .Q_2_0_n(s_logisimBus13[2:0]),
                      .REFRQ_n(s_logisimNet46),
                      .REF_n(s_logisimNet32),
                      .RERR_n(s_logisimNet57),
                      .SEMRQ50_n(s_logisimNet56),
                      .SEMRQ_n(s_logisimNet65),
                      .SPEA(s_logisimNet51),
                      .SPES(s_logisimNet36),
                      .SSEMA_n(s_logisimNet70),
                      .TERM_n(s_logisimNet5),
                      .TOUT(s_logisimNet44));

endmodule
