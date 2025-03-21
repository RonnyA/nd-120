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

    //paptertapeName = strdup("INSTRUCTION-B.BPUN"); // strdup creates a modifiable copy
    papertapeName = "INSTRUCTION-B.BPUN";
	if ((papertapeFile = fopen(papertapeName.c_str(), "r")) == 0)
	{
		printf("Unable to open file %s\r\n", papertapeName.c_str());
		return;
	}
}

PaperTape::~PaperTape()
{
    if(papertapeFile >0)
    {
        fclose(papertapeFile);
        papertapeFile=0;
    }

}


uint16_t PaperTape::Read(uint32_t address)
{

    uint16_t data = 0;

    Registers reg = (Registers)RegisterAddress(address);

    switch (reg)
    {
    case Registers::ReadDataRegister:
        // ReadDataBuffer(value);
        statusRegister.bits.readyForTransfer = 0;
        data = characterBuffer;
        break;

    case Registers::ReadStatusRegister:
        data = statusRegister.raw;
        break;
    default:
        std::cout << "PaperTape read, invalid register address: " << address << std::endl;
    }

    if (DEBUG_PT) std::cout << "PaperTape Reading from address: " << std::oct << address << " value: " << data << std::oct << std::endl;

    return data;
}

void PaperTape::Write(uint32_t address, uint16_t value)
{
    if (DEBUG_PT) std::cout << "PaperTape Writing value: " << std::oct << value << " to address: " << std::oct << address << std::endl;
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
            
            int w=-1;
            
            if (papertapeFile == NULL)
            {
                printf("NO Papertape");
            }
            else
            {                            
                w = getc(papertapeFile) & 0377;
            }

            // if  read successfull
            if (w>=0)
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
}

uint16_t FloppyPIO::Read(uint32_t address)
{
    std::cout << "FloppyPIO reading from address: " << address << std::endl;
    return 0xAAAA;
}

void FloppyPIO::Write(uint32_t address, uint16_t value)
{
    std::cout << "FloppyPIO writing value: " << value
              << " to address: " << address << std::endl;
}

uint16_t FloppyPIO::IDENT(uint16_t level)
{
    // Provide some default functionality or just return 0
    std::cout << "FloppyPIO::IDENT called with level " << level << std::endl;
    if ((interruptBits & 1 << level) != 0)
    {
        // statusRegister.bits.interruptEnabled = false;
        SetInterruptStatus(false, level); // Clear interrupt on this level
        return IdentCode;
    }
    return 0;
}

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
    if ((interruptBits & 1 << level) != 0)
    {
        // statusRegister.bits.interruptEnabled = false;
        SetInterruptStatus(false, level); // Clear interrupt on this level

        return IdentCode;
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
    std::cerr << "No device found for IDENT level: " << level << std::endl;
    return 0;
}

/// @brief  Every cpu tick this is called
/// @param
void DeviceManager::Tick(void)
{
    // Do stuff?
}
