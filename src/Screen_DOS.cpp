/*
 * Copyright (c) 2024, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 *
 * DOS VGA/VESA screen implementation for PCD-68
 * Supports both Mode 13h (320x200) and VESA modes (640x480+)
 */

#ifdef __DJGPP__

#include "Screen_DOS.h"
#include <dpmi.h>
#include <go32.h>
#include <sys/farptr.h>
#include <sys/nearptr.h>
#include <pc.h>
#include <cstring>
#include <iostream>

// VGA register ports
#define VGA_DAC_WRITE_INDEX 0x3C8
#define VGA_DAC_DATA        0x3C9

// Mode 13h constants
#define MODE_13H            0x13
#define MODE_13H_WIDTH      320
#define MODE_13H_HEIGHT     200
#define VGA_MEMORY_BASE     0xA0000

// VESA constants
#define VESA_MODE_640x400   0x100
#define VESA_MODE_640x480   0x101
#define VESA_MODE_800x600   0x103

// Constructor
Screen_DOS::Screen_DOS(uint32_t start, uint32_t size, bool fullEmulation) :
    Screen(start, size),
    Peripheral(start, size) {

    this->fullEmulation = fullEmulation;
    this->vesaMode = false;
    this->lfbAddress = 0;
    this->lfbLinear = 0;
    this->lfbSelector = 0;
    this->videoMode = 0;
    this->vesaWidth = 0;
    this->vesaHeight = 0;
    this->vesaBpp = 8;
    this->offsetX = 0;
    this->offsetY = 0;
    this->lastFrame = new uint8_t[SCREEN_WIDTH * SCREEN_HEIGHT];
    // Initialize to 0xFF so first frame always draws (framebufferMem starts at 0)
    memset(this->lastFrame, 0xFF, SCREEN_WIDTH * SCREEN_HEIGHT);
    this->frameChanged = true;
}

Screen_DOS::~Screen_DOS() {
    // Free frame buffer
    delete[] lastFrame;

    // Restore text mode
    __dpmi_regs regs;
    regs.x.ax = 0x0003;  // Mode 3 = 80x25 text
    __dpmi_int(0x10, &regs);
}

// Set up grayscale palette for B/W display
void Screen_DOS::setupPalette() {
    // Set palette to grayscale
    // Index 0 = white (paper), Index 255 = black (ink)
    outportb(VGA_DAC_WRITE_INDEX, 0);

    for (int i = 0; i < 256; i++) {
        // Invert: 0 = white, 255 = black (E-Ink style)
        int gray = 63 - (i * 63 / 255);
        outportb(VGA_DAC_DATA, gray);  // R
        outportb(VGA_DAC_DATA, gray);  // G
        outportb(VGA_DAC_DATA, gray);  // B
    }
}

bool Screen_DOS::initMode13h() {
    __dpmi_regs regs;

    // Set Mode 13h (320x200x256)
    regs.x.ax = MODE_13H;
    __dpmi_int(0x10, &regs);

    videoMode = MODE_13H;
    vesaMode = false;
    lfbAddress = VGA_MEMORY_BASE;

    // Calculate centering offsets
    // Screen is 400x300, Mode 13h is 320x200
    // We need to scale down or crop
    offsetX = 0;
    offsetY = 0;

    setupPalette();
    return true;
}

