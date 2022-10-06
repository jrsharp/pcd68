#ifndef CPU_H
#define CPU_H

#include "Moira/Moira.h"
#include "Peripheral.h"
#include <iostream>
#include <list>
#include <vector>

using namespace moira;

extern u8* systemRom;
extern u8* systemRam;

/* Helpers */
inline u8 get8(u8* p, u32 addr) {
    return p[addr];
}

inline u16 get16(u8* p, u32 addr) {
    return (u16)(get8(p, addr) << 8 | get8(p, addr + 1));
}

inline void set8(u8* p, u32 addr, u8 val) {
    p[addr] = val;
}

inline void set16(u8* p, u32 addr, u16 val) {
    set8(p, addr, val >> 8);
    set8(p, addr + 1, val & 0xFF);
}

class CPU : public Moira {

public:
    /**
     * Constructor
     */
    CPU();

    /**
     * Destructor
     */
    ~CPU();

    /**
     * Prints the internal state of CPU
     */
    void printState();

    /** Memory location of system ROM */
    static constexpr int ROM_BASE = 0x000000;
    /** Size of ROM (64k) */
    //static constexpr int ROM_SIZE = 0x0A000;
    static constexpr int ROM_SIZE = 0x10000;
    /** Memory location of system RAM */
    static constexpr int RAM_BASE = 0x800000;
    /** Size of RAM (4MB) */
    //static constexpr int RAM_SIZE = 1024 * 64 * 2;
    //static constexpr int RAM_SIZE = (400 * 300) + 128;
    static constexpr int RAM_SIZE = 0x400000;
    /** Memory location of Framebuffer */
    static constexpr int FRAMEBUFFER_BASE = RAM_BASE + 0x10000;
    /** Size of Framebuffer */
    static constexpr int FRAMEBUFFER_SIZE = 400 * 300; // 8bpp

    /**
     * Synchronizes emulated connected hardware with CPU
     *
     * @param cycles number of cycles elapsed since previous call
     */
    void sync(int cycles) override;

    /**
     * Reads a byte from memory
     *
     * @param addr address to read from
     */
    u8 read8(u32 addr) override;

    /**
     * Reads a word from memory
     *
     * @param addr address to read from
     */
    u16 read16(u32 addr) override;

    /**
     * Reads a word from memory (Called on reset)
     *
     * @param addr address to read from
     */
    u16 read16OnReset(u32 addr) override;

    /**
     * Reads a word from memory (For disassembler -- no side effects!)
     *
     * @param addr address to read from
     */
    u16 read16Dasm(u32 addr) override;

    /**
     * Writes byte into memory
     *
     * @param addr address to write to
     * @param val value to write
     */
    void write8(u32 addr, u8 val) override;

    /**
     * Writes word into memory
     *
     * @param addr address to write to
     * @param val value to write
     */
    void write16(u32 addr, u16 val) override;

    /**
     * Returns interrupt vector in IRQ_USER mode
     */
    u16 readIrqUserVector(u8 level) const override;

    /**
     * Breakpoint handler
     *
     * @param addr address of breakpoint
     */
    void breakpointReached(u32 addr) override;

    /**
     * Watchpoint handler
     *
     * @param addr address of watchpoint
     */
    void watchpointReached(u32 addr) override;

    /**
     * Internal buffer for storage of single-instruction disassembly
     */
    char disasm[64];

    /**
     * Adds a peripheral on the buses
     *
     * @param peripheral peripheral to add
     */
    int attachPeripheral(Peripheral* peripheral);

private:
    std::vector<Peripheral*> peripherals;
};

#endif
