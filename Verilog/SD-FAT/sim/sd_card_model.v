/****************************************************************************
** Behavioral SD card model (native 1-bit mode) for the SD-FAT test        **
**                                                                         **
** Serves sectors from a raw filesystem image file ($fread at time 0).     **
** Implements what the SD-FAT library needs:                               **
**   CMD0 (no response), CMD8 (R7), CMD55+ACMD41 (R1/R3, reports SDHC),    **
**   CMD2 (R2/CID), CMD3 (R6), CMD7 (R1), CMD16 (R1),                      **
**   CMD17 (R1 + 512-byte read block on DAT0, CRC16 appended),             **
**   CMD24 (R1 + receive a 512-byte write block on DAT0, CRC16 checked,    **
**          CRC status token + busy; the sector lands in the image)        **
** Anything else gets no response (the host times out and retries).        **
**                                                                         **
** Timing contract with sdcmd_ctrl.v: the host drives CMD on the falling   **
** edge of sd_clk and samples on the rising edge; this model does the      **
** mirror image (samples on rising, drives on falling). Response starts    **
** NCR = 4 clocks after the command end (host timeout is 250 clocks).      **
**                                                                         **
** The model checks the CRC7 of received commands and counts mismatches    **
** in crc_errors (testbench should require it to stay 0).                  **
**                                                                         **
** Simulation only - never synthesize.                                     **
**                                                                         **
** Last reviewed: 10-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module sd_card_model #(
    parameter IMAGE     = "fat16.img",
    parameter MAX_BYTES = 8 * 1024 * 1024
) (
    input  sd_clk,
    inout  sd_cmd,   // needs a pullup() in the testbench
    inout  sd_dat0   // needs a pullup() in the testbench (bidir since CMD24)
);

  reg [7:0] mem[0:MAX_BYTES-1];
  integer img_bytes;

  integer crc_errors;
  initial crc_errors = 0;

  initial begin : load_image
    integer fd;
    fd = $fopen(IMAGE, "rb");
    if (fd == 0) begin
      $display("sd_card_model: FATAL cannot open image %s", IMAGE);
      $finish;
    end
    img_bytes = $fread(mem, fd);
    $fclose(fd);
    $display("sd_card_model: loaded %0d bytes from %s", img_bytes, IMAGE);
  end

  // ------------------------------------------------------------- CMD pin
  reg cmd_drive;
  reg cmd_out;
  initial {cmd_drive, cmd_out} = 2'b01;
  assign sd_cmd = cmd_drive ? cmd_out : 1'bz;

  // ------------------------------------------------------------- DAT0 pin
  // driven only while the card sources data (read block, CRC status, busy)
  reg dat_out, dat_oe;
  initial {dat_out, dat_oe} = 2'b10;
  assign sd_dat0 = dat_oe ? dat_out : 1'bz;

  // ------------------------------------------------------------- CRC helpers
  function [6:0] crc7_step(input [6:0] crc, input b);
    crc7_step = {crc[5:0], 1'b0} ^ (7'h09 & {7{crc[6] ^ b}});
  endfunction

  function [15:0] crc16_step(input [15:0] crc, input b);
    crc16_step = {crc[14:0], 1'b0} ^ (16'h1021 & {16{crc[15] ^ b}});
  endfunction

  // CRC7 over an arbitrary-length MSB-first bit vector (up to 40 bits used)
  function [6:0] crc7_of40(input [39:0] bits);
    integer k;
    reg [6:0] c;
    begin
      c = 7'd0;
      for (k = 39; k >= 0; k = k - 1) c = crc7_step(c, bits[k]);
      crc7_of40 = c;
    end
  endfunction

  // ------------------------------------------------------------- engine
  reg [47:0] req;
  reg [5:0] cmd;
  reg [31:0] arg;
  reg app_cmd;
  initial app_cmd = 1'b0;

  reg [135:0] resp;
  integer resp_len;
  reg do_data, do_write;
  reg [31:0] data_base;

  // send one 512-byte sector + CRC16 on DAT0, MSB first
  task send_block(input [31:0] base);
    integer i, b;
    reg [15:0] crc;
    reg bitv;
    begin
      repeat (8) @(negedge sd_clk);
      @(negedge sd_clk) begin
        dat_oe  <= 1'b1;
        dat_out <= 1'b0;  // start bit
      end
      crc = 16'd0;
      for (i = 0; i < 512; i = i + 1) begin
        for (b = 7; b >= 0; b = b - 1) begin
          bitv = (base + i < MAX_BYTES) ? mem[base+i][b] : 1'b1;
          @(negedge sd_clk) dat_out <= bitv;
          crc  = crc16_step(crc, bitv);
        end
      end
      for (i = 15; i >= 0; i = i - 1) @(negedge sd_clk) dat_out <= crc[i];
      @(negedge sd_clk) dat_out <= 1'b1;  // end bit
      @(negedge sd_clk) dat_oe <= 1'b0;   // release DAT0
    end
  endtask

  // receive one 512-byte write block on DAT0 (CMD24), answer the CRC
  // status token and hold busy for a while; the data lands in the image
  integer wr_crc_errors;
  initial wr_crc_errors = 0;

  task recv_block_body(input [31:0] base);
    integer i, b;
    reg [15:0] crc, crc_host;
    reg [7:0] byt;
    begin
      crc = 16'd0;
      for (i = 0; i < 512; i = i + 1) begin
        byt = 8'h00;
        for (b = 7; b >= 0; b = b - 1) begin
          @(posedge sd_clk);
          byt[b] = sd_dat0;
          crc = crc16_step(crc, sd_dat0);
        end
        if (base + i < MAX_BYTES) mem[base+i] = byt;
      end
      crc_host = 16'd0;
      for (i = 15; i >= 0; i = i - 1) begin
        @(posedge sd_clk);
        crc_host[i] = sd_dat0;
      end
      if (crc_host !== crc) begin
        wr_crc_errors = wr_crc_errors + 1;
        $display("sd_card_model: CMD24 data CRC16 mismatch at %0t", $time);
      end
      @(posedge sd_clk);  // host end bit

      // CRC status token "010" + end bit, then busy for 64 clocks
      repeat (2) @(negedge sd_clk);
      @(negedge sd_clk) begin dat_oe <= 1'b1; dat_out <= 1'b0; end  // start
      @(negedge sd_clk) dat_out <= 1'b0;  // s2
      @(negedge sd_clk) dat_out <= 1'b1;  // s1
      @(negedge sd_clk) dat_out <= 1'b0;  // s0  -> "010" = accepted
      @(negedge sd_clk) dat_out <= 1'b1;  // token end bit
      @(negedge sd_clk) dat_out <= 1'b0;  // busy...
      repeat (63) @(negedge sd_clk);
      @(negedge sd_clk) dat_out <= 1'b1;  // ready
      @(negedge sd_clk) dat_oe <= 1'b0;   // release DAT0
    end
  endtask

  // build a 48-bit response with a correct CRC7 (the host ignores it, but
  // an honest model catches host-side regressions)
  function [47:0] r48(input [5:0] rcmd, input [31:0] rarg);
    reg [39:0] head;
    begin
      head = {2'b00, rcmd, rarg};
      r48  = {head, crc7_of40(head), 1'b1};
    end
  endfunction

  always begin : engine
    integer i;
    reg [6:0] crc_calc;
    // hunt for a command start bit on a rising edge
    @(posedge sd_clk);
    if (sd_cmd === 1'b0) begin
      req[47] = 1'b0;
      for (i = 46; i >= 0; i = i - 1) begin
        @(posedge sd_clk);
        req[i] = sd_cmd;
      end
      cmd = req[45:40];
      arg = req[39:8];

      // verify CRC7 over the first 40 bits
      crc_calc = crc7_of40(req[47:8]);
      if ({crc_calc, 1'b1} !== req[7:0]) begin
        crc_errors = crc_errors + 1;
        $display("sd_card_model: CMD%0d CRC7 MISMATCH (got %02x, want %02x) at %0t",
                 cmd, req[7:0], {crc_calc, 1'b1}, $time);
      end

      // decode
      resp_len = 0;
      do_data  = 1'b0;
      do_write = 1'b0;
      case (cmd)
        6'd0: app_cmd = 1'b0;  // GO_IDLE: no response
        6'd8: begin  // SEND_IF_COND -> R7, echo the check pattern
          resp[135:88] = r48(6'd8, 32'h000001AA);
          resp_len = 48;
        end
        6'd55: begin  // APP_CMD -> R1
          resp[135:88] = r48(6'd55, 32'h00000120);
          resp_len = 48;
          app_cmd  = 1'b1;
        end
        6'd41: begin  // ACMD41 -> R3: ready, CCS=1 (SDHC), reserved cmd field
          if (app_cmd) begin
            resp[135:88] = {2'b00, 6'b111111, 32'hC0FF8000, 7'b1111111, 1'b1};
            resp_len = 48;
          end
          app_cmd = 1'b0;
        end
        6'd2: begin  // ALL_SEND_CID -> R2 (136 bits, reserved cmd field)
          resp = {2'b00, 6'b111111, 120'h4E44313230_53444D4F44454C_012345, 7'b1010101, 1'b1};
          resp_len = 136;
        end
        6'd3: begin  // SEND_RELATIVE_ADDR -> R6: RCA=0x0001, status 0x0500
          resp[135:88] = r48(6'd3, {16'h0001, 16'h0500});
          resp_len = 48;
        end
        6'd7: begin  // SELECT_CARD -> R1
          resp[135:88] = r48(6'd7, 32'h00000700);
          resp_len = 48;
        end
        6'd16: begin  // SET_BLOCKLEN -> R1
          resp[135:88] = r48(6'd16, 32'h00000900);
          resp_len = 48;
        end
        6'd17: begin  // READ_SINGLE_BLOCK -> R1 + data block (SDHC: arg = sector)
          resp[135:88] = r48(6'd17, 32'h00000900);
          resp_len  = 48;
          do_data   = 1'b1;
          data_base = arg * 512;
        end
        6'd24: begin  // WRITE_BLOCK -> R1 + receive a data block (SDHC: arg = sector)
          resp[135:88] = r48(6'd24, 32'h00000900);
          resp_len  = 48;
          do_write  = 1'b1;
          data_base = arg * 512;
        end
        default: ;  // no response -> host times out
      endcase

      // respond: NCR = 4 clocks, then MSB-first on falling edges
      if (resp_len > 0) begin
        repeat (4) @(negedge sd_clk);
        for (i = 0; i < resp_len; i = i + 1) begin
          @(negedge sd_clk);
          cmd_drive <= 1'b1;
          cmd_out   <= resp[135-i];
        end
        @(negedge sd_clk);
        cmd_drive <= 1'b0;
        cmd_out   <= 1'b1;
      end

      if (do_data) send_block(data_base);
      if (do_write) begin
        // wait for the host's data start bit (with a timeout), then receive
        begin : wr_wait
          integer guard;
          guard = 0;
          while (guard >= 0) begin
            @(posedge sd_clk);
            if (sd_dat0 === 1'b0) guard = -1;  // start bit seen
            else if (guard > 5000) begin
              $display("sd_card_model: CMD24 data start-bit timeout at %0t", $time);
              guard = -2;
            end else guard = guard + 1;
          end
          if (guard == -1) recv_block_body(data_base);
        end
      end
    end
  end

endmodule
