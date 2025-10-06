#include "Screen_Zephyr.h"
#include "PCD68_CPU.h"
#include <zephyr/logging/log.h>
#include <zephyr/kernel.h>
#include <string.h>

LOG_MODULE_DECLARE(pcd68_main);

// Screen buffer constants
#define SCREEN_BUFFER_SIZE (400 * 300)  // PCD68 framebuffer size

extern u8* systemRam;  // Access to PCD68 system RAM

// Helper to get PCD68 framebuffer pointer
// FRAMEBUFFER_BASE = 0x810000, RAM_BASE = 0x800000, so offset = 0x10000 = 65536
static inline u8* getScreenBuffer() {
    return &systemRam[0x10000];
}

Screen_Zephyr::Screen_Zephyr(u32 baseAddress)
    : Peripheral(baseAddress, SCREEN_BUFFER_SIZE), Screen(baseAddress, SCREEN_BUFFER_SIZE),
      display_dev(nullptr), framebuffer(nullptr), previous_frame(nullptr),
      dirty(false), framebuffer_supported(false), is_epaper(true),  // nRF54L15 targets e-paper
      partial_refresh_enabled(true), refresh_rate_ms(3000),  // 3 second e-paper refresh
      last_refresh_time(0), display_width(400), display_height(300),
      pixel_format(PIXEL_FORMAT_MONO10), dirty_region_count(0)
{
    printk("DEBUG: Screen_Zephyr constructor entered\n");
    memset(dirty_regions, 0, sizeof(dirty_regions));
    printk("DEBUG: Screen_Zephyr constructor completed\n");
}

Screen_Zephyr::~Screen_Zephyr()
{
    if (framebuffer && framebuffer != previous_frame) {
        delete[] framebuffer;
    }
    if (previous_frame) {
        delete[] previous_frame;
    }
}

int Screen_Zephyr::init()
{
    LOG_INF("Initializing memory-only framebuffer (400x300)");
    printk("DEBUG: Screen_Zephyr::init() entered\n");

    // Set up memory-only framebuffer - no hardware display
    display_width = 400;
    display_height = 300;
    pixel_format = PIXEL_FORMAT_MONO10;

    // Use minimal static allocation for framebuffer (just enough to not crash)
    static u8 static_framebuffer[1024];  // 1KB minimal buffer
    framebuffer = static_framebuffer;
    int buffer_size = sizeof(static_framebuffer);
    memset(framebuffer, 0, buffer_size);
    framebuffer_supported = true;
    printk("DEBUG: Using %d bytes minimal static framebuffer\n", buffer_size);

    // No display hardware initialization needed
    display_dev = nullptr;

    printk("DEBUG: Screen_Zephyr::init() completed successfully (memory-only mode)\n");
    return 0;
}

bool Screen_Zephyr::initFramebuffer()
{
    // Allocate framebuffer for e-paper display
    int bytes_per_pixel = 1;  // E-paper is typically monochrome

    switch (pixel_format) {
        case PIXEL_FORMAT_MONO01:
        case PIXEL_FORMAT_MONO10:
            bytes_per_pixel = 1;
            break;
        default:
            LOG_WRN("Unexpected pixel format %d for e-paper, assuming mono", pixel_format);
            bytes_per_pixel = 1;
            break;
    }

    size_t fb_size = display_width * display_height / 8;  // Packed bits for mono
    framebuffer = new u8[fb_size];
    if (!framebuffer) {
        LOG_ERR("Failed to allocate framebuffer (%zu bytes)", fb_size);
        return false;
    }
    memset(framebuffer, 0xFF, fb_size);  // Start with white for e-paper
    LOG_INF("Allocated e-paper framebuffer: %zu bytes", fb_size);

    // Allocate previous frame for dirty detection (essential for e-paper)
    size_t frame_size = SCREEN_WIDTH * SCREEN_HEIGHT / 8;  // PCD68 mono framebuffer size
    previous_frame = new u8[frame_size];
    if (previous_frame) {
        memset(previous_frame, 0, frame_size);
        LOG_INF("Allocated previous frame buffer for e-paper optimization");
    }

    return true;
}

