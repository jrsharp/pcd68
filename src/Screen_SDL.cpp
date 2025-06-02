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

#ifdef __EMSCRIPTEN__
    // For Emscripten/WebGL, use a more compatible format
    texture = SDL_CreateTexture(renderer,
                                SDL_PIXELFORMAT_ABGR8888,
                                SDL_TEXTUREACCESS_STREAMING,
                                SCREEN_WIDTH,
                                SCREEN_HEIGHT);
#else
    // For native builds
    texture = SDL_CreateTexture(renderer,
                                SDL_PIXELFORMAT_RGBA8888,
                                SDL_TEXTUREACCESS_STREAMING,
                                SCREEN_WIDTH,
                                SCREEN_HEIGHT);
#endif

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
    // For web builds, always process refresh to ensure graphics mode works properly
    // The refreshFlag check is moved to after the Screen::refresh() call

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
#ifdef __EMSCRIPTEN__
            // Simplified E-ink emulation for better web performance
            uint32_t color1, color2;
            if (wait < (REFRESH_INTERVAL * 0.5)) {
                color1 = 0xFF333333; // ABGR format
                color2 = 0xFFCCCCCC; // ABGR format
            } else {
                color1 = 0xFFEEEEEE; // ABGR format (light)
                color2 = 0xFF111111; // ABGR format (dark)
            }
            
            // Use memset-like approach for better performance
            for (int i = 0; i < (SCREEN_WIDTH * SCREEN_HEIGHT); i++) {
                outPixels[i] = (framebufferMem[i] == 0xFF) ? color1 : color2;
            }
#else
            // Native version with RGBA format
            if (wait < (REFRESH_INTERVAL * 0.2)) {
                for (int i = 0; i < (SCREEN_WIDTH * SCREEN_HEIGHT); i++) {
                    if (framebufferMem[i] == 0xFF) {
                        outPixels[i] = 0x111111FF; // RGBA format
                    } else {
                        outPixels[i] = 0xEEEEEEFF; // RGBA format
                    }
                }
            } else if (wait < (REFRESH_INTERVAL * 0.5)) {
                for (int i = 0; i < (SCREEN_WIDTH * SCREEN_HEIGHT); i++) {
                    if (framebufferMem[i] == 0xFF) {
                        outPixels[i] = 0xAAAAAAFF; // RGBA format
                    } else {
                        outPixels[i] = 0xBBBBBBFF; // RGBA format
                    }
                }
            } else if (wait < (REFRESH_INTERVAL * 0.8)) {
                for (int i = 0; i < (SCREEN_WIDTH * SCREEN_HEIGHT); i++) {
                    if (framebufferMem[i] == 0xFF) {
                        outPixels[i] = 0xBBBBBBFF; // RGBA format
                    } else {
                        outPixels[i] = 0xAAAAAAFF; // RGBA format
                    }
                }
            } else {
                for (int i = 0; i < (SCREEN_WIDTH * SCREEN_HEIGHT); i++) {
                    if (framebufferMem[i] == 0xFF) {
                        outPixels[i] = 0xEEEEEEFF; // RGBA format
                    } else {
                        outPixels[i] = 0x111111FF; // RGBA format
                    }
                }
            }
#endif
        } else {
            // Standard rendering (no e-ink emulation)
#ifdef __EMSCRIPTEN__
            // Manual conversion for Emscripten - more reliable than SDL_ConvertPixels
            for (int i = 0; i < (SCREEN_WIDTH * SCREEN_HEIGHT); i++) {
                uint8_t pixel = framebufferMem[i];
                // Convert from RGB332 to ABGR8888 format
                uint8_t r = (pixel & 0xE0) | ((pixel & 0xE0) >> 3) | ((pixel & 0xC0) >> 6);
                uint8_t g = ((pixel & 0x1C) << 3) | ((pixel & 0x1C)) | ((pixel & 0x18) >> 3);
                uint8_t b = ((pixel & 0x03) << 6) | ((pixel & 0x03) << 4) | ((pixel & 0x03) << 2) | (pixel & 0x03);
                
                // In memory: 0xAABBGGRR (ABGR8888)
                outPixels[i] = (0xFF << 24) | (b << 16) | (g << 8) | r;
            }
#else
            // For native builds, use SDL_ConvertPixels
            SDL_ConvertPixels(SCREEN_WIDTH, SCREEN_HEIGHT,
                          SDL_PIXELFORMAT_RGB332, framebufferMem, SCREEN_WIDTH * sizeof(uint8_t),
                          SDL_PIXELFORMAT_RGBA8888, outPixels, outPitch);
#endif
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
