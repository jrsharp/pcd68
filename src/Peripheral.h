// Peripheral.h

#pragma once

#include "Moira/Moira.h"

using namespace moira;

class Peripheral {
    public:
        /** Constructor */
        Peripheral(uint32_t start, uint32_t size) {
            baseAddress = start;
            endAddress = start + size;
        }

        virtual u8 read8(u32 addr) = 0;
        virtual u16 read16(u32 addr) = 0;
        virtual void write8(u32 addr, u8 val) = 0;
        virtual void write16(u32 addr, u16 val) = 0;

        bool isValidFor(uint32_t addr) {
            return baseAddress <= addr && addr <= endAddress;
        }

    private:
        uint32_t baseAddress;
        uint32_t endAddress;

};
