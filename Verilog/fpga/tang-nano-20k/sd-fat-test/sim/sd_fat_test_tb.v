/****************************************************************************
** System testbench for the SD-FAT test (iverilog)                         **
**                                                                         **
** Full stack: sd_fat_test_top + behavioral SD card model serving a real   **
** FAT16 image (fat16.img, built by make_test_image.sh with mkfs.vfat +    **
** mcopy, containing payload.bin as BOOT.BPUN).                            **
**                                                                         **
** Drives the UART menu like a terminal user:                              **
**   - waits for the banner and menu prompt                                **
**   - sends '2' (DUMP): checks CARD:/FS: FAT16/FILE: FOUND, parses the    **
**     hex dump lines back into bytes and compares them (and the LENGTH    **
**     line) against payload.bin                                           **
**   - sends '1' (LIST): checks size columns, the <DIR> HDD entry and      **
**     the BOOT.BPUN / TEST.TXT names                                      **
**   - sends '3' (COPY): waits for COPY DONE (content equality is          **
**     verified by the Verilator twin, test_sd_fat.cpp)                    **
**                                                                         **
** Runs at a fast simulation baud rate (the BAUD parameter exists for      **
** exactly this). Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>      **
**                                                                         **
** Last reviewed: 10-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module sd_fat_test_tb;

  localparam CLK_HALF = 18.5;       // ~27 MHz
  localparam SIM_BAUD = 1_000_000;  // fast sim baud
  localparam DELAY_FRAMES = 27_000_000 / SIM_BAUD;

  reg clk = 0;
  always #CLK_HALF clk = ~clk;

  // ------------------------------------------------------------- DUT
  reg  s1 = 0;
  wire uart_rxp;
  wire uart_txp;
  wire sd_clk;
  wire sd_cmd;
  wire sd_dat0;
  wire sd_dat1, sd_dat2, sd_dat3;
  wire [5:0] led;

  pullup (sd_cmd);
  pullup (sd_dat0);

  sd_fat_test_top #(
      .CLK_FREQ(27_000_000),
      .BAUD    (SIM_BAUD),
      .SIMULATE(1),
      .WD_MAX  (32'd27_000_000)  // 1 s watchdog is plenty in sim
  ) dut (
      .sys_clk (clk),
      .s1      (s1),
      .uart_rxp(uart_rxp),
      .uart_txp(uart_txp),
      .sd_clk  (sd_clk),
      .sd_cmd  (sd_cmd),
      .sd_dat0 (sd_dat0),
      .sd_dat1 (sd_dat1),
      .sd_dat2 (sd_dat2),
      .sd_dat3 (sd_dat3),
      .led     (led)
  );

  sd_card_model #(
      .IMAGE("fat16.img"),
      .MAX_BYTES(8 * 1024 * 1024)
  ) card (
      .sd_clk (sd_clk),
      .sd_cmd (sd_cmd),
      .sd_dat0(sd_dat0)
  );

  // ------------------------------------------------------------- payload
  reg [7:0] payload[0:65535];
  integer pl_len;
  initial begin : load_payload
    integer fd;
    fd = $fopen("payload.bin", "rb");
    if (fd == 0) begin
      $display("TB_RESULT: FAIL cannot open payload.bin (run make_test_image.sh)");
      $finish;
    end
    pl_len = $fread(payload, fd);
    $fclose(fd);
    $display("tb: payload.bin = %0d bytes", pl_len);
  end

  // ------------------------------------------------------------- UART in/out
  reg [7:0] tx_key;
  reg tx_key_valid = 0;
  wire tx_key_busy;

  uart_tx #(
      .DELAY_FRAMES(DELAY_FRAMES)
  ) u_keys (
      .clk(clk),
      .rst_n(1'b1),
      .tx_data(tx_key),
      .tx_valid(tx_key_valid),
      .tx_busy(tx_key_busy),
      .txd(uart_rxp)
  );

  wire [7:0] rx_data;
  wire rx_valid;
  uart_rx #(
      .DELAY_FRAMES(DELAY_FRAMES)
  ) u_cap (
      .clk(clk),
      .rst_n(1'b1),
      .rxd(uart_txp),
      .rx_data(rx_data),
      .rx_valid(rx_valid)
  );

  // capture everything; also echo per line for debugging
  localparam CAPMAX = 1 << 19;
  reg [7:0] cap[0:CAPMAX-1];
  integer cap_len = 0;

  reg [8*120-1:0] lbuf;
  integer lpos = 0;
  always @(posedge clk)
    if (rx_valid) begin
      cap[cap_len] = rx_data;
      cap_len = cap_len + 1;
      if (rx_data == 8'h0A) begin
        $display("uart| %0s", lbuf);
        lbuf = 0;
        lpos = 0;
      end else if (rx_data != 8'h0D && lpos < 118) begin
        lbuf = {lbuf[8*119-1:0], rx_data};
        lpos = lpos + 1;
      end
    end

  // ------------------------------------------------------------- helpers
  task send_key(input [7:0] c);
    begin
      wait (!tx_key_busy);
      @(posedge clk);
      tx_key <= c;
      tx_key_valid <= 1;
      @(posedge clk);
      tx_key_valid <= 0;
      @(posedge clk);
    end
  endtask

  // wait until the last two captured chars are "# " (menu prompt printed)
  task wait_prompt;
    begin
      while (!(cap_len >= 2 && cap[cap_len-1] == " " && cap[cap_len-2] == "#"))
        @(posedge clk);
    end
  endtask

  // search cap[from..cap_len) for an ASCII pattern; returns index after
  // the match or -1
  function integer find_str(input integer from, input [8*32-1:0] pat, input integer plen);
    integer i, j;
    reg hit;
    begin
      find_str = -1;
      for (i = from; i <= cap_len - plen; i = i + 1) begin
        if (find_str == -1) begin
          hit = 1;
          for (j = 0; j < plen; j = j + 1)
            if (cap[i+j] !== pat[8*(plen-1-j)+:8]) hit = 0;
          if (hit) find_str = i + plen;
        end
      end
    end
  endfunction

  function [3:0] hexval(input [7:0] c);
    begin
      if (c >= "0" && c <= "9") hexval = c - "0";
      else if (c >= "A" && c <= "F") hexval = c - "A" + 10;
      else hexval = 4'hF;
    end
  endfunction

  function is_hex(input [7:0] c);
    is_hex = (c >= "0" && c <= "9") || (c >= "A" && c <= "F");
  endfunction

  // ------------------------------------------------------------- checks
  integer errors = 0;

  task expect_str(input integer from, input [8*32-1:0] pat, input integer plen,
                  input [8*32-1:0] what);
    begin
      if (find_str(from, pat, plen) == -1) begin
        $display("FAIL: missing '%0s' in UART output", what);
        errors = errors + 1;
      end
    end
  endtask

  // parse dump lines in cap[from..cap_len): "OOOOOO: HH HH ...", rebuild
  // the byte stream, compare with payload
  reg [7:0] dmp[0:65535];
  integer dmp_len;

  task check_dump(input integer from);
    integer i, k, offs, nb;
    reg [23:0] o;
    begin
      dmp_len = 0;
      i = from;
      while (i < cap_len - 8) begin
        // line start: 6 hex chars, ':', ' '
        if (is_hex(cap[i]) && is_hex(cap[i+1]) && is_hex(cap[i+2]) && is_hex(cap[i+3]) &&
            is_hex(cap[i+4]) && is_hex(cap[i+5]) && cap[i+6] == ":" && cap[i+7] == " " &&
            (i == 0 || cap[i-1] == 8'h0A)) begin
          o = 0;
          for (k = 0; k < 6; k = k + 1) o = {o[19:0], hexval(cap[i+k])};
          offs = o;
          i = i + 8;
          // byte pairs until CR
          while (i + 1 < cap_len && is_hex(cap[i]) && is_hex(cap[i+1])) begin
            dmp[offs] = {hexval(cap[i]), hexval(cap[i+1])};
            if (offs + 1 > dmp_len) dmp_len = offs + 1;
            offs = offs + 1;
            i = i + 2;
            while (i < cap_len && cap[i] == " ") i = i + 1;  // 1 or 2 spaces
          end
        end else i = i + 1;
      end

      if (dmp_len !== pl_len) begin
        $display("FAIL: dump length %0d != payload length %0d", dmp_len, pl_len);
        errors = errors + 1;
      end
      nb = 0;
      for (k = 0; k < pl_len && k < dmp_len; k = k + 1)
        if (dmp[k] !== payload[k]) begin
          if (nb < 10) $display("FAIL: dump byte %0d: got %02x want %02x", k, dmp[k], payload[k]);
          nb = nb + 1;
        end
      if (nb != 0) begin
        $display("FAIL: %0d dump byte mismatches", nb);
        errors = errors + 1;
      end
    end
  endtask

  // check the "LENGTH: NNNNNNNNNNNN BYTES" line matches pl_len
  task check_length(input integer from);
    integer p, k;
    integer v;
    begin
      p = find_str(from, "LENGTH: ", 8);
      if (p == -1) begin
        $display("FAIL: no LENGTH line");
        errors = errors + 1;
      end else begin
        v = 0;
        for (k = 0; k < 12; k = k + 1) v = v * 10 + (cap[p+k] - "0");
        if (v !== pl_len) begin
          $display("FAIL: LENGTH %0d != payload %0d", v, pl_len);
          errors = errors + 1;
        end
      end
    end
  endtask

  // ------------------------------------------------------------- run
  integer t0, t_dump, t_list;
  integer guard;

  initial begin : run
    // 0. banner + first menu prompt (SD status must be NOT CHECKED)
    wait_prompt;
    $display("tb: menu prompt seen");
    expect_str(0, "SD: NOT CHECKED", 15, "SD: NOT CHECKED at boot");

    // 1. DUMP command
    t_dump = cap_len;
    send_key("2");
    guard = 0;
    while (find_str(t_dump, "DONE", 4) == -1 && guard < 400_000_000) begin
      @(posedge clk);
      guard = guard + 1;
    end
    if (find_str(t_dump, "DONE", 4) == -1) begin
      $display("TB_RESULT: FAIL dump never finished (timeout)");
      $finish;
    end
    wait_prompt;

    expect_str(t_dump, "CARD: SDHC", 10, "CARD: SDHC");
    expect_str(t_dump, "SD: OK", 6, "SD: OK in menu after dump");
    expect_str(t_dump, "FS: FAT16", 9, "FS: FAT16");
    expect_str(t_dump, "FILE: FOUND", 11, "FILE: FOUND");
    check_dump(find_str(t_dump, "FILE: FOUND", 11));
    check_length(t_dump);

    // 2. LIST command
    t_list = cap_len;
    send_key("1");
    guard = 0;
    // list ends with the next menu prompt
    while (!(cap_len > t_list + 2 && cap[cap_len-1] == " " && cap[cap_len-2] == "#") &&
           guard < 400_000_000) begin
      @(posedge clk);
      guard = guard + 1;
    end
    expect_str(t_list, "BOOT.BPUN", 9, "BOOT.BPUN in LIST");
    expect_str(t_list, "TEST.TXT", 8, "TEST.TXT in LIST");
    expect_str(t_list, "      2342  ", 12, "size column in LIST");
    expect_str(t_list, "     <DIR>  ", 12, "<DIR> entry in LIST");
    expect_str(t_list, "HDD", 3, "HDD directory in LIST");

    // 3. COPY BOOT.BPUN -> TEST.TXT (CMD24 in-place rewrite)
    t0 = cap_len;
    send_key("3");
    guard = 0;
    while (find_str(t0, "COPY DONE", 9) == -1 && guard < 400_000_000 &&
           find_str(t0, "ERROR", 5) == -1) begin
      @(posedge clk);
      guard = guard + 1;
    end
    if (find_str(t0, "COPY DONE", 9) == -1) begin
      $display("FAIL: no COPY DONE for key 3");
      errors = errors + 1;
    end

    // 3b. WRBLK1: pattern into 1KW block 1 (content checked by the
    // Verilator twin; here we prove the command completes)
    t0 = cap_len;
    send_key("4");
    guard = 0;
    while (find_str(t0, "BLOCK 1 UPDATED", 15) == -1 && guard < 400_000_000 &&
           find_str(t0, "ERROR", 5) == -1) begin
      @(posedge clk);
      guard = guard + 1;
    end
    if (find_str(t0, "BLOCK 1 UPDATED", 15) == -1) begin
      $display("FAIL: no BLOCK 1 UPDATED for key 4");
      errors = errors + 1;
    end

    // 4. card-model CRC sanity (commands and the written data block)
    if (card.crc_errors != 0) begin
      $display("FAIL: %0d CRC7 errors on the SD command line", card.crc_errors);
      errors = errors + 1;
    end
    if (card.wr_crc_errors != 0) begin
      $display("FAIL: %0d CRC16 errors on the CMD24 data block", card.wr_crc_errors);
      errors = errors + 1;
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  // absolute watchdog
  initial begin
    #2_000_000_000;  // 2 s sim time
    $display("TB_RESULT: FAIL absolute watchdog");
    $finish;
  end

endmodule
