/*
 * Copyright (c) 2025, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#include "KeyboardInputEmscripten.h"
#include <iostream>

KeyboardInputEmscripten::KeyboardInputEmscripten() {
#ifdef __EMSCRIPTEN__
    lastKeyTime = 0;
#endif
}

KeyboardInputEmscripten::~KeyboardInputEmscripten() {
#ifdef __EMSCRIPTEN__
    // Remove event listeners if needed
    emscripten_set_keydown_callback(EMSCRIPTEN_EVENT_TARGET_WINDOW, nullptr, 0, nullptr);
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
    
    return 0;
#else
    return -1;
#endif
}

bool KeyboardInputEmscripten::poll() {
    // Emscripten events are handled via callbacks, so poll() is a no-op
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
        
        // Create a modifier flags byte
        u16 modifiers = 0;
        if (e->shiftKey) modifiers |= 0x01;
        if (e->ctrlKey)  modifiers |= 0x02;
        if (e->altKey)   modifiers |= 0x04;
        if (e->metaKey)  modifiers |= 0x08;
        
        // Call the callback
        if (keyCode > 0 && self->keyEventCallback) {
            self->keyEventCallback(keyCode, modifiers);
        }
    }
    
    // Don't prevent default browser behavior
    return EM_FALSE;
}
#endif 