/*
 * Open Firmware Screen Implementation for PCD68
 */

#pragma once

#include "Screen.h"
#include "openfirmware.h"

class Screen_OF : public Screen {
public:
    Screen_OF(uint32_t start, uint32_t size);
    ~Screen_OF();

    int init() override;
    int refresh() override;

private:
    uint32_t *of_framebuffer;  /* OF framebuffer address */
    int of_width;              /* OF screen width (1280) */
    int of_height;             /* OF screen height (854) */
    int scale;                 /* Scaling factor for PCD68 display */

    /* Convert PCD68 monochrome to 32-bit color */
    inline uint32_t mono_to_rgb32(uint8_t pixel) {
        /* PCD68 uses 8bpp, but we'll treat it as mono for now */
        uint32_t gray = pixel ? 0xFFFFFF : 0x000000;
        return 0xFF000000 | gray; /* ARGB */
    }

    /* Scale and copy framebuffer */
    void blit_scaled();
};