/**************************************************************************
** ND120 FPGA hardware test tool                                         **
**                                                                       **
** ndcomm - talk to the ND-120 OPCOM console over a serial port.         **
**                                                                       **
** Derived from the original ndcomm.c OPCOM console driver; extended     **
** into an FPGA bring-up tool:                                           **
**                                                                       **
**   - Load a BPUN image into main memory through OPCOM deposits.        **
**     Every written character waits for its console echo before the     **
**     next is sent, so the transfer self-paces at the maximum rate      **
**     MOPC can accept - no fixed delays, no dropped characters.         **
**   - Verify the loaded range with an OPCOM range dump (n<y) and        **
**     compare word-by-word against the BPUN payload.                    **
**   - Optionally start the program (addr!).                            **
**   - Instruction trace mode from the original tool (P register        **
**     examine + Z single-step, optional full register dump).            **
**   - Interactive/scripted command mode (original M/I language) when    **
**     no other action is requested.                                     **
**                                                                       **
** BPUN format (tape segments A-I):                                      **
**   A  leader, any chars without '!'                                    **
**   B  (optional) octal start address, terminated by CR                 **
**   C  (optional) octal number, terminated by '!'                       **
**   D  '!' delimiter                                                    **
**   E  block load address, two bytes, MSB first                         **
**   F  word count of G, two bytes, MSB first                            **
**   G  the payload words                                                **
**   H  checksum of G (16-bit sum)                                       **
**   I  action code (non-zero: start at B)                               **
**                                                                       **
** Build: make            (plain POSIX C, runs under Linux/WSL2)         **
** Usage: ndcomm -l prog.bpun -v -g /dev/ttyUSB1                         **
**                                                                       **
** Last reviewed: 10-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

#include <sys/ioctl.h>
#include <sys/poll.h>
#include <sys/time.h>
#include <time.h>

#include <fcntl.h>
#include <stdio.h>
#include <err.h>
#include <termios.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

static void usage(void);
int waitch_poll_ms(int ms);

FILE *outf;
int debug = 0, tcount, tobuf, pregs;
int cfd;
int wrtstr(const char *s); /* write string, waiting for each char echo back */
int rdstr(int ch);          /* read chars until ch seen */
int waitch(void);
void base(void), traceins(void);
void command_mode(void);
char obuf[4096], *obp;

/* BPUN image */
#define MAXWORDS 65536
static unsigned short bpun_data[MAXWORDS];
static int bpun_start;  /* B section - start address */
static int bpun_load;   /* E section - load address  */
static int bpun_count;  /* F section - word count    */
static unsigned char bpun_raw[2 * MAXWORDS + 4096]; /* the file, verbatim */
static int bpun_rawlen;

static int load_bpun_file(const char *fn);
static void opcom_sync(void);
static int opcom_load(void);
static int opcom_binload(int settle_ms, int noauto);
static int opcom_verify(void);
static int opcom_verify_repair(void);
static void opcom_start(int addr);

static double
now_s(void)
{
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return tv.tv_sec + tv.tv_usec / 1e6;
}

/* "estimated 107 s, expected done at 11:34:56" - local wall clock */
static void
print_eta(const char *what, double est_s)
{
	time_t done = time(NULL) + (time_t)(est_s + 0.5);
	struct tm tm;

	localtime_r(&done, &tm);
	fprintf(stderr, "%s: estimated %.0f s, expected done at %02d:%02d:%02d\n",
	    what, est_s, tm.tm_hour, tm.tm_min, tm.tm_sec);
}

static void
fmt_clock_after(double sec, char *out, int outsz)
{
	time_t done = time(NULL) + (time_t)(sec + 0.5);
	struct tm tm;

	localtime_r(&done, &tm);
	snprintf(out, outsz, "%02d:%02d:%02d", tm.tm_hour, tm.tm_min, tm.tm_sec);
}

int
main(int argc, char *argv[])
{
	int ch, fcarg;
	struct termios term;
	const char *bpun_fn = NULL;
	int do_verify = 0, do_go = 0, start_addr = -1;
	int fastload = 0, noauto = 0, settle_ms = 400;

	while ((ch = getopt(argc, argv, "dl:bnw:vgs:t:ro:")) != -1) {
		switch (ch) {
		case 'd':
			debug = 1;
			break;

		case 'l':
			bpun_fn = optarg;
			break;

		case 'b':
			fastload = 1;
			break;

		case 'n':
			noauto = 1;
			break;

		case 'w':
			settle_ms = atoi(optarg);
			break;

		case 'v':
			do_verify = 1;
			break;

		case 'g':
			do_go = 1;
			break;

		case 's':
			start_addr = (int)strtol(optarg, NULL, 8);
			break;

		case 't':
			tcount = atoi(optarg);
			break;

		case 'r':
			pregs = 1;
			break;

		case 'o':
			if ((outf = fopen(optarg, "w")) == NULL)
				err(1, "fopen");
			break;

		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (argc != 1)
		usage();

	if ((cfd = open(argv[0], O_RDWR | O_NONBLOCK)) < 0)
		err(1, "open tty");

	if (((fcarg = fcntl(cfd, F_GETFL, 0)) < 0 ||
	    fcntl(cfd, F_SETFL, fcarg & ~O_NONBLOCK) < 0)) {
		err(1, "can't clear O_NONBLOCK");
	}

	/* fully explicit raw 9600 8N1, no flow control */
	memset(&term, 0, sizeof(term));
	cfmakeraw(&term);
	cfsetspeed(&term, B9600);
	term.c_cflag |= CLOCAL | CREAD | CS8;
	term.c_cflag &= ~(CRTSCTS | PARENB | CSTOPB);
	term.c_cc[VMIN] = 1;
	term.c_cc[VTIME] = 0;
	tcsetattr(cfd, TCSAFLUSH, &term);

	if (bpun_fn) {
		if (load_bpun_file(bpun_fn) < 0)
			errx(1, "bad BPUN file %s", bpun_fn);
		printf("BPUN: start B=%06o load E=%06o words F=%06o (%d)\n",
		    bpun_start, bpun_load, bpun_count, bpun_count);

		opcom_sync();
		if (fastload) {
			if (opcom_binload(settle_ms, noauto) != 0)
				errx(1, "LOAD FAILED");
		} else if (opcom_load() != 0)
			errx(1, "LOAD FAILED");
		if (do_verify) {
			if (fastload && !noauto)
				errx(1, "cannot verify: program auto-started "
				    "(use -n to stay in MOPC)");
			if (opcom_verify_repair() != 0)
				errx(1, "VERIFY FAILED");
			printf("VERIFY OK (%d words)\n", bpun_count);
		}
		if (do_go) {
			int a = (start_addr >= 0) ? start_addr : bpun_start;
			opcom_start(a);
		}
		exit(0);
	}

	opcom_sync();

	if (tcount) {
		traceins();
		/* NOTREACHED */
	}

	base();
	command_mode();
	return 0;
}

/****************************** BPUN parsing ******************************/

static int
load_bpun_file(const char *fn)
{
	FILE *f;
	int B = 0, C = 0, w, i;
	unsigned short sum = 0, cks;

	if ((f = fopen(fn, "rb")) == NULL) {
		perror(fn);
		return -1;
	}
	bpun_rawlen = (int)fread(bpun_raw, 1, sizeof(bpun_raw), f);
	rewind(f);

	/* A/B/C sections up to the '!' delimiter */
	for (;;) {
		w = getc(f);
		if (w == EOF) {
			fclose(f);
			return -1;
		}
		w &= 0177;
		if (w == '!')
			break;
		if (w == '\n')
			continue;
		if (w == '\r') {
			B = C;
			C = 0;
		} else if (w >= '0' && w <= '7') {
			C = (C << 3) | (w - '0');
		} else {
			B = C = 0;
		}
	}

	bpun_start = B;
	bpun_load = (getc(f) & 0377) << 8;
	bpun_load |= getc(f) & 0377;
	bpun_count = (getc(f) & 0377) << 8;
	bpun_count |= getc(f) & 0377;

	if (bpun_count <= 0 || bpun_count > MAXWORDS ||
	    bpun_load + bpun_count > MAXWORDS) {
		fclose(f);
		return -1;
	}

	for (i = 0; i < bpun_count; i++) {
		w = (getc(f) & 0377) << 8;
		w |= getc(f) & 0377;
		bpun_data[i] = (unsigned short)w;
		sum += (unsigned short)w;
	}
	cks = (getc(f) & 0377) << 8;
	cks |= getc(f) & 0377;
	fclose(f);

	if (cks != sum) {
		fprintf(stderr, "BPUN checksum mismatch: file %06o calc %06o\n",
		    cks, sum);
		return -1;
	}
	return 0;
}

/*************************** OPCOM load / verify **************************/

/*
 * Get the console to a quiet, closed-cell state: send CR, then drain
 * everything until the line has been silent for 400ms. (The prompt
 * after CR is '#' possibly followed by an open-cell value, so waiting
 * for a specific character is not reliable - quiet is.)
 */
static void
opcom_sync(void)
{
	ssize_t wr = write(cfd, "\r", 1);

	(void)wr;
	while (waitch_poll_ms(400) > 0)
		;
}

/* drain with a short poll - returns char or 0 */
int
waitch_poll_ms(int ms)
{
	struct pollfd pfds[1];
	char c;

	pfds[0].fd = cfd;
	pfds[0].events = POLLIN;
	if (poll(pfds, 1, ms) == 0)
		return 0;
	if (read(cfd, &c, 1) != 1)
		return 0;
	return c & 0177;
}

/*
 * Deposit the BPUN payload:
 *   <load-addr>/          open the first cell (echoes current contents)
 *   <value> CR            deposit; OPCOM auto-advances and prints
 *                         '#<contents of the NEXT cell> ' (the value,
 *                         not the address - do not try to parse it as
 *                         a position check)
 *   ... repeat for every word, then a lone CR closes the cell.
 *
 * Pacing is echo-driven: every typed char waits for its console echo,
 * so nothing can overrun MOPC. The console link (USB serial
 * pass-through) can still lose an RX character; on any echo timeout
 * the loader resyncs and re-opens the current cell. Words corrupted by
 * a lost echo are caught by the verify+repair pass.
 */
static int
opcom_load(void)
{
	char valstr[24];
	int i, ok, retries = 0;
	double t0 = now_s(), t1;

	{
		/* estimate: count the chars to type; echo-paced round trip
		 * runs at ~16 chars/s on the 9600 console (measured) */
		long chars = 0;
		for (i = 0; i < bpun_count; i++) {
			snprintf(valstr, sizeof(valstr), "%o", bpun_data[i]);
			chars += (long)strlen(valstr) + 1;
		}
		print_eta("deposit load", (double)chars / 16.0);
	}

	snprintf(valstr, sizeof(valstr), "%o/", bpun_load);
	wrtstr(valstr);
	rdstr(' '); /* current contents of first cell + space */

	for (i = 0; i < bpun_count; i++) {
		snprintf(valstr, sizeof(valstr), "%o", bpun_data[i]);
		ok = wrtstr(valstr) == 0 &&
		    wrtstr("\r") == 0 &&
		    rdstr('#') == 0 &&
		    rdstr(' ') == 0;

		if (!ok) {
			/* lost sync - reopen this cell and redo the word */
			if (++retries > bpun_count / 4 + 32) {
				fprintf(stderr,
				    "\nload: too many retries, giving up\n");
				return -1;
			}
			opcom_sync();
			snprintf(valstr, sizeof(valstr), "%o/",
			    bpun_load + i);
			wrtstr(valstr);
			rdstr(' ');
			i--; /* redo */
			continue;
		}
		if ((i + 1) % 64 == 0) {
			double rate;
			char clk[16];

			t1 = now_s();
			rate = (i + 1) / (t1 - t0);
			fmt_clock_after((bpun_count - i - 1) / rate, clk,
			    sizeof(clk));
			fprintf(stderr, "\r%d/%d words (%.1f w/s, %d retries, "
			    "done ~%s)   ",
			    i + 1, bpun_count, rate, retries, clk);
		}
	}
	opcom_sync(); /* close the open cell */

	t1 = now_s();
	fprintf(stderr, "\rloaded %d words in %.1f s (%.1f words/s, %d retries)\n",
	    bpun_count, t1 - t0, bpun_count / (t1 - t0), retries);
	return 0;
}

/*
 * Fast load through the microcode's own serial binary loader (ETLO1):
 * type '300$' at MOPC to select the console (device 300) binary loader,
 * then stream the BPUN file bytes verbatim - the BPUN format IS the
 * loader's wire format (ND110-OPCOM-MICROCODE-REFERENCE.md).
 *
 * Timing analysis (why the pad + settle exist):
 *  - The 9600 line itself cannot be overfed: the kernel blocks writes.
 *  - Once ETLO1 runs, its INCH poll loop consumes bytes in microseconds
 *    while the line delivers one per ~1.04ms - a ~50x margin, so the
 *    binary phase needs no pacing at all. Too slow is also safe: INCH
 *    polls forever (but a stalled stream hangs the CPU until STOP/MCL).
 *  - The DANGER window is between typing '$' and ETLO1 polling: MOPC
 *    command dispatch is paced by the RTC tick and the SC2661 holds
 *    only ONE character, so bytes sent in that window are dropped.
 *    Defense: settle delay after '$' (default 400ms > a few RTC ticks)
 *    plus a run of harmless pad spaces in front of the file (spaces are
 *    ignored by the SEEK/SIKI preamble scan), so even a late loader
 *    only ever loses pad, never the B-section address or the '!'.
 *
 * With noauto, the trailing action field is replaced by '1' CR: the
 * loader then leaves the CPU stopped in MOPC (P = start address), so
 * the load can be verified with -v and started manually.
 */
static int
opcom_binload(int settle_ms, int noauto)
{
	static const char pad[16] = "                ";
	int off = 0, chunk, sent = 0;
	int len = bpun_rawlen;
	ssize_t wr;
	double t0, t1;

	if (noauto)
		len -= 2; /* drop the 2-byte action field, send '1' CR instead */

	print_eta("serial binary load (300$)",
	    (double)len / 960.0 + settle_ms / 1000.0 + 1.0);

	/* activate the console binary loader */
	if (wrtstr("300") < 0)
		return -1;
	wr = write(cfd, "$", 1); /* loader takes over - echo not guaranteed */
	(void)wr;
	usleep(settle_ms * 1000);
	while (waitch_poll_ms(50) > 0) /* eat the '$' echo, if any */
		;

	wr = write(cfd, pad, sizeof(pad)); /* absorb any residual drop window */
	(void)wr;

	t0 = now_s();
	while (off < len) {
		chunk = len - off > 256 ? 256 : len - off;
		wr = write(cfd, bpun_raw + off, chunk);
		if (wr <= 0)
			return -1;
		off += (int)wr;
		sent += (int)wr;
		tcdrain(cfd);
		{
			double rate = sent / (now_s() - t0);
			char clk[16];

			fmt_clock_after((len - sent) / rate, clk, sizeof(clk));
			fprintf(stderr, "\r%d/%d bytes (%.0f B/s, done ~%s)   ",
			    sent, len, rate, clk);
		}
	}
	if (noauto) {
		wr = write(cfd, "1\r", 2);
		(void)wr;
	}
	tcdrain(cfd);
	t1 = now_s();
	fprintf(stderr, "\rstreamed %d bytes in %.1f s (%.0f B/s)%s\n",
	    sent, t1 - t0, sent / (t1 - t0),
	    noauto ? " [no autostart]" : "");

	/* give the loader time to finish, then report anything it said
	 * (a '?' here means checksum error) */
	usleep(300 * 1000);
	{
		int n, saw = 0;
		while ((n = waitch_poll_ms(300)) > 0) {
			if (!saw) {
				fprintf(stderr, "loader said: ");
				saw = 1;
			}
			fputc(n, stderr);
			if (n == '?') {
				fprintf(stderr, "\nCHECKSUM ERROR reported\n");
				return -1;
			}
		}
		if (saw)
			fputc('\n', stderr);
	}
	return 0;
}

/* Deposit a single word: <addr>/ <value> CR, then leave a closed cell */
static void
deposit_one(int addr, unsigned short val)
{
	char b[24];

	opcom_sync();
	snprintf(b, sizeof(b), "%o/", addr);
	wrtstr(b);
	rdstr(' ');
	snprintf(b, sizeof(b), "%o", val);
	wrtstr(b);
	wrtstr("\r");
	rdstr('#');
	rdstr(' ');
	opcom_sync();
}

/*
 * Verify with a range dump: <start><<end> CR.
 * Dump format: one line per 8 words, "aaaaaa /www www ... www".
 * Collect every octal token; the first token of a line is the address,
 * the rest are data words.
 */
/* mismatch list filled by opcom_verify, repaired by the caller */
static int mism[1024];
static int nmism;

static int
opcom_verify(void)
{
	char cmd[32], c;
	int val = 0, inval = 0, isaddr = 1;
	int line_addr = 0, k = 0;
	int errors = 0, seen = 0;
	double t0 = now_s();

	nmism = 0;
	opcom_sync();

	snprintf(cmd, sizeof(cmd), "%o<%o", bpun_load,
	    bpun_load + bpun_count - 1);
	wrtstr(cmd);
	wrtstr("\r");

	/*
	 * Read until the prompt comes back. Line format:
	 *   aaaaaa /www www www www www www www www
	 * The token before '/' is the line address; the rest are the
	 * eight data words at line_addr+0 .. line_addr+7.
	 */
	for (;;) {
		int n = waitch();
		if (n == 0)
			break; /* line quiet - dump is over */
		c = (char)n;
		if (outf)
			putc(c, outf);
		if (c >= '0' && c <= '7') {
			val = (val << 3) | (c - '0');
			inval = 1;
			continue;
		}
		if (inval) { /* an octal token just ended */
			if (isaddr) {
				line_addr = val;
				k = 0;
			} else {
				int off = line_addr + k - bpun_load;
				if (off >= 0 && off < bpun_count) {
					if ((unsigned short)val !=
					    bpun_data[off]) {
						if (errors < 10)
							printf("MISMATCH %06o: "
							    "read %06o expect "
							    "%06o\n",
							    line_addr + k, val,
							    bpun_data[off]);
						if (nmism < 1024)
							mism[nmism++] = off;
						errors++;
					}
					seen++;
				}
				k++;
			}
			inval = 0;
			val = 0;
		}
		if (c == '/')
			isaddr = 0;
		else if (c == '\n' || c == '\r')
			isaddr = 1;
		/* NOTE: a '#' prompt is echoed BEFORE the dump lines, so it
		 * cannot be used as the end marker - quiet line ends the dump */
	}
	fprintf(stderr, "verified %d words in %.1f s, %d mismatches\n",
	    seen, now_s() - t0, errors);
	if (seen < bpun_count) {
		fprintf(stderr, "verify: only %d of %d words seen in dump\n",
		    seen, bpun_count);
		return -1;
	}
	return errors ? -1 : 0;
}

/*
 * Verify, repairing any mismatched cells with single deposits, up to
 * a few rounds. The dump itself can also lose characters on the link,
 * so a failed round is retried; only repeated failure is fatal.
 */
static int
opcom_verify_repair(void)
{
	int round, i, rv;

	for (round = 0; round < 5; round++) {
		rv = opcom_verify();
		if (rv == 0)
			return 0;
		if (nmism == 0)
			continue; /* dump glitched (timeout/short) - retry */
		fprintf(stderr, "repairing %d cells (round %d)\n",
		    nmism, round + 1);
		for (i = 0; i < nmism; i++)
			deposit_one(bpun_load + mism[i], bpun_data[mism[i]]);
	}
	return -1;
}

static void
opcom_start(int addr)
{
	char cmd[16];

	snprintf(cmd, sizeof(cmd), "%o!", addr);
	printf("starting at %06o\n", addr);
	wrtstr(cmd);
	/* after '!' the program owns the console - stream its output */
	printf("--- program console (Ctrl-C to exit) ---\n");
	for (;;) {
		int n = waitch_poll_ms(60000);
		if (n == 0)
			break;
		putchar(n);
		fflush(stdout);
		if (outf) {
			putc(n, outf);
			fflush(outf);
		}
	}
}

/*********************** original command / trace mode ********************/

static void
prtout(const char *s)
{
	printf("%s", s);
	if (outf)
		fprintf(outf, "%s", s);
}

static void
one_reg(const char *label, const char *reg)
{
	char pbuf[64];

	prtout(label);
	wrtstr(reg);
	obp = pbuf;
	rdstr(' ');
	*--obp = 0;
	prtout(pbuf);
}

static void
xregs(void)
{
	char pbuf[64];

	prtout(": IR=");
	obp = pbuf;
	wrtstr(obuf);
	wrtstr("/");
	obp = pbuf;
	rdstr(' ');
	*--obp = 0;
	prtout(pbuf);

	one_reg(" STS=", "I1/");
	one_reg(" D=", "D/");
	one_reg(" B=", "B/");
	one_reg(" L=", "L/");
	one_reg(" A=", "A/");
	one_reg(" T=", "T/");
	one_reg(" X=", "X/");

	obp = pbuf;
	wrtstr("\r");
	rdstr('#');
}

void
traceins(void)
{
	tobuf = 1;
	obp = obuf;
	while (tcount-- > 0) {
		wrtstr("P/");
		obp = obuf;
		rdstr(' ');
		*--obp = 0;
		prtout(obuf);
		if (pregs)
			xregs();
		prtout("\n");
		wrtstr("\r");
		rdstr('#');
		wrtstr("Z");
		wrtstr("\r");
		rdstr('#');
	}
	exit(0);
}

/* enter base state */
void
base(void)
{
	wrtstr("I/");
	rdstr(' ');
	wrtstr("\r");
	rdstr('#');
}

/*
 * Original stdin command language:
 *   MW <addr> <val>   deposit val at addr
 *   MR <addr>         examine addr
 *   M+ <val>          deposit val at next (auto-advanced) addr
 *   IW <dev> <val>    IOX write (via OPR)
 *   IR <dev>          IOX read
 *   # ...             comment
 */
void
command_mode(void)
{
	char buf[128];
	char *bp, *ap = NULL, *wp = NULL;
	int wasmem = 0, c1, c2;

	while (fgets(buf, sizeof(buf), stdin)) {
		buf[strcspn(buf, "\r\n")] = 0;
		if (buf[0] == 0)
			continue;
		c1 = buf[0];
		c2 = buf[1];
		bp = &buf[3];
		if (c2 == 'R' || c2 == 'W') {
			ap = bp;
			while (*bp >= '0' && *bp <= '7')
				bp++;
			*bp++ = 0;
		}
		if (c2 == '+' || c2 == 'W') {
			wp = bp;
			while (*bp >= '0' && *bp <= '7')
				bp++;
			*bp++ = 0;
		}

		if (c1 != 'M' && wasmem) {
			rdstr(' ');
			base();
			wasmem = 0;
		}

		switch (c1) {
		case '#':
			continue;

		case 'M':
			if (c2 == '+') {
				rdstr(' ');
				wrtstr(wp);
			} else if (c2 == 'W') {
				if (wasmem)
					base();
				wrtstr(ap);
				wrtstr("/");
				rdstr(' ');
				wrtstr(wp);
			} else if (c2 == 'R') {
				if (wasmem)
					base();
				wrtstr(ap);
				wrtstr("/");
				rdstr(' ');
			}
			wrtstr("\r");
			rdstr('#');
			wasmem = 1;
			break;

		case 'I':
			if (c2 == 'W') {
				/* setup utdata */
				wrtstr("OPR/");
				rdstr(' ');
				wrtstr(wp);
				wrtstr("\r");
				rdstr('#');
			}
			wrtstr(ap);
			wrtstr("IO/");
			rdstr(' ');
			wrtstr("\r");
			rdstr('#');
			break;
		default:
			errx(1, "bad buf %s", buf);
		}
	}
}

/*
 * Write string s, ensuring that all written chars are echoed back.
 * This is the pacing mechanism: MOPC echoes a char only when it has
 * consumed it, so one char is in flight at any time and nothing is
 * ever dropped, at the highest rate the console can actually take.
 */
int
wrtstr(const char *s)
{
	char c;
	ssize_t wr;

	for (; *s; s++) {
		wr = write(cfd, s, 1);
		(void)wr;

		do {
			if ((c = waitch()) == 0) {
				if (debug)
					printf("[timeout on %d (%c)]\n", *s,
					    *s > 31 ? *s : ' ');
				return -1;
			} else if (tobuf)
				*obp++ = c;
			else if (debug) {
				wr = write(1, &c, 1);
				(void)wr;
			}
		} while (c != *s);
	}
	return 0;
}

/*
 * Read chars until ch seen. Returns 0 on success, -1 on timeout.
 */
int
rdstr(int ch)
{
	char c;
	int n;
	ssize_t wr;

	for (;;) {
		if ((n = waitch()) == 0) {
			if (debug)
				printf("[timeout waiting for %d]\n", ch);
			return -1;
		}
		c = (char)n;
		if (tobuf)
			*obp++ = c;
		else if (debug) {
			wr = write(1, &c, 1);
			(void)wr;
		}
		if (n == ch)
			return 0;
	}
}

/*
 * Wait at most 800ms for a char (console echo latency is ~50ms; the
 * short timeout makes the load's resync-and-retry recovery snappy).
 */
int
waitch(void)
{
	struct pollfd pfds[1];
	char c;

	pfds[0].fd = cfd;
	pfds[0].events = POLLIN;
	if (poll(pfds, 1, 800) == 0)
		return 0;
	if (read(cfd, &c, 1) != 1)
		return 0;
	c &= 0177;
	return c;
}

static void
usage(void)
{
	fprintf(stderr,
	    "Usage: ndcomm [-l file.bpun [-v] [-g] [-s octaladdr]] [-t N [-r]]\n"
	    "              [-o logfile] [-d] <tty>\n"
	    "  -l file   load BPUN image into memory via OPCOM deposits\n"
	    "  -v        verify the loaded range with an OPCOM range dump\n"
	    "  -g        start the program after load (BPUN B address)\n"
	    "  -s addr   override the start address (octal)\n"
	    "  -t N      trace N instructions (P/ + Z single-step)\n"
	    "  -r        with -t: dump IR/STS/D/B/L/A/T/X each step\n"
	    "  -o file   append console traffic to a log file\n"
	    "  -d        echo all console traffic to stdout\n"
	    "  (no -l/-t: read MW/MR/M+/IW/IR commands from stdin)\n"
	    "Example: ndcomm -l RTC.BPUN -v -g /dev/ttyUSB1\n");
	exit(1);
}
