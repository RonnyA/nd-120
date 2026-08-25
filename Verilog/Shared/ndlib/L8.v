/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component L8 (8-bit latch)                                            **
**                                                                       **
** Last reviewed: 9-FEB-2025                                             **
** Ronny Hansen                                                          **
***************************************************************************/


module L8 (
    // System input signals
    input sysclk,    // System clock in FPGA
    input sys_rst_n, // System reset in FPGA


    input L, //! LATCH ENABLE

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
    output QHN,

    // Registered-value taps (21-AUG-2026): the stored value WITHOUT the
    // FF-mode transparent bypass mux (L ? D : reg). Combinational-loop cut
    // for IDB readback paths - see CGA_MAC_SEGPT_PCR. In latch mode reg8bit
    // updates combinationally while L is high, so the tap equals the
    // transparent output there; only FF mode behaves differently (the tap
    // lags the bypass by one sysclk during the load window). Leave
    // unconnected everywhere the transparent output is the wanted one.
    output QA_R,
    output QB_R,
    output QC_R,
    output QD_R,
    output QE_R,
    output QF_R,
    output QG_R,
    output QH_R
);

reg [7:0] reg8bit;

assign {QA_R, QB_R, QC_R, QD_R, QE_R, QF_R, QG_R, QH_R} =
       {reg8bit[0], reg8bit[1], reg8bit[2], reg8bit[3],
        reg8bit[4], reg8bit[5], reg8bit[6], reg8bit[7]};

`ifdef USE_TRANSPARENT_LATCHES
assign QA=reg8bit[0]; assign QAN=~reg8bit[0];
assign QB=reg8bit[1]; assign QBN=~reg8bit[1];
assign QC=reg8bit[2]; assign QCN=~reg8bit[2];
assign QD=reg8bit[3]; assign QDN=~reg8bit[3];
assign QE=reg8bit[4]; assign QEN=~reg8bit[4];
assign QF=reg8bit[5]; assign QFN=~reg8bit[5];
assign QG=reg8bit[6]; assign QGN=~reg8bit[6];
assign QH=reg8bit[7]; assign QHN=~reg8bit[7];
`else
// FPGA: synthesizable transparent latch = mux + FF (Q follows input while L high)
wire q_a = L ? A : reg8bit[0]; assign QA=q_a; assign QAN=~q_a;
wire q_b = L ? B : reg8bit[1]; assign QB=q_b; assign QBN=~q_b;
wire q_c = L ? C : reg8bit[2]; assign QC=q_c; assign QCN=~q_c;
wire q_d = L ? D : reg8bit[3]; assign QD=q_d; assign QDN=~q_d;
wire q_e = L ? E : reg8bit[4]; assign QE=q_e; assign QEN=~q_e;
wire q_f = L ? F : reg8bit[5]; assign QF=q_f; assign QFN=~q_f;
wire q_g = L ? G : reg8bit[6]; assign QG=q_g; assign QGN=~q_g;
wire q_h = L ? H : reg8bit[7]; assign QH=q_h; assign QHN=~q_h;
`endif


`ifdef USE_TRANSPARENT_LATCHES
always @(*) begin
    if (L) begin
        reg8bit[0] = A;
        reg8bit[1] = B;
        reg8bit[2] = C;
        reg8bit[3] = D;
        reg8bit[4] = E;
        reg8bit[5] = F;
        reg8bit[6] = G;
        reg8bit[7] = H;
    end
end
`else
always @(posedge sysclk) begin
    if (L) begin
        reg8bit[0] <= A;
        reg8bit[1] <= B;
        reg8bit[2] <= C;
        reg8bit[3] <= D;
        reg8bit[4] <= E;
        reg8bit[5] <= F;
        reg8bit[6] <= G;
        reg8bit[7] <= H;
    end
end
`endif

endmodule
