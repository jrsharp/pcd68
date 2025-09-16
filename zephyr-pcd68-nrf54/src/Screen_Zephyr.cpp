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
      dirty(false), framebuffer_supported(false), is_epaper(false), 
      partial_refresh_enabled(true), refresh_rate_ms(IS_ENABLED(CONFIG_PCD68_ENABLE_EINK_EMULATION) ? 2000 : 33),
      last_refresh_time(0), display_width(0), display_height(0), 
      pixel_format(PIXEL_FORMAT_MONO10), dirty_region_count(0)
{
    memset(dirty_regions, 0, sizeof(dirty_regions));
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
    LOG_INF("Initializing PCD68 display");
    
    // Get display device - try different approaches
    #if DT_NODE_EXISTS(DT_ALIAS(display0))
    display_dev = DEVICE_DT_GET(DT_ALIAS(display0));
    #elif DT_NODE_EXISTS(DT_NODELABEL(st7796s))
    display_dev = DEVICE_DT_GET(DT_NODELABEL(st7796s));
    #else
    LOG_ERR("No display device found in device tree");
    return -1;
    #endif
    
    if (!device_is_ready(display_dev)) {
        LOG_ERR("Display device not ready");
        return -1;
    }
    
    // Get display capabilities
    struct display_capabilities caps;
    display_get_capabilities(display_dev, &caps);
    display_width = caps.x_resolution;
    display_height = caps.y_resolution;
    pixel_format = caps.current_pixel_format;
    
    LOG_INF("Display: %dx%d, pixel format: %d", display_width, display_height, pixel_format);
    
    // Detect E-paper displays by driver name or capabilities
    const char* driver_name = display_dev->name;
    is_epaper = (strstr(driver_name, "ssd16") != nullptr) || 
                (strstr(driver_name, "epd") != nullptr) ||
                (strstr(driver_name, "waveshare") != nullptr);
    
    if (is_epaper) {
        LOG_INF("E-paper display detected: %s", driver_name);
        // E-paper displays typically need longer refresh intervals
        if (refresh_rate_ms < 1000) {
            refresh_rate_ms = 2000;  // 2 second minimum for E-paper
        }
    }
    
    // Try to use framebuffer if supported
    if (initFramebuffer()) {
        LOG_INF("Using framebuffer mode");
        framebuffer_supported = true;
    } else {
        LOG_INF("Using direct display mode");
        framebuffer_supported = false;
        if (!initDirectDisplay()) {
            return false;
        }
    }
    
    // Set display blanking off
    display_blanking_off(display_dev);
    
    // Initialize with a clear screen
    forceFullRefresh();
    
    return 0;
}

bool Screen_Zephyr::initFramebuffer()
{
#ifdef CONFIG_FRAMEBUFFER
    // Try to get framebuffer
    uint8_t *fb_ptr;
    size_t fb_size;
    
    if (display_get_framebuffer(display_dev, &fb_ptr) == 0) {
        // Use driver's framebuffer directly
        framebuffer = fb_ptr;
        LOG_INF("Using driver framebuffer directly");
    } else {
        // Allocate our own framebuffer
        int bytes_per_pixel = 1;  // Default to monochrome
        
        switch (pixel_format) {
            case PIXEL_FORMAT_RGB_565:
            case PIXEL_FORMAT_BGR_565:
                bytes_per_pixel = 2;
                break;
            case PIXEL_FORMAT_RGB_888:
            case PIXEL_FORMAT_BGR_888:
                bytes_per_pixel = 3;
                break;
            case PIXEL_FORMAT_ARGB_8888:
                bytes_per_pixel = 4;
                break;
            case PIXEL_FORMAT_MONO01:
            case PIXEL_FORMAT_MONO10:
            default:
                bytes_per_pixel = 1;
                break;
        }
        
        size_t fb_size = display_width * display_height * bytes_per_pixel;
        framebuffer = new u8[fb_size];
        if (!framebuffer) {
            LOG_ERR("Failed to allocate framebuffer (%zu bytes)", fb_size);
            return false;
        }
        memset(framebuffer, 0, fb_size);
        LOG_INF("Allocated framebuffer: %zu bytes", fb_size);
    }
    
    // Allocate previous frame for dirty detection (E-paper optimization)
    if (is_epaper) {
        size_t frame_size = SCREEN_WIDTH * SCREEN_HEIGHT / 8;  // PCD68 mono framebuffer size
        previous_frame = new u8[frame_size];
        if (previous_frame) {
            memset(previous_frame, 0, frame_size);
        }
    }
    
    return 0;
#else
    return false;
#endif
}

