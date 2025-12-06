/*
 * Copyright (c) 2025, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#include "KeyboardInput.h"

#ifdef __EMSCRIPTEN__
#include "KeyboardInputEmscripten.h"
#elif defined(__DJGPP__)
#include "KeyboardInputDOS.h"
#else
#include "KeyboardInputSDL.h"
#endif

#include <iostream>

/**
 * Create the appropriate KeyboardInput implementation based on the platform
 * @return A new KeyboardInput instance
 */
KeyboardInput* createKeyboardInput() {
#ifdef __EMSCRIPTEN__
    std::cout << "createKeyboardInput: Creating KeyboardInputEmscripten" << std::endl;
    return static_cast<KeyboardInput*>(new KeyboardInputEmscripten());
#elif defined(__DJGPP__)
    std::cout << "createKeyboardInput: Creating KeyboardInputDOS" << std::endl;
    return static_cast<KeyboardInput*>(new KeyboardInputDOS());
#else
    std::cout << "createKeyboardInput: Creating KeyboardInputSDL" << std::endl;
    return static_cast<KeyboardInput*>(new KeyboardInputSDL());
#endif
} 