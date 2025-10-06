/*
 * Test Helper - Shared TestMemory class for all tests
 */

#pragma once

#include "Moira/Moira.h"
#include <string.h>
#include <zephyr/kernel.h>

using namespace moira;

// Helper class to provide memory for tests
class TestMemory : public Moira {
public:
    uint8_t* ram;  // 16KB RAM for tests (heap-allocated to avoid stack overflow)
    static constexpr size_t RAM_SIZE = 16 * 1024;

    TestMemory() {
        // Use Zephyr's k_malloc instead of C++ new
        ram = (uint8_t*)k_malloc(RAM_SIZE);
        if (!ram) {
            printk("ERROR: Failed to allocate %zu bytes for test RAM!\n", RAM_SIZE);
            return;
        }
        memset(ram, 0, RAM_SIZE);
    }

    ~TestMemory() {
        if (ram) {
            k_free(ram);
        }
    }

    // Memory access methods (required by Moira)
    uint8_t read8(uint32_t addr) override {
        if (!ram) return 0xFF;
        if (addr < RAM_SIZE) return ram[addr];
        return 0xFF;
    }

    uint16_t read16(uint32_t addr) override {
        if (!ram) return 0xFFFF;
        if (addr + 1 < RAM_SIZE) {
            return (ram[addr] << 8) | ram[addr + 1];
        }
        return 0xFFFF;
    }

    void write8(uint32_t addr, uint8_t value) override {
        if (!ram) return;
        if (addr < RAM_SIZE) ram[addr] = value;
    }

    void write16(uint32_t addr, uint16_t value) override {
        if (!ram) return;
        if (addr + 1 < RAM_SIZE) {
            ram[addr] = value >> 8;
            ram[addr + 1] = value & 0xFF;
        }
    }

    // Helper to write a 16-bit word in big-endian
    void write_word(uint32_t addr, uint16_t value) {
        ram[addr] = value >> 8;
        ram[addr + 1] = value & 0xFF;
    }

    // Helper to write a 32-bit long in big-endian
    void write_long(uint32_t addr, uint32_t value) {
        ram[addr] = value >> 24;
        ram[addr + 1] = (value >> 16) & 0xFF;
        ram[addr + 2] = (value >> 8) & 0xFF;
        ram[addr + 3] = value & 0xFF;
    }

    // Convenience wrappers for public get/set methods
    u32 readD(int n) const { return getD(n); }
    u32 readA(int n) const { return getA(n); }
    void writeD(int n, u32 v) { setD(n, v); }
    void writeA(int n, u32 v) { setA(n, v); }
};
