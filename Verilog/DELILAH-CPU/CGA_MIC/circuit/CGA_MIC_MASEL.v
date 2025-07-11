/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MIC/MASEL                                                        **
** Microcode Address SELECT                                              **
**                                                                       **
** Page 19                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 22-MARCH 2025                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MIC_MASEL (
    input sysclk,    // System clock in FPGA
    input sys_rst_n, // System reset in FPGA

    input        CSBIT20,
    input [11:0] CSBIT_11_0,
    input [ 3:0] JMP_3_0,
    input        MCLK,
    input        MCLKN,
    input        MRN,
    input [12:0] NEXT_12_0,
    input [12:0] RET_12_0,
    input        SC5,
    input        SC6,

    output [12:0] IW_12_0,
    output [12:0] W_12_0
);

localparam [1:0] SEL_JUMP   = 2'b00;
localparam [1:0] SEL_RETURN = 2'b01;
localparam [1:0] SEL_NEXT   = 2'b10;
localparam [1:0] SEL_REPEAT = 2'b11;



  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [ 1:0] s_mux_selector;
  wire [12:0] s_ret_12_0;
  wire [12:0] s_next_12_0;
  wire [11:0] s_csbit_11_0;
  wire [12:0] s_w_12_0_out;
  wire [12:0] s_iw_12_0_out;
  wire [ 3:0] s_jmp_3_0;
  //wire [12:0] s_rep_12_0;
  wire        s_csbit20;
  wire        s_mclk_n;
  wire        s_mclk;
  wire        s_mr_n;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_mux_selector[0]  = SC5;
  assign s_mux_selector[1]  = SC6;
  assign s_ret_12_0[12:0]   = RET_12_0;
  assign s_next_12_0[12:0]  = NEXT_12_0;
  assign s_csbit_11_0[11:0] = CSBIT_11_0;
  assign s_jmp_3_0[3:0]     = JMP_3_0;
  assign s_mclk_n           = MCLKN;
  assign s_mclk             = MCLK;
  assign s_csbit20          = CSBIT20;
  assign s_mr_n             = MRN;

  wire [12:0] s_jmpaddr_12_0;
  assign s_jmpaddr_12_0 = {s_csbit_11_0[11:4], s_jmp_3_0[3:0]};

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  // assign IW_12_0            = s_iw_12_0_out[12:0];
  //assign W_12_0             = s_w_12_0_out[12:0];

  assign IW_12_0            = regIW;
  assign W_12_0             = regW;


  reg [12:0] regREP;

  reg [12:0] regW;
  reg [12:0] regIW;

  // Code to make LINTER _not_ complain about bits not read in CSBIITS bits 3:0
  (* keep = "true", DONT_TOUCH = "true" *) wire [3:0] unused_CSBITS_bits;
  assign unused_CSBITS_bits[3:0] = s_csbit_11_0[3:0];

  always @(*) begin
    case (s_mux_selector)
        SEL_JUMP: begin
            // handle jump
            regREP = s_jmpaddr_12_0;
        end
        SEL_RETURN: begin
            // handle return
            regREP = s_ret_12_0;
        end
        SEL_NEXT: begin
            // handle next
            regREP = s_next_12_0;
        end
        SEL_REPEAT: begin
            // handle repeat
            regREP = IW_12_0;
        end
        default: begin
            // optional: handle invalid case
        end
    endcase
  end

  // LATCH regREP to W as long as MCLKN is active
  // Is used by IPOS to create the MA_12_0 address to microcode RAM
  always @(*) begin
    if (s_mclk_n) begin
      regW = regREP;
    end
  end


  // On rising clock edge load REP into IW
  // IW goes back to IINC to calculate next address (which is then input to stack module)
  always @(posedge s_mclk or negedge s_mr_n) begin
    if (!s_mr_n) begin
        regIW <= 0;
    end else begin
      regIW <= regREP;
    end
  end



  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   /*

   reg [12:0] dRep12;

  Multiplexer_4 PLEXERS_1 (
      .muxIn_0(s_csbit_11_0[11]),
      .muxIn_1(s_ret_12_0[11]),
      .muxIn_2(s_next_12_0[11]),
      .muxIn_3(s_iw_12_0_out[11]),
      .muxOut(s_rep_12_0[11]),
      .sel(s_mux_selector[1:0])
  );

  Multiplexer_4 PLEXERS_2 (
      .muxIn_0(s_csbit_11_0[10]),
      .muxIn_1(s_ret_12_0[10]),
      .muxIn_2(s_next_12_0[10]),
      .muxIn_3(s_iw_12_0_out[10]),
      .muxOut(s_rep_12_0[10]),
      .sel(s_mux_selector[1:0])
  );

  Multiplexer_4 PLEXERS_3 (
      .muxIn_0(s_csbit_11_0[9]),
      .muxIn_1(s_ret_12_0[9]),
      .muxIn_2(s_next_12_0[9]),
      .muxIn_3(s_iw_12_0_out[9]),
      .muxOut(s_rep_12_0[9]),
      .sel(s_mux_selector[1:0])
  );

  Multiplexer_4 PLEXERS_4 (
      .muxIn_0(s_csbit_11_0[8]),
      .muxIn_1(s_ret_12_0[8]),
      .muxIn_2(s_next_12_0[8]),
      .muxIn_3(s_iw_12_0_out[8]),
      .muxOut(s_rep_12_0[8]),
      .sel(s_mux_selector[1:0])
  );

  Multiplexer_4 PLEXERS_5 (
      .muxIn_0(s_csbit_11_0[7]),
      .muxIn_1(s_ret_12_0[7]),
      .muxIn_2(s_next_12_0[7]),
      .muxIn_3(s_iw_12_0_out[7]),
      .muxOut(s_rep_12_0[7]),
      .sel(s_mux_selector[1:0])
  );

  Multiplexer_4 PLEXERS_6 (
      .muxIn_0(s_csbit_11_0[6]),
      .muxIn_1(s_ret_12_0[6]),
      .muxIn_2(s_next_12_0[6]),
      .muxIn_3(s_iw_12_0_out[6]),
      .muxOut(s_rep_12_0[6]),
      .sel(s_mux_selector[1:0])
  );

  Multiplexer_4 PLEXERS_7 (
      .muxIn_0(s_csbit_11_0[5]),
      .muxIn_1(s_ret_12_0[5]),
      .muxIn_2(s_next_12_0[5]),
      .muxIn_3(s_iw_12_0_out[5]),
      .muxOut(s_rep_12_0[5]),
      .sel(s_mux_selector[1:0])
  );

  Multiplexer_4 PLEXERS_8 (
      .muxIn_0(s_csbit_11_0[4]),
      .muxIn_1(s_ret_12_0[4]),
      .muxIn_2(s_next_12_0[4]),
      .muxIn_3(s_iw_12_0_out[4]),
      .muxOut(s_rep_12_0[4]),
      .sel(s_mux_selector[1:0])
  );

  Multiplexer_4 PLEXERS_9 (
      .muxIn_0(s_jmp_3_0[3]),
      .muxIn_1(s_ret_12_0[3]),
      .muxIn_2(s_next_12_0[3]),
      .muxIn_3(s_iw_12_0_out[3]),
      .muxOut(s_rep_12_0[3]),
      .sel(s_mux_selector[1:0])
  );

  Multiplexer_4 PLEXERS_10 (
      .muxIn_0(s_jmp_3_0[2]),
      .muxIn_1(s_ret_12_0[2]),
      .muxIn_2(s_next_12_0[2]),
      .muxIn_3(s_iw_12_0_out[2]),
      .muxOut(s_rep_12_0[2]),
      .sel(s_mux_selector[1:0])
  );

  Multiplexer_4 PLEXERS_11 (
      .muxIn_0(s_jmp_3_0[1]),
      .muxIn_1(s_ret_12_0[1]),
      .muxIn_2(s_next_12_0[1]),
      .muxIn_3(s_iw_12_0_out[1]),
      .muxOut(s_rep_12_0[1]),
      .sel(s_mux_selector[1:0])
  );

  Multiplexer_4 PLEXERS_12 (
      .muxIn_0(s_jmp_3_0[0]),
      .muxIn_1(s_ret_12_0[0]),
      .muxIn_2(s_next_12_0[0]),
      .muxIn_3(s_iw_12_0_out[0]),
      .muxOut(s_rep_12_0[0]),
      .sel(s_mux_selector[1:0])
  );

  Multiplexer_4 PLEXERS_13 (
      .muxIn_0(s_csbit20),
      .muxIn_1(s_ret_12_0[12]),
      .muxIn_2(s_next_12_0[12]),
      .muxIn_3(s_iw_12_0_out[12]),
      .muxOut(s_rep_12_0[12]),
      .sel(s_mux_selector[1:0])
  );

*/

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/
/*
  L8 WL_HI
  (
    // System Input signals
    .sysclk(sysclk),                          // System clock in FPGA
    .sys_rst_n(sys_rst_n),                    // System reset in FPGA

    // Input signals
    .L  (s_mclk_n),

    .A  (s_rep_12_0[12]),
    .B  (s_rep_12_0[11]),
    .C  (s_rep_12_0[10]),
    .D  (s_rep_12_0[9]),
    .E  (s_rep_12_0[8]),
    .F  (s_rep_12_0[7]),
    .G  (s_rep_12_0[6]),
    .H  (s_rep_12_0[5]),

    // Output signals
    .QA (s_w_12_0_out[12]),
    .QAN(),
    .QB (s_w_12_0_out[11]),
    .QBN(),
    .QC (s_w_12_0_out[10]),
    .QCN(),
    .QD (s_w_12_0_out[9]),
    .QDN(),
    .QE (s_w_12_0_out[8]),
    .QEN(),
    .QF (s_w_12_0_out[7]),
    .QFN(),
    .QG (s_w_12_0_out[6]),
    .QGN(),
    .QH (s_w_12_0_out[5]),
    .QHN()
  );

  L8 WL_LO
  (
    // System Input signals
    .sysclk(sysclk),                          // System clock in FPGA
    .sys_rst_n(sys_rst_n),                    // System reset in FPGA

    // Input signals
    .L  (s_mclk_n),

    .A  (s_rep_12_0[4]),
    .B  (s_rep_12_0[3]),
    .C  (s_rep_12_0[2]),
    .D  (s_rep_12_0[1]),
    .E  (s_rep_12_0[0]),
    .F  (1'b0),
    .G  (1'b0),
    .H  (1'b0),

    // Output signals
    .QA (s_w_12_0_out[4]),
    .QAN(),
    .QB (s_w_12_0_out[3]),
    .QBN(),
    .QC (s_w_12_0_out[2]),
    .QCN(),
    .QD (s_w_12_0_out[1]),
    .QDN(),
    .QE (s_w_12_0_out[0]),
    .QEN(),
    .QF (),
    .QFN(),
    .QG (),
    .QGN(),
    .QH (),
    .QHN()
  );

  //always @(negedge sysclk) begin
  always @(posedge sysclk) begin
    if (!sys_rst_n) begin
        dRep12[12:0] <=0;
    end else begin
        dRep12[12:0] <= s_rep_12_0[12:0];
    end
  end

  wire rptClock;
  assign rptClock = s_mclk;


  CGA_MIC_MASEL_REPEAT MASEL_REPEAT (
      .SC6(SC6),
      .SC5(SC5),
      .IW_12_0(s_iw_12_0_out[12:0]),
      //.MCLK(s_mclk),
      .MCLK(rptClock),
      .MPN(s_mr_n),
      .REP_12_0(s_w_12_0_out)
      //.REP_12_0(s_rep_12_0[12:0])
      //.REP_12_0(dRep12[12:0])
  );
  */

endmodule
