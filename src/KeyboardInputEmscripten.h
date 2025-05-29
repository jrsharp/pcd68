/*
 * Copyright (c) 2025, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include "KeyboardInput.h"
#include <vector>

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
     * Poll for Emscripten keyboard events
     * Processes any pending key events that have accumulated
     * @return true (always continues)
     */
    bool poll() override;
    
    /**
     * Enable or disable debug mode for keyboard input
     * @param enabled true to enable debug output, false to disable
     */
    void setDebugMode(bool enabled) override;

#ifdef __EMSCRIPTEN__
private:
    // Maximum number of keys that can be in a single report
    static constexpr int MAX_KEYS_PER_REPORT = 7;
    
    // The time window (in ms) during which keypresses are collected into a single report
    static constexpr unsigned long REPORT_COLLECTION_WINDOW_MS = 10;
    
    // Represents a key entry in the collection buffer
    struct PendingKey {
        u16 keyCode;
        unsigned long timestamp;
    };
    
    // Submit a report with multiple keys if available
    void submitPendingKeys();
    
    /**
     * Static callback for DOM keydown events
     */
    static EM_BOOL keydown_callback(int eventType, const EmscriptenKeyboardEvent* e, void* userData);
    
    /**
     * Static callback for DOM keyup events - used mainly for tracking modifier state
     */
    static EM_BOOL keyup_callback(int eventType, const EmscriptenKeyboardEvent* e, void* userData);
    
    /**
     * Debounce time for keyboard events (in ms)
     */
    unsigned long lastKeyTime;
    
    /**
     * Last report submission time
     */
    unsigned long lastReportTimeMs;
    
    /**
     * Pending keys waiting to be included in a report
     */
    std::vector<PendingKey> pendingKeys;
    
    /**
     * Current state of modifier keys
     */
    u16 currentModifiers;
    
    /**
     * Debounce period (in ms)
     */
    static constexpr unsigned long KEY_DEBOUNCE_MS = 5;
    
    /**
     * Debug mode flag
     */
    bool debugEnabled;
#endif
}; 