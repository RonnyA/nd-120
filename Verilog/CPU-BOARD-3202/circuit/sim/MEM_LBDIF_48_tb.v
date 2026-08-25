/**************************************************************************
** ND120 CPU - unit test                                                 **
** MEM_LBDIF_48: local BD control sheet (sheet 48) - two AM29C821 10-bit **
** pipeline registers (13F/14F, posedge OSC, OE_n=PD4) + PAL_44310D      **
** (3F, LBDIF).                                                          **
**                                                                       **
** Golden behavior comes from the INDEPENDENT Python model               **
** gen_lbdif_golden.py (scratchpad, not in repo): it re-transcribes the  **
** 13F/14F delay-chain wiring and the audited PAL_44310D equations       **
** (including the 30-JUL BDRY-hold fix) and emits the tables/constants   **
** embedded below.                                                       **
**                                                                       **
** TWO BUILD MODES (the Makefile compiles and runs both):                **
**   plain                     - PAL_44310D BDRY as edge FF (FPGA branch)**
**   -DUSE_TRANSPARENT_LATCHES - BDRY as transparent latch (original     **
**                               hardware / latch-mode sim branch)       **
** The two modes have different BDRY timing, so the directed table       **
** carries SEPARATE expected columns (dir_ff / dir_lm) and separate      **
** LFSR checksums.                                                       **
**                                                                       **
**  1. Directed phase (111 cycles, full 15-output compare per cycle):    **
**     every delay chain (BLRQ->BLRQ50 2t, CGNT->25/50, BGNT->25/50/75,  **
**     MWRITE->50 2t, MOR->25 1t, GNT->50 2t, BLOCKL->25 1t,             **
**     BCGNT25->50 1t, REF->REF100 4t), then the BDRY life cycle with a  **
**     ONE-INPUT-CHANGE-PER-CYCLE discipline (latch mode is history-     **
**     sensitive): bus-write set / BDAP50 hold / clear, the IOX ECCR     **
**     set with the audited BIOXE hold, bus-read set + MR_n clear, and   **
**     the "late BDRY for 10MHz disk" BGNT75 window.                     **
**  2. Comb sweep (32 vectors, clock frozen): RDATA / BIOXL_n /          **
**     BCGNT50R_n over all {CGNT_n,BGNT_n,RAS,HIEN_n,LOEN_n}.            **
**  3. LFSR phase (2000 cycles, fixed seed 1BADB002): random inputs      **
**     (MR_n low 1/4); per cycle a defined-ness check, all 15 outputs    **
**     folded into acc = acc*31 + out; final compare vs the per-mode     **
**     Python constant.                                                  **
**  4. PD4=1 comb check (chip outputs forced 0, per-mode expected word). **
**                                                                       **
** No VERILATOR_SIM branch exists in this sheet; iverilog covers both    **
** real branches of the one ifdef split (USE_TRANSPARENT_LATCHES in      **
** PAL_44310D). AM29C821 is used with USE_SYSCLK=0 (posedge CK), as in   **
** the board build.                                                      **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** Run: make test-lbdif   (CPU-BOARD-3202/circuit/sim)                   **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module MEM_LBDIF_48_tb;

  // osc starts HIGH so the first posedge comes after the first setup.
  reg osc = 1;
  reg clk_en = 1;
  always begin
    #5;
    if (clk_en) osc = ~osc;
  end

  reg sys_rst_n = 1;
  reg blrq_n = 1, blockl_n = 1, mwrite_n = 1, ref_n = 1, mor_n = 1;
  reg gnt_n = 1, bgnt_n = 1, cgnt_n = 1, hien_n = 1, loen_n = 1;
  reg ras = 0, bdap50_n = 1, eccr = 0, bioxe_n = 1, bcgnt25 = 0, mr_n = 1;
  reg pd4 = 0;

  wire bcgnt50, bcgnt50r_n, bdry_n, bgnt25_n, bgnt50_n, bioxl_n;
  wire blockl25_n, blrq50_n, cgnt25_n, cgnt50_n, gnt50_n, mor25_n;
  wire mwrite50_n, rdata, rdata25;

  MEM_LBDIF_48 dut (
      .sysclk   (osc),
      .BCGNT25  (bcgnt25),
      .BDAP50_n (bdap50_n),
      .BGNT_n   (bgnt_n),
      .BIOXE_n  (bioxe_n),
      .BLOCKL_n (blockl_n),
      .BLRQ_n   (blrq_n),
      .CGNT_n   (cgnt_n),
      .ECCR     (eccr),
      .GNT_n    (gnt_n),
      .HIEN_n   (hien_n),
      .LOEN_n   (loen_n),
      .MOR_n    (mor_n),
      .MR_n     (mr_n),
      .MWRITE_n (mwrite_n),
      .OSC      (osc),
      .sys_rst_n(sys_rst_n),
      .PD4      (pd4),
      .RAS      (ras),
      .REF_n    (ref_n),

      .BCGNT50   (bcgnt50),
      .BCGNT50R_n(bcgnt50r_n),
      .BDRY_n    (bdry_n),
      .BGNT25_n  (bgnt25_n),
      .BGNT50_n  (bgnt50_n),
      .BIOXL_n   (bioxl_n),
      .BLOCKL25_n(blockl25_n),
      .BLRQ50_n  (blrq50_n),
      .CGNT25_n  (cgnt25_n),
      .CGNT50_n  (cgnt50_n),
      .GNT50_n   (gnt50_n),
      .MOR25_n   (mor25_n),
      .MWRITE50_n(mwrite50_n),
      .RDATA     (rdata),
      .RDATA25   (rdata25)
  );

  // 15-bit output word, LSB first - must match gen_lbdif_golden.py
  wire [14:0] outword = {rdata25, rdata, mwrite50_n, mor25_n, gnt50_n,
                         cgnt50_n, cgnt25_n, blrq50_n, blockl25_n, bioxl_n,
                         bgnt50_n, bgnt25_n, bdry_n, bcgnt50r_n, bcgnt50};
  wire [2:0] combword = {bcgnt50r_n, bioxl_n, rdata};

  integer errors = 0;
  integer checks = 0;
  integer k;
  reg [31:0] acc = 0;
  reg [31:0] lfsr = 32'h1BADB002;
  reg [15:0] dir_in [0:110];
  reg [14:0] dir_ff [0:110];
  reg [14:0] dir_lm [0:110];
  reg [2:0]  comb_exp[0:31];
  reg [15:0] iw;
  reg [14:0] expw;
  reg [31:0] b;

`ifdef USE_TRANSPARENT_LATCHES
  localparam [31:0] ACC_EXPECT = 32'h2968F616;
  localparam [14:0] PD4_EXPECT = 15'h0022;
`else
  localparam [31:0] ACC_EXPECT = 32'h341C9176;
  localparam [14:0] PD4_EXPECT = 15'h0026;
`endif

  task apply_in(input [15:0] w);
    begin
      blrq_n   = w[0];
      blockl_n = w[1];
      mwrite_n = w[2];
      ref_n    = w[3];
      mor_n    = w[4];
      gnt_n    = w[5];
      bgnt_n   = w[6];
      cgnt_n   = w[7];
      hien_n   = w[8];
      loen_n   = w[9];
      ras      = w[10];
      bdap50_n = w[11];
      eccr     = w[12];
      bioxe_n  = w[13];
      bcgnt25  = w[14];
      mr_n     = w[15];
    end
  endtask

  // Tables generated by gen_lbdif_golden.py.
  initial begin
    dir_in[  0] = 16'hABFF; dir_ff[  0] = 15'h096A; dir_lm[  0] = 15'h096A;
    dir_in[  1] = 16'hABFF; dir_ff[  1] = 15'h1FFA; dir_lm[  1] = 15'h1FFA;
    dir_in[  2] = 16'hABFF; dir_ff[  2] = 15'h1FFA; dir_lm[  2] = 15'h1FFA;
    dir_in[  3] = 16'hABFE; dir_ff[  3] = 15'h1FFA; dir_lm[  3] = 15'h1FFE;
    dir_in[  4] = 16'hABFE; dir_ff[  4] = 15'h1F7E; dir_lm[  4] = 15'h1F7E;
    dir_in[  5] = 16'hABFF; dir_ff[  5] = 15'h1F7E; dir_lm[  5] = 15'h1F7E;
    dir_in[  6] = 16'hABFF; dir_ff[  6] = 15'h1FFE; dir_lm[  6] = 15'h1FFE;
    dir_in[  7] = 16'hABFF; dir_ff[  7] = 15'h1FFE; dir_lm[  7] = 15'h1FFE;
    dir_in[  8] = 16'hABFF; dir_ff[  8] = 15'h1FFE; dir_lm[  8] = 15'h1FFE;
    dir_in[  9] = 16'hABFF; dir_ff[  9] = 15'h1FFE; dir_lm[  9] = 15'h1FFE;
    dir_in[ 10] = 16'hAB7F; dir_ff[ 10] = 15'h7EFE; dir_lm[ 10] = 15'h7EFE;
    dir_in[ 11] = 16'hAB7F; dir_ff[ 11] = 15'h7CFC; dir_lm[ 11] = 15'h7CFC;
    dir_in[ 12] = 16'hABFF; dir_ff[ 12] = 15'h1DFE; dir_lm[ 12] = 15'h1DFE;
    dir_in[ 13] = 16'hABFF; dir_ff[ 13] = 15'h1FFE; dir_lm[ 13] = 15'h1FFE;
    dir_in[ 14] = 16'hABFF; dir_ff[ 14] = 15'h1FFE; dir_lm[ 14] = 15'h1FFE;
    dir_in[ 15] = 16'hABFF; dir_ff[ 15] = 15'h1FFE; dir_lm[ 15] = 15'h1FFE;
    dir_in[ 16] = 16'hABFF; dir_ff[ 16] = 15'h1FFE; dir_lm[ 16] = 15'h1FFE;
    dir_in[ 17] = 16'hABBF; dir_ff[ 17] = 15'h7FF6; dir_lm[ 17] = 15'h7FF6;
    dir_in[ 18] = 16'hABBF; dir_ff[ 18] = 15'h7FE4; dir_lm[ 18] = 15'h7FE4;
    dir_in[ 19] = 16'hABFF; dir_ff[ 19] = 15'h1FEE; dir_lm[ 19] = 15'h1FEE;
    dir_in[ 20] = 16'hABFF; dir_ff[ 20] = 15'h1FFE; dir_lm[ 20] = 15'h1FFE;
    dir_in[ 21] = 16'hABFF; dir_ff[ 21] = 15'h1FFE; dir_lm[ 21] = 15'h1FFE;
    dir_in[ 22] = 16'hABFF; dir_ff[ 22] = 15'h1FFE; dir_lm[ 22] = 15'h1FFE;
    dir_in[ 23] = 16'hABFF; dir_ff[ 23] = 15'h1FFE; dir_lm[ 23] = 15'h1FFE;
    dir_in[ 24] = 16'hABFB; dir_ff[ 24] = 15'h1FFE; dir_lm[ 24] = 15'h1FFE;
    dir_in[ 25] = 16'hABFB; dir_ff[ 25] = 15'h0FFE; dir_lm[ 25] = 15'h0FFE;
    dir_in[ 26] = 16'hABFF; dir_ff[ 26] = 15'h0FFE; dir_lm[ 26] = 15'h0FFE;
    dir_in[ 27] = 16'hABFF; dir_ff[ 27] = 15'h1FFE; dir_lm[ 27] = 15'h1FFE;
    dir_in[ 28] = 16'hABFF; dir_ff[ 28] = 15'h1FFE; dir_lm[ 28] = 15'h1FFE;
    dir_in[ 29] = 16'hABFF; dir_ff[ 29] = 15'h1FFE; dir_lm[ 29] = 15'h1FFE;
    dir_in[ 30] = 16'hABFF; dir_ff[ 30] = 15'h1FFE; dir_lm[ 30] = 15'h1FFE;
    dir_in[ 31] = 16'hABEF; dir_ff[ 31] = 15'h17FE; dir_lm[ 31] = 15'h17FE;
    dir_in[ 32] = 16'hABEF; dir_ff[ 32] = 15'h17FE; dir_lm[ 32] = 15'h17FE;
    dir_in[ 33] = 16'hABFF; dir_ff[ 33] = 15'h1FFE; dir_lm[ 33] = 15'h1FFE;
    dir_in[ 34] = 16'hABFF; dir_ff[ 34] = 15'h1FFE; dir_lm[ 34] = 15'h1FFE;
    dir_in[ 35] = 16'hABFF; dir_ff[ 35] = 15'h1FFE; dir_lm[ 35] = 15'h1FFE;
    dir_in[ 36] = 16'hABFF; dir_ff[ 36] = 15'h1FFE; dir_lm[ 36] = 15'h1FFE;
    dir_in[ 37] = 16'hABFF; dir_ff[ 37] = 15'h1FFE; dir_lm[ 37] = 15'h1FFE;
    dir_in[ 38] = 16'hABDF; dir_ff[ 38] = 15'h1FFE; dir_lm[ 38] = 15'h1FFE;
    dir_in[ 39] = 16'hABDF; dir_ff[ 39] = 15'h1BFE; dir_lm[ 39] = 15'h1BFE;
    dir_in[ 40] = 16'hABFF; dir_ff[ 40] = 15'h1BFE; dir_lm[ 40] = 15'h1BFE;
    dir_in[ 41] = 16'hABFF; dir_ff[ 41] = 15'h1FFE; dir_lm[ 41] = 15'h1FFE;
    dir_in[ 42] = 16'hABFF; dir_ff[ 42] = 15'h1FFE; dir_lm[ 42] = 15'h1FFE;
    dir_in[ 43] = 16'hABFF; dir_ff[ 43] = 15'h1FFE; dir_lm[ 43] = 15'h1FFE;
    dir_in[ 44] = 16'hABFF; dir_ff[ 44] = 15'h1FFE; dir_lm[ 44] = 15'h1FFE;
    dir_in[ 45] = 16'hABFD; dir_ff[ 45] = 15'h1FBE; dir_lm[ 45] = 15'h1FBE;
    dir_in[ 46] = 16'hABFD; dir_ff[ 46] = 15'h1FBE; dir_lm[ 46] = 15'h1FBE;
    dir_in[ 47] = 16'hABFF; dir_ff[ 47] = 15'h1FFE; dir_lm[ 47] = 15'h1FFE;
    dir_in[ 48] = 16'hABFF; dir_ff[ 48] = 15'h1FFE; dir_lm[ 48] = 15'h1FFE;
    dir_in[ 49] = 16'hABFF; dir_ff[ 49] = 15'h1FFE; dir_lm[ 49] = 15'h1FFE;
    dir_in[ 50] = 16'hABFF; dir_ff[ 50] = 15'h1FFE; dir_lm[ 50] = 15'h1FFE;
    dir_in[ 51] = 16'hABFF; dir_ff[ 51] = 15'h1FFE; dir_lm[ 51] = 15'h1FFE;
    dir_in[ 52] = 16'hEBFF; dir_ff[ 52] = 15'h1FFF; dir_lm[ 52] = 15'h1FFF;
    dir_in[ 53] = 16'hEBFF; dir_ff[ 53] = 15'h1FFF; dir_lm[ 53] = 15'h1FFF;
    dir_in[ 54] = 16'hABFF; dir_ff[ 54] = 15'h1FFE; dir_lm[ 54] = 15'h1FFE;
    dir_in[ 55] = 16'hABFF; dir_ff[ 55] = 15'h1FFE; dir_lm[ 55] = 15'h1FFE;
    dir_in[ 56] = 16'hABFF; dir_ff[ 56] = 15'h1FFE; dir_lm[ 56] = 15'h1FFE;
    dir_in[ 57] = 16'hABF7; dir_ff[ 57] = 15'h1FFE; dir_lm[ 57] = 15'h1FFE;
    dir_in[ 58] = 16'hABF7; dir_ff[ 58] = 15'h1FFE; dir_lm[ 58] = 15'h1FFE;
    dir_in[ 59] = 16'hABF7; dir_ff[ 59] = 15'h1FFE; dir_lm[ 59] = 15'h1FFE;
    dir_in[ 60] = 16'hABF7; dir_ff[ 60] = 15'h1FFE; dir_lm[ 60] = 15'h1FFA;
    dir_in[ 61] = 16'hABF7; dir_ff[ 61] = 15'h1FFA; dir_lm[ 61] = 15'h1FFA;
    dir_in[ 62] = 16'hABF7; dir_ff[ 62] = 15'h1FFA; dir_lm[ 62] = 15'h1FFA;
    dir_in[ 63] = 16'hABFF; dir_ff[ 63] = 15'h1FFA; dir_lm[ 63] = 15'h1FFA;
    dir_in[ 64] = 16'hABFF; dir_ff[ 64] = 15'h1FFA; dir_lm[ 64] = 15'h1FFA;
    dir_in[ 65] = 16'hABFF; dir_ff[ 65] = 15'h1FFA; dir_lm[ 65] = 15'h1FFA;
    dir_in[ 66] = 16'hABFF; dir_ff[ 66] = 15'h1FFA; dir_lm[ 66] = 15'h1FFE;
    dir_in[ 67] = 16'hABFF; dir_ff[ 67] = 15'h1FFE; dir_lm[ 67] = 15'h1FFE;
    dir_in[ 68] = 16'hABFF; dir_ff[ 68] = 15'h1FFE; dir_lm[ 68] = 15'h1FFE;
    dir_in[ 69] = 16'hABFB; dir_ff[ 69] = 15'h1FFE; dir_lm[ 69] = 15'h1FFE;
    dir_in[ 70] = 16'hABFB; dir_ff[ 70] = 15'h0FFE; dir_lm[ 70] = 15'h0FFE;
    dir_in[ 71] = 16'hABFB; dir_ff[ 71] = 15'h0FFE; dir_lm[ 71] = 15'h0FFE;
    dir_in[ 72] = 16'hABFB; dir_ff[ 72] = 15'h0FFE; dir_lm[ 72] = 15'h0FFE;
    dir_in[ 73] = 16'hABBB; dir_ff[ 73] = 15'h0FF6; dir_lm[ 73] = 15'h0FF6;
    dir_in[ 74] = 16'hABBB; dir_ff[ 74] = 15'h0FE6; dir_lm[ 74] = 15'h0FE6;
    dir_in[ 75] = 16'hA3BB; dir_ff[ 75] = 15'h0FE2; dir_lm[ 75] = 15'h0FE2;
    dir_in[ 76] = 16'hA3BB; dir_ff[ 76] = 15'h0FE2; dir_lm[ 76] = 15'h0FE2;
    dir_in[ 77] = 16'hA3FB; dir_ff[ 77] = 15'h0FEA; dir_lm[ 77] = 15'h0FEA;
    dir_in[ 78] = 16'hA3FB; dir_ff[ 78] = 15'h0FFA; dir_lm[ 78] = 15'h0FFA;
    dir_in[ 79] = 16'hABFB; dir_ff[ 79] = 15'h0FFE; dir_lm[ 79] = 15'h0FFE;
    dir_in[ 80] = 16'hABFF; dir_ff[ 80] = 15'h0FFE; dir_lm[ 80] = 15'h0FFE;
    dir_in[ 81] = 16'hABFF; dir_ff[ 81] = 15'h1FFE; dir_lm[ 81] = 15'h1FFE;
    dir_in[ 82] = 16'hABFF; dir_ff[ 82] = 15'h1FFE; dir_lm[ 82] = 15'h1FFE;
    dir_in[ 83] = 16'h8BFF; dir_ff[ 83] = 15'h1FDE; dir_lm[ 83] = 15'h1FDE;
    dir_in[ 84] = 16'h9BFF; dir_ff[ 84] = 15'h1FDA; dir_lm[ 84] = 15'h1FDA;
    dir_in[ 85] = 16'h9BFF; dir_ff[ 85] = 15'h1FDA; dir_lm[ 85] = 15'h1FDA;
    dir_in[ 86] = 16'h8BFF; dir_ff[ 86] = 15'h1FDA; dir_lm[ 86] = 15'h1FDA;
    dir_in[ 87] = 16'h8BFF; dir_ff[ 87] = 15'h1FDA; dir_lm[ 87] = 15'h1FDA;
    dir_in[ 88] = 16'hABFF; dir_ff[ 88] = 15'h1FFE; dir_lm[ 88] = 15'h1FFE;
    dir_in[ 89] = 16'hABFF; dir_ff[ 89] = 15'h1FFE; dir_lm[ 89] = 15'h1FFE;
    dir_in[ 90] = 16'hABBF; dir_ff[ 90] = 15'h7FF6; dir_lm[ 90] = 15'h7FF6;
    dir_in[ 91] = 16'hA3BF; dir_ff[ 91] = 15'h7FE0; dir_lm[ 91] = 15'h7FE0;
    dir_in[ 92] = 16'hA3BF; dir_ff[ 92] = 15'h7FE0; dir_lm[ 92] = 15'h7FE0;
    dir_in[ 93] = 16'hA7BF; dir_ff[ 93] = 15'h1FE0; dir_lm[ 93] = 15'h1FE0;
    dir_in[ 94] = 16'hA7BF; dir_ff[ 94] = 15'h1FE0; dir_lm[ 94] = 15'h1FE0;
    dir_in[ 95] = 16'h27BF; dir_ff[ 95] = 15'h1FE4; dir_lm[ 95] = 15'h1FE4;
    dir_in[ 96] = 16'hA7BF; dir_ff[ 96] = 15'h1FE4; dir_lm[ 96] = 15'h1FE4;
    dir_in[ 97] = 16'hAFBF; dir_ff[ 97] = 15'h1FE4; dir_lm[ 97] = 15'h1FE4;
    dir_in[ 98] = 16'hABBF; dir_ff[ 98] = 15'h7FE4; dir_lm[ 98] = 15'h7FE4;
    dir_in[ 99] = 16'hABFF; dir_ff[ 99] = 15'h1FEE; dir_lm[ 99] = 15'h1FEE;
    dir_in[100] = 16'hABFF; dir_ff[100] = 15'h1FFE; dir_lm[100] = 15'h1FFE;
    dir_in[101] = 16'hABBF; dir_ff[101] = 15'h7FF6; dir_lm[101] = 15'h7FF6;
    dir_in[102] = 16'hABBF; dir_ff[102] = 15'h7FE4; dir_lm[102] = 15'h7FE4;
    dir_in[103] = 16'hABBF; dir_ff[103] = 15'h7FE4; dir_lm[103] = 15'h7FE4;
    dir_in[104] = 16'hABFF; dir_ff[104] = 15'h1FEE; dir_lm[104] = 15'h1FEE;
    dir_in[105] = 16'hA3FF; dir_ff[105] = 15'h1FFE; dir_lm[105] = 15'h1FFA;
    dir_in[106] = 16'hA3FF; dir_ff[106] = 15'h1FFA; dir_lm[106] = 15'h1FFA;
    dir_in[107] = 16'hA3FF; dir_ff[107] = 15'h1FFA; dir_lm[107] = 15'h1FFA;
    dir_in[108] = 16'hABFF; dir_ff[108] = 15'h1FFE; dir_lm[108] = 15'h1FFE;
    dir_in[109] = 16'hABFF; dir_ff[109] = 15'h1FFE; dir_lm[109] = 15'h1FFE;
    dir_in[110] = 16'hABFF; dir_ff[110] = 15'h1FFE; dir_lm[110] = 15'h1FFE;
    comb_exp[ 0] = 3'h6;
    comb_exp[ 1] = 3'h6;
    comb_exp[ 2] = 3'h6;
    comb_exp[ 3] = 3'h7;
    comb_exp[ 4] = 3'h6;
    comb_exp[ 5] = 3'h6;
    comb_exp[ 6] = 3'h6;
    comb_exp[ 7] = 3'h6;
    comb_exp[ 8] = 3'h6;
    comb_exp[ 9] = 3'h6;
    comb_exp[10] = 3'h6;
    comb_exp[11] = 3'h7;
    comb_exp[12] = 3'h6;
    comb_exp[13] = 3'h6;
    comb_exp[14] = 3'h6;
    comb_exp[15] = 3'h6;
    comb_exp[16] = 3'h6;
    comb_exp[17] = 3'h6;
    comb_exp[18] = 3'h6;
    comb_exp[19] = 3'h7;
    comb_exp[20] = 3'h6;
    comb_exp[21] = 3'h6;
    comb_exp[22] = 3'h6;
    comb_exp[23] = 3'h6;
    comb_exp[24] = 3'h6;
    comb_exp[25] = 3'h6;
    comb_exp[26] = 3'h6;
    comb_exp[27] = 3'h6;
    comb_exp[28] = 3'h6;
    comb_exp[29] = 3'h6;
    comb_exp[30] = 3'h6;
    comb_exp[31] = 3'h6;
  end

  initial begin
    // ---- 1. directed phase ----
    for (k = 0; k < 111; k = k + 1) begin
      @(negedge osc);
      apply_in(dir_in[k]);
      @(posedge osc);
      #1;
`ifdef USE_TRANSPARENT_LATCHES
      expw = dir_lm[k];
`else
      expw = dir_ff[k];
`endif
      checks = checks + 1;
      if (outword !== expw) begin
        errors = errors + 1;
        $display("FAIL dir[%0d]: in=%04h got out=%04h expected %04h",
                 k, dir_in[k], outword, expw);
      end
    end

    // ---- 2. comb sweep, clock frozen low ----
    @(negedge osc);
    clk_en = 0;
    for (k = 0; k < 32; k = k + 1) begin
      apply_in(dir_in[110]);
      loen_n = k[0];
      hien_n = k[1];
      ras    = k[2];
      bgnt_n = k[3];
      cgnt_n = k[4];
      #2;
      checks = checks + 1;
      if (combword !== comb_exp[k]) begin
        errors = errors + 1;
        $display("FAIL comb[%0d]: got %b expected %b", k, combword,
                 comb_exp[k]);
      end
    end
    apply_in(dir_in[110]);
    #2;
    clk_en = 1;

    // ---- 3. LFSR phase ----
    for (k = 0; k < 2000; k = k + 1) begin
      lfsr = (lfsr >> 1) ^ (lfsr[0] ? 32'hEDB88320 : 32'h0);
      b = lfsr;
      @(negedge osc);
      apply_in({(b[16:15] == 2'b00) ? 1'b0 : 1'b1, b[14:0]});
      @(posedge osc);
      #1;
      checks = checks + 1;
      if (^outword === 1'bx) begin
        errors = errors + 1;
        $display("FAIL lfsr[%0d]: undefined output %b", k, outword);
      end
      acc = (acc << 5) - acc + {17'b0, outword};
    end
    checks = checks + 1;
    if (acc !== ACC_EXPECT) begin
      errors = errors + 1;
      $display("FAIL checksum: got %08h expected %08h", acc, ACC_EXPECT);
    end

    // ---- 4. PD4 comb check ----
    @(negedge osc);
    clk_en = 0;
    apply_in(16'hABFF);   // idle inputs
    #2;
    pd4 = 1;
    #2;
    checks = checks + 1;
    if (outword !== PD4_EXPECT) begin
      errors = errors + 1;
      $display("FAIL PD4: got %04h expected %04h", outword, PD4_EXPECT);
    end

    // Verdict. Expected: 111 + 32 + 2000 + 1 + 1 = 2145.
    if (errors == 0 && checks == 2145)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 2145 checks)",
               errors, checks);
    $finish;
  end

endmodule
