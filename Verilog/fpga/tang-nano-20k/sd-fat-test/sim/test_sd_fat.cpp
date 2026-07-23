/****************************************************************************
** Verilator testbench for the SD-FAT test (test_*.cpp per repo convention)**
**                                                                         **
** Same test plan as sd_fat_test_tb.v (iverilog), but with the SD card    **
** model in C++ (Verilator cannot run the event-driven Verilog model):     **
**                                                                         **
**   - behavioral SD card serving sectors from fat16.img                   **
**     (CMD0/8/55/ACMD41/2/3/7/16/17 reads + CMD24 single-sector WRITE +   **
**     CMD18/CMD25 multi-block bursts with ACMD23 and CMD12, inter-block   **
**     and final busy, SDHC, CRC7-checked commands, CRC16 on data blocks   **
**     both ways, ACMD6 4-bit bus mode: data as nibbles on DAT3..DAT0      **
**     with a CRC16 per line, CRC-status/busy on DAT0 only, CMD0 resets    **
**     the width - the writer engine runs 4-bit by default, rung c)        **
**   - drives the UART menu: '2' DUMP (verify bytes + LENGTH against       **
**     payload.bin), '1' LIST (sizes + dates + <DIR> entries),             **
**     '3' COPY to TEST.TXT (verifies the payload landed a second time     **
**     in the card image), '4' WRBLK1 (verifies the word[w]=w pattern in   **
**     1KW block 1 of BOOT.BPUN and that blocks 0/2 are untouched, both    **
**     in the card image and via a second dump), 'H' help,                 **
**     menu SD: status line NOT CHECKED -> OK                              **
**                                                                         **
** Filesystem-safety assertions (always on, every plan):                   **
**   - the card model REFUSES to trust any write into the volume's         **
**     RESERVED region (boot sector, FSInfo, backup boot): each CMD24 AND  **
**     each individual block of a CMD25 burst is checked, counted as an    **
**     illegal write and fails the test. Nothing the design does           **
**     legitimately ever writes below the first FAT.                       **
**   - the reserved region bytes are snapshotted at load and byte-compared **
**     after every destructive command.                                    **
**   (Added after a field failure: the FAT surgeon's create path flushed   **
**   the patched directory sector to sector 0 and destroyed a real card's  **
**   boot sector - see sd_fat_rewrite.v S_DIR_W.)                          **
**                                                                         **
** Test plans (+plan=<name>):                                              **
**   (default)   full menu walk: 2,1,3,1,3,H,4,2,7,6,7,5                   **
**   +plan=cold  destructive commands 6,3,4 each as the FIRST command      **
**     after a fresh reset (S1 between them) - the field failure needed a  **
**     cold start: the default plan's earlier COPY left a valid directory  **
**     sector in the geometry capture registers, masking the create bug    **
**   +plan=big   big-geometry field reproduction (use with fat32big.img:   **
**     32 sec/cluster like a real 16-32 GB SDHC): cold-start '6'           **
**     (create+write IO.DAT), then '1' LIST must still show the            **
**     filesystem, then '7' streams the file back                          **
**                                                                         **
** Build & run: make test-verilator (in this sim/ directory)               **
** Verdict:     TB_RESULT: PASS / TB_RESULT: FAIL <reason>                 **
**                                                                         **
** Interactive: make console (runs this binary with +interactive) - your   **
** terminal is bridged to the simulated UART: the menu appears, keys are   **
** sent to the design, ESC exits. Same FAT16 image as the scripted test.   **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/

#include <cctype>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>
#include <deque>

#include <termios.h>
#include <fcntl.h>
#include <unistd.h>

#include "Vsd_fat_test_vtop.h"
#include "verilated.h"

static const int DELAY_FRAMES = 27;  // 27 MHz / 1 Mbaud (matches the wrapper)

static bool g_interactive = false;

// ------------------------------------------------------------------ SD card
struct SDCard {
    std::vector<uint8_t> mem;
    bool app_cmd = false;
    int crc_errors = 0;

    // filesystem-safety assertion: no legal operation ever writes into the
    // volume's reserved region (boot sector, FSInfo, backup boot sector).
    // resv_sectors is parsed from the BPB at load; every CMD24 below it is
    // counted here and fails the test.
    uint32_t resv_sectors = 1;
    int illegal_writes = 0;
    std::vector<uint8_t> resv_snap;  // reserved-region bytes at load time

    // command receive (bits sampled on sd_clk rising edges)
    uint64_t sh = 0;
    int rxcnt = -1;  // -1 = hunting for the start bit

    // CMD response queue (played on falling edges) and the DAT queue:
    // each DAT entry is (drive_mask << 4) | nibble_value - 1-bit traffic
    // and all status/busy tokens use mask 0x1 (DAT0 only), 4-bit read
    // blocks use mask 0xF (per the SD spec the card never drives DAT1-3
    // outside a 4-bit data block)
    std::vector<uint8_t> cq;
    size_t cpos = 0;
    int ncr = 0;
    std::vector<uint16_t> dq;
    size_t dpos = 0;
    int ddelay = 0;

    // bus width (ACMD6 arg 2 = 4-bit; CMD0 resets to 1-bit)
    bool bus4 = false;

    // CMD24/CMD25 write-block receive state (sampled on rising edges;
    // bit-serial on DAT0 in 1-bit mode, nibbles on DAT3..DAT0 in 4-bit)
    bool wr_expect = false;   // R1 sent, waiting for the host data start bit
    bool wr_active = false;   // collecting data bits
    bool wr_wide = false;     // the active block is a 4-bit transfer
    uint64_t wr_base = 0;     // byte address of the target sector
    int wr_bit = 0;
    uint8_t wr_byte = 0;
    uint16_t wr_crc = 0, wr_crc_host = 0;
    uint16_t wr_crc4[4] = {0, 0, 0, 0};       // per-line CRC16 (4-bit mode)
    uint16_t wr_crc4_host[4] = {0, 0, 0, 0};  // per-line host CRC16
    std::vector<uint8_t> wr_buf;
    int wr_crc_errors = 0;

    // multi-block state (CMD18/CMD25 bursts, terminated by CMD12)
    bool rd_multi = false;    // CMD18: keep streaming blocks until CMD12
    uint64_t rd_base = 0;     // byte address of the NEXT block to stream
    bool wr_multi = false;    // CMD25: keep accepting blocks until CMD12
    uint32_t acmd23 = 0;      // last ACMD23 pre-erase block count (info)
    int cmd12_count = 0;      // STOP_TRANSMISSION commands received

    // CMD18 inter-block gap in SD clocks between a block's end bit and the
    // next start bit. Real cards stream back-to-back (spec N_AC minimum is
    // 2) - keep this MINIMAL so a host that re-arms its start-bit hunt too
    // slowly fails HERE first, not on silicon.
    int read_gap = 2;

    // error-text injection hooks (scoped to the 4-bit bus = the writer
    // engine; the reader's 1-bit mount/stream reads stay healthy):
    //   fail_reads4    - data-carrying read commands (CMD17/CMD18) are
    //                    answered with R1 but NO data block ever starts:
    //                    the host read times out (a dying card)
    //   corrupt_reads4 - read blocks are served as all-0xFF with VALID
    //                    CRC: the read SUCCEEDS but a FAT scan sees a
    //                    fully allocated FAT (genuine no-space verdict)
    bool fail_reads4 = false;
    bool corrupt_reads4 = false;

    // pin state (per-line drive enables; dat1-3 only in 4-bit read blocks)
    int cmd_drive = 0, cmd_val = 1;
    int dat_drive = 0, dat0 = 1;
    int dat1_drive = 0, dat1 = 1;
    int dat2_drive = 0, dat2 = 1;
    int dat3_drive = 0, dat3 = 1;

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
        // parse the superfloppy DBR for the reserved-region size
        resv_sectors = 1;
        if (n >= 512 && (mem[0] == 0xEB || mem[0] == 0xE9) &&
            mem[510] == 0x55 && mem[511] == 0xAA) {
            uint32_t r = (uint32_t)mem[14] | ((uint32_t)mem[15] << 8);
            if (r >= 1 && (uint64_t)r * 512 <= (uint64_t)n) resv_sectors = r;
        }
        resv_snap.assign(mem.begin(), mem.begin() + (size_t)resv_sectors * 512);
        printf("sdcard: reserved region = %u sectors (writes below are illegal)\n",
               resv_sectors);
        return true;
    }

    // byte-compare the reserved region against the load-time snapshot
    int reservedDamage() const {
        int bad = 0;
        for (size_t i = 0; i < resv_snap.size(); i++)
            if (mem[i] != resv_snap[i]) bad++;
        return bad;
    }

    static uint8_t crc7_step(uint8_t c, int b) {
        int fb = ((c >> 6) & 1) ^ (b & 1);
        return (uint8_t)(((c << 1) & 0x7F) ^ (fb ? 0x09 : 0));
    }
    static uint16_t crc16_step(uint16_t c, int b) {
        int fb = ((c >> 15) & 1) ^ (b & 1);
        return (uint16_t)((c << 1) ^ (fb ? 0x1021 : 0));
    }

    void push48(uint64_t head40) {  // 40 bits of {00,cmd,arg}, add CRC7+stop
        uint8_t c = 0;
        for (int i = 39; i >= 0; i--) c = crc7_step(c, (head40 >> i) & 1);
        for (int i = 39; i >= 0; i--) cq.push_back((head40 >> i) & 1);
        for (int i = 6; i >= 0; i--) cq.push_back((c >> i) & 1);
        cq.push_back(1);
    }

    // queue one 512-byte read block (start + data + CRC16 + end); 1-bit:
    // serial on DAT0, 4-bit: nibbles on DAT3..DAT0 with a CRC16 per line
    void queueBlock(uint64_t base, int delay) {
        dq.clear(); dpos = 0; ddelay = delay;
        if (bus4) {
            dq.push_back(0xF0);  // start nibble 0x0 on all four lines
            uint16_t crc[4] = {0, 0, 0, 0};
            for (int i = 0; i < 1024; i++) {
                uint8_t byte = (base + i / 2 < mem.size()) ? mem[base + i / 2] : 0xFF;
                if (corrupt_reads4) byte = 0xFF;  // injected: FAT reads full
                int nib = (i & 1) ? (byte & 0xF) : (byte >> 4);  // MSB nibble first
                dq.push_back((uint16_t)(0xF0 | nib));
                for (int l = 0; l < 4; l++)
                    crc[l] = crc16_step(crc[l], (nib >> l) & 1);
            }
            for (int i = 15; i >= 0; i--) {
                int nib = 0;
                for (int l = 0; l < 4; l++) nib |= ((crc[l] >> i) & 1) << l;
                dq.push_back((uint16_t)(0xF0 | nib));
            }
            dq.push_back(0xFF);  // end nibble 0xF
        } else {
            dq.push_back(0x10);  // start bit (mask DAT0 only)
            uint16_t crc = 0;
            for (int i = 0; i < 512; i++) {
                uint8_t byte = (base + i < mem.size()) ? mem[base + i] : 0xFF;
                for (int b = 7; b >= 0; b--) {
                    int bit = (byte >> b) & 1;
                    dq.push_back((uint16_t)(0x10 | bit));
                    crc = crc16_step(crc, bit);
                }
            }
            for (int i = 15; i >= 0; i--) dq.push_back((uint16_t)(0x10 | ((crc >> i) & 1)));
            dq.push_back(0x11);  // end bit
        }
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

        // DATA-STATE guard (matches real silicon; a stateless model masked
        // a field failure): while the card is transmitting read data - a
        // block queue still draining or an open CMD18 stream - it is in the
        // SENDING-DATA state and any command except CMD12 (stop) and CMD0
        // (reset) is illegal there: NO response, the data keeps flowing.
        // The menu-7 field failure was exactly a host that parked its
        // reader mid-read and then issued CMD18 to a card still sending.
        if ((!dq.empty() || rd_multi) && cmd != 12 && cmd != 0) {
            printf("sdcard: CMD%u while in SENDING-DATA state - ignored (no response)\n",
                   cmd);
            return;
        }

        cq.clear(); cpos = 0; ncr = 4;
        bool data = false;
        uint64_t head;
        switch (cmd) {
            case 0:  // GO_IDLE: always accepted; resets width and stops DAT
                app_cmd = false;
                bus4 = false;
                rd_multi = false;
                wr_multi = false;
                wr_expect = false;
                wr_active = false;
                dq.clear(); dpos = 0; ddelay = 0;
                datRelease();
                break;
            case 6:  // ACMD6: bus width (arg 2 = 4-bit); bare CMD6 unmodeled
                if (app_cmd) {
                    push48(((uint64_t)6 << 32) | 0x00000920ULL);
                    bus4 = ((arg & 0xF) == 2);
                } else {
                    printf("sdcard: CMD6 without CMD55 - no response\n");
                }
                app_cmd = false;
                break;
            case 8: push48(((uint64_t)8 << 32) | 0x000001AAULL); break;
            case 55:  // APP_CMD: only for RCA 0x0000 (pre-init) / 0x0001 (ours)
                if ((arg >> 16) == 0 || (arg >> 16) == 1) {
                    push48(((uint64_t)55 << 32) | 0x00000120ULL);
                    app_cmd = true;
                } else {
                    printf("sdcard: CMD55 with wrong RCA %04X ignored\n", arg >> 16);
                    app_cmd = false;
                }
                break;
            case 23:  // ACMD23 pre-erase count; bare CMD23 gets NO response
                if (app_cmd) {
                    push48(((uint64_t)23 << 32) | 0x00000900ULL);
                    acmd23 = arg & 0x7FFFFF;
                } else {
                    printf("sdcard: CMD23 without CMD55 (wrong RCA?) - no response\n");
                }
                app_cmd = false;
                break;
            case 12:  // STOP_TRANSMISSION: R1 (write bursts: R1b, final busy)
                push48(((uint64_t)12 << 32) | 0x00000900ULL);
                cmd12_count++;
                if (rd_multi) { dq.clear(); dpos = 0; ddelay = 0; }  // stop streaming
                if (wr_multi) {  // final busy on DAT0 while programming ends
                    dq.clear(); dpos = 0; ddelay = 2;
                    dq.push_back(0x10);
                    for (int b = 0; b < 64; b++) dq.push_back(0x10);
                    dq.push_back(0x11);
                }
                rd_multi = false;
                wr_multi = false;
                wr_expect = false;
                wr_active = false;
                break;
            case 41:
                if (app_cmd) {  // R3: reserved cmd field, OCR, no CRC
                    head = ((uint64_t)0x3F << 32) | 0xC0FF8000ULL;
                    for (int i = 39; i >= 0; i--) cq.push_back((head >> i) & 1);
                    for (int i = 0; i < 7; i++) cq.push_back(1);
                    cq.push_back(1);
                }
                app_cmd = false;
                break;
            case 2: {  // R2 / CID, 136 bits: 00 111111 CID[127:1] 1
                cq.push_back(0); cq.push_back(0);
                for (int i = 0; i < 6; i++) cq.push_back(1);
                for (int i = 0; i < 127; i++) cq.push_back((i * 7) & 1);
                cq.push_back(1);
                break;
            }
            case 3: push48(((uint64_t)3 << 32) | 0x00010500ULL); break;
            case 9: {  // SEND_CSD: R2, CSD v2.0 with capacity = mem.size()
                uint8_t csd[16] = {0};
                uint32_t c_size = (uint32_t)(mem.size() >> 19) - 1;  // 512KB units - 1
                csd[0] = 0x40;  // CSD_STRUCTURE = 1 (version 2.0)
                csd[7] = (uint8_t)((c_size >> 16) & 0x3F);  // C_SIZE at CSD[69:48]
                csd[8] = (uint8_t)(c_size >> 8);
                csd[9] = (uint8_t)c_size;
                // frame: 00 111111 CSD[127:1] end; CSD bit k = csd[15-k/8] bit k%8
                cq.push_back(0); cq.push_back(0);
                for (int i = 0; i < 6; i++) cq.push_back(1);
                for (int k = 127; k >= 1; k--)
                    cq.push_back((csd[15 - k / 8] >> (k % 8)) & 1);
                cq.push_back(1);
                break;
            }
            case 7: push48(((uint64_t)7 << 32) | 0x00000700ULL); break;
            case 16: push48(((uint64_t)16 << 32) | 0x00000900ULL); break;
            case 17:
                push48(((uint64_t)17 << 32) | 0x00000900ULL);
                if (bus4 && fail_reads4)
                    printf("sdcard: CMD17 read FAILED (injected: no data)\n");
                else data = true;
                break;
            case 18:  // READ_MULTIPLE_BLOCK: R1, blocks stream until CMD12
                push48(((uint64_t)18 << 32) | 0x00000900ULL);
                if (bus4 && fail_reads4)
                    printf("sdcard: CMD18 read FAILED (injected: no data)\n");
                else {
                    data = true;
                    rd_multi = true;
                }
                break;
            case 24:  // WRITE_BLOCK: R1, then receive the data block on DAT0
                push48(((uint64_t)24 << 32) | 0x00000900ULL);
                wr_expect = true;
                wr_active = false;
                wr_multi = false;
                wr_base = (uint64_t)arg * 512;  // SDHC: arg = sector number
                wr_buf.clear();
                // legal-target assertion: nothing ever writes the reserved
                // region (the field failure was a CMD24 to sector 0)
                if (arg < resv_sectors) {
                    illegal_writes++;
                    printf("sdcard: ILLEGAL WRITE to reserved sector %u\n", arg);
                }
                break;
            case 25:  // WRITE_MULTIPLE_BLOCK: R1, blocks accepted until CMD12
                push48(((uint64_t)25 << 32) | 0x00000900ULL);
                wr_expect = true;
                wr_active = false;
                wr_multi = true;
                wr_base = (uint64_t)arg * 512;  // SDHC: arg = sector number
                wr_buf.clear();
                // the legal-target assertion runs per BLOCK at completion,
                // so every sector of the burst is validated like a CMD24
                break;
            default: break;  // no response -> host times out
        }

        if (data) {
            uint64_t base = (uint64_t)arg * 512;  // SDHC: arg = sector number
            queueBlock(base, 4 + 48 + 8);  // after the R1 response + a small gap
            rd_base = base + 512;          // CMD18: next block of the stream
        }
    }

    // finish a received write block: validate, commit, queue the CRC status
    // token ("010"/"101") and busy - on DAT0 alone, in every bus width
    void finishWriteBlock(bool crc_ok) {
        if (!crc_ok) {
            wr_crc_errors++;
            printf("sdcard: write data CRC16 mismatch%s\n", wr_wide ? " (4-bit)" : "");
        }
        // CMD25: every block of the burst is validated exactly
        // like a CMD24 (always-on legal-target assertion)
        if (wr_multi && (uint32_t)(wr_base / 512) < resv_sectors) {
            illegal_writes++;
            printf("sdcard: ILLEGAL WRITE to reserved sector %u (CMD25 block)\n",
                   (uint32_t)(wr_base / 512));
        }
        for (size_t i = 0; i < 512 && wr_base + i < mem.size(); i++)
            mem[wr_base + i] = wr_buf[i];
        // CRC status token "010" + end, then ~64 clocks busy
        // (the burst's inter-block busy is this same period)
        dq.clear(); dpos = 0; ddelay = 3;
        dq.push_back(0x10); dq.push_back(0x10); dq.push_back(0x11);
        dq.push_back(0x10); dq.push_back(0x11);
        for (int b = 0; b < 64; b++) dq.push_back(0x10);  // busy
        dq.push_back(0x11);
        wr_active = false;
        if (wr_multi) wr_base += 512;  // next block of the burst
        else wr_expect = false;
    }

    // card samples on the rising edge of sd_clk (all four DAT lines)
    void onRise(int cmd_line, int d0, int d1, int d2, int d3) {
        // ---- DAT: incoming write block (host drives, we listen) ----
        if (wr_expect && !dat_drive) {
            if (!wr_active) {
                if (d0 == 0) {  // data start bit / start nibble on DAT0
                    wr_active = true;
                    wr_wide = bus4;
                    wr_bit = 0;
                    wr_byte = 0;
                    wr_crc = 0;
                    wr_crc_host = 0;
                    for (int l = 0; l < 4; l++) { wr_crc4[l] = 0; wr_crc4_host[l] = 0; }
                    wr_buf.clear();
                }
            } else if (wr_wide) {
                // 4-bit: 1024 data nibbles, then 16 CRC clocks per line
                int nib = ((d3 & 1) << 3) | ((d2 & 1) << 2) | ((d1 & 1) << 1) | (d0 & 1);
                if (wr_bit < 1024) {
                    for (int l = 0; l < 4; l++)
                        wr_crc4[l] = crc16_step(wr_crc4[l], (nib >> l) & 1);
                    if (wr_bit & 1) { wr_buf.push_back((uint8_t)((wr_byte << 4) | nib)); }
                    else wr_byte = (uint8_t)nib;
                    wr_bit++;
                } else if (wr_bit < 1040) {
                    for (int l = 0; l < 4; l++)
                        wr_crc4_host[l] = (uint16_t)((wr_crc4_host[l] << 1) | ((nib >> l) & 1));
                    wr_bit++;
                    if (wr_bit == 1040) {
                        bool ok = true;
                        for (int l = 0; l < 4; l++)
                            if (wr_crc4_host[l] != wr_crc4[l]) ok = false;
                        finishWriteBlock(ok);
                    }
                }
            } else if (wr_bit < 4096) {
                wr_byte = (uint8_t)((wr_byte << 1) | (d0 & 1));
                wr_crc = crc16_step(wr_crc, d0 & 1);
                if ((wr_bit & 7) == 7) { wr_buf.push_back(wr_byte); wr_byte = 0; }
                wr_bit++;
            } else if (wr_bit < 4112) {  // 16 CRC bits from the host
                wr_crc_host = (uint16_t)((wr_crc_host << 1) | (d0 & 1));
                wr_bit++;
                if (wr_bit == 4112) finishWriteBlock(wr_crc_host == wr_crc);
            }
        }

        // ---- CMD: command receive ----
        if (cmd_drive) return;  // our own response bits
        if (rxcnt < 0) {
            if (cmd_line == 0) { sh = 0; rxcnt = 1; }
            return;
        }
        sh = (sh << 1) | (cmd_line & 1);
        rxcnt++;
        if (rxcnt == 48) { decode(); rxcnt = -1; }
    }

    void datRelease() {
        dat_drive = 0; dat0 = 1;
        dat1_drive = 0; dat1 = 1;
        dat2_drive = 0; dat2 = 1;
        dat3_drive = 0; dat3 = 1;
    }

    // card drives on the falling edge of sd_clk
    void onFall() {
        if (!cq.empty()) {
            if (ncr > 0) { ncr--; cmd_drive = 0; cmd_val = 1; }
            else if (cpos < cq.size()) { cmd_drive = 1; cmd_val = cq[cpos++]; }
            else { cq.clear(); cpos = 0; cmd_drive = 0; cmd_val = 1; }
        } else { cmd_drive = 0; cmd_val = 1; }

        if (!dq.empty()) {
            if (ddelay > 0) { ddelay--; datRelease(); }
            else if (dpos < dq.size()) {
                uint16_t e = dq[dpos++];
                int mask = (e >> 4) & 0xF;
                dat_drive = mask & 1;         dat0 = e & 1;
                dat1_drive = (mask >> 1) & 1; dat1 = (e >> 1) & 1;
                dat2_drive = (mask >> 2) & 1; dat2 = (e >> 2) & 1;
                dat3_drive = (mask >> 3) & 1; dat3 = (e >> 3) & 1;
            } else {
                dq.clear(); dpos = 0; datRelease();
                if (rd_multi) {  // CMD18: next block after the MINIMAL gap
                    queueBlock(rd_base, read_gap);
                    rd_base += 512;
                }
            }
        } else datRelease();
    }
};

// ------------------------------------------------------------------ UART
struct UartRx {  // decodes the DUT's TX line, sampled once per clk cycle
    int state = 0, cnt = 0, bitno = 0;
    uint8_t sh = 0;
    std::string text;

    void tick(int rxd) {
        switch (state) {
            case 0: if (!rxd) { state = 1; cnt = 1; } break;
            case 1:  // half-bit alignment into the start bit
                if (++cnt >= DELAY_FRAMES / 2) { state = 2; cnt = 0; bitno = 0; sh = 0; }
                break;
            case 2:  // sample mid-bit, 8 data bits
                if (++cnt >= DELAY_FRAMES) {
                    cnt = 0;
                    sh = (uint8_t)((sh >> 1) | (rxd ? 0x80 : 0));
                    if (++bitno == 8) state = 3;
                }
                break;
            case 3:  // stop bit
                if (++cnt >= DELAY_FRAMES) {
                    text.push_back((char)sh);
                    if (g_interactive) {
                        fputc((char)sh, stdout);
                        fflush(stdout);
                    } else if (sh == '\n') {
                        size_t p = text.rfind('\n', text.size() - 2);
                        std::string line = text.substr(p == std::string::npos ? 0 : p + 1);
                        while (!line.empty() && (line.back() == '\n' || line.back() == '\r'))
                            line.pop_back();
                        printf("uart| %s\n", line.c_str());
                    }
                    state = 0; cnt = 0;
                }
                break;
        }
    }
};

struct UartTx {  // drives the DUT's RX line
    int state = 0, cnt = 0, bitno = 0;
    uint8_t sh = 0;
    int line = 1;
    bool busy() const { return state != 0; }
    void send(uint8_t c) { sh = c; state = 1; cnt = 0; }
    void tick() {
        switch (state) {
            case 0: line = 1; break;
            case 1:  // start bit
                line = 0;
                if (++cnt >= DELAY_FRAMES) { state = 2; cnt = 0; bitno = 0; }
                break;
            case 2:
                line = (sh >> bitno) & 1;
                if (++cnt >= DELAY_FRAMES) {
                    cnt = 0;
                    if (++bitno == 8) state = 3;
                }
                break;
            case 3:  // stop bit
                line = 1;
                if (++cnt >= DELAY_FRAMES) { state = 0; cnt = 0; }
                break;
        }
    }
};

// ------------------------------------------------------------------ harness
static Vsd_fat_test_vtop *top;
static SDCard card;
static UartRx urx;
static UartTx utx;
static int last_sdclk = 0;
static uint64_t cycles = 0;

// Bus-contention guard (12-JUL-2026 silicon failure: synthesis collapsed
// the DUT's DAT1-3 pad tristates into always-on drivers that fought the
// card through every 4-bit read - z-resolution in simulation hid it).
// Two defenses here:
//   1. whenever the card transmits on a line whose DUT pad driver is also
//      on, the run FAILS immediately (fatal assertion), and
//   2. a contended line feeds the DUT its OWN driven value, not the
//      card's - a push-pull FPGA output wins locally on silicon, so the
//      functional failure also reproduces exactly like hardware.
static void applyCardPins() {
    int doe = top->dat_oe_mon;   // {DAT3,DAT2,DAT1,DAT0} DUT pad drivers
    int coe = top->cmd_oe_mon;

    int contention = 0;
    if (card.cmd_drive && coe) contention |= 0x10;
    if (card.dat_drive && (doe & 1)) contention |= 0x01;
    if (card.dat1_drive && (doe & 2)) contention |= 0x02;
    if (card.dat2_drive && (doe & 4)) contention |= 0x04;
    if (card.dat3_drive && (doe & 8)) contention |= 0x08;
    if (contention) {
        printf("FATAL: SD bus contention (card and DUT both driving), "
               "mask CMD,DAT3..DAT0 = %d,%d%d%d%d at cycle %llu\n",
               (contention >> 4) & 1, (contention >> 3) & 1,
               (contention >> 2) & 1, (contention >> 1) & 1, contention & 1,
               (unsigned long long)cycles);
        printf("TB_RESULT: FAIL bus contention\n");
        exit(1);
    }

    top->sd_cmd_c_drive = card.cmd_drive && !coe;
    top->sd_cmd_c_val = card.cmd_val;
    top->sd_dat0_c_drive = card.dat_drive && !(doe & 1);
    top->sd_dat0_c_val = card.dat0;
    top->sd_dat1_c_drive = card.dat1_drive && !(doe & 2);
    top->sd_dat1_c_val = card.dat1;
    top->sd_dat2_c_drive = card.dat2_drive && !(doe & 4);
    top->sd_dat2_c_val = card.dat2;
    top->sd_dat3_c_drive = card.dat3_drive && !(doe & 8);
    top->sd_dat3_c_val = card.dat3;
}

static void step() {  // one full 27 MHz clock cycle
    // falling edge of sys_clk
    top->sys_clk = 0;
    top->eval();
    // rising edge
    top->sys_clk = 1;
    applyCardPins();
    top->uart_rxp = utx.line;
    top->eval();

    // SD clock edges (sd_clk toggles far slower than sys_clk)
    int sc = top->sd_clk;
    if (sc && !last_sdclk)
        card.onRise(top->sd_cmd_resolved, top->sd_dat0_resolved,
                    top->sd_dat1_resolved, top->sd_dat2_resolved,
                    top->sd_dat3_resolved);
    if (!sc && last_sdclk) {
        card.onFall();
        applyCardPins();
        top->eval();
    }
    last_sdclk = sc;

    urx.tick(top->uart_txp);
    utx.tick();
    cycles++;
}

static bool run_until(const std::string &pat, size_t from, uint64_t max_cycles) {
    while (cycles < max_cycles) {
        step();
        if (urx.text.find(pat, from) != std::string::npos) return true;
    }
    return false;
}

// wait for a menu prompt that appears AFTER text position 'after'
// (the text tail may still hold the previous prompt)
static bool wait_prompt(size_t after, uint64_t max_cycles) {
    while (cycles < max_cycles) {
        step();
        size_t n = urx.text.size();
        if (n >= after + 2 && urx.text[n - 2] == '#' && urx.text[n - 1] == ' ') return true;
    }
    return false;
}

static void send_key(char c) {
    while (utx.busy()) step();
    utx.send((uint8_t)c);
    while (utx.busy()) step();
}

// press S1: full board reset (the card model keeps its contents, like a
// real card in the slot across a reset)
static void pulse_s1() {
    top->s1 = 1;
    for (int i = 0; i < 100; i++) step();
    top->s1 = 0;
    for (int i = 0; i < 100; i++) step();
}

// must match the IO_BLOCKS parameter in sd_fat_test_vtop.v
static const long IO_BLOCKS_SIM = 20;

// ------------------------------------------------ expected LIST info line
// "CARD c MB  VOL v MB  FREE f MB" computed independently from the card
// image (superfloppy BPB + FAT #0), with the same truncating arithmetic as
// the RTL: VOL = total sectors >> 11, FREE = (free clusters << l2cs) >> 11.
static std::string expectedInfoLine(const std::vector<uint8_t> &m) {
    auto r16 = [&](size_t o) { return (uint32_t)m[o] | ((uint32_t)m[o + 1] << 8); };
    auto r32 = [&](size_t o) { return r16(o) | (r16(o + 2) << 16); };
    uint32_t spc = m[13];
    uint32_t rsvd = r16(14), nfat = m[16], rootn = r16(17);
    uint32_t tot16 = r16(19), spf16 = r16(22);
    uint32_t spf = spf16 ? spf16 : r32(36);
    uint32_t tot = tot16 ? tot16 : r32(32);
    bool fat32 = (spf16 == 0);
    uint32_t first_data = rsvd + nfat * spf + rootn * 32 / 512;
    uint32_t l2cs = 0;
    while ((1u << l2cs) < spc) l2cs++;
    uint32_t max_cluster = ((tot - first_data) >> l2cs) + 1;
    uint32_t freec = 0;
    for (uint32_t c = 2; c <= max_cluster; c++) {
        size_t off = (size_t)rsvd * 512 + (fat32 ? (size_t)c * 4 : (size_t)c * 2);
        uint32_t v = fat32 ? (r32(off) & 0x0FFFFFFF) : r16(off);
        if (v == 0) freec++;
    }
    uint32_t card_mb = (uint32_t)(m.size() >> 20);
    uint32_t vol_mb = tot >> 11;
    uint32_t free_mb = (uint32_t)(((uint64_t)freec << l2cs) >> 11);
    char buf[96];
    snprintf(buf, sizeof buf, "CARD %u MB  VOL %u MB  FREE %u MB",
             card_mb, vol_mb, free_mb);
    return std::string(buf);
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    for (int i = 1; i < argc; i++)
        if (!strcmp(argv[i], "+interactive")) g_interactive = true;
    top = new Vsd_fat_test_vtop;

    // payload for verification (scripted test only)
    std::vector<uint8_t> payload;
    long pl = 0;
    if (!g_interactive) {
        FILE *f = fopen("payload.bin", "rb");
        if (!f) { printf("TB_RESULT: FAIL cannot open payload.bin\n"); return 1; }
        fseek(f, 0, SEEK_END); pl = ftell(f); fseek(f, 0, SEEK_SET);
        payload.resize(pl);
        if (fread(payload.data(), 1, pl, f) != (size_t)pl) { printf("TB_RESULT: FAIL payload read\n"); return 1; }
        fclose(f);
        printf("tb: payload.bin = %ld bytes\n", pl);
    }

    const char *imgname = "fat16.img";
    const char *fsname = "FS: FAT16";
    const char *plan = "full";
    for (int i = 1; i < argc; i++) {
        if (!strncmp(argv[i], "+img=", 5)) imgname = argv[i] + 5;
        if (!strncmp(argv[i], "+plan=", 6)) plan = argv[i] + 6;
    }
    if (strstr(imgname, "32")) fsname = "FS: FAT32";
    if (!card.load(imgname)) { printf("TB_RESULT: FAIL cannot open %s\n", imgname); return 1; }

    top->s1 = 0;
    top->uart_rxp = 1;
    applyCardPins();  // all card drivers released, lines idle high

    if (g_interactive) {
        printf("=== SD-FAT interactive console (Verilator simulation) ===\n");
        printf("=== keys go to the simulated board - ESC exits         ===\n");
        struct termios told, traw;
        tcgetattr(0, &told);
        traw = told;
        traw.c_lflag &= ~(ICANON | ECHO);  // raw keys, no local echo (ISIG stays on)
        tcsetattr(0, TCSANOW, &traw);
        int fl = fcntl(0, F_GETFL);
        fcntl(0, F_SETFL, fl | O_NONBLOCK);

        std::deque<uint8_t> keys;
        uint64_t next_poll = 0;
        bool running = true;
        while (running) {
            step();
            if (cycles >= next_poll) {  // poll the keyboard every ~1 ms of sim time
                next_poll = cycles + 27000;
                char c;
                while (read(0, &c, 1) == 1) {
                    if (c == 27) { running = false; break; }
                    keys.push_back((uint8_t)c);
                }
            }
            if (!keys.empty() && !utx.busy()) {
                utx.send(keys.front());
                keys.pop_front();
            }
        }

        tcsetattr(0, TCSANOW, &told);
        fcntl(0, F_SETFL, fl);
        printf("\n=== console closed ===\n");
        top->final();
        delete top;
        return 0;
    }

    int errors = 0;
    const uint64_t SEC = 27000000ULL;

    // reserved-region byte gate: run after every destructive command
    auto check_reserved = [&](const char *tag) {
        int bad = card.reservedDamage();
        if (bad) {
            printf("FAIL: reserved region (boot sector area) damaged %s: %d bytes changed\n",
                   tag, bad);
            errors++;
        }
    };

    // shared verdict + post-image tail for every plan
    auto finish = [&](const char *suffix) -> int {
        if (card.crc_errors) { printf("FAIL: %d CMD CRC7 errors\n", card.crc_errors); errors++; }
        if (card.wr_crc_errors) { printf("FAIL: %d CMD24 data CRC errors\n", card.wr_crc_errors); errors++; }
        if (card.illegal_writes) {
            printf("FAIL: %d ILLEGAL writes into the reserved region\n", card.illegal_writes);
            errors++;
        }
        check_reserved("at the end of the run");
        char postname[160];
        snprintf(postname, sizeof postname, "%s%s", imgname, suffix);
        FILE *pf = fopen(postname, "wb");
        if (pf) { fwrite(card.mem.data(), 1, card.mem.size(), pf); fclose(pf); }
        printf("post image written: %s\n", postname);
        if (errors == 0) printf("TB_RESULT: PASS\n");
        else printf("TB_RESULT: FAIL %d errors\n", errors);
        top->final();
        delete top;
        return errors ? 1 : 0;
    };

    // ---------------------------------------------------------------- plans
    if (!strcmp(plan, "errtexts")) {
        // ERROR-TEXT TRUTH GATE (12-JUL-2026, owner report): silicon
        // printed "SD WRITE FAILED" for CHECK's failed FAT READS and
        // "NO CONTIGUOUS FREE SPACE" when the FAT free-run scan could not
        // READ the FAT - texts that send the operator hunting the wrong
        // fault. Each failure mode is injected deterministically and the
        // EXACT console line is asserted, plus the absence of the
        // misleading one. Wrong texts can never ship again.
        auto menu_expect = [&](char key, const char *waitpat, const char *must,
                               const char *mustnot, uint64_t budget) {
            size_t t0 = urx.text.size();
            send_key(key);
            if (!run_until(waitpat, t0, cycles + budget)) {
                printf("TB_RESULT: FAIL '%c' never printed '%s'\n", key, waitpat);
                printf("tail: %s\n", urx.text.substr(t0).c_str());
                exit(1);
            }
            if (!wait_prompt(urx.text.size(), cycles + budget)) {
                printf("TB_RESULT: FAIL no prompt after '%c'\n", key);
                exit(1);
            }
            std::string w = urx.text.substr(t0);
            if (w.size() < 3 || w[0] != key || w.compare(1, 2, "\r\n") != 0) {
                printf("FAIL: key echo '%c' CR LF missing at command start\n", key);
                errors++;
            }
            if (must && w.find(must) == std::string::npos) {
                printf("FAIL: expected text '%s' missing after '%c'\n", must, key);
                errors++;
            }
            if (mustnot && w.find(mustnot) != std::string::npos) {
                printf("FAIL: MISLEADING text '%s' printed after '%c'\n", mustnot, key);
                errors++;
            }
        };

        if (!wait_prompt(0, cycles + SEC)) { printf("TB_RESULT: FAIL no menu prompt\n"); return 1; }

        // clean 6 first: creates IO.DAT (menus 5/7 then have work to do)
        menu_expect('6', "KB/S", "WRITE ", "ERROR:", 60 * SEC);
        check_reserved("after clean 6");

        // menu 7 with the engine read dying -> READ error, never WRITE
        card.fail_reads4 = true;
        menu_expect('7', "ERROR:", "ERROR: SD READ FAILED",
                    "SD WRITE FAILED", 60 * SEC);
        card.fail_reads4 = false;

        // menu 5 CHECK reads FAT chains: its failure is a FAT READ error
        card.fail_reads4 = true;
        menu_expect('5', "ERROR:", "ERROR: FAT READ FAILED",
                    "SD WRITE FAILED", 60 * SEC);
        card.fail_reads4 = false;

        // menu 6 with the surgeon's FAT-scan READ dying -> FAT READ error,
        // NOT the no-space verdict (the silicon complaint)
        card.fail_reads4 = true;
        menu_expect('6', "ERROR:", "ERROR: FAT READ FAILED",
                    "NO CONTIGUOUS FREE SPACE", 60 * SEC);
        card.fail_reads4 = false;

        // GENUINE no-space: FAT reads SUCCEED but return a fully allocated
        // FAT (all 0xFF, valid CRC) - the scan completes and finds no run
        card.corrupt_reads4 = true;
        menu_expect('6', "ERROR:", "ERROR: NO CONTIGUOUS FREE SPACE",
                    "FAT READ FAILED", 60 * SEC);
        card.corrupt_reads4 = false;

        // recovery sanity: after a reset a clean 6 must still succeed
        pulse_s1();
        if (!wait_prompt(urx.text.size(), cycles + SEC)) {
            printf("TB_RESULT: FAIL no menu after reset\n");
            return 1;
        }
        menu_expect('6', "KB/S", "WRITE ", "ERROR:", 60 * SEC);
        check_reserved("after recovery 6");

        return finish("_errtexts.img");
    }

    if (!strcmp(plan, "big")) {
        // Field-failure reproduction (16-32 GB SDHC geometry: big clusters).
        // '6' is the FIRST command after reset: the create path runs with
        // nothing pre-captured - on hardware this wrote the patched root
        // directory sector to sector 0 and destroyed the card's boot sector.
        if (!wait_prompt(0, cycles + SEC)) { printf("TB_RESULT: FAIL no menu prompt\n"); return 1; }

        size_t t6 = urx.text.size();
        send_key('6');
        if (!run_until("KB/S", t6, cycles + 40 * SEC)) {
            printf("TB_RESULT: FAIL cold-start write speed test never finished\n");
            printf("tail: %s\n", urx.text.substr(t6).c_str());
            return 1;
        }
        if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after 6\n"); return 1; }
        if (urx.text.find("WRITE ", t6) == std::string::npos) {
            printf("FAIL: no WRITE speed line\n"); errors++;
        }
        check_reserved("after cold-start 6 (create IO.DAT)");

        // the filesystem must still mount and LIST (exactly what broke on hw)
        // the info line is the overflow guard: 1100 MB, FAT32, 16 KB clusters
        std::string exp_info = expectedInfoLine(card.mem);
        size_t t1 = urx.text.size();
        send_key('1');
        if (!wait_prompt(t1 + 2, cycles + 16 * SEC)) { printf("TB_RESULT: FAIL no prompt after list\n"); return 1; }
        {
            std::string l = urx.text.substr(t1);
            if (l.find("ERROR") != std::string::npos) {
                printf("FAIL: LIST after 6 errored:\n%s\n", l.c_str()); errors++;
            }
            if (l.find(exp_info) == std::string::npos) {
                printf("FAIL: big-geometry LIST info line wrong: want '%s' in:\n%s\n",
                       exp_info.c_str(), l.c_str());
                errors++;
            }
            char sizepat[64];
            snprintf(sizepat, sizeof sizepat, "%10ld  ", IO_BLOCKS_SIM * 2048L);
            if (l.find("IO.DAT") == std::string::npos ||
                l.find(sizepat) == std::string::npos) {
                printf("FAIL: LIST after 6 shows no %ld-byte IO.DAT:\n%s\n",
                       IO_BLOCKS_SIM * 2048L, l.c_str());
                errors++;
            }
            if (l.find("BOOT.BPUN") == std::string::npos) {
                printf("FAIL: LIST after 6 lost BOOT.BPUN\n"); errors++;
            }
        }

        // and the created file must stream back
        size_t t7 = urx.text.size();
        send_key('7');
        if (!run_until("KB/S", t7, cycles + 40 * SEC)) {
            printf("TB_RESULT: FAIL read speed test never finished\n");
            printf("tail: %s\n", urx.text.substr(t7).c_str());
            return 1;
        }
        if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after 7\n"); return 1; }
        if (urx.text.find("READ ", t7) == std::string::npos) {
            printf("FAIL: no READ speed line\n"); errors++;
        }
        return finish("_post.img");
    }

    if (!strcmp(plan, "cold")) {
        // Cold-start regression: every destructive command as the FIRST
        // command after a fresh reset (S1 between them). The default plan's
        // command order left valid values in the geometry capture registers
        // and masked the create-path boot-sector corruption.
        if (!wait_prompt(0, cycles + SEC)) { printf("TB_RESULT: FAIL no menu prompt\n"); return 1; }

        // 6: create + write IO.DAT (the field failure)
        size_t t6 = urx.text.size();
        send_key('6');
        if (!run_until("KB/S", t6, cycles + 40 * SEC)) {
            printf("TB_RESULT: FAIL cold 6 never finished\n");
            printf("tail: %s\n", urx.text.substr(t6).c_str());
            return 1;
        }
        if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after cold 6\n"); return 1; }
        check_reserved("after cold 6 (create IO.DAT)");

        pulse_s1();
        if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no menu after reset 1\n"); return 1; }

        // 3: COPY to TEST.TXT
        size_t t3 = urx.text.size();
        send_key('3');
        if (!run_until("COPY DONE", t3, cycles + 8 * SEC)) {
            printf("TB_RESULT: FAIL cold 3 never finished\n");
            printf("tail: %s\n", urx.text.substr(t3).c_str());
            return 1;
        }
        if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after cold 3\n"); return 1; }
        check_reserved("after cold 3 (COPY)");

        pulse_s1();
        if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no menu after reset 2\n"); return 1; }

        // 4: WRBLK1
        size_t t4 = urx.text.size();
        send_key('4');
        if (!run_until("BLOCK 1 UPDATED", t4, cycles + 8 * SEC)) {
            printf("TB_RESULT: FAIL cold 4 never finished\n");
            printf("tail: %s\n", urx.text.substr(t4).c_str());
            return 1;
        }
        if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after cold 4\n"); return 1; }
        check_reserved("after cold 4 (WRBLK1)");

        return finish("_cold.img");
    }

    // ------------------------------------------------------- default plan
    // 0. banner + first menu (SD: NOT CHECKED)
    if (!wait_prompt(0, cycles + SEC)) { printf("TB_RESULT: FAIL no menu prompt\n"); return 1; }
    if (urx.text.find("SD: NOT CHECKED") == std::string::npos) {
        printf("FAIL: no 'SD: NOT CHECKED' at boot\n"); errors++;
    }

    // 1. DUMP
    size_t t_dump = urx.text.size();
    send_key('2');
    if (!run_until("DONE", t_dump, cycles + 4 * SEC)) {
        printf("TB_RESULT: FAIL dump never finished\n"); return 1;
    }
    if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after dump\n"); return 1; }

    std::string d = urx.text.substr(t_dump);
    // the accepted key is echoed as <key> CR LF before any command output
    if (d.size() < 3 || d.compare(0, 3, "2\r\n") != 0) {
        printf("FAIL: key echo '2' CR LF missing before the dump\n");
        errors++;
    }
    for (const char *pat : {"CARD: SDHC", fsname, "FILE: FOUND", "SD: OK"}) {
        if (d.find(pat) == std::string::npos) { printf("FAIL: missing '%s'\n", pat); errors++; }
    }

    // parse the dump lines back into bytes
    std::vector<uint8_t> dmp;
    {
        size_t pos = 0;
        while (pos < d.size()) {
            size_t eol = d.find('\n', pos);
            if (eol == std::string::npos) eol = d.size();
            std::string line = d.substr(pos, eol - pos);
            unsigned off;
            if (line.size() > 8 && line[6] == ':' && sscanf(line.c_str(), "%06X:", &off) == 1) {
                const char *p = line.c_str() + 8;
                while (*p) {
                    while (*p == ' ') p++;
                    unsigned b;
                    if (sscanf(p, "%02X", &b) != 1) break;
                    if (dmp.size() < off + 1) dmp.resize(off + 1);
                    dmp[off++] = (uint8_t)b;
                    p += 2;
                }
            }
            pos = eol + 1;
        }
    }
    if ((long)dmp.size() != pl) {
        printf("FAIL: dump length %zu != payload %ld\n", dmp.size(), pl); errors++;
    }
    int nb = 0;
    for (long i = 0; i < pl && i < (long)dmp.size(); i++)
        if (dmp[i] != payload[i]) {
            if (nb < 10) printf("FAIL: byte %ld got %02X want %02X\n", i, dmp[i], payload[i]);
            nb++;
        }
    if (nb) { printf("FAIL: %d dump byte mismatches\n", nb); errors++; }

    char lenpat[64];
    snprintf(lenpat, sizeof lenpat, "LENGTH: %012ld BYTES", pl);
    if (d.find(lenpat) == std::string::npos) { printf("FAIL: missing '%s'\n", lenpat); errors++; }

    // 2. LIST: sizes, dates, <DIR> marker, disk-info line
    std::string exp_info = expectedInfoLine(card.mem);
    size_t t_list = urx.text.size();
    send_key('1');
    if (!wait_prompt(t_list + 2, cycles + 8 * SEC)) { printf("TB_RESULT: FAIL no prompt after list\n"); return 1; }
    {
        std::string l = urx.text.substr(t_list);
        if (l.size() < 3 || l.compare(0, 3, "1\r\n") != 0) {
            printf("FAIL: key echo '1' CR LF missing before the listing\n");
            errors++;
        }
        if (l.find("SCANNING FAT") == std::string::npos) {
            printf("FAIL: no SCANNING line before the free-space scan\n"); errors++;
        }
        if (l.find(exp_info) == std::string::npos) {
            printf("FAIL: LIST info line wrong: want '%s' in:\n%s\n",
                   exp_info.c_str(), l.c_str());
            errors++;
        }
        char sizepat[64];
        snprintf(sizepat, sizeof sizepat, "%10ld  ", pl);
        if (l.find(std::string(sizepat)) == std::string::npos ||
            l.find("BOOT.BPUN") == std::string::npos) {
            printf("FAIL: no size column for BOOT.BPUN in LIST\n"); errors++;
        }
        if (l.find("     <DIR>  ") == std::string::npos || l.find("HDD") == std::string::npos) {
            printf("FAIL: no <DIR> HDD entry in LIST\n"); errors++;
        }
        if (l.find("         9  ") == std::string::npos ||
            l.find("TEST.TXT") == std::string::npos) {
            printf("FAIL: no 9-byte TEST.TXT entry in LIST\n"); errors++;
        }
        // date column shape: find the BOOT.BPUN line and check DD-MMM-YYYY
        size_t bp = l.find("BOOT.BPUN");
        size_t ls = l.rfind('\n', bp);
        std::string line = l.substr(ls + 1, bp - ls - 1);
        // "      2342  10-JAN-2025  " -> date at columns 12..22
        bool date_ok = line.size() >= 25 && line[14] == '-' && line[18] == '-' &&
                       isdigit(line[12]) && isdigit(line[13]) && isupper(line[15]) &&
                       line.compare(19, 2, "20") == 0;
        if (!date_ok) { printf("FAIL: bad date column in '%s'\n", line.c_str()); errors++; }
    }

    // 3. COPY BOOT.BPUN -> TEST.TXT (in-place sector rewrite via CMD24)
    size_t before = 0;
    for (size_t off = 0; off + pl <= card.mem.size(); off++)
        if (!memcmp(card.mem.data() + off, payload.data(), pl)) before++;

    size_t t3 = urx.text.size();
    send_key('3');
    if (!run_until("COPY DONE", t3, cycles + 8 * SEC)) {
        printf("TB_RESULT: FAIL copy never finished (no COPY DONE)\n");
        printf("tail: %s\n", urx.text.substr(t3).c_str());
        return 1;
    }
    if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after copy\n"); return 1; }

    size_t after = 0;
    for (size_t off = 0; off + pl <= card.mem.size(); off++)
        if (!memcmp(card.mem.data() + off, payload.data(), pl)) after++;
    if (!(before >= 1 && after >= before + 1)) {
        printf("FAIL: payload copies in card image: before=%zu after=%zu (want +1)\n",
               before, after);
        errors++;
    }
    check_reserved("after COPY");

    // LIST must now show TEST.TXT with the payload's size (dir entry patched)
    exp_info = expectedInfoLine(card.mem);  // free space changed with the COPY
    size_t t_l2 = urx.text.size();
    send_key('1');
    if (!wait_prompt(t_l2 + 2, cycles + 8 * SEC)) { printf("TB_RESULT: FAIL no prompt after list 2\n"); return 1; }
    {
        std::string l = urx.text.substr(t_l2);
        if (l.find(exp_info) == std::string::npos) {
            printf("FAIL: LIST 2 info line wrong: want '%s' in:\n%s\n",
                   exp_info.c_str(), l.c_str());
            errors++;
        }
        size_t tt = l.find("TEST.TXT");
        size_t ls = (tt == std::string::npos) ? std::string::npos : l.rfind('\n', tt);
        char sizepat[64];
        snprintf(sizepat, sizeof sizepat, "%10ld  ", pl);
        if (tt == std::string::npos || l.compare(ls + 1, 12, sizepat) != 0) {
            printf("FAIL: TEST.TXT size not %ld after copy\n", pl); errors++;
        }
    }

    // second COPY: allocation now fits -> the size-patch-only fast path
    size_t t3b = urx.text.size();
    send_key('3');
    if (!run_until("COPY DONE", t3b, cycles + 8 * SEC)) {
        printf("TB_RESULT: FAIL second copy (fast path) never finished\n");
        return 1;
    }
    if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after copy 2\n"); return 1; }
    {
        size_t again = 0;
        for (size_t off = 0; off + pl <= card.mem.size(); off++)
            if (!memcmp(card.mem.data() + off, payload.data(), pl)) again++;
        if (again < after) { printf("FAIL: fast-path copy lost content\n"); errors++; }
    }

    // 4. H = help
    size_t t_h = urx.text.size();
    send_key('H');
    if (!wait_prompt(t_h + 2, cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after help\n"); return 1; }
    if (urx.text.find("4 = WRITE WORDS 0-1023", t_h) == std::string::npos) {
        printf("FAIL: help text missing\n"); errors++;
    }

    // 5. WRBLK1: pattern into 1KW block 1 of BOOT.BPUN
    // locate BOOT.BPUN's content in the card image first (payload match)
    size_t boot_off = std::string::npos;
    for (size_t off = 0; off + pl <= card.mem.size(); off++)
        if (!memcmp(card.mem.data() + off, payload.data(), pl)) { boot_off = off; break; }
    if (boot_off == std::string::npos) {
        printf("TB_RESULT: FAIL cannot locate BOOT.BPUN content in the image\n");
        return 1;
    }

    size_t t4 = urx.text.size();
    send_key('4');
    if (!run_until("BLOCK 1 UPDATED", t4, cycles + 8 * SEC)) {
        printf("TB_RESULT: FAIL WRBLK1 never finished\n");
        printf("tail: %s\n", urx.text.substr(t4).c_str());
        return 1;
    }
    if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after wrblk1\n"); return 1; }

    // card image: block 1 = pattern, block 0 and 2 = original payload
    {
        int bad = 0;
        for (int i = 0; i < 2048; i++) {
            uint16_t w = (uint16_t)(i >> 1);
            uint8_t want = (i & 1) ? (uint8_t)(w & 0xFF) : (uint8_t)(w >> 8);
            if (card.mem[boot_off + 2048 + i] != want) bad++;
        }
        if (bad) { printf("FAIL: block 1 pattern: %d bad bytes in the image\n", bad); errors++; }
        int bad0 = 0, bad2 = 0;
        for (int i = 0; i < 2048; i++)
            if (card.mem[boot_off + i] != payload[i]) bad0++;
        for (long i = 4096; i < pl; i++)
            if (card.mem[boot_off + i] != payload[i]) bad2++;
        if (bad0) { printf("FAIL: block 0 was modified (%d bytes)\n", bad0); errors++; }
        if (bad2) { printf("FAIL: block 2 was modified (%d bytes)\n", bad2); errors++; }
    }
    check_reserved("after WRBLK1");

    // 6. dump again: the DUMPED file must now be payload with block 1 patched
    size_t t_d2 = urx.text.size();
    send_key('2');
    if (!run_until("DONE", t_d2, cycles + 8 * SEC)) {
        printf("TB_RESULT: FAIL second dump never finished\n"); return 1;
    }
    if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after dump 2\n"); return 1; }
    {
        std::string d2 = urx.text.substr(t_d2);
        std::vector<uint8_t> dmp2;
        size_t pos = 0;
        while (pos < d2.size()) {
            size_t eol = d2.find('\n', pos);
            if (eol == std::string::npos) eol = d2.size();
            std::string line = d2.substr(pos, eol - pos);
            unsigned off;
            if (line.size() > 8 && line[6] == ':' && sscanf(line.c_str(), "%06X:", &off) == 1) {
                const char *p = line.c_str() + 8;
                while (*p) {
                    while (*p == ' ') p++;
                    unsigned b;
                    if (sscanf(p, "%02X", &b) != 1) break;
                    if (dmp2.size() < off + 1) dmp2.resize(off + 1);
                    dmp2[off++] = (uint8_t)b;
                    p += 2;
                }
            }
            pos = eol + 1;
        }
        int bad = 0;
        for (long i = 0; i < pl && i < (long)dmp2.size(); i++) {
            uint8_t want;
            if (i >= 2048 && i < 4096) {
                uint16_t w = (uint16_t)((i - 2048) >> 1);
                want = (i & 1) ? (uint8_t)(w & 0xFF) : (uint8_t)(w >> 8);
            } else want = payload[i];
            if (dmp2[i] != want) bad++;
        }
        if ((long)dmp2.size() != pl || bad) {
            printf("FAIL: post-WRBLK1 dump wrong (len %zu vs %ld, %d bad bytes)\n",
                   dmp2.size(), pl, bad);
            errors++;
        }
    }

    // 7a. READ speed before WRITE speed: must refuse (no IO.DAT yet)
    size_t t7a = urx.text.size();
    send_key('7');
    if (!run_until("FILE: NOT FOUND", t7a, cycles + 4 * SEC)) {
        printf("FAIL: 7 before 6 did not refuse\n"); errors++;
    }
    if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after 7a\n"); return 1; }

    // 7b. WRITE speed: rewrites IO.DAT with IO_BLOCKS blocks, reports KB/S
    size_t t6 = urx.text.size();
    send_key('6');
    if (!run_until("KB/S", t6, cycles + 20 * SEC)) {
        printf("TB_RESULT: FAIL write speed test never finished\n");
        printf("tail: %s\n", urx.text.substr(t6).c_str());
        return 1;
    }
    if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after 6\n"); return 1; }
    if (urx.text.find("WRITE ", t6) == std::string::npos) {
        printf("FAIL: no WRITE speed line\n"); errors++;
    }
    check_reserved("after 6 (WRITE speed)");

    // 7c. READ speed: streams IO.DAT back, reports KB/S
    size_t t7 = urx.text.size();
    send_key('7');
    if (!run_until("KB/S", t7, cycles + 20 * SEC)) {
        printf("TB_RESULT: FAIL read speed test never finished\n");
        return 1;
    }
    if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after 7\n"); return 1; }
    if (urx.text.find("READ ", t7) == std::string::npos) {
        printf("FAIL: no READ speed line\n"); errors++;
    }

    // 7. CHECK: every root file's cluster chain must validate OK
    size_t t5 = urx.text.size();
    send_key('5');
    if (!run_until("CHECK DONE", t5, cycles + 8 * SEC)) {
        printf("TB_RESULT: FAIL CHECK never finished\n");
        printf("tail: %s\n", urx.text.substr(t5).c_str());
        return 1;
    }
    if (!wait_prompt(urx.text.size(), cycles + SEC)) { printf("TB_RESULT: FAIL no prompt after check\n"); return 1; }
    {
        std::string c = urx.text.substr(t5);
        if (c.find(" BAD") != std::string::npos) {
            printf("FAIL: CHECK reported a BAD chain:\n%s\n", c.c_str());
            errors++;
        }
        for (const char *f : {"BOOT.BPUN", "TEST.TXT"}) {
            size_t fp = c.find(f);
            size_t eol = (fp == std::string::npos) ? std::string::npos : c.find('\n', fp);
            if (fp == std::string::npos ||
                c.substr(fp, eol - fp).find(" OK") == std::string::npos) {
                printf("FAIL: no OK line for %s in CHECK\n", f);
                errors++;
            }
        }
        if (c.find(" DIR") == std::string::npos || c.find("HDD") == std::string::npos) {
            printf("FAIL: no DIR line for HDD in CHECK\n"); errors++;
        }
    }

    return finish("_post.img");
}
