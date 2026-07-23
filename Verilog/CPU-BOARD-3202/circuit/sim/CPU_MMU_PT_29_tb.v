/**************************************************************************
** CPU_MMU_PT_29 (shadow RAM / page table) testbench                     **
**                                                                       **
** Goal (Ronny 21-JUL-2026): understand the MMU shadow RAM by DRIVING it:**
**   1. set up the shadow RAM (write PPN + PT entries),                  **
**   2. read them back,                                                  **
**   3. CHARACTERISE the read latency (sync vs async), because           **
**      TMM2018D_25.v models the real ASYNC TMM2018 SRAM as SYNCHRONOUS  **
**      block RAM (data_out_reg registered on clk; the async read on     **
**      line 68 is commented out). If the MMU expects the combinational  **
**      read of the real chip, a 1-clock-late registered PPN would be    **
**      latched as a WRONG translation.                                  **
**                                                                       **
** CPU_MMU_PT_29 port recap (see the module):                            **
**   LA_20_10[10:0]  = page index into the PT/PPN chips                  **
**   PPN table (22G/23G): CS = EPMAP_n, write = WMAP_n, data PPN_25_10   **
**   PT  table (24G/25G): CS = EPT_n,   write = WMAP_n, data PT_15_0     **
**   TMM2018D_25: on posedge clk, !CS_n & !W_n => write array[ADDR]<=D   **
**                                !CS_n &  W_n => data_out_reg<=array    **
**                D_OUT = (!OE_n & !CS_n & W_n) ? data_out_reg : 0       **
**                (OE_n is tied low inside CPU_MMU_PT_29, so CS+!W read.)**
**                                                                       **
** Prints TB_RESULT: PASS/FAIL.                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CPU_MMU_PT_29_tb;

  reg         sysclk;
  reg         sys_rst_n;
  reg  [10:0] LA_20_10;
  reg         EPMAP_n;   // PPN chip select (active low)
  reg         EPT_n;     // PT  chip select (active low)
  reg         WCLIM_n;   // PPN-hi 1-bit RAM write (unused here, hold inactive)
  reg         WMAP_n;    // write strobe (active low) shared by PT + PPN
  reg  [15:0] PPN_25_10_IN;
  reg  [15:0] PT_15_0_IN;

  wire [15:0] PPN_25_10_OUT;
  wire [15:0] PT_15_0_OUT;
  wire        WCINH_n;

  integer errors = 0;
  integer checks = 0;

  CPU_MMU_PT_29 DUT (
      .sysclk       (sysclk),
      .sys_rst_n    (sys_rst_n),
      .LA_20_10     (LA_20_10),
      .EPMAP_n      (EPMAP_n),
      .EPT_n        (EPT_n),
      .WCLIM_n      (WCLIM_n),
      .WMAP_n       (WMAP_n),
      .PPN_25_10_IN (PPN_25_10_IN),
      .PPN_25_10_OUT(PPN_25_10_OUT),
      .PT_15_0_IN   (PT_15_0_IN),
      .PT_15_0_OUT  (PT_15_0_OUT),
      .WCINH_n      (WCINH_n)
  );

  // 100 MHz clock
  initial sysclk = 0;
  always #5 sysclk = ~sysclk;

  // --- write one PPN entry: page -> value (one clocked write) ----------- //
  // Stimulus is driven on the NEGEDGE so it is stable and unambiguous at the
  // sampling posedge (avoids the classic tb clock-edge race that made an
  // earlier version falsely report "broken" - proven with a control RAM).
  task ppn_write(input [10:0] page, input [15:0] value);
    begin
      @(negedge sysclk);
      LA_20_10     = page;
      PPN_25_10_IN = value;
      EPMAP_n      = 1'b0;   // select PPN chips
      WMAP_n       = 1'b0;   // write
      @(posedge sysclk);     // TMM2018D writes array[page] <= value here
      @(negedge sysclk);
      WMAP_n       = 1'b1;   // release write AFTER the edge
      EPMAP_n      = 1'b1;
    end
  endtask

  // --- read a PPN entry after N posedges of the address being presented,
  //     returning what D_OUT shows. Used to CHARACTERISE the read latency. - //
  task ppn_read_after(input [10:0] page, input integer clocks, output [15:0] got);
    integer i;
    begin
      @(negedge sysclk);
      LA_20_10 = page;
      EPMAP_n  = 1'b0;   // select
      WMAP_n   = 1'b1;   // read (not writing)
      for (i = 0; i < clocks; i = i + 1) @(posedge sysclk);
      #1;                // let the combinational D_OUT settle after the edge
      got      = PPN_25_10_OUT;
    end
  endtask

  task check_eq(input [15:0] got, input [15:0] exp, input [255:0] msg);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        $display("  FAIL: %0s  got=%06o expected=%06o", msg, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  reg [15:0] r0, r1, r2;

  initial begin
    sys_rst_n   = 0;
    LA_20_10    = 0;
    EPMAP_n     = 1;
    EPT_n       = 1;
    WCLIM_n     = 1;
    WMAP_n      = 1;
    PPN_25_10_IN= 0;
    PT_15_0_IN  = 0;
    repeat (4) @(posedge sysclk);
    sys_rst_n = 1;
    repeat (2) @(posedge sysclk);

    // ---- 1. Set up the shadow RAM: write a distinct PPN per page -------- //
    ppn_write(11'o0000, 16'o000100);   // page 0   -> phys page 000100
    ppn_write(11'o0001, 16'o000200);   // page 1   -> phys page 000200
    ppn_write(11'o1777, 16'o007777);   // top page -> phys page 007777
    ppn_write(11'o0042, 16'o001234);   // page 42  -> phys page 001234

    // ---- 2. CHARACTERISE read latency for page 1 (expect 000200) ------- //
    // The real async SRAM would return the value with the address alone
    // (0 clocks). This synchronous model needs the registering clock.
    ppn_read_after(11'o0001, 0, r0);   // same cycle the address is set
    ppn_read_after(11'o0001, 1, r1);   // one clock later
    ppn_read_after(11'o0001, 2, r2);   // two clocks later
    $display("[latency] PPN[1] read: after0=%06o after1=%06o after2=%06o (expect 000200)",
             r0, r1, r2);
    if (r0 === 16'o000200)
      $display("[latency] -> ASYNC (combinational) read");
    else if (r1 === 16'o000200 || r2 === 16'o000200)
      $display("[latency] -> SYNCHRONOUS read (registered, %0d-clock latency) - MMU timing must allow for this",
               (r1 === 16'o000200) ? 1 : 2);
    else
      $display("[latency] -> read never returned the written value (broken)");

    // ---- 3. Read back every entry (allow up to 2 clocks) --------------- //
    // Read using whatever latency the model needs (2 clocks covers both).
    ppn_read_after(11'o0000, 2, r0); check_eq(r0, 16'o000100, "PPN[0] readback");
    ppn_read_after(11'o0001, 2, r0); check_eq(r0, 16'o000200, "PPN[1] readback");
    ppn_read_after(11'o1777, 2, r0); check_eq(r0, 16'o007777, "PPN[top] readback");
    ppn_read_after(11'o0042, 2, r0); check_eq(r0, 16'o001234, "PPN[42] readback");

    // ---- 4. Distinct entries must not alias -------------------------- //
    ppn_read_after(11'o0000, 2, r0);
    ppn_read_after(11'o0001, 2, r1);
    check_eq((r0 == r1) ? 16'o1 : 16'o0, 16'o0, "PPN[0] and PPN[1] are distinct");

    if (errors == 0) $display("TB_RESULT: PASS (%0d checks)", checks);
    else             $display("TB_RESULT: FAIL (%0d errors / %0d checks)", errors, checks);
    $finish;
  end

  initial begin
    #200000;
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule
