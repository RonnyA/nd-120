/**************************************************************************
** ND BUS BIF INTERFACE IMPLEMENTATION                                   **
**                                                                       **
** Processing of BIF signals                                             **
** Creation of ND BUS Devices                                            **
**                                                                       **
**                                                                       **
** Last reviewed: 22-MAR-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

#include "NDBus.h"
#include "NDDevices.h"

#ifdef ND120_DEVICECORE
#include "NDDeviceCoreAdapter.h"   // addDevicesCore() - the NDDeviceCore gate
#endif

#ifdef ND120_DEVICECORE_BUSMASTER
#include "NDCoreShim.h"            // the C bus master (raw ND120_TOP bus ports)
#endif

#include "VND120_TOP.h"
#include "VND120_TOP___024root.h" // Root-level details for updating RAM directly



DeviceManager deviceManager;

/******* BUS INTERFACE ***************/
enum class BIF_State {
    IDLE, // Idle
    READ, // Read from device
    WRITE // Write to device
};

int prev_bapr_n = 0;
int prev_bioxe_n = 0;
int prev_bmem_n = 0;
int prev_outident_n = 0;
int prev_binack_n = 0;
int prev_bdry_n_out = 0;

uint16_t idcode = 0;

BIF_State bifState = BIF_State::IDLE;

int bus_address = 0;
int bus_data = 0;
int bus_claimed = 0; // a C-model device owns the strobed address

/* Winchester trace sink - defined with the WD disc backend further down. */
static FILE *wd_trace(void);

void proccess_bif_signal(VND120_TOP *top)
{
	// Nedgative edge of BAPR (A valid address is present on the bus. Read it!)
	if ((top->BAPR_n_OUT == 0) && (prev_bapr_n == 1))
	{
		// BAPR going HIGH->LOW
		// Negate the 24 bits and mask off the rest
		bus_address = ~top->BD_23_0_n_OUT & 0xFFFFFF;		

//#define DEBUG_LOG
        if (DEBUG_BIF) printf("-> BAPR %o ", bus_address);

		// ND120_IOX_TRACE: log IOX addresses in the SMD and floppy
		// ranges (debug)
		if (getenv("ND120_IOX_TRACE") &&
		    ((bus_address & ~017) == 01540 || (bus_address & ~017) == 01560))
			printf("[iox] addr %06o %s\r\n", bus_address,
			       (bus_address & 1) ? "write" : "read");

		// Respond only to addresses a C-model device actually owns.
		// Answering unclaimed reads with 0 + instant BDRY would race
		// (and beat) the Verilog devices on the same bus, feeding the
		// CPU zeros (found by the tape-400 gate).
		bus_claimed = deviceManager.Claims(bus_address & ~1) ||
		              deviceManager.Claims(bus_address | 1);

		if ((bus_address & 1) ==0) // Read
		{			
			bifState = BIF_State::READ;
			if (DEBUG_BIF) printf(" READ \n");
		}
		else
		{
			bifState = BIF_State::WRITE;
			if (DEBUG_BIF) printf(" WRITE \n");
		}
		
		// Make sure BINPUT is cleared
		top->BINPUT_n_IN = 1;
	}

	// Nedgative edge of OUTIDENT (Check which controller that has an INTERRUPT)
	if ((top->OUTIDENT_n == 0) && (prev_outident_n == 1))
	{
		uint16_t idlevel = 0;


		switch(bus_address)
		{
			case 004:
				idlevel =10;
				break;
			case 011:
				idlevel =11;
				break;
			case 022:
				idlevel =12;
				break;
			case 043:
				idlevel =13;
				break;
			default:
				printf("Invalid IDENT level 0x%x\r\n",bus_address);
			break;
		}

			


		// Try to identify which device has interrupt
		idcode = deviceManager.IDENT(idlevel);

		// WINCHESTER INTERRUPT WATCH. Silicon's DISC-TEMA run shows
		// "INTERRUPT raised" then "IDENT answered, code 1" from the Verilog
		// card; the Verilator run reaches the same point and then dies with
		// "Software Timeout" without ever programming the transfer. So the
		// question is whether the CPU takes an interrupt at all here, and
		// what answers the IDENT: the C DeviceManager (idcode below) or the
		// Verilog card on the internal bus. A level-11 IDENT that the C model
		// answers with 0 is exactly where the card's code 1 should appear.
		if (wd_trace())
			fprintf(wd_trace(), "IDENT level=%d c_model_code=%d\n",
			        idlevel, (int)idcode);
		// IDENT tracing belongs to the DEBUG_INTERRUPT channel as well as the
		// broader DEBUG_BIF one: golden/console_ff_golden.log holds these lines
		// and the console gate turns them back on with -DDEBUG_INTERRUPT alone
		// (DEBUG_BIF=1 would also emit the BAPR/BIOXE trace, which is NOT in
		// the golden).
#ifdef DEBUG_INTERRUPT
		printf("IDENT LVL[%d]=%d\r\n", idlevel,idcode);
#else
		if (DEBUG_BIF) printf("IDENT LVL[%d]=%d\r\n", idlevel,idcode);
#endif


		if (idcode >0)
		{
			if (DEBUG_BIF) printf("Activating BINPUT !\n");
			top->BINPUT_n_IN = 0; // Tell cpu this address is READ (so we need to put data on the bus), then wait for the BINACK signal

			top->BD_23_0_n_IN = (~idcode) & 0xFFFFFF;
			//top->BDRY_n_IN = 0;
		}
		else
		{
			// NO device has a pending interrupt on this level. The oracle
			// (nd100x DeviceManager_Ident -> DoIDENT) returns 0, so the CPU reads
			// A:=0 here; it NEVER returns a stale code. On this open-collector,
			// active-low bus (idle = 0xFFFFFF) we MUST release BD so the CPU
			// reads 0 and not the ident code the PREVIOUS level's IDENT left
			// driven. Without this a device appears to answer IDENT on levels it
			// has no active interrupt on (TPE config investigation: LINE PRINTER
			// (lvl 10) also seen on 11/12, FLOPPY (lvl 11) also on 12). Do NOT
			// assert BINPUT: there is no data to present on an unclaimed level.
			top->BD_23_0_n_IN = 0xFFFFFF;
			top->BINPUT_n_IN  = 1;
		}
	}

	if ((top->OUTIDENT_n == 1) && (prev_outident_n == 0))
	{
		// Clear idcode
		if (idcode >0)
		{
			if (DEBUG_BIF) printf("Clearing OUTIDENT code %o\r\n",idcode);
			idcode = 0;
			top->BINPUT_n_IN = 1;
			top->BDRY_n_IN = 1;
		}
		// ALWAYS release the ident data lines when OUTIDENT deasserts, so no
		// stale code can linger on BD into the next IDENT cycle (open-collector
		// idle = 0xFFFFFF). Belt-and-suspenders with the no-match release above.
		top->BD_23_0_n_IN = 0xFFFFFF;
	}


	// Negative edge of BDRY_n_OUT tells us that data is valid on the bus
	if ((top->BDRY_n_OUT == 0) && (prev_bdry_n_out == 1))
	{		

		if (bifState != BIF_State::IDLE)
		{
			// nope?
			// 16 bits data valid on the BUS, read it!
			//bus_data = (~top->BD_23_0_n_OUT) & 0xFFFF;

			// DEBUG
			//printf("BDRY_n - Data: %o \n", bus_data);

			
		}
	}

	// Nedgative edge of BIOXE  (IOX in our out)
	if ((top->BIOXE_n == 0) && (prev_bioxe_n == 1))
	{

		if (DEBUG_BIF) printf("BIOXE_n START\n"); // BUS IOX Enabled

		// 16 bits data valid on the BUS, read the exported A register
		bus_data = (~top->BD_23_0_n_OUT) & 0xFFFF;

		
		// WINCHESTER IOX WATCH (500-507). The disc-side trace showed the card
		// never issuing a single START/REQ while still reporting "finished",
		// so the question is whether the CPU programs the card at all. This
		// logs every IOX the CPU aims at the card's own address block,
		// independent of whether any C-model device claims it.
		if ((bus_address & ~07) == 0500 && wd_trace())
			fprintf(wd_trace(), "IOX %s reg=%ld addr=%06o data=%06o\n",
			        (bus_address & 1) ? "W" : "R",
			        (long)((bus_address - 0500) >> 1), bus_address, bus_data);

		if (bifState == BIF_State::WRITE && bus_claimed)
		{
			if (DEBUG_BIF) printf("WRITE IOX Address: %o Data: %o \n", bus_address, bus_data);

			deviceManager.Write(bus_address, bus_data);
			top->BDRY_n_IN = 0; // Tell we have accepted the data
		}
		
		// If CPU tries to read, we need to ask CPU if we can write to bus - then wait for BINACK_n
		if (bifState == BIF_State::READ && bus_claimed)
		{
			if (DEBUG_BIF) printf("Activating BINPUT !\n");
			top->BINPUT_n_IN = 0; // Tell cpu this address is READ (so we need to put data on the bus), then wait for the BINACK signal
		}
	}

	// Negative edge of BINACK (meaning CPU is ready to read data)
	if ((top->BINACK_n == 0) && (prev_binack_n == 1))
	{
		if (DEBUG_BIF) printf("BINACK_n !\n");
		if (bifState == BIF_State::READ && bus_claimed)
		{
			top->BD_23_0_n_IN = (~deviceManager.Read(bus_address)) & 0xFFFFFF;
			top->BDAP_n_IN = 0; // DATA Present
			top->BDRY_n_IN = 0;
		}
		else if (idcode>0)
		{
			if (DEBUG_BIF) printf("Setting IDCODE %d\r\n",idcode);
			top->BD_23_0_n_IN = (~idcode) & 0xFFFFFF;
			top->BDAP_n_IN = 0; // DATA Present
			top->BDRY_n_IN = 0; //
		}
	}

	// Positive edge of BIOXE (clear BDRY signal)
	if ((top->BIOXE_n == 1) && (prev_bioxe_n == 0))
	{
		if (DEBUG_BIF) printf("BIOXE exit!\n");

		top->BDRY_n_IN = 1;
		top->BDAP_n_IN = 1;
		top->BINPUT_n_IN = 1;
		top->BD_23_0_n_IN = 0xFFFFFF; // Clear (set to high, which means 0)
		bifState = BIF_State::IDLE;
	}

	
	// Negative edge of BMEM_n (memory r/w)
	if ((top->BMEM_n == 0) && ( prev_bmem_n==1))
	{
		/*
		// 16 bits data
		bus_data = ~top->BD_23_0_n_OUT & 0xFFFF;

		printf("BMEM_n Address: %o Data: %o \n", bus_address, bus_data);
		*/
	}

#ifdef ND120_DEVICECORE_BUSMASTER
	// THE C BUS MASTER. This empty BMEM_n stub above is exactly the slot it
	// belongs in: NDBus.cpp has never had DMA (see NDDeviceCore's trap list -
	// "no DMA in NDBus.cpp" must NOT be read as "DMA is impossible").
	//
	// It is ticked BEFORE deviceManager.Tick() so the FSM advances on the
	// signals the CPU produced in the eval() that just ran; the device core
	// then observes the completion in the same pass via dma_poll().
	//
	// One call = one FSM step = one FULL sysclk period, which is the rate
	// ND_DMA_MASTER.v's always @(posedge sysclk) runs at. NOTE: this function
	// is NOT called every half-clock (a common claim) - Run120.cpp toggles
	// sysclk twice per loop iteration, so we always see the same phase.
	ndcore_shim_bus_tick(top);
#endif

#ifdef ND120_VERILOG_DEVICES
	// Serve the Verilog devices' backend ports (the C models are NOT
	// registered in this build - see addDevices).
#ifndef ND120_SD_STORAGE
	// SD_STORAGE=1: the Verilog SD-FAT stack inside ND120_TOP serves the tape
	// bytes from a simulated SD card, so this C file server must stand down -
	// otherwise both would answer TAPE_BYTE_REQ.
	process_verilog_tape(top);
#endif
	process_verilog_floppy(top);
	process_verilog_smd(top);
	process_verilog_wd(top);
#endif

	// Tick deviceManager
	uint16_t interruptBits = deviceManager.Tick();

	// BINTxx_n is active-low: assert (0) when this device level has its bit
	// set. The old code compared the masked value == 1, which is never true
	// for level >= 1 (see NDBUS_ASSERT_C_INTERRUPTS in NDBus.h) - so these
	// lines were stuck deasserted and C devices were poll-only.
#if NDBUS_ASSERT_C_INTERRUPTS
	top->BINT10_n = (interruptBits & (1<<10)) ? 0 : 1;
	top->BINT11_n = (interruptBits & (1<<11)) ? 0 : 1;
	top->BINT12_n = (interruptBits & (1<<12)) ? 0 : 1;
	top->BINT13_n = (interruptBits & (1<<13)) ? 0 : 1;
#else
	// Legacy always-deasserted behaviour (poll-only C devices)
	top->BINT10_n = 1;
	top->BINT11_n = 1;
	top->BINT12_n = 1;
	top->BINT13_n = 1;
#endif

	// Update signals
	prev_bapr_n = top->BAPR_n_OUT;
	prev_bioxe_n = top->BIOXE_n;
	prev_bmem_n = top->BMEM_n;
	prev_outident_n = top->OUTIDENT_n;
	prev_binack_n = top->BINACK_n;
	prev_bdry_n_out = top->BDRY_n_OUT;
}

void addDevices()
{
#ifndef ND120_VERILOG_DEVICES
#ifndef ND120_DEVICECORE_TAPE
	// Add the PaperTape (TapeReader) at octal 400-403.
	// SUPPRESSED under ND120_DEVICECORE_TAPE: the portable NDDeviceCore
	// nd_tape400 owns 0400-0403 in that build, and two devices claiming the
	// same window would race on every IOX cycle.
	deviceManager.AddDevice(DeviceType::PaperTape, 0);
#endif

#ifndef ND120_DEVICECORE_FLOPPY
	// Add the FloppyPIO at octal 1560-1567.
	// SUPPRESSED under ND120_DEVICECORE_FLOPPY: the portable NDDeviceCore
	// nd_floppy_dma owns 1560-1567 in that build, and two devices claiming
	// the same window would race on every IOX cycle.
	deviceManager.AddDevice(DeviceType::FloppyPIO, 0);
#endif
#endif
	// With ND120_VERILOG_DEVICES both devices are Verilog cores inside
	// ND120_TOP; this harness only serves their backend ports (tape
	// bytes + floppy disk image).

#ifdef ND120_DEVICECORE
	// The NDDeviceCore RTL equivalence gate (runSim: make DEVICECORE=1).
	// Registers the PORTABLE C99 cores (the same .c that runs on the RP2350
	// controller card) so the real ND-120 CPU + bus RTL drives them.
	// Their IOX windows do not overlap any device above.
	addDevicesCore();
#endif
}

#ifdef ND120_VERILOG_DEVICES
/* Byte source for the Verilog ND_TAPE_400 device (same tape file the C
** papertape model uses). Called once per half-clock like the rest of
** the bus processing, so the request/rewind pulses (one full clock)
** are edge-detected to serve exactly one byte per request. The valid
** flag spans one full clock; the device tolerates seeing the same
** byte on two edges (same data, no position change). */
static FILE *vtape_file = 0;
static int vtape_prev_req = 0;
static int vtape_prev_rewind = 0;
static int vtape_valid_ticks = 0;

void process_verilog_tape(VND120_TOP *top)
{
	if (vtape_file == 0)
	{
		vtape_file = fopen("INSTRUCTION-B.BPUN", "r");
		if (vtape_file == 0)
			printf("VerilogTape: unable to open INSTRUCTION-B.BPUN\r\n");
	}

	if (vtape_valid_ticks > 0)
	{
		vtape_valid_ticks--;
		if (vtape_valid_ticks == 0)
			top->TAPE_BYTE_VALID = 0;
	}

	if (top->TAPE_REWIND && !vtape_prev_rewind && vtape_file != 0)
	{
		rewind(vtape_file);
	}

	if (top->TAPE_BYTE_REQ && !vtape_prev_req && vtape_file != 0)
	{
		int w = getc(vtape_file);
		if (w >= 0)
		{
			top->TAPE_BYTE_DATA = w & 0xFF;
			top->TAPE_BYTE_VALID = 1;
			vtape_valid_ticks = 2; // one full clock
		}
		else
		{
			printf("VerilogTape EOF");
		}
	}

	vtape_prev_req = top->TAPE_BYTE_REQ;
	vtape_prev_rewind = top->TAPE_REWIND;
}

/* Disk-image backend for the Verilog ND_FLOPPY_DMA (FLOPPY.IMG).
** DMA-flavor position math: byte offset = logical sector * sector
** size; sector size by format: 0=512, 1=256, 2=128, 3=1024 bytes
** (nd100x deviceFloppyDMA). One word moves per half-clock call. */
static FILE *vflp_file = 0;
static int vflp_dbg = (getenv("ND120_FLOPPY_DEBUG") != 0);
static int vflp_prev_req = 0;
static int vflp_state = 0;    // 0 idle, 1 read-stream, 2 write-addr, 3 write-take, 4 read-tail
static long vflp_pos = 0;
static int vflp_words = 0, vflp_idx = 0;
static int vflp_done_ticks = 0;

void process_verilog_floppy(VND120_TOP *top)
{
	if (vflp_file == 0)
	{
		// ND120_FLOPPY_IMG selects the image (unit tests use a generated
		// one); default FLOPPY.IMG
		const char *img = getenv("ND120_FLOPPY_IMG");
		if (img == 0) img = "FLOPPY.IMG";
		vflp_file = fopen(img, "r+");
		if (vflp_file == 0)
			vflp_file = fopen(img, "r");

		// Media format from the image size, exactly like nd100x
		// deviceFloppyDMA.c READ FORMAT: 315392 bytes = 8-inch disk
		// (512 B/sector, format word 0); >= 1261568 bytes = 5.25"
		// 1.2MB (1024 B/sector + double sided + double density = 017
		// octal). Default 0xF (the 1.2MB descriptor) if unknown.
		top->FDISK_MEDIA_FMT = 0xF;
		if (vflp_file != 0)
		{
			long sz;
			fseek(vflp_file, 0, SEEK_END);
			sz = ftell(vflp_file);
			fseek(vflp_file, 0, SEEK_SET);
			if (sz == 315392)
				top->FDISK_MEDIA_FMT = 0x0;
			else if (sz >= 1261568)
				top->FDISK_MEDIA_FMT = 0xF;
		}
	}

	if (vflp_done_ticks > 0)
	{
		if (--vflp_done_ticks == 0)
		{
			top->FDISK_DONE = 0;
			top->FDISK_ERR = 0;
		}
	}

	if (top->FDISK_REQ && !vflp_prev_req)
	{
		int bytes_per_sector = (top->FDISK_FORMAT == 0) ? 512 :
		                       (top->FDISK_FORMAT == 1) ? 256 :
		                       (top->FDISK_FORMAT == 2) ? 128 : 1024;
		vflp_pos = (long)top->FDISK_LSECT * bytes_per_sector;
		vflp_words = top->FDISK_WORDCOUNT;
		vflp_idx = 0;

		// ND120_FLOPPY_DEBUG=1 traces every backend sector request so a silent
		// boot hang shows WHICH sector the device asked for and whether it was
		// served (the boot microcode polls ready forever with no timeout, so
		// without this a stall is invisible).
		if (vflp_dbg)
			printf("[flpdbg] REQ %s lsect=%d fmt=%d wc=%d -> byte pos %ld\n",
			       top->FDISK_WR ? "WRITE" : "READ", (int)top->FDISK_LSECT,
			       (int)top->FDISK_FORMAT, (int)top->FDISK_WORDCOUNT, vflp_pos);

		if (vflp_file == 0 || fseek(vflp_file, vflp_pos, SEEK_SET) != 0)
		{
			if (vflp_dbg)
				printf("[flpdbg]   SEEK FAILED (file=%p) -> FDISK_ERR\n", (void *)vflp_file);
			top->FDISK_ERR = 1;
			top->FDISK_DONE = 1;
			vflp_done_ticks = 2;
		}
		else if (!top->FDISK_WR)
		{
			vflp_state = 1;
		}
		else
		{
			vflp_state = 2;
		}
	}
	else if (vflp_state == 1) // read: one word per call into the buffer
	{
		int hi = getc(vflp_file);
		int lo = getc(vflp_file);
		if (hi < 0 || lo < 0)
		{
			top->FDISK_ERR = 1;
			top->FDISK_DONE = 1;
			vflp_done_ticks = 2;
			top->FDBUF_WE = 0;
			vflp_state = 0;
		}
		else
		{
			top->FDBUF_ADDR = vflp_idx & 0x3FF;
			top->FDBUF_WDATA = ((hi & 0xFF) << 8) | (lo & 0xFF);
			top->FDBUF_WE = 1;
			vflp_idx++;
			if (vflp_idx >= vflp_words)
				vflp_state = 4;
		}
	}
	else if (vflp_state == 4) // read tail: drop WE, pulse done
	{
		if (vflp_dbg)
			printf("[flpdbg]   served %d words, first=%06o -> FDISK_DONE\n",
			       vflp_idx, (unsigned)top->FDBUF_WDATA);
		top->FDBUF_WE = 0;
		top->FDISK_DONE = 1;
		vflp_done_ticks = 2;
		vflp_state = 0;
	}
	else if (vflp_state == 2) // write: present the buffer address
	{
		top->FDBUF_WE = 0;
		top->FDBUF_ADDR = vflp_idx & 0x3FF;
		vflp_state = 3;
	}
	else if (vflp_state == 3) // write: take the word after eval settled
	{
		unsigned short w = top->FDBUF_RDATA;
		putc((w >> 8) & 0xFF, vflp_file);
		putc(w & 0xFF, vflp_file);
		vflp_idx++;
		if (vflp_idx >= vflp_words)
		{
			fflush(vflp_file);
			top->FDISK_DONE = 1;
			vflp_done_ticks = 2;
			vflp_state = 0;
		}
		else
		{
			vflp_state = 2;
		}
	}

	vflp_prev_req = top->FDISK_REQ;
}

/* Disk backend for the Verilog ND_SMD (disk 0). Image selected by
** ND120_SMD_IMG (no default - without it every operation reports an
** error, like a drive with no pack). Position mapping (same as the
** SMD unit tb and nd_storage_disc_adapter.v): the block address is
** cylinder/head/sector, so
**   LBA        = (cyl * SMD_GEO_HEADS + head) * SMD_GEO_SPT + sector
**   byte offset = LBA * SMD_SECTOR_BYTES
** with head = blkaddrI bits 15-8 and sector = blkaddrI bits 7-0.
** (Was blkaddrII * 2048 + blkaddrI * 64, which matches the real geometry
** only at block 0 - so the boot worked and everything past it read the
** wrong part of the image.)
** SDISK_START latches the position, chunks advance linearly. */
#define SMD_GEO_HEADS    5
#define SMD_GEO_SPT      18
#define SMD_SECTOR_BYTES 1024L
static FILE *vsmd_file = 0;
static int vsmd_file_tried = 0;
static int vsmd_prev_req = 0;
static int vsmd_state = 0;
static long vsmd_pos = 0;   // byte position, advances across chunks
static int vsmd_words = 0, vsmd_idx = 0;
static int vsmd_done_ticks = 0;

void process_verilog_smd(VND120_TOP *top)
{
	if (vsmd_file == 0 && !vsmd_file_tried)
	{
		vsmd_file_tried = 1;
		const char *img = getenv("ND120_SMD_IMG");
		if (img != 0)
		{
			vsmd_file = fopen(img, "r+");
			if (vsmd_file == 0)
				vsmd_file = fopen(img, "r");
			if (vsmd_file == 0)
				printf("VerilogSMD: cannot open %s\r\n", img);
		}
	}

	if (vsmd_done_ticks > 0)
	{
		if (--vsmd_done_ticks == 0)
		{
			top->SDISK_DONE = 0;
			top->SDISK_ERR = 0;
		}
	}

	if (top->SDISK_START)
	{
		{
			long cyl  = (long)top->SDISK_BLKADDR2;
			long head = ((long)top->SDISK_BLKADDR1 >> 8) & 0xFF;
			long sect = (long)top->SDISK_BLKADDR1 & 0xFF;
			long lba  = (cyl * SMD_GEO_HEADS + head) * SMD_GEO_SPT + sect;
			vsmd_pos  = lba * SMD_SECTOR_BYTES;
		}
		if (getenv("ND120_SMD_TRACE"))
			printf("[smd] START blk2=%06o blk1=%06o unit=%d pos=%ld\r\n",
			       top->SDISK_BLKADDR2, top->SDISK_BLKADDR1,
			       (int)top->SDISK_UNIT, vsmd_pos);
	}

	if (top->SDISK_REQ && !vsmd_prev_req)
	{
		if (getenv("ND120_SMD_TRACE"))
			printf("[smd] REQ wr=%d words=%d pos=%ld\r\n",
			       (int)top->SDISK_WR, (int)top->SDISK_WORDCOUNT, vsmd_pos);
		vsmd_words = top->SDISK_WORDCOUNT;
		vsmd_idx = 0;
		if (vsmd_file == 0 || fseek(vsmd_file, vsmd_pos, SEEK_SET) != 0)
		{
			top->SDISK_ERR = 1;
			top->SDISK_DONE = 1;
			vsmd_done_ticks = 2;
		}
		else if (!top->SDISK_WR)
		{
			vsmd_state = 1;
		}
		else
		{
			vsmd_state = 2;
		}
	}
	else if (vsmd_state == 1) // read: one word per call into the buffer
	{
		int hi = getc(vsmd_file);
		int lo = getc(vsmd_file);
		if (hi < 0 || lo < 0)
		{
			top->SDISK_ERR = 1;
			top->SDISK_DONE = 1;
			vsmd_done_ticks = 2;
			top->SDBUF_WE = 0;
			vsmd_state = 0;
		}
		else
		{
			top->SDBUF_ADDR = vsmd_idx & 0x3FF;
			top->SDBUF_WDATA = ((hi & 0xFF) << 8) | (lo & 0xFF);
			top->SDBUF_WE = 1;
			vsmd_idx++;
			if (vsmd_idx >= vsmd_words)
				vsmd_state = 4;
		}
	}
	else if (vsmd_state == 4)
	{
		top->SDBUF_WE = 0;
		vsmd_pos += 2L * vsmd_words;
		top->SDISK_DONE = 1;
		vsmd_done_ticks = 2;
		vsmd_state = 0;
	}
	else if (vsmd_state == 2) // write: present the buffer address
	{
		top->SDBUF_WE = 0;
		top->SDBUF_ADDR = vsmd_idx & 0x3FF;
		vsmd_state = 3;
	}
	else if (vsmd_state == 3) // write: take the word
	{
		unsigned short w = top->SDBUF_RDATA;
		putc((w >> 8) & 0xFF, vsmd_file);
		putc(w & 0xFF, vsmd_file);
		vsmd_idx++;
		if (vsmd_idx >= vsmd_words)
		{
			fflush(vsmd_file);
			vsmd_pos += 2L * vsmd_words;
			top->SDISK_DONE = 1;
			vsmd_done_ticks = 2;
			vsmd_state = 0;
		}
		else
		{
			vsmd_state = 2;
		}
	}

	vsmd_prev_req = top->SDISK_REQ;
}

/* Disk backend for the Verilog ND_WINCHESTER (ST506/8 inch card at IOX 500).
** Image selected by ND120_WD_IMG (no default - without it every operation
** reports an error, like a drive with no pack).
**
** WHY THIS EXISTS: the Winchester seam (the WDISK_ and WDBUF_ ports) has
** been a port on
** ND120_TOP since the card was written, but NOTHING drove it here - only the
** SMD seam above had a server. So WDISK_DONE was tied low and the card could
** never complete a transfer with the real CPU in Verilator. The card was
** therefore taken straight from iverilog unit benches to the Tang, where the
** only instrument is a 128-entry IOX ring over a UART. That cost four wrong
** trigger designs and eleven dead hypotheses to find one bug. This closes it.
**
** Geometry is the Micropolis 1325 (DISC-74-1): 8 heads, 9 sectors/track,
** 1024-byte sectors - it MUST match the ND_WINCHESTER GEO_* parameters in
** ND120_CORE.v (gen_wd) and the nd_storage_disc_adapter in front of the card
** on hardware, or sim and silicon read different parts of the image.
** Mapping is the same oracle CHS->LBA formula the SMD uses:
**   LBA         = (cyl * WD_GEO_HEADS + head) * WD_GEO_SPT + sector
**   byte offset = LBA * WD_SECTOR_BYTES
** with head = blkaddrI bits 15-8 and sector = blkaddrI bits 7-0. */
#define WD_GEO_HEADS    8
#define WD_GEO_SPT      9
#define WD_SECTOR_BYTES 1024L
static FILE *vwd_file = 0;
static int vwd_file_tried = 0;
/* Trace sink. ND120_WD_TRACE alone printf()s, which is USELESS under the
** nd120_probe engine: its stdout carries the machine-readable line protocol,
** so trace lines are parsed as junk and dropped. Set ND120_WD_TRACE_FILE to a
** path to get the trace in a file that nothing else writes to. */
static FILE *vwd_trc = 0;
static int vwd_trc_tried = 0;

static FILE *wd_trace(void)
{
	if (!vwd_trc_tried)
	{
		vwd_trc_tried = 1;
		const char *tf = getenv("ND120_WD_TRACE_FILE");
		if (tf != 0)
		{
			vwd_trc = fopen(tf, "w");
			if (vwd_trc)
				setvbuf(vwd_trc, 0, _IOLBF, 0);
		}
	}
	return vwd_trc;
}
static int vwd_prev_req = 0;
static int vwd_state = 0;
static long vwd_pos = 0;   // byte position, advances across chunks
static int vwd_words = 0, vwd_idx = 0;
static int vwd_done_ticks = 0;

void process_verilog_wd(VND120_TOP *top)
{
	if (vwd_file == 0 && !vwd_file_tried)
	{
		vwd_file_tried = 1;
		const char *img = getenv("ND120_WD_IMG");
		if (img != 0)
		{
			vwd_file = fopen(img, "r+");
			if (vwd_file == 0)
				vwd_file = fopen(img, "r");
			if (vwd_file == 0)
				printf("VerilogWD: cannot open %s\r\n", img);
			if (wd_trace())
				fprintf(wd_trace(), "open %s -> %s\n", img,
				        vwd_file ? "OK" : "FAILED");
		}
		else if (wd_trace())
		{
			fprintf(wd_trace(), "open SKIPPED - ND120_WD_IMG unset\n");
		}
	}

	if (vwd_done_ticks > 0)
	{
		if (--vwd_done_ticks == 0)
		{
			top->WDISK_DONE = 0;
			top->WDISK_ERR = 0;
		}
	}

	if (top->WDISK_START)
	{
		{
			long cyl  = (long)top->WDISK_BLKADDR2;
			long head = ((long)top->WDISK_BLKADDR1 >> 8) & 0xFF;
			long sect = (long)top->WDISK_BLKADDR1 & 0xFF;
			long lba  = (cyl * WD_GEO_HEADS + head) * WD_GEO_SPT + sect;
			vwd_pos   = lba * WD_SECTOR_BYTES;
		}
		if (wd_trace())
			fprintf(wd_trace(), "START blk2=%06o blk1=%06o unit=%d pos=%ld\n",
			        top->WDISK_BLKADDR2, top->WDISK_BLKADDR1,
			        (int)top->WDISK_UNIT, vwd_pos);
	}

	if (top->WDISK_REQ && !vwd_prev_req)
	{
		if (wd_trace())
			fprintf(wd_trace(), "REQ wr=%d words=%d pos=%ld\n",
			        (int)top->WDISK_WR, (int)top->WDISK_WORDCOUNT, vwd_pos);
		vwd_words = top->WDISK_WORDCOUNT;
		vwd_idx = 0;
		if (vwd_file == 0 || fseek(vwd_file, vwd_pos, SEEK_SET) != 0)
		{
			top->WDISK_ERR = 1;
			top->WDISK_DONE = 1;
			vwd_done_ticks = 2;
		}
		else if (!top->WDISK_WR)
		{
			vwd_state = 1;
		}
		else
		{
			vwd_state = 2;
		}
	}
	else if (vwd_state == 1) // read: one word per call into the buffer
	{
		int hi = getc(vwd_file);
		int lo = getc(vwd_file);
		if (hi < 0 || lo < 0)
		{
			top->WDISK_ERR = 1;
			top->WDISK_DONE = 1;
			vwd_done_ticks = 2;
			top->WDBUF_WE = 0;
			vwd_state = 0;
		}
		else
		{
			top->WDBUF_ADDR = vwd_idx & 0x3FF;
			top->WDBUF_WDATA = ((hi & 0xFF) << 8) | (lo & 0xFF);
			top->WDBUF_WE = 1;
			vwd_idx++;
			if (vwd_idx >= vwd_words)
				vwd_state = 4;
		}
	}
	else if (vwd_state == 4)
	{
		if (wd_trace())
			fprintf(wd_trace(), "READ DONE %d words, next pos=%ld\n",
			        vwd_words, vwd_pos + 2L * vwd_words);
		top->WDBUF_WE = 0;
		vwd_pos += 2L * vwd_words;
		top->WDISK_DONE = 1;
		vwd_done_ticks = 2;
		vwd_state = 0;
	}
	else if (vwd_state == 2) // write: present the buffer address
	{
		top->WDBUF_WE = 0;
		top->WDBUF_ADDR = vwd_idx & 0x3FF;
		vwd_state = 3;
	}
	else if (vwd_state == 3) // write: take the word
	{
		unsigned short w = top->WDBUF_RDATA;
		putc((w >> 8) & 0xFF, vwd_file);
		putc(w & 0xFF, vwd_file);
		vwd_idx++;
		if (vwd_idx >= vwd_words)
		{
			fflush(vwd_file);
			vwd_pos += 2L * vwd_words;
			top->WDISK_DONE = 1;
			vwd_done_ticks = 2;
			vwd_state = 0;
		}
		else
		{
			vwd_state = 2;
		}
	}

	vwd_prev_req = top->WDISK_REQ;
}
#endif


/*
Norsk Data ND-06.026,1 EN

PAGE 126 (143 in pdf)

A CPU memory read or write cycle is started by an internal signal requesting the bus.
When the bus arbiter grants the request /BMEM, the bus cycle can begin. 
The CPU sets /BINPUT false (high) for a memory read cycle and true (low) for a memory write cycle. 
The 24-bit physical memory adcress is strobed onto the bus (/BAPR).

When valid data is available on the bus, the data source (memory card for read cycle; CPU for write) acknowledges with BDAP. 
The memory card closes by the memory cycle by signaling with /BDRY that data has been transfered.

*/