bool Screen_Zephyr::initDirectDisplay()
{
    // For direct display mode, we'll write directly to the display
    // Allocate a buffer for format conversion
    int bytes_per_pixel = (pixel_format == PIXEL_FORMAT_RGB_565 || pixel_format == PIXEL_FORMAT_BGR_565) ? 2 : 1;
    size_t buffer_size = display_width * display_height * bytes_per_pixel;
    
    framebuffer = new u8[buffer_size];
    if (!framebuffer) {
        LOG_ERR("Failed to allocate display buffer");
        return false;
    }
    memset(framebuffer, 0, buffer_size);
    
    return 0;
}

int Screen_Zephyr::refresh()
{
    if (!dirty) {
        return 0;
    }
    
    // Rate limiting for E-paper displays
    uint32_t now = k_uptime_get_32();
    if (is_epaper && (now - last_refresh_time) < refresh_rate_ms) {
        return 0;  // Too soon for E-paper refresh
    }
    
    if (framebuffer_supported) {
        updateFramebuffer();
    } else {
        updateDirectDisplay();
    }
    
    last_refresh_time = now;
    dirty = false;
    return 0;
}

void Screen_Zephyr::updateFramebuffer()
{
#ifdef CONFIG_FRAMEBUFFER
    // Convert PCD68 400x300 monochrome to display format and resolution
    convertMonoToDisplay(framebuffer, getScreenBuffer(), display_width, display_height);
    
    if (is_epaper && partial_refresh_enabled && previous_frame) {
        // For E-paper, try partial refresh if supported
        calculateDirtyRegions();
        
        if (shouldDoPartialRefresh() && dirty_region_count > 0) {
            // Perform partial refresh on dirty regions
            for (int i = 0; i < dirty_region_count; i++) {
                if (dirty_regions[i].active) {
                    performPartialRefresh(dirty_regions[i].x, dirty_regions[i].y,
                                        dirty_regions[i].width, dirty_regions[i].height);
                }
            }
        } else {
            performFullRefresh();
        }
        
        // Update previous frame
        memcpy(previous_frame, getScreenBuffer(), SCREEN_BUFFER_SIZE);
    } else {
        // Direct framebuffer update for LCD or full E-paper refresh
        performFullRefresh();
    }
#endif
}

void Screen_Zephyr::updateDirectDisplay()
{
    // Convert and write directly to display
    convertMonoToDisplay(framebuffer, getScreenBuffer(), display_width, display_height);
    
    struct display_buffer_descriptor desc = {
        .buf_size = display_width * display_height * 
                   ((pixel_format == PIXEL_FORMAT_RGB_565) ? 2 : 1),
        .width = display_width,
        .height = display_height,
        .pitch = display_width,
    };
    
    int ret = display_write(display_dev, 0, 0, &desc, framebuffer);
    if (ret < 0) {
        LOG_ERR("Display write failed: %d", ret);
    }
}

u8 Screen_Zephyr::read8(u32 address)
{
    u32 offset = address - getBaseAddress();
    if (offset < SCREEN_BUFFER_SIZE) {
        return getScreenBuffer()[offset];
    }
    return 0;
}

void Screen_Zephyr::write8(u32 address, u8 value)
{
    u32 offset = address - getBaseAddress();
    if (offset < SCREEN_BUFFER_SIZE) {
        if (getScreenBuffer()[offset] != value) {
            getScreenBuffer()[offset] = value;
            dirty = true;
        }
    }
}

