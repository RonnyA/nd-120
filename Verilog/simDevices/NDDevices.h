
#ifndef NDDEVICES_H
#define NDDEVICES_H

#include <memory>
#include <vector>
#include <iostream>
#include <string>

#define DEBUG_PT 1 //0=OFF Papertape

enum class DeviceType {
    PaperTape,
    FloppyPIO,
    FloppyDMA
};


class NDDevice {
protected:
    uint32_t startAddress = 0;
    uint32_t endAddress   = 0;
    uint16_t interruptBits = 0;
    uint16_t InterruptLevel = 0; // Default interrupt level
    uint16_t IdentCode = 0; // Identcode for this device
    bool     HasInterrupt = 0;

    void SetInterruptStatus(bool active)
    {
        SetInterruptStatus(active, InterruptLevel);
    }

    void SetInterruptStatus(bool active, uint16_t level)
    {
        if ((level <10) ||(level >13))
        {
            // Invalid
            return;
        }

        uint16_t saveBits = interruptBits;
        if (active)
            interruptBits |= 1<<level;
        else
            interruptBits &= ~(1<<level);

        if (interruptBits != saveBits)
        {
            HasInterrupt = 1;
        }


    }


public:
    NDDevice(uint8_t thumbweel)
    {
    }

    virtual ~NDDevice() = default;

    // Returns true if 'address' is within [startAddress, endAddress].
    bool IsInAddress(uint32_t address) const {
        return (address >= startAddress && address <= endAddress);
    }

    // Returns 'address' offset relative to 'startAddress'.
    uint32_t RegisterAddress(uint32_t address) const {
        return address - startAddress;
    }

    virtual uint16_t Read(uint32_t address) = 0;
    virtual void Write(uint32_t address, uint16_t value) = 0;

    virtual uint16_t IDENT(uint16_t level) = 0;
};

class DeviceManager {
private:
    struct DeviceInfo {
        std::unique_ptr<NDDevice> device;
    };

    std::vector<DeviceInfo> devices;

    // CreateDevice needs the thumbweel setting so the device can set up its internal settings (address, interruptlevel,identcode)    
    std::unique_ptr<NDDevice> CreateDevice(DeviceType type, uint8_t thumbweel);

public:
    void AddDevice(DeviceType type, uint8_t thumbweel);
    uint16_t Read(uint32_t address);
    void Write(uint32_t address, uint16_t value);
    uint16_t IDENT(uint16_t level);
    void Tick(void); // Every cpu tick this is called
};




class PaperTape: public NDDevice{
public:    
        
    PaperTape(uint8_t thumbweel);       
    ~PaperTape();       
    uint16_t Read(uint32_t address) override;
    void Write(uint32_t address, uint16_t value) override;
    uint16_t IDENT(uint16_t level);

private:
    enum class Registers {
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
            unsigned interruptEnabled : 1;  // Bit 0
            unsigned notUsed1         : 1;  // Bit 1
            unsigned readActive       : 1;  // Bit 2
            // Expand or rename bits as you need ...
            unsigned readyForTransfer : 1;  // Bit 3
            unsigned deviceClear      : 1;  // Bit 4
            unsigned notUsed5         : 1;  // Bit 5
            unsigned notUsed6         : 1;  // Bit 6
            unsigned notUsed7         : 1;  // Bit 7
            unsigned notUsed8         : 1;  // Bit 8
            unsigned notUsed9         : 1;  // Bit 9
            unsigned notUsed10        : 1;  // Bit 10
            unsigned notUsed11        : 1;  // Bit 11
            unsigned notUsed12        : 1;  // Bit 12
            unsigned notUsed13        : 1;  // Bit 13
            unsigned notUsed14        : 1;  // Bit 14
            unsigned notUsed15        : 1;  // Bit 15
        } bits;
    };

    ControlWord controlWord{};

    union StatusRegister
    {
        uint16_t raw;
        struct
        {
            unsigned interruptEnabled : 1;  // Bit 0
            unsigned notUsed1         : 1;  // Bit 1
            unsigned readActive       : 1;  // Bit 2
            // Expand or rename bits as you need ...
            unsigned readyForTransfer : 1;  // Bit 3
            unsigned notUsed4         : 1;  // Bit 4
            unsigned notUsed5         : 1;  // Bit 5
            unsigned notUsed6         : 1;  // Bit 6
            unsigned notUsed7         : 1;  // Bit 7
            unsigned notUsed8         : 1;  // Bit 8
            unsigned notUsed9         : 1;  // Bit 9
            unsigned notUsed10        : 1;  // Bit 10
            unsigned notUsed11        : 1;  // Bit 11
            unsigned notUsed12        : 1;  // Bit 12
            unsigned notUsed13        : 1;  // Bit 13
            unsigned notUsed14        : 1;  // Bit 14
            unsigned notUsed15        : 1;  // Bit 15
        } bits;
    };

    StatusRegister statusRegister{};

    uint8_t characterBuffer;

    FILE *papertapeFile;
    //char *paptertapeName;
    std::string papertapeName;
};



class FloppyPIO : public NDDevice {
public:     
    FloppyPIO(uint8_t thumbwheel);    

    uint16_t Read(uint32_t address) override;
    void Write(uint32_t address, uint16_t value) override;
    uint16_t IDENT(uint16_t level);
};


class FloppyDMA : public NDDevice {
public:     
    FloppyDMA(uint8_t thumbweel);    

    uint16_t Read(uint32_t address) override;
    void Write(uint32_t address, uint16_t value) override;
    uint16_t IDENT(uint16_t level);
};


#endif // NDDEVICES_H
