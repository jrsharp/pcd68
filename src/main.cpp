#include <iostream>
#include <fstream>
#include <thread>
#include <stdlib.h>

#include "CPU.h"
#include "TDA.h"
#include "KCTL.h"

#include "text_demo.h"

#ifdef __EMSCRIPTEN__
#include "emscripten.h"
#endif

#if(USE_SDL)
#pragma message("Including SDL screen")
#include "Screen_SDL.h"
#include <chrono>
#else
#pragma message("Including memory screen")
#include "Screen_Memory.h"
#endif

u8 systemRom[CPU::ROM_SIZE];    // ROM
u8 systemRam[CPU::RAM_SIZE];    // RAM
Screen* pcdScreen;              // Screen instance
u32 keydownDebounceMs = 0;      // debounce period (in ms) for keyboard input
i64 interruptDebounceClocks = 5000;// debounce period (in clocks) for keyboard input interrupt
i64 lastClock = 0;
u16 keyCode = 0;
u16 mod = 0;

#if (USE_SDL)
bool handleEvents(u16 *kc) {
    SDL_Event event;
    SDL_PollEvent(&event);
    if (event.type == SDL_QUIT) {
        return false;
    }
    if (event.type == SDL_KEYDOWN) {
        u32 ticksNow = SDL_GetTicks();
        if (SDL_TICKS_PASSED(ticksNow, keydownDebounceMs)) {
            // Throttle keydown events for 5ms.
            keydownDebounceMs = ticksNow + 5;
            keyCode = event.key.keysym.sym;
            mod = event.key.keysym.mod;
            //std::cout << "code:" << keyCode << std::endl;
        }
    } else if (event.type == SDL_KEYUP) {
        keyCode = 0;
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
        memcpy(systemRom, text_demo_bin, text_demo_bin_len);
    } else {
        std::ifstream programBinaryFile(argv[1], std::ios::binary);
        programBinaryFile.seekg(0, programBinaryFile.end);
        int size = programBinaryFile.tellg();
        programBinaryFile.seekg(0, programBinaryFile.beg);

        std::cout << "Loading file: " << argv[1] << "(" << size << ")" << std::endl;

        programBinaryFile.read(reinterpret_cast<char *>(systemRom + 0x00), size);
    }

    // Random pixels to system ram used for fb:
    /*
    uint8_t * ptr = (uint8_t*)systemRam + 0x10000;
    for (int i = 0; i < (400 * 300); i++) {
        *ptr++ = rand();
    }
    */

    CPU* pcdCpu = new CPU();

    // Init screen:
    pcdScreen = new Screen(0x400000, 8);
    int result = pcdScreen->init();
    TDA* textDisplayAdapter = new TDA(pcdCpu, TDA::BASE_ADDR, ((80 * 23) + 8));
    //KCTL* keyboardController = new KCTL(pcdCpu, KCTL::BASE_ADDR, 8);

    pcdCpu->attachPeripheral(pcdScreen);
    pcdCpu->attachPeripheral(textDisplayAdapter);
    //pcdCpu->attachPeripheral(keyboardController);

    //pcdCpu->debugger.enableLogging();

    //keyboardController->reset();
    textDisplayAdapter->reset();
    pcdCpu->reset();
    // Clear all interrupts:
    pcdCpu->setIPL(0x00);

    //pcdCpu->debugger.watchpoints.addAt(0x103a);
    //pcdCpu->debugger.watchpoints.addAt(0x2002);

    bool exit, clearKbdInt = false;

    // Initial screen:
    updateScreen();

    while (!exit) {

#if (USE_SDL)
        exit = !handleEvents(&keyCode);
        // Throttle:
        std::this_thread::sleep_for(std::chrono::nanoseconds(2));
#endif

        i64 clocks = pcdCpu->getClock();

        // Update screen:
        if (clocks % 5000 == 0) {
            textDisplayAdapter->update();
            updateScreen();
        }
        
        /*
        if (keyCode > 0) {
            if (clocks > lastClock + interruptDebounceClocks) {
                keyboardController->update(keyCode, mod);
                textDisplayAdapter->update();
                updateScreen();
                keyCode = 0;
                mod = 0;
                lastClock = clocks;
                clearKbdInt = true;
            }
        }
        */

        //std::cout << "\n\nBefore Instruction: \n\n" << std::endl;
        //pcdCpu->printState();
        
        // Advance CPU:
        pcdCpu->execute();
        /*
        if (clearKbdInt) {
            keyboardController->clear();
            clearKbdInt = false;
        }
        */
    }

    return 0;
}
