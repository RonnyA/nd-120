/**************************************************************************
** CPU_CS_PROM_19 - microcode PROM address/data path testbench           **
** (sheet 19, PROMS - AM27256 45132L low byte + 45133L high byte)        **
**                                                                       **
** This is the pair of 32K x 8 PROMs the whole machine boots out of. The **
** module is small, but three separate things in it are exactly the kind **
** of one-wire error that costs weeks:                                   **
**                                                                       **
**   1. THE ADDRESS CONCATENATION. s_Address = {LUA_12_0, RF_1_0} - the  **
**      microinstruction address in the HIGH 13 bits and the word select **
**      in the LOW 2. Concatenate it the other way round and the ROM     **
**      still reads, still returns real microcode, and the CPU executes  **
**      garbage. The test reads the REAL hex files itself and checks the **
**      DUT against rom[LUA*4 + RF] for every RF at many LUA values,     **
**      including LUA values whose bit pattern makes the two orderings   **
**      differ.                                                          **
**                                                                       **
**   2. THE BYTE SPLIT. 45132L is the LOW byte (IDB 7:0) and 45133L the  **
**      HIGH byte (IDB 15:8). Swapped, every microword comes out         **
**      byte-reversed. The test only counts addresses where the two      **
**      bytes actually DIFFER, and reports how many it used, so a swap   **
**      cannot hide behind palindromic data.                             **
**                                                                       **
**   3. THE READ TIMING. The comment says the sequencer expects data one **
**      cycle after the address. The test asserts exactly that: the new  **
**      word is NOT there before the clock edge and IS there after it.   **
**                                                                       **
** Also checked: BLCS~ gating publishes ZERO, not z and not stale data   **
** (IDB is an OR-ed bus in CPU_15.v line 320), and the register keeps    **
** its content while gated so lowering BLCS~ again republishes it.       **
**                                                                       **
** SPECIFICATION test. The two .hex files are the golden reference and   **
** the testbench re-reads them independently of the DUT.                 **
**                                                                       **
** Run: cd Verilog/CPU-BOARD-3202/sim && make test-prom19                **
**      (the target symlinks the two .hex files next to the testbench,   **
**       because the RTL opens them by bare filename)                    **
**                                                                       **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CPU_CS_PROM_19_tb;

  reg         sysclk = 1'b0;
  reg         sys_rst_n = 1'b1;
  reg         BLCS_n;
  reg  [ 1:0] RF_1_0;
  reg  [12:0] LUA_12_0;
  wire [15:0] IDB_15_0_OUT;

  integer errors = 0;
  integer checks = 0;
  integer differing_bytes = 0;
  integer nonzero_words = 0;
  integer i, r;
  reg [14:0] addr;
  reg [15:0] want, before_edge;
  reg [15:0] or_seen = 16'h0000;
  reg [15:0] and_seen = 16'hFFFF;

  always #5 sysclk = ~sysclk;

  // independent golden copies of the same two PROM images
  reg [7:0] gold_lo[0:32767];
  reg [7:0] gold_hi[0:32767];

  CPU_CS_PROM_19 DUT (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .BLCS_n(BLCS_n), .RF_1_0(RF_1_0), .LUA_12_0(LUA_12_0),
      .IDB_15_0_OUT(IDB_15_0_OUT)
  );

  // present an address and let the registered ROM read settle
  task read_at;
    input [12:0] lua;
    input [ 1:0] rf;
    begin
      LUA_12_0 = lua;
      RF_1_0   = rf;
      @(posedge sysclk); #1;
      @(posedge sysclk); #1;
    end
  endtask

  initial begin
    $dumpfile("CPU_CS_PROM_19_tb.vcd");
    $dumpvars(0, CPU_CS_PROM_19_tb);
    // Keep the committed waveform SHORT and readable: this testbench
    // runs far more stimulus than anyone wants to open in GTKWave, so
    // only the opening 3000 ns is recorded. The pass/fail verdict comes
    // from the text output, never from the waveform.
    #3000 $dumpoff;
  end

  initial begin
    $display("=====================================================");
    $display(" CPU_CS_PROM_19 (sheet 19) microcode PROM path");
    $display("=====================================================");

    $readmemh("AM27256_45132L.hex", gold_lo);
    $readmemh("AM27256_45133L.hex", gold_hi);

    // sanity: if the images did not load, every later compare would pass
    // trivially against x, so refuse to run
    if (gold_lo[0] === 8'hxx || gold_hi[0] === 8'hxx) begin
      $display("FAIL NO_PROM_IMAGE: AM27256_45132L.hex / 45133L.hex not readable from the run directory");
      $display("TB_RESULT: FAIL");
      $finish;
    end

    BLCS_n = 1'b0; LUA_12_0 = 0; RF_1_0 = 0;
    @(posedge sysclk); #1;

    // ---- 1. address concatenation + byte split, swept over the image.
    // ----    Step through LUA in a stride that is not a power of two so
    // ----    the sweep does not sit on one bit pattern.
    for (i = 0; i < 8192; i = i + 37) begin
      for (r = 0; r < 4; r = r + 1) begin
        read_at(i[12:0], r[1:0]);
        addr = {i[12:0], r[1:0]};
        want = {gold_hi[addr], gold_lo[addr]};
        checks = checks + 1;
        if (IDB_15_0_OUT !== want) begin
          errors = errors + 1;
          if (errors < 12)
            $display("FAIL ROM_WORD: LUA=%0d RF=%0d (addr %0d) -> %04h want %04h",
                     i, r, addr, IDB_15_0_OUT, want);
        end
        if (gold_hi[addr] !== gold_lo[addr]) differing_bytes = differing_bytes + 1;
        if (want !== 16'h0000) nonzero_words = nonzero_words + 1;
        or_seen  = or_seen  | IDB_15_0_OUT;
        and_seen = and_seen & IDB_15_0_OUT;
      end
    end

    // The byte-split check is only meaningful where the two bytes differ,
    // and the address-order check only where the data is non-zero. Say how
    // much real evidence the sweep actually gathered.
    $display(" addresses where HI != LO : %0d", differing_bytes);
    $display(" non-zero microwords read : %0d", nonzero_words);
    checks = checks + 2;
    if (differing_bytes < 50) begin
      errors = errors + 1;
      $display("FAIL WEAK_EVIDENCE: too few differing byte pairs to prove the HI/LO split");
    end
    if (nonzero_words < 50) begin
      errors = errors + 1;
      $display("FAIL WEAK_EVIDENCE: too few non-zero words to prove the address order");
    end

    // ---- 2. the word select must be the LOW two address bits. Four
    // ----    consecutive RF values at one LUA must read four CONSECUTIVE
    // ----    ROM addresses. If the concatenation were {RF, LUA} these
    // ----    four reads would be 8192 apart instead.
    begin : word_select
      integer lua_pick, hits;
      reg [15:0] w0, w1, w2, w3;
      lua_pick = 13'd1234;
      read_at(lua_pick[12:0], 2'd0); w0 = IDB_15_0_OUT;
      read_at(lua_pick[12:0], 2'd1); w1 = IDB_15_0_OUT;
      read_at(lua_pick[12:0], 2'd2); w2 = IDB_15_0_OUT;
      read_at(lua_pick[12:0], 2'd3); w3 = IDB_15_0_OUT;
      hits = 0;
      if (w0 === {gold_hi[lua_pick*4+0], gold_lo[lua_pick*4+0]}) hits = hits + 1;
      if (w1 === {gold_hi[lua_pick*4+1], gold_lo[lua_pick*4+1]}) hits = hits + 1;
      if (w2 === {gold_hi[lua_pick*4+2], gold_lo[lua_pick*4+2]}) hits = hits + 1;
      if (w3 === {gold_hi[lua_pick*4+3], gold_lo[lua_pick*4+3]}) hits = hits + 1;
      checks = checks + 1;
      if (hits != 4) begin
        errors = errors + 1;
        $display("FAIL WORD_SELECT_NOT_LOW_BITS: only %0d of 4 slices matched at LUA=%0d",
                 hits, lua_pick);
      end
    end

    // ---- 3. read latency is exactly one clock. Change the address and
    // ----    confirm the OLD word is still out before the edge.
    begin : latency
      reg [15:0] old_word;
      integer a, b;
      a = 100; b = 2000;
      read_at(a[12:0], 2'd0);
      old_word = IDB_15_0_OUT;
      LUA_12_0 = b[12:0]; RF_1_0 = 2'd0;
      #1;
      checks = checks + 1;
      if (IDB_15_0_OUT !== old_word) begin
        errors = errors + 1;
        $display("FAIL NOT_REGISTERED: the ROM output followed the address combinationally");
      end
      @(posedge sysclk); #1;
      checks = checks + 1;
      if (IDB_15_0_OUT !== {gold_hi[b*4], gold_lo[b*4]}) begin
        errors = errors + 1;
        $display("FAIL LATENCY: after one clock got %04h want %04h",
                 IDB_15_0_OUT, {gold_hi[b*4], gold_lo[b*4]});
      end
    end

    // ---- 4. BLCS~ gating: OFF means exactly zero, and the register still
    // ----    holds so turning it back on republishes the same word.
    begin : gating
      reg [15:0] w;
      read_at(13'd777, 2'd1);
      w = IDB_15_0_OUT;
      BLCS_n = 1'b1;
      @(posedge sysclk); #1;
      checks = checks + 1;
      if (IDB_15_0_OUT !== 16'h0000) begin
        errors = errors + 1;
        $display("FAIL GATED_NOT_ZERO: IDB=%04h with BLCS_n high", IDB_15_0_OUT);
      end
      BLCS_n = 1'b0;
      #1;
      checks = checks + 1;
      if (IDB_15_0_OUT !== w) begin
        errors = errors + 1;
        $display("FAIL LOST_WHILE_GATED: %04h -> %04h", w, IDB_15_0_OUT);
      end
    end

    // ---- 5. liveness: no IDB bit may be stuck across the whole sweep.
    // ----    A stuck bit here is a broken ROM data connection.
    for (i = 0; i < 16; i = i + 1) begin
      checks = checks + 2;
      if (or_seen[i] === 1'b0) begin
        errors = errors + 1;
        $display("FAIL STUCK_LOW: IDB bit %0d never went high in the sweep", i);
      end
      if (and_seen[i] === 1'b1) begin
        errors = errors + 1;
        $display("FAIL STUCK_HIGH: IDB bit %0d never went low in the sweep", i);
      end
    end

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

endmodule

`default_nettype wire
