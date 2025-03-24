/**************************************************************************
** ND BUS DEVICES INTERFACE DEFINITIONS                                  **
**                                                                       **
**                                                                       **
** Shared:                                                               **
**   DeviceManager - Handles interaction between ND BUS and devices      **
**                                                                       **
** Generic:                                                              **
**   NDDevice - Base class for all bus devices                           **
**                                                                       **
** Specfic:                                                              **
**   Papertape reader                                                    **
**   Floppy PIO                                                          **
**   Floppy DMA                                                          **
**                                                                       **
**   SMD HardDrive (TBD)                                                 **
**                                                                       **
**                                                                       **
** Last reviewed: 22-MAR-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

#ifndef NDDEVICES_H
#define NDDEVICES_H

#include <memory>
#include <vector>
#include <iostream>
#include <string>

// Enable/Disable interface debugging for devices

#define DEBUG_PT // Papertape
#define DEBUG_FLOPPY_PIO   
#define DEBUG_FLOPPY_DMA 

#define DEBUG_DATATRANSFER_PIO // uncomment to remove datatransfer debug for PIO
#define DEBUG_DETAIL //uncomment to remove detailed debugging
#define DEBUG_INTERRUPT  // uncomment to remove INTERRUPT and IDENT debugging

enum class DeviceType
{
    PaperTape,
    FloppyPIO,
    FloppyDMA
};

#define MAX_IO_DELAYS 128

typedef bool (*IODelayedDelegate)(void *context, int param);

struct DelayedIoInfo
{
    int delayTicks;
    IODelayedDelegate callback;
    void *context;
    int parameter;
    uint8_t level;

    DelayedIoInfo(int ticks, IODelayedDelegate cb, void *ctx, int param, uint8_t irq)
        : delayTicks(ticks), callback(cb), context(ctx), parameter(param), level(irq) {}
};

#define IODELAY_TERMINAL 1000
#define IODELAY_FLOPPY 3000
#define IODELAY_HDD 100
#define IODELAY_HDD_SMD 100
#define IODELAY_SLOW 100 // Unknown device, maybe papertape ?
#define IODELAY_SCSI_SHORT 100
#define IODELAY_SCSI_TIMEOUT 0xFFFF

class NDDevice
{
protected:
    uint32_t startAddress = 0;
    uint32_t endAddress = 0;
    uint16_t interruptBits = 0;
    uint16_t InterruptLevel = 0; // Default interrupt level
    uint16_t IdentCode = 0;      // Identcode for this device
    

    std::vector<DelayedIoInfo> IODelays;

    void QueueIODelay(uint16_t ticks, IODelayedDelegate cb, int param, uint8_t irqlevel)
    {
        IODelays.emplace_back(ticks, cb, this, param, irqlevel);
    }

    void TickIODelay()
    {
        for (auto it = IODelays.begin(); it != IODelays.end();)
        {
            it->delayTicks--;
            if (it->delayTicks <= 0)
            {                
                bool triggered = it->callback(it->context, it->parameter);

                printf("Callback LVL[%d] PARAM[%d] Returned %d!!\r\n", it->level, it->parameter, triggered);

                if (triggered && it->level > 0)
                    GenerateInterrupt(it->level);

                it = IODelays.erase(it);
                return;
            }
            else
            {
                ++it;
            }
        }
    }


    void ClearInterrupt(uint16_t level)
    {
        if ((level >= 10) && (level <= 13))			
        {
            if ((interruptBits & 1<<level) != 0)
            {
                printf("Clearing interrupt at level %d\r\n",level);            
                interruptBits &= ~(1 << level);
            }
        }
    }

    void GenerateInterrupt(uint16_t level)
    {
        if ((level >= 10) && (level <= 13))			
        {
            if ((interruptBits & 1<<level) == 0)
            {
                printf("Generating interrupt at level %d\r\n",level);
                interruptBits |= 1<<level;
            }
        }
    }

    void SetInterruptStatus(bool active)
    {
        SetInterruptStatus(active, InterruptLevel);
    }

    void SetInterruptStatus(bool active, uint16_t level)
    {
        if (active)
            GenerateInterrupt(level);
        else
            ClearInterrupt(level);
    }

public:
    NDDevice(uint8_t thumbweel)
    {
    }

    virtual ~NDDevice() = default;

    virtual void Reset() = 0;
    virtual uint16_t Tick() = 0; // Every cpu tick this is called. Returns the interruptBits 

    // Returns true if 'address' is within [startAddress, endAddress].
    bool IsInAddress(uint32_t address) const
    {
        return (address >= startAddress && address <= endAddress);
    }

    // Returns 'address' offset relative to 'startAddress'.
    uint32_t RegisterAddress(uint32_t address) const
    {
        return address - startAddress;
    }

    virtual uint16_t Read(uint32_t address) = 0;
    virtual void Write(uint32_t address, uint16_t value) = 0;

    virtual uint16_t IDENT(uint16_t level) = 0;

    // Read 16 bits from file, big endian style 
    int32_t ReadWord(FILE *f)
    {
        int16_t hi = getc(f);
        if (hi < 0)
            return -1;
        hi = hi & 0xFF;

        int16_t lo = getc(f);
        if (lo < 0)
            return -1;
        lo = lo & 0xFF;

        return hi << 8 | lo;
    }

    // Write 16 bits to file, big endian style 
    int32_t WriteWord(FILE *f, uint16_t data)
    {
        uint8_t hi = (data >>8) & 0xFF;
        uint8_t lo = data & 0xFF;

        if (putc(hi, f) == EOF) return -1;
        if (putc(lo, f) == EOF) return -1;

        return 0;
    }
};

class DeviceManager
{
private:
    struct DeviceInfo
    {
        std::unique_ptr<NDDevice> device;
    };

    std::vector<DeviceInfo> devices;

    // CreateDevice needs the thumbweel setting so the device can set up its internal settings (address, interruptlevel,identcode)
    std::unique_ptr<NDDevice> CreateDevice(DeviceType type, uint8_t thumbweel);

public:
    void MasterClear();
    void AddDevice(DeviceType type, uint8_t thumbweel);
    uint16_t Read(uint32_t address);
    void Write(uint32_t address, uint16_t value);
    uint16_t IDENT(uint16_t level);
    uint16_t Tick(void); // Every cpu tick this is called
};

class PaperTape : public NDDevice
{
public:
    PaperTape(uint8_t thumbweel);
    ~PaperTape();
    void Reset();
    uint16_t Tick();

    uint16_t Read(uint32_t address) override;
    void Write(uint32_t address, uint16_t value) override;
    uint16_t IDENT(uint16_t level);

private:
    enum class Registers
    {
        /// @brief Read data register (8 bit) - 0400
        ReadDataRegister,

        /// @brief Write data buffer - 0401
        WriteDataBuffer,

        /// @brief Read status register - 0402
        ReadStatusRegister,

        /// @brief Write control register paper tape reader (bit 2 == Activate) - 0403
        WriteControlWord
    };

    // A union for interpreting the 16-bit control word
    union ControlWord
    {
        uint16_t raw;
        struct
        {
            unsigned interruptEnabled : 1; // Bit 0
            unsigned notUsed1 : 1;         // Bit 1
            unsigned readActive : 1;       // Bit 2
            // Expand or rename bits as you need ...
            unsigned readyForTransfer : 1; // Bit 3
            unsigned deviceClear : 1;      // Bit 4
            unsigned notUsed5 : 1;         // Bit 5
            unsigned notUsed6 : 1;         // Bit 6
            unsigned notUsed7 : 1;         // Bit 7
            unsigned notUsed8 : 1;         // Bit 8
            unsigned notUsed9 : 1;         // Bit 9
            unsigned notUsed10 : 1;        // Bit 10
            unsigned notUsed11 : 1;        // Bit 11
            unsigned notUsed12 : 1;        // Bit 12
            unsigned notUsed13 : 1;        // Bit 13
            unsigned notUsed14 : 1;        // Bit 14
            unsigned notUsed15 : 1;        // Bit 15
        } bits;
    };

    ControlWord controlWord{};

    union StatusRegister
    {
        uint16_t raw;
        struct
        {
            unsigned interruptEnabled : 1; // Bit 0
            unsigned notUsed1 : 1;         // Bit 1
            unsigned readActive : 1;       // Bit 2
            // Expand or rename bits as you need ...
            unsigned readyForTransfer : 1; // Bit 3
            unsigned notUsed4 : 1;         // Bit 4
            unsigned notUsed5 : 1;         // Bit 5
            unsigned notUsed6 : 1;         // Bit 6
            unsigned notUsed7 : 1;         // Bit 7
            unsigned notUsed8 : 1;         // Bit 8
            unsigned notUsed9 : 1;         // Bit 9
            unsigned notUsed10 : 1;        // Bit 10
            unsigned notUsed11 : 1;        // Bit 11
            unsigned notUsed12 : 1;        // Bit 12
            unsigned notUsed13 : 1;        // Bit 13
            unsigned notUsed14 : 1;        // Bit 14
            unsigned notUsed15 : 1;        // Bit 15
        } bits;
    };

    StatusRegister statusRegister{};

    uint8_t characterBuffer;

    FILE *papertapeFile;
    // char *paptertapeName;
    std::string papertapeName;
};

class FloppyPIO : public NDDevice
{
public:
    FloppyPIO(uint8_t thumbwheel);
    void Reset();
    uint16_t Tick();

    uint16_t Read(uint32_t address) override;
    void Write(uint32_t address, uint16_t value) override;
    uint16_t IDENT(uint16_t level);

    // Callback
    bool ReadEnd(int drive);
    bool RecalibrateEnd(int drive);
    bool SeekEnd(int drive);

    	
	
private:
    enum class Registers
    {
        // IOX +0: Read one 16-bit word from the interface buffer
        ReadDataBuffer = 0,

        // IOX +1: Write one 16-bit word to the interface buffer
        WriteDataBuffer = 1,

        // IOX +2: Read Status Register No. 1 (RSR1)
        ReadStatusRegister1 = 2,

        // IOX +3: Write Control Word (WCWD)
        WriteControlWord = 3,

        // IOX +4: Read Status Register No. 2 (RSR2)
        ReadStatusRegister2 = 4,

        // IOX +5: Write Drive Address / Write Difference
        WriteDriveAddress = 5,

        // IOX +6: Read test
        ReadTestData = 6,

        // IOX +7: Write Sector / Write Test Byte
        WriteSector = 7

    };

    enum class DriveCommand
    {
        FormatTrack = 0,
        WriteData,
        WriteDeletedData,
        ReadID,
        ReadData,
        Seek,
        Recalibrate,
        ControlReset,
        None
    };

    void ExecuteGo(DriveCommand command);
    void ClearAllErrorFlags();

    // Array to hold information about deleted sectors - so that testprogram can validate driver
    bool DeletedSector[100][100];

    void SetSectorAsDeleted(int sector, int track, bool flag = true)
	{
		// TODO: Implement. Problem: There is no room in the image file on disk to store this information
		// Temp solution: Write 0xFFFF to the sector. But then flag the sector as deleted in this temporary array

		// Hacketiy hackety hack
		DeletedSector[sector][track] = flag;
	}


	bool SectorIsDeleted(int sector, int track)
	{
		// Hacketiy hackety hack
		return DeletedSector[sector][track];
	}


    DriveCommand command;

    FILE *floppyFile;
    std::string floppyName;

    const int BUFFER_MAX = 1023;

    // uint16_t DataBuffer[BUFFER_MAX+1]; // Example size
    uint16_t DataBuffer[1024];

    int16_t loadDriveAddress;

    uint16_t sector;
    uint16_t track;

    uint16_t bufferPointer=0;
    int selectedDrive;

    int bytes_pr_sector = 0;
    int sectors_pr_track = 0;
    const int max_tracks = 77; // Track 0 to 76
    uint8_t testByte = 0;
    bool sectorAutoIncrement;
    int testmodeByte = 0;
    bool deletedRecord = 0;

    // 16-bit Read Status Register 1
    union ReadStatusRegister1
    {
        uint16_t raw;
        struct
        {
            unsigned notUsed : 1;                // Bit 0
            unsigned interruptEnabled : 1;       // Bit 1
            unsigned deviceBusy : 1;             // Bit 2
            unsigned deviceReadyForTransfer : 1; // Bit 3
            unsigned inclusiveOrBitsInReg2 : 1;  // Bit 4 (Error indication; status reg 2 must be read)
            unsigned deletedRecord : 1;           // Bit 5 (Sector had delete data address mark)
            unsigned readWriteComplete : 1;      // Bit 6 (Read or write operation completed)
            unsigned seekComplete : 1;           // Bit 7 (Seek or recalibration completed)
            unsigned timeOut : 1;                // Bit 8 (Approximately 1.5 seconds timeout)
            unsigned notUsed9 : 1;               // Bit 9
            unsigned notUsed10 : 1;              // Bit 10
            unsigned notUsed11 : 1;              // Bit 11
            unsigned notUsed12 : 1;              // Bit 12
            unsigned notUsed13 : 1;              // Bit 13
            unsigned notUsed14 : 1;              // Bit 14
            unsigned notUsed15 : 1;              // Bit 15
        } bits;
    };

    ReadStatusRegister1 RSR1;

    // A union for interpreting the 16-bit Write Control Word (WCWD)
    union WriteControlWord
    {
        uint16_t raw;
        struct
        {
            unsigned notUsed0 : 1;                    // Bit 0
            unsigned enableInterrupt : 1;             // Bit 1
            unsigned autoload : 1;                    // Bit 2
            unsigned testMode : 1;                    // Bit 3 (See IOX RTST and IOX WSCT)
            unsigned deviceClear : 1;                 // Bit 4 (Selected drive is deselected)
            unsigned clearInterfaceBufferAddress : 1; // Bit 5
            unsigned enableTimeout : 1;               // Bit 6
            unsigned notUsed7 : 1;                    // Bit 7
            // The following bits are commands to the floppy disk. These are the only control bits that generate device busy and give interrupt (NB: With the exception of bit 15 - control reset)
            unsigned formatTrack : 1;      // Bit 8
            unsigned writeData : 1;        // Bit 9
            unsigned writeDeletedData : 1; // Bit 10
            unsigned readID : 1;           // Bit 11
            unsigned readData : 1;         // Bit 12
            unsigned seek : 1;             // Bit 13
            unsigned recalibrate : 1;      // Bit 14
            unsigned controlReset : 1;     // Bit 15
        } bits;
    };

    WriteControlWord WCWD;

    // A union for interpreting the 16-bit Read Status Register 2
    union ReadStatusRegister2
    {
        uint16_t raw;
        struct
        {
            unsigned notUsed0 : 1;      // Bit 0
            unsigned notUsed1 : 1;      // Bit 1
            unsigned notUsed2 : 1;      // Bit 2
            unsigned notUsed3 : 1;      // Bit 3
            unsigned notUsed4 : 1;      // Bit 4
            unsigned notUsed5 : 1;      // Bit 5
            unsigned notUsed6 : 1;      // Bit 6
            unsigned notUsed7 : 1;      // Bit 7
            unsigned driveNotReady : 1; // Bit 8 (Drive not powered, door open, diskette improperly installed, or invalid address)
            unsigned writeProtect : 1;  // Bit 9 (Attempted write on write-protected diskette)
            unsigned notUsed10 : 1;     // Bit 10
            unsigned sectorMissing : 1; // Bit 11 (Sector or data/ID field address mark not located)
            unsigned crcError : 1;      // Bit 12 (CRC Error)
            unsigned notUsed13 : 1;     // Bit 13
            unsigned dataOverrun : 1;   // Bit 14 (Data byte lost during communication)
            unsigned notUsed15 : 1;     // Bit 15
        } bits;
    };

    ReadStatusRegister2 RSR2;

    // A union for interpreting the 16-bit Write Drive Address (WDAD) word
    union WriteDriveAddress
    {
        uint16_t raw;
        struct
        {
            unsigned modeBit : 1; // Bit 0 (1 = Write Drive Address, 0 = Write Difference)

            // Shared unused bits (1-7)
            unsigned notUsed1 : 1; // Bit 1
            unsigned notUsed2 : 1; // Bit 2
            unsigned notUsed3 : 1; // Bit 3
            unsigned notUsed4 : 1; // Bit 4
            unsigned notUsed5 : 1; // Bit 5
            unsigned notUsed6 : 1; // Bit 6
            unsigned notUsed7 : 1; // Bit 7

            // When modeBit = 1 (Write Drive Address)
            unsigned driveAddress : 3;   // Bits 8–10 (Unit number: 0, 1, or 2)
            unsigned deselectDrives : 1; // Bit 11
            unsigned notUsed12 : 1;      // Bit 12
            unsigned notUsed13 : 1;      // Bit 13
            unsigned formatSelect : 2;   // Bits 14–15 (Format)

            // When modeBit = 0 (Write Difference)
            // Bits 8–14 represent the track difference
            // Bit 15 is direction: 0 = out (lower track), 1 = in (higher track)
        } bits;
    };

    WriteDriveAddress WDAD;

    // A union for interpreting the 16-bit Write Sector (WSCT) word
    union WriteSector
    {
        uint16_t raw;
        struct
        {
            unsigned notUsed0 : 1; // Bit 0
            unsigned notUsed1 : 1; // Bit 1
            unsigned notUsed2 : 1; // Bit 2
            unsigned notUsed3 : 1; // Bit 3
            unsigned notUsed4 : 1; // Bit 4
            unsigned notUsed5 : 1; // Bit 5
            unsigned notUsed6 : 1; // Bit 6
            unsigned notUsed7 : 1; // Bit 7

            unsigned sectorNumber : 7;  // Bits 8–14 (Valid range depends on format; 0 must not be used)
            unsigned autoIncrement : 1; // Bit 15 (Auto-increment sector number after each read/write)
        } bits;
    };

    WriteSector WSCT;

    const uint8_t floppy_boot[388] = {
        0xb1, 0x8d, 0x0a, 0x30, 0x30, 0x36, 0x30, 0x30, 0x30, 0x8d, 0x0a, 0xb1, 0x36, 0xb4, 0x33, 0xb1,
        0x36, 0x21, 0x0c, 0x00, 0x00, 0xb3, 0xf1, 0x00, 0xb2, 0x03, 0xd2, 0x40, 0xa8, 0x00, 0xf1, 0xff,
        0x08, 0x1b, 0x40, 0x1a, 0xa8, 0x02, 0xa8, 0x03, 0xf3, 0x31, 0xa8, 0x1a, 0x48, 0x16, 0xcc, 0x69,
        0xf1, 0x00, 0xf2, 0x03, 0xc3, 0xb0, 0x68, 0x12, 0xb2, 0x03, 0xf3, 0x32, 0xa8, 0x11, 0xcc, 0x4d,
        0x68, 0x0e, 0xb3, 0xfc, 0xf3, 0x00, 0x4c, 0x00, 0x0c, 0x00, 0xcd, 0x07, 0xcc, 0x7d, 0xb3, 0xfc,
        0xd0, 0x05, 0xd0, 0x0d, 0xa8, 0x23, 0x00, 0x00, 0x00, 0x11, 0x00, 0x05, 0x00, 0x02, 0x48, 0x1d,
        0xe8, 0xc3, 0xf2, 0x0d, 0xb8, 0x14, 0xf2, 0x0a, 0xb8, 0x12, 0xf2, 0x45, 0xb8, 0x10, 0xf2, 0x52,
        0xb8, 0x0e, 0xb8, 0x0d, 0xf2, 0x4f, 0xb8, 0x0b, 0xf2, 0x52, 0xb8, 0x09, 0xf2, 0x20, 0xb8, 0x07,
        0xcc, 0x7e, 0xb8, 0x05, 0xf2, 0x20, 0xb8, 0x03, 0xd2, 0x08, 0xa8, 0xc6, 0xe8, 0xc6, 0xfa, 0x9d,
        0xa8, 0xfe, 0xcc, 0x75, 0xe8, 0xc5, 0xcc, 0x62, 0x48, 0x04, 0xf1, 0xfb, 0x08, 0x49, 0xf1, 0x30,
        0xeb, 0x73, 0x48, 0x4e, 0xeb, 0x75, 0x00, 0x00, 0x00, 0x00, 0xeb, 0x72, 0xfa, 0x9d, 0xa8, 0xfe,
        0xfa, 0xa5, 0xa8, 0x0a, 0x08, 0x07, 0xeb, 0x74, 0xfa, 0x45, 0xa8, 0xf2, 0x08, 0x04, 0xf3, 0x33,
        0xa8, 0xcf, 0x00, 0x00, 0x00, 0x00, 0x48, 0x3d, 0xeb, 0x73, 0xeb, 0x72, 0xfa, 0x9d, 0xa8, 0xfe,
        0x48, 0x39, 0xeb, 0x77, 0x48, 0x38, 0xeb, 0x73, 0xeb, 0x72, 0xfa, 0x15, 0xa8, 0xfe, 0xfa, 0x25,
        0xa8, 0x20, 0xf1, 0x20, 0xeb, 0x73, 0xb8, 0x32, 0xf2, 0x21, 0x70, 0x2e, 0xc4, 0x2e, 0xa8, 0x04,
        0xcc, 0x4d, 0x08, 0x16, 0xa8, 0xf9, 0xb8, 0x1d, 0xcc, 0x6b, 0xb8, 0x1b, 0xcc, 0x6f, 0xcc, 0x41,
        0xb8, 0x18, 0xcc, 0x29, 0x09, 0x00, 0xcd, 0x03, 0xcc, 0x87, 0xc0, 0x07, 0xa8, 0xfa, 0xb8, 0x11,
        0xcd, 0x8d, 0xb3, 0x07, 0xeb, 0x70, 0x70, 0x19, 0xc0, 0x05, 0xd2, 0x00, 0xaa, 0x01, 0x00, 0x00,
        0x08, 0xd1, 0xeb, 0x74, 0x08, 0xd0, 0x40, 0x04, 0xa8, 0xbb, 0xf3, 0x34, 0xa8, 0x99, 0x00, 0x00,
        0xeb, 0x70, 0xdd, 0x08, 0xcc, 0x6e, 0xeb, 0x70, 0x70, 0x08, 0xcb, 0x35, 0xcc, 0x62, 0xc0, 0x01,
        0x40, 0x00, 0x01, 0x00, 0x10, 0x00, 0x00, 0x7f, 0x00, 0xff, 0x10, 0x14, 0xcc, 0x41, 0x50, 0x13,
        0xeb, 0x70, 0x70, 0x12, 0xc4, 0x35, 0xa8, 0xfd, 0x08, 0x0c, 0x68, 0x0f, 0xb1, 0x07, 0x68, 0x0e,
        0xb0, 0x05, 0x60, 0x0c, 0xdc, 0x83, 0xcb, 0x29, 0xa8, 0xf4, 0x48, 0x03, 0x50, 0x02, 0xcc, 0x62,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x7f, 0x00, 0x30, 0x00, 0x08, 0x54, 0xd4, 0x00, 0x00,
        0xf1, 0x00, 0x00, 00};

    const size_t floppy_boot_length = sizeof(floppy_boot);
};

class FloppyDMA : public NDDevice
{
public:
    FloppyDMA(uint8_t thumbweel);
    void Reset();
    uint16_t Tick();

    uint16_t Read(uint32_t address) override;
    void Write(uint32_t address, uint16_t value) override;
    uint16_t IDENT(uint16_t level);
};

#endif // NDDEVICES_H
