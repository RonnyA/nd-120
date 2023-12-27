/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : BIF_DPATH_9                                                  **
 **                                                                          **
 *****************************************************************************/

module BIF_DPATH_9( BDAP50_n,
                    BDRY25_n,
                    BDRY50_n,
                    BD_23_0_n_io,
                    BGNT50_n,
                    BGNT_n,
                    BINPUT50_n,
                    CACT_n,
                    CA_9_0,
                    CBWRITE_n,
                    CC2_n,
                    CD_15_0_io,
                    CGNT50_n,
                    CGNTCACT_n,
                    CGNT_n,
                    DBAPR,
                    EADDR_n,
                    EBUS_n,
                    ECREQ,
                    EPEA_n,
                    EPES_n,
                    FETCH,
                    GNT_n,
                    IBAPR_n,
                    IDB_15_0,
                    IOD_n,
                    IORQ_n,
                    LBD_23_0_io,
                    MIS0,
                    MWRITE_n,
                    PD1,
                    PD3,
                    PPN_23_10,
                    Q0_n,
                    Q2_n,
                    RT_n,
                    SPEA,
                    SPES,
                    TERM_n,
                    WRITE );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        BDAP50_n;
   input        BDRY25_n;
   input        BDRY50_n;
   input        BGNT50_n;
   input        BGNT_n;
   input        BINPUT50_n;
   input        CACT_n;
   input [9:0]  CA_9_0;
   input        CC2_n;
   input        CGNT50_n;
   input        CGNT_n;
   input        EADDR_n;
   input        EBUS_n;
   input        ECREQ;
   input        EPEA_n;
   input        EPES_n;
   input        FETCH;
   input        GNT_n;
   input        IBAPR_n;
   input        IOD_n;
   input        IORQ_n;
   input        MIS0;
   input        MWRITE_n;
   input        PD1;
   input        PD3;
   input [13:0] PPN_23_10;
   input        Q0_n;
   input        Q2_n;
   input        RT_n;
   input        SPEA;
   input        SPES;
   input        TERM_n;
   input        WRITE;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [23:0] BD_23_0_n_io;
   output        CBWRITE_n;
   output [15:0] CD_15_0_io;
   output        CGNTCACT_n;
   output        DBAPR;
   output [15:0] IDB_15_0;
   output [23:0] LBD_23_0_io;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [23:0] s_logisimBus12;
   wire [23:0] s_logisimBus22;
   wire [15:0] s_logisimBus26;
   wire [13:0] s_logisimBus27;
   wire [9:0]  s_logisimBus5;
   wire [15:0] s_logisimBus7;
   wire [23:0] s_logisimBus8;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet18;
   wire        s_logisimNet19;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet23;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
   wire        s_logisimNet3;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
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
   wire        s_logisimNet6;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus27[13:0] = PPN_23_10;
   assign s_logisimBus5[9:0]   = CA_9_0;
   assign s_logisimNet0        = EADDR_n;
   assign s_logisimNet10       = ECREQ;
   assign s_logisimNet13       = GNT_n;
   assign s_logisimNet15       = EPES_n;
   assign s_logisimNet16       = SPEA;
   assign s_logisimNet17       = FETCH;
   assign s_logisimNet18       = SPES;
   assign s_logisimNet19       = EPEA_n;
   assign s_logisimNet25       = BGNT_n;
   assign s_logisimNet28       = WRITE;
   assign s_logisimNet29       = BDAP50_n;
   assign s_logisimNet30       = CACT_n;
   assign s_logisimNet31       = BDRY25_n;
   assign s_logisimNet32       = BDRY50_n;
   assign s_logisimNet33       = CGNT_n;
   assign s_logisimNet34       = CGNT50_n;
   assign s_logisimNet35       = CC2_n;
   assign s_logisimNet36       = Q0_n;
   assign s_logisimNet37       = Q2_n;
   assign s_logisimNet38       = EBUS_n;
   assign s_logisimNet39       = IBAPR_n;
   assign s_logisimNet40       = MWRITE_n;
   assign s_logisimNet41       = PD1;
   assign s_logisimNet42       = IOD_n;
   assign s_logisimNet43       = BINPUT50_n;
   assign s_logisimNet44       = IORQ_n;
   assign s_logisimNet45       = TERM_n;
   assign s_logisimNet46       = RT_n;
   assign s_logisimNet47       = PD3;
   assign s_logisimNet48       = MIS0;
   assign s_logisimNet49       = BGNT50_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BD_23_0_n_io = s_logisimBus12[23:0];
   assign CBWRITE_n    = s_logisimNet3;
   assign CD_15_0_io   = s_logisimBus26[15:0];
   assign CGNTCACT_n   = s_logisimNet2;
   assign DBAPR        = s_logisimNet4;
   assign IDB_15_0     = s_logisimBus7[15:0];
   assign LBD_23_0_io  = s_logisimBus8[23:0];

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   BIF_DPATH_PPNLBD_14   PPNLBD (.CA_9_0(s_logisimBus5[9:0]),
                                 .EADR_n(s_logisimNet0),
                                 .ECREQ(s_logisimNet10),
                                 .LBD_23_0(s_logisimBus22[23:0]),
                                 .PPN_23_10(s_logisimBus27[13:0]));

   BIF_DPATH_CDLBD_11   CDLBD (.CD_15_0_io(s_logisimBus26[15:0]),
                               .DSTB_n(s_logisimNet1),
                               .ECREQ(s_logisimNet10),
                               .EMD_n(s_logisimNet9),
                               .LBD_15_0_io(s_logisimBus22[15:0]),
                               .WLBD_n(s_logisimNet24));

   BIF_DPATH_BDLBD_10   BDLBD (.BD_23_0_n_io(s_logisimBus12[23:0]),
                               .BGNTCACT_n(s_logisimNet23),
                               .BGNT_n(s_logisimNet25),
                               .CLKBD(s_logisimNet11),
                               .EBADR(s_logisimNet20),
                               .EBD_n(s_logisimNet6),
                               .LBD_23_0_io(s_logisimBus8[23:0]),
                               .WBD_n(s_logisimNet14));

   BIF_DPATH_PESPEA_13   PESPEA (.BD_23_0_n(s_logisimBus12[23:0]),
                                 .EPEA_n(s_logisimNet19),
                                 .EPES_n(s_logisimNet15),
                                 .FETCH(s_logisimNet17),
                                 .GNT_n(s_logisimNet13),
                                 .IDB_15_0(s_logisimBus7[15:0]),
                                 .SPEA(s_logisimNet16),
                                 .SPES(s_logisimNet18));

   BIF_DPATH_LDBCTL_12   LDBCTL (.BDAP50_n(s_logisimNet29),
                                 .BDRY25_n(s_logisimNet31),
                                 .BDRY50_n(s_logisimNet32),
                                 .BGNT50_n(s_logisimNet49),
                                 .BGNTCACT(s_logisimNet23),
                                 .BGNT_n(s_logisimNet25),
                                 .BINPUT50_n(s_logisimNet43),
                                 .CACT_n(s_logisimNet30),
                                 .CBWRITE_n(s_logisimNet3),
                                 .CC2_n(s_logisimNet35),
                                 .CGNT50_n(s_logisimNet34),
                                 .CGNTCACT_n(s_logisimNet2),
                                 .CGNT_n(s_logisimNet33),
                                 .CLKBD(s_logisimNet11),
                                 .DBAPR(s_logisimNet4),
                                 .DSTB_n(s_logisimNet1),
                                 .EADR_n(s_logisimNet0),
                                 .EBADR(s_logisimNet20),
                                 .EBD_n(s_logisimNet6),
                                 .EBUS_n(s_logisimNet38),
                                 .EMD_n(s_logisimNet9),
                                 .GNT_n(s_logisimNet13),
                                 .IBAPR_n(s_logisimNet39),
                                 .IOD_n(s_logisimNet42),
                                 .IORQ_n(s_logisimNet44),
                                 .MIS0(s_logisimNet48),
                                 .MWRITE_n(s_logisimNet40),
                                 .PD1(s_logisimNet41),
                                 .PD3(s_logisimNet47),
                                 .Q0_n(s_logisimNet36),
                                 .Q2_n(s_logisimNet37),
                                 .RT_n(s_logisimNet46),
                                 .TERM_n(s_logisimNet45),
                                 .WBD_n(s_logisimNet14),
                                 .WLBD_n(s_logisimNet24),
                                 .WRITE(s_logisimNet28));

endmodule
