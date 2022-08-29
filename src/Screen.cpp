#include "Screen.h"
#include <iostream>

// C'tor
Screen::Screen(uint32_t start, uint32_t size) :
    Peripheral(start, size) {
    refreshFlag = false;
}

// Init SDL
int Screen::init() {
    registers.busy = false;

#ifdef USE_SDL
    std::cerr << "Compiled with SDL2, initializing: " << SDL_GetError() << std::endl;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        std::cerr << "Could not init SDL: " << SDL_GetError() << std::endl;
        return -1;
    } else {
        std::cerr << "Successfully initialized SDL2. " << std::endl;
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
#endif

    return 0;
}

void Screen::reset() {
    refreshFlag = true;
}

u8 Screen::read8(u32 addr) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        return get8((u8*)&registers, addr - BASE_ADDR);
    } else if (addr >= (BASE_ADDR + sizeof(registers)) && addr < BASE_ADDR + sizeof(framebufferMem)) {
        return get8((u8*)framebufferMem, addr - (BASE_ADDR + sizeof(registers)));
    }
    return 0;
}

u16 Screen::read16(u32 addr) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        return get16((u8*)&registers, addr - BASE_ADDR);
    } else if (addr >= (BASE_ADDR + sizeof(registers)) && addr < BASE_ADDR + sizeof(framebufferMem)) {
        return get16((u8*)framebufferMem, addr - (BASE_ADDR + sizeof(registers)));
    }
    return 0;
}

void Screen::write8(u32 addr, u8 val) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        set8((u8*)&registers, addr - BASE_ADDR, val);
        refreshFlag = true;
    } else if (addr >= (BASE_ADDR + sizeof(registers)) && addr < BASE_ADDR + sizeof(framebufferMem)) {
        set8((u8*)framebufferMem, addr - (BASE_ADDR + sizeof(registers)), val);
        refreshFlag = true;
    }
}

void Screen::write16(u32 addr, u16 val) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        set16((u8*)&registers, addr - BASE_ADDR, val);
        refreshFlag = true;
    } else if (addr >= (BASE_ADDR + sizeof(registers)) && addr < BASE_ADDR + sizeof(framebufferMem)) {
        set16((u8*)framebufferMem, addr - (BASE_ADDR + sizeof(registers)), val);
        refreshFlag = true;
    }
}

// Refresh screen (SDL refresh)
int Screen::refresh() {
    if (refreshFlag) {

#ifdef USE_SDL
        void* outPixels;
        int outPitch;

        registers.busy = true;

        if (SDL_LockTexture(texture, NULL, &outPixels, &outPitch) < 0) {
            return -1;
        }
        SDL_ConvertPixels(SCREEN_WIDTH, SCREEN_HEIGHT,
                          SDL_PIXELFORMAT_RGB332, framebufferMem, SCREEN_WIDTH * sizeof(uint8_t),
                          SDL_PIXELFORMAT_RGBA8888, outPixels, outPitch);
        SDL_UnlockTexture(texture);

        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, nullptr, nullptr);
        SDL_RenderPresent(renderer);
#endif

        registers.busy = false;
        refreshFlag = false;
    }

    return 0;
}
