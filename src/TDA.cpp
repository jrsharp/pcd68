#include "TDA.h"
#include <iostream>

TDA::TDA(CPU* cpu, Screen* screen, uint32_t start, uint32_t size) :
    Peripheral(start, size) {
    this->cpu = cpu;
    this->screen = screen;
    refreshFlag = false;
}

void TDA::reset() {
    registers.mode = COL80; // Default to 80-column font
    memset(textMapMem, ' ', sizeof(textMapMem));
    refreshFlag = true;
}

// transfer / flush the character map to the frame buffer
void TDA::update() {
    if (refreshFlag) {
        //u8* framebufferStart = systemRam + 0x10000;
        u8* framebufferStart = screen->framebufferMem;
        u8* framebufferEnd = framebufferStart + (400 * 300);
        for (u8* framebufferPtr = framebufferStart; framebufferPtr < framebufferEnd; framebufferPtr++) {
            int fromStart = (long)framebufferPtr - (long)framebufferStart;
            int xPos = fromStart % 400;
            int yPos = fromStart / 400;
            if (registers.mode == COL80) {
                if (yPos < 299) { // in 80-col mode, do not render text on bottom, left-over line
                    int charX = xPos / 5;
                    int charY = yPos / 13;
                    int charXPos = xPos % 5;
                    int charYPos = yPos % 13;
                    unsigned char c = textMapMem[(charY * 80) + charX];
                    if (c >= 32 && c <= 127) { // 80-col charset is limited
                        //printf("%d: (%d, %d), (%d, %d): %c -- (%d, %d)\n", fromStart, xPos, yPos, charX, charY, c, charXPos, charYPos);
                        int charOffset = c - 32;
                        u8 lineValue = five_by_thirteen[(charOffset * 16) + charYPos];
                        u8 newLineValue = 0x00;
                        for (int b = 0; b < 8; b++) {
                            newLineValue |= ((lineValue >> b) & 0b1) << (7 - b);
                        }
                        if (newLineValue & (1 << charXPos)) {
                            *framebufferPtr = 0x00;
                            //cpu->write8(Screen::BASE_ADDR + sizeof(Screen::Registers) + fromStart, 0x00);
                        } else {
                            *framebufferPtr = 0xFF;
                            //cpu->write8(Screen::BASE_ADDR + sizeof(Screen::Registers) + fromStart, 0xFF);
                        }
                    } else {
                        // Fill white:
                        *framebufferPtr = 0xFF;
                        //cpu->write8(Screen::BASE_ADDR + sizeof(Screen::Registers) + fromStart, 0xFF);
                    }
                } else {
                    // Fill white:
                    *framebufferPtr = 0xFF;
                    //cpu->write8(Screen::BASE_ADDR + sizeof(Screen::Registers) + fromStart, 0xFF);
                }
            } else if (registers.mode == COL50) {
                if (yPos < 296) { // in 50-col mode, do not render text on bottom, left-over lines
                    int charX = xPos / 8;
                    int charY = yPos / 8;
                    int charXPos = xPos % 8;
                    int charYPos = yPos % 8;
                    unsigned char c = textMapMem[(charY * 50) + charX];
                    //printf("%d: (%d, %d), (%d, %d): %c -- (%d, %d)\n", fromStart, xPos, yPos, charX, charY, c, charXPos, charYPos);
                    u8 lineValue = 0x00;
                    if (c >= 0 && c < 128) {
                        lineValue = font8x8_basic[c][charYPos];
                    } else if (c >= 128 && c < 160) {
                        lineValue = font8x8_block[c - 128][charYPos];
                    }
                    if (lineValue & (1 << charXPos)) {
                        *framebufferPtr = 0x00;
                        //cpu->write8(Screen::BASE_ADDR + sizeof(Screen::Registers) + fromStart, 0x00);
                    } else {
                        *framebufferPtr = 0xFF;
                        //cpu->write8(Screen::BASE_ADDR + sizeof(Screen::Registers) + fromStart, 0xFF);
                    }
                } else {
                    // Fill white:
                    *framebufferPtr = 0xFF;
                    //cpu->write8(Screen::BASE_ADDR + sizeof(Screen::Registers) + fromStart, 0xFF);
                }
            }
        }
        // Signal screen for refresh
        screen->refreshFlag = true;
        // Done for now, wait
        refreshFlag = false;
    }
}

u8 TDA::read8(u32 addr) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        return get8((u8*)&registers, addr - BASE_ADDR);
    } else if (addr >= (BASE_ADDR + sizeof(registers)) && addr < BASE_ADDR + sizeof(textMapMem)) {
        return get8((u8*)textMapMem, addr - (BASE_ADDR + sizeof(registers)));
    }
    return 0;
}

u16 TDA::read16(u32 addr) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        return get16((u8*)&registers, addr - BASE_ADDR);
    } else if (addr >= (BASE_ADDR + sizeof(registers)) && addr < BASE_ADDR + sizeof(textMapMem)) {
        return get16((u8*)textMapMem, addr - (BASE_ADDR + sizeof(registers)));
    }
    return 0;
}

void TDA::write8(u32 addr, u8 val) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        set8((u8*)&registers, addr - BASE_ADDR, val);
        refreshFlag = true;
    } else if (addr >= (BASE_ADDR + sizeof(registers)) && addr < BASE_ADDR + sizeof(textMapMem)) {
        set8((u8*)textMapMem, addr - (BASE_ADDR + sizeof(registers)), val);
        refreshFlag = true;
    }
}

void TDA::write16(u32 addr, u16 val) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        set16((u8*)&registers, addr - BASE_ADDR, val);
        refreshFlag = true;
    } else if (addr >= (BASE_ADDR + sizeof(registers)) && addr < BASE_ADDR + sizeof(textMapMem)) {
        set16((u8*)textMapMem, addr - (BASE_ADDR + sizeof(registers)), val);
        refreshFlag = true;
    }
}
