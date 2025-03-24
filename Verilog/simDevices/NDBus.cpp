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

		
		if (bifState == BIF_State::WRITE) 
		{
			if (DEBUG_BIF) printf("WRITE IOX Address: %o Data: %o \n", bus_address, bus_data);

			deviceManager.Write(bus_address, bus_data);
			top->BDRY_n_IN = 0; // Tell we have accepted the data
		}
		
		// If CPU tries to read, we need to ask CPU if we can write to bus - then wait for BINACK_n
		if (bifState == BIF_State::READ)
		{
			if (DEBUG_BIF) printf("Activating BINPUT !\n");
			top->BINPUT_n_IN = 0; // Tell cpu this address is READ (so we need to put data on the bus), then wait for the BINACK signal
		}
	}

	// Negative edge of BINACK (meaning CPU is ready to read data)
	if ((top->BINACK_n == 0) && (prev_binack_n == 1))
	{
		if (DEBUG_BIF) printf("BINACK_n !\n");
		if (bifState == BIF_State::READ)
		{
			top->BD_23_0_n_IN = (~deviceManager.Read(bus_address)) & 0xFFFFFF;
			top->BDRY_n_IN = 0;
		}
		else if (idcode>0)
		{
			printf("Setting IDCODE %d\r\n",idcode);
			top->BD_23_0_n_IN = (~idcode) & 0xFFFFFF;
			top->BDRY_n_IN = 0;
		}
	}

	// Positive edge of BIOXE (clear BDRY signal)
	if ((top->BIOXE_n == 1) && (prev_bioxe_n == 0))
	{
		if (DEBUG_BIF) printf("BIOXE exit!\n");

		top->BDRY_n_IN = 1;
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
	// Add the PaperTape (TapeReader) at octal 400-403
	deviceManager.AddDevice(DeviceType::PaperTape, 0);

	// Add the FloppyPIO at octal 1560-1567
	deviceManager.AddDevice(DeviceType::FloppyPIO, 0);
}
