/**************************************************************************
** ND BUS DEVICES INTERFACE IMPLEMENTATION                               **
**                                                                       **
**                                                                       **
** Shared:                                                               **
**   DeviceManager - Handles interaction between ND BUS and devices      **
**                                                                       **
** Specfic:                                                              **
**   Papertape reader                                                    **
**   Floppy PIO                                                          **
**                                                                       **
**   Floppy DMA (TBD)                                                    **
**   SMD HardDrive (TBD)                                                 **
**                                                                       **
**                                                                       **
** Last reviewed: 22-MAR-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

#include <iostream>
#include <vector>
#include <memory>
#include <string>
#include <map>
#include <string>
#include "NDDevices.h"

/************************************
 * Papertape reader                 *
 ************************************/

PaperTape::PaperTape(uint8_t thumbweel) : NDDevice(thumbweel)
{
    switch (thumbweel)
    {
    case 0:
        InterruptLevel = 12;
        IdentCode = 02; // octal 02
        startAddress = 0400;
        endAddress = 0403;
        break;
    case 1:
        InterruptLevel = 12;
        IdentCode = 022; // Octal 22
        startAddress = 0404;
        endAddress = 0407;
        break;
    default:
        throw std::runtime_error("Invalid Thumbweel value");
        break;
    }
    std::cout << "PaperTape object created." << std::endl;

    // paptertapeName = strdup("INSTRUCTION-B.BPUN"); // strdup creates a modifiable copy
    papertapeName = "INSTRUCTION-B.BPUN";
    if ((papertapeFile = fopen(papertapeName.c_str(), "r")) == 0)
    {
        printf("Unable to open file %s\r\n", papertapeName.c_str());
        return;
    }
}

void PaperTape::Reset()
{
    // Reset reader. Rewind paper
    if (papertapeFile > 0)
    {
        // fseek(papertapeFile,0,SEEK_SET);
        rewind(papertapeFile);
    }
}

uint16_t PaperTape::Tick()
{
    TickIODelay();
    return interruptBits;
}

PaperTape::~PaperTape()
{
    if (papertapeFile > 0)
    {
        fclose(papertapeFile);
        papertapeFile = 0;
    }
}

uint16_t PaperTape::Read(uint32_t address)
{
    uint16_t data = 0;
    Registers reg = (Registers)RegisterAddress(address);

    switch (reg)
    {
    case Registers::ReadDataRegister:
        statusRegister.bits.readyForTransfer = 0;
        data = characterBuffer;
        break;

    case Registers::ReadStatusRegister:
        data = statusRegister.raw;
        break;
    default:
#ifdef DEBUG_PT
        std::cout << "PaperTape read, invalid register address: " << address << std::endl;
#endif
    }

#ifdef DEBUG_PT
    std::cout << "PaperTape Reading from address: " << std::oct << address << " value: " << data << std::oct << std::endl;
#endif

    return data;
}

void PaperTape::Write(uint32_t address, uint16_t value)
{
#ifdef DEBUG_PT
    std::cout << "PaperTape Writing value: " << std::oct << value << " to address: " << std::oct << address << std::endl;
#endif

    Registers reg = (Registers)RegisterAddress(address);

    switch (reg)
    {
    case Registers::WriteDataBuffer:
        // WriteDataBuffer(value);
        // Only for PaperTapeWRITER
        break;

    case Registers::WriteControlWord: // WriteControlWord (trigger read of next byte if readActive is set)
        controlWord.raw = value;

        statusRegister.bits.interruptEnabled = controlWord.bits.interruptEnabled;
        statusRegister.bits.readActive = controlWord.bits.readActive;
        statusRegister.bits.readyForTransfer = controlWord.bits.readyForTransfer;

        if (controlWord.bits.deviceClear)
        {
            std::cout << "PaperTape DeviceClear " << std::endl;
            statusRegister.bits.readActive = 0;
            statusRegister.bits.readyForTransfer = 0;
            characterBuffer = 0x00;

            // Reset reader and its buffer - spool papertape back to start
        }

        SetInterruptStatus(statusRegister.bits.interruptEnabled && statusRegister.bits.readyForTransfer);

        if (statusRegister.bits.readActive)
        {
            statusRegister.bits.readyForTransfer = 0;

            // Try to Read from papertape

            int w = -1;

            if (papertapeFile == NULL)
            {
                printf("NO Papertape");
            }
            else
            {
                w = getc(papertapeFile) & 0377;
            }

            // if  read successfull
            if (w >= 0)
            {
                characterBuffer = w; //<== value from tape
                statusRegister.bits.readyForTransfer = 1;
            }
            else
            {
                printf("Papertape EOF");
            }

            statusRegister.bits.readActive = false;
        }

        SetInterruptStatus(statusRegister.bits.interruptEnabled && statusRegister.bits.readyForTransfer);
        break;
    default:
        std::cout << "PaperTape Write, invalid register address: " << std::oct << address << std::endl;
    }
}

