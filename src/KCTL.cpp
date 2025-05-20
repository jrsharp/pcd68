#include "KCTL.h"

KCTL::KCTL(CPU* cpu, uint32_t start, uint32_t size) :
    Peripheral(start, size) {
    this->cpu = cpu;
}

void KCTL::reset() {
    registers.status = StatusBits::KEYBOARD_ENABLED; // Enable keyboard by default
    registers.pendingReportCount = 0;
    
    // Initialize all report slots
    for (int i = 0; i < REPORT_STACK_SIZE; i++) {
        registers.reportStack[i].mod = 0;
        registers.reportStack[i].activeKeyCount = 0;
        for (int j = 0; j < KEYS_IN_REPORT; j++) {
            registers.reportStack[i].keys[j] = 0;
        }
    }
}

void KCTL::update(u8 keycode, u8 mod) {
    // Just wrap this as a single-key multi-key update
    const u8 keys[1] = { keycode };
    updateMultiKey(keys, 1, mod);
}

void KCTL::updateMultiKey(const u8* keycodes, u8 keyCount, u8 mod) {
    // Ignore empty updates or if keyboard is disabled
    if (keyCount == 0 || !(registers.status & StatusBits::KEYBOARD_ENABLED)) {
        if (debugMode && keyCount > 0) {
            std::cout << "KCTL::updateMultiKey - Keyboard disabled, ignoring "
                      << (int)keyCount << " keycodes" << std::endl;
        }
        return;
    }

    // Limit key count to what fits in a report
    if (keyCount > KEYS_IN_REPORT) {
        if (debugMode) {
            std::cout << "KCTL::updateMultiKey - Too many keys (" << (int)keyCount
                      << "), limiting to " << KEYS_IN_REPORT << std::endl;
        }
        keyCount = KEYS_IN_REPORT;
    }

    // Fast path for report overflow - avoid costly debug print if not needed
    if (registers.pendingReportCount >= REPORT_STACK_SIZE) {
        if (debugMode) {
            std::cout << "KCTL::updateMultiKey - WARNING: Report stack is full! Keys ignored." << std::endl;
        }
        return;
    }

    // Log the update call if debug is enabled
    if (debugMode) {
        std::cout << "KCTL::updateMultiKey - " << (int)keyCount << " keys, mod: 0x"
                  << std::hex << (int)mod << std::dec
                  << ", pending reports: " << (int)registers.pendingReportCount
                  << "/" << REPORT_STACK_SIZE << std::endl;

        // Print each keycode
        for (int i = 0; i < keyCount; i++) {
            std::cout << "  Key[" << i << "]: 0x" << std::hex << (int)keycodes[i]
                      << std::dec << " ('" << (char)keycodes[i] << "')" << std::endl;
        }
    }

    // Update warning flag based on queue fullness
    if (registers.pendingReportCount >= REPORT_STACK_SIZE - 1) {
        registers.status |= StatusBits::QUEUE_FULL_WARNING;
    } else {
        registers.status &= ~StatusBits::QUEUE_FULL_WARNING;
    }

    // Create a new report with the keycodes (we know there's space from the fast path check)
    KeyReport report;
    report.mod = mod;
    report.activeKeyCount = keyCount;

    // Copy key array efficiently using memcpy for the actual keys
    if (keyCount > 0) {
        memcpy(report.keys, keycodes, keyCount);
    }

    // Zero out unused keys if any
    if (keyCount < KEYS_IN_REPORT) {
        memset(&report.keys[keyCount], 0, KEYS_IN_REPORT - keyCount);
    }

    // Add to report stack
    registers.reportStack[registers.pendingReportCount++] = report;

    // Set status bit to indicate report available
    registers.status |= StatusBits::REPORT_AVAILABLE;

    // Trigger interrupt
    this->cpu->setIPL(KBD_INT_LEVEL);

    if (debugMode) {
        std::cout << "KCTL::updateMultiKey - Added report with " << (int)keyCount
                  << " keys, new count: " << (int)registers.pendingReportCount
                  << ", setting IPL to " << (int)KBD_INT_LEVEL << std::endl;
    }
}

void KCTL::clear() {
    // Only log when there are still reports pending
    if (debugMode && registers.pendingReportCount > 0) {
        std::cout << "KCTL::clear - Clearing interrupt, setting IPL to 0, pending count: " 
                  << (int)registers.pendingReportCount << std::endl;
    }
    this->cpu->setIPL(0x00);
}

void KCTL::advanceToNextReport() {
    if (registers.pendingReportCount > 0) {
        // Use a circular buffer approach with a head index instead of shifting all reports
        static int headIndex = 0;

        // Move to next report by advancing the head index
        headIndex = (headIndex + 1) % REPORT_STACK_SIZE;

        // Decrement the count
        registers.pendingReportCount--;

        // Move the current report to the head position
        if (registers.pendingReportCount > 0) {
            registers.reportStack[0] = registers.reportStack[headIndex];
        }

        // Update status bits
        if (registers.pendingReportCount == 0) {
            // No more reports - clear available bit
            registers.status &= ~StatusBits::REPORT_AVAILABLE;
            // Clear queue full warning bit
            registers.status &= ~StatusBits::QUEUE_FULL_WARNING;
            // Clear interrupt
            this->cpu->setIPL(0x00);
            // Reset head index
            headIndex = 0;

            if (debugMode) {
                std::cout << "KCTL::advanceToNextReport - Queue empty, clearing interrupt" << std::endl;
            }
        }

        if (debugMode) {
            std::cout << "KCTL::advanceToNextReport - Advanced queue, new count: "
                      << (int)registers.pendingReportCount << "/" << REPORT_STACK_SIZE << std::endl;
        }
    }
}

