#include "KCTL.h"

KCTL::KCTL(CPU* cpu, uint32_t start, uint32_t size) :
    Peripheral(start, size) {
    this->cpu = cpu;
}

void KCTL::reset() {
    registers.status = Status::CONNECTED;
    registers.pendingReportCount = 0;
}

void KCTL::update(u8 keycode, u8 mod) {
    if (registers.pendingReportCount < REPORT_STACK_SIZE) {
        KeyReport report = { mod, { keycode, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 } };
        registers.reportStack[registers.pendingReportCount++] = report;
        this->cpu->setIPL(KBD_INT_LEVEL);
    }
}

void KCTL::clear() {
    this->cpu->setIPL(0x00);
}

u8 KCTL::read8(u32 addr) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        u32 offset = addr - BASE_ADDR;
        
        if (offset >= offsetof(Registers, reportStack) && registers.pendingReportCount > 0) {
            u32 reportOffset = offset - offsetof(Registers, reportStack);
            u8 value = get8((u8*)&registers, offset);
            
            if (reportOffset == 2 && registers.pendingReportCount > 0) {
                for (int i = 0; i < registers.pendingReportCount - 1; i++) {
                    registers.reportStack[i] = registers.reportStack[i + 1];
                }
                registers.pendingReportCount--;
                
                if (registers.pendingReportCount == 0) {
                    this->cpu->setIPL(0x00);
                }
            }
            
            return value;
        }
        
        return get8((u8*)&registers, offset);
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
        u32 offset = addr - BASE_ADDR;
        
        if (offset == offsetof(Registers, pendingReportCount)) {
            if (val == 0) {
                registers.pendingReportCount = 0;
                this->cpu->setIPL(0x00);
                return;
            }
        }
        
        set8((u8*)&registers, offset, val);
    }
}

void KCTL::write16(u32 addr, u16 val) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        set16((u8*)&registers, addr - BASE_ADDR, val);
    }
}