void Screen_Zephyr::convertMonoToDisplay(u8 *dest, const u8 *src, int dest_w, int dest_h)
{
    // Special handling for ST7796S 480x320 - center PCD68 400x300 with decorative border
    if (dest_w == 480 && dest_h == 320) {
        renderCenteredWithBorder(dest, src, dest_w, dest_h);
        return;
    }
    
    // If display resolution matches PCD68 exactly (like Waveshare 4.2")
    if (dest_w == SCREEN_WIDTH && dest_h == SCREEN_HEIGHT) {
        // Direct conversion without scaling
        for (int y = 0; y < dest_h; y++) {
            for (int x = 0; x < dest_w; x++) {
                // Get pixel from PCD68 monochrome buffer (1 bit per pixel)
                int bit_offset = y * SCREEN_WIDTH + x;
                int byte_offset = bit_offset / 8;
                int bit_pos = 7 - (bit_offset % 8);
                bool pixel = (src[byte_offset] >> bit_pos) & 1;
                
                // Convert to display format
                switch (pixel_format) {
                    case PIXEL_FORMAT_MONO01:
                        // Direct monochrome (0=black, 1=white)
                        if ((x % 8) == 0) dest[y * (dest_w/8) + x/8] = 0;
                        if (pixel) dest[y * (dest_w/8) + x/8] |= (0x80 >> (x % 8));
                        break;
                        
                    case PIXEL_FORMAT_MONO10:
                        // Inverse monochrome (1=black, 0=white) - common for E-paper
                        if ((x % 8) == 0) dest[y * (dest_w/8) + x/8] = 0xFF;
                        if (pixel) dest[y * (dest_w/8) + x/8] &= ~(0x80 >> (x % 8));
                        break;
                        
                    case PIXEL_FORMAT_RGB_565: {
                        uint16_t color = pixel ? 0xFFFF : 0x0000;
                        uint16_t *dest16 = (uint16_t*)dest;
                        dest16[y * dest_w + x] = color;
                        break;
                    }
                    
                    default:
                        // Grayscale fallback
                        dest[y * dest_w + x] = pixel ? 0xFF : 0x00;
                        break;
                }
            }
        }
    } else {
        // Scale from 400x300 to display resolution
        scaleFrame(dest, src, dest_w, dest_h, SCREEN_WIDTH, SCREEN_HEIGHT);
    }
}

void Screen_Zephyr::scaleFrame(u8 *dest, const u8 *src, int dest_w, int dest_h, int src_w, int src_h)
{
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
            
            // Convert to destination format (simplified)
            switch (pixel_format) {
                case PIXEL_FORMAT_RGB_565: {
                    uint16_t color = pixel ? 0xFFFF : 0x0000;
                    uint16_t *dest16 = (uint16_t*)dest;
                    dest16[y * dest_w + x] = color;
                    break;
                }
                default:
                    dest[y * dest_w + x] = pixel ? 0xFF : 0x00;
                    break;
            }
        }
    }
}

void Screen_Zephyr::renderCenteredWithBorder(u8 *dest, const u8 *src, int dest_w, int dest_h)
{
    // Clear entire buffer first
    uint16_t *dest16 = (uint16_t*)dest;
    
    // Calculate centering offsets for 400x300 on 480x320
    const int border_x = (dest_w - SCREEN_WIDTH) / 2;  // 40px left/right borders
    const int border_y = (dest_h - SCREEN_HEIGHT) / 2; // 10px top/bottom borders
    
    // Fill entire display with decorative border
    for (int y = 0; y < dest_h; y++) {
        for (int x = 0; x < dest_w; x++) {
            uint16_t border_color = generateBorderPixel(x, y, dest_w, dest_h);
            dest16[y * dest_w + x] = border_color;
        }
    }
    
    // Render PCD68 400x300 framebuffer in center
    for (int src_y = 0; src_y < SCREEN_HEIGHT; src_y++) {
        for (int src_x = 0; src_x < SCREEN_WIDTH; src_x++) {
            // Get pixel from PCD68 monochrome buffer (1 bit per pixel)
            int bit_offset = src_y * SCREEN_WIDTH + src_x;
            int byte_offset = bit_offset / 8;
            int bit_pos = 7 - (bit_offset % 8);
            bool pixel = (src[byte_offset] >> bit_pos) & 1;
            
            // Calculate destination position (centered)
            int dest_x = border_x + src_x;
            int dest_y = border_y + src_y;
            
            // Only draw if within bounds (safety check)
            if (dest_x >= 0 && dest_x < dest_w && dest_y >= 0 && dest_y < dest_h) {
                // Convert monochrome pixel to RGB565
                uint16_t color = pixel ? 0xFFFF : 0x0000;  // White or black
                dest16[dest_y * dest_w + dest_x] = color;
            }
        }
    }
}

