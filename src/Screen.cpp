/*
 * Copyright (c) 2022, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#include "Screen.h"
#include <iostream>

// C'tor
Screen::Screen(uint32_t start, uint32_t size) :
    Peripheral(start, size) {
    refreshFlag = false;
    wait = 0;
}


u8 Screen::read8(u32 addr) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        return get8((u8*)&registers, addr - BASE_ADDR);
    } else if (addr >= (BASE_ADDR + sizeof(registers)) && addr < BASE_ADDR + sizeof(framebufferMem)) {
        return get8((u8*)framebufferMem, addr - (BASE_ADDR + sizeof(registers)));
    }
    return 0;
}

u16 Screen::read16(u32 addr) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        return get16((u8*)&registers, addr - BASE_ADDR);
    } else if (addr >= (BASE_ADDR + sizeof(registers)) && addr < BASE_ADDR + sizeof(framebufferMem)) {
        return get16((u8*)framebufferMem, addr - (BASE_ADDR + sizeof(registers)));
    }
    return 0;
}

void Screen::write8(u32 addr, u8 val) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        set8((u8*)&registers, addr - BASE_ADDR, val);
        refreshFlag = true;
    } else if (addr >= (BASE_ADDR + sizeof(registers)) && addr < BASE_ADDR + sizeof(framebufferMem)) {
        set8((u8*)framebufferMem, addr - (BASE_ADDR + sizeof(registers)), val);
        refreshFlag = true;
    }
}

void Screen::write16(u32 addr, u16 val) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        set16((u8*)&registers, addr - BASE_ADDR, val);
        refreshFlag = true;
    } else if (addr >= (BASE_ADDR + sizeof(registers)) && addr < BASE_ADDR + sizeof(framebufferMem)) {
        set16((u8*)framebufferMem, addr - (BASE_ADDR + sizeof(registers)), val);
        refreshFlag = true;
    }
}

void Screen::reset() {
}

int Screen::refresh() {
    return 0;
}

void Screen::advance(int cycles) {
    if (wait - cycles <= 0) {
        wait = 0;
        registers.busy = false;
        refreshFlag = false;
    } else {
        wait = wait - cycles;
    }
}
