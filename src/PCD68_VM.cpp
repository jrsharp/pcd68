// Lightweight PCD68 Virtual Machine implementation

#include "PCD68_VM.h"

namespace pcd68 {

enum Flags {
    FLAG_ZERO = 0x01,
    FLAG_CARRY = 0x02,
    FLAG_NEGATIVE = 0x04,
    FLAG_OVERFLOW = 0x08
};

PCD68_VM::PCD68_VM() 
    : pc(0), sp(0), flags(0), halted(false),
      rom(nullptr), romSize(0), ram(nullptr), ramSize(0),
      numPeripherals(0), pendingInterrupts(0), interruptMask(0xFF) {
    memset(registers, 0, sizeof(registers));
    memset(stack, 0, sizeof(stack));
}

void PCD68_VM::init(uint8_t* romData, size_t romLen, uint8_t* ramData, size_t ramLen) {
    rom = romData;
    romSize = romLen;
    ram = ramData;
    ramSize = ramLen;
    reset();
}

void PCD68_VM::registerPeripheral(uint32_t address, Peripheral* device) {
    if (numPeripherals < MAX_PERIPHERALS) {
        peripherals[numPeripherals].address = address;
        peripherals[numPeripherals].device = device;
        numPeripherals++;
    }
}

void PCD68_VM::reset() {
    pc = 0;
    sp = 0;
    flags = 0;
    halted = false;
    pendingInterrupts = 0;
    memset(registers, 0, sizeof(registers));
}

void PCD68_VM::step() {
    if (halted) return;
    
    // Check for interrupts
    if (pendingInterrupts & interruptMask) {
        // Handle interrupt - simplified for now
        for (uint8_t i = 0; i < 8; i++) {
            if ((pendingInterrupts & (1 << i)) && (interruptMask & (1 << i))) {
                pendingInterrupts &= ~(1 << i);
                push(pc);
                push(flags);
                pc = 0x100 + (i * 4); // Simple vector table
                break;
            }
        }
    }
    
    uint8_t opcode = fetchByte();
    
    switch (opcode) {
        case OP_LOAD_IMM: {
            uint8_t reg = fetchByte();
            uint32_t value = fetchLong();
            registers[reg & 0xF] = value;
            break;
        }
        
        case OP_LOAD_MEM: {
            uint8_t reg = fetchByte();
            uint32_t addr = fetchLong();
            registers[reg & 0xF] = readMemory(addr, 4);
            break;
        }
        
        case OP_STORE_MEM: {
            uint8_t reg = fetchByte();
            uint32_t addr = fetchLong();
            writeMemory(addr, registers[reg & 0xF], 4);
            break;
        }
        
        case OP_ADD: {
            uint8_t dst = fetchByte();
            uint8_t src = fetchByte();
            uint32_t result = registers[dst & 0xF] + registers[src & 0xF];
            registers[dst & 0xF] = result;
            setFlag(FLAG_ZERO, result == 0);
            setFlag(FLAG_NEGATIVE, result & 0x80000000);
            break;
        }
        
        case OP_SUB: {
            uint8_t dst = fetchByte();
            uint8_t src = fetchByte();
            uint32_t result = registers[dst & 0xF] - registers[src & 0xF];
            registers[dst & 0xF] = result;
            setFlag(FLAG_ZERO, result == 0);
            setFlag(FLAG_NEGATIVE, result & 0x80000000);
            break;
        }
        
        case OP_JMP: {
            pc = fetchLong();
            break;
        }
        
        case OP_JZ: {
            uint32_t addr = fetchLong();
            if (getFlag(FLAG_ZERO)) pc = addr;
            break;
        }
        
        case OP_JNZ: {
            uint32_t addr = fetchLong();
            if (!getFlag(FLAG_ZERO)) pc = addr;
            break;
        }
        
        case OP_CALL: {
            uint32_t addr = fetchLong();
            push(pc);
            pc = addr;
            break;
        }
        
        case OP_RET: {
            pc = pop();
            break;
        }
        
        case OP_IN: {
            uint8_t reg = fetchByte();
            uint32_t addr = fetchLong();
            Peripheral* p = findPeripheral(addr);
            if (p) {
                registers[reg & 0xF] = p->read8(addr);
            }
            break;
        }
        
        case OP_OUT: {
            uint8_t reg = fetchByte();
            uint32_t addr = fetchLong();
            Peripheral* p = findPeripheral(addr);
            if (p) {
                p->write8(addr, registers[reg & 0xF] & 0xFF);
            }
            break;
        }
        
        case OP_HALT: {
            halted = true;
            break;
        }
        
        case OP_NOP:
        default:
            break;
    }
}

void PCD68_VM::run(uint32_t maxCycles) {
    uint32_t cycles = 0;
    while (!halted && (maxCycles == 0 || cycles < maxCycles)) {
        step();
        cycles++;
    }
}

void PCD68_VM::raiseInterrupt(uint8_t level) {
    pendingInterrupts |= (1 << (level & 7));
}

uint8_t PCD68_VM::fetchByte() {
    if (pc < romSize) {
        return rom[pc++];
    }
    pc++;
    return 0;
}

uint16_t PCD68_VM::fetchWord() {
    uint16_t value = fetchByte() << 8;
    value |= fetchByte();
    return value;
}

uint32_t PCD68_VM::fetchLong() {
    uint32_t value = fetchWord() << 16;
    value |= fetchWord();
    return value;
}

uint32_t PCD68_VM::readMemory(uint32_t address, uint8_t size) {
    // Check if it's a peripheral access
    Peripheral* p = findPeripheral(address);
    if (p) {
        switch (size) {
            case 1: return p->read8(address);
            case 2: return p->read16(address);
            case 4: return p->read16(address) << 16 | p->read16(address + 2);
        }
    }
    
    // ROM access
    if (address < romSize) {
        if (size == 1) return rom[address];
        if (size == 2 && address + 1 < romSize) {
            return (rom[address] << 8) | rom[address + 1];
        }
        if (size == 4 && address + 3 < romSize) {
            return (rom[address] << 24) | (rom[address + 1] << 16) |
                   (rom[address + 2] << 8) | rom[address + 3];
        }
    }
    
    // RAM access (mapped after ROM)
    uint32_t ramAddr = address - 0x10000;
    if (ramAddr < ramSize) {
        if (size == 1) return ram[ramAddr];
        if (size == 2 && ramAddr + 1 < ramSize) {
            return (ram[ramAddr] << 8) | ram[ramAddr + 1];
        }
        if (size == 4 && ramAddr + 3 < ramSize) {
            return (ram[ramAddr] << 24) | (ram[ramAddr + 1] << 16) |
                   (ram[ramAddr + 2] << 8) | ram[ramAddr + 3];
        }
    }
    
    return 0;
}

void PCD68_VM::writeMemory(uint32_t address, uint32_t value, uint8_t size) {
    // Check if it's a peripheral access
    Peripheral* p = findPeripheral(address);
    if (p) {
        switch (size) {
            case 1: p->write8(address, value & 0xFF); break;
            case 2: p->write16(address, value & 0xFFFF); break;
            case 4: 
                p->write16(address, (value >> 16) & 0xFFFF);
                p->write16(address + 2, value & 0xFFFF);
                break;
        }
        return;
    }
    
    // RAM access only (ROM is read-only)
    uint32_t ramAddr = address - 0x10000;
    if (ramAddr < ramSize) {
        if (size == 1) {
            ram[ramAddr] = value & 0xFF;
        } else if (size == 2 && ramAddr + 1 < ramSize) {
            ram[ramAddr] = (value >> 8) & 0xFF;
            ram[ramAddr + 1] = value & 0xFF;
        } else if (size == 4 && ramAddr + 3 < ramSize) {
            ram[ramAddr] = (value >> 24) & 0xFF;
            ram[ramAddr + 1] = (value >> 16) & 0xFF;
            ram[ramAddr + 2] = (value >> 8) & 0xFF;
            ram[ramAddr + 3] = value & 0xFF;
        }
    }
}

Peripheral* PCD68_VM::findPeripheral(uint32_t address) {
    for (uint8_t i = 0; i < numPeripherals; i++) {
        uint32_t base = peripherals[i].address;
        // Simple range check - assumes peripherals use 256 byte ranges
        if (address >= base && address < base + 256) {
            return peripherals[i].device;
        }
    }
    return nullptr;
}

void PCD68_VM::push(uint32_t value) {
    if (sp < STACK_SIZE) {
        stack[sp++] = value;
    }
}

uint32_t PCD68_VM::pop() {
    if (sp > 0) {
        return stack[--sp];
    }
    return 0;
}

void PCD68_VM::setFlag(uint8_t flag, bool value) {
    if (value) {
        flags |= flag;
    } else {
        flags &= ~flag;
    }
}

bool PCD68_VM::getFlag(uint8_t flag) const {
    return flags & flag;
}

} // namespace pcd68