/****************************************************************************
** Verilator system gate for nd_storage (step 6 of the nd-storage plan)   **
**                                                                         **
** Runs the FULL nd_storage stack (nd_storage_vtop.v: mount + engine +    **
** fatchk + sd_file_reader + sd_writer + pin mux) against:                **
**   - a C++ SD card model (adapted from the PROVEN                       **
**     fpga/tang-nano-20k/sd-fat-test/sim/test_sd_fat.cpp model:          **
**     CMD0/8/55/ACMD41/2/3/7/16/17/18/24/25/ACMD23/CMD12, CRC7/CRC16     **
**     both ways) serving nds_storage_full.img, with the ALWAYS-ON        **
**     illegal-write assertion tightened for this gate: any write outside **
**     the DATA SECTORS OF THE THREE MOUNTED FILES is an immediate FAIL   **
**     (owner safety rule - stricter than the reserved-region check).     **
**   - a C++ behavioral SDRAM model on the mem_* device port (same        **
**     contract and randomized 4..40-cycle latency as nds_mem_model.v).   **
** clk_stor ~27.03 MHz and clk_cpu ~23.04 MHz (non-integer ratio - the    **
** CDC stress convention of the iverilog stack testbenches).              **
**                                                                         **
** Acceptance tests (spec section 9 / design section 6):                  **
**   1  open clients 0..2 (TAPE.BPUN 3001 B, FLOPPY1.IMG 12288 B,         **
**      FLOPPY2.IMG 8192 B): open_ok, size_bytes exact, SDRAM preload     **
**      byte-exact vs the image file incl. the zero-padded tail word;     **
**      n_blocks proven behaviorally (last block reads OK, block ==       **
**      n_blocks answers err).                                            **
**   2  block reads through the client ports, byte-compared against the   **
**      file patterns; post-run fsck: the card image is re-parsed after   **
**      all write traffic (boot sector snapshot, root directory entries,  **
**      FAT chains contiguous + end-of-chain) AND byte-compared against   **
**      an expected image that only differs where the verified writes     **
**      landed. The Makefile additionally runs fsck.vfat -n on the        **
**      dumped post image.                                                **
**   3  concurrency: clients 0/1/2 request simultaneously; each is served **
**      exactly once, distinct patterns, no cross-client leak, no SD      **
**      traffic (reads come from SDRAM).                                  **
**   3w block write on client 1: card-FIRST/SDRAM-second observable       **
**      ordering (last CMD24 commit cycle < first SDRAM write cycle),     **
**      write-through lands in the right file sectors on the card,        **
**      SDRAM copy matches, neighbor blocks untouched, read-back OK.      **
**   5  errors: injected CMD24 failure (card answers CRC status "101",    **
**      discards the data) -> client gets done+err, SDRAM slot NOT        **
**      corrupted, card image unchanged, open_ok STAYS UP (spec sec 7),   **
**      and a retry succeeds; missing-file open (client 3, SMD0.IMG       **
**      absent) -> open_err; out-of-range block -> done+err with ZERO     **
**      mem-port and ZERO SD-clock traffic.                               **
**                                                                         **
** Build & run: make test-storage (in this sim/ directory).               **
** Verdict:     TB_RESULT: PASS / TB_RESULT: FAIL <reason>                **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/

#include <cstdio>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "Vnd_storage_vtop.h"
#include "verilated.h"

// ---------------------------------------------------------------- constants
static const uint64_t STOR_HALF_PS = 18500;  // ~27.03 MHz (matches nd_storage_tb.v)
static const uint64_t CPU_HALF_PS  = 21700;  // ~23.04 MHz

static const long TAPE_BYTES = 3001;
static const long FLP1_BYTES = 12288;
static const long FLP2_BYTES = 8192;

// slot bases in 2048-byte blocks (nd_storage defaults, design section 1.3)
static const uint32_t SLOT_BASE_BLK[3] = {0, 32, 672};

static const char *IMG_NAME  = "nds_storage_full.img";
static const char *POST_NAME = "nds_storage_full_post.img";

// file patterns - MUST match make_storage_image.sh
static uint8_t pat_tape(long k) { return (uint8_t)(((k % 256) + 37 * ((k / 256) % 256) + 129) % 256); }
static uint8_t pat_flp1(long k) { return (uint8_t)(((k % 256) + 29 * ((k / 256) % 256) + 7) % 256); }
static uint8_t pat_flp2(long k) { return (uint8_t)(((k % 256) + 41 * ((k / 256) % 256) + 63) % 256); }

static uint8_t pat_file(int c, long k) {
    return c == 0 ? pat_tape(k) : (c == 1 ? pat_flp1(k) : pat_flp2(k));
}
static long file_size(int c) { return c == 0 ? TAPE_BYTES : (c == 1 ? FLP1_BYTES : FLP2_BYTES); }

static uint64_t g_stor_posedges = 0;  // global clk_stor rising-edge counter

// ---------------------------------------------------------------- SD card
// Adapted from the proven model in
// fpga/tang-nano-20k/sd-fat-test/sim/test_sd_fat.cpp. Additions for this
// gate: (a) legal-write ranges = the data sectors of the mounted files -
// ANY other write target is an immediate fatal FAIL (owner safety rule);
// (b) inject_fail: the next CMD24 data block is answered with CRC status
// "101" (rejected) and NOT committed - the error-injection case of
// acceptance test 5; (c) per-commit instrumentation for the card-first/
// SDRAM-second ordering check.
struct SDCard {
    std::vector<uint8_t> mem;
    bool app_cmd = false;
    int crc_errors = 0;

    uint32_t resv_sectors = 1;
    int illegal_writes = 0;
    bool fatal = false;
    std::vector<uint8_t> resv_snap;

    // legal write ranges: [sector, sector+count)
    std::vector<std::pair<uint32_t, uint32_t>> legal;

    // error injection: reject the next N CMD24 data blocks (status "101")
    int inject_fail = 0;
    int injected = 0;

    // instrumentation: committed writes
    uint64_t last_commit_cycle = 0;
    uint32_t commit_count = 0;

    // command receive (bits sampled on sd_clk rising edges)
    uint64_t sh = 0;
    int rxcnt = -1;

    // CMD response / DAT block bit queues (played on falling edges)
    std::vector<uint8_t> cq;
    size_t cpos = 0;
    int ncr = 0;
    std::vector<uint8_t> dq;
    size_t dpos = 0;
    int ddelay = 0;

    // CMD24/CMD25 write-block receive state
    bool wr_expect = false;
    bool wr_active = false;
    uint64_t wr_base = 0;
    int wr_bit = 0;
    uint8_t wr_byte = 0;
    uint16_t wr_crc = 0, wr_crc_host = 0;
    std::vector<uint8_t> wr_buf;
    int wr_crc_errors = 0;

    // multi-block state (present for completeness; nd_storage v1 is CMD24)
    bool rd_multi = false;
    uint64_t rd_base = 0;
    bool wr_multi = false;

    // pin state
    int cmd_drive = 0, cmd_val = 1;
    int dat_drive = 0, dat0 = 1;

    bool load(const char *fn) {
        FILE *f = fopen(fn, "rb");
        if (!f) return false;
        fseek(f, 0, SEEK_END);
        long n = ftell(f);
        fseek(f, 0, SEEK_SET);
        mem.resize(n);
        if (fread(mem.data(), 1, n, f) != (size_t)n) { fclose(f); return false; }
        fclose(f);
        printf("sdcard: loaded %ld bytes\n", n);
        resv_sectors = 1;
        if (n >= 512 && (mem[0] == 0xEB || mem[0] == 0xE9) &&
            mem[510] == 0x55 && mem[511] == 0xAA) {
            uint32_t r = (uint32_t)mem[14] | ((uint32_t)mem[15] << 8);
            if (r >= 1 && (uint64_t)r * 512 <= (uint64_t)n) resv_sectors = r;
        }
        resv_snap.assign(mem.begin(), mem.begin() + (size_t)resv_sectors * 512);
        return true;
    }

    bool sectorLegal(uint32_t sec) const {
        for (auto &r : legal)
            if (sec >= r.first && sec < r.first + r.second) return true;
        return false;
    }

    void flagIllegal(uint32_t sec, const char *how) {
        illegal_writes++;
        fatal = true;
        printf("FAIL: sdcard ILLEGAL WRITE to sector %u (%s) - outside every file data area\n",
               sec, how);
    }

    static uint8_t crc7_step(uint8_t c, int b) {
        int fb = ((c >> 6) & 1) ^ (b & 1);
        return (uint8_t)(((c << 1) & 0x7F) ^ (fb ? 0x09 : 0));
    }
    static uint16_t crc16_step(uint16_t c, int b) {
        int fb = ((c >> 15) & 1) ^ (b & 1);
        return (uint16_t)((c << 1) ^ (fb ? 0x1021 : 0));
    }

    void push48(uint64_t head40) {
        uint8_t c = 0;
        for (int i = 39; i >= 0; i--) c = crc7_step(c, (head40 >> i) & 1);
        for (int i = 39; i >= 0; i--) cq.push_back((head40 >> i) & 1);
        for (int i = 6; i >= 0; i--) cq.push_back((c >> i) & 1);
        cq.push_back(1);
    }

    void queueBlock(uint64_t base, int delay) {
        dq.clear(); dpos = 0; ddelay = delay;
        dq.push_back(0);
        uint16_t crc = 0;
        for (int i = 0; i < 512; i++) {
            uint8_t byte = (base + i < mem.size()) ? mem[base + i] : 0xFF;
            for (int b = 7; b >= 0; b--) {
                int bit = (byte >> b) & 1;
                dq.push_back(bit);
                crc = crc16_step(crc, bit);
            }
        }
        for (int i = 15; i >= 0; i--) dq.push_back((crc >> i) & 1);
        dq.push_back(1);
    }

    void decode() {
        uint32_t cmd = (sh >> 40) & 0x3F;
        uint32_t arg = (uint32_t)(sh >> 8);

        uint8_t c = 0;
        for (int i = 47; i >= 8; i--) c = crc7_step(c, (sh >> i) & 1);
        uint8_t want = (uint8_t)((c << 1) | 1);
        if (want != (uint8_t)(sh & 0xFF)) {
            crc_errors++;
            printf("sdcard: CMD%u CRC7 mismatch\n", cmd);
        }

        cq.clear(); cpos = 0; ncr = 4;
        bool data = false;
        uint64_t head;
        switch (cmd) {
            case 0: app_cmd = false; break;
            case 8: push48(((uint64_t)8 << 32) | 0x000001AAULL); break;
            case 55:
                if ((arg >> 16) == 0 || (arg >> 16) == 1) {
                    push48(((uint64_t)55 << 32) | 0x00000120ULL);
                    app_cmd = true;
                } else app_cmd = false;
                break;
            case 23:
                if (app_cmd) push48(((uint64_t)23 << 32) | 0x00000900ULL);
                app_cmd = false;
                break;
            case 12:
                push48(((uint64_t)12 << 32) | 0x00000900ULL);
                if (rd_multi) { dq.clear(); dpos = 0; ddelay = 0; }
                if (wr_multi) {
                    dq.clear(); dpos = 0; ddelay = 2;
                    dq.push_back(0);
                    for (int b = 0; b < 64; b++) dq.push_back(0);
                    dq.push_back(1);
                }
                rd_multi = false;
                wr_multi = false;
                wr_expect = false;
                wr_active = false;
                break;
            case 41:
                if (app_cmd) {
                    head = ((uint64_t)0x3F << 32) | 0xC0FF8000ULL;
                    for (int i = 39; i >= 0; i--) cq.push_back((head >> i) & 1);
                    for (int i = 0; i < 7; i++) cq.push_back(1);
                    cq.push_back(1);
                }
                app_cmd = false;
                break;
            case 2: {
                cq.push_back(0); cq.push_back(0);
                for (int i = 0; i < 6; i++) cq.push_back(1);
                for (int i = 0; i < 127; i++) cq.push_back((i * 7) & 1);
                cq.push_back(1);
                break;
            }
            case 3: push48(((uint64_t)3 << 32) | 0x00010500ULL); break;
            case 7: push48(((uint64_t)7 << 32) | 0x00000700ULL); break;
            case 16: push48(((uint64_t)16 << 32) | 0x00000900ULL); break;
            case 17:
                push48(((uint64_t)17 << 32) | 0x00000900ULL);
                data = true;
                break;
            case 18:
                push48(((uint64_t)18 << 32) | 0x00000900ULL);
                data = true;
                rd_multi = true;
                break;
            case 24:
                push48(((uint64_t)24 << 32) | 0x00000900ULL);
                wr_expect = true;
                wr_active = false;
                wr_multi = false;
                wr_base = (uint64_t)arg * 512;
                wr_buf.clear();
                if (!sectorLegal(arg)) flagIllegal(arg, "CMD24");
                break;
            case 25:
                push48(((uint64_t)25 << 32) | 0x00000900ULL);
                wr_expect = true;
                wr_active = false;
                wr_multi = true;
                wr_base = (uint64_t)arg * 512;
                wr_buf.clear();
                break;
            default: break;
        }

        if (data) {
            uint64_t base = (uint64_t)arg * 512;
            queueBlock(base, 4 + 48 + 8);
            rd_base = base + 512;
        }
    }

    void onRise(int cmd_line, int dat_line) {
        // ---- DAT0: incoming write block ----
        if (wr_expect && !dat_drive) {
            if (!wr_active) {
                if (dat_line == 0) {
                    wr_active = true;
                    wr_bit = 0;
                    wr_byte = 0;
                    wr_crc = 0;
                    wr_crc_host = 0;
                    wr_buf.clear();
                }
            } else if (wr_bit < 4096) {
                wr_byte = (uint8_t)((wr_byte << 1) | (dat_line & 1));
                wr_crc = crc16_step(wr_crc, dat_line & 1);
                if ((wr_bit & 7) == 7) { wr_buf.push_back(wr_byte); wr_byte = 0; }
                wr_bit++;
            } else if (wr_bit < 4112) {
                wr_crc_host = (uint16_t)((wr_crc_host << 1) | (dat_line & 1));
                wr_bit++;
                if (wr_bit == 4112) {
                    if (wr_crc_host != wr_crc) {
                        wr_crc_errors++;
                        printf("sdcard: write data CRC16 mismatch\n");
                    }
                    if (wr_multi && !sectorLegal((uint32_t)(wr_base / 512)))
                        flagIllegal((uint32_t)(wr_base / 512), "CMD25 block");
                    if (inject_fail > 0) {
                        // injected failure: reject the block (status "101"),
                        // discard the data - the card image stays intact
                        inject_fail--;
                        injected++;
                        printf("sdcard: INJECTED write failure at sector %u (status 101, data discarded)\n",
                               (uint32_t)(wr_base / 512));
                        dq.clear(); dpos = 0; ddelay = 3;
                        dq.push_back(0); dq.push_back(1); dq.push_back(0);
                        dq.push_back(1); dq.push_back(1);
                    } else {
                        for (size_t i = 0; i < 512 && wr_base + i < mem.size(); i++)
                            mem[wr_base + i] = wr_buf[i];
                        last_commit_cycle = g_stor_posedges;
                        commit_count++;
                        // CRC status token "010" + end, then ~64 clocks busy
                        dq.clear(); dpos = 0; ddelay = 3;
                        dq.push_back(0); dq.push_back(0); dq.push_back(1);
                        dq.push_back(0); dq.push_back(1);
                        for (int b = 0; b < 64; b++) dq.push_back(0);
                        dq.push_back(1);
                    }
                    wr_active = false;
                    if (wr_multi) wr_base += 512;
                    else wr_expect = false;
                }
            }
        }

        // ---- CMD: command receive ----
        if (cmd_drive) return;
        if (rxcnt < 0) {
            if (cmd_line == 0) { sh = 0; rxcnt = 1; }
            return;
        }
        sh = (sh << 1) | (cmd_line & 1);
        rxcnt++;
        if (rxcnt == 48) { decode(); rxcnt = -1; }
    }

    void onFall() {
        if (!cq.empty()) {
            if (ncr > 0) { ncr--; cmd_drive = 0; cmd_val = 1; }
            else if (cpos < cq.size()) { cmd_drive = 1; cmd_val = cq[cpos++]; }
            else { cq.clear(); cpos = 0; cmd_drive = 0; cmd_val = 1; }
        } else { cmd_drive = 0; cmd_val = 1; }

        if (!dq.empty()) {
            if (ddelay > 0) { ddelay--; dat_drive = 0; dat0 = 1; }
            else if (dpos < dq.size()) { dat_drive = 1; dat0 = dq[dpos++]; }
            else {
                dq.clear(); dpos = 0; dat_drive = 0; dat0 = 1;
                if (rd_multi) {
                    queueBlock(rd_base, 8);
                    rd_base += 512;
                }
            }
        } else { dat_drive = 0; dat0 = 1; }
    }
};

// ---------------------------------------------------------------- mem model
// Behavioral SDRAM device port: identical contract to nds_mem_model.v -
// start/we/addr/wdata sampled at the start pulse, randomized 4..40 clk_stor
// latency, rdata valid at done and held, done a 1-cycle pulse.
struct MemModel {
    std::vector<uint32_t> mem;
    bool busy = false;
    bool done = false;
    bool we = false;
    uint32_t addr = 0, wdata = 0, rdata = 0;
    int cnt = 0;
    uint32_t seed = 0x0005D00D;
    uint64_t start_pulses = 0;

    // instrumentation: first write inside a watched address window
    bool watch_armed = false;
    uint32_t watch_lo = 0, watch_hi = 0;
    uint64_t watch_first_cycle = 0;
    bool watch_hit = false;

    MemModel() : mem(1u << 20, 0) {}

    uint32_t rnd() {
        seed = seed * 1664525u + 1013904223u;
        return seed >> 8;
    }

    void arm_watch(uint32_t lo, uint32_t hi) {
        watch_armed = true;
        watch_lo = lo;
        watch_hi = hi;
        watch_hit = false;
        watch_first_cycle = 0;
    }

    // called with the DUT's PRE-edge output values, once per clk_stor posedge
    void posedge(bool start, bool we_i, uint32_t addr_i, uint32_t wdata_i) {
        done = false;
        if (!busy) {
            if (start) {
                start_pulses++;
                busy = true;
                we = we_i;
                addr = addr_i;
                wdata = wdata_i;
                cnt = 4 + (int)(rnd() % 37);  // 4..40 cycles
            }
        } else if (cnt > 1) {
            cnt--;
        } else {
            if (addr < mem.size()) {
                if (we) {
                    mem[addr] = wdata;
                    if (watch_armed && !watch_hit && addr >= watch_lo && addr < watch_hi) {
                        watch_hit = true;
                        watch_first_cycle = g_stor_posedges;
                    }
                } else rdata = mem[addr];
            } else if (!we) rdata = 0xDEADBEEF;
            done = true;
            busy = false;
        }
    }
};

// ---------------------------------------------------------------- FAT16 view
struct FatGeom {
    uint32_t bps, spc, rsvd, nfats, rootn, spf;
    uint32_t fat0, root_sector, root_sectors, data_sector;
};

static bool parse_geom(const std::vector<uint8_t> &m, FatGeom &g) {
    if (m.size() < 512 || m[510] != 0x55 || m[511] != 0xAA) return false;
    g.bps   = (uint32_t)m[11] | ((uint32_t)m[12] << 8);
    g.spc   = m[13];
    g.rsvd  = (uint32_t)m[14] | ((uint32_t)m[15] << 8);
    g.nfats = m[16];
    g.rootn = (uint32_t)m[17] | ((uint32_t)m[18] << 8);
    g.spf   = (uint32_t)m[22] | ((uint32_t)m[23] << 8);
    if (g.bps != 512 || g.spc == 0 || g.spf == 0) return false;
    g.fat0         = g.rsvd;
    g.root_sector  = g.rsvd + g.nfats * g.spf;
    g.root_sectors = (g.rootn * 32) / g.bps;
    g.data_sector  = g.root_sector + g.root_sectors;
    return true;
}

struct FileLoc {
    uint32_t dir_off = 0, cluster = 0, size = 0;
    uint32_t first_sector = 0, nsectors = 0;
};

static uint16_t fat_get(const std::vector<uint8_t> &m, const FatGeom &g, uint32_t c) {
    size_t off = (size_t)g.fat0 * g.bps + (size_t)c * 2;
    return (uint16_t)m[off] | ((uint16_t)m[off + 1] << 8);
}

// locate a root file by its exact size (unique per file in the test image;
// avoids re-implementing the 8.3/LFN name matching here)
static bool find_by_size(const std::vector<uint8_t> &m, const FatGeom &g,
                         uint32_t size, FileLoc &fl) {
    int hits = 0;
    for (uint32_t i = 0; i < g.rootn; i++) {
        size_t off = (size_t)g.root_sector * g.bps + (size_t)i * 32;
        if (m[off] == 0x00 || m[off] == 0xE5) continue;
        uint8_t attr = m[off + 11];
        if (attr == 0x0F || (attr & 0x08) || (attr & 0x10)) continue;
        uint32_t sz = (uint32_t)m[off + 28] | ((uint32_t)m[off + 29] << 8) |
                      ((uint32_t)m[off + 30] << 16) | ((uint32_t)m[off + 31] << 24);
        if (sz != size) continue;
        hits++;
        fl.dir_off = (uint32_t)off;
        fl.cluster = (uint32_t)m[off + 26] | ((uint32_t)m[off + 27] << 8);
        fl.size = sz;
        fl.first_sector = g.data_sector + (fl.cluster - 2) * g.spc;
        fl.nsectors = (sz + 511) / 512;
    }
    return hits == 1;
}

// chain contiguous with an intact end-of-chain mark
static bool chain_ok(const std::vector<uint8_t> &m, const FatGeom &g,
                     uint32_t first, uint32_t size) {
    uint32_t n = (size + g.spc * g.bps - 1) / (g.spc * g.bps);
    uint32_t c = first;
    for (uint32_t i = 0; i + 1 < n; i++) {
        uint16_t nx = fat_get(m, g, c);
        if (nx != c + 1) return false;
        c = nx;
    }
    return fat_get(m, g, c) >= 0xFFF7;
}

// ---------------------------------------------------------------- harness
static Vnd_storage_vtop *top;
static SDCard card;
static MemModel memm;
static uint16_t cbuf[3][1024];

static uint64_t t_ps = 0, next_stor = STOR_HALF_PS, next_cpu = CPU_HALF_PS;
static int v_stor = 0, v_cpu = 0;
static uint64_t g_cpu_posedges = 0;
static int last_sdclk = 0;
static uint64_t sd_posedge_count = 0;
static uint64_t done_count[7] = {0, 0, 0, 0, 0, 0, 0};

static int errors = 0;

static void check(bool ok, const char *what) {
    if (ok) printf("  ok: %s\n", what);
    else { printf("FAIL: %s\n", what); errors++; }
}

static void apply_card_pins() {
    top->sd_cmd_c_drive = card.cmd_drive;
    top->sd_cmd_c_val = card.cmd_val;
    top->sd_dat0_c_drive = card.dat_drive;
    top->sd_dat0_c_val = card.dat0;
}

static void after_eval_sd() {
    int sc = top->sd_clk;
    if (sc && !last_sdclk) {
        sd_posedge_count++;
        card.onRise(top->sd_cmd_resolved, top->sd_dat0_resolved);
    }
    if (!sc && last_sdclk) {
        card.onFall();
        apply_card_pins();
        top->eval();
    }
    last_sdclk = sc;
}

static uint16_t get_buf_addr(int c) {
    return c == 0 ? top->buf_addr0 : (c == 1 ? top->buf_addr1 : top->buf_addr2);
}
static uint16_t get_buf_wdata(int c) {
    return c == 0 ? top->buf_wdata0 : (c == 1 ? top->buf_wdata1 : top->buf_wdata2);
}
static void set_buf_rdata(int c, uint16_t v) {
    if (c == 0) top->buf_rdata0 = v;
    else if (c == 1) top->buf_rdata1 = v;
    else top->buf_rdata2 = v;
}

// advance the simulation by ONE clock edge (whichever clock is due first)
static void step_edge() {
    if (next_stor <= next_cpu) {
        t_ps = next_stor;
        next_stor += STOR_HALF_PS;
        v_stor ^= 1;
        if (v_stor) {
            // registered mem model: sample the DUT's pre-edge outputs,
            // update state, then drive the post-edge outputs after eval
            memm.posedge(top->mem_start, top->mem_we, top->mem_addr, top->mem_wdata);
            g_stor_posedges++;
        }
        top->clk_stor = v_stor;
        top->eval();
        if (v_stor) {
            top->mem_rdata = memm.rdata;
            top->mem_busy = memm.busy;
            top->mem_done = memm.done;
            top->eval();
        }
        after_eval_sd();
    } else {
        t_ps = next_cpu;
        next_cpu += CPU_HALF_PS;
        v_cpu ^= 1;
        uint16_t p_addr[3], p_wdata[3];
        uint8_t p_we = 0;
        if (v_cpu) {
            // registered-BRAM semantics: the write strobes sampled at this
            // edge are the DUT's PRE-edge outputs
            p_we = top->buf_we_o;
            for (int c = 0; c < 3; c++) {
                p_addr[c] = get_buf_addr(c);
                p_wdata[c] = get_buf_wdata(c);
            }
        }
        top->clk_cpu = v_cpu;
        top->eval();
        if (v_cpu) {
            for (int c = 0; c < 3; c++)
                if ((p_we >> c) & 1) cbuf[c][p_addr[c] & 1023] = p_wdata[c];
            // combinational read port on the NEW address (the FE presents
            // the address one cycle ahead - contract allows comb. rdata)
            for (int c = 0; c < 3; c++) set_buf_rdata(c, cbuf[c][get_buf_addr(c) & 1023]);
            top->eval();
            for (int c = 0; c < 7; c++)
                if ((top->done_o >> c) & 1) done_count[c]++;
            g_cpu_posedges++;
        }
        after_eval_sd();
    }
}

// run until n more clk_cpu rising edges have happened
static void run_cpu(long n) {
    uint64_t until = g_cpu_posedges + (uint64_t)n;
    while (g_cpu_posedges < until) step_edge();
}

static bool fatal_guard(const char *what) {
    if (card.fatal) {
        printf("TB_RESULT: FAIL illegal card write during %s\n", what);
        return true;
    }
    return false;
}

// wait for busy[c] to rise then fall (mirrors nd_storage_tb.v wait_op)
static bool op_wait(int c, long max_cpu, const char *what) {
    long guard = 0;
    while (!((top->busy_o >> c) & 1) && guard < 5000) { run_cpu(1); guard++; }
    if (!((top->busy_o >> c) & 1)) {
        printf("TB_RESULT: FAIL %s: client %d never went busy\n", what, c);
        return false;
    }
    guard = 0;
    while (((top->busy_o >> c) & 1) && guard < max_cpu) {
        run_cpu(1);
        guard++;
        if (card.fatal) return !fatal_guard(what);
    }
    if ((top->busy_o >> c) & 1) {
        printf("TB_RESULT: FAIL %s: client %d op hung (%ld cpu cycles)\n", what, c, max_cpu);
        return false;
    }
    run_cpu(30);  // let levels (open_ok/err/size) settle across the CDC
    return true;
}

static bool do_open(int c, const char *what) {
    top->open_req_i = (uint8_t)(1u << c);
    run_cpu(1);
    top->open_req_i = 0;
    return op_wait(c, 8000000, what);
}

static void set_block(int c, uint16_t blk) {
    if (c == 0) top->block0 = blk;
    else if (c == 1) top->block1 = blk;
    else if (c == 2) top->block2 = blk;
    else top->block3 = blk;
}

static bool do_req(int c, bool wrflag, uint16_t blk, const char *what) {
    set_block(c, blk);
    top->wr_i = wrflag ? (uint8_t)(1u << c) : 0;
    top->req_i = (uint8_t)(1u << c);
    run_cpu(1);
    top->req_i = 0;
    top->wr_i = 0;
    return op_wait(c, 4000000, what);
}

// expected client word (big-endian pair; bytes past the file size are 0 -
// the SDRAM slot beyond the mount's zero-padded tail word reads as the
// mem model's zero init)
static uint16_t exp_word(int c, uint16_t blk, int w) {
    long k = 2048L * blk + 2L * w;
    long sz = file_size(c);
    uint8_t hi = (k < sz) ? pat_file(c, k) : 0;
    uint8_t lo = (k + 1 < sz) ? pat_file(c, k + 1) : 0;
    return (uint16_t)((hi << 8) | lo);
}

static int compare_buf(int c, uint16_t blk, const char *what) {
    int bad = 0;
    for (int w = 0; w < 1024; w++) {
        uint16_t want = exp_word(c, blk, w);
        if (cbuf[c][w] != want) {
            if (bad < 5)
                printf("FAIL: %s word %d: got %04X want %04X\n", what, w, cbuf[c][w], want);
            bad++;
        }
    }
    return bad;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    top = new Vnd_storage_vtop;

    if (!card.load(IMG_NAME)) {
        printf("TB_RESULT: FAIL cannot open %s (run make_storage_image.sh)\n", IMG_NAME);
        return 1;
    }

    // ---- parse the image, locate the three files, set the legal write set
    FatGeom geom;
    if (!parse_geom(card.mem, geom)) {
        printf("TB_RESULT: FAIL cannot parse the FAT16 boot sector\n");
        return 1;
    }
    FileLoc f_tape, f_flp1, f_flp2;
    if (!find_by_size(card.mem, geom, TAPE_BYTES, f_tape) ||
        !find_by_size(card.mem, geom, FLP1_BYTES, f_flp1) ||
        !find_by_size(card.mem, geom, FLP2_BYTES, f_flp2)) {
        printf("TB_RESULT: FAIL cannot locate the three files by size in the image\n");
        return 1;
    }
    if (!chain_ok(card.mem, geom, f_tape.cluster, f_tape.size) ||
        !chain_ok(card.mem, geom, f_flp1.cluster, f_flp1.size) ||
        !chain_ok(card.mem, geom, f_flp2.cluster, f_flp2.size)) {
        printf("TB_RESULT: FAIL a file chain is not contiguous at load (bad image)\n");
        return 1;
    }
    // ALWAYS-ON safety assertion: legal writes only inside the files' data
    // sectors (the design never legitimately writes anywhere else)
    card.legal.push_back({f_tape.first_sector, f_tape.nsectors});
    card.legal.push_back({f_flp1.first_sector, f_flp1.nsectors});
    card.legal.push_back({f_flp2.first_sector, f_flp2.nsectors});
    printf("image: TAPE.BPUN sec %u+%u, FLOPPY1.IMG sec %u+%u, FLOPPY2.IMG sec %u+%u\n",
           f_tape.first_sector, f_tape.nsectors, f_flp1.first_sector, f_flp1.nsectors,
           f_flp2.first_sector, f_flp2.nsectors);

    // expected post-run image: the load snapshot, patched only where the
    // VERIFIED writes land; final gate = full byte-compare against it
    std::vector<uint8_t> expected(card.mem);

    // ---- reset
    top->rst_n = 0;
    top->open_req_i = 0;
    top->req_i = 0;
    top->wr_i = 0;
    top->block0 = top->block1 = top->block2 = top->block3 = 0;
    top->buf_rdata0 = top->buf_rdata1 = top->buf_rdata2 = 0;
    top->mem_rdata = 0;
    top->mem_busy = 0;
    top->mem_done = 0;
    apply_card_pins();
    run_cpu(20);
    top->rst_n = 1;
    run_cpu(50);

    check(top->sd_status == 0, "sd_status NOTCHK after reset");

    // =================================================================
    // TEST 1: open clients 0..2, preload byte-exact, size/n_blocks
    // =================================================================
    printf("---- test 1: open + preload ----\n");
    static const long SIZES[3] = {TAPE_BYTES, FLP1_BYTES, FLP2_BYTES};
    static const int NBLOCKS[3] = {2, 6, 4};
    static const char *NAMES[3] = {"tape", "floppy1", "floppy2"};
    for (int c = 0; c < 3; c++) {
        char what[64];
        snprintf(what, sizeof what, "open %s", NAMES[c]);
        if (!do_open(c, what)) return 1;
        bool ok_flags = ((top->open_ok_o >> c) & 1) && !((top->open_err_o >> c) & 1) &&
                        !((top->err_o >> c) & 1);
        char m[96];
        snprintf(m, sizeof m, "%s open_ok (ok=%d oerr=%d err=%d)", NAMES[c],
                 (top->open_ok_o >> c) & 1, (top->open_err_o >> c) & 1, (top->err_o >> c) & 1);
        check(ok_flags, m);
        uint32_t sz = c == 0 ? top->size_bytes0 : (c == 1 ? top->size_bytes1 : top->size_bytes2);
        snprintf(m, sizeof m, "%s size_bytes = %u (want %ld)", NAMES[c], sz, SIZES[c]);
        check(sz == (uint32_t)SIZES[c], m);
        // Phase 4: NOTHING is preloaded, so there is no region copy to
        // inspect. Content is proven the only way that now means anything -
        // read every block through the CLIENT PORT, which drives the fetch
        // (or cache hit) path all the way to the card. Bytes at or past
        // size_bytes must read as ZERO: a fetch pulls whole 2048-byte
        // blocks, so the last block of a file that is not a multiple of
        // 2048 also drags in cluster slack, and the engine zero-fills it to
        // keep v1's tail-padding contract.
        int bad = 0;
        for (int blk = 0; blk < NBLOCKS[c]; blk++) {
            char rm[96];
            memset(cbuf[c], 0xEE, sizeof cbuf[c]);
            snprintf(rm, sizeof rm, "fetch %s blk %d", NAMES[c], blk);
            if (!do_req(c, false, (uint16_t)blk, rm)) return 1;
            for (long j = 0; j < 1024; j++) {
                long k0 = (long)blk * 2048 + 2 * j;
                long k1 = k0 + 1;
                uint16_t expw = 0;
                if (k0 < SIZES[c]) expw |= (uint16_t)pat_file(c, k0) << 8;
                if (k1 < SIZES[c]) expw |= (uint16_t)pat_file(c, k1);
                if (cbuf[c][j] != expw) {
                    if (bad < 5)
                        printf("FAIL: %s blk %d word %ld: got %04X want %04X\n",
                               NAMES[c], blk, j, cbuf[c][j], expw);
                    bad++;
                }
            }
        }
        snprintf(m, sizeof m, "%s block content byte-exact via client port", NAMES[c]);
        check(bad == 0, m);
    }
    check(top->sd_status == 3, "sd_status OK after the good opens");
    check(top->fs_type == 2, "fs_type latched FAT16");
    check(top->card_type != 0, "card_type latched nonzero");

    // n_blocks proven behaviorally: last block reads OK, block == n_blocks errs
    for (int c = 0; c < 3; c++) {
        char m[96];
        memset(cbuf[c], 0xEE, sizeof cbuf[c]);
        snprintf(m, sizeof m, "read %s last block", NAMES[c]);
        if (!do_req(c, false, (uint16_t)(NBLOCKS[c] - 1), m)) return 1;
        snprintf(m, sizeof m, "%s last block (blk %d) read err=0", NAMES[c], NBLOCKS[c] - 1);
        check(!((top->err_o >> c) & 1), m);
        int bad = compare_buf(c, (uint16_t)(NBLOCKS[c] - 1), m);
        snprintf(m, sizeof m, "%s last block content exact (n_blocks upper edge)", NAMES[c]);
        check(bad == 0, m);
        // out of range: block == n_blocks answers err with zero traffic
        uint64_t mem_before = memm.start_pulses;
        uint64_t sd_before = sd_posedge_count;
        snprintf(m, sizeof m, "read %s out-of-range block", NAMES[c]);
        if (!do_req(c, false, (uint16_t)NBLOCKS[c], m)) return 1;
        snprintf(m, sizeof m, "%s block %d (== n_blocks) answers err", NAMES[c], NBLOCKS[c]);
        check((top->err_o >> c) & 1, m);
        snprintf(m, sizeof m, "%s out-of-range: zero mem-port and zero SD traffic", NAMES[c]);
        check(memm.start_pulses == mem_before && sd_posedge_count == sd_before, m);
    }

    // =================================================================
    // TEST 2: block reads through the client ports, byte-compared
    // =================================================================
    printf("---- test 2: block reads ----\n");
    {
        static const uint16_t RBLK[3] = {0, 3, 2};
        for (int c = 0; c < 3; c++) {
            char m[96];
            memset(cbuf[c], 0xEE, sizeof cbuf[c]);
            snprintf(m, sizeof m, "read %s block %u", NAMES[c], RBLK[c]);
            if (!do_req(c, false, RBLK[c], m)) return 1;
            check(!((top->err_o >> c) & 1), m);
            int bad = compare_buf(c, RBLK[c], m);
            snprintf(m, sizeof m, "%s block %u byte-exact via client port", NAMES[c], RBLK[c]);
            check(bad == 0, m);
        }
    }

    // =================================================================
    // TEST 3: concurrency - three clients pending simultaneously
    // =================================================================
    printf("---- test 3: concurrency ----\n");
    {
        static const uint16_t CBLK[3] = {1, 4, 3};
        uint64_t dc_before[3], sd_before = sd_posedge_count;
        for (int c = 0; c < 3; c++) {
            dc_before[c] = done_count[c];
            memset(cbuf[c], 0xEE, sizeof cbuf[c]);
            set_block(c, CBLK[c]);
        }
        top->wr_i = 0;
        top->req_i = 0x7;  // clients 0,1,2 in the same cpu cycle
        run_cpu(1);
        top->req_i = 0;
        for (int c = 0; c < 3; c++) {
            char m[64];
            snprintf(m, sizeof m, "concurrent read client %d", c);
            if (!op_wait(c, 4000000, m)) return 1;
        }
        for (int c = 0; c < 3; c++) {
            char m[96];
            snprintf(m, sizeof m, "concurrent client %d err=0", c);
            check(!((top->err_o >> c) & 1), m);
            snprintf(m, sizeof m, "concurrent client %d served exactly once", c);
            check(done_count[c] == dc_before[c] + 1, m);
            int bad = compare_buf(c, CBLK[c], "concurrent");
            snprintf(m, sizeof m, "concurrent client %d block %u: own pattern, no cross-leak",
                     c, CBLK[c]);
            check(bad == 0, m);
        }
        // v1 asserted the OPPOSITE (== sd_before): with the whole image
        // preloaded, a read never went near the card. Nothing is preloaded
        // now, so a read that produced no card traffic would mean it was
        // served from a stale region - the failure this guards against.
        check(sd_posedge_count != sd_before,
              "concurrent reads DID touch the card (nothing is preloaded now)");
    }

    // =================================================================
    // TEST 3w (acceptance 2/3 write side): write-through with ordering
    // =================================================================
    printf("---- test 3w: block write-through ----\n");
    {
        const uint16_t WBLK = 2;  // FLOPPY1.IMG block 2 (bytes 4096..6143)
        for (int w = 0; w < 1024; w++) cbuf[1][w] = (uint16_t)(0x9100 + 7 * w);
        // Phase 4: where a block LIVES in the region is no longer
        // slot_base+block. Client 1 is DIRECT (not in CACHE_MASK), so its
        // block lands in the shared staging line at STAGE_BASE_BLK - one
        // line is enough because the arbiter serves one client at a time.
        // The card-first/SDRAM-second ordering this measures is unchanged
        // and still worth proving; only the address moved.
        const int STAGE_BLK = 0;   // = nd_storage's STAGE_BASE_BLK
        memm.arm_watch(STAGE_BLK * 512, STAGE_BLK * 512 + 512);
        uint32_t commits_before = card.commit_count;
        if (!do_req(1, true, WBLK, "write floppy1 block 2")) return 1;
        check(!((top->err_o >> 1) & 1), "write floppy1 block 2 err=0");
        check(card.commit_count == commits_before + 4,
              "exactly 4 card sectors committed (1 block = 4 CMD24)");
        char m[128];
        snprintf(m, sizeof m,
                 "card-first/SDRAM-second: last card commit @%llu < first SDRAM write @%llu",
                 (unsigned long long)card.last_commit_cycle,
                 (unsigned long long)memm.watch_first_cycle);
        check(memm.watch_hit && card.last_commit_cycle < memm.watch_first_cycle, m);
        memm.watch_armed = false;

        // card image: the block's 2048 bytes at the right file sectors
        size_t coff = (size_t)f_flp1.first_sector * 512 + (size_t)WBLK * 2048;
        int bad = 0;
        for (int i = 0; i < 2048; i++) {
            uint16_t w16 = (uint16_t)(0x9100 + 7 * (i >> 1));
            uint8_t want = (i & 1) ? (uint8_t)w16 : (uint8_t)(w16 >> 8);
            if (card.mem[coff + i] != want) bad++;
            expected[coff + i] = want;  // patch the expected post-run image
        }
        check(bad == 0, "write-through landed byte-exact in the card image");
        // SDRAM copy matches
        bad = 0;
        for (int mw = 0; mw < 512; mw++) {
            uint16_t a = (uint16_t)(0x9100 + 7 * (2 * mw));
            uint16_t b = (uint16_t)(0x9100 + 7 * (2 * mw + 1));
            uint32_t expw = ((uint32_t)a << 16) | b;
            if (memm.mem[STAGE_BLK * 512 + mw] != expw) bad++;
        }
        check(bad == 0, "region copy of the written block matches (staging line)");
        // neighbor blocks untouched on the card
        bad = 0;
        for (int i = 0; i < 2048; i++) {
            if (card.mem[(size_t)f_flp1.first_sector * 512 + 2048 + i] != pat_flp1(2048 + i)) bad++;
            if (card.mem[(size_t)f_flp1.first_sector * 512 + 3 * 2048 + i] != pat_flp1(3 * 2048 + i)) bad++;
        }
        check(bad == 0, "neighbor blocks 1 and 3 untouched on the card");
        // read-back through the client port
        memset(cbuf[1], 0xEE, sizeof cbuf[1]);
        if (!do_req(1, false, WBLK, "read back floppy1 block 2")) return 1;
        bad = 0;
        for (int w = 0; w < 1024; w++)
            if (cbuf[1][w] != (uint16_t)(0x9100 + 7 * w)) bad++;
        check(bad == 0, "written block reads back exactly via the client port");
    }
    if (fatal_guard("test 3w")) { errors++; goto verdict; }

    // =================================================================
    // TEST 5: error injection + missing file
    // =================================================================
    printf("---- test 5: errors ----\n");
    {
        const uint16_t EBLK = 1;  // FLOPPY2.IMG block 1
        for (int w = 0; w < 1024; w++) cbuf[2][w] = (uint16_t)(0x4400 + 3 * w);
        // snapshot the SDRAM slot words that must NOT change
        std::vector<uint32_t> snap(512);
        for (int mw = 0; mw < 512; mw++)
            snap[mw] = memm.mem[SLOT_BASE_BLK[2] * 512 + EBLK * 512 + mw];
        std::vector<uint8_t> card_snap(card.mem);

        card.inject_fail = 1;  // reject the next CMD24 data block
        if (!do_req(2, true, EBLK, "write floppy2 block 1 (injected fail)")) return 1;
        check((top->err_o >> 2) & 1, "injected CMD24 failure: client got done+err");
        check(card.injected == 1, "the injection actually fired");
        int bad = 0;
        for (int mw = 0; mw < 512; mw++)
            if (memm.mem[SLOT_BASE_BLK[2] * 512 + EBLK * 512 + mw] != snap[mw]) bad++;
        check(bad == 0, "SDRAM slot NOT corrupted by the failed write");
        check(card.mem == card_snap, "card image unchanged by the failed write");
        check((top->open_ok_o >> 2) & 1, "open_ok stays up across the write error (spec sec 7)");
        check(top->sd_status == 2, "sd_status degraded to ERROR after the write failure");

        // retry without injection: must succeed and commit everywhere
        if (!do_req(2, true, EBLK, "write floppy2 block 1 (retry)")) return 1;
        check(!((top->err_o >> 2) & 1), "retry after the injected failure succeeds");
        size_t coff = (size_t)f_flp2.first_sector * 512 + (size_t)EBLK * 2048;
        bad = 0;
        for (int i = 0; i < 2048; i++) {
            uint16_t w16 = (uint16_t)(0x4400 + 3 * (i >> 1));
            uint8_t want = (i & 1) ? (uint8_t)w16 : (uint8_t)(w16 >> 8);
            if (card.mem[coff + i] != want) bad++;
            expected[coff + i] = want;
        }
        check(bad == 0, "retry write-through landed byte-exact in the card image");

        // missing file: client 3 (SMD0.IMG absent, inside PRELOAD_MASK here)
        if (!do_open(3, "open missing SMD0.IMG")) return 1;
        check(((top->open_err_o >> 3) & 1) && !((top->open_ok_o >> 3) & 1) &&
                  ((top->err_o >> 3) & 1),
              "missing-file open answers open_err (no open_ok)");
    }
    if (fatal_guard("test 5")) { errors++; goto verdict; }

    // =================================================================
    // post-run fsck: re-parse the card image after all the write traffic
    // =================================================================
    printf("---- post-run card image fsck ----\n");
    {
        // boot sector / reserved region byte-identical to the load snapshot
        int bad = 0;
        for (size_t i = 0; i < card.resv_snap.size(); i++)
            if (card.mem[i] != card.resv_snap[i]) bad++;
        check(bad == 0, "boot sector / reserved region byte-identical");

        FatGeom g2;
        check(parse_geom(card.mem, g2), "post-run boot sector still parses");
        FileLoc p_tape, p_flp1, p_flp2;
        bool dirs = find_by_size(card.mem, g2, TAPE_BYTES, p_tape) &&
                    find_by_size(card.mem, g2, FLP1_BYTES, p_flp1) &&
                    find_by_size(card.mem, g2, FLP2_BYTES, p_flp2);
        check(dirs, "root directory entries intact (all three files, exact sizes)");
        if (dirs) {
            check(p_tape.cluster == f_tape.cluster && p_flp1.cluster == f_flp1.cluster &&
                      p_flp2.cluster == f_flp2.cluster,
                  "directory first-cluster fields unchanged");
            check(chain_ok(card.mem, g2, p_tape.cluster, p_tape.size) &&
                      chain_ok(card.mem, g2, p_flp1.cluster, p_flp1.size) &&
                      chain_ok(card.mem, g2, p_flp2.cluster, p_flp2.size),
                  "FAT chains contiguous with intact end-of-chain");
        }
        // the strongest gate: the whole image equals the load snapshot
        // patched ONLY where the verified writes landed
        size_t diff = 0, first = 0;
        for (size_t i = 0; i < card.mem.size(); i++)
            if (card.mem[i] != expected[i]) { if (!diff) first = i; diff++; }
        char m[128];
        snprintf(m, sizeof m,
                 "card image differs from the expected image ONLY at the written blocks"
                 " (%zu stray bytes, first at %zu)", diff, first);
        check(diff == 0, m);
    }

    // ---- health -----------------------------------------------------------
    check(card.crc_errors == 0, "no CMD CRC7 errors");
    check(card.wr_crc_errors == 0, "no write-data CRC16 errors");
    check(card.illegal_writes == 0, "no illegal card writes (always-on assertion)");

verdict:
    // dump the post image for the Makefile's fsck.vfat gate
    {
        FILE *pf = fopen(POST_NAME, "wb");
        if (pf) {
            fwrite(card.mem.data(), 1, card.mem.size(), pf);
            fclose(pf);
            printf("post image written: %s\n", POST_NAME);
        } else {
            printf("FAIL: cannot write %s\n", POST_NAME);
            errors++;
        }
    }

    printf("stats: %llu clk_stor cycles, %llu clk_cpu cycles, %llu sd_clk edges\n",
           (unsigned long long)g_stor_posedges, (unsigned long long)g_cpu_posedges,
           (unsigned long long)sd_posedge_count);
    if (errors == 0) printf("TB_RESULT: PASS\n");
    else printf("TB_RESULT: FAIL %d errors\n", errors);

    top->final();
    delete top;
    return errors ? 1 : 0;
}
