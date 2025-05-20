/*
 * Copyright (c) 2025, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#include "KeyboardInputEmscripten.h"
#include <iostream>
#include <algorithm>

KeyboardInputEmscripten::KeyboardInputEmscripten() {
#ifdef __EMSCRIPTEN__
    lastKeyTime = 0;
    lastReportTimeMs = 0;
    currentModifiers = 0;
    debugEnabled = false;
    pendingKeys.reserve(MAX_KEYS_PER_REPORT); // Pre-allocate space for max keys
#endif
}

KeyboardInputEmscripten::~KeyboardInputEmscripten() {
#ifdef __EMSCRIPTEN__
    // Remove event listeners
    emscripten_set_keydown_callback(EMSCRIPTEN_EVENT_TARGET_WINDOW, nullptr, 0, nullptr);
    emscripten_set_keyup_callback(EMSCRIPTEN_EVENT_TARGET_WINDOW, nullptr, 0, nullptr);
#endif
}

int KeyboardInputEmscripten::init() {
#ifdef __EMSCRIPTEN__
    // Set up event listeners for keyboard events
    EMSCRIPTEN_RESULT result = emscripten_set_keydown_callback(
        EMSCRIPTEN_EVENT_TARGET_WINDOW, 
        this, 
        0, 
        keydown_callback
    );
    
    if (result != EMSCRIPTEN_RESULT_SUCCESS) {
        std::cerr << "Failed to set keydown callback" << std::endl;
        return -1;
    }
    
    // Also set up keyup callback to track modifiers
    result = emscripten_set_keyup_callback(
        EMSCRIPTEN_EVENT_TARGET_WINDOW,
        this,
        0,
        keyup_callback
    );
    
    if (result != EMSCRIPTEN_RESULT_SUCCESS) {
        std::cerr << "Failed to set keyup callback" << std::endl;
        return -1;
    }
    
    std::cout << "KeyboardInputEmscripten initialized" << std::endl;
    return 0;
#else
    return -1;
#endif
}

void KeyboardInputEmscripten::setDebugMode(bool enabled) {
#ifdef __EMSCRIPTEN__
    debugEnabled = enabled;
    if (debugEnabled) {
        std::cout << "Keyboard debug mode enabled (Emscripten)" << std::endl;
    }
#endif
}

#ifdef __EMSCRIPTEN__
void KeyboardInputEmscripten::submitPendingKeys() {
    if (pendingKeys.empty()) {
        return;
    }
    
    // Create an array to hold keycodes for the multi-key report
    std::vector<u8> keyCodes;
    keyCodes.reserve(pendingKeys.size());
    
    // Extract all key codes from pending keys
    for (const auto& key : pendingKeys) {
        // We need to cast to u8 since KCTL can only handle 8-bit keycodes
        // This may result in some loss of precision for higher keycodes
        keyCodes.push_back(static_cast<u8>(key.keyCode & 0xFF));
    }
    
    // Limit to maximum keys per report
    size_t keyCount = std::min(keyCodes.size(), static_cast<size_t>(MAX_KEYS_PER_REPORT));
    
    if (debugEnabled) {
        std::cout << "Emscripten: Submitting multi-key report with " << keyCount << " key(s) and modifiers 0x" 
                  << std::hex << currentModifiers << std::dec << std::endl;
        
        for (size_t i = 0; i < keyCount; i++) {
            std::cout << "  Key[" << i << "]: 0x" << std::hex << (int)keyCodes[i] 
                      << std::dec << " ('" << (char)keyCodes[i] << "')" << std::endl;
        }
    }
    
    // Call the callback with the multi-key report
    if (keyEventCallback) {
        // Check if it's a specialized callback that supports multi-key reports
        // Unfortunately we can't directly check the type, so we'll send individual keys for safety
        // Each key platform will handle the same way for consistency
        for (size_t i = 0; i < keyCount; i++) {
            keyEventCallback(keyCodes[i], currentModifiers & 0xFF);
        }
    }
    
    // Clear pending keys
    pendingKeys.clear();
    
    // Update last report time
    lastReportTimeMs = emscripten_get_now();
}
#endif

bool KeyboardInputEmscripten::poll() {
#ifdef __EMSCRIPTEN__
    // Check if pending keys need to be submitted due to timeout
    unsigned long ticksNow = emscripten_get_now();
    if (!pendingKeys.empty() && 
        (ticksNow - lastReportTimeMs) > REPORT_COLLECTION_WINDOW_MS) {
        submitPendingKeys();
    }
#endif
    return true;
}

#ifdef __EMSCRIPTEN__
EM_BOOL KeyboardInputEmscripten::keydown_callback(int eventType, const EmscriptenKeyboardEvent* e, void* userData) {
    if (eventType != EMSCRIPTEN_EVENT_KEYDOWN) {
        return EM_FALSE;
    }
    
    KeyboardInputEmscripten* self = static_cast<KeyboardInputEmscripten*>(userData);
    
    // Get current time for debouncing
    unsigned long now = emscripten_get_now();
    
    // Update modifier state
    // Create a modifier flags byte
    u16 modifiers = 0;
    if (e->shiftKey) modifiers |= 0x01;
    if (e->ctrlKey)  modifiers |= 0x02;
    if (e->altKey)   modifiers |= 0x04;
    if (e->metaKey)  modifiers |= 0x08;
    
    // Update current modifiers state
    self->currentModifiers = modifiers;
    
    // Skip if repeat key (browser sends repeats for held keys)
    if (e->repeat) {
        if (self->debugEnabled) {
            std::cout << "Emscripten: Ignoring repeat key" << std::endl;
        }
        return EM_FALSE;
    }
    
    // Debounce keyboard input
    if (now - self->lastKeyTime > KEY_DEBOUNCE_MS) {
        self->lastKeyTime = now;
        
        // Map key code and modifiers
        u16 keyCode = 0;
        
        // Try to use the key code first
        if (e->keyCode > 0) {
            keyCode = e->keyCode;
        } else if (e->which > 0) {
            keyCode = e->which;
        } else if (e->key[0] != '\0') {
            keyCode = e->key[0];
        }
        
        if (self->debugEnabled) {
            std::cout << "Emscripten keydown: key='" << e->key << "' keyCode=0x" 
                      << std::hex << keyCode << std::dec << " modifiers=0x" 
                      << std::hex << modifiers << std::dec << std::endl;
        }
        
        // Process the key
        if (keyCode > 0) {
            // Add to pending keys
            PendingKey key;
            key.keyCode = keyCode;
            key.timestamp = now;
            self->pendingKeys.push_back(key);
            
            // If this is the first key, start the collection window timer
            if (self->pendingKeys.size() == 1) {
                self->lastReportTimeMs = now;
            }
            
            // If we've hit the max keys per report, submit immediately
            if (self->pendingKeys.size() >= MAX_KEYS_PER_REPORT) {
                self->submitPendingKeys();
            }
        }
    }
    
    // Don't prevent default browser behavior
    return EM_FALSE;
}

EM_BOOL KeyboardInputEmscripten::keyup_callback(int eventType, const EmscriptenKeyboardEvent* e, void* userData) {
    if (eventType != EMSCRIPTEN_EVENT_KEYUP) {
        return EM_FALSE;
    }
    
    KeyboardInputEmscripten* self = static_cast<KeyboardInputEmscripten*>(userData);
    
    // Update modifier state
    u16 modifiers = 0;
    if (e->shiftKey) modifiers |= 0x01;
    if (e->ctrlKey)  modifiers |= 0x02;
    if (e->altKey)   modifiers |= 0x04;
    if (e->metaKey)  modifiers |= 0x08;
    
    self->currentModifiers = modifiers;
    
    if (self->debugEnabled) {
        std::cout << "Emscripten keyup: key='" << e->key << "' modifiers=0x" 
                  << std::hex << modifiers << std::dec << std::endl;
    }
    
    // Don't prevent default browser behavior
    return EM_FALSE;
}
#endif 