uint16_t PaperTape::IDENT(uint16_t level)
{
    // Provide some default functionality or just return 0
    std::cout << "PaperTape::IDENT called with level " << level << std::endl;
    if ((interruptBits & 1 << level) != 0)
    {
        statusRegister.bits.interruptEnabled = false;
        SetInterruptStatus(false, level); // Clear interrupt on this level
        return IdentCode;
    }
    return 0;
}

/************************************
 * Floppy with PIO only             *
 ************************************/

FloppyPIO::FloppyPIO(uint8_t thumbweel) : NDDevice(thumbweel)
{
    switch (thumbweel)
    {
    case 0:
        InterruptLevel = 11;
        IdentCode = 021; // octal 021
        startAddress = 01560;
        endAddress = 01567;
        break;
    case 1:
        InterruptLevel = 11;
        IdentCode = 022; // Octal 022
        startAddress = 01570;
        endAddress = 01577;

        break;
    default:
        throw std::runtime_error("Invalid Thumbweel value");
        break;
    }
    std::cout << "FloppyPIO object created." << std::endl;

    floppyName = "FLOPPY.IMG";
    if ((floppyFile = fopen(floppyName.c_str(), "r")) == 0)
    {
        printf("Unable to open file %s\r\n", floppyName.c_str());
        return;
    }
}

void FloppyPIO::Reset()
{
    RSR1.bits.deviceReadyForTransfer = 1;

    bufferPointer = 0;
    testmodeByte = 0;
    interruptBits = 0;
    selectedDrive = -1;
}

uint16_t FloppyPIO::Tick()
{
    TickIODelay();
    return interruptBits;
}

uint16_t FloppyPIO::Read(uint32_t address)
{
    uint16_t data = 0;
    Registers reg = (Registers)RegisterAddress(address);

    switch (reg)
    {
    case Registers::ReadDataBuffer:
        data = DataBuffer[bufferPointer];
#ifdef DEBUG_DATATRANSFER_PIO
        printf("%o Read offset [%04X]= %04X\r\n", address, bufferPointer, data);
#endif
        bufferPointer = (bufferPointer + 1) & BUFFER_MAX;
        break;

    case Registers::ReadStatusRegister1:
        RSR1.bits.inclusiveOrBitsInReg2 = RSR2.raw > 0; // Set error flag if bits in reg2 is set
        data = RSR1.raw;

        // For testprogram to succeed, this 'magic' needs to be here
        {
            int w = bufferPointer;
            if ((w & (1 << 1)) && (w & (1 << 6)))
                data |= (1 << 9);
            if ((w & (1 << 1)) && (w & (1 << 7)))
                data |= (1 << 10);
            if ((w & (1 << 1)) && (w & (1 << 8)))
                data |= (1 << 11);
        }
        break;

    case Registers::ReadStatusRegister2:
        data = RSR2.raw;
        break;

    case Registers::ReadTestData:
        if (WCWD.bits.testMode)
        {
            int wbufptr = bufferPointer;
            uint16_t val = DataBuffer[wbufptr];

            if (testmodeByte > 0)
            {
                val = (val & 0xFF00) | testByte;
                DataBuffer[bufferPointer] = val;
                bufferPointer = (bufferPointer + 1) & BUFFER_MAX;
                testmodeByte = 0;
            }
            else
            {
                val = (val & 0x00FF) | (testByte << 8);
                DataBuffer[bufferPointer] = val;
                testmodeByte++;
            }
        }
        break;

    default:
        break;
    }

#ifdef DEBUG_FLOPPY_PIO
    if (reg != Registers::ReadDataBuffer)
    {
        std::cout << "Floppy PIO Reading from address: " << std::oct << address << " value: " << data << std::oct << std::endl;
    }
#endif

    return data;
}

