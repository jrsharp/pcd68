#pragma once

#include "PCD68_CPU.h"
#include "Peripheral.h"
#include <cstring>
#include <stdint.h>

extern u8* systemRam;

class KCTL : public Peripheral {

public:

    /** Number of keys in single key input report */
    static constexpr int KEYS_IN_REPORT = 7;
    /** Number of key input reports that can be held in report stack */
    static constexpr int REPORT_STACK_SIZE = 8;

    /**
     * Video/Text mode
     */
    enum Status : u8 {
        DISCONNECTED = 0x00,
        CONNECTED = 0x01,
    };

    /**
     * Represents a single key input report
     */
    struct KeyReport {
        u8 mod;                     //!< Byte containing pressed modifier keys
        u8 keys[KEYS_IN_REPORT];    //!< Array of keys pressed in report
    };

    /**
     * Struct for KCTL's registers
     */
    struct Registers {
        Status status;                              //!< Status byte
        u8 pendingReportCount;                      //!< Number of input reports currently held in the report stack
        KeyReport reportStack[REPORT_STACK_SIZE];   //!< The stack of pending reports
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
    KCTL(CPU* cpu, uint32_t start, uint32_t size);

    void update(u8 keycode, u8 mod);
    void clear();

    void reset() override;
    u8 read8(u32 addr) override;
    u16 read16(u32 addr) override;
    void write8(u32 addr, u8 val) override;
    void write16(u32 addr, u16 val) override;


protected:
    CPU* cpu;
    Registers registers;

private:
};
