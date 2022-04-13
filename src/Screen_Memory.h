#pragma once

#include <stdint.h>

class Screen {

public:

    /**
     * Initialize Screen peripheral
     * (Set up layers/textures/etc.)
     */
    int init();

    /**
     * Update / refresh display contents
     */
    int refresh();

    static constexpr int SCREEN_WIDTH = 400;
    static constexpr int SCREEN_HEIGHT = 300;

    uint8_t framebufferMem[400 * 300]; // 8bpp (RGB332)

private:

};

