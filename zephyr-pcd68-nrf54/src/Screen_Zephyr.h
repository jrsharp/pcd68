#ifndef SCREEN_ZEPHYR_H
#define SCREEN_ZEPHYR_H

#include "Screen.h"
#include <zephyr/device.h>
#include <zephyr/drivers/display.h>

class Screen_Zephyr : public Screen {
public:
    Screen_Zephyr(u32 baseAddress);
    virtual ~Screen_Zephyr();
    
    int init() override;
    int refresh() override;
    bool needsRefresh() const { return dirty; }
    
    // Override Screen virtual methods
    virtual u8 read8(u32 address) override;
    virtual void write8(u32 address, u8 value) override;
    
    // E-paper specific methods
    void setPartialRefresh(bool enabled) { partial_refresh_enabled = enabled; }
    void setRefreshRate(uint32_t rate_ms) { refresh_rate_ms = rate_ms; }
    void forceFullRefresh();
    
private:
    const struct device *display_dev;
    u8 *framebuffer;         // Framebuffer for display output
    u8 *previous_frame;      // Previous frame for dirty detection
    bool dirty;
    bool framebuffer_supported;
    bool is_epaper;
    bool partial_refresh_enabled;
    uint32_t refresh_rate_ms;
    uint32_t last_refresh_time;
    
    int display_width;
    int display_height;
    enum display_pixel_format pixel_format;
    
    // Display management
    bool initFramebuffer();
    bool initDirectDisplay();
    void updateFramebuffer();
    void updateDirectDisplay();
    
    // Format conversion
    void convertMonoToDisplay(u8 *dest, const u8 *src, int width, int height);
    void scaleFrame(u8 *dest, const u8 *src, int dest_w, int dest_h, int src_w, int src_h);
    
    // Centered rendering with decorative border (Super Game Boy style)
    void renderCenteredWithBorder(u8 *dest, const u8 *src, int dest_w, int dest_h);
    uint16_t generateBorderPixel(int x, int y, int display_w, int display_h);
    
    // E-paper optimizations
    void calculateDirtyRegions();
    bool shouldDoPartialRefresh();
    void performPartialRefresh(int x, int y, int width, int height);
    void performFullRefresh();
    
    // Dirty region tracking for E-paper
    struct dirty_region {
        int x, y, width, height;
        bool active;
    } dirty_regions[4];  // Support up to 4 dirty regions
    int dirty_region_count;
};

#endif // SCREEN_ZEPHYR_H