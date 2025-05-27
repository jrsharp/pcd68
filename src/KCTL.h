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
     * Enable or disable debug mode
     * @param enabled true to enable debug output, false to disable
     */
    void setDebugMode(bool enabled) {
        debugMode = enabled;
        if (debugMode) {
            std::cout << "KCTL debug mode enabled" << std::endl;
        }
    }

    /**
     * Status register bit definitions
     */
    enum StatusBits : u8 {
        REPORT_AVAILABLE = 0x01,   // Bit 0: Report available (1 = available)
        QUEUE_FULL_WARNING = 0x02, // Bit 1: Queue full warning (1 = queue at capacity)
        CLEAR_INTERRUPT = 0x04,    // Bit 2: Clear interrupt (write 1 to clear)
        KEYBOARD_ENABLED = 0x08,   // Bit 3: Enable/disable keyboard (1 = enabled)
    };

    /**
     * Represents a single key input report
     */
    struct KeyReport {
        u8 mod;                     //!< Byte containing pressed modifier keys
        u8 keys[KEYS_IN_REPORT];    //!< Array of keys pressed in report
        u8 activeKeyCount;          //!< Number of active keys in this report
    };

    /**
     * Register offsets within the KCTL memory map
     */
    enum RegisterOffsets : u8 {
        REG_STATUS = 0x00,         //!< Status/control register
        REG_COUNT = 0x01,          //!< Number of reports in queue
        REG_REPORT_SIZE = 0x02,    //!< Number of active keys in current report
        REG_MODIFIERS = 0x03,      //!< Modifier byte
        REG_KEYS = 0x04,           //!< Start of key array (7 bytes, one per key)
        REG_NEXT_REPORT = 0x0B,    //!< Advance to next report (write any value)
    };

    /**
     * Struct for KCTL's registers
     */
    struct Registers {
        u8 status;                               //!< Status/control register
        u8 pendingReportCount;                   //!< Number of input reports currently held in the report stack
        KeyReport reportStack[REPORT_STACK_SIZE];//!< The stack of pending reports
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
    
    /**
     * Update with multiple keys in a single report
     * @param keycodes Array of key codes to include in the report
     * @param keyCount Number of keys in the report
     * @param mod The modifier byte for the report
     */
    void updateMultiKey(const u8* keycodes, u8 keyCount, u8 mod);
    
    void clear();

    void reset() override;
    u8 read8(u32 addr) override;
    u16 read16(u32 addr) override;
    void write8(u32 addr, u8 val) override;
    void write16(u32 addr, u16 val) override;

public: // Making registers public for debug access
    Registers registers;

protected:
    CPU* cpu;

private:
    bool debugMode = false;  // Debug mode flag
    int headIndex = 0;       // Head index for circular buffer queue management
    
    // Helper method to advance to the next report in the queue
    void advanceToNextReport();
};
