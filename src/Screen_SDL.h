/*
 * Copyright (c) 2022, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include "Screen.h"
#include "SDL2/SDL.h"
#include <stdint.h>

class Screen_SDL : public Screen {

public:
    
    Screen_SDL(uint32_t start, uint32_t size, bool fullEmulation = true);

    virtual int init();
    virtual void reset();
    virtual int refresh();

private:
    SDL_Window* window;
    SDL_Renderer* renderer;
    SDL_Texture* texture;
    bool fullEmulation;
};
