/****************************************************************************
** Status message printer for the SD-FAT test                              **
**                                                                         **
** Streams one of a set of fixed ASCII status lines through an external    **
** uart_tx (shared with hex_dumper, muxed by the top level). Same byte     **
** pump pattern as sdram-test/src/msg_printer.v.                           **
**                                                                         **
** NOTE: \r is not a legal Verilog string escape - CR must be octal \015.  **
**                                                                         **
** Last reviewed: 10-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/

module status_printer (
    input clk,
    input rst_n,

    input       start,  // 1-cycle pulse; only when busy=0
    input [4:0] msg,    // MSG_* selector, latched at start
    output      busy,   // high until the whole message has left the UART

    // handshake to the shared uart_tx (top level muxes this with hex_dumper)
    output reg [7:0] tx_data,
    output reg       tx_valid,
    input            tx_busy
);

  // Message selectors (top level uses the same values)
  localparam MSG_BANNER       = 5'd0;
  localparam MSG_CARD_SDV1    = 5'd1;
  localparam MSG_CARD_SDV2    = 5'd2;
  localparam MSG_CARD_SDHC    = 5'd3;
  localparam MSG_FS_FAT16     = 5'd4;
  localparam MSG_FS_FAT32     = 5'd5;
  localparam MSG_FS_UNKNOWN   = 5'd6;
  localparam MSG_FILE_FOUND   = 5'd7;
  localparam MSG_FILE_NOTFND  = 5'd8;
  localparam MSG_ERR_CARD_TO  = 5'd9;
  localparam MSG_ERR_SCAN_TO  = 5'd10;
  localparam MSG_ERR_TRUNC    = 5'd11;
  localparam MSG_MENU         = 5'd12;
  localparam MSG_NOTIMPL      = 5'd13;
  localparam MSG_SD_NOTCHK    = 5'd14;  // menu SD status line (14 + status code)
  localparam MSG_SD_NOCARD    = 5'd15;
  localparam MSG_SD_ERROR     = 5'd16;
  localparam MSG_SD_OK        = 5'd17;
  localparam MSG_COPYING      = 5'd18;
  localparam MSG_COPY_DONE    = 5'd19;
  localparam MSG_ERR_NOTGT    = 5'd20;
  localparam MSG_ERR_SMALL    = 5'd21;
  localparam MSG_ERR_WRITE    = 5'd22;
  localparam MSG_BLK_WRITING  = 5'd23;
  localparam MSG_BLK_DONE     = 5'd24;
  localparam MSG_ERR_RANGE    = 5'd25;
  localparam MSG_HELP1        = 5'd26;
  localparam MSG_HELP2        = 5'd27;
  localparam MSG_HELP3        = 5'd28;
  localparam MSG_HELP4        = 5'd29;

  // Fixed strings (longest is 55 chars; strchar window is 64)
  localparam S_BANNER      = "\015\012SD-FAT TEST 10-JUL-2026\015\012";
  localparam S_CARD_SDV1   = "CARD: SDV1\015\012";
  localparam S_CARD_SDV2   = "CARD: SDV2\015\012";
  localparam S_CARD_SDHC   = "CARD: SDHC\015\012";
  localparam S_FS_FAT16    = "FS: FAT16\015\012";
  localparam S_FS_FAT32    = "FS: FAT32\015\012";
  localparam S_FS_UNKNOWN  = "FS: UNKNOWN\015\012";
  localparam S_FILE_FOUND  = "FILE: FOUND\015\012";
  localparam S_FILE_NOTFND = "FILE: NOT FOUND\015\012";
  localparam S_ERR_CARD_TO = "ERROR: CARD INIT TIMEOUT\015\012";
  localparam S_ERR_SCAN_TO = "ERROR: FS SCAN TIMEOUT\015\012";
  localparam S_ERR_TRUNC   = "ERROR: FILE TRUNCATED TO BUFFER\015\012";
  localparam S_MENU        = "\015\0121=LIST 2=DUMP 3=COPY 4=WRBLK1 H=HELP\015\012# ";
  localparam S_NOTIMPL     = "NOT IMPLEMENTED\015\012";
  localparam S_SD_NOTCHK   = "SD: NOT CHECKED\015\012";
  localparam S_SD_NOCARD   = "SD: NO CARD\015\012";
  localparam S_SD_ERROR    = "SD: ERROR\015\012";
  localparam S_SD_OK       = "SD: OK\015\012";
  localparam S_COPYING     = "COPYING BOOT.BPUN TO TEST.TXT\015\012";
  localparam S_COPY_DONE   = "COPY DONE\015\012";
  localparam S_ERR_NOTGT   = "ERROR: TEST.TXT NOT ON CARD\015\012";
  localparam S_ERR_SMALL   = "ERROR: TEST.TXT TOO SMALL\015\012";
  localparam S_ERR_WRITE   = "ERROR: SD WRITE FAILED\015\012";
  localparam S_BLK_WRITING = "WRITING PATTERN TO 1KW BLOCK 1\015\012";
  localparam S_BLK_DONE    = "BLOCK 1 UPDATED\015\012";
  localparam S_ERR_RANGE   = "ERROR: BLOCK OUT OF RANGE\015\012";
  localparam S_HELP1       = "1 = LIST ROOT DIR (SIZE, DATE, NAME)\015\012";
  localparam S_HELP2       = "2 = DUMP BOOT.BPUN AS HEX + OCTAL WORDS\015\012";
  localparam S_HELP3       = "3 = COPY BOOT.BPUN OVER TEST.TXT (IN PLACE)\015\012";
  localparam S_HELP4       = "4 = WRITE WORDS 0-1023 TO 1KW BLOCK 1 OF BOOT.BPUN\015\012";

  // pick character idx (0-based) out of a string literal; 0 terminates
  function [7:0] strchar(input [8*64-1:0] s, input integer len, input integer i);
    strchar = (i < len) ? s[8*(len-1-i)+:8] : 8'h00;
  endfunction

  reg [4:0] msg_r;
  reg [5:0] idx;

  reg [7:0] ch;
  always @(*) begin
    case (msg_r)
      MSG_BANNER:      ch = strchar({8'b0, S_BANNER}, $bits(S_BANNER)/8, idx);
      MSG_CARD_SDV1:   ch = strchar({8'b0, S_CARD_SDV1}, $bits(S_CARD_SDV1)/8, idx);
      MSG_CARD_SDV2:   ch = strchar({8'b0, S_CARD_SDV2}, $bits(S_CARD_SDV2)/8, idx);
      MSG_CARD_SDHC:   ch = strchar({8'b0, S_CARD_SDHC}, $bits(S_CARD_SDHC)/8, idx);
      MSG_FS_FAT16:    ch = strchar({8'b0, S_FS_FAT16}, $bits(S_FS_FAT16)/8, idx);
      MSG_FS_FAT32:    ch = strchar({8'b0, S_FS_FAT32}, $bits(S_FS_FAT32)/8, idx);
      MSG_FS_UNKNOWN:  ch = strchar({8'b0, S_FS_UNKNOWN}, $bits(S_FS_UNKNOWN)/8, idx);
      MSG_FILE_FOUND:  ch = strchar({8'b0, S_FILE_FOUND}, $bits(S_FILE_FOUND)/8, idx);
      MSG_FILE_NOTFND: ch = strchar({8'b0, S_FILE_NOTFND}, $bits(S_FILE_NOTFND)/8, idx);
      MSG_ERR_CARD_TO: ch = strchar({8'b0, S_ERR_CARD_TO}, $bits(S_ERR_CARD_TO)/8, idx);
      MSG_ERR_SCAN_TO: ch = strchar({8'b0, S_ERR_SCAN_TO}, $bits(S_ERR_SCAN_TO)/8, idx);
      MSG_ERR_TRUNC:   ch = strchar({8'b0, S_ERR_TRUNC}, $bits(S_ERR_TRUNC)/8, idx);
      MSG_MENU:        ch = strchar({8'b0, S_MENU}, $bits(S_MENU)/8, idx);
      MSG_NOTIMPL:     ch = strchar({8'b0, S_NOTIMPL}, $bits(S_NOTIMPL)/8, idx);
      MSG_SD_NOTCHK:   ch = strchar({8'b0, S_SD_NOTCHK}, $bits(S_SD_NOTCHK)/8, idx);
      MSG_SD_NOCARD:   ch = strchar({8'b0, S_SD_NOCARD}, $bits(S_SD_NOCARD)/8, idx);
      MSG_SD_ERROR:    ch = strchar({8'b0, S_SD_ERROR}, $bits(S_SD_ERROR)/8, idx);
      MSG_SD_OK:       ch = strchar({8'b0, S_SD_OK}, $bits(S_SD_OK)/8, idx);
      MSG_COPYING:     ch = strchar({8'b0, S_COPYING}, $bits(S_COPYING)/8, idx);
      MSG_COPY_DONE:   ch = strchar({8'b0, S_COPY_DONE}, $bits(S_COPY_DONE)/8, idx);
      MSG_ERR_NOTGT:   ch = strchar({8'b0, S_ERR_NOTGT}, $bits(S_ERR_NOTGT)/8, idx);
      MSG_ERR_SMALL:   ch = strchar({8'b0, S_ERR_SMALL}, $bits(S_ERR_SMALL)/8, idx);
      MSG_ERR_WRITE:   ch = strchar({8'b0, S_ERR_WRITE}, $bits(S_ERR_WRITE)/8, idx);
      MSG_BLK_WRITING: ch = strchar({8'b0, S_BLK_WRITING}, $bits(S_BLK_WRITING)/8, idx);
      MSG_BLK_DONE:    ch = strchar({8'b0, S_BLK_DONE}, $bits(S_BLK_DONE)/8, idx);
      MSG_ERR_RANGE:   ch = strchar({8'b0, S_ERR_RANGE}, $bits(S_ERR_RANGE)/8, idx);
      MSG_HELP1:       ch = strchar({8'b0, S_HELP1}, $bits(S_HELP1)/8, idx);
      MSG_HELP2:       ch = strchar({8'b0, S_HELP2}, $bits(S_HELP2)/8, idx);
      MSG_HELP3:       ch = strchar({8'b0, S_HELP3}, $bits(S_HELP3)/8, idx);
      MSG_HELP4:       ch = strchar({8'b0, S_HELP4}, $bits(S_HELP4)/8, idx);
      default:         ch = 8'h00;
    endcase
  end

  // Byte pump: hand ch to uart_tx, one handshake per character
  localparam P_IDLE = 2'd0;
  localparam P_SEND = 2'd1;
  localparam P_GAP  = 2'd2;  // one cycle for tx_busy to assert

  reg [1:0] pstate;

  assign busy = (pstate != P_IDLE);

  always @(posedge clk) begin
    if (!rst_n) begin
      pstate   <= P_IDLE;
      tx_valid <= 1'b0;
      tx_data  <= 0;
      idx      <= 0;
      msg_r    <= MSG_BANNER;
    end else begin
      tx_valid <= 1'b0;
      case (pstate)
        P_IDLE:
        if (start) begin
          msg_r  <= msg;
          idx    <= 0;
          pstate <= P_SEND;
        end
        P_SEND:
        if (ch == 8'h00) begin
          pstate <= P_IDLE;
        end else if (!tx_busy) begin
          tx_valid <= 1'b1;
          tx_data  <= ch;
          idx      <= idx + 1;
          pstate   <= P_GAP;
        end
        P_GAP: pstate <= P_SEND;
        default: pstate <= P_IDLE;
      endcase
    end
  end

endmodule
