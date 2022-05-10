#pragma once

#include "Peripheral.h"
#include <stdint.h>

class TDA : public Peripheral {

public:

    /**
     * Constructor
     *
     * @param start base address
     * @param size size of memory
     */
    TDA(uint32_t start, uint32_t size) : Peripheral(start, size) {
    }

    u8 read8(u32 addr) override;
    u16 read16(u32 addr) override;
    void write8(u32 addr, u8 val) override;
    void write16(u32 addr, u16 val) override;

private:
    uint8_t textMapMem[80 * 23];
};

