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

  task check(input [17:0] got, input [17:0] expect_dd, input [127:0] what);
    if (got !== expect_dd) begin
      errors = errors + 1;
      $display("FAIL at %0t: %0s (got=%o expected %o)", $time, what, got, expect_dd);
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

  initial begin
    repeat (6) @(posedge sysclk);
    sys_rst_n = 1;
    repeat (4) @(posedge sysclk);

    // THE regression scenario: write where data != address, read back.
    // (On the broken level-enable latches the write lands at addr=data.)
    access(0, 20'o0000022, 1'b0, 18'o054321, r);   // deposit 054321 at 22
    access(0, 20'o0000022, 1'b1, 18'o0, r);
    check(r, 18'o054321, "readback of deposit at 22");

    // More write/read pairs. NOTE the FPGA BRAM (ramSize=3) is only 4K words:
    // lin_addr = {col,row} low 12 bits, so keep col in 0..3 and row in
    // 0..1023 to stay alias-free (col[1:0] become the top address bits).
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
