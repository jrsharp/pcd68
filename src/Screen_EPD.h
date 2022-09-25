#pragma once

#include "CPU.h"
#include "Peripheral.h"
#include <gdeh042Z21.h>
#include <gdew042t2.h>
#include <stdint.h>

extern u8* systemRam;

class Screen : public Peripheral {

public:
    /**
     * Struct for Screen's registers
     */
    struct Registers {
        bool busy;
    };

    /**
     * Constructor
     *
     * @param start base address
     * @param size size of memory
     */
    Screen(uint32_t start, uint32_t size);

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
    static constexpr u32 BASE_ADDR = 0x430000;

    u8 framebufferMem[400 * 300]; // 8bpp (RGB332)

    u8 reg_STAT;

    void reset() override;
    u8 read8(u32 addr) override;
    u16 read16(u32 addr) override;
    void write8(u32 addr, u8 val) override;
    void write16(u32 addr, u16 val) override;

    bool refreshFlag;

private:
    Registers registers;
    static EpdSpi io;
    static Gdew042t2 display;
};