void FloppyPIO::Write(uint32_t address, uint16_t value)
{
    Registers reg = (Registers)RegisterAddress(address);

#ifdef DEBUG_FLOPPY_PIO
    if (reg != Registers::WriteDataBuffer)
    {
        std::cout << "Floppy PIO Writing value: " << std::oct << value << " to address: " << std::oct << address << std::endl;
    }
#endif

    switch (reg)
    {
    case Registers::WriteDataBuffer:

#ifdef DEBUG_DATATRANSFER_PIO
        std::cout << "FloppyPIO: Write Buffer offset " << bufferPointer << " value = " << std::hex << value << std::endl;
#endif

        DataBuffer[bufferPointer] = value;
        bufferPointer = (bufferPointer + 1) & BUFFER_MAX;
        break;

    case Registers::WriteControlWord:
        WCWD.raw = value;

        RSR1.bits.interruptEnabled = WCWD.bits.enableInterrupt;

        if (WCWD.bits.autoload)
        {
            // HACK HACK HACK
            // Correct is to read track 0, sector 1
            // Check ND-11.015.01_Floppy_Disk_Controller_3027_May_1982_ocr.PDF physical page 64

            // FLO-MON (FLOppy-MONitor-2010F or newer) must be dumped to the diskette.

            track = 0;
            sector = 1;
            bufferPointer = 0;
            RSR1.bits.deviceReadyForTransfer = 1;

            for (int i = 0; i < floppy_boot_length; i++)
                DataBuffer[i] = floppy_boot[i];
        }

        if (WCWD.bits.deviceClear)
        {
            selectedDrive = -1;
            bufferPointer = 0;
            RSR1.bits.deviceReadyForTransfer = 1;
            ClearAllErrorFlags();
        }

        if (WCWD.bits.clearInterfaceBufferAddress)
        {
            bufferPointer = 0;
            RSR1.bits.deviceReadyForTransfer = 1;
            // Optionally reset buffer and related state
        }

        if ((value & 0xFF00) != 0)
        {
            RSR1.bits.deviceBusy = 1;
            int tmp = (value >> 8) & 0xFF;
            for (int i = 0; i < 8; i++)
            {
                if (tmp & (1 << i))
                    command = static_cast<DriveCommand>(i);
            }
            ExecuteGo(command);
        }

        SetInterruptStatus(RSR1.bits.interruptEnabled && RSR1.bits.deviceReadyForTransfer);
        break;

    case Registers::WriteDriveAddress:
        WDAD.raw = value;

        if (WDAD.bits.modeBit) // Write Drive Address
        {
            selectedDrive = WDAD.bits.driveAddress;
            if (WDAD.bits.deselectDrives)
            {
                // do what ?
                selectedDrive = -1;
            }

            switch (WDAD.bits.formatSelect)
            {
            case 0:
            case 1:
                bytes_pr_sector = 128;
                sectors_pr_track = 26;
                break;
            case 2:
                bytes_pr_sector = 256;
                sectors_pr_track = 15;
                break;
            case 3:
                bytes_pr_sector = 512;
                sectors_pr_track = 8;
                break;
            }
        }
        else
        {
            // Bit 0 = 0, Write Difference
            int difference = (value >> 8) & 0x7F; // 7 bits difference setting
            int move_in = (value >> 15) & 0x01;   // 'in' means "Higher address"

            if (move_in)
            {
                // Move "IN" to a higher track address
                track += difference;
            }
            else
            {
                // Move "OUT" to a lower track address
                track -= difference;
            }

            // Limits!
            if (track < 0)
                track = 0;
            if (track > 76)
                track = 76;
        }
        break;

    case Registers::WriteSector:
        if (WCWD.bits.testMode)
        {
            testByte = ((value >> 8) & 0xFF);
        }
        else
        {
            // Bit 8-14 Setor to be used in subsequent Read/write command
            //
            // Sector ranges (octal)
            // 1-32 for UBM 3740
            // 1-17 for IBM 3600
            // 1-10 for IBM System 32I1
            // Sector 0 must not be used
            sector = (value >> 8) & 0x7F;

            // If this bit is true the sector register is automatically incremented after each read/write command.
            // NB! This autoincrement is not valid past the last sector of a track
            sectorAutoIncrement = (value >> 15) != 0;
        }

#ifdef DEBUG_DETAIL
        std::cout << "WriteSector: Sector = " << std::dec << sector << " AutoIncrement = " << sectorAutoIncrement << std::endl;
#endif
        break;

    default:
        break;
    }
}

