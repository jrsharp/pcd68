/*
 * Copyright (c) 2025, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#include "KeyboardInputSDL.h"
#include <iostream>
#include <algorithm>

KeyboardInputSDL::KeyboardInputSDL() 
    : keydownDebounceMs(0), 
      keyEventCount(0), 
      debugEnabled(false),
      lastReportTimeMs(0),
      currentModifiers(0) {
}

KeyboardInputSDL::~KeyboardInputSDL() {
    // SDL cleanup happens elsewhere, in Screen_SDL
}

int KeyboardInputSDL::init() {
    // SDL is already initialized in Screen_SDL
    std::cout << "KeyboardInputSDL initialized" << std::endl;
    pendingKeys.reserve(MAX_KEYS_PER_REPORT); // Pre-allocate space for max keys
    return 0;
}

void KeyboardInputSDL::setDebugMode(bool enabled) {
    debugEnabled = enabled;
    if (debugEnabled) {
        std::cout << "Keyboard debug mode enabled" << std::endl;
    }
}

void KeyboardInputSDL::submitPendingKeys() {
    if (pendingKeys.empty()) {
        return;
    }

    // Use a fixed-size array to avoid heap allocations
    u8 keyCodes[MAX_KEYS_PER_REPORT];

    // Extract key codes from pending keys, limiting to max keys
    size_t keyCount = std::min(pendingKeys.size(), static_cast<size_t>(MAX_KEYS_PER_REPORT));

    for (size_t i = 0; i < keyCount; i++) {
        // Cast to u8 since KCTL can only handle 8-bit keycodes
        keyCodes[i] = static_cast<u8>(pendingKeys[i].keyCode & 0xFF);
    }

    if (debugEnabled) {
        std::cout << "Submitting multi-key report with " << keyCount << " key(s) and modifiers 0x"
                  << std::hex << currentModifiers << std::dec << std::endl;

        for (size_t i = 0; i < keyCount; i++) {
            std::cout << "  Key[" << i << "]: 0x" << std::hex << (int)keyCodes[i]
                      << std::dec << " ('" << (char)keyCodes[i] << "')" << std::endl;
        }
    }

    // Process the keys if we have any
    if (keyCount > 0) {
        // Prefer multi-key callback if available, fall back to individual key callback if not
        if (keyMultiEventCallback) {
            keyMultiEventCallback(keyCodes, keyCount, currentModifiers & 0xFF);
        } else if (keyEventCallback) {
            // Fall back to sending individual key events if multi-key callback not set
            for (size_t i = 0; i < keyCount; i++) {
                keyEventCallback(keyCodes[i], currentModifiers);
            }
        }
    }

    // Clear pending keys
    pendingKeys.clear();

    // Update last report time
    lastReportTimeMs = SDL_GetTicks();
}

bool KeyboardInputSDL::poll() {
    // Check if pending keys need to be submitted due to timeout
    u32 ticksNow = SDL_GetTicks();
    if (!pendingKeys.empty() && 
        SDL_TICKS_PASSED(ticksNow, lastReportTimeMs + REPORT_COLLECTION_WINDOW_MS)) {
        submitPendingKeys();
    }
    
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_QUIT) {
            return false;
        }
        if (event.type == SDL_KEYDOWN) {
            u32 ticksNow = SDL_GetTicks();
            u32 keyCode = event.key.keysym.sym;  // Use u32 to avoid truncation
            u16 mod = event.key.keysym.mod;
            bool isRepeat = event.key.repeat != 0;

            // Update current modifiers
            currentModifiers = mod;

            if (this->debugEnabled) {
                std::cout << "SDL_KEYDOWN - Raw keyCode: 0x" << std::hex << keyCode
                          << ", mod: 0x" << std::hex << mod
                          << ", repeat: " << (isRepeat ? "yes" : "no")
                          << ", scancode: " << (int)event.key.keysym.scancode
                          << ", name: " << SDL_GetKeyName(keyCode)
                          << std::dec << std::endl;
            }

            // Skip repeated keys and check debounce
            if (!isRepeat && SDL_TICKS_PASSED(ticksNow, keydownDebounceMs)) {
                // Throttle keydown events for 1ms (was 5ms)
                keydownDebounceMs = ticksNow + 1;
                keyEventCount++;

                // Convert SDL keysym to ASCII if possible for better display compatibility
                u8 asciiCode = 0;
                if (keyCode >= 32 && keyCode <= 126) {
                    // Simple ASCII mapping for printable characters
                    asciiCode = (u8)(keyCode & 0xFF);
                } else if (keyCode == SDLK_RETURN || keyCode == SDLK_KP_ENTER) {
                    asciiCode = '\r';  // Convert Enter to carriage return
                } else if (keyCode == SDLK_TAB) {
                    asciiCode = '\t';  // Tab character
                } else if (keyCode == SDLK_ESCAPE) {
                    asciiCode = 27;    // ESC character
                } else if (keyCode == SDLK_BACKSPACE) {
                    asciiCode = 8;     // Backspace
                } else if (keyCode == SDLK_UP) {
                    asciiCode = 16;    // Custom code for up arrow (DLE)
                } else if (keyCode == SDLK_DOWN) {
                    asciiCode = 17;    // Custom code for down arrow (DC1)
                } else if (keyCode == SDLK_LEFT) {
                    asciiCode = 18;    // Custom code for left arrow (DC2)
                } else if (keyCode == SDLK_RIGHT) {
                    asciiCode = 19;    // Custom code for right arrow (DC3)
                } else {
                    // For other keys, just use the original keycode
                    asciiCode = (u8)(keyCode & 0xFF);
                }

                if (this->debugEnabled) {
                    std::cout << "SDL Keyboard event #" << keyEventCount
                              << " - Queuing key: keyCode=0x" << std::hex << keyCode
                              << " raw (" << (char)keyCode << ") -> ASCII 0x"
                              << (int)asciiCode << " (" << (asciiCode >= 32 && asciiCode < 127 ? (char)asciiCode : '?') << ")"
                              << ", mod=0x" << mod << std::dec << std::endl;
                }

                // Add to pending keys
                PendingKey key;
                key.keyCode = asciiCode;  // Use the ASCII code instead of SDL keycode
                key.timestamp = ticksNow;
                pendingKeys.push_back(key);
                
                // If we've reached the maximum keys or this is the first key,
                // start the collection window timer
                if (pendingKeys.size() == 1) {
                    lastReportTimeMs = ticksNow;
                }
                
                // If we've hit the max keys per report, submit immediately
                if (pendingKeys.size() >= MAX_KEYS_PER_REPORT) {
                    submitPendingKeys();
                }
            } else if (this->debugEnabled && isRepeat) {
                std::cout << "Keyboard event ignored - key repeat" << std::endl;
            } else if (this->debugEnabled) {
                std::cout << "Keyboard event ignored - debounce" << std::endl;
            }
        } else if (event.type == SDL_KEYUP && this->debugEnabled) {
            u32 keyCode = event.key.keysym.sym;  // Use u32 for consistency
            u16 mod = event.key.keysym.mod;
            
            // Update current modifiers
            currentModifiers = mod;
            
            std::cout << "SDL_KEYUP - keyCode: 0x" << std::hex << keyCode 
                      << ", mod: 0x" << mod
                      << ", name: " << SDL_GetKeyName(keyCode) << std::dec << std::endl;
        }
    }
    
    // Submit any pending keys that have accumulated during the poll
    if (!pendingKeys.empty() && 
        SDL_TICKS_PASSED(ticksNow, lastReportTimeMs + REPORT_COLLECTION_WINDOW_MS)) {
        submitPendingKeys();
    }
    
    return true;
} 