uint16_t Screen_Zephyr::generateBorderPixel(int x, int y, int display_w, int display_h)
{
    // Super Game Boy / Retro Computer inspired decorative border pattern
    // Using RGB565 format: RRRRR GGGGGG BBBBB
    
    const int border_x = (display_w - SCREEN_WIDTH) / 2;
    const int border_y = (display_h - SCREEN_HEIGHT) / 2;
    
    // Check if we're in the border area
    bool in_left_border = (x < border_x);
    bool in_right_border = (x >= border_x + SCREEN_WIDTH);
    bool in_top_border = (y < border_y);
    bool in_bottom_border = (y >= border_y + SCREEN_HEIGHT);
    
    if (in_left_border || in_right_border || in_top_border || in_bottom_border) {
        // Distance from PCD68 screen area edge (for gradient effects)
        int dist_from_screen = 0;
        if (in_left_border) dist_from_screen = border_x - x;
        else if (in_right_border) dist_from_screen = x - (border_x + SCREEN_WIDTH);
        else if (in_top_border) dist_from_screen = border_y - y;
        else if (in_bottom_border) dist_from_screen = y - (border_y + SCREEN_HEIGHT);
        
        // Create layered border design
        if (dist_from_screen < 2) {
            // Inner border: "FRST Computer PCD68 Model 4" accent
            return 0x39E7; // Cyan: 00111 001111 00111
        } else if (dist_from_screen < 4) {
            // Second layer: dark frame
            return 0x18C3; // Dark blue-gray: 00011 000110 00011
        } else {
            // Outer decorative area with retro pattern
            int pattern_x = x / 6;
            int pattern_y = y / 6;
            int checker = (pattern_x + pattern_y) % 2;
            
            // Create subtle texture reminiscent of 80s computers
            if (checker == 0) {
                return 0x2104; // Purple-gray: 00100 001000 00100
            } else {
                return 0x4A69; // Magenta-gray: 01001 010011 01001
            }
        }
    }
    
    return 0x0000; // Should not reach here, but return black as fallback
}

void Screen_Zephyr::calculateDirtyRegions()
{
    if (!previous_frame) return;
    
    dirty_region_count = 0;
    // Simple implementation: find changed areas
    // This could be optimized for better E-paper partial refresh
    
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
    }
}

bool Screen_Zephyr::shouldDoPartialRefresh()
{
    // Use partial refresh for small changes on E-paper
    if (!is_epaper || dirty_region_count == 0) return false;
    
    int total_changed_area = 0;
    for (int i = 0; i < dirty_region_count; i++) {
        if (dirty_regions[i].active) {
            total_changed_area += dirty_regions[i].width * dirty_regions[i].height;
        }
    }
    
    int total_area = display_width * display_height;
    return (total_changed_area < total_area / 4);  // Less than 25% changed
}

void Screen_Zephyr::performPartialRefresh(int x, int y, int width, int height)
{
    // Try partial refresh if display supports it
    struct display_buffer_descriptor desc = {
        .buf_size = width * height * ((pixel_format == PIXEL_FORMAT_RGB_565) ? 2 : 1),
        .width = width,
        .height = height,
        .pitch = width,
    };
    
    // Create partial buffer
    size_t partial_size = width * height;
    u8 *partial_buffer = new u8[partial_size];
    if (!partial_buffer) {
        LOG_WRN("Failed to allocate partial refresh buffer, doing full refresh");
        performFullRefresh();
        return;
    }
    
    // Extract the region from framebuffer
    for (int py = 0; py < height; py++) {
        memcpy(&partial_buffer[py * width], 
               &framebuffer[(y + py) * display_width + x], 
               width);
    }
    
    int ret = display_write(display_dev, x, y, &desc, partial_buffer);
    delete[] partial_buffer;
    
    if (ret < 0) {
        LOG_WRN("Partial refresh failed: %d, doing full refresh", ret);
        performFullRefresh();
    } else {
        LOG_DBG("Partial refresh: %dx%d at (%d,%d)", width, height, x, y);
    }
}

void Screen_Zephyr::performFullRefresh()
{
    struct display_buffer_descriptor desc = {
        .buf_size = display_width * display_height * 
                   ((pixel_format == PIXEL_FORMAT_RGB_565) ? 2 : 1),
        .width = display_width,
        .height = display_height,
        .pitch = display_width,
    };
    
    int ret = display_write(display_dev, 0, 0, &desc, framebuffer);
    if (ret < 0) {
        LOG_ERR("Full refresh failed: %d", ret);
    } else {
        LOG_DBG("Full display refresh completed");
    }
}

void Screen_Zephyr::forceFullRefresh()
{
    dirty = true;
    if (framebuffer_supported) {
        updateFramebuffer();
    } else {
        updateDirectDisplay();
    }
    dirty = false;
}