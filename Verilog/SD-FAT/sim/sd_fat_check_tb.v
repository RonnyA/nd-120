/****************************************************************************
** sd_fat_check - FAT16 cluster-chain validator, report-stream testbench   **
**                                                                         **
** Full path:                                                              **
**   Verilog/SD-FAT/sim/sd_fat_check_tb.v                                  **
**                                                                         **
** WHAT IS VERIFIED                                                        **
**   sd_fat_check (Verilog/SD-FAT/circuit/sd_fat_check.v) walks the FAT    **
**   cluster chain of every entry in a caller-supplied table and emits an  **
**   ASCII report on ck_we/ck_byte. Everything it does ends up in that     **
**   byte stream, so this bench drives a hand-built FAT16 image through a  **
**   behavioural engine model and compares the ENTIRE REPORT, character    **
**   for character, against text assembled independently in the bench.     **
**   A single wrong nibble, a dropped space, a mis-counted cluster or a    **
**   flipped verdict all fail as a byte mismatch at a named offset.        **
**                                                                         **
**   Pinned by the character-exact compare:                                **
**     - the 16-character name field, and NUL -> space padding             **
**     - the " CL " header (note the LEADING space)                        **
**     - 8 upper-case hex digits, most significant nibble first            **
**     - " LEN " / " EXP " + 5 zero-padded decimal digits each             **
**     - " OK\r\n" / " BAD\r\n" / " DIR\r\n" line terminators              **
**     - the trailing "CHECK DONE\r\n" line                                **
**                                                                         **
**   Pinned by the engine-read counter (eng_start pulses per run):         **
**     - the FAT-sector cache: a chain wholly inside one FAT sector costs  **
**       exactly ONE read, a chain that crosses into the next FAT sector   **
**       exactly TWO, a directory entry and a zero-length file ZERO        **
**     - eng_rd is 1 at all times (this module must never ask for a write) **
**                                                                         **
**   Pinned by the arithmetic cases:                                       **
**     - EXP = ceil(size / bytes_per_cluster) at size 0, exactly one       **
**       cluster, and one byte over one cluster                            **
**     - LEN = clusters actually reachable, and the verdict rule           **
**       BAD = (bad flag) OR (LEN != EXP) - including two cases where      **
**       LEN == EXP but the chain is broken anyway (a FREE entry mid-chain **
**       and an out-of-range pointer), which a length-only check misses    **
**                                                                         **
** WHERE THE REFERENCE MODEL COMES FROM                                    **
**   NOT from any FAT specification and not from re-implementing the DUT's **
**   algorithm. Two independent sources:                                   **
**     1. The report LAYOUT is taken from the worked example in the RTL's  **
**        own file header (sd_fat_check.v lines 1-27), e.g.                **
**          "BOOT.BPUN        CL 00013AF2 LEN 00003 EXP 00003 OK"          **
**        The field widths and separators in this bench are transcribed    **
**        from that example and from the S_* string constants, then held   **
**        as literal text.                                                 **
**     2. The expected LEN / EXP / verdict / read-count for each entry are **
**        HAND-COMPUTED from the FAT bytes this bench itself writes into   **
**        the card image (see the table at "golden values"), by following  **
**        the chain on paper. They are constants in the source, not        **
**        anything the bench derives at run time.                          **
**                                                                         **
** THE IMAGE                                                               **
**   FAT16, cluster_size = 1 sector (512 B/cluster), fat0_sector = 4,      **
**   data_base_sector = 10, total_sectors = 2048. That makes               **
**   usable = 2048 - (10 + 2) = 2036 and max_cluster = 2036 + 1 = 2037,    **
**   and puts 256 FAT entries in each sector (clusters 0-255 in sector 4,  **
**   256-511 in sector 5, 1024-1279 in sector 8).                          **
**                                                                         **
** CHARACTERISATION (observed behaviour, recorded - not a specification)   **
**   Three things this bench pins down as OBSERVED rather than intended,   **
**   because no statement of intent exists for them anywhere in the RTL:   **
**     C1  n_entries == 0 emits "CHECK DONE\r\n" TWICE, not once.          **
**     C2  done (and err) pulse in the cycle when busy is ALREADY 0.       **
**     C3  the report has no separator between entries beyond each line's  **
**         own CRLF, and no header line.                                   **
**   See the report notes at the end of this file.                         **
**                                                                         **
** TEST PLAN                                                               **
**   T1  reset: busy/done/err/ck_we/eng_start all 0, t_idx 0               **
**   T2  n_entries = 0: report is "CHECK DONE" (characterisation C1)       **
**   T3  the full 10-entry table: whole report compared byte for byte,     **
**       engine reads == 9, done a single-cycle pulse, err never fires     **
**   T4  engine error on the first FAT read: err pulses, done does NOT,    **
**       busy drops, and exactly the 28 bytes emitted before the read      **
**       (16 name + " CL " + 8 hex) are in the buffer                      **
**   T5  the module is reusable after that error: same entry, healthy      **
**       engine, full correct line                                         **
**   T6  one entry whose chain crosses a FAT sector boundary: 2 reads      **
**   T7  one entry whose chain is inside one FAT sector: 1 read            **
**   T8  a directory entry: DIR line, 0 reads, chain not walked            **
**   T9  a zero-length file with cluster 0: LEN 0 EXP 0 OK, 0 reads        **
**   T10 n_entries = 16, the largest value the 4-bit t_idx can finish:     **
**       terminates, 16 lines + CHECK DONE                                 **
**   Continuous: eng_rd == 1; ck_we and eng_start silent while !busy;      **
**   t_idx never exceeds n_entries-1; no x on the report byte.             **
**                                                                         **
** DELIBERATELY NOT TESTED                                                 **
**   n_entries > 16. t_idx is 4 bits and C_FIN compares                    **
**   "t_idx + 5'd1 >= n_entries[4:0]", so for n_entries 17..31 that        **
**   comparison can never be true and t_idx wraps 15 -> 0 forever. A test  **
**   would hang rather than fail, so this is REPORTED, not exercised.      **
**                                                                         **
** HOW TO RUN                                                              **
**   cd Verilog/SD-FAT/sim && make test-fatcheck                           **
**   or:                                                                   **
**   cd Verilog/SD-FAT/sim && \                                            **
**     iverilog -g2012 -o sd_fat_check_tb.vvp \                            **
**       ../circuit/sd_fat_check.v sd_fat_check_tb.v && \                  **
**     vvp -N sd_fat_check_tb.vvp                                          **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module sd_fat_check_tb;

  // -------------------------------------------------------------- clock/reset
  reg clk = 1'b0;
  always #5 clk = ~clk;          // 100 MHz
  reg rst_n = 1'b0;

  integer checks = 0;
  integer errors = 0;

  task chk(input cond, input [8*64-1:0] what);
    begin
      checks = checks + 1;
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL @%0t: %0s", $time, what);
      end
    end
  endtask

  // -------------------------------------------------------------- geometry
  localparam integer FAT0_SEC  = 4;
  localparam integer DATA_BASE = 10;
  localparam integer TOTAL_SEC = 2048;
  localparam integer CLU_SZ    = 1;     // sectors per cluster -> 512 B/cluster
  // hand-computed here, NOT read from the DUT:
  //   usable      = 2048 - (10 + 1*2) = 2036
  //   max_cluster = (2036 >> log2(1)) + 1 = 2037
  localparam integer MAX_CLUSTER = 2037;

  // -------------------------------------------------------------- DUT signals
  reg         start = 1'b0;
  wire        busy;
  wire        done;
  wire        err;

  reg  [4:0]  n_entries = 5'd0;
  wire [3:0]  t_idx;
  reg  [127:0] t_name_r;
  reg  [31:0] t_cluster_r;
  reg  [31:0] t_size_r;
  reg         t_isdir_r;

  wire        eng_start;
  wire        eng_rd;
  wire [31:0] eng_sector;
  reg         eng_done = 1'b0;
  reg         eng_err  = 1'b0;
  reg         eng_rx_we = 1'b0;
  reg  [8:0]  eng_rx_addr = 9'd0;
  reg  [7:0]  eng_rx_data = 8'd0;

  wire        ck_we;
  wire [7:0]  ck_byte;

  sd_fat_check DUT (
      .clk             (clk),
      .rst_n           (rst_n),
      .start           (start),
      .busy            (busy),
      .done            (done),
      .err             (err),
      .fs_is_fat32     (1'b0),
      .cluster_size    (CLU_SZ[7:0]),
      .fat0_sector     (FAT0_SEC[31:0]),
      .data_base_sector(DATA_BASE[31:0]),
      .total_sectors   (TOTAL_SEC[31:0]),
      .n_entries       (n_entries),
      .t_idx           (t_idx),
      .t_name          (t_name_r),
      .t_cluster       (t_cluster_r),
      .t_size          (t_size_r),
      .t_isdir         (t_isdir_r),
      .eng_start       (eng_start),
      .eng_rd          (eng_rd),
      .eng_sector      (eng_sector),
      .eng_done        (eng_done),
      .eng_err         (eng_err),
      .eng_rx_we       (eng_rx_we),
      .eng_rx_addr     (eng_rx_addr),
      .eng_rx_data     (eng_rx_data),
      .ck_we           (ck_we),
      .ck_byte         (ck_byte)
  );

  // ------------------------------------------------------- the entry table
  // e_name is what the DUT is fed (byte 0 = the FIRST character emitted);
  // e_disp is the 16 characters the report must contain, left to right.
  reg [127:0] e_name [0:15];
  reg [127:0] e_disp [0:15];
  reg [31:0]  e_clu  [0:15];
  reg [31:0]  e_size [0:15];
  reg         e_dir  [0:15];
  integer     e_len  [0:15];   // golden: clusters reachable
  integer     e_exp  [0:15];   // golden: ceil(size / 512)
  reg         e_bad  [0:15];   // golden: verdict is BAD
  integer     e_rd   [0:15];   // golden: engine reads this entry costs

  reg [4:0] tbl_base = 5'd0;   // lets a run start at any table index
  reg [4:0] sel;

  always @(*) begin
    sel         = (tbl_base + {1'b0, t_idx}) & 5'h0F;
    t_name_r    = e_name[sel[3:0]];
    t_cluster_r = e_clu [sel[3:0]];
    t_size_r    = e_size[sel[3:0]];
    t_isdir_r   = e_dir [sel[3:0]];
  end

  // 16-char display literal -> the byte-0-first order the DUT emits
  function [127:0] revb(input [127:0] s);
    integer k;
    begin
      for (k = 0; k < 16; k = k + 1) revb[8*k +: 8] = s[8*(15-k) +: 8];
    end
  endfunction

  // same, but trailing spaces become NULs, to exercise the NUL -> space
  // padding in C_NAME (the report text is identical either way)
  function [127:0] revb_nul(input [127:0] s);
    integer k;
    reg     hit;
    begin
      revb_nul = revb(s);
      hit = 1'b0;
      for (k = 15; k >= 0; k = k - 1) begin
        if (!hit && revb_nul[8*k +: 8] == 8'h20) revb_nul[8*k +: 8] = 8'h00;
        else hit = 1'b1;
      end
    end
  endfunction

  // -------------------------------------------------------------- card image
  reg [7:0] card [0:16*512-1];   // sectors 0..15

  // FAT16 entry write, addressed the independent way: the entry for cluster c
  // lives at sector fat0 + c/256, byte offset (c % 256) * 2, little endian.
  task fatw(input integer c, input [15:0] v);
    integer a;
    begin
      a = (FAT0_SEC + (c / 256)) * 512 + (c % 256) * 2;
      card[a]     = v[7:0];
      card[a + 1] = v[15:8];
    end
  endtask

  // -------------------------------------------------------------- engine model
  // Read-only CMD17 model: on an eng_start pulse it streams the 512 bytes of
  // eng_sector out on eng_rx_*, one per clock, then pulses eng_done one clock
  // after the last byte has been written. eng_fail turns the same request
  // into a one-cycle eng_err instead.
  localparam [1:0] M_IDLE = 2'd0, M_STREAM = 2'd1, M_FIN = 2'd2;
  reg  [1:0]  ms = M_IDLE;
  integer     eng_i = 0;
  integer     eng_reads = 0;
  reg         eng_fail = 1'b0;
  reg  [31:0] eng_sec_seen = 32'd0;

  always @(posedge clk) begin
    if (!rst_n) begin
      ms          <= M_IDLE;
      eng_rx_we   <= 1'b0;
      eng_done    <= 1'b0;
      eng_err     <= 1'b0;
      eng_i       <= 0;
    end else begin
      eng_rx_we <= 1'b0;
      eng_done  <= 1'b0;
      eng_err   <= 1'b0;
      case (ms)
        M_IDLE:
        if (eng_start) begin
          eng_sec_seen <= eng_sector;
          if (eng_fail) eng_err <= 1'b1;
          else begin
            ms    <= M_STREAM;
            eng_i <= 0;
          end
        end

        M_STREAM: begin
          eng_rx_we   <= 1'b1;
          eng_rx_addr <= eng_i[8:0];
          eng_rx_data <= card[eng_sec_seen * 512 + eng_i];
          if (eng_i == 511) ms <= M_FIN;
          eng_i <= eng_i + 1;
        end

        M_FIN: begin
          eng_done <= 1'b1;
          ms       <= M_IDLE;
        end

        default: ms <= M_IDLE;
      endcase
    end
  end

  // accepted engine requests (counts the error answers too)
  always @(posedge clk)
    if (rst_n && ms == M_IDLE && eng_start) eng_reads = eng_reads + 1;

  // -------------------------------------------------------------- report capture
  reg [7:0] got_buf [0:4095];
  integer   got_n = 0;

  always @(posedge clk)
    if (rst_n && ck_we) begin
      if (got_n < 4096) got_buf[got_n] = ck_byte;
      got_n = got_n + 1;
    end

  // -------------------------------------------------------------- expected text
  reg [7:0] exp_buf [0:4095];
  integer   exp_n = 0;

  task eput(input [8*80-1:0] s, input integer len);
    integer k;
    begin
      for (k = 0; k < len; k = k + 1) begin
        exp_buf[exp_n] = s[8*(len-1-k) +: 8];
        exp_n = exp_n + 1;
      end
    end
  endtask

  // independent of the RTL's hexd(): built from the character literals
  function [7:0] hexchar(input [3:0] n);
    hexchar = (n < 4'd10) ? ("0" + {4'b0, n}) : ("A" + (n - 4'd10));
  endfunction

  // independent of the RTL's repeated-subtract decimal loop: plain
  // divide-and-modulo, always 5 digits, no leading-zero suppression
  task eput_dec5(input integer v);
    integer k, p;
    begin
      p = 10000;
      for (k = 0; k < 5; k = k + 1) begin
        exp_buf[exp_n] = "0" + ((v / p) % 10);
        exp_n = exp_n + 1;
        p = p / 10;
      end
    end
  endtask

  task eput_hex8(input [31:0] v);
    integer k;
    begin
      for (k = 0; k < 8; k = k + 1) begin
        exp_buf[exp_n] = hexchar(v[31 - 4*k -: 4]);
        exp_n = exp_n + 1;
      end
    end
  endtask

  task build_expect(input integer base, input integer n);
    integer i, s;
    begin
      exp_n = 0;
      for (i = 0; i < n; i = i + 1) begin
        s = base + i;
        eput(e_disp[s], 16);
        eput(" CL ", 4);
        eput_hex8(e_clu[s]);
        if (e_dir[s]) begin
          eput(" DIR\015\012", 6);
        end else begin
          eput(" LEN ", 5);
          eput_dec5(e_len[s]);
          eput(" EXP ", 5);
          eput_dec5(e_exp[s]);
          if (e_bad[s]) eput(" BAD\015\012", 6);
          else          eput(" OK\015\012",  5);
        end
      end
      eput("CHECK DONE\015\012", 12);
    end
  endtask

  task show_buf(input [8*12-1:0] tag, input integer n, input integer which);
    integer k;
    reg [7:0] b;
    begin
      $write("  %0s[%0d]: \"", tag, n);
      for (k = 0; k < n && k < 200; k = k + 1) begin
        b = which ? exp_buf[k] : got_buf[k];
        if (b == 8'h0D) $write("\\r");
        else if (b == 8'h0A) $write("\\n");
        else $write("%c", b);
      end
      $write("\"\n");
    end
  endtask

  integer cmp_i;
  integer cmp_shown;
  task compare_report(input [8*24-1:0] tag);
    begin
      chk(got_n == exp_n, {tag, " report byte COUNT wrong"});
      if (got_n != exp_n)
        $display("  %0s: got %0d bytes, expected %0d", tag, got_n, exp_n);
      cmp_shown = 0;
      for (cmp_i = 0; cmp_i < exp_n; cmp_i = cmp_i + 1) begin
        checks = checks + 1;
        if (cmp_i >= got_n || got_buf[cmp_i] !== exp_buf[cmp_i]) begin
          errors = errors + 1;
          if (cmp_shown < 8) begin
            cmp_shown = cmp_shown + 1;
            $display("FAIL %0s: byte %0d got %02h expected %02h",
                     tag, cmp_i, (cmp_i < got_n) ? got_buf[cmp_i] : 8'hXX,
                     exp_buf[cmp_i]);
          end
        end
      end
      if (cmp_shown != 0 || got_n != exp_n) begin
        show_buf("got", got_n, 0);
        show_buf("exp", exp_n, 1);
      end
    end
  endtask

  // -------------------------------------------------------------- monitors
  integer mon_bad_engrd  = 0;
  integer mon_idle_noise = 0;
  integer mon_idx_over   = 0;
  integer mon_x_byte     = 0;

  always @(posedge clk) begin
    #1;
    if (rst_n) begin
      if (eng_rd !== 1'b1) mon_bad_engrd = mon_bad_engrd + 1;
      if (!busy && (ck_we || eng_start)) mon_idle_noise = mon_idle_noise + 1;
      if (busy && n_entries != 0 && ({1'b0, t_idx} >= n_entries))
        mon_idx_over = mon_idx_over + 1;
      if (ck_we === 1'b1 && (^ck_byte) === 1'bx) mon_x_byte = mon_x_byte + 1;
    end
  end

  // -------------------------------------------------------------- run helper
  integer n_done, n_err, busy_low, guard, pulse_gone;

  task pulse_start;
    begin
      @(negedge clk);
      start = 1'b1;
      @(negedge clk);
      start = 1'b0;
    end
  endtask

  task run_until_done;
    begin
      n_done   = 0;
      n_err    = 0;
      busy_low = 0;
      guard    = 0;
      while (n_done == 0 && n_err == 0 && guard < 300000) begin
        @(posedge clk);
        #1;
        if (done) n_done = n_done + 1;
        if (err)  n_err  = n_err + 1;
        if (!busy && !done && !err) busy_low = busy_low + 1;
        guard = guard + 1;
      end
      @(posedge clk);
      #1;
      pulse_gone = (!done && !err);
    end
  endtask

  // start a fresh run: clear the capture and the read counter
  task begin_run(input [4:0] base, input [4:0] n, input fail);
    begin
      @(negedge clk);
      tbl_base  = base;
      n_entries = n;
      eng_fail  = fail;
      got_n     = 0;
      eng_reads = 0;
    end
  endtask

  // -------------------------------------------------------------- watchdog
  initial begin
    #20_000_000;
    $display("checks=%0d failures=%0d", checks, errors + 1);
    $display("TB_RESULT: FAIL  (watchdog: testbench did not finish)");
    $finish;
  end

  // -------------------------------------------------------------- VCD
  initial begin
    $dumpfile("sd_fat_check_tb.vcd");
    $dumpvars(0, sd_fat_check_tb);
  end

  // -------------------------------------------------------------- image + table
  integer ii;
  task build_image;
    begin
      for (ii = 0; ii < 16*512; ii = ii + 1) card[ii] = 8'h00;

      // entry 0 GOOD.TXT      2 -> 3 -> 4 -> EOC          (all in FAT sector 4)
      fatw(2, 16'd3); fatw(3, 16'd4); fatw(4, 16'hFFFF);
      // entry 1 SHORT.BIN     8 -> 9 -> EOC
      fatw(8, 16'd9); fatw(9, 16'hFFFF);
      // entry 2 LONG.BIN      12 -> 13 -> 14 -> EOC
      fatw(12, 16'd13); fatw(13, 16'd14); fatw(14, 16'hFFFF);
      // entry 4 FREEHIT.DAT   24 -> 25 -> 0 (FREE, mid-chain)
      fatw(24, 16'd25); fatw(25, 16'd0);
      // entry 5 OOR.DAT       30 -> 9000 (> max_cluster 2037)
      fatw(30, 16'd9000);
      // entry 6 CROSS.IMG     254 -> 255 -> 256 -> EOC  (sector 4 then 5)
      fatw(254, 16'd255); fatw(255, 16'd256); fatw(256, 16'hFFFF);
      // entry 8 SIXTEEN...    1234 -> EOC                (FAT sector 8)
      fatw(1234, 16'hFFFF);
      // entry 9 OVER.DAT      42 -> 43 -> EOC
      fatw(42, 16'd43); fatw(43, 16'hFFFF);
    end
  endtask

  task build_table;
    integer k;
    begin
      // ---- golden values: hand-derived from the FAT bytes above ----------
      // idx name              clu   size  dir  LEN EXP BAD reads
      //  0  GOOD.TXT            2   1536   0    3   3   0    1
      //  1  SHORT.BIN           8   2048   0    2   4   1    1
      //  2  LONG.BIN           12    512   0    3   1   1    1
      //  3  HDD                20      0   1    -   -   -    0
      //  4  FREEHIT.DAT        24   1024   0    2   2   1    1   (free entry)
      //  5  OOR.DAT            30    512   0    1   1   1    1   (out of range)
      //  6  CROSS.IMG         254   1536   0    3   3   0    2   (sector cross)
      //  7  ZERO.DAT            0      0   0    0   0   0    0
      //  8  SIXTEENCHARNAME1 1234    512   0    1   1   0    1
      //  9  OVER.DAT           42    513   0    2   2   0    1   (one byte over)
      // 10..15 PADnn             0      0   0    0   0   0    0

      e_disp[0] = "GOOD.TXT        "; e_name[0] = revb(e_disp[0]);
      e_clu[0]  = 32'd2;   e_size[0] = 32'd1536; e_dir[0] = 1'b0;
      e_len[0]  = 3; e_exp[0] = 3; e_bad[0] = 1'b0; e_rd[0] = 1;

      e_disp[1] = "SHORT.BIN       "; e_name[1] = revb_nul(e_disp[1]);
      e_clu[1]  = 32'd8;   e_size[1] = 32'd2048; e_dir[1] = 1'b0;
      e_len[1]  = 2; e_exp[1] = 4; e_bad[1] = 1'b1; e_rd[1] = 1;

      e_disp[2] = "LONG.BIN        "; e_name[2] = revb_nul(e_disp[2]);
      e_clu[2]  = 32'd12;  e_size[2] = 32'd512;  e_dir[2] = 1'b0;
      e_len[2]  = 3; e_exp[2] = 1; e_bad[2] = 1'b1; e_rd[2] = 1;

      e_disp[3] = "HDD             "; e_name[3] = revb_nul(e_disp[3]);
      e_clu[3]  = 32'd20;  e_size[3] = 32'd0;    e_dir[3] = 1'b1;
      e_len[3]  = 0; e_exp[3] = 0; e_bad[3] = 1'b0; e_rd[3] = 0;

      e_disp[4] = "FREEHIT.DAT     "; e_name[4] = revb_nul(e_disp[4]);
      e_clu[4]  = 32'd24;  e_size[4] = 32'd1024; e_dir[4] = 1'b0;
      e_len[4]  = 2; e_exp[4] = 2; e_bad[4] = 1'b1; e_rd[4] = 1;

      e_disp[5] = "OOR.DAT         "; e_name[5] = revb_nul(e_disp[5]);
      e_clu[5]  = 32'd30;  e_size[5] = 32'd512;  e_dir[5] = 1'b0;
      e_len[5]  = 1; e_exp[5] = 1; e_bad[5] = 1'b1; e_rd[5] = 1;

      e_disp[6] = "CROSS.IMG       "; e_name[6] = revb_nul(e_disp[6]);
      e_clu[6]  = 32'd254; e_size[6] = 32'd1536; e_dir[6] = 1'b0;
      e_len[6]  = 3; e_exp[6] = 3; e_bad[6] = 1'b0; e_rd[6] = 2;

      e_disp[7] = "ZERO.DAT        "; e_name[7] = revb_nul(e_disp[7]);
      e_clu[7]  = 32'd0;   e_size[7] = 32'd0;    e_dir[7] = 1'b0;
      e_len[7]  = 0; e_exp[7] = 0; e_bad[7] = 1'b0; e_rd[7] = 0;

      e_disp[8] = "SIXTEENCHARNAME1"; e_name[8] = revb(e_disp[8]);
      e_clu[8]  = 32'd1234; e_size[8] = 32'd512; e_dir[8] = 1'b0;
      e_len[8]  = 1; e_exp[8] = 1; e_bad[8] = 1'b0; e_rd[8] = 1;

      e_disp[9] = "OVER.DAT        "; e_name[9] = revb_nul(e_disp[9]);
      e_clu[9]  = 32'd42;  e_size[9] = 32'd513;  e_dir[9] = 1'b0;
      e_len[9]  = 2; e_exp[9] = 2; e_bad[9] = 1'b0; e_rd[9] = 1;

      // filler entries 10..15: empty files, no chain, no engine traffic
      e_disp[10] = "PAD10           ";
      e_disp[11] = "PAD11           ";
      e_disp[12] = "PAD12           ";
      e_disp[13] = "PAD13           ";
      e_disp[14] = "PAD14           ";
      e_disp[15] = "PAD15           ";
      for (k = 10; k < 16; k = k + 1) begin
        e_name[k] = revb_nul(e_disp[k]);
        e_clu[k]  = 32'd0;
        e_size[k] = 32'd0;
        e_dir[k]  = 1'b0;
        e_len[k]  = 0;
        e_exp[k]  = 0;
        e_bad[k]  = 1'b0;
        e_rd[k]   = 0;
      end
    end
  endtask

  // -------------------------------------------------------------- stimulus
  integer total_rd;
  integer k2;

  initial begin
    build_image;
    build_table;

    // ---- T1: reset ------------------------------------------------------
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    #1;
    chk(busy === 1'b0,      "T1 busy not 0 in reset");
    chk(done === 1'b0,      "T1 done not 0 in reset");
    chk(err  === 1'b0,      "T1 err not 0 in reset");
    chk(ck_we === 1'b0,     "T1 ck_we not 0 in reset");
    chk(eng_start === 1'b0, "T1 eng_start not 0 in reset");
    chk(t_idx === 4'd0,     "T1 t_idx not 0 in reset");
    chk(eng_rd === 1'b1,    "T1 eng_rd not hardwired 1");
    @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
    #1;
    chk(busy === 1'b0, "T1 busy not 0 after reset release");

    // ---- T2: n_entries == 0 (characterisation C1) -----------------------
    begin_run(5'd0, 5'd0, 1'b0);
    pulse_start;
    run_until_done;
    chk(n_done == 1, "T2 no done for n_entries=0");
    chk(n_err  == 0, "T2 spurious err for n_entries=0");
    chk(eng_reads == 0, "T2 engine touched for n_entries=0");
    // CHARACTERISATION: the RTL emits the DONE line from C_IDLE and then
    // C_FIN's terminating branch emits it a SECOND time. Recorded, not
    // endorsed - see the defect notes at the end of this file.
    exp_n = 0;
    eput("CHECK DONE\015\012", 12);
    eput("CHECK DONE\015\012", 12);
    compare_report("T2 n_entries=0");

    // ---- T3: the full 10-entry table ------------------------------------
    begin_run(5'd0, 5'd10, 1'b0);
    pulse_start;
    @(posedge clk); #1;
    chk(busy === 1'b1, "T3 busy did not rise at start");
    run_until_done;
    chk(n_done == 1,     "T3 no done pulse");
    chk(n_err  == 0,     "T3 unexpected err");
    chk(busy_low == 0,   "T3 busy dropped mid-run");
    chk(pulse_gone == 1, "T3 done is not a single-cycle pulse");
    // CHARACTERISATION C2: done pulses in the cycle busy is ALREADY low.
    chk(busy === 1'b0, "T3 busy still high after done");
    total_rd = 0;
    for (k2 = 0; k2 < 10; k2 = k2 + 1) total_rd = total_rd + e_rd[k2];
    chk(eng_reads == total_rd, "T3 engine read COUNT wrong (FAT sector cache)");
    if (eng_reads != total_rd)
      $display("  T3: eng_reads=%0d expected=%0d", eng_reads, total_rd);
    build_expect(0, 10);
    compare_report("T3 full table");

    // ---- T4: engine error on the first FAT read -------------------------
    begin_run(5'd0, 5'd1, 1'b1);      // entry 0 needs one FAT read
    pulse_start;
    run_until_done;
    chk(n_err  == 1, "T4 no err pulse on engine failure");
    chk(n_done == 0, "T4 done fired on engine failure");
    chk(busy === 1'b0, "T4 busy did not drop after engine failure");
    chk(pulse_gone == 1, "T4 err is not a single-cycle pulse");
    chk(eng_reads == 1, "T4 wrong number of engine requests");
    // exactly the bytes emitted before the walk starts: 16 name + " CL " + 8 hex
    exp_n = 0;
    eput(e_disp[0], 16);
    eput(" CL ", 4);
    eput_hex8(e_clu[0]);
    compare_report("T4 engine error");

    // ---- T5: reusable after the error -----------------------------------
    begin_run(5'd0, 5'd1, 1'b0);
    pulse_start;
    run_until_done;
    chk(n_done == 1, "T5 no done after recovering from an engine error");
    chk(n_err  == 0, "T5 err again after recovery");
    chk(eng_reads == e_rd[0], "T5 wrong engine read count after recovery");
    build_expect(0, 1);
    compare_report("T5 recovery");

    // ---- T6: chain crossing a FAT sector boundary -> 2 reads -------------
    begin_run(5'd6, 5'd1, 1'b0);
    pulse_start;
    run_until_done;
    chk(n_done == 1, "T6 no done");
    chk(eng_reads == 2, "T6 sector-crossing chain did not cost exactly 2 reads");
    build_expect(6, 1);
    compare_report("T6 sector cross");

    // ---- T7: chain inside one FAT sector -> 1 read -----------------------
    begin_run(5'd0, 5'd1, 1'b0);
    pulse_start;
    run_until_done;
    chk(eng_reads == 1, "T7 single-sector chain did not cost exactly 1 read");

    // ---- T8: a directory entry -> DIR line, no chain walk ----------------
    begin_run(5'd3, 5'd1, 1'b0);
    pulse_start;
    run_until_done;
    chk(n_done == 1, "T8 no done for a directory entry");
    chk(eng_reads == 0, "T8 a directory entry touched the engine");
    build_expect(3, 1);
    compare_report("T8 directory");

    // ---- T9: zero-length file, cluster 0 ---------------------------------
    begin_run(5'd7, 5'd1, 1'b0);
    pulse_start;
    run_until_done;
    chk(n_done == 1, "T9 no done for a zero-length file");
    chk(eng_reads == 0, "T9 a zero-length file touched the engine");
    build_expect(7, 1);
    compare_report("T9 zero length");

    // ---- T10: n_entries = 16, the largest a 4-bit t_idx can finish -------
    begin_run(5'd0, 5'd16, 1'b0);
    pulse_start;
    run_until_done;
    chk(n_done == 1, "T10 n_entries=16 did not terminate");
    chk(n_err  == 0, "T10 unexpected err at n_entries=16");
    total_rd = 0;
    for (k2 = 0; k2 < 16; k2 = k2 + 1) total_rd = total_rd + e_rd[k2];
    chk(eng_reads == total_rd, "T10 engine read count wrong at n_entries=16");
    build_expect(0, 16);
    compare_report("T10 sixteen entries");

    // ---- continuous monitors ---------------------------------------------
    chk(mon_bad_engrd  == 0, "eng_rd was not 1 at some point");
    chk(mon_idle_noise == 0, "ck_we or eng_start asserted while !busy");
    chk(mon_idx_over   == 0, "t_idx went past n_entries-1");
    chk(mon_x_byte     == 0, "an x/z byte was written to the report");

    // ---- verdict ----------------------------------------------------------
    repeat (2) @(posedge clk);
    $display("checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

  // ==========================================================================
  // NOTES RECORDED BY THIS BENCH (reported, never fixed here)
  //
  // D1  sd_fat_check.v:380 - C_FIN compares "t_idx + 5'd1 >= n_entries[4:0]"
  //     while t_idx is declared 4 bits at sd_fat_check.v:48 and n_entries is
  //     a 5-bit port at sd_fat_check.v:47. For n_entries in 17..31 the
  //     comparison can never become true: t_idx counts to 15, wraps to 0 at
  //     sd_fat_check.v:386, and the report never terminates. Not exercised
  //     here - it would hang rather than fail. The largest working value is
  //     16, and T10 proves 16 does terminate.
  //
  // D2  sd_fat_check.v:221-228 together with sd_fat_check.v:379-383 - with
  //     n_entries == 0 the "CHECK DONE" line is emitted TWICE: once from the
  //     C_IDLE special case, and again from C_FIN, whose terminating branch
  //     is entered because 0 + 1 >= 0. Recorded as behaviour by T2.
  //
  // D3  sd_fat_check.v:222 - "state <= (n_entries == 0) ? C_DONELN : C_ENTRY"
  //     is immediately overwritten by the if at sd_fat_check.v:223-227, so
  //     C_DONELN (declared sd_fat_check.v:147, body sd_fat_check.v:395) is
  //     unreachable dead code.
  //
  // D4  sd_fat_check.v:390 - the comment "err path jumps here too" is wrong.
  //     The engine-error path at sd_fat_check.v:405-408 goes straight to
  //     C_IDLE and never enters C_ERR; C_ERR is only ever the normal
  //     terminal state. The note at sd_fat_check.v:383 calling C_ERR
  //     "reused" reads as if the error path shared it.
  //
  // D5  sd_fat_check.v:133 - the comment says "12 name chars"; the code at
  //     sd_fat_check.v:231-245 emits 16 (nidx runs to 15). The port comment
  //     at sd_fat_check.v:49 says 16, so the code is right and the state
  //     comment is stale.
  //
  // D6  done and err pulse in the cycle when busy is ALREADY 0: both
  //     terminal paths set state <= C_IDLE in the same cycle they raise the
  //     pulse (sd_fat_check.v:390-393 and sd_fat_check.v:405-408), while
  //     busy is the combinational "state != C_IDLE" at sd_fat_check.v:168.
  //     A caller gating on "busy && done" would never see either pulse.
  //     Recorded by T3 and T4.
  // ==========================================================================

endmodule

`default_nettype wire
