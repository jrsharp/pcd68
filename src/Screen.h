/*
 * Copyright (c) 2022, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include "PCD68_CPU.h"
#include "Peripheral.h"
#include <stdint.h>

class Screen : virtual public Peripheral {

public:
    // Class constants
    static constexpr int SCREEN_WIDTH = 400;
    static constexpr int SCREEN_HEIGHT = 300;
    static constexpr u32 BASE_ADDR = 0x430000;
    static constexpr u16 REFRESH_INTERVAL = 100;

    /**
     * State enum
     */
    enum State {
        BUSY,
        READY,
        SLEEP
    };

    /**
     * Struct for Screen's registers
     */
    struct Registers {
        bool busy;
        State state;
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
    virtual int init() = 0;

    /**
     * Update / refresh display contents
     */
    virtual int refresh();

    virtual void reset() override;
    virtual u8 read8(u32 addr) override;
    virtual u16 read16(u32 addr) override;
    virtual void write8(u32 addr, u8 val) override;
    virtual void write16(u32 addr, u16 val) override;
    virtual void advance(int cycles);

    u8 framebufferMem[400 * 300]; // 8bpp (RGB332)
    bool refreshFlag;
    Registers registers;

protected:
    u16 wait;
};
