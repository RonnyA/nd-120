/**************************************************************************
** CPU_MMU_PT_29 - CACHE INHIBIT BIT (WCINH_n) testbench                 **
**                                                                       **
** WHY THIS EXISTS. WCINH_n is the cache-inhibit bit, stored one bit per **
** physical page in IMS1403_25 CHIP_20G. It gates the whole cache:       **
**                                                                       **
**   CHIP_20G -> WCINH_n -> s_ewc_n = ~(BRK_n & CON & WCINH_n)           **
**            -> PAL_44402D: WCA_n  -> PAL_44511A: CWR -> /CUP           **
**            -> Cache Status bit 0                                      **
**                                                                       **
** On real hardware (Nexys 4 DDR, 28-AUG-2026) CACHE-120-A00 test 2      **
** reports "CUP does not work" and test 3 reports "Cache not updated     **
** (Use of limit registers)". The diagnostic's own PRINT-NOTE 6 says the **
** fault "may come from the inhibit logic". THIS PATH HAD NO TEST AT ALL:**
** the three existing CPU_MMU_PT_29 benches each mention WCINH_n exactly **
** twice, both times a port connection, and CPU_MMU_PT_29_tb.v says of   **
** WCLIM_n "unused here, hold inactive".                                 **
**                                                                       **
** WHAT IS ACTUALLY UNDER SUSPICION. CHIP_20G is addressed by            **
**                                                                       **
**   assign s_ims_ppn_25_10_in = s_ppn_25_10_in | s_ppn_25_10_out;       **
**   // maybe do a conditional expression here to select which PPN ...   **
**                                                                       **
** (CPU_MMU_PT_29.v:71) - the original author's own doubt, left in a     **
** comment. PPN_25_10_IN and PPN_25_10_OUT are the two directions of one **
** BIDIRECTIONAL bus on the real board; ORing them models neither.       **
**                                                                       **
** THIS BENCH TAKES NO SIDE on which direction should win. Deciding that **
** needs the schematic, not a guess. It asserts only the property that   **
** holds either way: THE ADDRESS MUST BE A REAL PAGE NUMBER - one of the **
** two sources - and never a bitwise mixture of both. Check 3 picks      **
** P = 0005B and M = 0012B so that P|M is a THIRD page distinct from     **
** both, then arranges the memory so a mixed address is the only way to  **
** get the wrong answer.                                                 **
**                                                                       **
** Note on the RAM (IMS1403_25): synchronous, CE_n tied low inside       **
** CPU_MMU_PT_29 so it reads or writes on EVERY clock, one clock of read **
** latency, and Q is forced to 0 while W_n is low (during a write).      **
** PPN_25_10_OUT is 0 unless the map chips are BOTH selected (EPMAP_n=0) **
** and in read mode (WMAP_n=1) - TMM2018D_25 gates D_OUT that way.       **
**                                                                       **
** Prints TB_RESULT: PASS or TB_RESULT: FAIL.                            **
**                                                                       **
** Written 28-AUG-2026.                                                  **
***************************************************************************/
`timescale 1ns / 1ps

module CPU_MMU_PT_29_wcinh_tb;

  reg         sysclk = 1'b0;
  reg         sys_rst_n;
  reg  [10:0] LA_20_10;
  reg         EPMAP_n;
  reg         EPT_n;
  reg         WCLIM_n;
  reg         WMAP_n;
  reg  [15:0] PPN_25_10_IN;
  reg  [15:0] PT_15_0_IN;

  wire [15:0] PPN_25_10_OUT;
  wire [15:0] PT_15_0_OUT;
  wire        WCINH_n;

  integer errors = 0, checks = 0;

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

  always #5 sysclk = ~sysclk;

  //! Drive changes just after a posedge so nothing races the sampling edge -
  //! the same convention CPU_MMU_PT_29_tb.v uses.
  task step;
    begin
      @(posedge sysclk);
      #1;
    end
  endtask

  //! Write the inhibit bit for one physical page. Bit 15 of the PPN bus is
  //! the data (PPN bit 25); bits 13:0 are the address.
  task write_inhibit (input [13:0] page, input value);
    begin
      EPMAP_n      = 1'b1;             // map deselected -> PPN_OUT is 0
      WMAP_n       = 1'b1;
      PPN_25_10_IN = {value, 1'b0, page};
      WCLIM_n      = 1'b0;             // write strobe
      step;
      WCLIM_n      = 1'b1;
      step;
    end
  endtask

  //! Read the inhibit bit back with the map DESELECTED, so PPN_OUT is 0 and
  //! the address can only have come from PPN_IN.
  task read_inhibit_via_in (input [13:0] page, output value);
    begin
      EPMAP_n      = 1'b1;
      WMAP_n       = 1'b1;
      WCLIM_n      = 1'b1;
      PPN_25_10_IN = {2'b00, page};
      step;                            // one clock of read latency
      value = WCINH_n;
    end
  endtask

  //! Put a value into the PPN map at a logical page, so that reading that
  //! logical page afterwards presents it on PPN_25_10_OUT.
  task write_map (input [10:0] lpage, input [15:0] ppn);
    begin
      WCLIM_n      = 1'b1;
      LA_20_10     = lpage;
      PPN_25_10_IN = ppn;
      EPMAP_n      = 1'b0;             // select map
      WMAP_n       = 1'b0;             // write
      step;
      WMAP_n       = 1'b1;
      EPMAP_n      = 1'b1;
      step;
    end
  endtask

  task chk (input [511:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got=%b exp=%b (PPN_IN=%o PPN_OUT=%o)",
                 name, got, exp, PPN_25_10_IN, PPN_25_10_OUT);
      end
    end
  endtask

  localparam [13:0] PAGE_P = 14'o0005;
  localparam [13:0] PAGE_M = 14'o0012;
  localparam [13:0] PAGE_MIX = PAGE_P | PAGE_M;   // 0017B - a THIRD page

  reg v;

  initial begin
    $dumpfile("CPU_MMU_PT_29_wcinh_tb.vcd");
    $dumpvars(0, CPU_MMU_PT_29_wcinh_tb);

    sys_rst_n    = 1'b0;
    LA_20_10     = 11'd0;
    EPMAP_n      = 1'b1;
    EPT_n        = 1'b1;
    WCLIM_n      = 1'b1;
    WMAP_n       = 1'b1;
    PPN_25_10_IN = 16'd0;
    PT_15_0_IN   = 16'd0;
    repeat (4) step;
    sys_rst_n = 1'b1;
    repeat (2) step;

    $display("=====================================================");
    $display(" CPU_MMU_PT_29 - cache inhibit bit (WCINH_n)");
    $display("=====================================================");

    // ---- 1. the bit can be written and read back at all ------------------
    //! Both pages are written FIRST. The IMS1403 array has no reset - the
    //! commented-out reset loop in IMS1403_25.v says Vivado would not take
    //! one - so an untouched cell reads X in simulation and would read 0 from
    //! FPGA block RAM. Checking an unwritten cell tests the testbench, not
    //! the design.
    write_inhibit(PAGE_M, 1'b0);
    write_inhibit(PAGE_P, 1'b1);
    read_inhibit_via_in(PAGE_P, v);
    chk("INHIBIT_WRITE_READBACK", v, 1'b1);

    // ---- 2. it is PER PAGE - writing P must not disturb M ----------------
    read_inhibit_via_in(PAGE_M, v);
    chk("INHIBIT_IS_PER_PAGE", v, 1'b0);

    // ---- 3. the address must not be a MIXTURE of the two PPN sources.
    //         Set page P and page M both inhibited, and the page P|M NOT
    //         inhibited. Then present P on PPN_IN while the map presents M
    //         on PPN_OUT. A design that selects either source returns 1.
    //         Only a bitwise OR addresses P|M and returns 0.
    write_inhibit(PAGE_P,   1'b1);
    write_inhibit(PAGE_M,   1'b1);
    write_inhibit(PAGE_MIX, 1'b0);

    write_map(11'd7, {2'b00, PAGE_M});   // logical page 7 -> physical M

    // present logical page 7 for READING: map selected, not writing
    WCLIM_n      = 1'b1;
    LA_20_10     = 11'd7;
    EPMAP_n      = 1'b0;
    WMAP_n       = 1'b1;
    PPN_25_10_IN = {2'b00, PAGE_P};      // CPU side presents P at the same time
    step;                                // map output settles
    step;                                // inhibit RAM read latency

    if (PPN_25_10_OUT[13:0] !== PAGE_M) begin
      // If the map is not actually presenting M then check 3 proves nothing;
      // say so rather than passing on a setup that did not take.
      errors = errors + 1;
      $display("FAIL WCINH_SETUP: map did not present page M (PPN_OUT=%o, want %o)",
               PPN_25_10_OUT, PAGE_M);
      checks = checks + 1;
    end else begin
      chk("WCINH_ADDR_NOT_MIXED_PPN", WCINH_n, 1'b1);
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
