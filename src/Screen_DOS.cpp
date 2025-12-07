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

// Mode 12h constants (VGA 640x480x16, planar)
#define MODE_12H            0x12
#define MODE_12H_WIDTH      640
#define MODE_12H_HEIGHT     480
#define MODE_12H_STRIDE     80   // 640 pixels / 8 bits per byte

// VGA sequencer and graphics controller ports
#define VGA_SEQ_INDEX       0x3C4
#define VGA_SEQ_DATA        0x3C5
#define VGA_GC_INDEX        0x3CE
#define VGA_GC_DATA         0x3CF

// VGA register indices
#define VGA_SEQ_MAP_MASK    0x02
#define VGA_GC_MODE         0x05
#define VGA_GC_BIT_MASK     0x08

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
    this->modeType = MODE_TYPE_VGA_13H;  // Default fallback
    this->lfbAddress = 0;
    this->lfbLinear = 0;
    this->lfbSelector = 0;
    this->videoMode = 0;
    this->vesaWidth = 0;
    this->vesaHeight = 0;
    this->vesaBpp = 8;
    this->offsetX = 0;
    this->offsetY = 0;

    // Frame caching
    this->lastFrame = new uint8_t[SCREEN_WIDTH * SCREEN_HEIGHT];
    memset(this->lastFrame, 0xFF, SCREEN_WIDTH * SCREEN_HEIGHT);
    this->frameChanged = true;

    // Dirty tile tracking (bit array - 1900 tiles / 8 = 238 bytes)
    this->dirtyTiles = new uint8_t[(NUM_TILES + 7) / 8];
    memset(this->dirtyTiles, 0xFF, (NUM_TILES + 7) / 8);  // All dirty initially

    // Packed framebuffer for Mode 12h (50 bytes per line * 300 lines = 15000 bytes)
    this->packedFrame = new uint8_t[SCREEN_WIDTH / 8 * SCREEN_HEIGHT];
    memset(this->packedFrame, 0, SCREEN_WIDTH / 8 * SCREEN_HEIGHT);
}

Screen_DOS::~Screen_DOS() {
    // Free buffers
    delete[] lastFrame;
    delete[] dirtyTiles;
    delete[] packedFrame;

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
    modeType = MODE_TYPE_VGA_13H;
    lfbAddress = VGA_MEMORY_BASE;

    // Calculate centering offsets
    // Screen is 400x300, Mode 13h is 320x200
    // We need to scale down or crop
    offsetX = 0;
    offsetY = 0;

    setupPalette();
    std::cerr << "Using VGA Mode 13h (320x200x256) - scaled display" << std::endl;
    return true;
}

// Set up 16-color palette for Mode 12h
void Screen_DOS::setupPalette16() {
    // In Mode 12h, we have 16 colors (indices 0-15)
    // Set up simple black and white:
    // Index 0 = white (background/paper)
    // Index 15 = black (foreground/ink)
    outportb(VGA_DAC_WRITE_INDEX, 0);
    // Color 0: white
    outportb(VGA_DAC_DATA, 63);  // R
    outportb(VGA_DAC_DATA, 63);  // G
    outportb(VGA_DAC_DATA, 63);  // B

    // Colors 1-14: grayscale ramp (useful for debugging)
    for (int i = 1; i < 15; i++) {
        int gray = 63 - (i * 63 / 15);
        outportb(VGA_DAC_DATA, gray);
        outportb(VGA_DAC_DATA, gray);
        outportb(VGA_DAC_DATA, gray);
    }

    // Color 15: black
    outportb(VGA_DAC_DATA, 0);   // R
    outportb(VGA_DAC_DATA, 0);   // G
    outportb(VGA_DAC_DATA, 0);   // B
}