uint16_t FloppyPIO::IDENT(uint16_t level)
{
#ifdef DEBUG_INTERRUPT
    // Provide some default functionality or just return 0
    printf("[%x] ", interruptBits);

    // Provide some default functionality or just return 0
    printf("FloppyPIO::IDENT called with level %d\r\n", level);
#endif

    bool HasInterrupt = (interruptBits & (1 << level)) != 0;
    if (HasInterrupt)
    {
        // statusRegister.bits.interruptEnabled = false;
        RSR1.bits.interruptEnabled = 0;
        SetInterruptStatus(false, level); // Clear interrupt on this level

#ifdef DEBUG_INTERRUPT
        printf("FloppyPIO::IDENT found %o\r\n", IdentCode);
#endif

        return IdentCode;
    }
    else
    {
        printf("WTF %x %x\r\n", interruptBits, 1 << level);
    }

    return 0;
}

//
// Callbacks used by ExecuteGO
//

static bool FloppyPIO_ReadEndThunk(void *ctx, int param)
{
    return static_cast<FloppyPIO *>(ctx)->ReadEnd(param);
}

static bool FloppyPIO_RecalibrateThunk(void *ctx, int param)
{
    return static_cast<FloppyPIO *>(ctx)->RecalibrateEnd(param);
}

static bool FloppyPIO_SeekEndThunk(void *ctx, int param)
{
    return static_cast<FloppyPIO *>(ctx)->SeekEnd(param);
}

bool FloppyPIO::ReadEnd(int drive)
{
    RSR1.bits.deviceBusy = 0;
    RSR1.bits.deviceReadyForTransfer = 1;
    RSR1.bits.readWriteComplete = 1;
    if (sectorAutoIncrement)
    {
        if (sector <= sectors_pr_track)
            sector++;
    }

    if (RSR1.bits.interruptEnabled)
        return true;
    return false;
}

bool FloppyPIO::RecalibrateEnd(int drive)
{
    RSR1.bits.deviceBusy = 0;
    RSR1.bits.deviceReadyForTransfer = 1;
    RSR1.bits.seekComplete = 1;

    if (RSR1.bits.interruptEnabled)
        return true;

    return false;
}

bool FloppyPIO::SeekEnd(int drive)
{
    RSR1.bits.deviceBusy = 0;
    RSR1.bits.deviceReadyForTransfer = 1;
    RSR1.bits.seekComplete = 1;

    if (RSR1.bits.interruptEnabled)
        return true;
    return false;
}

void FloppyPIO::ClearAllErrorFlags()
{
    // Clear all error flags
    // RSR2.bits.sectorMissing = 0;
    // RSR2.bits.writeProtect = 0;
    // RSR2.bits.driveNotReady = 0;
    RSR2.raw = 0;
}

