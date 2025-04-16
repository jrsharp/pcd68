/*
 * Copyright (c) 2025, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include "KeyboardInput.h"
#include "SDL2/SDL.h"
#include "PCD68_CPU.h" // For u32 type definition

/**
 * SDL-specific implementation of the KeyboardInput interface
 */
class KeyboardInputSDL : public KeyboardInput {
public:
    /**
     * Constructor
     */
    KeyboardInputSDL();

    /**
     * Destructor
     */
    virtual ~KeyboardInputSDL();

    /**
     * Initialize SDL keyboard handling
     * @return 0 on success, nonzero on failure
     */
    int init() override;

    /**
     * Poll for SDL keyboard events
     * @return true if should continue, false if should exit
     */
    bool poll() override;

private:
    u32 keydownDebounceMs;  // Debounce period (in ms) for keyboard input
}; 