#pragma once

#include "CPU.h"
#include "Peripheral.h"
#include <cstring>
#include <stdint.h>

extern u8 systemRam[];

class KCTL : public Peripheral {

public:

    /**
     * Video/Text mode
     */
    enum Status : u8 {
        CONNECTED = 0x01,
    };

    /**
     * Struct for KCTL's registers
     */
    struct Registers {
        Status status;
        u16 keycode;
        u16 mod;
    };

    /** Default base address for peripheral */
    static constexpr u32 BASE_ADDR = 0x420000;

    /** Keyboard interrupt level (68000) */
    static constexpr u8 KBD_INT_LEVEL = 3;

    /**
     * Constructor
     *
     * @param start base address
     * @param size size of memory
     */
    KCTL(CPU *cpu, uint32_t start, uint32_t size);

    void update(u16 keycode, u16 mod);
    void clear();

    void reset() override;
    u8 read8(u32 addr) override;
    u16 read16(u32 addr) override;
    void write8(u32 addr, u8 val) override;
    void write16(u32 addr, u16 val) override;

private:
    CPU *cpu;
    Registers registers;
};