void FloppyPIO::ExecuteGo(DriveCommand command)
{
    ClearAllErrorFlags();

    int data;
    int transferWordCount = bytes_pr_sector >> 1;
    int wordsRead = 0;

    RSR1.bits.deviceReadyForTransfer = 0;
    RSR1.bits.readWriteComplete = 0;
    RSR1.bits.seekComplete = 0;
    RSR1.bits.deletedRecord = 0;

    RSR2.bits.writeProtect = false;

    // Validat that we have a selected drive, that the drive is ready and we have valid inputdata.
    if (sector <= 0)
        sector = 1;

    if (sector > sectors_pr_track)
    {
        RSR2.bits.sectorMissing = 1;
        RSR1.bits.deviceReadyForTransfer = 1;
        RSR1.bits.deviceBusy = 0;
        return;
    }

    uint8_t unit = (uint8_t)selectedDrive;

    // TODO: Implement support for multiple drives
    // IODevice* device = GetIODevice(unit);

    if (floppyFile < 0 || selectedDrive < 0)
    {
        RSR2.bits.driveNotReady = 1;
        RSR1.bits.deviceBusy = 0;
        return;
    }

    // Check if file is write-protected
    // RSR2.bits.writeProtect = device->read_only;

    // Ok, seems like all is ok - now calculate file offset for read/write operations
    int position = ((sector - 1) * bytes_pr_sector) + (track * bytes_pr_sector * sectors_pr_track);

#ifdef DEBUG_FLOPPY_PIO
    std::cout << "Executing command " << (uint8_t)command << " on drive " << selectedDrive
              << " position " << position << " [Sector " << sector << " Track " << track
              << " DataBufAddr " << bufferPointer << "]\n";
#endif

    switch (command)
    {
    case DriveCommand::FormatTrack:
        // The Format Track command provides the function of writing an entire track of information. (Refer to Figure 11 1.3.2.)
        // When executing this command, the Fortnatter provides all gaps, address marks, and CRC bytes while the interface
        // provides the 4 ID bytes and all data bytes for each record (under Formatter transfer control).

        // NOTE! Not tested!!!

#ifdef DEBUG_FLOPPY_PIO
        printf("Starting FormatTrack \r\n");
#endif
        if (RSR2.bits.writeProtect)
        {
            RSR1.bits.deviceBusy = 0;
            RSR1.bits.deviceReadyForTransfer = 1;
            return;
        }

        // Move to sector 1 on the track
        position = (1 * (bytes_pr_sector)) + (track * bytes_pr_sector * sectors_pr_track);

        if (fseek(floppyFile, position, SEEK_SET) != 0)
        {
#ifdef DEBUG_FLOPPY_PIO
            printf("Floppy SEEK in FormatTrack to %d FAILED\r\n", position);
#endif
            RSR2.bits.sectorMissing = 1;
            RSR1.bits.deviceBusy = 0;
            RSR1.bits.deviceReadyForTransfer = 1;
            return;
        }

        data = 0xAAFF; // What is the correct data to write to a newly formatted track??

        // Now write "dummy" data to all sectors
        for (int s = 1; s <= sectors_pr_track; s++)
        {
            transferWordCount = bytes_pr_sector >> 1;
            while (transferWordCount > 0)
            {

                if (!WriteWord(floppyFile, (uint16_t)data))
                {
#ifdef DEBUG_FLOPPY_PIO
                    printf("IO error during [FORMAT] Track=%d, Sector=%d\r\n", track, sector);
#endif
                    RSR2.bits.driveNotReady = 1;
                    RSR1.bits.deviceBusy = 0;
                    return;
                }

                transferWordCount--;
            }

            // Remove potentially "deleted" flags
            SetSectorAsDeleted(s, track, false);
        }

        QueueIODelay(IODELAY_FLOPPY, FloppyPIO_ReadEndThunk, unit, InterruptLevel);
        break;

    case DriveCommand::WriteData:
#ifdef DEBUG_FLOPPY_PIO
        printf("Starting WriteData \r\n");
#endif
        if (RSR2.bits.writeProtect)
        {
            RSR1.bits.deviceBusy = 0;
            RSR1.bits.deviceReadyForTransfer = 1;
            return;
        }

        if (fseek(floppyFile, position, SEEK_SET) != 0)
        {
            // Logger.Log($"Unable to seek floppy", Logger.LogLevel.Device);
#ifdef DEBUG_FLOPPY_PIO
            printf("Floppy SEEK in WRITE to %d FAILED\r\n", position);
#endif
            RSR2.bits.sectorMissing = 1;
            RSR1.bits.deviceBusy = 0;
            return;
        }

        // Read sector data
        while (transferWordCount > 0)
        {

            data = DataBuffer[bufferPointer];
            bufferPointer = (bufferPointer + 1) & BUFFER_MAX;

            if (!WriteWord(floppyFile, (uint16_t)data))
            {
#ifdef DEBUG_FLOPPY_PIO
                printf("IO ERROR in WRITE at %d\r\n", position);
#endif
                RSR2.bits.driveNotReady = 1;
                RSR1.bits.deviceBusy = 0;
                return;
            }

            wordsRead++;
            transferWordCount--;
        }

        // Remove flag that sets the sector as deleted
        SetSectorAsDeleted(sector, track, false);

#ifdef DEBUG_DETAIL
        printf("FloppyPIO: Write %d WORDs\r\n", wordsRead);
#endif

        QueueIODelay(IODELAY_FLOPPY, FloppyPIO_ReadEndThunk, unit, InterruptLevel);
        break;

    case DriveCommand::WriteDeletedData:
        // The WRITE DELETED DATA command is operationally identical to the WRITE DATA command,
        // but results in the Formatter writing a Deleted Data Address Mark byte in front of the data field.

#ifdef DEBUG_FLOPPY_PIO
        printf("Starting WriteDeletedData \r\n");
#endif
        if (RSR2.bits.writeProtect)
        {
            RSR1.bits.deviceBusy = 0;
            RSR1.bits.deviceReadyForTransfer = 1;
            return;
        }

        SetSectorAsDeleted(sector, track, true);

        if (fseek(floppyFile, position, SEEK_SET) != 0)
        {
            // Logger.Log($"Unable to seek floppy", Logger.LogLevel.Device);
#ifdef DEBUG_FLOPPY_PIO
            printf("Floppy SEEK in WriteDeletedData to %d FAILED\r\n", position);
#endif
            RSR2.bits.sectorMissing = 1;
            RSR1.bits.deviceBusy = 0;
            return;
        }

        // Read sector data
        while (transferWordCount > 0)
        {

            data = DataBuffer[bufferPointer];
            bufferPointer = (bufferPointer + 1) & BUFFER_MAX;

            if (!WriteWord(floppyFile, (uint16_t)data))
            {
#ifdef DEBUG_FLOPPY_PIO
                printf("IO ERROR in WriteDeletedData at %d\r\n", position);
#endif
                RSR2.bits.driveNotReady = 1;
                RSR1.bits.deviceBusy = 0;
                return;
            }

            wordsRead++;
            transferWordCount--;
        }
        

        QueueIODelay(IODELAY_FLOPPY, FloppyPIO_ReadEndThunk, unit, InterruptLevel);
        break;

    case DriveCommand::ReadID:
#ifdef DEBUG_FLOPPY_PIO
        printf("Starting ReadID \r\n");
#endif

        // ND-11.012.01 Floppy Disk System.PDF - Page III-6-2
        // The READ ID command causes the Formatter to transfer the first ID field encountered by the Read/Write head from the selected drive.
        // The four bytes of data contained in the ID field are transferred to the interface via the X-fer bus.
        // The contents of the bytes are shown below, in the order of transfer.
        //
        // Byte no	Content
        // -------	----------------------------------------------
        //  00		Track address represented in binary (0-76)
        //  01		Binary zero
        //  02		Sector address represented in binary (1-8)
        //  03      Hex 02

        if (SectorIsDeleted(sector, track))          
        {
            DataBuffer[0] = 0xFF00;
            DataBuffer[1] = 0xFF02;
        }
        else
        {
            DataBuffer[0] = (uint16_t)((track << 8) | 0x00);
            DataBuffer[1] = (uint16_t)((sector << 8)); // | (0x02)); // Removed 0x02 in position 3 as FLOPPY-FU-1986F complained then
        }

        bufferPointer = 0;

        QueueIODelay(IODELAY_FLOPPY, FloppyPIO_ReadEndThunk, unit, InterruptLevel);
        break;

    case DriveCommand::ReadData:
#ifdef DEBUG_FLOPPY_PIO
        printf("Starting ReadData, transferWordCount=%d, position=%d\r\n", transferWordCount, position);
#endif
        // if (!StreamSeek(unit, position))
        if (fseek(floppyFile, position, SEEK_SET) != 0)
        {
            // Logger.Log($"Unable to seek floppy", Logger.LogLevel.Device);
#ifdef DEBUG_FLOPPY_PIO
            printf("Floppy SEEK in READ to %d FAILED\r\n", position);
#endif
            RSR2.bits.sectorMissing = 1;
            RSR1.bits.deviceBusy = 0;
            return;
        }

        if (sector <= 0)
        {
            RSR2.bits.sectorMissing = 1;
            RSR1.bits.deviceBusy = 0;
            return;
        }

        // Set flag if sector is deleted, but still read sector data
        if (SectorIsDeleted(sector, track))        
        {
            RSR1.bits.deletedRecord = 1;            
        }

        // Read sector data
        while (transferWordCount > 0)
        {
            data = ReadWord(floppyFile);

            if (data == -1)
            {

#ifdef DEBUG_FLOPPY_PIO
                printf("IO ERROR in READ at %d FAILED\r\n", position);
#endif
                RSR2.bits.driveNotReady = 1;
                RSR1.bits.deviceBusy = 0;
                return;
            }

            wordsRead++;
            DataBuffer[bufferPointer] = (uint16_t)data;
            bufferPointer = (bufferPointer + 1) & BUFFER_MAX;

            transferWordCount--;
        }

#ifdef DEBUG_DETAIL
        printf("FloppyPIO: Read %d WORDs\r\n", wordsRead);
#endif
        QueueIODelay(IODELAY_FLOPPY, FloppyPIO_ReadEndThunk, unit, InterruptLevel);
        break;

    case DriveCommand::Seek:

        if (sector <= 0)
        {
            RSR2.bits.sectorMissing = 1;
        }

        if (fseek(floppyFile, position, SEEK_SET) != 0)
        {
            printf("Floppy SEEK to %d FAILED\r\n", position);

            RSR2.bits.sectorMissing = 1;
            RSR1.bits.deviceBusy = 0;
            return;
        }

        QueueIODelay(IODELAY_FLOPPY, FloppyPIO_SeekEndThunk, unit, InterruptLevel);
        break;

    case DriveCommand::Recalibrate:
        printf("Starting Recalibrate\r\n");
        track = 0;
        sector = 1;

        QueueIODelay(IODELAY_FLOPPY, FloppyPIO_RecalibrateThunk, unit, InterruptLevel);
        break;

    case DriveCommand::ControlReset:    
        RSR1.bits.deviceBusy = 0;

        //NO INTERRUPT acording to documentatation
        break;

    default:
        break;
    }
}

