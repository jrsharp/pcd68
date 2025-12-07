/*
 * Copyright (c) 2024, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 *
 * DOS VGA/VESA screen implementation for PCD-68
 * Requires DJGPP with DPMI support
 */

#pragma once

#include "Screen.h"
#include <stdint.h>

class Screen_DOS : public Screen {

public:
    /**
     * Constructor
     *
     * @param start base address
     * @param size size of memory
     * @param fullEmulation enable E-Ink emulation effects
     */
    Screen_DOS(uint32_t start, uint32_t size, bool fullEmulation = false);

    /**
     * Initialize DOS video mode
     * @return 0 on success, non-zero on failure
     */
    virtual int init() override;

    /**
     * Reset the screen
     */
    virtual void reset() override;

    /**
     * Refresh the display from framebuffer
     * @return 0 on success, non-zero on failure
     */
    virtual int refresh() override;

    /**
     * Shutdown and restore text mode
     */
    ~Screen_DOS();

    /**
     * Draw overlay text at screen position (in pixels)
     */
    void drawOverlayText(int x, int y, const char* text);

    /**
     * Get video dimensions for overlay positioning
     */
    int getVideoWidth() const {
        switch (modeType) {
            case MODE_TYPE_VESA: return vesaWidth;
            case MODE_TYPE_VGA_12H: return 640;
            case MODE_TYPE_VGA_13H: default: return 320;
        }
    }
    int getVideoHeight() const {
        switch (modeType) {
            case MODE_TYPE_VESA: return vesaHeight;
            case MODE_TYPE_VGA_12H: return 480;
            case MODE_TYPE_VGA_13H: default: return 200;
        }
    }

private:
    bool fullEmulation;
    bool vesaMode;           // True if using VESA, false for Mode 13h
    uint32_t lfbAddress;     // Linear framebuffer address (VESA)
    int videoMode;           // Current video mode

    // VESA mode info
    int vesaWidth;
    int vesaHeight;
    int vesaBpp;
    int lfbSelector;         // DPMI selector for LFB access
    uint32_t lfbLinear;      // Linear address after DPMI mapping

    // Scaling offsets for centering
    int offsetX;
    int offsetY;

    // Frame caching for performance
    uint8_t* lastFrame;
    bool frameChanged;

    // Dirty-rectangle tracking (8x8 pixel tiles)
    static const int TILE_SIZE = 8;
    static const int TILES_X = (SCREEN_WIDTH + TILE_SIZE - 1) / TILE_SIZE;   // 50 tiles (400/8)
    static const int TILES_Y = (SCREEN_HEIGHT + TILE_SIZE - 1) / TILE_SIZE;  // 38 tiles (ceil(300/8))
    static const int NUM_TILES = TILES_X * TILES_Y;  // 50 * 38 = 1900 tiles
    uint8_t* dirtyTiles;  // Bit array: 1 = tile needs redraw

    // Packed framebuffer for Mode 12h (1 bit per pixel, 8 pixels per byte)
    uint8_t* packedFrame;

    // Mark tile as dirty
    void markTileDirty(int tileX, int tileY);
    bool isTileDirty(int tileX, int tileY) const;
    void clearDirtyTiles();
    void checkDirtyTiles();

    // Optimized blitters
    void blitMode12hOptimized();
    void blitMode12hTile(int tileX, int tileY);
    void packPixelsFast(const uint8_t* src, uint8_t* dst, int count);

    // Video mode type
    enum VideoModeType {
        MODE_TYPE_VESA,
        MODE_TYPE_VGA_12H,  // 640x480x16 planar
        MODE_TYPE_VGA_13H   // 320x200x256 linear
    };
    VideoModeType modeType;

    // Mode 13h palette (grayscale for B/W display)
    void setupPalette();
    void setupPalette16();  // For Mode 12h (16 colors)

    // Mode init helpers
    bool initVesa();
    bool initMode12h();    // VGA 640x480x16 planar
    bool initMode13h();    // VGA 320x200x256 linear
    void setVesaMode(int mode);

    // Pixel writing
    void putPixelMode13h(int x, int y, uint8_t color);
    void putPixelMode12h(int x, int y, uint8_t color);
    void putPixelVesa(int x, int y, uint8_t color);

    // Mode 12h helpers
    void mode12hWriteByte(int offset, uint8_t value);

    // Overlay drawing helper
    void drawOverlayPixel(int px, int py, bool black);
};
