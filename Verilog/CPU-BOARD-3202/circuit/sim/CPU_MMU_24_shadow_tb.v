/**************************************************************************
** ND120 CPU - unit test                                                 **
** CPU_MMU_24: MMU TOP SHEET - shadow write STROBE and BUS wiring        **
**                                                                       **
** WHY THIS BENCH EXISTS                                                 **
**   A SINTRAN boot on real silicon repeats a trap cycle, and the        **
**   suspicion is a page-table entry that is written but does not take   **
**   effect. The shadow RAM itself is already covered by                 **
**   CPU_MMU_PT_29_shadow_rmw_tb.v (sheet 29, storage proven good), so   **
**   this bench takes the NEXT layer out: sheet 24, which                **
**     - GENERATES the single write strobe                               **
**           CPU_MMU_24.v:243  s_wmap_n = ~(LSHADOW & WRITE & CYD)       **
**     - merges the PTIDB / PPNX transceiver outputs onto the PT and PPN **
**       buses with wired-OR assigns                                     **
**           CPU_MMU_24.v:210-237                                        **
**     - takes EPT_n / EPMAP_n / EPTI_n / EIPL_n / EIPU_n / EIPUR_n /    **
**       LAPA_n from PAL_44306A (instance at CPU_MMU_24.v:404-423)       **
**   The PAL's own equations are exhaustively covered by                 **
**   Verilog/PAL/sim/PAL_44306A_tb.v and are NOT re-swept here. What is  **
**   tested here is the INTEGRATION: PAL outputs + WMAP_n + the bus      **
**   merges, acting on the real RAM chips.                               **
**                                                                       **
** THE QUESTION THIS BENCH WAS BUILT TO ANSWER                           **
**   CPU_MMU_24.v:216   s_pt_pt_15_0_in = s_ptidb_pt_15_0_out |          **
**                                        s_ptidb_idb_15_0_in            **
**   CPU_MMU_24.v:224   s_ptidb_idb_15_0_in = IDB_15_0_IN                **
**   i.e. the data written into the PT STATUS bank is the transceiver    **
**   output OR the RAW, UNGATED IDB. On the board only an ENABLED 74245  **
**   pair drives that bus, so a raw IDB contribution while EPTI_n is     **
**   HIGH would be wrong. Section A proves, by sweeping every qualifier  **
**   combination, that the wrong case is UNREACHABLE, and section G      **
**   drives it directly. The proof from the PAL equations:               **
**     WMAP_n low  => LSHADOW=1 AND WRITE=1 AND CYD=1                    **
**     EPT_n  low  => EMCL_n=1 AND (WRITE=0 | LSHADOW=0 | DOUBLE=0 |     **
**                                  CA0=0)                               **
**                    which with LSHADOW=WRITE=1 forces EMCL_n=1         **
**     EPTI_n      = ~(LSHADOW & EMCL_n & (WRITE | ~DOUBLE | ~CA0))      **
**                 = ~(1 & 1 & 1) = 0            <-- always ENABLED      **
**   and the transceiver direction is DIR=WRITE=1, so it drives          **
**   PT_15_0_OUT = IDB. The raw-IDB OR then contributes the SAME word,   **
**   which is why the sheet is safe today. It is safe by a PAL identity, **
**   not by construction - hence the sweep, so a future PAL edit that    **
**   breaks the identity fails HERE, loudly.                             **
**                                                                       **
**   The same OR shape on the PPN side (CPU_MMU_24.v:220-221) is NOT     **
**   self-protecting: the raw PPN_25_10_IN port IS OR-ed into the PPN    **
**   write data (section H measures it). It is gated one level up, in    **
**   CPU_15.v:391, which drives PPN_25_10_IN to 0 unless LAPA_n is low;  **
**   and LAPA_n is HIGH on every cycle where WMAP_n is low (asserted for **
**   all 256 combinations in section A).                                 **
**                                                                       **
** SHEET FACTS PINNED BY THIS BENCH (all measured, none assumed)         **
**   REX shadow write (DOUBLE=0): ONE word writes BOTH banks -           **
**     PT[idx]  = IDB[15:0]        (status word, bits 15:9 visible on    **
**                                  PT_15_9_OUT)                         **
**     PPN[idx] = IDB[8:0]         (EIPUR_n masks the protect bits, so   **
**                                  only IDB[8] reaches the high byte)   **
**   SEX shadow write (DOUBLE=1): TWO words, selected by CA0 -           **
**     CA0=0 -> PT bank only  (EPMAP_n high)                             **
**     CA0=1 -> PPN bank only (EPT_n high), full 16 bits from the IDB    **
**   ESTOF_n is the PPNX transceiver DIRECTION pin, and the decoder      **
**   drives it as ESTOF_n = LSHADOW AND RT (DECODE_DGA_COMM.v:551-556),  **
**   so it is LOW (IDB -> PPN) during a shadow write with RT low. This   **
**   bench drives it accordingly.                                        **
**                                                                       **
** TWO BUILD MODES (the Makefile runs both), as in the sheet-29 bench:   **
**   plain            - TMM2018D_25 SYNCHRONOUS block-RAM read, ONE      **
**                      clock of read latency                            **
**   -DTMM_ASYNC_READ - the faithful async SRAM read of the real chip,   **
**                      ZERO clocks of read latency                      **
** Every expectation that differs is written per model with `ifdef, and  **
** the latency itself is measured and asserted (section K).              **
**                                                                       **
** COVERAGE                                                              **
**   A  STRUCTURAL SWEEP: all 256 combinations of LSHADOW/WRITE/CYD/     **
**      DOUBLE/CA0/EMCL_n/WCHIM_n/DVACC_n, 5 invariants each -           **
**      WMAP_n is exactly LSHADOW&WRITE&CYD, and no write strobe can     **
**      ever coincide with a disabled transceiver on either bank         **
**   B  full REX shadow write sequence through this sheet, read back     **
**      through PT_15_9_OUT / PPN_25_10_OUT (never by reaching into RAM) **
**   C  the same entry read back through the sheet's own IDB output      **
**      (the path the software read uses), all 16 bits                   **
**   D  strobe qualifier truth table on the REAL RAM: an entry changes   **
**      for LSHADOW&WRITE&CYD and for NO other combination               **
**   E  CYD low - the "write that silently never lands" failure mode     **
**   F  trap-handler READ-MODIFY-WRITE: set WIP (PT12), then PGU (PT11), **
**      at read->write-back gaps 0/1/3, asserting the new bit stands,    **
**      no other bit moved, and the PPN half is undisturbed              **
**   G  the raw-IDB question, both banks, driven directly                **
**   H  the raw PPN_25_10_IN merge (CPU_MMU_24.v:220-221) measured       **
**   I  output isolation: a PT read does not disturb the PPN output and  **
**      vice versa, and neither read disturbs the other bank's storage   **
**   J  SEX shadow write pair and its bank selection                     **
**   K  read latency, measured and asserted against the model's RDLAT    **
**                                                                       **
** Stimulus is driven on the NEGEDGE so it is stable and unambiguous at  **
** the sampling posedge (the anti-race convention of this directory).    **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** Run: make test-mmu24-shadow   (CPU-BOARD-3202/circuit/sim)            **
**                                                                       **
** 11-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CPU_MMU_24_shadow_tb;

  // Read latency of the compiled RAM model, in posedges from the address
  // presentation to valid data. Measured and asserted in section K.
`ifdef TMM_ASYNC_READ
  localparam integer RDLAT = 0;
`else
  localparam integer RDLAT = 1;
`endif

  // Section A: 8 swept inputs, 5 invariants per combination.
  localparam integer NCOMBO = 256;
  localparam integer NINVAR = 5;
  localparam integer SWEEP_CHECKS = NCOMBO * NINVAR;

  // Directed checks in sections B..K.
  localparam integer DIRECTED_CHECKS = 94;

  localparam integer EXPECTED_CHECKS = SWEEP_CHECKS + DIRECTED_CHECKS;

  // PT status word bit positions (same decode as the sheet-29 bench)
  localparam integer BIT_WIP = 12;
  localparam integer BIT_PGU = 11;

  // captured real PT status entry
  localparam [15:0] PTE_BASE = 16'o162000;

  integer errors = 0;
  integer checks = 0;
  integer printed = 0;
  localparam integer MAX_PRINT = 25;

  /*************************************************************************
   ** DUT pins                                                            **
   *************************************************************************/
  reg         sysclk;
  reg         sys_rst_n;

  reg         BRK_n;
  reg  [10:0] CA_10_0;
  reg         CC2_n;
  reg         CCLR_n;
  reg         CUP;
  reg         CWR;
  reg         CYD;
  reg         DOUBLE;
  reg         DT_n;
  reg         DVACC_n;
  reg         ECSR_n;
  reg         EDO_n;
  reg         EMCL_n;
  reg         EMPID_n;
  reg         EORF_n;
  reg         ESTOF_n;
  reg         FMISS;
  reg  [10:0] LA_20_10;
  reg         LCS_n;
  reg         LSHADOW;
  reg         PD2;
  reg         RT_n;
  reg         STP;
  reg         SW1_CONSOLE;
  reg         UCLK;
  reg         UCLK_EN;
  reg         WCHIM_n;
  reg         WRITE;

  reg  [15:0] IDB_15_0_IN;
  reg  [15:0] CD_15_0_IN;
  reg  [15:0] PPN_25_10_IN;

  wire [15:0] IDB_15_0_OUT;
  wire [15:0] CD_15_0_OUT;
  wire [15:0] PPN_25_10_OUT;

  wire        BEDO_n;
  wire        BEMPID_n;
  wire        BLCS_n;
  wire        BSTP;
  wire        HIT;
  wire        LAPA_n;
  wire [ 6:0] PT_15_9_OUT;
  wire        WCA_n;
  wire        LED1;

  CPU_MMU_24 DUT (
      .sysclk       (sysclk),
      .sys_rst_n    (sys_rst_n),
      .BRK_n        (BRK_n),
      .CA_10_0      (CA_10_0),
      .CC2_n        (CC2_n),
      .CCLR_n       (CCLR_n),
      .CUP          (CUP),
      .CWR          (CWR),
      .CYD          (CYD),
      .DOUBLE       (DOUBLE),
      .DT_n         (DT_n),
      .DVACC_n      (DVACC_n),
      .ECSR_n       (ECSR_n),
      .EDO_n        (EDO_n),
      .EMCL_n       (EMCL_n),
      .EMPID_n      (EMPID_n),
      .EORF_n       (EORF_n),
      .ESTOF_n      (ESTOF_n),
      .FMISS        (FMISS),
      .LA_20_10     (LA_20_10),
      .LCS_n        (LCS_n),
      .LSHADOW      (LSHADOW),
      .PD2          (PD2),
      .RT_n         (RT_n),
      .STP          (STP),
      .SW1_CONSOLE  (SW1_CONSOLE),
      .UCLK         (UCLK),
      .UCLK_EN      (UCLK_EN),
      .WCHIM_n      (WCHIM_n),
      .WRITE        (WRITE),
      .IDB_15_0_IN  (IDB_15_0_IN),
      .IDB_15_0_OUT (IDB_15_0_OUT),
      .CD_15_0_IN   (CD_15_0_IN),
      .CD_15_0_OUT  (CD_15_0_OUT),
      .PPN_25_10_IN (PPN_25_10_IN),
      .PPN_25_10_OUT(PPN_25_10_OUT),
      .BEDO_n       (BEDO_n),
      .BEMPID_n     (BEMPID_n),
      .BLCS_n       (BLCS_n),
      .BSTP         (BSTP),
      .HIT          (HIT),
      .LAPA_n       (LAPA_n),
      .PT_15_9_OUT  (PT_15_9_OUT),
      .WCA_n        (WCA_n),
      .LED1         (LED1)
  );

  // 100 MHz clock
  initial sysclk = 0;
  always #5 sysclk = ~sysclk;

  /*************************************************************************
   ** Helpers                                                             **
   *************************************************************************/

  task check_eq(input [15:0] got, input [15:0] exp, input [(8*56):1] msg);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (printed < MAX_PRINT) begin
          $display("  FAIL: %0s  got=%06o expected=%06o", msg, got, exp);
          printed = printed + 1;
        end
      end
    end
  endtask

  // shadow index = PT_number*64 + virtual_page (same convention as the
  // sheet-29 bench: 32 page tables of 64 pages each)
  function [10:0] sidx(input integer pt_number, input integer vpn);
    begin
      sidx = pt_number * 64 + vpn;
    end
  endfunction

  // Quiescent board context. Everything that belongs to the cache half of
  // the sheet is held inactive so only the PT/PPN path moves.
  task quiescent;
    begin
      BRK_n       = 1'b1;
      CC2_n       = 1'b1;
      CCLR_n      = 1'b1;
      CUP         = 1'b0;
      CWR         = 1'b0;
      DT_n        = 1'b1;
      ECSR_n      = 1'b1;  // cache status register off the IDB
      EDO_n       = 1'b1;
      EMPID_n     = 1'b1;
      EORF_n      = 1'b1;  // with this high WCLIM_n stays high: no cache-
      FMISS       = 1'b0;  //   inhibit RAM write in this bench
      LCS_n       = 1'b1;
      PD2         = 1'b0;
      RT_n        = 1'b1;
      STP         = 1'b0;
      SW1_CONSOLE = 1'b0;
      UCLK        = 1'b0;
      UCLK_EN     = 1'b0;
      CD_15_0_IN  = 16'b0;
    end
  endtask

  // -------- writes ------------------------------------------------------ //

  // REX shadow write: DOUBLE=0, CA0=0. Writes the PT STATUS bank with the
  // full IDB word and the PPN bank with IDB[8:0].
  task rex_write(input [10:0] idx, input [15:0] w);
    begin
      @(negedge sysclk);
      LA_20_10     = idx;
      CA_10_0      = 11'b0;
      DOUBLE       = 1'b0;
      EMCL_n       = 1'b1;
      WCHIM_n      = 1'b1;
      DVACC_n      = 1'b1;
      ESTOF_n      = 1'b0;  // IDB -> PPN direction
      PPN_25_10_IN = 16'b0;  // LAPA_n is high here; CPU_15.v:391 drives 0
      IDB_15_0_IN  = w;
      LSHADOW      = 1'b1;
      WRITE        = 1'b1;
      CYD          = 1'b1;
      @(posedge sysclk);  // the RAM write lands on this edge
      @(negedge sysclk);
      LSHADOW     = 1'b0;
      WRITE       = 1'b0;
      CYD         = 1'b0;
      IDB_15_0_IN = 16'b0;
    end
  endtask

  // Same cycle shape, but with the three strobe qualifiers under test.
  task rex_write_q(input [10:0] idx, input [15:0] w, input ls, input wr,
                   input cy);
    begin
      @(negedge sysclk);
      LA_20_10     = idx;
      CA_10_0      = 11'b0;
      DOUBLE       = 1'b0;
      EMCL_n       = 1'b1;
      WCHIM_n      = 1'b1;
      DVACC_n      = 1'b1;
      ESTOF_n      = 1'b0;
      PPN_25_10_IN = 16'b0;
      IDB_15_0_IN  = w;
      LSHADOW      = ls;
      WRITE        = wr;
      CYD          = cy;
      @(posedge sysclk);
      @(negedge sysclk);
      LSHADOW     = 1'b0;
      WRITE       = 1'b0;
      CYD         = 1'b0;
      IDB_15_0_IN = 16'b0;
    end
  endtask

  // SEX shadow write, CA0 selects which bank the word lands in.
  task sex_write(input [10:0] idx, input [15:0] w, input ca0);
    begin
      @(negedge sysclk);
      LA_20_10     = idx;
      CA_10_0      = {10'b0, ca0};
      DOUBLE       = 1'b1;
      EMCL_n       = 1'b1;
      WCHIM_n      = 1'b1;
      DVACC_n      = 1'b1;
      ESTOF_n      = 1'b0;
      PPN_25_10_IN = 16'b0;
      IDB_15_0_IN  = w;
      LSHADOW      = 1'b1;
      WRITE        = 1'b1;
      CYD          = 1'b1;
      @(posedge sysclk);
      @(negedge sysclk);
      LSHADOW     = 1'b0;
      WRITE       = 1'b0;
      CYD         = 1'b0;
      CA_10_0     = 11'b0;
      DOUBLE      = 1'b0;
      IDB_15_0_IN = 16'b0;
    end
  endtask

  // -------- reads ------------------------------------------------------- //

  // TRANSLATION read: LSHADOW=0, WRITE=0. Both banks are chip-selected and
  // both transceivers are disabled, so the sheet outputs carry the stored
  // entries and nothing else. `hostile_idb` lets a caller jam the IDB while
  // the read happens (section G).
  task xlat_read(input [10:0] idx, input [15:0] hostile_idb,
                 output [6:0] pt_hi, output [15:0] ppn);
    integer i;
    begin
      @(negedge sysclk);
      LA_20_10     = idx;
      CA_10_0      = 11'b0;
      LSHADOW      = 1'b0;
      WRITE        = 1'b0;
      CYD          = 1'b0;
      DOUBLE       = 1'b0;
      EMCL_n       = 1'b1;
      WCHIM_n      = 1'b1;
      DVACC_n      = 1'b1;
      ESTOF_n      = 1'b0;
      PPN_25_10_IN = 16'b0;
      IDB_15_0_IN  = hostile_idb;
      for (i = 0; i < RDLAT; i = i + 1) @(posedge sysclk);
      #1;  // let the output merge settle after the edge
      pt_hi = PT_15_9_OUT;
      ppn   = PPN_25_10_OUT;
      IDB_15_0_IN = 16'b0;
    end
  endtask

  // SOFTWARE read of a PT entry: the shadow read path, EPTI_n low with
  // DIR=WRITE=0, so the full 16-bit entry appears on the sheet's IDB output.
  task shadow_read_idb(input [10:0] idx, output [15:0] w);
    integer i;
    begin
      @(negedge sysclk);
      LA_20_10     = idx;
      CA_10_0      = 11'b0;
      LSHADOW      = 1'b1;
      WRITE        = 1'b0;
      CYD          = 1'b0;
      DOUBLE       = 1'b0;
      EMCL_n       = 1'b1;
      WCHIM_n      = 1'b1;
      DVACC_n      = 1'b1;
      ESTOF_n      = 1'b1;
      PPN_25_10_IN = 16'b0;
      IDB_15_0_IN  = 16'b0;
      for (i = 0; i < RDLAT; i = i + 1) @(posedge sysclk);
      #1;
      w = IDB_15_0_OUT;
      @(negedge sysclk);
      LSHADOW = 1'b0;
    end
  endtask

  // PT bank selected ALONE: WCHIM_n low forces EPMAP_n high.
  task pt_only_read(input [10:0] idx, output [6:0] pt_hi, output [15:0] ppn);
    integer i;
    begin
      @(negedge sysclk);
      LA_20_10     = idx;
      CA_10_0      = 11'b0;
      LSHADOW      = 1'b0;
      WRITE        = 1'b0;
      CYD          = 1'b0;
      DOUBLE       = 1'b0;
      EMCL_n       = 1'b1;
      WCHIM_n      = 1'b0;  // -> EPMAP_n high, PPN bank deselected
      EORF_n       = 1'b1;  // keeps WCLIM_n high: no cache-inhibit write
      DVACC_n      = 1'b1;
      ESTOF_n      = 1'b0;
      PPN_25_10_IN = 16'b0;
      IDB_15_0_IN  = 16'b0;
      for (i = 0; i < RDLAT; i = i + 1) @(posedge sysclk);
      #1;
      pt_hi   = PT_15_9_OUT;
      ppn     = PPN_25_10_OUT;
      @(negedge sysclk);
      WCHIM_n = 1'b1;
    end
  endtask

  // PPN bank selected ALONE: EMCL_n low forces EPT_n high.
  task ppn_only_read(input [10:0] idx, output [6:0] pt_hi, output [15:0] ppn);
    integer i;
    begin
      @(negedge sysclk);
      LA_20_10     = idx;
      CA_10_0      = 11'b0;
      LSHADOW      = 1'b0;
      WRITE        = 1'b0;
      CYD          = 1'b0;
      DOUBLE       = 1'b0;
      EMCL_n       = 1'b0;  // -> EPT_n high, PT bank deselected
      WCHIM_n      = 1'b1;
      DVACC_n      = 1'b1;
      ESTOF_n      = 1'b0;
      PPN_25_10_IN = 16'b0;
      IDB_15_0_IN  = 16'b0;
      for (i = 0; i < RDLAT; i = i + 1) @(posedge sysclk);
      #1;
      pt_hi  = PT_15_9_OUT;
      ppn    = PPN_25_10_OUT;
      @(negedge sysclk);
      EMCL_n = 1'b1;
    end
  endtask

  // Latency probe: ONE address presentation, sampled at 0/1/2 posedges.
  task xlat_read_latency(input [10:0] idx, output [6:0] a0, output [6:0] a1,
                         output [6:0] a2);
    begin
      @(negedge sysclk);
      LA_20_10     = idx;
      CA_10_0      = 11'b0;
      LSHADOW      = 1'b0;
      WRITE        = 1'b0;
      CYD          = 1'b0;
      DOUBLE       = 1'b0;
      EMCL_n       = 1'b1;
      WCHIM_n      = 1'b1;
      DVACC_n      = 1'b1;
      ESTOF_n      = 1'b0;
      PPN_25_10_IN = 16'b0;
      IDB_15_0_IN  = 16'b0;
      #1;
      a0 = PT_15_9_OUT;
      @(posedge sysclk);
      #1;
      a1 = PT_15_9_OUT;
      @(posedge sysclk);
      #1;
      a2 = PT_15_9_OUT;
    end
  endtask

  // Park the sheet with both banks deselected for one clock.
  task idle_deselected;
    begin
      @(negedge sysclk);
      LSHADOW = 1'b0;
      WRITE   = 1'b1;  // WRITE high + LSHADOW low + EMCL_n low: EPT_n high
      CYD     = 1'b0;
      DOUBLE  = 1'b1;
      CA_10_0 = 11'b1;
      EMCL_n  = 1'b0;
      WCHIM_n = 1'b0;  // EPMAP_n high
      @(posedge sysclk);
      @(negedge sysclk);
      WRITE   = 1'b0;
      DOUBLE  = 1'b0;
      CA_10_0 = 11'b0;
      EMCL_n  = 1'b1;
      WCHIM_n = 1'b1;
    end
  endtask

  /*************************************************************************
   ** The trap handler's shape: read the entry, set one status bit, write  **
   ** it back, read again. `gap` = extra posedges between read and write.  **
   *************************************************************************/
  task pt_rmw_setbit(input [10:0] idx, input integer bitnum, input integer gap,
                     input [15:0] prev_val);
    reg [15:0] got;
    reg [15:0] newv;
    reg [ 6:0] pt_hi;
    reg [15:0] ppn;
    integer i;
    begin
      shadow_read_idb(idx, got);
      check_eq(got, prev_val, "RMW: entry read before modify");
      newv = got | (16'b1 << bitnum);
      for (i = 0; i < gap; i = i + 1) @(posedge sysclk);
      rex_write(idx, newv);
      shadow_read_idb(idx, got);
      check_eq(got, newv, "RMW: modified PTE stuck");
      check_eq(got & ~(16'b1 << bitnum), prev_val, "RMW: no other bit moved");
      xlat_read(idx, 16'b0, pt_hi, ppn);
      check_eq({9'b0, pt_hi}, {9'b0, newv[15:9]}, "RMW: status visible on PT_15_9_OUT");
      check_eq(ppn, newv & 16'o000777, "RMW: PPN half undisturbed");
    end
  endtask

  /*************************************************************************
   ** Stimulus                                                            **
   *************************************************************************/

  reg [ 6:0] pt_hi;
  reg [ 6:0] pt_hi2;
  reg [15:0] ppn;
  reg [15:0] ppn2;
  reg [15:0] w;
  reg [ 6:0] l0, l1, l2;
  integer    v;
  integer    c;
  integer    measured;
  reg [15:0] mw;
  reg        bad;

  // section A working variables
  reg        a_ls, a_wr, a_cy, a_dbl, a_ca0, a_emcl_n, a_wchim_n, a_dvacc_n;

  initial begin
    quiescent;
    sys_rst_n    = 1'b0;
    LA_20_10     = 11'b0;
    CA_10_0      = 11'b0;
    LSHADOW      = 1'b0;
    WRITE        = 1'b0;
    CYD          = 1'b0;
    DOUBLE       = 1'b0;
    EMCL_n       = 1'b1;
    WCHIM_n      = 1'b1;
    DVACC_n      = 1'b1;
    ESTOF_n      = 1'b0;
    IDB_15_0_IN  = 16'b0;
    PPN_25_10_IN = 16'b0;

    repeat (4) @(posedge sysclk);
    sys_rst_n = 1'b1;
    repeat (2) @(posedge sysclk);

    $display("[info] compiled read model: %0s, RDLAT=%0d posedge(s)",
`ifdef TMM_ASYNC_READ
             "ASYNC (TMM_ASYNC_READ)",
`else
             "SYNC (block RAM)",
`endif
             RDLAT);

    // =================================================================== //
    // A. STRUCTURAL SWEEP of the strobe and the enables.
    //    Purely combinational (PAL_44306A + the sheet assigns), so no
    //    clocking is needed. 256 combinations, 5 invariants each.
    //      1  WMAP_n is EXACTLY ~(LSHADOW & WRITE & CYD)
    //      2  a PT-bank write can never coincide with EPTI_n high, i.e.
    //         the raw-IDB OR at CPU_MMU_24.v:216 is never the only driver
    //      3  LAPA_n is high on every cycle where WMAP_n is low, which is
    //         what keeps PPN_25_10_IN at 0 (CPU_15.v:391) and therefore
    //         keeps the OR at CPU_MMU_24.v:220 harmless on the board
    //      4  a PPN-bank write can never coincide with EIPL_n high
    //      5  ... nor with BOTH EIPU_n and EIPUR_n high (the high byte is
    //         always transceiver-driven, either straight or protect-masked)
    // =================================================================== //
    for (v = 0; v < NCOMBO; v = v + 1) begin
      a_ls      = v[0];
      a_wr      = v[1];
      a_cy      = v[2];
      a_dbl     = v[3];
      a_ca0     = v[4];
      a_emcl_n  = v[5];
      a_wchim_n = v[6];
      a_dvacc_n = v[7];

      @(negedge sysclk);
      LSHADOW = a_ls;
      WRITE   = a_wr;
      CYD     = a_cy;
      DOUBLE  = a_dbl;
      CA_10_0 = {10'b0, a_ca0};
      EMCL_n  = a_emcl_n;
      WCHIM_n = a_wchim_n;
      DVACC_n = a_dvacc_n;
      EORF_n  = 1'b1;  // keep WCLIM_n high whatever WCHIM_n does
      #1;

      check_eq({15'b0, DUT.s_wmap_n}, {15'b0, ~(a_ls & a_wr & a_cy)},
               "A: WMAP_n = ~(LSHADOW & WRITE & CYD)");

      bad = (!DUT.s_wmap_n) && (!DUT.s_ept_n) && DUT.s_epti_n;
      check_eq({15'b0, bad}, 16'b0, "A: PT write with PTIDB disabled");

      bad = (!DUT.s_wmap_n) && (!LAPA_n);
      check_eq({15'b0, bad}, 16'b0, "A: LAPA_n low while WMAP_n low");

      bad = (!DUT.s_wmap_n) && (!DUT.s_epmap_n) && DUT.s_eipl_n;
      check_eq({15'b0, bad}, 16'b0, "A: PPN write with EIPL disabled");

      bad = (!DUT.s_wmap_n) && (!DUT.s_epmap_n) && DUT.s_eipu_n && DUT.s_eipur_n;
      check_eq({15'b0, bad}, 16'b0, "A: PPN write with high byte undriven");
    end

    @(negedge sysclk);
    LSHADOW = 1'b0;
    WRITE   = 1'b0;
    CYD     = 1'b0;
    DOUBLE  = 1'b0;
    CA_10_0 = 11'b0;
    EMCL_n  = 1'b1;
    WCHIM_n = 1'b1;
    DVACC_n = 1'b1;

    // =================================================================== //
    // B. Full REX shadow write sequence through this sheet, read back only
    //    through the sheet's own outputs.
    // =================================================================== //
    rex_write(sidx(0, 0), 16'o162003);
    rex_write(sidx(0, 1), 16'o142777);
    rex_write(sidx(3, 63), 16'o160400);
    rex_write(sidx(31, 63), 16'o177777);

    xlat_read(sidx(0, 0), 16'b0, pt_hi, ppn);
    check_eq({9'b0, pt_hi}, {9'b0, 16'o162003 >> 9}, "B: PT[0,0] status on PT_15_9_OUT");
    check_eq(ppn, 16'o162003 & 16'o000777, "B: PPN[0,0] = IDB[8:0]");

    xlat_read(sidx(0, 1), 16'b0, pt_hi, ppn);
    check_eq({9'b0, pt_hi}, {9'b0, 16'o142777 >> 9}, "B: PT[0,1] status");
    check_eq(ppn, 16'o142777 & 16'o000777, "B: PPN[0,1] = IDB[8:0]");

    xlat_read(sidx(3, 63), 16'b0, pt_hi, ppn);
    check_eq({9'b0, pt_hi}, {9'b0, 16'o160400 >> 9}, "B: PT[3,63] status");
    check_eq(ppn, 16'o160400 & 16'o000777, "B: PPN[3,63] = IDB[8:0]");

    xlat_read(sidx(31, 63), 16'b0, pt_hi, ppn);
    check_eq({9'b0, pt_hi}, {9'b0, 16'o177777 >> 9}, "B: PT[31,63] status (top entry)");
    check_eq(ppn, 16'o177777 & 16'o000777, "B: PPN[31,63] = IDB[8:0]");

    // the protect bits above IDB[8] never reach the PPN bank: EIPUR_n masks
    // them on every REX shadow write
    check_eq(ppn & 16'o177000, 16'b0, "B: PPN high bits masked by EIPUR");

    // page tables do not alias each other
    xlat_read(sidx(0, 1), 16'b0, pt_hi, ppn);
    xlat_read(sidx(31, 63), 16'b0, pt_hi2, ppn2);
    check_eq((pt_hi == pt_hi2) ? 16'o1 : 16'o0, 16'o0,
             "B: PT[0,1] and PT[31,63] do not alias");

    // =================================================================== //
    // C. The same entries read back through the sheet's own IDB output -
    //    the path the software read uses (EPTI_n low, DIR = WRITE = 0).
    // =================================================================== //
    shadow_read_idb(sidx(0, 0), w);
    check_eq(w, 16'o162003, "C: PT[0,0] full word on IDB_15_0_OUT");
    shadow_read_idb(sidx(0, 1), w);
    check_eq(w, 16'o142777, "C: PT[0,1] full word on IDB_15_0_OUT");
    shadow_read_idb(sidx(31, 63), w);
    check_eq(w, 16'o177777, "C: PT[31,63] full word on IDB_15_0_OUT");

    // =================================================================== //
    // D. Strobe qualifier truth table on the REAL RAM: for each of the
    //    eight LSHADOW/WRITE/CYD combinations, does an entry change?
    //    Only 111 may change it. The strobe itself is checked at the same
    //    time so a failure says WHICH of the two went wrong.
    // =================================================================== //
    for (c = 0; c < 8; c = c + 1) begin
      // known baseline in both banks
      rex_write(sidx(9, 5), PTE_BASE | 16'o000101);

      @(negedge sysclk);
      LSHADOW = c[0];
      WRITE   = c[1];
      CYD     = c[2];
      #1;
      check_eq({15'b0, DUT.s_wmap_n}, {15'b0, ~(c[0] & c[1] & c[2])},
               "D: WMAP_n for this qualifier combination");
      LSHADOW = 1'b0;  // restored BEFORE the next posedge: probing the
      WRITE   = 1'b0;  // strobe must not itself write anything
      CYD     = 1'b0;

      // now try to write a DIFFERENT word with those qualifiers
      rex_write_q(sidx(9, 5), 16'o134202, c[0], c[1], c[2]);

      xlat_read(sidx(9, 5), 16'b0, pt_hi, ppn);
      if (c == 7)
        check_eq({9'b0, pt_hi}, {9'b0, 16'o134202 >> 9},
                 "D: entry changed for LSHADOW&WRITE&CYD");
      else
        check_eq({9'b0, pt_hi}, {9'b0, (PTE_BASE | 16'o000101) >> 9},
                 "D: entry untouched without the full strobe");
    end

    // =================================================================== //
    // E. CYD low - the cycle-delay qualifier absent. This is the "write
    //    that silently never lands" failure mode the investigation is
    //    about, so it gets its own explicit check on BOTH banks.
    // =================================================================== //
    rex_write(sidx(12, 7), 16'o162111);
    rex_write_q(sidx(12, 7), 16'o177666, 1'b1, 1'b1, 1'b0);  // CYD low
    xlat_read(sidx(12, 7), 16'b0, pt_hi, ppn);
    check_eq({9'b0, pt_hi}, {9'b0, 16'o162111 >> 9}, "E: CYD low left PT untouched");
    check_eq(ppn, 16'o162111 & 16'o000777, "E: CYD low left PPN untouched");
    // and the very same word DOES land once CYD is present
    rex_write_q(sidx(12, 7), 16'o177666, 1'b1, 1'b1, 1'b1);
    xlat_read(sidx(12, 7), 16'b0, pt_hi, ppn);
    check_eq({9'b0, pt_hi}, {9'b0, 16'o177666 >> 9}, "E: same word lands with CYD");
    check_eq(ppn, 16'o177666 & 16'o000777, "E: same word lands with CYD (PPN)");

    // =================================================================== //
    // F. Trap-handler READ-MODIFY-WRITE through this sheet: read the entry
    //    on the IDB, set WIP (bit 12) then PGU (bit 11), write it back, and
    //    read it again. Three read->write-back distances; gap 0 is the
    //    tightest the RTL allows.
    // =================================================================== //
    rex_write(sidx(5, 10), PTE_BASE);
    pt_rmw_setbit(sidx(5, 10), BIT_WIP, 0, PTE_BASE);
    pt_rmw_setbit(sidx(5, 10), BIT_PGU, 0, PTE_BASE | (16'b1 << BIT_WIP));

    rex_write(sidx(6, 63), PTE_BASE);
    pt_rmw_setbit(sidx(6, 63), BIT_WIP, 1, PTE_BASE);
    pt_rmw_setbit(sidx(6, 63), BIT_PGU, 1, PTE_BASE | (16'b1 << BIT_WIP));

    rex_write(sidx(7, 0), PTE_BASE);
    pt_rmw_setbit(sidx(7, 0), BIT_WIP, 3, PTE_BASE);
    pt_rmw_setbit(sidx(7, 0), BIT_PGU, 3, PTE_BASE | (16'b1 << BIT_WIP));

    // =================================================================== //
    // G. THE RAW-IDB QUESTION (CPU_MMU_24.v:216 / :224).
    //
    //    G1 - the wrong case is UNREACHABLE. Section A already proved it
    //         over all 256 qualifier combinations; here it is stated once
    //         more at the exact operating point of a PT shadow write, so
    //         the answer is on the log next to the write it concerns.
    //    G2 - drive the case as hard as the sheet allows: EPTI_n is forced
    //         HIGH by taking EMCL_n low, with a distinctive IDB pattern and
    //         all three strobe qualifiers asserted. EPT_n goes HIGH at the
    //         same instant (both come from PAL_44306A), so the PT entry
    //         cannot be touched - measured, not assumed.
    //    G3 - a hostile IDB during a normal translation read must not reach
    //         the outputs, and must not disturb storage either.
    // =================================================================== //
    // G1: at the operating point of a REX shadow write
    @(negedge sysclk);
    LA_20_10     = sidx(15, 1);
    CA_10_0      = 11'b0;
    DOUBLE       = 1'b0;
    EMCL_n       = 1'b1;
    WCHIM_n      = 1'b1;
    DVACC_n      = 1'b1;
    ESTOF_n      = 1'b0;
    IDB_15_0_IN  = 16'o125252;
    PPN_25_10_IN = 16'b0;
    LSHADOW      = 1'b1;
    WRITE        = 1'b1;
    CYD          = 1'b1;
    #1;
    check_eq({15'b0, DUT.s_wmap_n}, 16'b0, "G1: WMAP_n asserted");
    check_eq({15'b0, DUT.s_ept_n}, 16'b0, "G1: PT bank selected");
    check_eq({15'b0, DUT.s_epti_n}, 16'b0,
             "G1: PTIDB ENABLED during the PT write");
    // with the transceiver enabled and DIR=WRITE=1 it drives the same word
    // the raw-IDB OR contributes, so the merge is a no-op here
    check_eq({9'b0, PT_15_9_OUT}, {9'b0, 16'o125252 >> 9},
             "G1: PT bus carries the transceiver word during the write");
    @(posedge sysclk);
    @(negedge sysclk);
    LSHADOW     = 1'b0;
    WRITE       = 1'b0;
    CYD         = 1'b0;
    IDB_15_0_IN = 16'b0;
    xlat_read(sidx(15, 1), 16'b0, pt_hi, ppn);
    check_eq({9'b0, pt_hi}, {9'b0, 16'o125252 >> 9}, "G1: that word landed");

    // G2: force EPTI_n high while all three strobe qualifiers are asserted
    rex_write(sidx(15, 2), 16'o162007);  // known baseline in both banks
    @(negedge sysclk);
    LA_20_10     = sidx(15, 2);
    CA_10_0      = 11'b0;
    DOUBLE       = 1'b0;
    EMCL_n       = 1'b0;  // EPTI_n -> HIGH, and EPT_n -> HIGH with it
    WCHIM_n      = 1'b1;
    DVACC_n      = 1'b1;
    ESTOF_n      = 1'b0;
    IDB_15_0_IN  = 16'o052525;  // distinctive, nothing like the baseline
    PPN_25_10_IN = 16'b0;
    LSHADOW      = 1'b1;
    WRITE        = 1'b1;
    CYD          = 1'b1;
    #1;
    check_eq({15'b0, DUT.s_wmap_n}, 16'b0, "G2: WMAP_n asserted");
    check_eq({15'b0, DUT.s_epti_n}, 16'b1, "G2: PTIDB DISABLED");
    check_eq({15'b0, DUT.s_ept_n}, 16'b1,
             "G2: PT bank deselected at the same instant");
    @(posedge sysclk);
    @(negedge sysclk);
    LSHADOW     = 1'b0;
    WRITE       = 1'b0;
    CYD         = 1'b0;
    EMCL_n      = 1'b1;
    IDB_15_0_IN = 16'b0;
    xlat_read(sidx(15, 2), 16'b0, pt_hi, ppn);
    check_eq({9'b0, pt_hi}, {9'b0, 16'o162007 >> 9},
             "G2: PT entry untouched, raw IDB did NOT land");
    // The PPN bank, by contrast, IS still selected while EMCL_n is low, and
    // its write DOES land - but through an ENABLED transceiver (EIPL_n and
    // EIPUR_n both low), never from the raw PPN bus. Recorded behaviour.
    check_eq(ppn, 16'o052525 & 16'o000777,
             "G2: PPN bank written from the transceiver");

    // G3: hostile IDB during a translation read
    rex_write(sidx(15, 3), 16'o164321);
    xlat_read(sidx(15, 3), 16'o177777, pt_hi, ppn);
    check_eq({9'b0, pt_hi}, {9'b0, 16'o164321 >> 9},
             "G3: hostile IDB did not reach PT_15_9_OUT");
    check_eq(ppn, 16'o164321 & 16'o000777,
             "G3: hostile IDB did not reach PPN_25_10_OUT");
    xlat_read(sidx(15, 3), 16'b0, pt_hi, ppn);
    check_eq({9'b0, pt_hi}, {9'b0, 16'o164321 >> 9},
             "G3: hostile IDB did not disturb the stored entry");

    // =================================================================== //
    // H. The PPN-side merge, CPU_MMU_24.v:220-221. Unlike the PT side this
    //    one is NOT self-protecting: a non-zero PPN_25_10_IN is OR-ed into
    //    the PPN write data. Measured here, and the gate that makes it
    //    unreachable on the board is asserted next to it:
    //    LAPA_n is HIGH during the write, and CPU_15.v:391 drives
    //    PPN_25_10_IN to 0 whenever LAPA_n is high.
    // =================================================================== //
    rex_write(sidx(16, 4), 16'o162010);
    xlat_read(sidx(16, 4), 16'b0, pt_hi, ppn);
    check_eq(ppn, 16'o162010 & 16'o000777, "H: baseline PPN with PPN_25_10_IN = 0");

    @(negedge sysclk);
    LA_20_10     = sidx(16, 4);
    CA_10_0      = 11'b0;
    DOUBLE       = 1'b0;
    EMCL_n       = 1'b1;
    WCHIM_n      = 1'b1;
    DVACC_n      = 1'b1;
    ESTOF_n      = 1'b0;
    IDB_15_0_IN  = 16'o162010;
    PPN_25_10_IN = 16'o000300;  // a driver the board never presents here
    LSHADOW      = 1'b1;
    WRITE        = 1'b1;
    CYD          = 1'b1;
    #1;
    check_eq({15'b0, LAPA_n}, 16'b1,
             "H: LAPA_n HIGH during the write (CPU_15.v:391 gates PPN in)");
    @(posedge sysclk);
    @(negedge sysclk);
    LSHADOW      = 1'b0;
    WRITE        = 1'b0;
    CYD          = 1'b0;
    IDB_15_0_IN  = 16'b0;
    PPN_25_10_IN = 16'b0;
    xlat_read(sidx(16, 4), 16'b0, pt_hi, ppn);
    check_eq(ppn, (16'o162010 & 16'o000777) | 16'o000300,
             "H: PPN_25_10_IN OR-ed into the PPN write data (sheet level)");
    check_eq({9'b0, pt_hi}, {9'b0, 16'o162010 >> 9},
             "H: the PT half was unaffected by PPN_25_10_IN");

    // =================================================================== //
    // I. Output isolation between the two banks.
    // =================================================================== //
    rex_write(sidx(17, 8), 16'o166123);

    pt_only_read(sidx(17, 8), pt_hi, ppn);
    check_eq({9'b0, pt_hi}, {9'b0, 16'o166123 >> 9}, "I: PT-only read value");
    check_eq(ppn, 16'b0, "I: PPN output is 0 while the PPN bank is deselected");

    ppn_only_read(sidx(17, 8), pt_hi, ppn);
    check_eq(ppn, 16'o166123 & 16'o000777, "I: PPN-only read value");
    check_eq({9'b0, pt_hi}, 16'b0,
             "I: PT output is 0 while the PT bank is deselected");

    // neither single-bank read disturbed the other bank's storage
    xlat_read(sidx(17, 8), 16'b0, pt_hi, ppn);
    check_eq({9'b0, pt_hi}, {9'b0, 16'o166123 >> 9}, "I: PT storage intact");
    check_eq(ppn, 16'o166123 & 16'o000777, "I: PPN storage intact");

    // =================================================================== //
    // J. SEX shadow write pair: CA0 picks the bank, and each write must
    //    leave the other bank alone.
    // =================================================================== //
    rex_write(sidx(19, 2), 16'o160001);  // baseline in both banks

    sex_write(sidx(19, 2), 16'o172000, 1'b0);  // CA0=0 -> PT bank only
    xlat_read(sidx(19, 2), 16'b0, pt_hi, ppn);
    check_eq({9'b0, pt_hi}, {9'b0, 16'o172000 >> 9}, "J: SEX CA0=0 wrote PT");
    check_eq(ppn, 16'o160001 & 16'o000777, "J: SEX CA0=0 left PPN alone");

    sex_write(sidx(19, 2), 16'o007654, 1'b1);  // CA0=1 -> PPN bank only
    xlat_read(sidx(19, 2), 16'b0, pt_hi, ppn);
    check_eq(ppn, 16'o007654, "J: SEX CA0=1 wrote PPN (all 16 bits)");
    check_eq({9'b0, pt_hi}, {9'b0, 16'o172000 >> 9},
             "J: SEX CA0=1 left PT alone");

    // =================================================================== //
    // K. Read latency measured from ONE address presentation and asserted
    //    against the compiled model's RDLAT.
    // =================================================================== //
    rex_write(sidx(21, 1), 16'o164000);  // the address under test
    rex_write(sidx(21, 2), 16'o166000);  // a decoy read just before it
    xlat_read(sidx(21, 2), 16'b0, pt_hi, ppn);
    idle_deselected;
    xlat_read_latency(sidx(21, 1), l0, l1, l2);
    $display("[latency] PT[21,1]: after0=%03o after1=%03o after2=%03o (value 164)",
             l0, l1, l2);

`ifdef TMM_ASYNC_READ
    check_eq({9'b0, l0}, 16'o000164, "K: async - data valid with 0 clocks");
`else
    check_eq({9'b0, l0}, 16'o000166, "K: sync - previous word still out at 0 clocks");
`endif
    check_eq({9'b0, l1}, 16'o000164, "K: data valid 1 clock after address");
    check_eq({9'b0, l2}, 16'o000164, "K: data still valid 2 clocks after address");

    if (l0 === 7'o164) measured = 0;
    else if (l1 === 7'o164) measured = 1;
    else if (l2 === 7'o164) measured = 2;
    else measured = -1;
    $display("[latency] measured read latency = %0d posedge(s)", measured);
    mw = measured;
    check_eq(mw, RDLAT, "K: measured read latency == RDLAT");

    // =================================================================== //
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)", errors, checks,
               EXPECTED_CHECKS);
    $finish;
  end

  initial begin
    #2000000;
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule
