/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** R81_EN - R81 (8-bit register, true+complement outputs) with an        **
** optional clock-enable mode.                                           **
**                                                                       **
** USE_ENABLE=0 (default): wraps the original R81 - posedge CP,          **
**   original behaviour (latch mode).                                    **
** USE_ENABLE=1: posedge sysclk, captures when EN is high (P2 clock-     **
**   domain conversion mode - see SCAN_FF_EN.v / the plan doc).          **
**                                                                       **
** Last reviewed: 9-JUL-2026                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module R81_EN #(
    parameter integer USE_ENABLE = 0
) (
    input sysclk,  //! FPGA system clock (used only when USE_ENABLE=1)
    input EN,      //! Clock enable    (used only when USE_ENABLE=1)

    input CP,      //! Clock (used only when USE_ENABLE=0)

    input A,
    input B,
    input C,
    input D,
    input E,
    input F,
    input G,
    input H,

    output QA,
    output QAN,
    output QB,
    output QBN,
    output QC,
    output QCN,
    output QD,
    output QDN,
    output QE,
    output QEN,
    output QF,
    output QFN,
    output QG,
    output QGN,
    output QH,
    output QHN
);

  generate
    if (USE_ENABLE == 1) begin : gen_enable
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_cp = CP;
      /* verilator lint_on UNUSEDSIGNAL */
      reg [7:0] q_r = 8'b0;
      always @(posedge sysclk) begin
        if (EN) q_r <= {H, G, F, E, D, C, B, A};
      end
      assign {QA, QB, QC, QD, QE, QF, QG, QH} =
             {q_r[0], q_r[1], q_r[2], q_r[3], q_r[4], q_r[5], q_r[6], q_r[7]};
      assign {QAN, QBN, QCN, QDN, QEN, QFN, QGN, QHN} =
             {~q_r[0], ~q_r[1], ~q_r[2], ~q_r[3], ~q_r[4], ~q_r[5], ~q_r[6], ~q_r[7]};
    end else begin : gen_orig
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_sys = sysclk & EN;
      /* verilator lint_on UNUSEDSIGNAL */
      R81 R (
          .CP(CP),
          .A(A), .B(B), .C(C), .D(D), .E(E), .F(F), .G(G), .H(H),
          .QA(QA), .QAN(QAN), .QB(QB), .QBN(QBN),
          .QC(QC), .QCN(QCN), .QD(QD), .QDN(QDN),
          .QE(QE), .QEN(QEN), .QF(QF), .QFN(QFN),
          .QG(QG), .QGN(QGN), .QH(QH), .QHN(QHN)
      );
    end
  endgenerate

endmodule
