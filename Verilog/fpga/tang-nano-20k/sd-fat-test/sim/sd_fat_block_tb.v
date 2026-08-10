/****************************************************************************
** Streaming-dump testbench for the SD-FAT test tool (iverilog)             **
**                                                                         **
** Covers the diagnostic commands that exist because a 75 MB disc image on  **
** a card could not be inspected at all: the buffered dump (menu 2) stops   **
** at 64 KB, so nothing could tell "the FAT points somewhere wrong" from    **
** "the card really holds zeros there".                                     **
**                                                                         **
**   read-only build   the menu must NOT offer 3/4 and both must answer     **
**                     NOT IMPLEMENTED (default config, see                 **
**                     ../src/sd_fat_test_config.vh)                        **
**   N                 set the target file name from the console            **
**   8  BLOCK          dump 1KW block 100 of BIG.BPUN - byte 204800 of a    **
**                     327680-byte file, i.e. FAR past the 64 KB buffer.    **
**                     Every byte is checked against the image pattern      **
**                     (big-endian word w of the file holds w mod 65536),   **
**                     so a read from the wrong sector cannot pass.         **
**   1  LIST           the new column must carry the file's first ABSOLUTE  **
**                     sector, and it must agree with the sector the block  **
**                     command reported (first + 4*100)                     **
**   9  SECTOR         dumping that same absolute sector by number, with    **
**                     the FAT bypassed, must return the same 512 bytes     **
**   R  RANGE          70 CONSECUTIVE blocks (280 sectors, 143360 bytes)    **
**                     read as one run: the reported block count, sector    **
**                     count and word checksum must all match what this     **
**                     bench computes from the image model, and the run     **
**                     must end RESULT: PASS. That is the case SINTRAN      **
**                     segment handling exercises and nothing here had      **
**                     ever covered - every earlier check read ONE block.   **
**                     A second run with an INJECTED card read failure      **
**                     must stop early, name the failing sector and block   **
**                     and end RESULT: FAIL.                                **
**                                                                         **
** Card: blockdump.img, built by make_block_image.sh (mkfs.vfat + mcopy).   **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                      **
**                                                                         **
** Last reviewed: 10-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module sd_fat_block_tb;

  localparam CLK_HALF = 18.5;       // ~27 MHz
  localparam SIM_BAUD = 1_000_000;  // fast sim baud (BAUD exists for this)
  localparam DELAY_FRAMES = 27_000_000 / SIM_BAUD;

  localparam BLOCK_NO   = 100;      // the block under test
  localparam BLOCK_BYTES = 2048;    // 1024 x 16-bit words = 4 SD sectors
  localparam BLOCK_WORDS = 1024;

  // RANGE run: 70 consecutive blocks = 280 SD sectors = 143360 bytes,
  // starting at block 7 so the run is NOT aligned with the start of the
  // file. (7 + 70) * 2048 = 157696 bytes, inside the 327680-byte file.
  // 70 and not 64: the progress line is printed AFTER a completed 64-block
  // group, so a run of exactly 64 blocks would finish without one and the
  // progress path would go untested. Longer runs cost iverilog minutes and
  // prove nothing further - the loop is identical for every block.
  localparam RNG_START = 7;
  localparam RNG_CNT   = 70;

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

  // real tristate nets on purpose: the DUT is a board top with genuine
  // bidirectional pads (same rationale as sd_fat_test_tb.v)
  pullup (sd_cmd);
  pullup (sd_dat0);
  pullup (sd_dat1);
  pullup (sd_dat2);
  pullup (sd_dat3);

  wire cm_cmd_o, cm_cmd_oe, cm_dat0_o, cm_dat0_oe;
  wire cm_dat1_o, cm_dat1_oe, cm_dat2_o, cm_dat2_oe, cm_dat3_o, cm_dat3_oe;
  assign sd_cmd  = cm_cmd_oe  ? cm_cmd_o  : 1'bz;
  assign sd_dat0 = cm_dat0_oe ? cm_dat0_o : 1'bz;
  assign sd_dat1 = cm_dat1_oe ? cm_dat1_o : 1'bz;
  assign sd_dat2 = cm_dat2_oe ? cm_dat2_o : 1'bz;
  assign sd_dat3 = cm_dat3_oe ? cm_dat3_o : 1'bz;

  sd_fat_test_top #(
      .CLK_FREQ(27_000_000),
      .BAUD    (SIM_BAUD),
      .SIMULATE(1),
      .WD_MAX  (32'd27_000_000)  // 1 s watchdog is plenty in sim
  ) dut (
      .sys_clk (clk),
      .s1      (s1),
      .s2      (1'b0),
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

  // LEGAL_MIN_SECTOR = the whole address space: the card model then counts
  // EVERY CMD24 / CMD25 block as an illegal write. That is the read-only
  // gate - a build that cannot write must not put a write command on the
  // bus, and this counts them at the wire, not in the menu logic.
  sd_card_model #(
      .IMAGE("blockdump.img"),
      .MAX_BYTES(8 * 1024 * 1024),
      .LEGAL_MIN_SECTOR(32'hFFFFFFFF)
  ) card (
      .sd_clk   (sd_clk),
      .sd_cmd_i (sd_cmd),  .sd_cmd_o (cm_cmd_o),  .sd_cmd_oe (cm_cmd_oe),
      .sd_dat0_i(sd_dat0), .sd_dat0_o(cm_dat0_o), .sd_dat0_oe(cm_dat0_oe),
      .sd_dat1_i(sd_dat1), .sd_dat1_o(cm_dat1_o), .sd_dat1_oe(cm_dat1_oe),
      .sd_dat2_i(sd_dat2), .sd_dat2_o(cm_dat2_o), .sd_dat2_oe(cm_dat2_oe),
      .sd_dat3_i(sd_dat3), .sd_dat3_o(cm_dat3_o), .sd_dat3_oe(cm_dat3_oe)
  );

  // bus contention is always an error (12-JUL-2026 silicon failure class)
  always @(posedge sd_clk) begin
    if ((card.dat_oe && dut.s_dat0_pad_oe) ||
        (card.datx_oe && (dut.s_dat1_pad_oe || dut.s_dat2_pad_oe ||
                          dut.s_dat3_pad_oe)) ||
        (card.cmd_drive && dut.cmd_oe)) begin
      $display("TB_RESULT: FAIL bus contention at %0t", $time);
      $finish;
    end
  end

  // ------------------------------------------------------------- UART
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
  integer errors = 0;

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

  // search cap[from..cap_len) for an ASCII pattern; index after the match, or -1
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

  // Wait until a pattern appears (polled, not per-clock: find_str is a
  // linear scan and the capture grows into the tens of kilobytes).
  //
  // When the pattern is a PROMPT that is about to be answered, wait for the
  // WHOLE prompt. The design reads the console only while it is in its
  // number/name entry state, and it gets there after the last character of
  // the prompt has gone out; a key sent earlier is simply lost (the UART has
  // no receive buffer). Matching a prompt's first word deadlocked this bench
  // once already - see the same warning for real operators in README.md.
  task wait_str(input integer from, input [8*32-1:0] pat, input integer plen,
                input [8*32-1:0] what);
    integer guard;
    begin
      guard = 0;
      while (find_str(from, pat, plen) == -1 && guard < 100_000) begin
        repeat (4096) @(posedge clk);
        guard = guard + 1;
      end
      if (find_str(from, pat, plen) == -1) begin
        $display("TB_RESULT: FAIL timeout waiting for '%0s'", what);
        $finish;
      end
    end
  endtask

  task expect_str(input integer from, input [8*32-1:0] pat, input integer plen,
                  input [8*32-1:0] what);
    begin
      if (find_str(from, pat, plen) == -1) begin
        $display("FAIL: missing '%0s' in UART output", what);
        errors = errors + 1;
      end
    end
  endtask

  task expect_absent(input integer from, input [8*32-1:0] pat, input integer plen,
                     input [8*32-1:0] what);
    begin
      if (find_str(from, pat, plen) != -1) begin
        $display("FAIL: '%0s' present in a READ-ONLY build", what);
        errors = errors + 1;
      end
    end
  endtask

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

  // the image's content model, independent of the design: 16-bit big-endian
  // word w of the file holds w mod 65536 (make_block_image.sh)
  function [7:0] img_byte(input integer off);
    reg [15:0] w;
    begin
      w = (off / 2) % 65536;
      img_byte = ((off % 2) != 0) ? w[7:0] : w[15:8];
    end
  endfunction

  // the expected RANGE checksum, computed the same way the design must:
  // rotate the accumulator left by one bit per word, then add the word
  function [15:0] img_cksum(input integer start_blk, input integer nblk);
    integer w, first, last;
    reg [15:0] s, word;
    begin
      s = 16'd0;
      first = start_blk * BLOCK_WORDS;
      last  = first + nblk * BLOCK_WORDS;
      for (w = first; w < last; w = w + 1) begin
        word = w % 65536;
        s = {s[14:0], s[15]} + word;
      end
      img_cksum = s;
    end
  endfunction

  // type a decimal number on the console, most significant digit first
  task send_dec(input integer v);
    integer d, p, started;
    begin
      p = 1000000000;
      started = 0;
      while (p > 0) begin
        d = (v / p) % 10;
        if (d != 0 || started || p == 1) begin
          started = 1;
          send_key("0" + d[7:0]);
        end
        p = p / 10;
      end
    end
  endtask

  // parse "OOOOOO: HH HH ..." lines in cap[from..cap_len) back into bytes
  reg [7:0] dmp[0:4095];
  integer dmp_len;

  task parse_dump(input integer from);
    integer i, k, offs;
    reg [23:0] o;
    begin
      dmp_len = 0;
      for (k = 0; k < 4096; k = k + 1) dmp[k] = 8'hXX;
      i = from;
      while (i < cap_len - 8) begin
        if (is_hex(cap[i]) && is_hex(cap[i+1]) && is_hex(cap[i+2]) && is_hex(cap[i+3]) &&
            is_hex(cap[i+4]) && is_hex(cap[i+5]) && cap[i+6] == ":" && cap[i+7] == " " &&
            (i == 0 || cap[i-1] == 8'h0A)) begin
          o = 0;
          for (k = 0; k < 6; k = k + 1) o = {o[19:0], hexval(cap[i+k])};
          offs = o;
          i = i + 8;
          while (i + 1 < cap_len && is_hex(cap[i]) && is_hex(cap[i+1])) begin
            if (offs < 4096) dmp[offs] = {hexval(cap[i]), hexval(cap[i+1])};
            if (offs + 1 > dmp_len) dmp_len = offs + 1;
            offs = offs + 1;
            i = i + 2;
            while (i < cap_len && cap[i] == " ") i = i + 1;  // 1 or 2 spaces
          end
        end else i = i + 1;
      end
    end
  endtask

  // ------------------------------------------------------------- run
  integer t0, p, k, nbad;
  integer at_sec, first_sec;
  reg [8*16-1:0] decstr;

  initial begin : run
    // ---------------------------------------------------------------- 0
    wait_str(0, "# ", 2, "menu prompt");
    $display("tb: menu prompt seen");

    // Task 1 gate: the read-only build must not OFFER the writing commands
    expect_str(0, "8=BLOCK", 7, "8=BLOCK in the menu");
    expect_str(0, "9=SECTOR", 8, "9=SECTOR in the menu");
    expect_str(0, "N=NAME", 6, "N=NAME in the menu");
    expect_absent(0, "3=COPY", 6, "3=COPY");
    expect_absent(0, "4=WRBLK1", 8, "4=WRBLK1");
    expect_absent(0, "6=WS", 4, "6=WS");

    // the help text: the new commands must be described, the absent ones
    // must not be (their strings are empty in this build), and the whole
    // sequence must walk from message 1 to 12 across the code gap
    t0 = cap_len;
    send_key("H");
    wait_str(t0, "# ", 2, "prompt after help");
    expect_str(t0, "1 = LIST", 8, "help line for LIST");
    expect_str(t0, "8 = DUMP", 8, "help line for BLOCK");
    expect_str(t0, "9 = DUMP", 8, "help line for SECTOR");
    expect_str(t0, "N = SET FILE NAME", 17, "help line for NAME");
    expect_str(t0, "LIST COLUMN 4", 13, "help line for the sector column");
    expect_absent(t0, "3 = COPY", 8, "help line for COPY");
    expect_absent(t0, "6 = WRITE SPEED", 15, "help line for WRITE SPEED");

    // ...and must refuse them when they are typed anyway
    t0 = cap_len;
    send_key("3");
    wait_str(t0, "NOT IMPLEMENTED", 15, "NOT IMPLEMENTED for key 3");
    wait_str(t0, "# ", 2, "prompt after key 3");
    t0 = cap_len;
    send_key("4");
    wait_str(t0, "NOT IMPLEMENTED", 15, "NOT IMPLEMENTED for key 4");
    wait_str(t0, "# ", 2, "prompt after key 4");

    // ---------------------------------------------------------------- N
    // runtime file name: BIG.BPUN is 327680 bytes - five times the buffer
    t0 = cap_len;
    send_key("N");
    wait_str(t0, "THEN CR: ", 9, "file name prompt");
    send_key("B"); send_key("I"); send_key("G"); send_key(".");
    send_key("B"); send_key("P"); send_key("U"); send_key("N");
    send_key(8'h0D);
    wait_str(t0, "FILE NAME SET", 13, "FILE NAME SET");
    wait_str(t0, "# ", 2, "prompt after the name entry");

    // ---------------------------------------------------------------- 8
    t0 = cap_len;
    send_key("8");
    wait_str(t0, "THEN CR: ", 9, "block number prompt");
    send_dec(BLOCK_NO);
    send_key(8'h0D);
    wait_str(t0, "DONE", 4, "block dump DONE");
    wait_str(t0, "# ", 2, "prompt after the block dump");

    if (find_str(t0, "ERROR", 5) != -1) begin
      $display("FAIL: block dump reported an error");
      errors = errors + 1;
    end
    expect_str(t0, "FILE: FOUND", 11, "FILE: FOUND for BIG.BPUN");
    expect_str(t0, "LENGTH: 000000002048 BYTES", 26, "2048-byte dump length");

    // the sector the tool says it read
    p = find_str(t0, "AT SECTOR ", 10);
    if (p == -1) begin
      $display("TB_RESULT: FAIL no 'AT SECTOR' line for the block dump");
      $finish;
    end
    at_sec = 0;
    for (k = 0; k < 8; k = k + 1) at_sec = at_sec * 16 + hexval(cap[p+k]);
    $display("tb: block %0d reported at absolute sector %0d", BLOCK_NO, at_sec);

    // every byte must match the image pattern: byte j of block b = b + j
    parse_dump(t0);
    if (dmp_len != BLOCK_BYTES) begin
      $display("FAIL: block dump produced %0d bytes, expected %0d", dmp_len, BLOCK_BYTES);
      errors = errors + 1;
    end
    nbad = 0;
    for (k = 0; k < BLOCK_BYTES && k < dmp_len; k = k + 1)
      if (dmp[k] !== img_byte(BLOCK_NO * BLOCK_BYTES + k)) begin
        if (nbad < 8)
          $display("FAIL: block byte %0d: got %02x want %02x", k, dmp[k],
                   img_byte(BLOCK_NO * BLOCK_BYTES + k));
        nbad = nbad + 1;
      end
    if (nbad != 0) begin
      $display("FAIL: %0d wrong bytes in the block dump", nbad);
      errors = errors + 1;
    end

    // ---------------------------------------------------------------- 8b
    // a block that starts past the end of the file must be REFUSED: those
    // sectors belong to another file. Block 1000 needs 2050048 bytes; the
    // file has 327680. (This also exercises the 40-bit range arithmetic -
    // the same expression in 32 bits wraps for large block numbers.)
    t0 = cap_len;
    send_key("8");
    wait_str(t0, "THEN CR: ", 9, "block number prompt");
    send_dec(1000);
    send_key(8'h0D);
    wait_str(t0, "# ", 2, "prompt after the out-of-range block");
    expect_str(t0, "ERROR: BLOCK OUT OF RANGE", 25, "out-of-range refusal");

    // ---------------------------------------------------------------- 1
    // LIST must publish the file's first ABSOLUTE sector, and it must be
    // the sector the block command used minus 4 sectors per block
    first_sec = at_sec - 4 * BLOCK_NO;
    $display("tb: expecting LIST to show first sector %0d for BIG.BPUN", first_sec);
    t0 = cap_len;
    send_key("1");
    wait_str(t0, "BIG.BPUN", 8, "BIG.BPUN in LIST");
    wait_str(t0, "# ", 2, "prompt after LIST");
    expect_str(t0, " SPC ", 5, "sectors-per-cluster in the LIST info line");
    expect_str(t0, " DBASE ", 7, "data base sector in the LIST info line");

    // The column is right-aligned in 10 characters and followed by two
    // spaces, so " <digits>  " identifies it without a full line parser.
    begin : chk_list_col
      integer q, ok, d, nz, v;
      ok = 0;
      nz = 0;              // index of the most significant digit
      v = first_sec;
      while (v >= 10) begin
        v = v / 10;
        nz = nz + 1;
      end
      decstr = 0;
      v = first_sec;
      for (k = 0; k <= nz; k = k + 1) begin
        decstr[8*k+:8] = "0" + (v % 10);  // byte k = k-th least significant
        v = v / 10;
      end
      for (q = t0; q < cap_len - 16; q = q + 1) begin
        if (ok == 0 && cap[q] == " ") begin
          d = 1;
          for (k = 0; k <= nz; k = k + 1)
            if (cap[q+1+k] !== decstr[8*(nz-k)+:8]) d = 0;
          if (d && cap[q+nz+2] == " " && cap[q+nz+3] == " ") ok = 1;
        end
      end
      if (!ok) begin
        $display("FAIL: LIST does not show %0d as an absolute-sector column", first_sec);
        errors = errors + 1;
      end
    end

    // ---------------------------------------------------------------- 9
    // the same sector by absolute number, FAT not consulted: the first 512
    // bytes of the block must come back identical
    t0 = cap_len;
    send_key("9");
    wait_str(t0, "THEN CR: ", 9, "sector number prompt");
    send_dec(at_sec);
    send_key(8'h0D);
    wait_str(t0, "DONE", 4, "sector dump DONE");
    wait_str(t0, "# ", 2, "prompt after the sector dump");

    if (find_str(t0, "ERROR", 5) != -1) begin
      $display("FAIL: sector dump reported an error");
      errors = errors + 1;
    end
    expect_str(t0, "LENGTH: 000000000512 BYTES", 26, "512-byte dump length");

    parse_dump(t0);
    if (dmp_len != 512) begin
      $display("FAIL: sector dump produced %0d bytes, expected 512", dmp_len);
      errors = errors + 1;
    end
    nbad = 0;
    for (k = 0; k < 512 && k < dmp_len; k = k + 1)
      if (dmp[k] !== img_byte(BLOCK_NO * BLOCK_BYTES + k)) begin
        if (nbad < 8)
          $display("FAIL: sector byte %0d: got %02x want %02x", k, dmp[k],
                   img_byte(BLOCK_NO * BLOCK_BYTES + k));
        nbad = nbad + 1;
      end
    if (nbad != 0) begin
      $display("FAIL: %0d wrong bytes in the sector dump", nbad);
      errors = errors + 1;
    end

    // ---------------------------------------------------------------- R
    // The long consecutive run: 100 blocks = 400 sectors in one command.
    t0 = cap_len;
    send_key("R");
    wait_str(t0, "START BLOCK, DECIMAL, THEN CR: ", 31, "start block prompt");
    send_dec(RNG_START);
    send_key(8'h0D);
    wait_str(t0, "BLOCK COUNT, DECIMAL, THEN CR: ", 31, "block count prompt");
    send_dec(RNG_CNT);
    send_key(8'h0D);
    wait_str(t0, "RESULT:", 7, "range summary");
    wait_str(t0, "# ", 2, "prompt after the range read");

    expect_str(t0, "RESULT: PASS", 12, "range run PASS");
    if (find_str(t0, "ERROR", 5) != -1) begin
      $display("FAIL: range read reported an error");
      errors = errors + 1;
    end
    // sparse progress: one line per 64 blocks, so block 64 must appear and
    // the run must NOT have printed a line for every block
    expect_str(t0, "AT BLOCK 00000040", 17, "progress line at block 64");
    expect_absent(t0, "AT BLOCK 00000041", 17, "a progress line per block");
    expect_absent(t0, "AT BLOCK 00000080", 17, "a progress line past the run");

    // blocks, sectors and checksum, each 8 hex digits after its label
    begin : chk_range
      integer q;
      reg [31:0] v_blocks, v_secs, v_chk;
      q = find_str(t0, "BLOCKS READ ", 12);
      v_blocks = 0;
      if (q == -1) begin
        $display("FAIL: no BLOCKS READ line"); errors = errors + 1;
      end else
        for (k = 0; k < 8; k = k + 1) v_blocks = v_blocks * 16 + hexval(cap[q+k]);

      q = find_str(t0, "SECTORS READ ", 13);
      v_secs = 0;
      if (q == -1) begin
        $display("FAIL: no SECTORS READ line"); errors = errors + 1;
      end else
        for (k = 0; k < 8; k = k + 1) v_secs = v_secs * 16 + hexval(cap[q+k]);

      q = find_str(t0, "CHECKSUM ", 9);
      v_chk = 0;
      if (q == -1) begin
        $display("FAIL: no CHECKSUM line"); errors = errors + 1;
      end else
        for (k = 0; k < 8; k = k + 1) v_chk = v_chk * 16 + hexval(cap[q+k]);

      $display("tb: range reported blocks=%0d sectors=%0d checksum=%04x",
               v_blocks, v_secs, v_chk[15:0]);
      if (v_blocks !== RNG_CNT) begin
        $display("FAIL: range read %0d blocks, expected %0d", v_blocks, RNG_CNT);
        errors = errors + 1;
      end
      if (v_secs !== 4 * RNG_CNT) begin
        $display("FAIL: range read %0d sectors, expected %0d", v_secs, 4 * RNG_CNT);
        errors = errors + 1;
      end
      // the checksum is computed here from the image model, so it fails if
      // any block came from the wrong place, arrived out of order, or was
      // silently zero
      if (v_chk[15:0] !== img_cksum(RNG_START, RNG_CNT)) begin
        $display("FAIL: range checksum %04x, expected %04x",
                 v_chk[15:0], img_cksum(RNG_START, RNG_CNT));
        errors = errors + 1;
      end
    end

    // A card that dies PARTWAY THROUGH the run must stop it and name the
    // exact place - that is what the command exists for. The card model is
    // told to stop sending read data after the run has started, so the
    // victim is a range sector and not the mount: sd_writer's read watchdog
    // then raises err.
    t0 = cap_len;
    send_key("R");
    wait_str(t0, "START BLOCK, DECIMAL, THEN CR: ", 31, "start block prompt");
    send_dec(0);
    send_key(8'h0D);
    wait_str(t0, "BLOCK COUNT, DECIMAL, THEN CR: ", 31, "block count prompt");
    send_dec(64);
    send_key(8'h0D);
    wait_str(t0, "READING BLOCK RANGE AT SECTOR ", 30, "range start line");
    card.fail_next_reads = 32'd1;   // the next read data block is never sent
    wait_str(t0, "RESULT:", 7, "summary after the injected failure");
    wait_str(t0, "# ", 2, "prompt after the injected failure");

    expect_str(t0, "ERROR: SD READ FAILED", 21, "read failure reported");
    expect_str(t0, "RESULT: FAIL", 12, "FAIL verdict after a card error");
    expect_str(t0, "AT SECTOR ", 10, "failing sector named");
    expect_str(t0, "AT BLOCK ", 9, "failing block named");
    begin : chk_stopped
      integer q;
      reg [31:0] v_blocks;
      q = find_str(t0, "BLOCKS READ ", 12);
      v_blocks = 0;
      if (q == -1) begin
        $display("FAIL: no BLOCKS READ line after the injected failure");
        errors = errors + 1;
      end else begin
        for (k = 0; k < 8; k = k + 1) v_blocks = v_blocks * 16 + hexval(cap[q+k]);
        $display("tb: injected failure stopped the run after %0d blocks", v_blocks);
        if (v_blocks >= 64) begin
          $display("FAIL: the run did not stop at the card error");
          errors = errors + 1;
        end
      end
    end

    // an over-long range must be refused by the same arithmetic as key 8
    t0 = cap_len;
    send_key("R");
    wait_str(t0, "START BLOCK, DECIMAL, THEN CR: ", 31, "start block prompt");
    send_dec(150);
    send_key(8'h0D);
    wait_str(t0, "BLOCK COUNT, DECIMAL, THEN CR: ", 31, "block count prompt");
    send_dec(100);            // 150 + 100 = 250 blocks > the 160 in the file
    send_key(8'h0D);
    wait_str(t0, "# ", 2, "prompt after the over-long range");
    expect_str(t0, "ERROR: BLOCK OUT OF RANGE", 25, "over-long range refusal");

    // ---------------------------------------------------------------- end
    if (card.illegal_writes != 0) begin
      $display("FAIL: %0d card WRITE commands issued by a read-only build",
               card.illegal_writes);
      errors = errors + 1;
    end
    if (card.crc_errors != 0) begin
      $display("FAIL: %0d CRC7 errors on the SD command line", card.crc_errors);
      errors = errors + 1;
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  // absolute watchdog (split: a single delay literal above 2^31 ns is not
  // portable across simulators)
  initial begin
    #2_000_000_000;
    #2_000_000_000;
    $display("TB_RESULT: FAIL absolute watchdog");
    $finish;
  end

endmodule
