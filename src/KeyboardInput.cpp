/*
 * Copyright (c) 2025, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#include "KeyboardInput.h"
#include "KeyboardInputSDL.h"

#ifdef __EMSCRIPTEN__
#include "KeyboardInputEmscripten.h"
#endif

/**
 * Create the appropriate KeyboardInput implementation based on the platform
 * @return A new KeyboardInput instance
 */
KeyboardInput* createKeyboardInput() {
#ifdef __EMSCRIPTEN__
    return static_cast<KeyboardInput*>(new KeyboardInputEmscripten());
#else
    return static_cast<KeyboardInput*>(new KeyboardInputSDL());
#endif
} 