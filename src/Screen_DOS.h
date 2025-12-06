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
    int getVideoWidth() const { return vesaMode ? vesaWidth : 320; }
    int getVideoHeight() const { return vesaMode ? vesaHeight : 200; }

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

    // Mode 13h palette (grayscale for B/W display)
    void setupPalette();

    // VESA helpers
    bool initVesa();
    bool initMode13h();
    void setVesaMode(int mode);

    // Pixel writing
    void putPixelMode13h(int x, int y, uint8_t color);
    void putPixelVesa(int x, int y, uint8_t color);
};
