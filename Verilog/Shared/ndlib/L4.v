/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component L4 (4-bit latch)                                            **
**                                                                       **
** Last reviewed: 9-FEB-2025                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module L4 (
    // System input signals
    input sysclk,    // System clock in FPGA
    input sys_rst_n, // System reset in FPGA

    input L, //! LATCH ENABLE

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

reg [3:0] reg4bit;

`ifdef USE_TRANSPARENT_LATCHES
assign QA=reg4bit[0]; assign QAN=~reg4bit[0];
assign QB=reg4bit[1]; assign QBN=~reg4bit[1];
assign QC=reg4bit[2]; assign QCN=~reg4bit[2];
assign QD=reg4bit[3]; assign QDN=~reg4bit[3];
`else
// FPGA: synthesizable transparent latch = mux + FF (Q follows input while L high)
wire q_a = L ? A : reg4bit[0]; assign QA=q_a; assign QAN=~q_a;
wire q_b = L ? B : reg4bit[1]; assign QB=q_b; assign QBN=~q_b;
wire q_c = L ? C : reg4bit[2]; assign QC=q_c; assign QCN=~q_c;
wire q_d = L ? D : reg4bit[3]; assign QD=q_d; assign QDN=~q_d;
`endif



`ifdef USE_TRANSPARENT_LATCHES
always @(*) begin
    if (L) begin
        reg4bit[0] = A;
        reg4bit[1] = B;
        reg4bit[2] = C;
        reg4bit[3] = D;
    end
end
`else
always @(posedge sysclk) begin
    if (L) begin
        reg4bit[0] <= A;
        reg4bit[1] <= B;
        reg4bit[2] <= C;
        reg4bit[3] <= D;
    end
end
`endif

endmodule
