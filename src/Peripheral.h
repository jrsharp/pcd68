// Peripheral.h

#pragma once

#ifdef CONFIG_PCD68_USE_LIGHTWEIGHT_VM
// When using lightweight VM, types are defined in PCD68_VM.h
#include <stdint.h>
namespace moira {
    typedef uint8_t u8;
    typedef uint16_t u16;
    typedef uint32_t u32;
}
using namespace moira;
#else
#include "Moira/Moira.h"
using namespace moira;
#endif

class Peripheral {
public:
    /** Constructor */
    Peripheral(uint32_t start, uint32_t size) {
        baseAddress = start;
        endAddress = start + size;
    }

    virtual void reset() = 0;
    virtual u8 read8(u32 addr) = 0;
    virtual u16 read16(u32 addr) = 0;
    virtual void write8(u32 addr, u8 val) = 0;
    virtual void write16(u32 addr, u16 val) = 0;

    bool isValidFor(uint32_t addr) {
        return baseAddress <= addr && addr < endAddress;
    }

protected:
    uint32_t getBaseAddress() const { return baseAddress; }
    uint32_t getEndAddress() const { return endAddress; }

private:
    uint32_t baseAddress;
    uint32_t endAddress;
};
