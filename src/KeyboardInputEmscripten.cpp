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
    std::cout << "=== KeyboardInputEmscripten::init() starting ===" << std::endl;
    
    // Set up event listeners for keyboard events
    // Use canvas as target for better focus management
    std::cout << "Setting up keydown callback..." << std::endl;
    EMSCRIPTEN_RESULT result = emscripten_set_keydown_callback(
        "#canvas", 
        this, 
        1, // Use capture
        keydown_callback
    );
    
    std::cout << "Keydown callback result: " << result << std::endl;
    if (result != EMSCRIPTEN_RESULT_SUCCESS) {
        std::cerr << "Failed to set keydown callback, result: " << result << std::endl;
        return -1;
    }
    
    // Also set up keyup callback to track modifiers
    std::cout << "Setting up keyup callback..." << std::endl;
    result = emscripten_set_keyup_callback(
        "#canvas",
        this,
        1, // Use capture
        keyup_callback
    );
    
    std::cout << "Keyup callback result: " << result << std::endl;
    if (result != EMSCRIPTEN_RESULT_SUCCESS) {
        std::cerr << "Failed to set keyup callback, result: " << result << std::endl;
        return -1;
    }
    
    std::cout << "KeyboardInputEmscripten initialized successfully" << std::endl;
    std::cout << "Keyboard events will be captured from canvas with event capture enabled" << std::endl;
    std::cout << "=== KeyboardInputEmscripten::init() complete ===" << std::endl;
    return 0;
#else
    std::cout << "KeyboardInputEmscripten::init() called but __EMSCRIPTEN__ not defined!" << std::endl;
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
    if (keyCount > 0) {
        // Prefer multi-key callback if available, fall back to individual key callback if not
        if (keyMultiEventCallback) {
            if (debugEnabled) {
                std::cout << "Emscripten: Calling keyMultiEventCallback" << std::endl;
            }
            keyMultiEventCallback(keyCodes.data(), keyCount, currentModifiers & 0xFF);
        } else if (keyEventCallback) {
            if (debugEnabled) {
                std::cout << "Emscripten: Calling keyEventCallback for " << keyCount << " keys" << std::endl;
            }
            // Fall back to sending individual key events if multi-key callback not set
            for (size_t i = 0; i < keyCount; i++) {
                keyEventCallback(keyCodes[i], currentModifiers & 0xFF);
            }
        } else {
            std::cout << "Emscripten: ERROR - No callback functions set!" << std::endl;
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
    
    // Debug output disabled for production
    /*
    std::cout << "Emscripten: keydown_callback triggered! key='" << e->key << "'" << std::endl;
    */
    
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
    
    // Process the key (browser already handles repeat detection via e->repeat)
    {
        
        // Map key code and modifiers - convert to ASCII like SDL version
        u16 keyCode = 0;
        
        // Get the raw browser keycode
        u16 rawKeyCode = 0;
        if (e->keyCode > 0) {
            rawKeyCode = e->keyCode;
        } else if (e->which > 0) {
            rawKeyCode = e->which;
        } else if (e->key[0] != '\0') {
            rawKeyCode = e->key[0];
        }
        
        // Convert browser keycodes to ASCII like SDL version for compatibility
        if (rawKeyCode >= 32 && rawKeyCode <= 126) {
            // Simple ASCII mapping for printable characters
            keyCode = rawKeyCode;
            
            // Convert uppercase letters to lowercase to match ROM expectations
            // Browser keycodes for letters are always uppercase (A=65, Z=90)
            // but ROM expects lowercase (a=97, z=122)
            if (keyCode >= 65 && keyCode <= 90 && !e->shiftKey) {
                keyCode += 32; // Convert to lowercase
            }
        } else if (rawKeyCode == 13) { // Enter
            keyCode = 13;  // Keep as carriage return
        } else if (rawKeyCode == 9) { // Tab
            keyCode = 9;   // Tab character
        } else if (rawKeyCode == 27) { // Escape
            keyCode = 27;  // ESC character
        } else if (rawKeyCode == 8) { // Backspace
            keyCode = 8;   // Backspace
        } else if (rawKeyCode == 38) { // Up arrow
            keyCode = 16;  // Custom code for up arrow (DLE) - match SDL
        } else if (rawKeyCode == 40) { // Down arrow
            keyCode = 17;  // Custom code for down arrow (DC1) - match SDL
        } else if (rawKeyCode == 37) { // Left arrow
            keyCode = 18;  // Custom code for left arrow (DC2) - match SDL
        } else if (rawKeyCode == 39) { // Right arrow
            keyCode = 19;  // Custom code for right arrow (DC3) - match SDL
        } else {
            // For other keys, try to use the character from e->key
            if (e->key[0] != '\0' && e->key[1] == '\0') {
                // Single character key
                keyCode = e->key[0];
            } else {
                // Multi-character key name, use raw keycode
                keyCode = rawKeyCode & 0xFF;
            }
        }
        
        if (self->debugEnabled) {
            std::cout << "Emscripten keydown: key='" << e->key << "' rawKeyCode=0x" 
                      << std::hex << rawKeyCode << " -> ASCII=0x" << keyCode 
                      << std::dec << " ('" << (keyCode >= 32 && keyCode < 127 ? (char)keyCode : '?') 
                      << "') modifiers=0x" << std::hex << modifiers << std::dec << std::endl;
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
            
            // Submit immediately for single keys to improve responsiveness
            // Only batch if we get multiple keys within the debounce window
            if (self->pendingKeys.size() >= MAX_KEYS_PER_REPORT || 
                self->pendingKeys.size() == 1) {
                self->submitPendingKeys();
            }
        }
    }
    
    // Prevent default browser behavior for better keyboard handling
    return EM_TRUE;
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
    
    // Don't prevent default browser behavior for keyup
    return EM_FALSE;
}
#endif 