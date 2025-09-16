#include "PCD68_CPU.h"

#ifdef USE_ZEPHYR
#include <zephyr/logging/log.h>
LOG_MODULE_REGISTER(cpu, LOG_LEVEL_WRN);  // Reduce logging to save flash space
#endif

// C'tor
CPU::CPU() {
}

// D'tor
CPU::~CPU() {
}

// Sync
void CPU::sync(int cycles) {
    clock += cycles;
}

// Read Byte
u8 CPU::read8(u32 addr) {
    for (size_t i = 0; i < peripherals.size(); i++) {
        Peripheral* p = peripherals[i];
        if (p->isValidFor(addr)) {
            return p->read8(addr);
        }
    }
    if (addr >= ROM_BASE && addr < (ROM_BASE + ROM_SIZE)) {
        return get8(systemRom, addr - ROM_BASE);
    } else if (addr >= RAM_BASE && addr < (RAM_BASE + RAM_SIZE)) {
        return get8(systemRam, addr - RAM_BASE);
    } else {
        // Fill unused/null memmory with 0xFF
        return 0xFF;
    }
}

// Read Word
u16 CPU::read16(u32 addr) {
    for (size_t i = 0; i < peripherals.size(); i++) {
        Peripheral* p = peripherals[i];
        if (p->isValidFor(addr)) {
            return p->read16(addr);
        }
    }
    if (addr >= ROM_BASE && addr < (ROM_BASE + ROM_SIZE)) {
        return get16(systemRom, addr - ROM_BASE);
    } else if (addr >= RAM_BASE && addr < (RAM_BASE + RAM_SIZE)) {
        return get16(systemRam, addr - RAM_BASE);
    } else {
        return 0x00;
    }
}

// Read Word
u16 CPU::read16Dasm(u32 addr) {
    if (addr >= ROM_BASE && addr < (ROM_BASE + ROM_SIZE)) {
        return get16(systemRom, addr - ROM_BASE);
    } else if (addr >= RAM_BASE && addr < (RAM_BASE + RAM_SIZE)) {
        return get16(systemRam, addr - RAM_BASE);
    } else {
        return 0x00;
    }
}

// Read Word
u16 CPU::read16OnReset(u32 addr) {
    if (addr >= ROM_BASE && addr < (ROM_BASE + ROM_SIZE)) {
        return get16(systemRom, addr - ROM_BASE);
    } else if (addr >= RAM_BASE && addr < (RAM_BASE + RAM_SIZE)) {
        return get16(systemRam, addr - RAM_BASE);
    } else {
        return 0x00;
    }
}

// Write Byte
void CPU::write8(u32 addr, u8 val) {
    for (size_t i = 0; i < peripherals.size(); i++) {
        Peripheral* p = peripherals[i];
        if (p->isValidFor(addr)) {
            p->write8(addr, val);
            return;
        }
    }
    if (addr >= ROM_BASE && addr < (ROM_BASE + ROM_SIZE)) {
        set8(systemRom, addr - ROM_BASE, val);
        //std::cout << "Writing BYTE to (ROM!) " << std::hex << (addr - ROM_BASE) << std::endl;
    } else if (addr >= RAM_BASE && addr < (RAM_BASE + RAM_SIZE)) {
        set8(systemRam, addr - RAM_BASE, val);
        //std::cout << "Writing BYTE to " << std::hex << (addr - RAM_BASE) << std::endl;
    } else {
        //std::cout << "Writing BYTE to NOWHERE. (" << std::hex << addr << ")" << std::endl;
    }
}

