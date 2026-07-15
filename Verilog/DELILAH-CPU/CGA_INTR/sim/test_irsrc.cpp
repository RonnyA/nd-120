// ============================================================================
// test_irsrc.cpp - CGA_INTR_IRSRC (interrupt source, schematic p.76) unit test
//
// Locks in the MOR (Memory Out of Range) interrupt wiring: the source input
// was tied off (assign s_nor_n = 1) and was re-wired to the real MORN port on
// 14-JUL-2026. This test proves MORN drives IREQ bit 12 and IOXERRN drives
// bit 10, independently, and that neither leaks into a neighbouring level.
//
// Combinational module (no clock). Gate facts (CGA_INTR_IRSRC.v):
//   IREQ_15_0_N[12] = gates5_out & MORN     (GATES_21, both inputs bubbled)
//   IREQ_15_0_N[10] = gates7_out & IOXERRN  (GATES_23)
//   gates{5,7}_out  = ~(FIDBO[12|10] & EMPID)  -> =1 when FIDBO=0
// so with FIDBO=0 the request bit (active low) simply follows its source_n.
//
// Self-checking: prints "TB_RESULT: PASS" only when every check passes.
// ============================================================================
#include "VCGA_INTR_IRSRC.h"
#include "verilated.h"
#include <cstdio>
#include <cstdint>

static int failures = 0;
static VCGA_INTR_IRSRC *dut = nullptr;

static void check(const char *name, int cond)
{
    if (!cond) { printf("FAIL: %s\n", name); failures++; }
    else       { printf("  ok: %s\n", name); }
}

static int bit(uint32_t v, int b) { return (int)((v >> b) & 1u); }

// All interrupt inputs inactive (active-low sources = 1), FIDBO=0 (no software
// request), EMPID disabled, Z (active high) = 0.
static void setIdle()
{
    dut->BINT10N = 1; dut->BINT11N = 1; dut->BINT12N = 1; dut->BINT13N = 1;
    dut->BINT15N = 1; dut->EMPIDN = 1; dut->FIDBO_15_0 = 0;
    dut->IOXERRN = 1; dut->MORN = 1; dut->PARERRN = 1; dut->POWFAILN = 1;
    dut->Z = 0;
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    dut = new VCGA_INTR_IRSRC;

    // 1) fully idle -> the internal levels 10 (IOX) and 12 (MOR) are inactive (=1)
    setIdle(); dut->eval();
    check("idle: IREQ[12] (MOR) inactive", bit(dut->IREQ_15_0_N, 12) == 1);
    check("idle: IREQ[10] (IOX) inactive", bit(dut->IREQ_15_0_N, 10) == 1);

    // 2) MOR active only -> bit 12 asserts (=0), bit 10 stays inactive
    setIdle(); dut->MORN = 0; dut->eval();
    check("MOR active -> IREQ[12]=0",        bit(dut->IREQ_15_0_N, 12) == 0);
    check("MOR active -> IREQ[10] stays 1",  bit(dut->IREQ_15_0_N, 10) == 1);
    // and it must not leak into neighbouring internal levels
    check("MOR active -> IREQ[11](PAR) stays 1", bit(dut->IREQ_15_0_N, 11) == 1);
    check("MOR active -> IREQ[13](POW) stays 1", bit(dut->IREQ_15_0_N, 13) == 1);

    // 3) IOX active only -> bit 10 asserts, bit 12 stays inactive
    setIdle(); dut->IOXERRN = 0; dut->eval();
    check("IOX active -> IREQ[10]=0",        bit(dut->IREQ_15_0_N, 10) == 0);
    check("IOX active -> IREQ[12] stays 1",  bit(dut->IREQ_15_0_N, 12) == 1);

    // 4) both active -> independent, both assert
    setIdle(); dut->MORN = 0; dut->IOXERRN = 0; dut->eval();
    check("both active -> IREQ[12]=0", bit(dut->IREQ_15_0_N, 12) == 0);
    check("both active -> IREQ[10]=0", bit(dut->IREQ_15_0_N, 10) == 0);

    // 5) sanity: a software request via FIDBO[12]+EMPID also asserts bit 12
    //    (proves the MOR wiring did not displace the software path)
    setIdle(); dut->EMPIDN = 0; dut->FIDBO_15_0 = (1u << 12); dut->eval();
    check("sw FIDBO[12]+EMPID -> IREQ[12]=0", bit(dut->IREQ_15_0_N, 12) == 0);

    dut->final();
    delete dut;

    if (failures == 0) printf("TB_RESULT: PASS\n");
    else               printf("TB_RESULT: FAIL (%d errors)\n", failures);
    return failures ? 1 : 0;
}