bool Screen_DOS::initMode12h() {
    __dpmi_regs regs;

    // Set Mode 12h (640x480x16 planar)
    regs.x.ax = MODE_12H;
    __dpmi_int(0x10, &regs);

    videoMode = MODE_12H;
    vesaMode = false;
    modeType = MODE_TYPE_VGA_12H;
    lfbAddress = VGA_MEMORY_BASE;

    // Calculate centering offsets
    // Screen is 400x300, Mode 12h is 640x480
    offsetX = (MODE_12H_WIDTH - SCREEN_WIDTH) / 2;    // 120
    offsetY = (MODE_12H_HEIGHT - SCREEN_HEIGHT) / 2;  // 90

    // Set up VGA for writing to all planes at once
    // This gives us effective 1-bit mode: all planes same = color 0 or 15
    outportb(VGA_SEQ_INDEX, VGA_SEQ_MAP_MASK);
    outportb(VGA_SEQ_DATA, 0x0F);  // Enable writes to all 4 planes

    // Set write mode 0 (direct write)
    outportb(VGA_GC_INDEX, VGA_GC_MODE);
    outportb(VGA_GC_DATA, 0x00);

    // Set bit mask to all bits
    outportb(VGA_GC_INDEX, VGA_GC_BIT_MASK);
    outportb(VGA_GC_DATA, 0xFF);

    setupPalette16();

    std::cerr << "Using VGA Mode 12h (640x480x16) - native resolution" << std::endl;
    return true;
}

// Helper to write a byte to Mode 12h planar memory
void Screen_DOS::mode12hWriteByte(int offset, uint8_t value) {
    _farpokeb(_dos_ds, VGA_MEMORY_BASE + offset, value);
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
    modeType = MODE_TYPE_VESA;

    // Calculate centering offsets
    offsetX = (vesaWidth - SCREEN_WIDTH) / 2;
    offsetY = (vesaHeight - SCREEN_HEIGHT) / 2;

    setupPalette();
    std::cerr << "Using VESA mode " << vesaWidth << "x" << vesaHeight << std::endl;
    return true;
}

int Screen_DOS::init() {
    registers.busy = false;

    // Try VESA first, then Mode 12h, finally Mode 13h
    if (!initVesa()) {
        std::cerr << "VESA not available, trying VGA Mode 12h..." << std::endl;
        if (!initMode12h()) {
            std::cerr << "Mode 12h failed, falling back to Mode 13h..." << std::endl;
            if (!initMode13h()) {
                std::cerr << "Failed to initialize any video mode" << std::endl;
                return -1;
            }
        }
    }

    return 0;
}

