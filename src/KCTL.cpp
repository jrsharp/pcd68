#include "KCTL.h"
#include <iostream>

KCTL::KCTL(CPU* cpu, uint32_t start, uint32_t size) : Peripheral(start, size) {
    this->cpu = cpu;
}

void KCTL::reset() {
    registers.status = Status::CONNECTED;
}

// Check system inputs -> update registers
void KCTL::update() {
}

u8 KCTL::read8(u32 addr) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        return get8((u8*)&registers, addr - BASE_ADDR);
    }
    return 0;
}

u16 KCTL::read16(u32 addr) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        return get16((u8*)&registers, addr - BASE_ADDR);
    }
    return 0;
}

void KCTL::write8(u32 addr, u8 val) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        set8((u8*)&registers, addr - BASE_ADDR, val);
    }
}

void KCTL::write16(u32 addr, u16 val) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        set16((u8*)&registers, addr - BASE_ADDR, val);
    }
}
