#include <iostream>
#include <fstream>
#include <thread>
#include <stdlib.h>

#include "CPU.h"
#include "TDA.h"
#include "KCTL.h"

#if(USE_SDL==1)
#include "Screen_SDL.h"
#include <chrono>
#else
#include "Screen_Memory.h"
#endif

u8 systemRom[CPU::ROM_SIZE];    // ROM
u8 systemRam[CPU::RAM_SIZE];    // RAM
Screen* pcdScreen;              // Screen instance
u32 keydownDebounceMs = 0;      // debounce period (in ms) for keyboard input
u16 keyCode = 0;
char asciiValue;

#if(USE_SDL==1)
bool handleEvents(u16 *keycode) {
    SDL_Event event;
    SDL_PollEvent(&event);
    if (event.type == SDL_QUIT) {
        return false;
    }
    if (event.type == SDL_KEYDOWN) {
        u32 ticksNow = SDL_GetTicks();
        if (SDL_TICKS_PASSED(ticksNow, keydownDebounceMs)) {
            // Throttle keydown events for 20ms.
            keydownDebounceMs = ticksNow + 20;
            keyCode = event.key.keysym.sym;
            keyCode = event.key.keysym.unicode;
            std::cout << "code:" << event.key.keysym.sym << std::endl;
        }
    } else if (event.type == SDL_TEXTINPUT) {
        std::cout << "TextEvent: >" << event.text.text << "<" << std::endl;
        asciiValue = event.text.text[0];
    } else {
        *keycode = 0;
    }

    return true;
}

void runMainLoop() {
#ifdef __EMSCRIPTEN__
    emscripten_set_main_loop([]() { handleEvents(&keyCode); }, 0, true);
#else
    while (handleEvents(&keyCode));
#endif
}

#endif

// from system RAM to Screen's memory
void updateScreen() {
    uint8_t * pixelPtr = (uint8_t*)pcdScreen->framebufferMem;
    uint8_t * ramPtr = (uint8_t*)systemRam + 0x10000; // Framebuffer start addr in system RAM
    std::memcpy(pixelPtr, ramPtr, (400 * 300)); // 400x300x8bpp (RGB332)
    pcdScreen->refresh();
}

// Main (Load a program binary, set up I/O and begin execution)
int main(int argc, char **argv) {
    // Load program:
    if (argc < 2) {
        std::cout << "Usage: pcd68 <program.bin>" << std::endl;
        exit(-1);
    }

    std::ifstream programBinaryFile(argv[1], std::ios::binary);
    programBinaryFile.seekg(0, programBinaryFile.end);
    int size = programBinaryFile.tellg();
    programBinaryFile.seekg(0, programBinaryFile.beg);

    std::cout << "Loading file: " << argv[1] << "(" << size << ")" << std::endl;

    programBinaryFile.read(reinterpret_cast<char *>(systemRom + 0x00), size);

    // Random pixels to system ram used for fb:
    uint8_t * ptr = (uint8_t*)systemRam + 0x10000;
    for (int i = 0; i < (400 * 300); i++) {
        *ptr++ = rand();
    }

    CPU* pcdCpu = new CPU();

    // Init screen:
    pcdScreen = new Screen(0x400000, 8);
    int result = pcdScreen->init();
    TDA* textDisplayAdapter = new TDA(pcdCpu, TDA::BASE_ADDR, ((80 * 23) + 8));
    KCTL* keyboardController = new KCTL(pcdCpu, KCTL::BASE_ADDR, 8);

    pcdCpu->attachPeripheral(pcdScreen);
    pcdCpu->attachPeripheral(textDisplayAdapter);
    pcdCpu->attachPeripheral(keyboardController);

    pcdCpu->debugger.enableLogging();

    keyboardController->reset();
    textDisplayAdapter->reset();
    pcdCpu->reset();

    bool exit = false;

    // Initial screen:
    updateScreen();

    while (!exit) {

#if(USE_SDL == 1)
        exit = !handleEvents(&keyCode);
        // Throttle:
        std::this_thread::sleep_for(std::chrono::nanoseconds(5));
#endif

        // Update screen:
        if (pcdCpu->getClock() % 5000 == 0) {
            textDisplayAdapter->update();
            updateScreen();
        }
        
        if (keyCode > 0) {
            keyboardController->update(keyCode);
            keyboardController->update(asciiValue);
            textDisplayAdapter->update();
            updateScreen();
        }

        //std::cout << "\n\nBefore Instruction: \n\n" << std::endl;
        //pcdCpu->printState();
        
        // Advance CPU:
        pcdCpu->execute();
    }

    return 0;
}
