/*
 * Copyright (c) 2025, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#include "KeyboardInputSDL.h"
#include <iostream>

KeyboardInputSDL::KeyboardInputSDL() : keydownDebounceMs(0) {
}

KeyboardInputSDL::~KeyboardInputSDL() {
    // SDL cleanup happens elsewhere, in Screen_SDL
}

int KeyboardInputSDL::init() {
    // SDL is already initialized in Screen_SDL
    return 0;
}

bool KeyboardInputSDL::poll() {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_QUIT) {
            return false;
        }
        if (event.type == SDL_KEYDOWN) {
            u32 ticksNow = SDL_GetTicks();
            if (SDL_TICKS_PASSED(ticksNow, keydownDebounceMs)) {
                // Throttle keydown events for 5ms.
                keydownDebounceMs = ticksNow + 5;
                u16 keyCode = event.key.keysym.sym;
                u16 mod = event.key.keysym.mod;
                
                // Call the callback if it's set
                if (keyEventCallback) {
                    keyEventCallback(keyCode, mod);
                }
            }
        }
    }
    return true;
} 