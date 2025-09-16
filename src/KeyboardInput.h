/*
 * Copyright (c) 2025, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#ifndef USE_ZEPHYR
#include <functional>
#endif
#include <stdint.h>

using u8 = uint8_t;
using u16 = uint16_t;

/**
 * Platform-agnostic keyboard input interface
 */
class KeyboardInput {
public:
    /**
     * Callback type for single keyboard events
     * @param keycode The keycode of the pressed key
     * @param mod The modifier keys that were held during the keypress
     */
#ifndef USE_ZEPHYR
    using KeyEventCallback = std::function<void(u16 keycode, u16 mod)>;
#else
    using KeyEventCallback = void(*)(u16 keycode, u16 mod);
#endif

    /**
     * Callback type for multi-key keyboard events
     * @param keycodes Array of keycodes for pressed keys
     * @param keyCount Number of keys in the report
     * @param mod The modifier keys that were held during the keypress
     */
#ifndef USE_ZEPHYR
    using KeyMultiEventCallback = std::function<void(const u8* keycodes, u8 keyCount, u8 mod)>;
#else
    using KeyMultiEventCallback = void(*)(const u8* keycodes, u8 keyCount, u8 mod);
#endif

    /**
     * Constructor
     */
    KeyboardInput() : keyEventCallback(nullptr), keyMultiEventCallback(nullptr) {}

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

    /**
     * Set callback for multi-key keyboard events
     * @param callback The function to call for multi-key reports
     */
    void setKeyMultiEventCallback(KeyMultiEventCallback callback) {
        keyMultiEventCallback = callback;
    }
    
    /**
     * Enable or disable debug mode for keyboard input
     * This is a no-op in the base class, implementations should override
     * @param enabled true to enable debug output, false to disable
     */
    virtual void setDebugMode(bool enabled) {}

protected:
    KeyEventCallback keyEventCallback;
    KeyMultiEventCallback keyMultiEventCallback;
};

/**
 * Factory function to create the appropriate KeyboardInput implementation
 * @return A new KeyboardInput instance
 */
KeyboardInput* createKeyboardInput(); 