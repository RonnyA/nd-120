/******************************************************************************
 **                                                                          **
 ** Component : 74LS374                                                      **
 **                                                                          **
 ** Octal Transparent EDGE-TRIGGERED FLIP-FLOPS with 3-state outputs         **
 **                                                                          **
 ** Documentation: https://www.ti.com/lit/ds/symlink/sn54ls373-sp.pdf        **
 **                                                                          **
 ** Last reviewed: 14-DEC-2024                                               **
 ** Ronny Hansen                                                             **
 *****************************************************************************/

module TTL_74374 (
    input wire        sysclk, // FPGA system clock — used for CK edge detection
    input wire [7:0]  D,      // Data inputs
    input wire        CK,     // Clock input (latches on rising edge of CK)
    input wire        OE_n,   // Output Control (active low)
    output wire [7:0] Q       // Outputs
);
    reg [7:0] Q_reg = 8'b0;

    // Detect rising edge of CK relative to sysclk
    reg CK_d = 1'b0;
    always @(posedge sysclk)
        CK_d <= CK;

    wire CK_pulse = CK & ~CK_d;

    always @(posedge sysclk) begin
        if (CK_pulse)
            Q_reg <= D;
    end

    assign Q = OE_n ? 8'b0 : Q_reg;

endmodule
