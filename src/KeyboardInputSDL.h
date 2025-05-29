/*
 * Copyright (c) 2025, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include "KeyboardInput.h"
#include "SDL2/SDL.h"
#include "PCD68_CPU.h" // For u32 type definition
#include <vector>

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
    
    /**
     * Enable or disable keyboard debug mode
     * @param enabled true to enable debug output, false to disable
     */
    void setDebugMode(bool enabled) override;

private:
    // Maximum number of keys that can be in a single report
    static constexpr int MAX_KEYS_PER_REPORT = 7;
    
    // The time window (in ms) during which keypresses are collected into a single report
    static constexpr u32 REPORT_COLLECTION_WINDOW_MS = 2;
    
    // Represents a key entry in the collection buffer
    struct PendingKey {
        u16 keyCode;
        u32 timestamp;
    };
    
    // Submit a report with multiple keys if available
    void submitPendingKeys();
    
    u32 keydownDebounceMs;        // Debounce period (in ms) for keyboard input
    u32 keyEventCount;            // Counter for keyboard events
    bool debugEnabled = false;    // Debug mode flag
    
    u32 lastReportTimeMs;         // Timestamp of the last report submission
    std::vector<PendingKey> pendingKeys; // Keys waiting to be included in a report
    u16 currentModifiers;         // Current state of modifier keys
}; 