bool Screen_DOS::initVesa() {
    __dpmi_regs regs;

    // Try to set VESA mode 640x400 (fits 400x300 nicely)
    regs.x.ax = 0x4F02;           // VESA set mode
    regs.x.bx = VESA_MODE_640x400 | 0x4000;  // Linear framebuffer bit
    __dpmi_int(0x10, &regs);

    if (regs.x.ax != 0x004F) {
        // Try 640x480 instead
        regs.x.ax = 0x4F02;
        regs.x.bx = VESA_MODE_640x480 | 0x4000;
        __dpmi_int(0x10, &regs);

        if (regs.x.ax != 0x004F) {
            std::cerr << "VESA modes not available, falling back to Mode 13h" << std::endl;
            return false;
        }

        vesaWidth = 640;
        vesaHeight = 480;
        videoMode = VESA_MODE_640x480;
    } else {
        vesaWidth = 640;
        vesaHeight = 400;
        videoMode = VESA_MODE_640x400;
    }

    // Get mode info to find LFB address
    // Allocate DOS memory for VESA info block
    int selector;
    int segment = __dpmi_allocate_dos_memory(256/16, &selector);
    if (segment < 0) {
        std::cerr << "Failed to allocate DOS memory for VESA info" << std::endl;
        return false;
    }

    // Get mode info
    regs.x.ax = 0x4F01;           // Get mode info
    regs.x.cx = videoMode;
    regs.x.di = 0;                // Offset in segment
    regs.x.es = segment;          // Segment
    __dpmi_int(0x10, &regs);

    if (regs.x.ax == 0x004F) {
        // Read LFB address from offset 40 in mode info block
        lfbAddress = _farpeekl(_dos_ds, segment * 16 + 40);
    }

    __dpmi_free_dos_memory(selector);

    if (lfbAddress == 0) {
        std::cerr << "Failed to get VESA LFB address" << std::endl;
        return false;
    }

    // Map physical LFB address to linear address using DPMI
    __dpmi_meminfo mi;
    mi.address = lfbAddress;
    mi.size = vesaWidth * vesaHeight;  // Size of framebuffer

    if (__dpmi_physical_address_mapping(&mi) != 0) {
        std::cerr << "Failed to map VESA LFB physical address" << std::endl;
        return false;
    }
    lfbLinear = mi.address;

    // Allocate a selector for the LFB
    lfbSelector = __dpmi_allocate_ldt_descriptors(1);
    if (lfbSelector < 0) {
        std::cerr << "Failed to allocate LDT descriptor for LFB" << std::endl;
        return false;
    }

    // Set the selector base and limit
    __dpmi_set_segment_base_address(lfbSelector, lfbLinear);
    __dpmi_set_segment_limit(lfbSelector, vesaWidth * vesaHeight - 1);

    vesaMode = true;

    // Calculate centering offsets
    offsetX = (vesaWidth - SCREEN_WIDTH) / 2;
    offsetY = (vesaHeight - SCREEN_HEIGHT) / 2;

    setupPalette();
    return true;
}

int Screen_DOS::init() {
    registers.busy = false;

    // Try VESA first, fall back to Mode 13h
    if (!initVesa()) {
        if (!initMode13h()) {
            std::cerr << "Failed to initialize video mode" << std::endl;
            return -1;
        }
    }

    return 0;
}

void Screen_DOS::reset() {
    Screen::reset();
    refreshFlag = true;

    // Clear the video memory
    if (vesaMode) {
        // Clear VESA framebuffer using the mapped selector
        for (int y = 0; y < vesaHeight; y++) {
            for (int x = 0; x < vesaWidth; x++) {
                _farpokeb(lfbSelector, y * vesaWidth + x, 0);
            }
        }
    } else {
        // Clear Mode 13h framebuffer
        for (int i = 0; i < MODE_13H_WIDTH * MODE_13H_HEIGHT; i++) {
            _farpokeb(_dos_ds, VGA_MEMORY_BASE + i, 0);
        }
    }
}

void Screen_DOS::putPixelMode13h(int x, int y, uint8_t color) {
    // Scale 400x300 to 320x200 (80% x 66%)
    // Simple nearest-neighbor scaling
    int scaledX = x * MODE_13H_WIDTH / SCREEN_WIDTH;
    int scaledY = y * MODE_13H_HEIGHT / SCREEN_HEIGHT;

    if (scaledX >= 0 && scaledX < MODE_13H_WIDTH &&
        scaledY >= 0 && scaledY < MODE_13H_HEIGHT) {
        _farpokeb(_dos_ds, VGA_MEMORY_BASE + scaledY * MODE_13H_WIDTH + scaledX, color);
    }
}