u8 KCTL::read8(u32 addr) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + 0x10) { // Limit to our register space
        u32 offset = addr - BASE_ADDR;
        
        switch (offset) {
            case REG_STATUS: // Status register
                if (debugMode) {
                    std::cout << "KCTL::read8 - Status register: 0x" 
                              << std::hex << (int)registers.status << std::dec << std::endl;
                }
                return registers.status;
                
            case REG_COUNT: // Number of reports in queue
                if (debugMode) {
                    std::cout << "KCTL::read8 - Report count: " 
                              << (int)registers.pendingReportCount << std::endl;
                }
                return registers.pendingReportCount;
                
            case REG_REPORT_SIZE: // Number of active keys in current report
                if (registers.pendingReportCount > 0) {
                    u8 activeKeys = registers.reportStack[0].activeKeyCount;
                    if (debugMode) {
                        std::cout << "KCTL::read8 - Active keys in current report: " 
                                  << (int)activeKeys << std::endl;
                    }
                    return activeKeys;
                }
                return 0;
                
            case REG_MODIFIERS: // Modifier byte
                if (registers.pendingReportCount > 0) {
                    u8 modifiers = registers.reportStack[0].mod;
                    if (debugMode) {
                        std::cout << "KCTL::read8 - Modifiers: 0x" 
                                  << std::hex << (int)modifiers << std::dec << std::endl;
                    }
                    return modifiers;
                }
                return 0;
                
            case REG_KEYS ... REG_KEYS + KEYS_IN_REPORT - 1: // Key array
                if (registers.pendingReportCount > 0) {
                    int keyIndex = offset - REG_KEYS;
                    u8 keyValue = registers.reportStack[0].keys[keyIndex];
                    
                    if (debugMode) {
                        std::cout << "KCTL::read8 - Key[" << keyIndex << "]: 0x" 
                                  << std::hex << (int)keyValue 
                                  << (keyValue >= 32 && keyValue < 127 ? 
                                      std::string(" ('") + (char)keyValue + "')" : "") 
                                  << std::dec << std::endl;
                    }
                    
                    return keyValue;
                }
                return 0;
                
            case REG_NEXT_REPORT: // Advance to next report
                if (debugMode) {
                    std::cout << "KCTL::read8 - Next report register read" << std::endl;
                }
                advanceToNextReport();
                return 0;
                
            default:
                return 0;
        }
    }
    return 0;
}

u16 KCTL::read16(u32 addr) {
    // For 16-bit reads, we'll just do two 8-bit reads for simplicity
    u8 lowByte = read8(addr);
    u8 highByte = read8(addr + 1);
    return (highByte << 8) | lowByte;
}

void KCTL::write8(u32 addr, u8 val) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + 0x10) {
        u32 offset = addr - BASE_ADDR;
        
        if (offset == REG_STATUS) { // Status register
            if (debugMode) {
                std::cout << "KCTL::write8 - Status register write: 0x" 
                          << std::hex << (int)val << std::dec << std::endl;
            }
            
            // Check if interrupt clear bit is being set
            if (val & StatusBits::CLEAR_INTERRUPT) {
                if (debugMode) {
                    std::cout << "KCTL::write8 - Clearing interrupt via status register" << std::endl;
                }
                this->cpu->setIPL(0x00);
                // Don't store the clear bit in status register
                val &= ~StatusBits::CLEAR_INTERRUPT;
            }
            
            // Update enable/disable bit
            if ((val & StatusBits::KEYBOARD_ENABLED) != 
                (registers.status & StatusBits::KEYBOARD_ENABLED)) {
                if (debugMode) {
                    std::cout << "KCTL::write8 - Keyboard " 
                              << ((val & StatusBits::KEYBOARD_ENABLED) ? "enabled" : "disabled") 
                              << std::endl;
                }
            }
            
            // Keep read-only bits
            u8 readOnlyBits = registers.status & (StatusBits::REPORT_AVAILABLE | StatusBits::QUEUE_FULL_WARNING);
            registers.status = (val & ~(StatusBits::REPORT_AVAILABLE | StatusBits::QUEUE_FULL_WARNING)) | readOnlyBits;
        }
        else if (offset == REG_COUNT) { // Reset report count (allow clearing the queue)
            if (val == 0) {
                if (debugMode) {
                    std::cout << "KCTL::write8 - Clearing report queue" << std::endl;
                }
                registers.pendingReportCount = 0;
                registers.status &= ~(StatusBits::REPORT_AVAILABLE | StatusBits::QUEUE_FULL_WARNING);
                this->cpu->setIPL(0x00);
            }
        }
        else if (offset == REG_NEXT_REPORT) { // Advance to next report
            if (debugMode) {
                std::cout << "KCTL::write8 - Next report register write" << std::endl;
            }
            advanceToNextReport();
        }
        // Other registers are read-only
    }
}

void KCTL::write16(u32 addr, u16 val) {
    // For 16-bit writes, break into two 8-bit writes
    write8(addr, val & 0xFF);
    write8(addr + 1, (val >> 8) & 0xFF);
}
