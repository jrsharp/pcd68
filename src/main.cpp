#include <chrono>
#include <fstream>
#include <iostream>
#include <stdlib.h>
#include <thread>
#include <stdio.h>

#include "PCD68_CPU.h"
#include "KCTL.h"
#include "Screen_SDL.h"
#include "TDA.h"
#include "UART.h"
#include "KeyboardInput.h"

#include "text_demo.h"

#ifdef __EMSCRIPTEN__
#    include "emscripten.h"
#    define CYCLE_FACTOR 10
#    define INPUT_FACTOR 2
#else
#    define CYCLE_FACTOR 50
#    define INPUT_FACTOR 100
#endif

u8* systemRom;                   // ROM
u8* systemRam;                   // RAM
CPU* pcdCpu;                     // CPU
TDA* textDisplayAdapter;         // Graphics adapter
KCTL* keyboardController;        // Keyboard controller
UART* uartController;            // UART controller
Screen* pcdScreen;               // Screen instance
KeyboardInput* keyboardInput;    // Keyboard input handler
i64 interruptDebounceClocks = 0; // debounce period (in clocks) for keyboard input interrupt
i64 lastClock = 0;

// Keyboard event handler callback
void handleKeyEvent(u16 keyCode, u16 mod) {
    if (keyCode > 0) {
        keyboardController->update(keyCode, mod);
        textDisplayAdapter->update();
        pcdScreen->refresh();
    }
}

// Main loop
bool mainLoop() {
    bool exit = false, clearKbdInt = false;

    // Process input and update screen
    i64 clocks = pcdCpu->getClock();

    // Input processing / peripheral servicing
    if (clocks % CYCLE_FACTOR == 0) {
        // Check/advance busy screen:
        if (pcdScreen->registers.busy) {
            pcdScreen->advance(1);
        }

        // Process input only a fraction
        if (clocks % (CYCLE_FACTOR * INPUT_FACTOR) == 0) {
            // Poll for keyboard events
            exit = !keyboardInput->poll();
            
            // Poll UART for data
            uartController->poll();
            
            // Flag to clear keyboard interrupt
            clearKbdInt = true;
        }

        textDisplayAdapter->update();
        pcdScreen->refresh();
    }

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
    // Allocate ROM + RAM:
    systemRom = (u8*)malloc(CPU::ROM_SIZE);
    systemRam = (u8*)malloc(CPU::RAM_SIZE);

    if (systemRom == nullptr || systemRam == nullptr) {
        std::cerr << "Unable to allocate memory for system RAM + ROM" << std::endl;
        return -1;
    }

    // Default to using full E-Ink emulation:
    bool fullEmulation = true;
    // Load program into systemRom memory
    if (argc < 2) {
        memcpy(systemRom, text_demo_bin, text_demo_bin_len);
    } else {
        if (argc > 2) {
            // second arg is fullEmulation flag
            if (std::string(argv[2]).compare("-nf") == 0) {
                fullEmulation = false;
            }
        }

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
    pcdScreen = new Screen_SDL(Screen::BASE_ADDR, sizeof(Screen::Registers) + sizeof(Screen::framebufferMem), fullEmulation);
    textDisplayAdapter = new TDA(pcdCpu, pcdScreen, TDA::BASE_ADDR, sizeof(TDA::textMapMem) + sizeof(TDA::Registers));
    keyboardController = new KCTL(pcdCpu, KCTL::BASE_ADDR, sizeof(KCTL::Registers));
    uartController = new UART(pcdCpu, UART::BASE_ADDR, sizeof(UART::Registers));

    // Attach to CPU
    pcdCpu->attachPeripheral(pcdScreen);
    pcdCpu->attachPeripheral(textDisplayAdapter);
    pcdCpu->attachPeripheral(keyboardController);
    pcdCpu->attachPeripheral(uartController);

    // Any that require init()
    int result = pcdScreen->init();
    result = uartController->init();

    // Initialize keyboard input
    keyboardInput = createKeyboardInput();
    keyboardInput->setKeyEventCallback(handleKeyEvent);
    result = keyboardInput->init();
    if (result != 0) {
        std::cerr << "Failed to initialize keyboard input" << std::endl;
        return -1;
    }

#ifdef __EMSCRIPTEN__
    // Connect UART to websocket for Emscripten target
    const char* webSocketUrl1 = "ws://localhost:8080";
    const char* webSocketUrl2 = "ws://localhost:8081";
    result = uartController->connectWebsocket(webSocketUrl1, webSocketUrl2);
    if (result != 0) {
        std::cerr << "Failed to connect UART to websocket" << std::endl;
        // Don't return - continue without websocket
    }
#endif

    // Initialize keyboard input
    keyboardInput = createKeyboardInput();
    keyboardInput->setKeyEventCallback(handleKeyEvent);
    result = keyboardInput->init();
    if (result != 0) {
        std::cerr << "Failed to initialize keyboard input" << std::endl;
        return -1;
    }

    // And/or reset()
    keyboardController->reset();
    textDisplayAdapter->reset();
    uartController->reset();

    // And then proceed to reset/start CPU:
    pcdCpu->debugger.enableLogging();
    pcdCpu->reset();
    // Clear all interrupts:
    pcdCpu->setIPL(0x00);

    // Initial screen:
    textDisplayAdapter->update();
    pcdScreen->refresh();

#ifdef __EMSCRIPTEN__
    emscripten_set_main_loop([]() { mainLoop(); }, -1, true);
#else
    while (!mainLoop()) continue;
#endif

    // Clean up
    delete keyboardInput;
    delete uartController;
    
    std::cout << "Clocks: " << std::dec << pcdCpu->getClock() << std::endl;
    return 0;
}
