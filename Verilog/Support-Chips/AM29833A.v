// AM29833A
// PARITY BUS TRANSCEIVERS
// Documentation: https://pdf1.alldatasheet.com/datasheet-pdf/view/165880/AMD/AM29833A.html

// Used on 3202D - Sheet 46 - MEM_DATA

/*
GENERAL DESCRIPTION 
The Am29833A and Am29853A are high-performance parity bus transceivers designed for two-way communications. 
Each device can be used as an 8-bit transceiver, as well as a 9-bit parity checker/generator. 

In the transmit mode, data is read at the R port and output at the T port with a parity bit. 
In the receive mode, data and parity are read at the T port, and the data is output at the R port along with an /ERR flag showing the result of the parity test. 

In the Am29833A, the error flag is clocked and stored in a register which is read at the open-collector ERR out-put. 

The /CLR input is used to clear the error flag register. 

In the Am29853A, a latch replaces this register, and the /EN and /CLR controls are used to pass, store, sample or clear the error flag output.
When both output enables are disabled in the Am29853A and Am29833A, the  parity logic defaults to the transmit mode, so that the ERR pin reflects the parity of the R port. 

The output enables, /OER and /OET, are used to force the port outputs to the high-impedance state so that other devices can drive bus lines directly. 
In addition, the user can force a parity error by enabling both OER and OET simultaneously. 

This transmission of inverted parity gives the designer more system diagnostic capability. 
Each of these devices is produced with AMD's proprietary IMOX bipolar process, and features typical propagation delays of 6 ns, as well as high-capacitive drive capability. 

*/


module AM29833A( input  CLK,
                 input  CLR_n,
                 output ERR_n,
                 input  OER_n,
                 input  OET_n,
                 inout  PAR, // Parity bit
                 inout  R0,
                 inout  R1,
                 inout  R2,
                 inout  R3,
                 inout  R4,
                 inout  R5,
                 inout  R6,
                 inout  R7,
                 inout  T0,
                 inout  T1,
                 inout  T2,
                 inout  T3,
                 inout  T4,
                 inout  T5,
                 inout  T6,
                 inout  T7 
);


reg r_port_reg[7:0];
reg t_port_reg[7:0];

reg error_flag_reg;
reg parity_reg;

// temporary

assign ERR_n = ~error_flag_reg;

// Not complete yer..
always @(*) begin
    if (CLR_n == false) begin
        error_flag_reg <= 1'b0;
        
    end
    else if ( (OET_n == false) && (OER_n == true)) begin // TRANSMIT MODE (Transmits data from R port to T port, generating parity. Receive path is disabled.)
        r_port_reg[0] <= R0;
        r_port_reg[1] <= R1;
        r_port_reg[2] <= R2;
        r_port_reg[3] <= R3;
        r_port_reg[4] <= R4;
        r_port_reg[5] <= R5;
        r_port_reg[6] <= R6;
        r_port_reg[7] <= R7;

        T0 <= r_port_reg[0];
        T1 <= r_port_reg[1];
        T2 <= r_port_reg[2];
        T3 <= r_port_reg[3];
        T4 <= r_port_reg[4];
        T5 <= r_port_reg[5];
        T6 <= r_port_reg[6];
        T7 <= r_port_reg[7];

        
    end
    else if ( (OET_n == true) && (OER_n == false)) begin // RECEIVE MODE (Transmits data drom T port to R port with parity test resulting in error flag. Transmit path is disabled.)
        t_port_reg[0] <= T0;
        t_port_reg[1] <= T1;
        t_port_reg[2] <= T2;
        t_port_reg[3] <= T3;
        t_port_reg[4] <= T4;
        t_port_reg[5] <= T5;
        t_port_reg[6] <= T6;
        t_port_reg[7] <= T7;


        R0 <= t_port_reg[0];
        R1 <= t_port_reg[1];
        R2 <= t_port_reg[2];
        R3 <= t_port_reg[3];
        R4 <= t_port_reg[4];
        R5 <= t_port_reg[5];
        R6 <= t_port_reg[6];
        R7 <= t_port_reg[7];
    end 
    else if ( (OET_n == true) && (OER_n == true)) begin // Both transmitting and receiving paths are disabled

        R0 = 1'bZ;
        R1 = 1'bZ;
        R2 = 1'bZ;
        R3 = 1'bZ;
        R4 = 1'bZ;
        R5 = 1'bZ;
        R6 = 1'bZ;
        R7 = 1'bZ;


        T0 = 1'bZ;
        T1 = 1'bZ;
        T2 = 1'bZ;
        T3 = 1'bZ;
        T4 = 1'bZ;
        T5 = 1'bZ;
        T6 = 1'bZ;
        T7 = 1'bZ;
    end


end




endmodule

