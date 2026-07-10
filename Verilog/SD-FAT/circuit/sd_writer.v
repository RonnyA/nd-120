/****************************************************************************
** SD single-sector writer (CMD24, SD-native 1-bit mode)                   **
**                                                                         **
** Writes one 512-byte sector to an ALREADY-INITIALIZED card: the reader   **
** (sd_reader.v) must have brought the card into the transfer state with   **
** 512-byte block length before this module is used; the top level then    **
** muxes the SD pins from the reader to this writer. Written for the       **
** ND-120 project "copy file in place" path (SD-FAT/README.md, Route B):   **
** rewriting the data sectors of a pre-created contiguous file needs no    **
** FAT metadata updates.                                                   **
**                                                                         **
** Protocol per SD Physical Layer Simplified Spec (single block write):    **
**   CMD24(sector) -> R1 -> Nwr gap -> DAT0: start(0) + 4096 data bits     **
**   MSB-first + CRC16-CCITT + end(1) -> card CRC status token on DAT0     **
**   (start 0, "010" = accepted, end 1) -> card busy (DAT0 low) -> ready.  **
**                                                                         **
** No tristates here (repo rule): the CMD/DAT0 drivers are exposed as      **
** _o/_oe pairs and the single tristate lives at the board top level.      **
**                                                                         **
** This file is ORIGINAL ND-120 project code (MIT, like the repository);   **
** it is intentionally independent of the vendored GPL SD reader.          **
**                                                                         **
** Sector data is fetched through a registered read port (1-clk latency); **
** the SD bit clock is many system clocks long, so the fetch pipeline is   **
** trivially satisfied.                                                    **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/

module sd_writer #(
    parameter [7:0]  CLKDIV       = 8'd5,        // sdclk = clk / (2*CLKDIV); 27 MHz / 10 = 2.7 MHz
    parameter [31:0] BUSY_TIMEOUT = 32'd2_700_000 // sdclk cycles of busy before err (~1 s at 2.7 MHz)
) (
    input wire clk,
    input wire rst_n,

    // SD pins (muxed onto the card at the top level while writing)
    output reg  sd_clk_o,
    input  wire sd_cmd_i,
    output reg  sd_cmd_o,
    output reg  sd_cmd_oe,
    input  wire sd_dat0_i,
    output reg  sd_dat0_o,
    output reg  sd_dat0_oe,

    // command interface
    input  wire        start,   // 1-cycle pulse; only when busy=0
    input  wire [31:0] sector,  // SDHC sector number (CMD24 argument)
    output wire        busy,
    output reg         done,    // 1-cycle pulse: sector written and card ready
    output reg         err,     // 1-cycle pulse: timeout or CRC status rejected

    // sector data source (registered read port, 1-clk latency)
    output reg [8:0]  rd_addr,  // byte 0..511 of the sector
    input  wire [7:0] rd_data
);

  function [6:0] crc7_step(input [6:0] c, input b);
    crc7_step = {c[5:0], 1'b0} ^ (7'h09 & {7{c[6] ^ b}});
  endfunction

  function [15:0] crc16_step(input [15:0] c, input b);
    crc16_step = {c[14:0], 1'b0} ^ (16'h1021 & {16{c[15] ^ b}});
  endfunction

  // ------------------------------------------------------------- bit clock
  reg [7:0] divcnt;
  wire tick = (divcnt == CLKDIV - 8'd1);  // one system-clock pulse per sdclk half-period
  wire fall_tick = tick && sd_clk_o;      // next edge will be falling: change outputs
  wire rise_tick = tick && !sd_clk_o;     // next edge will be rising: sample inputs

  // ------------------------------------------------------------- FSM
  localparam W_IDLE    = 4'd0;
  localparam W_CMD     = 4'd1;   // shift out the 48-bit CMD24
  localparam W_R1WAIT  = 4'd2;   // wait for the response start bit
  localparam W_R1      = 4'd3;   // skip the rest of the 48-bit R1
  localparam W_GAP     = 4'd4;   // Nwr gap before the data block
  localparam W_DSTART  = 4'd5;   // data start bit
  localparam W_DATA    = 4'd6;   // 4096 data bits
  localparam W_CRC     = 4'd7;   // 16 CRC bits
  localparam W_DEND    = 4'd8;   // end bit, then release DAT0
  localparam W_CSWAIT  = 4'd9;   // wait for the CRC status start bit
  localparam W_CS      = 4'd10;  // 3 status bits + end bit
  localparam W_BUSY    = 4'd11;  // card holds DAT0 low while programming
  localparam W_DONE    = 4'd12;
  localparam W_ERR     = 4'd13;

  reg [3:0]  state;
  reg [47:0] cmdreg;
  reg [6:0]  crc7;
  reg [15:0] crc16;
  reg [12:0] bitcnt;
  reg [7:0]  shreg;
  reg [31:0] toctr;
  reg [3:0]  csbits;

  assign busy = (state != W_IDLE);

  always @(posedge clk) begin
    if (!rst_n) begin
      state      <= W_IDLE;
      divcnt     <= 0;
      sd_clk_o   <= 1'b0;
      sd_cmd_o   <= 1'b1;
      sd_cmd_oe  <= 1'b0;
      sd_dat0_o  <= 1'b1;
      sd_dat0_oe <= 1'b0;
      done       <= 1'b0;
      err        <= 1'b0;
      rd_addr    <= 0;
      cmdreg     <= 0;
      crc7       <= 0;
      crc16      <= 0;
      bitcnt     <= 0;
      shreg      <= 0;
      toctr      <= 0;
      csbits     <= 0;
    end else begin
      done <= 1'b0;
      err  <= 1'b0;

      if (state == W_IDLE) begin
        divcnt     <= 0;
        sd_clk_o   <= 1'b0;
        sd_cmd_oe  <= 1'b0;
        sd_dat0_oe <= 1'b0;
        if (start) begin
          // 48-bit command: start(0) host(1) index(6) arg(32) crc7 end(1);
          // CRC7 is accumulated while shifting (over the first 40 bits)
          cmdreg  <= {2'b01, 6'd24, sector, 7'b0000000, 1'b1};
          crc7    <= 0;
          bitcnt  <= 0;
          rd_addr <= 0;
          state   <= W_CMD;
        end
      end else begin
        // free-running bit clock while active
        divcnt <= tick ? 8'd0 : divcnt + 8'd1;
        if (tick) sd_clk_o <= ~sd_clk_o;

        case (state)
          // ---- command phase --------------------------------------------
          W_CMD:
          if (fall_tick) begin
            if (bitcnt < 13'd40) begin
              sd_cmd_oe <= 1'b1;
              sd_cmd_o  <= cmdreg[47];
              crc7      <= crc7_step(crc7, cmdreg[47]);
              cmdreg    <= {cmdreg[46:0], 1'b1};
            end else if (bitcnt < 13'd47) begin
              sd_cmd_o <= crc7[6];  // the 7 CRC bits
              crc7     <= {crc7[5:0], 1'b0};
            end else begin
              sd_cmd_o <= 1'b1;     // end bit
            end
            if (bitcnt == 13'd47) begin
              bitcnt <= 0;
              toctr  <= 0;
              state  <= W_R1WAIT;
            end else bitcnt <= bitcnt + 13'd1;
          end

          W_R1WAIT: begin
            if (fall_tick) sd_cmd_oe <= 1'b0;  // release CMD after the end bit
            if (rise_tick && !sd_cmd_oe) begin
              if (sd_cmd_i == 1'b0) begin
                bitcnt <= 0;
                state  <= W_R1;
              end else if (toctr == 32'd500) state <= W_ERR;
              else toctr <= toctr + 1;
            end
          end

          W_R1:  // skip the remaining 47 bits of the R1 response
          if (rise_tick) begin
            if (bitcnt == 13'd46) begin
              bitcnt <= 0;
              state  <= W_GAP;
            end else bitcnt <= bitcnt + 13'd1;
          end

          // ---- data block ------------------------------------------------
          W_GAP:  // Nwr >= 2 clocks; use 8
          if (fall_tick) begin
            if (bitcnt == 13'd7) begin
              bitcnt <= 0;
              state  <= W_DSTART;
            end else bitcnt <= bitcnt + 13'd1;
          end

          W_DSTART:
          if (fall_tick) begin
            sd_dat0_oe <= 1'b1;
            sd_dat0_o  <= 1'b0;    // data start bit
            shreg      <= rd_data; // byte 0 (rd_addr has been 0 long enough)
            rd_addr    <= 9'd1;
            crc16      <= 0;
            bitcnt     <= 0;
            state      <= W_DATA;
          end

          W_DATA:
          if (fall_tick) begin
            sd_dat0_o <= shreg[7];
            crc16     <= crc16_step(crc16, shreg[7]);
            if (bitcnt[2:0] == 3'd7) begin
              shreg   <= rd_data;             // next byte (fetched 8 ticks ago)
              rd_addr <= rd_addr + 9'd1;
            end else shreg <= {shreg[6:0], 1'b0};
            if (bitcnt == 13'd4095) begin
              bitcnt <= 0;
              state  <= W_CRC;
            end else bitcnt <= bitcnt + 13'd1;
          end

          W_CRC:
          if (fall_tick) begin
            sd_dat0_o <= crc16[15];
            crc16     <= {crc16[14:0], 1'b0};
            if (bitcnt == 13'd15) begin
              bitcnt <= 0;
              state  <= W_DEND;
            end else bitcnt <= bitcnt + 13'd1;
          end

          W_DEND:
          if (fall_tick) begin
            if (bitcnt == 13'd0) begin
              sd_dat0_o <= 1'b1;  // end bit
              bitcnt    <= 13'd1;
            end else begin
              sd_dat0_oe <= 1'b0;  // release DAT0 to the card
              toctr      <= 0;
              bitcnt     <= 0;
              state      <= W_CSWAIT;
            end
          end

          // ---- CRC status + busy ----------------------------------------
          W_CSWAIT:
          if (rise_tick) begin
            if (sd_dat0_i == 1'b0) begin  // status token start bit
              bitcnt <= 0;
              csbits <= 0;
              state  <= W_CS;
            end else if (toctr == 32'd500) state <= W_ERR;
            else toctr <= toctr + 1;
          end

          W_CS:  // 3 status bits, then the token end bit
          if (rise_tick) begin
            if (bitcnt == 13'd3) begin
              // csbits[2:0] holds the 3 status bits; this sample is the end
              // bit. "010" = data accepted; anything else = CRC/write error.
              toctr <= 0;
              state <= (csbits[2:0] == 3'b010) ? W_BUSY : W_ERR;
            end else begin
              csbits <= {csbits[2:0], sd_dat0_i};
              bitcnt <= bitcnt + 13'd1;
            end
          end

          W_BUSY:
          if (rise_tick) begin
            if (sd_dat0_i == 1'b1) state <= W_DONE;  // programming finished
            else if (toctr == BUSY_TIMEOUT) state <= W_ERR;
            else toctr <= toctr + 1;
          end

          W_DONE: begin
            done  <= 1'b1;
            state <= W_IDLE;
          end

          W_ERR: begin
            err   <= 1'b1;
            state <= W_IDLE;
          end

          default: state <= W_IDLE;
        endcase
      end
    end
  end

endmodule
