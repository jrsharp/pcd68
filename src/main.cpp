#include <chrono>
#include <fstream>
#include <iostream>
#include <stdlib.h>
#include <thread>

#include "CPU.h"
#include "KCTL.h"
#include "Screen.h"
#include "TDA.h"

#include "text_demo.h"

#ifdef __EMSCRIPTEN__
#    include "emscripten.h"
#    define CYCLE_FACTOR 10
#    define INPUT_FACTOR 2
#else
#    define CYCLE_FACTOR 50
#    define INPUT_FACTOR 100
#endif

u8 systemRom[CPU::ROM_SIZE];     // ROM
u8 systemRam[CPU::RAM_SIZE];     // RAM
CPU* pcdCpu;                     // CPU
TDA* textDisplayAdapter;         // Graphics adapter
KCTL* keyboardController;        // Keyboard controller
Screen* pcdScreen;               // Screen instance
u32 keydownDebounceMs = 0;       // debounce period (in ms) for keyboard input
i64 interruptDebounceClocks = 0; // debounce period (in clocks) for keyboard input interrupt
i64 lastClock = 0;
u16 keyCode = 0;
u16 mod = 0;

bool handleEvents(u16* kc) {
#ifdef USE_SDL
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
            //std::cout << "code:" << keyCode << ", mod:" << mod << std::endl;
        }
    }
#endif
    return true;
}

// Main loop
bool mainLoop() {
    bool exit, clearKbdInt = false;

    // yield
    //std::this_thread::sleep_for(std::chrono::nanoseconds(2));

    // Process input and update screen
    i64 clocks = pcdCpu->getClock();
    if (clocks % CYCLE_FACTOR == 0) {
        // Process input only a fraction
        if (clocks % (CYCLE_FACTOR * INPUT_FACTOR) == 0) {
            exit = !handleEvents(&keyCode);

            if (keyCode > 0) {
                keyboardController->update(keyCode, mod);
                textDisplayAdapter->update();
                pcdScreen->refresh();
                keyCode = 0;
                mod = 0;
                clearKbdInt = true;
            }
        }

        //std::cout << "Clocks: " << clocks << std::endl;
        textDisplayAdapter->update();
        pcdScreen->refresh();
    }

    //std::cout << "\n\nBefore Instruction: \n\n" << std::endl;
    //pcdCpu->printState();

    // Advance CPU
    pcdCpu->execute();

    if (clearKbdInt) {
        keyboardController->clear();
        clearKbdInt = false;
    }

    return exit;
}

// Main (Load a program binary, set up I/O and begin execution)
int main(int argc, char** argv) {
    // Load program into systemRom memory
    if (argc < 2) {
        memcpy(systemRom, text_demo_bin, text_demo_bin_len);
    } else {
        std::ifstream programBinaryFile(argv[1], std::ios::binary);
        programBinaryFile.seekg(0, programBinaryFile.end);
        int size = programBinaryFile.tellg();
        programBinaryFile.seekg(0, programBinaryFile.beg);

        std::cout << "Loading file: " << argv[1] << "(" << size << ")" << std::endl;

        programBinaryFile.read(reinterpret_cast<char*>(systemRom + 0x00), size);
    }

    // Start with a CPU
    pcdCpu = new CPU();

    // Set up peripherals
    pcdScreen = new Screen(Screen::BASE_ADDR, sizeof(Screen::Registers) + sizeof(Screen::framebufferMem));
    textDisplayAdapter = new TDA(pcdCpu, pcdScreen, TDA::BASE_ADDR, sizeof(TDA::textMapMem) + sizeof(TDA::Registers));
    keyboardController = new KCTL(pcdCpu, KCTL::BASE_ADDR, sizeof(KCTL::Registers));

    // Attach to CPU
    pcdCpu->attachPeripheral(pcdScreen);
    pcdCpu->attachPeripheral(textDisplayAdapter);
    pcdCpu->attachPeripheral(keyboardController);

    // Any that require init()
    int result = pcdScreen->init();

    // And/or reset()
    keyboardController->reset();
    textDisplayAdapter->reset();

    // And then proceed to reset/start CPU:

    pcdCpu->debugger.enableLogging();
    pcdCpu->reset();
    // Clear all interrupts:
    pcdCpu->setIPL(0x00);

    //pcdCpu->debugger.watchpoints.addAt(0x103a);
    //pcdCpu->debugger.watchpoints.addAt(0x2002);

    // Initial screen:
    textDisplayAdapter->update();
    pcdScreen->refresh();

#ifdef __EMSCRIPTEN__
    emscripten_set_main_loop([]() { mainLoop(); }, -1, true);
#else
    while (!mainLoop()) continue;
#endif

    std::cout << "Clocks: " << std::dec << pcdCpu->getClock() << std::endl;
    return 0;
}