/* 

TEST RESULTS: FLOPPY-FU-1986F.BPUN

FLOPPY FUNCTION TEST
IS IT A N-100 SYSTEM ? :Y
DEVICE NO. (1560 OR 1570):1560
DO YOU KNOW FORMAT  NUMBERS : Y
FORMAT (0,1 OR 2): 2
UNIT NO (0,1 OR 2): 0
TEST 1 : INTERFACE BUFFER TEST
TEST 2: FORMAT DECODER TEST
TEST 3 : TEST MODE TEST
TEST 3B, BOOTSTRAP PROM TEST N-100.
TEST 4 : DISK OPERATIONS TEST
DO YOU WANT TO RUN TESTS IN LOOP ?

*/

/************************************
 *Floppy with DMA                   *
 ************************************/

FloppyDMA::FloppyDMA(uint8_t thumbweel) : NDDevice(thumbweel)
{
    switch (thumbweel)
    {
    case 0:
        InterruptLevel = 11;
        IdentCode = 021; // octal 021
        startAddress = 01560;
        endAddress = 01567;
        break;
    case 1:
        InterruptLevel = 11;
        IdentCode = 022; // Octal 022
        startAddress = 01570;
        endAddress = 01577;

        break;
    default:
        throw std::runtime_error("Invalid Thumbweel value");
        break;
    }

    std::cout << "FloppyDMA object created." << std::endl;
}

