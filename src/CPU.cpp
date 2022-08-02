#include "CPU.h"

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
    for (Peripheral* p : peripherals) {
        if (p->isValidFor(addr)) {
            return p->read8(addr);
        }
    }
    if (addr >= ROM_BASE && addr < ROM_SIZE) {
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
    for (Peripheral* p : peripherals) {
        if (p->isValidFor(addr)) {
            return p->read16(addr);
        }
    }
    if (addr >= ROM_BASE && addr < ROM_SIZE) {
        return get16(systemRom, addr - ROM_BASE);
    } else if (addr >= RAM_BASE && addr < (RAM_BASE + RAM_SIZE)) {
        return get16(systemRam, addr - RAM_BASE);
    } else {
        return 0x00;
    }
}

// Read Word
u16 CPU::read16Dasm(u32 addr) {
    if (addr >= ROM_BASE && addr < ROM_SIZE) {
        return get16(systemRom, addr - ROM_BASE);
    } else if (addr >= RAM_BASE && addr < (RAM_BASE + RAM_SIZE)) {
        return get16(systemRam, addr - RAM_BASE);
    } else {
        return 0x00;
    }
}

// Read Word
u16 CPU::read16OnReset(u32 addr) {
    if (addr >= ROM_BASE && addr < ROM_SIZE) {
        return get16(systemRom, addr - ROM_BASE);
    } else if (addr >= RAM_BASE && addr < (RAM_BASE + RAM_SIZE)) {
        return get16(systemRam, addr - RAM_BASE);
    } else {
        return 0x00;
    }
}

// Write Byte
void CPU::write8(u32 addr, u8 val) {
    for (Peripheral* p : peripherals) {
        if (p->isValidFor(addr)) {
            p->write8(addr, val);
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
    for (Peripheral* p : peripherals) {
        if (p->isValidFor(addr)) {
            p->write16(addr, val);
        }
    }
    if (addr >= ROM_BASE && addr < (ROM_BASE + ROM_SIZE)) {
        set16(systemRom, addr - ROM_BASE, val);
        //std::cout << "Writing WORD to (ROM!) " << std::hex << addrAdj << std::endl;
    } else if (addr >= RAM_BASE && addr < (RAM_BASE + RAM_SIZE)) {
        //std::cout << "Writing WORD to " << std::hex << addrAdj << std::endl;
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
    std::cout << "bp: " << addr << std::endl;
}

// Watchpoint handler
void CPU::watchpointReached(u32 addr) {
    std::cout << "wp: " << addr << std::endl;
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
    std::cout << "PC: " << std::hex << pc << std::endl;
    std::cout << "SR: " << std::hex << sr << std::endl;
    std::cout << "USP: " << std::hex << usp << std::endl;
    std::cout << "SSP: " << std::hex << ssp << std::endl;
    std::cout << "FC: " << std::hex << fc << std::endl;
    std::cout << "D: ";
    for (int i = 0; i < 8; i++) { std::cout << std::hex << getD(i) << " "; }
    std::cout << std::endl;
    std::cout << "A: ";
    for (int i = 0; i < 8; i++) { std::cout << std::hex << getA(i) << " "; }
    std::cout << std::endl;

    disassemble(pc, disasm);
    std::cout << "disasm: " << disasm << std::endl;
   
    u16 op = get16(systemRom, pc);
    Instr instr = getInfo(op).I;
    std::cout << "Op: " << op << std::endl;
    std::cout << "Instr: " << instr << std::endl;

    i64 cycles = getClock();
    std::cout << "Cycles: " << cycles << std::endl;
}

