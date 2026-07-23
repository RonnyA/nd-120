/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** R41P_EN - R41P (4-bit register, true+complement outputs) with an      **
** optional clock-enable mode.                                           **
**                                                                       **
** USE_ENABLE=0 (default): wraps the original R41P - posedge CP,         **
**   original behaviour (latch mode).                                    **
** USE_ENABLE=1: posedge sysclk, captures when EN is high (P2 clock-     **
**   domain conversion mode - see SCAN_FF_EN.v / the plan doc).          **
**                                                                       **
** Last reviewed: 9-JUL-2026                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module R41P_EN #(
    parameter integer USE_ENABLE = 0
) (
    input sysclk,  //! FPGA system clock (used only when USE_ENABLE=1)
    input EN,      //! Clock enable    (used only when USE_ENABLE=1)

    input CP,      //! Clock (used only when USE_ENABLE=0)

    input A,
    input B,
    input C,
    input D,

    output QA,
    output QAN,
    output QB,
    output QBN,
    output QC,
    output QCN,
    output QD,
    output QDN
);

  generate
    if (USE_ENABLE == 1) begin : gen_enable
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_cp = CP;
      /* verilator lint_on UNUSEDSIGNAL */
      reg [3:0] q_r = 4'b0;
      always @(posedge sysclk) begin
        if (EN) q_r <= {D, C, B, A};
      end
      assign {QA, QB, QC, QD} = {q_r[0], q_r[1], q_r[2], q_r[3]};
      assign {QAN, QBN, QCN, QDN} = {~q_r[0], ~q_r[1], ~q_r[2], ~q_r[3]};
    end else begin : gen_orig
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_sys = sysclk & EN;
      /* verilator lint_on UNUSEDSIGNAL */
      R41P R (
          .CP(CP),
          .A(A), .B(B), .C(C), .D(D),
          .QA(QA), .QAN(QAN), .QB(QB), .QBN(QBN),
          .QC(QC), .QCN(QCN), .QD(QD), .QDN(QDN)
      );
    end
  endgenerate

endmodule