void FloppyDMA::Reset()
{
}

uint16_t FloppyDMA::Tick()
{
    TickIODelay();
    return interruptBits;
}

uint16_t FloppyDMA::Read(uint32_t address)
{
    std::cout << "FloppyDMA reading from address: " << address << std::endl;
    return 0xBBBB;
}

void FloppyDMA::Write(uint32_t address, uint16_t value)
{
    std::cout << "FloppyDMA writing value: " << value
              << " to address: " << address << std::endl;
}

uint16_t FloppyDMA::IDENT(uint16_t level)
{
    // Provide some default functionality or just return 0
    std::cout << "FloppyDMA::IDENT called with level " << level << std::endl;

    bool HasInterrupt = (interruptBits & (1 << level)) != 0;
    if (HasInterrupt)
    {
        // statusRegister.bits.interruptEnabled = false;
        SetInterruptStatus(false, level); // Clear interrupt on this level

        printf("FloppyDMA::IDENT found %o\r\n", IdentCode);

        return IdentCode;
    }
    else
    {
        printf("WTF %x %x\r\n", interruptBits, 1 << level);
    }

    return 0;
}




/************************************
 *  Device Manager implementation   *
 ************************************/

/// @brief
/// @param type
/// @param startAddress
/// @param endAddress
/// @return
std::unique_ptr<NDDevice> DeviceManager::CreateDevice(DeviceType type, uint8_t thumbweel)
{
    switch (type)
    {
    case DeviceType::PaperTape:
        return std::make_unique<PaperTape>(thumbweel);
    case DeviceType::FloppyPIO:
        return std::make_unique<FloppyPIO>(thumbweel);
    case DeviceType::FloppyDMA:
        return std::make_unique<FloppyDMA>(thumbweel);
    default:
        return nullptr;
    }
}

