#define STB_TRUETYPE_IMPLEMENTATION
#define STBTT_STATIC

#include "TDA.h"
#include <iostream>

TDA::TDA(CPU* cpu, uint32_t start, uint32_t size) : Peripheral(start, size) {
    this->cpu = cpu;
    //stbtt_InitFont(&font, VT323_Regular_ttf, stbtt_GetFontOffsetForIndex(VT323_Regular_ttf, 0));
    stbtt_InitFont(&font, noto_sans, stbtt_GetFontOffsetForIndex(noto_sans, 0));
}

void TDA::reset() {
    // Default to 80-column font
    mode = COL80;
    memset(textMapMem, ' ', 80 * 23);

    // For testing... populate text buffer
    /*
    char c = ' ';
    for (int i = 0; i < 80 * 23; i++) {
        if (i < 96) {
            textMapMem[i] = 32 + i;
        } else {
            textMapMem[i] = c;
        }
    }
    strncpy(&textMapMem[(2 * 80) + 0], "Hello World!", 12);
    strncpy(&textMapMem[(12 * 80) + 0], "Hello World!", 12);
    strncpy(&textMapMem[(18 * 80) + 40], "Hello World!", 12);
    strncpy(&textMapMem[(22 * 80) + 0], "Hello World!", 12);
    strncpy(&textMapMem[(22 * 80) + 66], "Hello World!", 12);
    */
}

// transfer / flush the character map to the frame buffer
void TDA::update() {
    u8* framebufferStart = systemRam + 0x10000;
    u8* framebufferEnd = framebufferStart + (400 * 300);
    for (u8* framebufferPtr = framebufferStart; framebufferPtr < framebufferEnd; framebufferPtr++) {
        int fromStart = (long)framebufferPtr - (long)framebufferStart;
        int xPos = fromStart % 400;
        int yPos = fromStart / 400;
        if (mode == COL80) {
            if (yPos < 299) { // in 80-col mode, do not render text on bottom, left-over line
                int charX = xPos / 5;
                int charY = yPos / 13;
                int charXPos = xPos % 5;
                int charYPos = yPos % 13;
                char c = textMapMem[(charY * 80) + charX];
                if (c >= 32 && c <= 128) { // 80-col charset is limited
                    //printf("%d: (%d, %d), (%d, %d): %c -- (%d, %d)\n", fromStart, xPos, yPos, charX, charY, c, charXPos, charYPos);
                    int charOffset = c - 32;
                    u8 lineValue = five_by_thirteen[(charOffset * 16) + charYPos];
                    u8 newLineValue = 0x00;
                    for (int b = 0; b < 8; b++) {
                        newLineValue |= ((lineValue >> b) & 0b1) << (7 - b);
                    }
                    if (newLineValue & (1 << charXPos)) {
                        *framebufferPtr = 0x00;
                    } else {
                        *framebufferPtr = 0xFF;
                    }
                }
            } else {
                // Fill white:
                *framebufferPtr = 0xFF;
            }
        } else if (mode == COL40) {
            int charX = xPos / 10;
            int charY = yPos / 15;
            int charXPos = xPos % 10;
            int charYPos = yPos % 15;
            char c = textMapMem[(charY * 40) + charX];
            //printf("%d: (%d, %d), (%d, %d): %c -- (%d, %d)\n", fromStart, xPos, yPos, charX, charY, c, charXPos, charYPos);
            if (c >= 32 && c <= 128) {
                unsigned char *bitmap;
                int w, h, s = 22;

                bitmap = stbtt_GetCodepointBitmap(&font, 0, stbtt_ScaleForPixelHeight(&font, s), c, &w, &h, 0, 0);
                if (charYPos < h && charXPos < w) {
                    if ((bitmap[charYPos * w + charXPos] >> 5) > 0) {
                        *framebufferPtr = 0x00;
                    } else {
                        *framebufferPtr = 0xFF;
                    }
                }
                /*
                for (int j = 0; j < h; ++j) {
                    for (int i = 0; i < w; ++i) {
                        putchar(" .:ioVM@"[bitmap[j * w + i] >> 5]);
                    }
                    putchar('\n');
                }
                */
            }
        }
    }
}

u8 TDA::read8(u32 addr) {
    // TODO: memory for registers
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(textMapMem)) {
        return get8((u8*)textMapMem, addr - BASE_ADDR);
    }
    return 0;
}

u16 TDA::read16(u32 addr) {
    // TODO: memory for registers
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(textMapMem)) {
        return get16((u8*)textMapMem, addr - BASE_ADDR);
    }
    return 0;
}

void TDA::write8(u32 addr, u8 val) {
    // TODO: memory for registers
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(textMapMem)) {
        set8((u8*)textMapMem, addr - BASE_ADDR, val);
    }
}

void TDA::write16(u32 addr, u16 val) {
    // TODO: memory for registers
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(textMapMem)) {
        set16((u8*)textMapMem, addr - BASE_ADDR, val);
    }
}