void Screen_DOS::reset() {
    Screen::reset();
    refreshFlag = true;

    // Clear the video memory based on mode type
    switch (modeType) {
        case MODE_TYPE_VESA:
            // Clear VESA framebuffer using the mapped selector
            for (int y = 0; y < vesaHeight; y++) {
                for (int x = 0; x < vesaWidth; x++) {
                    _farpokeb(lfbSelector, y * vesaWidth + x, 0);
                }
            }
            break;

        case MODE_TYPE_VGA_12H:
            // Clear Mode 12h planar framebuffer (write 0 = white to all planes)
            // Ensure we're writing to all planes
            outportb(VGA_SEQ_INDEX, VGA_SEQ_MAP_MASK);
            outportb(VGA_SEQ_DATA, 0x0F);
            for (int i = 0; i < MODE_12H_STRIDE * MODE_12H_HEIGHT; i++) {
                _farpokeb(_dos_ds, VGA_MEMORY_BASE + i, 0x00);
            }
            break;

        case MODE_TYPE_VGA_13H:
        default:
            // Clear Mode 13h framebuffer
            for (int i = 0; i < MODE_13H_WIDTH * MODE_13H_HEIGHT; i++) {
                _farpokeb(_dos_ds, VGA_MEMORY_BASE + i, 0);
            }
            break;
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

void Screen_DOS::putPixelMode12h(int x, int y, uint8_t color) {
    int destX = x + offsetX;
    int destY = y + offsetY;

    if (destX >= 0 && destX < MODE_12H_WIDTH &&
        destY >= 0 && destY < MODE_12H_HEIGHT) {
        // Calculate byte offset and bit position
        int byteOffset = destY * MODE_12H_STRIDE + (destX >> 3);
        int bitPos = 7 - (destX & 7);

        // Read current byte, modify bit, write back
        // For Mode 12h, we need to use read-modify-write
        // Set bit mask for single pixel
        outportb(VGA_GC_INDEX, VGA_GC_BIT_MASK);
        outportb(VGA_GC_DATA, 1 << bitPos);

        // Read to load latches (required for read-modify-write)
        volatile uint8_t dummy = _farpeekb(_dos_ds, VGA_MEMORY_BASE + byteOffset);
        (void)dummy;

        // Write the pixel (color 0=white, 15=black -> write 0x00 or 0xFF)
        _farpokeb(_dos_ds, VGA_MEMORY_BASE + byteOffset, color ? 0xFF : 0x00);
    }
}

// ============================================================================
// Dirty-rectangle tracking
// ============================================================================

void Screen_DOS::markTileDirty(int tileX, int tileY) {
    if (tileX >= 0 && tileX < TILES_X && tileY >= 0 && tileY < TILES_Y) {
        int tileIndex = tileY * TILES_X + tileX;
        dirtyTiles[tileIndex / 8] |= (1 << (tileIndex % 8));
    }
}

bool Screen_DOS::isTileDirty(int tileX, int tileY) const {
    if (tileX >= 0 && tileX < TILES_X && tileY >= 0 && tileY < TILES_Y) {
        int tileIndex = tileY * TILES_X + tileX;
        return (dirtyTiles[tileIndex / 8] & (1 << (tileIndex % 8))) != 0;
    }
    return false;
}

void Screen_DOS::clearDirtyTiles() {
    memset(dirtyTiles, 0, (NUM_TILES + 7) / 8);
}

// Compare current framebuffer with last frame and mark dirty tiles
void Screen_DOS::checkDirtyTiles() {
    for (int ty = 0; ty < TILES_Y; ty++) {
        for (int tx = 0; tx < TILES_X; tx++) {
            // Check if any pixel in this tile changed
            bool dirty = false;
            int baseX = tx * TILE_SIZE;
            int baseY = ty * TILE_SIZE;

            for (int py = 0; py < TILE_SIZE && !dirty; py++) {
                int y = baseY + py;
                if (y >= SCREEN_HEIGHT) break;

                int rowOffset = y * SCREEN_WIDTH + baseX;
                for (int px = 0; px < TILE_SIZE; px++) {
                    int x = baseX + px;
                    if (x >= SCREEN_WIDTH) break;

                    int idx = rowOffset + px;
                    if (framebufferMem[idx] != lastFrame[idx]) {
                        dirty = true;
                        break;
                    }
                }
            }

            if (dirty) {
                markTileDirty(tx, ty);
            }
        }
    }
}

// ============================================================================
// Optimized pixel packing (8 pixels -> 1 byte)
// ============================================================================

// Pack 8 pixels into 1 byte
// src points to 8 consecutive pixels (each 0x00 or 0xFF)
// Returns packed byte where bit 7 = first pixel, bit 0 = last pixel
//
// Optimized approach: read as 32-bit words and use bit manipulation
// This reduces memory accesses from 8 to 2
static inline uint8_t packPixels8(const uint8_t* src) {
    // Read 8 bytes as two 32-bit words (little-endian on x86)
    const uint32_t* src32 = reinterpret_cast<const uint32_t*>(src);
    uint32_t lo = src32[0];  // pixels 0-3
    uint32_t hi = src32[1];  // pixels 4-7

    // Extract MSB of each byte using bit manipulation
    // For 0xFF bytes, MSB is 1; for 0x00 bytes, MSB is 0
    // We mask with 0x80808080 to get the MSBs, then compress them

    uint8_t result = 0;

    // Pixels 0-3 (from lo word)
    // Byte 0 (pixels[0]) -> bit 7
    // Byte 1 (pixels[1]) -> bit 6
    // Byte 2 (pixels[2]) -> bit 5
    // Byte 3 (pixels[3]) -> bit 4
    if (lo & 0x00000080) result |= 0x80;  // pixel 0 -> bit 7
    if (lo & 0x00008000) result |= 0x40;  // pixel 1 -> bit 6
    if (lo & 0x00800000) result |= 0x20;  // pixel 2 -> bit 5
    if (lo & 0x80000000) result |= 0x10;  // pixel 3 -> bit 4

    // Pixels 4-7 (from hi word)
    if (hi & 0x00000080) result |= 0x08;  // pixel 4 -> bit 3
    if (hi & 0x00008000) result |= 0x04;  // pixel 5 -> bit 2
    if (hi & 0x00800000) result |= 0x02;  // pixel 6 -> bit 1
    if (hi & 0x80000000) result |= 0x01;  // pixel 7 -> bit 0

    return result;
}

// Pack entire row of pixels (srcStride bytes = srcStride*8 pixels)
void Screen_DOS::packPixelsFast(const uint8_t* src, uint8_t* dst, int byteCount) {
    for (int i = 0; i < byteCount; i++) {
        dst[i] = packPixels8(src + i * 8);
    }
}

// ============================================================================
// Optimized Mode 12h blitter with dirty-rect support
// ============================================================================

// Blit a single 8x8 tile to Mode 12h VGA
void Screen_DOS::blitMode12hTile(int tileX, int tileY) {
    int srcX = tileX * TILE_SIZE;
    int srcY = tileY * TILE_SIZE;
    int dstX = srcX + offsetX;
    int dstY = srcY + offsetY;

    // Tile is 8 pixels wide = 1 byte in packed format
    int dstByteX = dstX / 8;

    for (int row = 0; row < TILE_SIZE; row++) {
        int y = srcY + row;
        if (y >= SCREEN_HEIGHT) break;

        // Pack 8 pixels from this row of the tile
        int srcOffset = y * SCREEN_WIDTH + srcX;
        uint8_t packed = packPixels8(&framebufferMem[srcOffset]);

        // Write to VGA
        int vgaOffset = (dstY + row) * MODE_12H_STRIDE + dstByteX;
        _farpokeb(_dos_ds, VGA_MEMORY_BASE + vgaOffset, packed);

        // Update packed frame cache
        int packedOffset = y * (SCREEN_WIDTH / 8) + tileX;
        packedFrame[packedOffset] = packed;
    }
}

// Full optimized blit for Mode 12h with dirty-rect tracking
void Screen_DOS::blitMode12hOptimized() {
    // Set up VGA for bulk writes
    outportb(VGA_SEQ_INDEX, VGA_SEQ_MAP_MASK);
    outportb(VGA_SEQ_DATA, 0x0F);  // All planes
    outportb(VGA_GC_INDEX, VGA_GC_BIT_MASK);
    outportb(VGA_GC_DATA, 0xFF);  // All bits

    // Check which tiles are dirty
    checkDirtyTiles();

    // Blit only dirty tiles
    for (int ty = 0; ty < TILES_Y; ty++) {
        for (int tx = 0; tx < TILES_X; tx++) {
            if (isTileDirty(tx, ty)) {
                blitMode12hTile(tx, ty);
            }
        }
    }

    // Update last frame buffer for next comparison
    memcpy(lastFrame, framebufferMem, SCREEN_WIDTH * SCREEN_HEIGHT);

    // Clear dirty flags
    clearDirtyTiles();
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

    // Copy framebuffer to video memory based on mode type
    switch (modeType) {
        case MODE_TYPE_VESA: {
            // VESA mode with dirty-rect tracking
            checkDirtyTiles();

            int baseOffset = offsetY * vesaWidth + offsetX;

            for (int ty = 0; ty < TILES_Y; ty++) {
                for (int tx = 0; tx < TILES_X; tx++) {
                    if (!isTileDirty(tx, ty)) continue;

                    // Blit this dirty tile
                    int tileStartX = tx * TILE_SIZE;
                    int tileStartY = ty * TILE_SIZE;

                    for (int py = 0; py < TILE_SIZE; py++) {
                        int y = tileStartY + py;
                        if (y >= SCREEN_HEIGHT) break;

                        int lineOffset = baseOffset + y * vesaWidth;
                        int srcOffset = y * SCREEN_WIDTH;

                        for (int px = 0; px < TILE_SIZE; px++) {
                            int x = tileStartX + px;
                            if (x >= SCREEN_WIDTH) break;

                            uint8_t pixel = framebufferMem[srcOffset + x];
                            uint8_t color = (pixel == 0xFF) ? colorBlack : colorWhite;
                            _farpokeb(lfbSelector, lineOffset + x, color);
                        }
                    }
                }
            }

            // Update last frame and clear dirty flags
            memcpy(lastFrame, framebufferMem, SCREEN_WIDTH * SCREEN_HEIGHT);
            clearDirtyTiles();
            break;
        }

        case MODE_TYPE_VGA_12H: {
            // Use optimized blitter with dirty-rect tracking
            blitMode12hOptimized();
            break;
        }

        case MODE_TYPE_VGA_13H:
        default: {
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
            break;
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

// Helper to draw a single pixel in overlay based on current mode
void Screen_DOS::drawOverlayPixel(int px, int py, bool black) {
    switch (modeType) {
        case MODE_TYPE_VESA:
            if (px >= 0 && px < vesaWidth && py >= 0 && py < vesaHeight) {
                _farpokeb(lfbSelector, py * vesaWidth + px, black ? 0xFF : 0x00);
            }
            break;

        case MODE_TYPE_VGA_12H:
            if (px >= 0 && px < MODE_12H_WIDTH && py >= 0 && py < MODE_12H_HEIGHT) {
                // For Mode 12h, we need to do read-modify-write for individual pixels
                int byteOffset = py * MODE_12H_STRIDE + (px >> 3);
                int bitPos = 7 - (px & 7);

                // Set bit mask for single pixel
                outportb(VGA_GC_INDEX, VGA_GC_BIT_MASK);
                outportb(VGA_GC_DATA, 1 << bitPos);

                // Ensure writing to all planes
                outportb(VGA_SEQ_INDEX, VGA_SEQ_MAP_MASK);
                outportb(VGA_SEQ_DATA, 0x0F);

                // Read to load latches
                volatile uint8_t dummy = _farpeekb(_dos_ds, VGA_MEMORY_BASE + byteOffset);
                (void)dummy;

                // Write (0xFF = black/color 15, 0x00 = white/color 0)
                _farpokeb(_dos_ds, VGA_MEMORY_BASE + byteOffset, black ? 0xFF : 0x00);
            }
            break;

        case MODE_TYPE_VGA_13H:
        default:
            if (px >= 0 && px < MODE_13H_WIDTH && py >= 0 && py < MODE_13H_HEIGHT) {
                _farpokeb(_dos_ds, VGA_MEMORY_BASE + py * MODE_13H_WIDTH + px, black ? 0xFF : 0x00);
            }
            break;
    }
}

void Screen_DOS::drawOverlayText(int x, int y, const char* text) {
    const int charWidth = 5;  // 4 pixels + 1 spacing
    const int charHeight = 6;

    // Get screen dimensions based on mode
    int screenW, screenH;
    switch (modeType) {
        case MODE_TYPE_VESA:
            screenW = vesaWidth;
            screenH = vesaHeight;
            break;
        case MODE_TYPE_VGA_12H:
            screenW = MODE_12H_WIDTH;
            screenH = MODE_12H_HEIGHT;
            break;
        case MODE_TYPE_VGA_13H:
        default:
            screenW = MODE_13H_WIDTH;
            screenH = MODE_13H_HEIGHT;
            break;
    }

    // Calculate text width and clear background first
    int textLen = 0;
    while (text[textLen] != '\0') textLen++;
    int bgWidth = textLen * charWidth + 2;
    int bgHeight = charHeight + 2;

    // Draw background (white)
    for (int py = y - 1; py < y + bgHeight - 1; py++) {
        for (int px = x - 1; px < x + bgWidth - 1; px++) {
            if (px >= 0 && px < screenW && py >= 0 && py < screenH) {
                drawOverlayPixel(px, py, false);  // white background
            }
        }
    }

    // Reset bit mask after background clear (for Mode 12h efficiency)
    if (modeType == MODE_TYPE_VGA_12H) {
        outportb(VGA_GC_INDEX, VGA_GC_BIT_MASK);
        outportb(VGA_GC_DATA, 0xFF);
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
                        if (px >= 0 && px < screenW && py >= 0 && py < screenH) {
                            drawOverlayPixel(px, py, true);  // black text
                        }
                    }
                }
            }
        }
    }

    // Reset bit mask after drawing (for Mode 12h)
    if (modeType == MODE_TYPE_VGA_12H) {
        outportb(VGA_GC_INDEX, VGA_GC_BIT_MASK);
        outportb(VGA_GC_DATA, 0xFF);
    }
}

#endif // __DJGPP__
