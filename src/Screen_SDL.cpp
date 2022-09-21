/*
 * Copyright (c) 2022, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 */

#include "Screen_SDL.h"
#include <iostream>

// C'tor
Screen_SDL::Screen_SDL(uint32_t start, uint32_t size, bool fullEmulation) :
    Screen(start, size),
    Peripheral(start, size) {

    this->fullEmulation = fullEmulation;
}

// Init SDL
int Screen_SDL::init() {
    registers.busy = false;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        std::cerr << "Could not init SDL: " << SDL_GetError() << std::endl;
        return -1;
    }

    window = SDL_CreateWindow("Screen", SDL_WINDOWPOS_UNDEFINED,
                              SDL_WINDOWPOS_UNDEFINED, SCREEN_WIDTH * 2, SCREEN_HEIGHT * 2, SDL_WINDOW_SHOWN);
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "linear");

    if (renderer == NULL) {
        std::cerr << "Could not init renderer: " << SDL_GetError() << std::endl;
        return -1;
    }

    texture = SDL_CreateTexture(renderer,
                                SDL_PIXELFORMAT_RGBA8888,
                                SDL_TEXTUREACCESS_STREAMING,
                                SCREEN_WIDTH,
                                SCREEN_HEIGHT);

    if (texture == NULL) {
        std::cerr << "Could not init texture: " << SDL_GetError() << std::endl;
        return -1;
    }

    return 0;
}

void Screen_SDL::reset() {
    Screen::reset();
    refreshFlag = true;
}

// Refresh screen (memcpy + SDL refresh)
int Screen_SDL::refresh() {
    if (Screen::refresh() != 0) {
        return -1;
    }
    if (refreshFlag) {
        uint32_t* outPixels;
        int outPitch;

        // Lock texture
        if (SDL_LockTexture(texture, NULL, (void**)&outPixels, &outPitch) < 0) {
            return -1;
        }

        if (wait == 0) {
            registers.busy = true;
            if (fullEmulation) {
                wait = REFRESH_INTERVAL;
            } else {
                wait = 1;
            }
        }

        if (wait > 1) {
            // Approximate voltage cycling effects of physical E-Ink display
            if (wait < (REFRESH_INTERVAL * 0.2)) {
                for (int i = 0; i < (SCREEN_WIDTH * SCREEN_HEIGHT); i++) {
                    if (framebufferMem[i] == 0xFF) {
                        outPixels[i] = 0x111111FF;
                    } else {
                        outPixels[i] = 0xEEEEEEFF;
                    }
                }
            } else if (wait < (REFRESH_INTERVAL * 0.5)) {
                for (int i = 0; i < (SCREEN_WIDTH * SCREEN_HEIGHT); i++) {
                    if (framebufferMem[i] == 0xFF) {
                        outPixels[i] = 0xAAAAAAFF;
                    } else {
                        outPixels[i] = 0xBBBBBBFF;
                    }
                }
            } else if (wait < (REFRESH_INTERVAL * 0.8)) {
                for (int i = 0; i < (SCREEN_WIDTH * SCREEN_HEIGHT); i++) {
                    if (framebufferMem[i] == 0xFF) {
                        outPixels[i] = 0xBBBBBBFF;
                    } else {
                        outPixels[i] = 0xAAAAAAFF;
                    }
                }
            } else {
                for (int i = 0; i < (SCREEN_WIDTH * SCREEN_HEIGHT); i++) {
                    if (framebufferMem[i] == 0xFF) {
                        outPixels[i] = 0xEEEEEEFF;
                    } else {
                        outPixels[i] = 0x111111FF;
                    }
                }
            }
        } else {
            SDL_ConvertPixels(SCREEN_WIDTH, SCREEN_HEIGHT,
                              SDL_PIXELFORMAT_RGB332, framebufferMem, SCREEN_WIDTH * sizeof(uint8_t),
                              SDL_PIXELFORMAT_RGBA8888, outPixels, outPitch);
        }
        SDL_UnlockTexture(texture);

        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, nullptr, nullptr);
        SDL_RenderPresent(renderer);

        //registers.busy = false;
        //refreshFlag = false;
    }

    return 0;
}