void Screen_DOS::putPixelVesa(int x, int y, uint8_t color) {
    int destX = x + offsetX;
    int destY = y + offsetY;

    if (destX >= 0 && destX < vesaWidth &&
        destY >= 0 && destY < vesaHeight) {
        _farpokeb(lfbSelector, destY * vesaWidth + destX, color);
    }
}

int Screen_DOS::refresh() {
    if (Screen::refresh() != 0) {
        return -1;
    }

    if (!refreshFlag) {
        return 0;
    }

    if (wait == 0) {
        registers.busy = true;
        if (fullEmulation) {
            wait = REFRESH_INTERVAL;
        } else {
            wait = 1;
        }
    }

    // E-Ink emulation effects (simplified for DOS)
    uint8_t colorWhite, colorBlack;

    if (fullEmulation && wait > 1) {
        // Approximate E-Ink refresh cycling
        if (wait < (REFRESH_INTERVAL * 0.5)) {
            colorWhite = 0x40;  // Dark gray
            colorBlack = 0xC0;  // Light gray
        } else {
            colorWhite = 0xE0;  // Near white
            colorBlack = 0x10;  // Near black
        }
    } else {
        // Final state: clean B/W
        colorWhite = 0x00;  // White (index 0 in our grayscale palette)
        colorBlack = 0xFF;  // Black (index 255)
    }

    // Copy framebuffer to video memory
    if (vesaMode) {
        // VESA mode: 1:1 pixel mapping with centering
        int baseOffset = offsetY * vesaWidth + offsetX;
        for (int y = 0; y < SCREEN_HEIGHT; y++) {
            int lineOffset = baseOffset + y * vesaWidth;
            int srcOffset = y * SCREEN_WIDTH;
            for (int x = 0; x < SCREEN_WIDTH; x++) {
                uint8_t pixel = framebufferMem[srcOffset + x];
                uint8_t color = (pixel == 0xFF) ? colorBlack : colorWhite;
                _farpokeb(lfbSelector, lineOffset + x, color);
            }
        }
    } else {
        // Mode 13h: scaled down
        for (int y = 0; y < SCREEN_HEIGHT; y++) {
            int scaledY = y * MODE_13H_HEIGHT / SCREEN_HEIGHT;
            int srcOffset = y * SCREEN_WIDTH;
            int dstBase = scaledY * MODE_13H_WIDTH;
            for (int x = 0; x < SCREEN_WIDTH; x++) {
                int scaledX = x * MODE_13H_WIDTH / SCREEN_WIDTH;
                uint8_t pixel = framebufferMem[srcOffset + x];
                uint8_t color = (pixel == 0xFF) ? colorBlack : colorWhite;
                _farpokeb(_dos_ds, VGA_MEMORY_BASE + dstBase + scaledX, color);
            }
        }
    }

    return 0;
}

