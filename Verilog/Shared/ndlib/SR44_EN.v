/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** SR44_EN - SR44 (4-bit load/shift register) with an optional           **
** clock-enable mode.                                                    **
**                                                                       **
** USE_ENABLE=0 (default): wraps the original SR44 - posedge CP,         **
**   original behaviour.                                                 **
** USE_ENABLE=1: posedge sysclk, updates when EN is high (P2 clock-      **
**   domain conversion mode - see SCAN_FF_EN.v / the plan doc). The      **
**   CP pin is unused in this mode.                                      **
**                                                                       **
** Behaviour (verified against the Multiplexer_2 wiring in SR44.v):      **
**   PLEXERS_1: sel=L, muxIn_1=A,  muxIn_0=SI -> QA d = L ? A : SI       **
**   PLEXERS_2: sel=L, muxIn_1=B,  muxIn_0=QA -> QB d = L ? B : QA       **
**   PLEXERS_3: sel=L, muxIn_1=C,  muxIn_0=QB -> QC d = L ? C : QB       **
**   PLEXERS_4: sel=L, muxIn_1=D,  muxIn_0=QC -> QD d = L ? D : QC       **
**   So: L=1 loads {A,B,C,D} into {QA,QB,QC,QD}; L=0 shifts              **
**   SI -> QA -> QB -> QC -> QD. With q_r[0]=QA .. q_r[3]=QD this is     **
**   q_r <= L ? {D,C,B,A} : {q_r[2:0], SI};                              **
**                                                                       **
** Last reviewed: 10-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module SR44_EN #(
    parameter integer USE_ENABLE = 0
) (
    input sysclk,  //! FPGA system clock (used only when USE_ENABLE=1)
    input EN,      //! Clock enable    (used only when USE_ENABLE=1)

    input CP,      //! Clock (used only when USE_ENABLE=0)

    input A,   //! Parallel load input A
    input B,   //! Parallel load input B
    input C,   //! Parallel load input C
    input D,   //! Parallel load input D
    input L,   //! 1 = load {A,B,C,D}, 0 = shift SI -> QA -> QB -> QC -> QD
    input SI,  //! Serial input

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
      reg [3:0] q_r = 4'b0;  // q_r[0]=QA, q_r[1]=QB, q_r[2]=QC, q_r[3]=QD
      always @(posedge sysclk) begin
        if (EN) q_r <= L ? {D, C, B, A} : {q_r[2:0], SI};
      end
      assign {QA, QB, QC, QD} = {q_r[0], q_r[1], q_r[2], q_r[3]};
      assign {QAN, QBN, QCN, QDN} = {~q_r[0], ~q_r[1], ~q_r[2], ~q_r[3]};
    end else begin : gen_orig
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_sys = sysclk & EN;
      /* verilator lint_on UNUSEDSIGNAL */
      SR44 R (
          .CP(CP),
          .A(A), .B(B), .C(C), .D(D),
          .L(L), .SI(SI),
          .QA(QA), .QAN(QAN), .QB(QB), .QBN(QBN),
          .QC(QC), .QCN(QCN), .QD(QD), .QDN(QDN)
      );
    end
  endgenerate

endmodule
