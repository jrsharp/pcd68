/*
 * Copyright (c) 2025, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <functional>
#include <stdint.h>

using u8 = uint8_t;
using u16 = uint16_t;

/**
 * Platform-agnostic keyboard input interface
 */
class KeyboardInput {
public:
    /**
     * Callback type for keyboard events
     * @param keycode The keycode of the pressed key
     * @param mod The modifier keys that were held during the keypress
     */
    using KeyEventCallback = std::function<void(u16 keycode, u16 mod)>;

    /**
     * Constructor
     */
    KeyboardInput() : keyEventCallback(nullptr) {}

    /**
     * Destructor
     */
    virtual ~KeyboardInput() {}

    /**
     * Initialize the keyboard input system
     * @return 0 on success, nonzero on failure
     */
    virtual int init() = 0;

    /**
     * Poll for keyboard events and update state
     * @return true if should continue, false if should exit
     */
    virtual bool poll() = 0;

    /**
     * Set callback for keyboard events
     * @param callback The function to call when a key is pressed
     */
    void setKeyEventCallback(KeyEventCallback callback) {
        keyEventCallback = callback;
    }

protected:
    KeyEventCallback keyEventCallback;
};

/**
 * Factory function to create the appropriate KeyboardInput implementation
 * @return A new KeyboardInput instance
 */
KeyboardInput* createKeyboardInput(); 