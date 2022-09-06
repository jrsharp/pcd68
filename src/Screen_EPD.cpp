#include "Screen_EPD.h"
#include <iostream>

EpdSpi Screen::io;
Gdew042t2 Screen::display(Screen::io);

// C'tor
Screen::Screen(uint32_t start, uint32_t size) :
    Peripheral(start, size) {
    refreshFlag = false;
    /*
    io = new EpdSpi();
    display = new Gdew042t2(*io);
    */
}

// Init EPD
int Screen::init() {
    registers.busy = false;
    //framebufferMem = (u8*)malloc((400 * 300));
    if (framebufferMem == nullptr) {
        return -1;
    }
    display.init(false);
    display.fillScreen(EPD_WHITE);
    display.update();
    return 0;
}

void Screen::reset() {
    refreshFlag = true;
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

// Refresh screen
int Screen::refresh() {
    if (refreshFlag) {
        registers.busy = true;
        // copy 
        u8 oneBB = 0xFF; // start with white
        for (int i = 0; i < (400 * 300); i++) {
            if (framebufferMem[i] == 0x00) { // black pixel found
                oneBB = (oneBB & ~(1 << (7 - (i % 8))));
            } else if (framebufferMem[i] == 0xFF) { // white pixel found
                oneBB = (oneBB | (1 << (7 - (i % 8))));
            }
            if (i % 8 == 7) { // Filled a byte?
                display._buffer[i / 8] = oneBB;
                oneBB = 0xFF;
            }
        }
        display.update();
        registers.busy = false;
        refreshFlag = false;
    }

    return 0;
}