// Write Word
void CPU::write16(u32 addr, u16 val) {
    for (size_t i = 0; i < peripherals.size(); i++) {
        Peripheral* p = peripherals[i];
        if (p->isValidFor(addr)) {
            p->write16(addr, val);
            return;
        }
    }
    if (addr >= ROM_BASE && addr < (ROM_BASE + ROM_SIZE)) {
        set16(systemRom, addr - ROM_BASE, val);
        //std::cout << "Writing WORD to (ROM!) " << std::hex << addr - ROM_BASE << std::endl;
    } else if (addr >= RAM_BASE && addr < (RAM_BASE + RAM_SIZE)) {
        //std::cout << "Writing WORD to " << std::hex << addr - RAM_BASE << std::endl;
        set16(systemRam, addr - RAM_BASE, val);
    } else {
        //std::cout << "Writing NOWHERE. (" << std::hex << addr << ")" << std::endl;
    }
}

// Read Interrupt
u16 CPU::readIrqUserVector(u8 level) const {
    return 0;
}

// Breakpoint handler
void CPU::breakpointReached(u32 addr) {
#ifndef USE_ZEPHYR
    std::cout << "bp: " << std::hex << addr << std::endl;
#else
    LOG_INF("bp: 0x%08x", addr);
#endif
    this->printState();
}

// Watchpoint handler
void CPU::watchpointReached(u32 addr) {
#ifndef USE_ZEPHYR
    std::cout << "wp: " << std::hex << addr << std::endl;
#else
    LOG_INF("wp: 0x%08x", addr);
#endif
    this->printState();
}

int CPU::attachPeripheral(Peripheral* p) {
    peripherals.push_back(p);
    return 0;
}

// Print CPU state
void CPU::printState() {
    u32 pc = getPC();
    u16 sr = getSR();
    u32 usp = getUSP();
    u32 ssp = getSSP();
    u32 fc = readFC();
    
#ifndef USE_ZEPHYR
    std::cout << "PC: " << std::hex << pc << std::endl;
    std::cout << "SR: " << std::hex << sr << std::endl;
    std::cout << "USP: " << std::hex << usp << std::endl;
    std::cout << "SSP: " << std::hex << ssp << std::endl;
    std::cout << "FC: " << std::hex << fc << std::endl;
    std::cout << "D: ";
    for (int i = 0; i < 8; i++) {
        std::cout << std::hex << getD(i) << " ";
    }
    std::cout << std::endl;
    std::cout << "A: ";
    for (int i = 0; i < 8; i++) {
        std::cout << std::hex << getA(i) << " ";
    }
    std::cout << std::endl;

#ifndef USE_ZEPHYR
    disassemble(pc, disasm);
    std::cout << "disasm: " << disasm << std::endl;
#else
    // Disassembler disabled in Zephyr builds to save flash space
    strcpy(disasm, "[disasm disabled]");
    LOG_INF("disasm: %s", disasm);
#endif

    u16 op = get16(systemRom, pc);
    Instr instr = getInfo(op).I;
    std::cout << "Op: " << op << std::endl;
    std::cout << "Instr: " << instr << std::endl;

    i64 cycles = getClock();
    std::cout << "Cycles: " << cycles << std::endl;
#else
    LOG_INF("PC: 0x%08x SR: 0x%04x USP: 0x%08x SSP: 0x%08x FC: 0x%08x", pc, sr, usp, ssp, fc);
    
    LOG_INF("D: %08x %08x %08x %08x %08x %08x %08x %08x", 
           getD(0), getD(1), getD(2), getD(3), getD(4), getD(5), getD(6), getD(7));
    LOG_INF("A: %08x %08x %08x %08x %08x %08x %08x %08x", 
           getA(0), getA(1), getA(2), getA(3), getA(4), getA(5), getA(6), getA(7));

#ifndef USE_ZEPHYR
    disassemble(pc, disasm);
#else
    // Disassembler disabled in Zephyr builds to save flash space  
    strcpy(disasm, "[disasm disabled]");
#endif
    LOG_INF("disasm: %s", disasm);

    u16 op = get16(systemRom, pc);
    Instr instr = getInfo(op).I;
    LOG_INF("Op: 0x%04x Instr: %d", op, instr);

    i64 cycles = getClock();
    LOG_INF("Cycles: %lld", cycles);
#endif
}
