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
    output QHN
);

reg [7:0] reg8bit;

assign QA   = reg8bit[0];
assign QAN  = ~reg8bit[0];

assign QB   = reg8bit[1];
assign QBN  = ~reg8bit[1];

assign QC   = reg8bit[2];
assign QCN  = ~reg8bit[2];

assign QD   = reg8bit[3];
assign QDN  = ~reg8bit[3];

assign QE   = reg8bit[4];
assign QEN  = ~reg8bit[4];

assign QF   = reg8bit[5];
assign QFN  = ~reg8bit[5];

assign QG   = reg8bit[6];
assign QGN  = ~reg8bit[6];

assign QH   = reg8bit[7];
assign QHN  = ~reg8bit[7];


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

endmodule
