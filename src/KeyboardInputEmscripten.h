/*
 * Copyright (c) 2025, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include "KeyboardInput.h"

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include <emscripten/html5.h>
#endif

/**
 * Emscripten-specific implementation of the KeyboardInput interface
 * Handles keyboard input in a browser environment
 */
class KeyboardInputEmscripten : public KeyboardInput {
public:
    /**
     * Constructor
     */
    KeyboardInputEmscripten();

    /**
     * Destructor
     */
    virtual ~KeyboardInputEmscripten();

    /**
     * Initialize Emscripten keyboard handling
     * @return 0 on success, nonzero on failure
     */
    int init() override;

    /**
     * Poll for Emscripten keyboard events (no-op)
     * @return true (always continues)
     */
    bool poll() override;

#ifdef __EMSCRIPTEN__
private:
    /**
     * Static callback for DOM keydown events
     */
    static EM_BOOL keydown_callback(int eventType, const EmscriptenKeyboardEvent* e, void* userData);
    
    /**
     * Debounce time for keyboard events (in ms)
     */
    unsigned long lastKeyTime;
    
    /**
     * Debounce period (in ms)
     */
    static constexpr unsigned long KEY_DEBOUNCE_MS = 5;
#endif
}; 