/// @brief  Add a new device
/// @param type
/// @param startAddress
/// @param endAddress
void DeviceManager::AddDevice(DeviceType type, uint8_t thumbweel)
{
    DeviceInfo info;
    info.device = CreateDevice(type, thumbweel);
    devices.push_back(std::move(info));
}

void DeviceManager::MasterClear()
{
    for (auto &info : devices)
    {

        return info.device->Reset();
    }
}

/// @brief
/// @param address
/// @return
uint16_t DeviceManager::Read(uint32_t address)
{
    for (auto &info : devices)
    {
        // If the address belongs to this device, read from it
        if (info.device->IsInAddress(address))
        {
            return info.device->Read(address);
        }
    }
    std::cerr << "No device found for address: " << address << std::endl;
    return 0;
}

/// @brief
/// @param address
/// @param value
void DeviceManager::Write(uint32_t address, uint16_t value)
{
    for (auto &info : devices)
    {
        // If the address belongs to this device, write to it
        if (info.device->IsInAddress(address))
        {
            info.device->Write(address, value);
            return;
        }
    }
    std::cerr << "No device found for address: " << address << std::endl;
}

/// @brief Identify which device had en interrupt
/// @param level
/// @return
uint16_t DeviceManager::IDENT(uint16_t level)
{
    for (auto &info : devices)
    {
        // Check if this device has an interrupt at this 'level'
        uint16_t id = info.device->IDENT(level);
        if (id > 0)
        {
            return id;
        }
    }
    printf("No device found for IDENT level: %d\r\n", level);
    return 0;
}

/// @brief  Every cpu tick this is called. Returns interrupt bits from all devices
///
/// @param
uint16_t DeviceManager::Tick(void)
{
    uint16_t interruptBits = 0;
    for (auto &info : devices)
    {
        // Tick the device
        interruptBits |= info.device->Tick();
    }

    return interruptBits;
}
