/*
 * Copyright (c) 2024, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 *
 * DOS keyboard input implementation for PCD-68
 * Uses BIOS/DOS keyboard services
 */

#pragma once

#include "KeyboardInput.h"
#include <stdint.h>

/**
 * DOS-specific implementation of the KeyboardInput interface
 * Uses BIOS int 16h for keyboard access
 */
class KeyboardInputDOS : public KeyboardInput {
public:
    /**
     * Constructor
     */
    KeyboardInputDOS();

    /**
     * Destructor
     */
    virtual ~KeyboardInputDOS();

    /**
     * Initialize DOS keyboard handling
     * @return 0 on success, nonzero on failure
     */
    int init() override;

    /**
     * Poll for DOS keyboard events
     * @return true if should continue, false if should exit (ESC pressed)
     */
    bool poll() override;

    /**
     * Enable or disable keyboard debug mode
     * @param enabled true to enable debug output, false to disable
     */
    void setDebugMode(bool enabled) override;

private:
    // Maximum number of keys that can be in a single report
    static constexpr int MAX_KEYS_PER_REPORT = 7;

    // Pending key buffer for multi-key reports
    u8 pendingKeys[MAX_KEYS_PER_REPORT];
    u8 pendingKeyCount;

    // Current modifier state
    u16 currentModifiers;

    // Debug mode flag
    bool debugEnabled;

    // Scan code to ASCII conversion
    u8 scanCodeToAscii(u8 scanCode, bool shifted);

    // Extended key handling (arrows, function keys)
    u16 handleExtendedKey(u8 scanCode);

    // Get current modifier state from BIOS
    u16 getModifierState();

    // Submit pending keys as a report
    void submitPendingKeys();
};