bool Screen_Zephyr::initDirectDisplay()
{
    // For direct display mode with e-paper
    int bytes_per_pixel = 1;  // E-paper monochrome
    size_t buffer_size = display_width * display_height / 8;  // Packed bits

    framebuffer = new u8[buffer_size];
    if (!framebuffer) {
        LOG_ERR("Failed to allocate display buffer");
        return false;
    }
    memset(framebuffer, 0xFF, buffer_size);  // White background for e-paper

    return true;
}

int Screen_Zephyr::refresh()
{
    // Memory-only mode - no actual display hardware
    if (!dirty) {
        return 0;
    }

    // Just mark as no longer dirty - no actual refresh needed
    dirty = false;
    return 0;
}

void Screen_Zephyr::updateFramebuffer()
{
    // Memory-only mode - no actual display operations needed
    // Just update internal state if we have a previous frame buffer
    if (previous_frame) {
        memcpy(previous_frame, getScreenBuffer(), SCREEN_BUFFER_SIZE);
    }
}

void Screen_Zephyr::updateDirectDisplay()
{
    // Memory-only mode - no display hardware operations
}

u8 Screen_Zephyr::read8(u32 address)
{
    // Override base class to avoid using the 120KB framebufferMem
    // Use PCD68 system RAM directly
    u32 offset = address - getBaseAddress();
    if (offset < SCREEN_BUFFER_SIZE) {
        return getScreenBuffer()[offset];
    }
    return 0;
}

void Screen_Zephyr::write8(u32 address, u8 value)
{
    // Override base class to avoid using the 120KB framebufferMem
    // Use PCD68 system RAM directly
    u32 offset = address - getBaseAddress();
    if (offset < SCREEN_BUFFER_SIZE) {
        if (getScreenBuffer()[offset] != value) {
            getScreenBuffer()[offset] = value;
            dirty = true;
        }
    }
}

void Screen_Zephyr::convertMonoToEpaper(u8 *dest, const u8 *src, int dest_w, int dest_h)
{
    // Direct conversion for matching 400x300 e-paper displays
    if (dest_w == SCREEN_WIDTH && dest_h == SCREEN_HEIGHT) {
        // Direct conversion without scaling - perfect match
        for (int y = 0; y < dest_h; y++) {
            for (int x = 0; x < dest_w; x++) {
                // Get pixel from PCD68 monochrome buffer (1 bit per pixel)
                int bit_offset = y * SCREEN_WIDTH + x;
                int byte_offset = bit_offset / 8;
                int bit_pos = 7 - (bit_offset % 8);
                bool pixel = (src[byte_offset] >> bit_pos) & 1;

                // Convert to e-paper format
                int dest_byte = (y * dest_w + x) / 8;
                int dest_bit = 7 - ((y * dest_w + x) % 8);

                if (pixel_format == PIXEL_FORMAT_MONO01) {
                    // 0=black, 1=white
                    if (pixel) {
                        dest[dest_byte] |= (1 << dest_bit);
                    } else {
                        dest[dest_byte] &= ~(1 << dest_bit);
                    }
                } else {
                    // MONO10: 1=black, 0=white (common for e-paper)
                    if (pixel) {
                        dest[dest_byte] &= ~(1 << dest_bit);
                    } else {
                        dest[dest_byte] |= (1 << dest_bit);
                    }
                }
            }
        }
    } else {
        // Scale if needed (though 400x300 should be exact match)
        LOG_WRN("Display size mismatch: %dx%d vs expected 400x300", dest_w, dest_h);
        // Simple scaling fallback
        scaleFrameToEpaper(dest, src, dest_w, dest_h, SCREEN_WIDTH, SCREEN_HEIGHT);
    }
}

