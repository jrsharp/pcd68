#include "Screen_Zephyr.h"
#include <zephyr/logging/log.h>
#include <zephyr/kernel.h>
#include <string.h>

LOG_MODULE_DECLARE(pcd68_main);

Screen_Zephyr::Screen_Zephyr(u32 baseAddress) 
    : Screen(baseAddress), display_dev(nullptr), framebuffer(nullptr), previous_frame(nullptr),
      dirty(false), framebuffer_supported(false), is_epaper(false), 
      partial_refresh_enabled(true), refresh_rate_ms(CONFIG_PCD68_ENABLE_EINK_EMULATION ? 2000 : 33),
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

bool Screen_Zephyr::init()
{
    LOG_INF("Initializing PCD68 display");
    
    // Get display device from chosen node in device tree
    display_dev = DEVICE_DT_GET(DT_CHOSEN(zephyr_display));
    if (!device_is_ready(display_dev)) {
        LOG_ERR("Display device not ready");
        return false;
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
    
    return true;
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
    
    return true;
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
    
    return true;
}

void Screen_Zephyr::refresh()
{
    if (!dirty) {
        return;
    }
    
    // Rate limiting for E-paper displays
    uint32_t now = k_uptime_get_32();
    if (is_epaper && (now - last_refresh_time) < refresh_rate_ms) {
        return;  // Too soon for E-paper refresh
    }
    
    if (framebuffer_supported) {
        updateFramebuffer();
    } else {
        updateDirectDisplay();
    }
    
    last_refresh_time = now;
    dirty = false;
}

void Screen_Zephyr::updateFramebuffer()
{
#ifdef CONFIG_FRAMEBUFFER
    // Convert PCD68 400x300 monochrome to display format and resolution
    convertMonoToDisplay(framebuffer, screenBuffer, display_width, display_height);
    
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
        memcpy(previous_frame, screenBuffer, SCREEN_BUFFER_SIZE);
    } else {
        // Direct framebuffer update for LCD or full E-paper refresh
        performFullRefresh();
    }
#endif
}

void Screen_Zephyr::updateDirectDisplay()
{
    // Convert and write directly to display
    convertMonoToDisplay(framebuffer, screenBuffer, display_width, display_height);
    
    struct display_buffer_descriptor desc = {
        .buf_size = display_width * display_height * 
                   ((pixel_format == PIXEL_FORMAT_RGB_565) ? 2 : 1),
        .pitch = display_width,
        .width = display_width,
        .height = display_height,
    };
    
    int ret = display_write(display_dev, 0, 0, &desc, framebuffer);
    if (ret < 0) {
        LOG_ERR("Display write failed: %d", ret);
    }
}

u8 Screen_Zephyr::read8(u32 address)
{
    u32 offset = address - baseAddress;
    if (offset < SCREEN_BUFFER_SIZE) {
        return screenBuffer[offset];
    }
    return 0;
}

void Screen_Zephyr::write8(u32 address, u8 value)
{
    u32 offset = address - baseAddress;
    if (offset < SCREEN_BUFFER_SIZE) {
        if (screenBuffer[offset] != value) {
            screenBuffer[offset] = value;
            dirty = true;
        }
    }
}

void Screen_Zephyr::convertMonoToDisplay(u8 *dest, const u8 *src, int dest_w, int dest_h)
{
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
        if (screenBuffer[i] != previous_frame[i]) {
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
        .pitch = width,
        .width = width,
        .height = height,
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
        .pitch = display_width,
        .width = display_width,
        .height = display_height,
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