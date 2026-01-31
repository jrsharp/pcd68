/*
 * Open Firmware Screen Implementation for PCD68
 */

#include "Screen_OF.h"
#include <cstring>

Screen_OF::Screen_OF(uint32_t start, uint32_t size)
    : Screen(start, size), of_framebuffer(nullptr), scale(3) {
}

Screen_OF::~Screen_OF() {
    /* Nothing to free - OF manages the framebuffer */
}

int Screen_OF::init() {
    /* Get OF framebuffer info */
    of_framebuffer = of_env.fb_addr;
    of_width = of_env.fb_width;
    of_height = of_env.fb_height;

    if (!of_framebuffer) {
        of_print("Screen_OF: No framebuffer found!\n");
        return -1;
    }

    of_print("Screen_OF initialized: ");
    of_print_hex((uint32_t)of_framebuffer);
    of_print(" ");
    of_print_hex(of_width);
    of_print("x");
    of_print_hex(of_height);
    of_print("\n");

    /* Calculate scale to fit PCD68's 400x300 into PowerBook's 1280x854 */
    int scale_x = of_width / SCREEN_WIDTH;
    int scale_y = of_height / SCREEN_HEIGHT;
    scale = (scale_x < scale_y) ? scale_x : scale_y;
    if (scale < 1) scale = 1;
    if (scale > 3) scale = 3; /* Cap at 3x for performance */

    /* Clear OF framebuffer */
    memset(of_framebuffer, 0, of_width * of_height * 4);

    return 0;
}

int Screen_OF::refresh() {
    if (!of_framebuffer || !refreshFlag) {
        return 0;
    }

    blit_scaled();
    refreshFlag = false;
    return 0;
}

void Screen_OF::blit_scaled() {
    /* Calculate centered position */
    int scaled_width = SCREEN_WIDTH * scale;
    int scaled_height = SCREEN_HEIGHT * scale;
    int offset_x = (of_width - scaled_width) / 2;
    int offset_y = (of_height - scaled_height) / 2;

    /* Clear border area (dark gray) */
    uint32_t border_color = 0xFF202020;

    /* Top border */
    for (int y = 0; y < offset_y; y++) {
        for (int x = 0; x < of_width; x++) {
            of_framebuffer[y * of_width + x] = border_color;
        }
    }

    /* Bottom border */
    for (int y = offset_y + scaled_height; y < of_height; y++) {
        for (int x = 0; x < of_width; x++) {
            of_framebuffer[y * of_width + x] = border_color;
        }
    }

    /* Scale and copy PCD68 framebuffer */
    for (int y = 0; y < SCREEN_HEIGHT; y++) {
        for (int x = 0; x < SCREEN_WIDTH; x++) {
            uint8_t pixel = framebufferMem[y * SCREEN_WIDTH + x];
            uint32_t color = mono_to_rgb32(pixel);

            /* Draw scaled pixel */
            for (int sy = 0; sy < scale; sy++) {
                for (int sx = 0; sx < scale; sx++) {
                    int screen_x = offset_x + (x * scale) + sx;
                    int screen_y = offset_y + (y * scale) + sy;

                    if (screen_x >= 0 && screen_x < of_width &&
                        screen_y >= 0 && screen_y < of_height) {
                        of_framebuffer[screen_y * of_width + screen_x] = color;
                    }
                }
            }
        }

        /* Draw left/right borders for this row */
        for (int x = 0; x < offset_x; x++) {
            of_framebuffer[(offset_y + y * scale) * of_width + x] = border_color;
        }
        for (int x = offset_x + scaled_width; x < of_width; x++) {
            of_framebuffer[(offset_y + y * scale) * of_width + x] = border_color;
        }
    }
}