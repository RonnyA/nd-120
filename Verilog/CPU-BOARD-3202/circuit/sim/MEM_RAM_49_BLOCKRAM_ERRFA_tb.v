/**************************************************************************
** ND120 - unit test for the SINTRAN ERRFATAL evidence probe             **
** (ND120_ERRFA_PROBE in MEM_RAM_49_BLOCKRAM.v).                         **
**                                                                       **
** Drives the sheet-49 DRAM protocol to write the five ERRFA save cells  **
** 0o4347-0o4353 (X,T,A,D,L) into bank 0, then decodes the probe's own   **
** 9600-baud TX line and demands the exact line                          **
**   "EF 012345 000004 054321 111111 042514\r\n"                         **
** i.e. the five values in save order, 6 octal digits each. Also proves  **
** the negative: before the L cell (0o4353) is written the line never    **
** starts (a probe that fires early garbles the LIVE console).           **
**                                                                       **
** Protocol per MEM_RAM_49_BLOCKRAM: row at the RAS rising edge (high    **
** address half), AA carries the low half during the window, write data  **
** captured while RAS&!CAS, write on the first RAS&CAS edge. The probe   **
** divides its bit clock by EFP_BAUD_DIV=1736 from sysclk.               **
**                                                                       **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module MEM_RAM_49_BLOCKRAM_ERRFA_tb;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  reg [9:0] aa = 0;
  reg bank0 = 0;
  reg cas = 0, ras = 0;
  reg mwrite_n = 1;
  reg [17:0] dd_in = 0;
  wire [17:0] dd_out;
  wire corr_n;
  wire errfa_txd;
  reg  contx = 1;   // simulated console TX line (idle mark)

  MEM_RAM_49_BLOCKRAM #(
      .BANK_ADDR_BITS(16)
  ) DUT (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .AA_9_0(aa),
      .BANK0(bank0),
      .BANK1(1'b0),
      .BANK2(1'b0),
      .CAS(cas),
      .RAS(ras),
      .MWRITE50_n(mwrite_n),
      .DD_17_0_IN(dd_in),
      .DD_17_0_OUT(dd_out),
      .ERRFA_CONTX(contx),
      .ERRFA_TXD(errfa_txd),
      .CORR_n(corr_n)
  );

  always #10 sysclk = ~sysclk;

  integer errors = 0;

  // one full DRAM write cycle, 16-bit word address split {row[9:0], col[9:0]}
  task write_word(input [19:0] addr, input [15:0] data);
    begin
      @(negedge sysclk);
      aa = addr[19:10]; ras = 1; cas = 0; bank0 = 1; mwrite_n = 0;
      dd_in = {1'b0, data[15:8], 1'b0, data[7:0]};
      @(negedge sysclk);   // row captured, data capturing
      aa = addr[9:0];
      @(negedge sysclk);
      cas = 1;             // window opens -> write on first win edge
      @(negedge sysclk);
      @(negedge sysclk);
      ras = 0; cas = 0; bank0 = 0; mwrite_n = 1;
      @(negedge sysclk);
    end
  endtask

  // one full DRAM read cycle (drives the probe's read-history ring)
  task read_word(input [19:0] addr);
    begin
      @(negedge sysclk);
      aa = addr[19:10]; ras = 1; cas = 0; bank0 = 1; mwrite_n = 1;
      @(negedge sysclk);
      aa = addr[9:0];
      @(negedge sysclk);
      cas = 1;
      @(negedge sysclk);
      @(negedge sysclk);
      ras = 0; cas = 0; bank0 = 0;
      @(negedge sysclk);
    end
  endtask

  // decode one 8N1 char off errfa_txd (bit time = 1736 sysclk cycles)
  task recv_char(output [7:0] ch);
    integer b;
    begin
      @(negedge errfa_txd);              // start bit edge
      repeat (`ND120_ERRFA_BAUD_DIV / 2) @(posedge sysclk);
      for (b = 0; b < 8; b = b + 1) begin
        repeat (`ND120_ERRFA_BAUD_DIV) @(posedge sysclk);
        ch[b] = errfa_txd;
      end
      repeat (`ND120_ERRFA_BAUD_DIV) @(posedge sysclk);   // stop bit
      if (errfa_txd !== 1'b1) begin
        $display("FAIL: stop bit low");
        errors = errors + 1;
      end
    end
  endtask

  // feed one 8N1 char into the probe's console-TX matcher
  task send_char(input [7:0] ch);
    integer b;
    begin
      contx = 0;                                   // start
      repeat (`ND120_ERRFA_BAUD_DIV) @(posedge sysclk);
      for (b = 0; b < 8; b = b + 1) begin
        contx = ch[b];
        repeat (`ND120_ERRFA_BAUD_DIV) @(posedge sysclk);
      end
      contx = 1;                                   // stop
      repeat (`ND120_ERRFA_BAUD_DIV) @(posedge sysclk);
    end
  endtask

  localparam [8*75-1:0] EXPECT = "EF 012345 000004 054321 111111 042514 123456 002000 060005 000013 044444 \015\012";

  reg [7:0] got;
  integer i;
  reg early_fired = 0;

  initial begin
    repeat (4) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (4) @(negedge sysclk);

    // NEGATIVE: a bulk load sweeping straight through the save area (the
    // resident image load does exactly this) covers 4347..4353 in order
    // but is preceded by the neighbor 0o4346 - the probe must NOT arm.
    begin : sweep
      integer sa;
      for (sa = 2276; sa <= 2286; sa = sa + 1)  // 0o4344..0o4356
        write_word(sa[19:0], 16'o000000);
    end

    // silence check across two whole would-be lines plus the arming gap
    begin : silent
      integer k;
      for (k = 0; k < 100000; k = k + 1) begin
        @(posedge sysclk);
        if (errfa_txd !== 1'b1) begin
          early_fired = 1;
          k = 100000;
        end
      end
    end
    if (early_fired) begin
      $display("FAIL: probe armed on the bulk sweep (would garble the live console)");
      errors = errors + 1;
    end

    // POSITIVE: ERRFA's saves in a DELIBERATELY scrambled order (the probe
    // must assume nothing about write order), then SINTRAN's own crash
    // text on the console line - the only thing that may arm the probe.
    write_word(20'o1000, 16'o000777);
    write_word(20'o4351, 16'o054321);  // A
    write_word(20'o4347, 16'o012345);  // X
    write_word(20'o4353, 16'o042514);  // L
    write_word(20'o4350, 16'o000004);  // T (= MEMER, the interesting one)
    write_word(20'o4352, 16'o111111);  // D
    write_word(20'o42312, 16'o123456); // SVLCA (driver datafield)
    write_word(20'o42313, 16'o002000); // SVLWC
    write_word(20'o42244, 16'o060005); // SSTAT
    write_word(20'o42314, 16'o000013); // 9TREG (caller function argument)
    write_word(20'o42317, 16'o044444); // 9XREG

    // more silence: memory writes alone must never arm it
    begin : silent2
      integer k2;
      for (k2 = 0; k2 < 100000; k2 = k2 + 1) begin
        @(posedge sysclk);
        if (errfa_txd !== 1'b1) begin
          $display("FAIL: probe armed from memory writes alone");
          errors = errors + 1;
          k2 = 100000;
        end
      end
    end

    // read-history ring: fill it, prove the sequential-sweep pass does
    // NOT freeze it, then take the fatal jump into ERRFA
    begin : ringfill
      integer r;
      read_word(20'o4355);
      read_word(20'o4356);              // sequential arrival - must NOT freeze
      for (r = 0; r < 128; r = r + 1)
        read_word(20'o10000 + r);
      read_word(20'o42510);
      read_word(20'o42511);
      read_word(20'o42512);
      read_word(20'o42513);
      read_word(20'o42522);             // the JPL I 7 pointer cell
      read_word(20'o4356);              // JUMP arrival - freezes the ring
      // post-freeze reads must NOT be recorded
      read_word(20'o77777);
      read_word(20'o77776);
    end

    // the console announces the crash
    send_char("H"); send_char("A"); send_char("L"); send_char("T");
    send_char(" "); send_char("I"); send_char("N");
    send_char(" "); send_char("E"); send_char("R"); send_char("R");
    send_char("F"); send_char("A"); send_char("T");

    // the ring line comes FIRST (RWAIT 2^13 < GAP 2^18 in the bench
    // scaling, matching silicon: P at ~0.5 s, EF at ~2 s)
    
    begin : ringline
      integer g;
      reg [15:0] expw;
      recv_char(got);
      while (got != "P") recv_char(got);
      recv_char(got);
      if (got !== " ") begin
        $display("FAIL: no space after P");
        errors = errors + 1;
      end
      for (g = 0; g < 128; g = g + 1) begin : ringgrp
        integer d;
        reg [17:0] oct;
        oct = 0;
        for (d = 0; d < 6; d = d + 1) begin
          recv_char(got);
          oct = (oct << 3) | (got - 8'h30);
        end
        recv_char(got);   // separator
        // driven tail: entries 122..127 = 42510,42511,42512,42513,42522,4356
        case (g)
          122: expw = 16'o42510;
          123: expw = 16'o42511;
          124: expw = 16'o42512;
          125: expw = 16'o42513;
          126: expw = 16'o42522;
          127: expw = 16'o004356;
          default: expw = 16'hFFFF;   // unchecked
        endcase
        if (expw !== 16'hFFFF && oct[15:0] !== expw) begin
          $display("FAIL: ring entry %0d got %06o expected %06o", g, oct[15:0], expw);
          errors = errors + 1;
        end
      end
    end

    // the line repeats; sync on the 'E' and check all 40 chars
    begin : rx
      recv_char(got);
      while (got != "E") recv_char(got);
      if (got !== "E") errors = errors + 1;
      for (i = 1; i < 75; i = i + 1) begin
        recv_char(got);
        if (got !== EXPECT[8*(74-i)+:8]) begin
          $display("FAIL: char %0d got %02x ('%c') expected %02x ('%c')", i, got, got,
                   EXPECT[8*(74-i)+:8], EXPECT[8*(74-i)+:8]);
          errors = errors + 1;
        end
      end
    end

    if (errors == 0) begin
      $display("probe line verified: EF X T A D L in octal, repeats after the halt");
      $display("TB_RESULT: PASS");
    end else begin
      $display("TB_RESULT: FAIL (%0d errors)", errors);
    end
    $finish;
  end

  // global timeout - a probe that never transmits must FAIL loudly
  initial begin
    #400000000;  // 400 ms sim time >> gap (2^25 cycles) + lines
    $display("FAIL: timeout - probe never transmitted");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