// Simple 4x6 font for overlay (digits 0-9, some letters, colon, space)
static const uint8_t miniFont[43][6] = {
    // 0-9
    {0x6,0x9,0x9,0x9,0x9,0x6}, // 0
    {0x2,0x6,0x2,0x2,0x2,0x7}, // 1
    {0x6,0x9,0x2,0x4,0x8,0xF}, // 2
    {0xF,0x2,0x6,0x1,0x9,0x6}, // 3
    {0x2,0x6,0xA,0xF,0x2,0x2}, // 4
    {0xF,0x8,0xE,0x1,0x9,0x6}, // 5
    {0x6,0x8,0xE,0x9,0x9,0x6}, // 6
    {0xF,0x1,0x2,0x4,0x4,0x4}, // 7
    {0x6,0x9,0x6,0x9,0x9,0x6}, // 8
    {0x6,0x9,0x9,0x7,0x1,0x6}, // 9
    // A-Z (subset: C,K,L,P,S)
    {0x6,0x9,0xF,0x9,0x9,0x9}, // A (10)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // B (11) - unused
    {0x6,0x9,0x8,0x8,0x9,0x6}, // C (12)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // D (13)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // E (14)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // F (15)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // G (16)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // H (17)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // I (18)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // J (19)
    {0x9,0xA,0xC,0xC,0xA,0x9}, // K (20)
    {0x8,0x8,0x8,0x8,0x8,0xF}, // L (21)
    {0x9,0xF,0xF,0x9,0x9,0x9}, // M (22)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // N (23)
    {0x6,0x9,0x9,0x9,0x9,0x6}, // O (24)
    {0xE,0x9,0x9,0xE,0x8,0x8}, // P (25)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // Q (26)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // R (27)
    {0x6,0x8,0x6,0x1,0x9,0x6}, // S (28)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // T (29)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // U (30)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // V (31)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // W (32)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // X (33)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // Y (34)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // Z (35)
    // Special chars
    {0x0,0x0,0x0,0x0,0x0,0x0}, // space (36)
    {0x0,0x4,0x0,0x0,0x4,0x0}, // : (37)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // / (38)
    {0x0,0x0,0x0,0x0,0x0,0x0}, // unused
    {0x0,0x0,0x0,0x0,0x0,0x0}, // unused
    {0x0,0x0,0x0,0x0,0x0,0x0}, // unused
    {0x0,0x0,0x0,0x0,0x0,0x0}, // unused
};

void Screen_DOS::drawOverlayText(int x, int y, const char* text) {
    const int charWidth = 5;  // 4 pixels + 1 spacing
    const int charHeight = 6;

    // Calculate text width and clear background first
    int textLen = 0;
    while (text[textLen] != '\0') textLen++;
    int bgWidth = textLen * charWidth + 2;
    int bgHeight = charHeight + 2;

    // Draw background (white = 0x00 in our palette)
    for (int py = y - 1; py < y + bgHeight - 1; py++) {
        for (int px = x - 1; px < x + bgWidth - 1; px++) {
            if (vesaMode) {
                if (px >= 0 && px < vesaWidth && py >= 0 && py < vesaHeight) {
                    _farpokeb(lfbSelector, py * vesaWidth + px, 0x00);
                }
            } else {
                if (px >= 0 && px < 320 && py >= 0 && py < 200) {
                    _farpokeb(_dos_ds, 0xA0000 + py * 320 + px, 0x00);
                }
            }
        }
    }

    for (int i = 0; text[i] != '\0'; i++) {
        char c = text[i];
        int fontIndex = -1;

        if (c >= '0' && c <= '9') {
            fontIndex = c - '0';
        } else if (c >= 'A' && c <= 'Z') {
            fontIndex = 10 + (c - 'A');
        } else if (c >= 'a' && c <= 'z') {
            fontIndex = 10 + (c - 'a');
        } else if (c == ' ') {
            fontIndex = 36;
        } else if (c == ':') {
            fontIndex = 37;
        }

        if (fontIndex >= 0 && fontIndex < 43) {
            // Draw character
            for (int row = 0; row < charHeight; row++) {
                uint8_t bits = miniFont[fontIndex][row];
                for (int col = 0; col < 4; col++) {
                    if (bits & (0x8 >> col)) {
                        int px = x + i * charWidth + col;
                        int py = y + row;
                        if (vesaMode) {
                            if (px >= 0 && px < vesaWidth && py >= 0 && py < vesaHeight) {
                                _farpokeb(lfbSelector, py * vesaWidth + px, 0xFF);
                            }
                        } else {
                            if (px >= 0 && px < 320 && py >= 0 && py < 200) {
                                _farpokeb(_dos_ds, 0xA0000 + py * 320 + px, 0xFF);
                            }
                        }
                    }
                }
            }
        }
    }
}

#endif // __DJGPP__
