/****************************************************************************
** Verilator testbench for the SD-FAT test (test_*.cpp per repo convention)**
**                                                                         **
** Same test plan as sd_fat_test_tb.v (iverilog), but with the SD card    **
** model in C++ (Verilator cannot run the event-driven Verilog model):     **
**                                                                         **
**   - behavioral SD card serving sectors from fat16.img                   **
**     (CMD0/8/55/ACMD41/2/3/7/16/17 reads + CMD24 single-sector WRITE,    **
**     SDHC, CRC7-checked commands, CRC16 on data blocks both ways)        **
**   - drives the UART menu: '2' DUMP (verify bytes + LENGTH against       **
**     payload.bin), '1' LIST (sizes + dates + <DIR> entries),             **
**     '3' COPY to TEST.TXT (verifies the payload landed a second time     **
**     in the card image), '4' WRBLK1 (verifies the word[w]=w pattern in   **
**     1KW block 1 of BOOT.BPUN and that blocks 0/2 are untouched, both    **
**     in the card image and via a second dump), 'H' help,                 **
**     menu SD: status line NOT CHECKED -> OK                              **
**                                                                         **
** Build & run: make test-verilator (in this sim/ directory)               **
** Verdict:     TB_RESULT: PASS / TB_RESULT: FAIL <reason>                 **
**                                                                         **
** Interactive: make console (runs this binary with +interactive) - your   **
** terminal is bridged to the simulated UART: the menu appears, keys are   **
** sent to the design, ESC exits. Same FAT16 image as the scripted test.   **
**                                                                         **
** Last reviewed: 10-JUL-2026                                              **
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

    // command receive (bits sampled on sd_clk rising edges)
    uint64_t sh = 0;
    int rxcnt = -1;  // -1 = hunting for the start bit

    // CMD response / DAT block bit queues (played on falling edges)
    std::vector<uint8_t> cq;
    size_t cpos = 0;
    int ncr = 0;
    std::vector<uint8_t> dq;
    size_t dpos = 0;
    int ddelay = 0;

    // CMD24 write-block receive state (bits sampled on rising edges)
    bool wr_expect = false;   // R1 sent, waiting for the host data start bit
    bool wr_active = false;   // collecting data bits
    uint64_t wr_base = 0;     // byte address of the target sector
    int wr_bit = 0;
    uint8_t wr_byte = 0;
    uint16_t wr_crc = 0, wr_crc_host = 0;
    std::vector<uint8_t> wr_buf;
    int wr_crc_errors = 0;

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
        return true;
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
            case 0: app_cmd = false; break;  // no response
            case 8: push48(((uint64_t)8 << 32) | 0x000001AAULL); break;
            case 55: push48(((uint64_t)55 << 32) | 0x00000120ULL); app_cmd = true; break;
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
            case 7: push48(((uint64_t)7 << 32) | 0x00000700ULL); break;
            case 16: push48(((uint64_t)16 << 32) | 0x00000900ULL); break;
            case 17:
                push48(((uint64_t)17 << 32) | 0x00000900ULL);
                data = true;
                break;
            case 24:  // WRITE_BLOCK: R1, then receive the data block on DAT0
                push48(((uint64_t)24 << 32) | 0x00000900ULL);
                wr_expect = true;
                wr_active = false;
                wr_base = (uint64_t)arg * 512;  // SDHC: arg = sector number
                wr_buf.clear();
                break;
            default: break;  // no response -> host times out
        }

        if (data) {
            uint64_t base = (uint64_t)arg * 512;  // SDHC: arg = sector number
            dq.clear(); dpos = 0;
            ddelay = 4 + 48 + 8;  // after the R1 response + a small gap
            dq.push_back(0);      // start bit
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
            dq.push_back(1);  // end bit
        }
    }

    // card samples on the rising edge of sd_clk
    void onRise(int cmd_line, int dat_line) {
        // ---- DAT0: incoming write block (host drives, we listen) ----
        if (wr_expect && !dat_drive) {
            if (!wr_active) {
                if (dat_line == 0) {  // data start bit
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
            } else if (wr_bit < 4112) {  // 16 CRC bits from the host
                wr_crc_host = (uint16_t)((wr_crc_host << 1) | (dat_line & 1));
                wr_bit++;
                if (wr_bit == 4112) {
                    if (wr_crc_host != wr_crc) {
                        wr_crc_errors++;
                        printf("sdcard: CMD24 data CRC16 mismatch\n");
                    }
                    for (size_t i = 0; i < 512 && wr_base + i < mem.size(); i++)
                        mem[wr_base + i] = wr_buf[i];
                    // CRC status token "010" + end, then ~64 clocks busy
                    dq.clear(); dpos = 0; ddelay = 3;
                    dq.push_back(0); dq.push_back(0); dq.push_back(1);
                    dq.push_back(0); dq.push_back(1);
                    for (int b = 0; b < 64; b++) dq.push_back(0);  // busy
                    dq.push_back(1);
                    wr_expect = false;
                    wr_active = false;
                }
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

    // card drives on the falling edge of sd_clk
    void onFall() {
        if (!cq.empty()) {
            if (ncr > 0) { ncr--; cmd_drive = 0; cmd_val = 1; }
            else if (cpos < cq.size()) { cmd_drive = 1; cmd_val = cq[cpos++]; }
            else { cq.clear(); cpos = 0; cmd_drive = 0; cmd_val = 1; }
        } else { cmd_drive = 0; cmd_val = 1; }

        if (!dq.empty()) {
            if (ddelay > 0) { ddelay--; dat_drive = 0; dat0 = 1; }
            else if (dpos < dq.size()) { dat_drive = 1; dat0 = dq[dpos++]; }
            else { dq.clear(); dpos = 0; dat_drive = 0; dat0 = 1; }
        } else { dat_drive = 0; dat0 = 1; }
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

static void step() {  // one full 27 MHz clock cycle
    // falling edge of sys_clk
    top->sys_clk = 0;
    top->eval();
    // rising edge
    top->sys_clk = 1;
    top->sd_cmd_c_drive = card.cmd_drive;
    top->sd_cmd_c_val = card.cmd_val;
    top->sd_dat0_c_drive = card.dat_drive;
    top->sd_dat0_c_val = card.dat0;
    top->uart_rxp = utx.line;
    top->eval();

    // SD clock edges (sd_clk toggles far slower than sys_clk)
    int sc = top->sd_clk;
    if (sc && !last_sdclk) card.onRise(top->sd_cmd_resolved, top->sd_dat0_resolved);
    if (!sc && last_sdclk) {
        card.onFall();
        top->sd_cmd_c_drive = card.cmd_drive;
        top->sd_cmd_c_val = card.cmd_val;
        top->sd_dat0_c_drive = card.dat_drive;
        top->sd_dat0_c_val = card.dat0;
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

    if (!card.load("fat16.img")) { printf("TB_RESULT: FAIL cannot open fat16.img\n"); return 1; }

    top->s1 = 0;
    top->uart_rxp = 1;
    top->sd_cmd_c_drive = 0;
    top->sd_cmd_c_val = 1;
    top->sd_dat0_c_drive = 0;
    top->sd_dat0_c_val = 1;

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
    for (const char *pat : {"CARD: SDHC", "FS: FAT16", "FILE: FOUND", "SD: OK"}) {
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

    // 2. LIST: sizes, dates, <DIR> marker
    size_t t_list = urx.text.size();
    send_key('1');
    if (!wait_prompt(t_list + 2, cycles + 4 * SEC)) { printf("TB_RESULT: FAIL no prompt after list\n"); return 1; }
    {
        std::string l = urx.text.substr(t_list);
        char sizepat[64];
        snprintf(sizepat, sizeof sizepat, "%10ld  ", pl);
        if (l.find(std::string(sizepat)) == std::string::npos ||
            l.find("BOOT.BPUN") == std::string::npos) {
            printf("FAIL: no size column for BOOT.BPUN in LIST\n"); errors++;
        }
        if (l.find("     <DIR>  ") == std::string::npos || l.find("HDD") == std::string::npos) {
            printf("FAIL: no <DIR> HDD entry in LIST\n"); errors++;
        }
        if (l.find("TEST.TXT") == std::string::npos) {
            printf("FAIL: no TEST.TXT entry in LIST\n"); errors++;
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

    if (card.crc_errors) { printf("FAIL: %d CMD CRC7 errors\n", card.crc_errors); errors++; }
    if (card.wr_crc_errors) { printf("FAIL: %d CMD24 data CRC errors\n", card.wr_crc_errors); errors++; }

    if (errors == 0) printf("TB_RESULT: PASS\n");
    else printf("TB_RESULT: FAIL %d errors\n", errors);

    top->final();
    delete top;
    return errors ? 1 : 0;
}
