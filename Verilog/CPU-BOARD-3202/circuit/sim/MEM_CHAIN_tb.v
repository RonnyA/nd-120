/****************************************************************************
** Chain testbench: MEM_ADDR_44 + MEM_RAM_49 (write / readback)            **
**                                                                         **
** Pre-synth validation of the memory ADDRESS + STORAGE chain with the     **
** MEASURED ND-120 DRAM protocol (docs/nd120-dram-memory.md section 4)     **
** INCLUDING the LBD address-then-data multiplex and the multi-cycle       **
** BCGNT50 grant window that broke writes on 8-JUL-2026:                   **
**                                                                         **
**   grant rise (addr on LBD) -> addr latched -> LBD switches to data ->   **
**   HIEN row phase / RAS -> LOEN col phase / CAS -> write or read ->      **
**   readback must return what was written, at the right address.          **
**                                                                         **
** Uses the FPGA BRAM path of SIP1M9 (ramSize=3 default, no                **
** VERILATOR_SIM), i.e. exactly what Basys3 synthesizes.                   **
**                                                                         **
** Prints "TB_RESULT: PASS" on success.                                    **
**                                                                         **
** Last reviewed: 8-JUL-2026                                               **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module MEM_CHAIN_tb;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg sys_rst_n = 0;

  // MEM_ADDR_44 side
  reg [19:0] LBD = 0;
  reg BCGNT50 = 0;
  reg LOEN_n = 1;
  reg HIEN_n = 1;
  wire [9:0] AA;

  // MEM_RAM_49 side
  reg RAS = 0, CAS = 0;
  reg MWRITE50_n = 1;
  reg BANK0 = 0, BANK1 = 0, BANK2 = 0;
  reg [17:0] DD_IN = 0;
  wire [17:0] DD_OUT;
  wire CORR_n;

  MEM_ADDR_44 u_addr (
      .sysclk(sysclk),
      .LBD_19_0(LBD),
      .BCGNT50(BCGNT50),
      .LOEN_n(LOEN_n),
      .HIEN_n(HIEN_n),
      .PD4(1'b0),
      .AA_9_0(AA)
  );

`ifdef CHAIN_USE_BLOCKRAM
  MEM_RAM_49_BLOCKRAM u_ram (
`elsif CHAIN_USE_SIM
  MEM_RAM_49_SIM u_ram (
`else
  MEM_RAM_49 u_ram (
`endif
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .AA_9_0(AA),
      .BANK0(BANK0),
      .BANK1(BANK1),
      .BANK2(BANK2),
      .CAS(CAS),
      .RAS(RAS),
      .MWRITE50_n(MWRITE50_n),
      .DD_17_0_IN(DD_IN),
      .DD_17_0_OUT(DD_OUT),
      .CORR_n(CORR_n)
  );

  integer errors = 0;

  // ---- the 18-bit word: 16 data bits + 2 REGENERATED parity bits -----------
  // The word is two lots of 8 data + 1 parity: data in DD[7:0] and DD[16:9],
  // parity in DD[8] and DD[17] - MEM_DATA_46.v wires exactly those two bits to
  // the AM29833A PAR / PAR_OUT pins (CHIP_1H low byte, CHIP_2H high byte).
  //
  // NO BACKEND STORES PARITY (policy, Ronny 3-AUG-2026): every sheet-49 backend
  // drops the two parity bits on write and regenerates ODD parity on read, so
  // the readback is fully determined by the 16 data bits that were written -
  // whatever parity the writer supplied is irrelevant. The expectation below is
  // therefore identical for SIP1M9, BLOCKRAM, SIM and SDRAM: the data bits must
  // match exactly AND the parity bits must come back correct for that data.
  // A backend that stored parity, returned 0, or got the polarity backwards all
  // fail this check.
  //
  // EXCEPTION - MEM_RAM_49_SIM (behavior changed 11-AUG-2026, this tb updated
  // 27-AUG-2026): the SIM backend keeps a 1-bit per-byte-lane corruption flag.
  // A write whose parity bit DISAGREES with its data sets the flag, and the
  // read-side regenerated parity is XORed with it (MEM_RAM_49_SIM.v, the
  // b*_bad arrays and the q0e/q1e/q2e assigns). Net effect: the readback
  // parity bit always equals the WRITTEN parity bit. This is deliberate - it
  // is what lets the AM29833A forced-error write (the TPE CONFIGURATION
  // ECC-simulate probe) survive to the read and raise a real parity error;
  // unconditional regeneration healed the injected error and CONFIGURATION
  // mis-typed all memory as Multiport, ending in ERRFATAL (measured on the
  // Tang Nano 20K, 11-AUG-2026). Only a forced-error write can produce a
  // mismatched parity bit through the real AM29833A datapath; this tb drives
  // DD directly, so its deliberately-wrong-parity writes exercise exactly
  // that flag path. Expectation for SIM is therefore: readback == written,
  // all 18 bits.
  function [17:0] expect_word(input [17:0] written);
`ifdef CHAIN_USE_SIM
    expect_word = written;
`else
    expect_word = {~(^written[16:9]), written[16:9], ~(^written[7:0]), written[7:0]};
`endif
  endfunction

  task check(input [17:0] got, input [17:0] expect_dd, input [127:0] what);
    if (got !== expect_word(expect_dd)) begin
      errors = errors + 1;
      $display("FAIL at %0t: %0s (got=%o expected %o)", $time, what,
               got, expect_word(expect_dd));
    end
  endtask

  // One full access with the measured 6-cycle RAS/CAS signature, driven the
  // way the MAC drives it: grant + LBD addr -> addr latched -> LBD switches
  // to write data -> HIEN/RAS row phase -> LOEN/CAS col phase.
  // wn=1 read (rdata returns result), wn=0 write (wdata written).
  task access(input [1:0] bank, input [19:0] addr, input wn, input [17:0] wdata,
              output [17:0] rdata);
    begin
      @(posedge sysclk);
      LBD     <= addr;
      BCGNT50 <= 1;                    // grant rises with the ADDRESS on LBD
      BANK0   <= (bank == 0);
      BANK1   <= (bank == 1);
      BANK2   <= (bank == 2);
      @(posedge sysclk);               // addr registers capture (edge detect)
      @(posedge sysclk);
      LBD    <= wdata;                 // LBD moves on to the DATA (grant high!)
      DD_IN  <= wdata;                 // write data drives EARLY, before CAS
      MWRITE50_n <= wn;
      HIEN_n <= 0;                     // row phase begins
      @(posedge sysclk);               // N: RAS rises with row on AA
      RAS <= 1;
      @(posedge sysclk);               // N+1: switch to column
      HIEN_n <= 1;
      LOEN_n <= 0;
      @(posedge sysclk);               // N+2: CAS rises AND the data bus dies
      CAS <= 1;                        // (silicon: DD released around CAS-fall,
`ifndef CHAIN_USE_SIM
      // hardware backends must survive the bus dying at CAS (measured
      // 8-JUL-2026); the zero-delay SIM backend lives in a zero-delay world
      // where DD persists, so the hazard is not injected there
      DD_IN <= 18'h15A5A ^ wdata;
`endif
      @(posedge sysclk);               // N+3
      @(posedge sysclk);               // N+4
      #4 rdata = DD_OUT;               // late in N+4: CPU sample point
      @(posedge sysclk);               // N+5: RAS falls, CAS tail
      RAS <= 0;
      @(posedge sysclk);               // N+6: idle
      CAS        <= 0;
      LOEN_n     <= 1;
      MWRITE50_n <= 1;
      BCGNT50    <= 0;
      BANK0 <= 0; BANK1 <= 0; BANK2 <= 0;
      LBD   <= 20'hxxxxx;
      repeat (5) @(posedge sysclk);    // min RAS-to-RAS spacing
    end
  endtask

  reg [17:0] r;

  // Parity-regeneration sweep state: 16 data patterns covering all four
  // odd/even population combinations of the two bytes.
  integer    p;
  reg [15:0] pat;
  reg [17:0] wr18;
  reg [19:0] addr;
  reg [15:0] PATTERNS [0:15];
  initial begin
    PATTERNS[0]  = 16'h0000;  // even  / even
    PATTERNS[1]  = 16'h0001;  // odd   / even
    PATTERNS[2]  = 16'h0100;  // even  / odd
    PATTERNS[3]  = 16'h0101;  // odd   / odd
    PATTERNS[4]  = 16'hFFFF;
    PATTERNS[5]  = 16'hAA55;
    PATTERNS[6]  = 16'h5AA5;
    PATTERNS[7]  = 16'h8000;
    PATTERNS[8]  = 16'h0080;
    PATTERNS[9]  = 16'h7FFF;
    PATTERNS[10] = 16'hFFFE;
    PATTERNS[11] = 16'h1234;
    PATTERNS[12] = 16'hCAFE;
    PATTERNS[13] = 16'hBEEF;
    PATTERNS[14] = 16'h0F0F;
    PATTERNS[15] = 16'hF0F0;
  end

  initial begin
    repeat (6) @(posedge sysclk);
    sys_rst_n = 1;
    repeat (4) @(posedge sysclk);

    // THE regression scenario: write where data != address, read back.
    // (On the broken level-enable latches the write lands at addr=data.)
    access(0, 20'o0000022, 1'b0, 18'o054321, r);   // deposit 054321 at 22
    access(0, 20'o0000022, 1'b1, 18'o0, r);
    check(r, 18'o054321, "readback of deposit at 22");

    // More write/read pairs. NOTE the FPGA BRAM backend is only 4K words per
    // bank at the default size: lin_addr = {row,col} low 12 bits (22-AUG-2026
    // fix - the row captured at RAS is the HIGH CPU address half, PAL 44902A
    // drives HIEN during RAS), so the contiguous low CPU address bits
    // addr[11:0] are all alias-free; keep addresses under 4K words.
    access(0, 20'o0002000, 1'b0, 18'o012345, r);   // row 1, col 0
    access(1, 20'o0000003, 1'b0, 18'o177777, r);   // bank1, row 0, col 3
    access(0, 20'o0006002, 1'b0, 18'o123456, r);   // row 3, col 2
    access(0, 20'o0002000, 1'b1, 18'o0, r);
    check(r, 18'o012345, "readback bank0 row1");
    access(1, 20'o0000003, 1'b1, 18'o0, r);
    check(r, 18'o177777, "readback bank1 col3");
    access(0, 20'o0006002, 1'b1, 18'o0, r);
    check(r, 18'o123456, "readback bank0 row3col2");
    // and the original cell must still be intact
    access(0, 20'o0000022, 1'b1, 18'o0, r);
    check(r, 18'o054321, "addr 22 still intact after other writes");

    // ---- parity regeneration sweep --------------------------------------
    // Every backend must drop the two parity bits on write and regenerate them
    // on read. Each pattern is WRITTEN WITH DELIBERATELY WRONG PARITY (both
    // bits inverted); the readback must still carry the CORRECT odd parity for
    // the data. That proves the write-side bits are ignored, not stored - a
    // backend that stored them returns the wrong parity and fails here.
    //
    // The 16 data patterns cover all four odd/even population combinations of
    // the two bytes, so a backend that regenerated only one byte, or got the
    // polarity backwards, cannot pass by luck.
    for (p = 0; p < 16; p = p + 1) begin
      pat  = PATTERNS[p];
      // written word: data + INVERTED parity in both positions
      wr18 = {(^pat[15:8]), pat[15:8], (^pat[7:0]), pat[7:0]};
      addr = {10'd0, p[9:0]} + 20'd100;           // bank0, row 0, cols 100..115
      access(0, addr, 1'b0, wr18, r);
      access(0, addr, 1'b1, 18'o0, r);
      check(r, wr18, "parity regen sweep");
`ifdef CHAIN_USE_SIM
      // SIM backend contract (11-AUG-2026, see expect_word above): a bad
      // parity bit written is a bad parity bit read back - the corruption
      // flag must preserve the injected error, not heal it.
      if (r[8] !== wr18[8] || r[17] !== wr18[17]) begin
        errors = errors + 1;
        $display("FAIL: injected bad parity not preserved for pattern %04h (got %o)",
                 pat, r);
      end
`else
      if (r[8] !== ~(^r[7:0]) || r[17] !== ~(^r[16:9])) begin
        errors = errors + 1;
        $display("FAIL: readback parity not regenerated for pattern %04h (got %o)",
                 pat, r);
      end
`endif
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  initial begin
    #500000;
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule
