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
		printf("IDENT LVL[%d]=%d\r\n", idlevel,idcode);


		if (idcode >0)
		{
			if (DEBUG_BIF) printf("Activating BINPUT !\n");
			top->BINPUT_n_IN = 0; // Tell cpu this address is READ (so we need to put data on the bus), then wait for the BINACK signal

			top->BD_23_0_n_IN = (~idcode) & 0xFFFFFF;
			//top->BDRY_n_IN = 0;
		}
	}

	if ((top->OUTIDENT_n == 1) && (prev_outident_n == 0))
	{
		// Clear idcode
		if (idcode >0)
		{
			printf("Clearing OUTIDENT code %o\r\n",idcode);
			idcode = 0;
			top->BINPUT_n_IN = 1;
			top->BDRY_n_IN = 1;
		}
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
			printf("Setting IDCODE %d\r\n",idcode);
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
	
#ifdef ND120_VERILOG_DEVICES
	// Serve the Verilog devices' backend ports (the C models are NOT
	// registered in this build - see addDevices).
	process_verilog_tape(top);
	process_verilog_floppy(top);
#endif

	// Tick deviceManager
	uint16_t interruptBits = deviceManager.Tick();

	top->BINT10_n = !((interruptBits & 1<<10) == 1);
	top->BINT11_n = !((interruptBits & 1<<11) == 1);
	top->BINT12_n = !((interruptBits & 1<<12) == 1);
	top->BINT13_n = !((interruptBits & 1<<13) == 1);

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
	// Add the PaperTape (TapeReader) at octal 400-403
	deviceManager.AddDevice(DeviceType::PaperTape, 0);

	// Add the FloppyPIO at octal 1560-1567
	deviceManager.AddDevice(DeviceType::FloppyPIO, 0);
#endif
	// With ND120_VERILOG_DEVICES both devices are Verilog cores inside
	// ND120_TOP; this harness only serves their backend ports (tape
	// bytes + floppy disk image).
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

/* Disk-image backend for the Verilog ND_FLOPPY_PIO (FLOPPY.IMG, same
** file and position math as the C FloppyPIO model). One word moves per
** half-clock call: reads stream image words into the device buffer via
** the FDBUF port, writes stream buffer words into the image. Command
** ops other than read/write/writedel (format) fill the track with the
** C model's 0xAAFF pattern. */
static FILE *vflp_file = 0;
static int vflp_prev_req = 0;
static int vflp_state = 0;    // 0 idle, 1 read-stream, 2 write-addr, 3 write-take, 4 done-pulse
static long vflp_pos = 0;
static int vflp_words = 0, vflp_idx = 0;
static unsigned vflp_bufstart = 0;
static int vflp_op = 0;
static int vflp_done_ticks = 0;

void process_verilog_floppy(VND120_TOP *top)
{
	if (vflp_file == 0)
	{
		vflp_file = fopen("FLOPPY.IMG", "r+");
		if (vflp_file == 0)
			vflp_file = fopen("FLOPPY.IMG", "r");
	}

	if (vflp_done_ticks > 0)
	{
		if (--vflp_done_ticks == 0)
		{
			top->FDISK_DONE = 0;
			top->FDISK_ERR_NOTRDY = 0;
			top->FDISK_ERR_MISSING = 0;
		}
	}

	if (top->FDISK_REQ && !vflp_prev_req)
	{
		int bytes_per_sector = (top->FDISK_FORMAT == 2) ? 256 :
		                       (top->FDISK_FORMAT == 3) ? 512 : 128;
		int sectors_per_track = (top->FDISK_FORMAT == 2) ? 15 :
		                        (top->FDISK_FORMAT == 3) ? 8 : 26;
		vflp_pos = ((long)top->FDISK_SECTOR - 1) * bytes_per_sector +
		           (long)top->FDISK_TRACK * bytes_per_sector * sectors_per_track;
		vflp_words = top->FDISK_WORDCOUNT;
		vflp_bufstart = top->FDISK_BUF_START;
		vflp_idx = 0;
		vflp_op = top->FDISK_OP;

		if (vflp_file == 0 || fseek(vflp_file, vflp_pos, SEEK_SET) != 0)
		{
			top->FDISK_ERR_NOTRDY = 1;
			top->FDISK_DONE = 1;
			vflp_done_ticks = 2;
		}
		else if (vflp_op == 4) // read data
		{
			vflp_state = 1;
		}
		else if (vflp_op == 1 || vflp_op == 2) // write / write deleted
		{
			vflp_state = 2;
		}
		else // format track: C-model 0xAAFF fill
		{
			for (int sct = 0; sct < sectors_per_track; sct++)
				for (int w = 0; w < bytes_per_sector / 2; w++)
				{
					long p = (long)top->FDISK_TRACK * bytes_per_sector *
					             sectors_per_track + sct * bytes_per_sector + w * 2;
					fseek(vflp_file, p, SEEK_SET);
					putc(0xAA, vflp_file);
					putc(0xFF, vflp_file);
				}
			fflush(vflp_file);
			top->FDISK_DONE = 1;
			vflp_done_ticks = 2;
		}
	}
	else if (vflp_state == 1) // read: one word per call into the buffer
	{
		int hi = getc(vflp_file);
		int lo = getc(vflp_file);
		if (hi < 0 || lo < 0)
		{
			top->FDISK_ERR_NOTRDY = 1;
			top->FDISK_DONE = 1;
			vflp_done_ticks = 2;
			top->FDBUF_WE = 0;
			vflp_state = 0;
		}
		else
		{
			top->FDBUF_ADDR = (vflp_bufstart + vflp_idx) & 0x3FF;
			top->FDBUF_WDATA = ((hi & 0xFF) << 8) | (lo & 0xFF);
			top->FDBUF_WE = 1;
			vflp_idx++;
			if (vflp_idx >= vflp_words)
			{
				vflp_state = 4;
			}
		}
	}
	else if (vflp_state == 4) // read tail: drop WE, pulse done
	{
		top->FDBUF_WE = 0;
		top->FDISK_DONE = 1;
		vflp_done_ticks = 2;
		vflp_state = 0;
	}
	else if (vflp_state == 2) // write: present the buffer address
	{
		top->FDBUF_WE = 0;
		top->FDBUF_ADDR = (vflp_bufstart + vflp_idx) & 0x3FF;
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