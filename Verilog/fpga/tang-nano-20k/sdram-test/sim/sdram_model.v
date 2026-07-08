/****************************************************************************
** Behavioral model of the Tang Nano 20K embedded SDRAM                    **
**                                                                         **
** 64 Mbit SDR: 4 banks x 2K rows x 256 columns x 32 bits, CL=2.           **
** Just enough protocol for the nand2mario controller (sdram.v):           **
** BankActivate, Read/Write with auto-precharge (A10 ignored), byte        **
** masking via DQM, AutoRefresh/ModeReg/Precharge accepted and ignored.    **
**                                                                         **
** Last reviewed: 8-JUL-2026                                               **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module sdram_model (
    input clk,   // SDRAM clock (180 degrees from controller clock)
    input cke,
    input cs_n,
    input ras_n,
    input cas_n,
    input we_n,
    input [10:0] a,
    input [1:0] ba,
    input [3:0] dqm,
    inout [31:0] dq
);

  // {RAS#, CAS#, WE#}
  localparam CMD_MRS = 3'b000;
  localparam CMD_REF = 3'b001;
  localparam CMD_PRE = 3'b010;
  localparam CMD_ACT = 3'b011;
  localparam CMD_WR  = 3'b100;
  localparam CMD_RD  = 3'b101;

  reg [31:0] mem[0:2097151];  // 2M x 32 = 8 MB
  reg [10:0] row[0:3];

  wire [2:0] cmd = {ras_n, cas_n, we_n};
  wire [20:0] idx = {ba, row[ba], a[7:0]};

  // CL=2 read pipeline: data driven between the 2nd and 3rd clock edge
  // after the READ command, exactly one clock wide.
  reg pipe0, pipe1, drv;
  reg [31:0] pdata, ddata;

  assign dq = drv ? ddata : 32'hzzzzzzzz;

  integer i;
  initial begin
    for (i = 0; i < 2097152; i = i + 1) mem[i] = 32'hXXXXXXXX;
    pipe0 = 0;
    pipe1 = 0;
    drv   = 0;
  end

  always @(posedge clk) begin
    pipe0 <= 1'b0;
    pipe1 <= pipe0;
    drv   <= pipe1;
    if (pipe1) ddata <= pdata;

    if (!cs_n && cke) begin
      case (cmd)
        CMD_ACT: row[ba] <= a;
        CMD_WR: begin
          if (!dqm[0]) mem[idx][7:0]   <= dq[7:0];
          if (!dqm[1]) mem[idx][15:8]  <= dq[15:8];
          if (!dqm[2]) mem[idx][23:16] <= dq[23:16];
          if (!dqm[3]) mem[idx][31:24] <= dq[31:24];
        end
        CMD_RD: begin
          pipe0 <= 1'b1;
          pdata <= mem[idx];
        end
        default: ;  // MRS / REF / PRE: accepted, nothing to model
      endcase
    end
  end

endmodule