void Screen_Zephyr::scaleFrameToEpaper(u8 *dest, const u8 *src, int dest_w, int dest_h, int src_w, int src_h)
{
    // Clear destination first
    memset(dest, (pixel_format == PIXEL_FORMAT_MONO01) ? 0x00 : 0xFF, dest_w * dest_h / 8);

    float x_scale = (float)src_w / dest_w;
    float y_scale = (float)src_h / dest_h;

    for (int y = 0; y < dest_h; y++) {
        for (int x = 0; x < dest_w; x++) {
            // Find source pixel using nearest neighbor
            int src_x = (int)(x * x_scale);
            int src_y = (int)(y * y_scale);

            if (src_x >= src_w) src_x = src_w - 1;
            if (src_y >= src_h) src_y = src_h - 1;

            // Get pixel from monochrome source
            int bit_offset = src_y * src_w + src_x;
            int byte_offset = bit_offset / 8;
            int bit_pos = 7 - (bit_offset % 8);
            bool pixel = (src[byte_offset] >> bit_pos) & 1;

            // Set pixel in e-paper format
            int dest_byte = (y * dest_w + x) / 8;
            int dest_bit = 7 - ((y * dest_w + x) % 8);

            if (pixel_format == PIXEL_FORMAT_MONO01) {
                // 0=black, 1=white
                if (pixel) {
                    dest[dest_byte] |= (1 << dest_bit);
                } else {
                    dest[dest_byte] &= ~(1 << dest_bit);
                }
            } else {
                // MONO10: 1=black, 0=white
                if (pixel) {
                    dest[dest_byte] &= ~(1 << dest_bit);
                } else {
                    dest[dest_byte] |= (1 << dest_bit);
                }
            }
        }
    }
}

void Screen_Zephyr::calculateDirtyRegions()
{
    if (!previous_frame) return;

    dirty_region_count = 0;

    bool found_changes = false;
    int min_x = SCREEN_WIDTH, min_y = SCREEN_HEIGHT;
    int max_x = 0, max_y = 0;

    for (int i = 0; i < SCREEN_BUFFER_SIZE; i++) {
        if (getScreenBuffer()[i] != previous_frame[i]) {
            found_changes = true;
            // Convert byte offset to x,y coordinates
            int bit_offset = i * 8;
            int y = bit_offset / SCREEN_WIDTH;
            int x = bit_offset % SCREEN_WIDTH;

            if (x < min_x) min_x = x;
            if (x > max_x) max_x = x;
            if (y < min_y) min_y = y;
            if (y > max_y) max_y = y;
        }
    }

    if (found_changes) {
        // Create a single dirty region encompassing all changes
        dirty_regions[0].x = min_x;
        dirty_regions[0].y = min_y;
        dirty_regions[0].width = max_x - min_x + 8;  // +8 for byte boundary
        dirty_regions[0].height = max_y - min_y + 1;
        dirty_regions[0].active = true;
        dirty_region_count = 1;

        LOG_DBG("E-paper dirty region: %dx%d at (%d,%d)",
                dirty_regions[0].width, dirty_regions[0].height,
                dirty_regions[0].x, dirty_regions[0].y);
    }
}

bool Screen_Zephyr::shouldDoPartialRefresh()
{
    // Use partial refresh for small changes on E-paper to reduce power consumption
    if (dirty_region_count == 0) return false;

    int total_changed_area = 0;
    for (int i = 0; i < dirty_region_count; i++) {
        if (dirty_regions[i].active) {
            total_changed_area += dirty_regions[i].width * dirty_regions[i].height;
        }
    }

    int total_area = display_width * display_height;
    bool use_partial = (total_changed_area < total_area / 3);  // Less than 33% changed

    LOG_DBG("E-paper refresh decision: %s (changed: %d/%d pixels)",
            use_partial ? "partial" : "full", total_changed_area, total_area);

    return use_partial;
}

void Screen_Zephyr::performPartialRefresh(int x, int y, int width, int height)
{
    // Memory-only mode - no display hardware operations
}

void Screen_Zephyr::performFullRefresh()
{
    // Memory-only mode - no display hardware operations
}

void Screen_Zephyr::forceFullRefresh()
{
    // Memory-only mode - just clear dirty flag
    dirty = false;
}