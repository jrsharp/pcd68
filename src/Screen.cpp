#include "Screen.h"
#include <iostream>

// Init SDL
int Screen::init() {
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

// Refresh screen (memcpy + SDL refresh)
int Screen::refresh() {
    void *outPixels;
    int outPitch;

    //SDL_UpdateTexture(texture, NULL, framebufferMem, SCREEN_WIDTH * sizeof(uint8_t));
    
    if (SDL_LockTexture(texture, NULL, &outPixels, &outPitch) < 0) {
        return -1;
    }
    SDL_ConvertPixels(SCREEN_WIDTH, SCREEN_HEIGHT,
            SDL_PIXELFORMAT_RGB332, framebufferMem, SCREEN_WIDTH * sizeof(uint8_t),
            SDL_PIXELFORMAT_RGBA8888, outPixels, outPitch);
    SDL_UnlockTexture(texture);

    SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer, texture, NULL, NULL);
    SDL_RenderPresent(renderer);

    return 0;
}
