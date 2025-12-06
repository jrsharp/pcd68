/*
 * Copyright (c) 2024, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 *
 * PCD-68 DOS main entry point
 * Simplified version for DOS/DJGPP without threading
 * Uses Moira 68000 CPU core (requires DJGPP with GCC 12+ for C++14 support)
 */

#ifdef __DJGPP__

#include <fstream>
#include <iostream>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <conio.h>
#include <sys/farptr.h>
#include <go32.h>
#include <dpmi.h>

#include "PCD68_CPU.h"
#include "KCTL.h"
#include "Screen_DOS.h"
#include "TDA.h"
#include "UART_DOS.h"
#include "KeyboardInput.h"

// Cycle factors for DOS - tuned for performance
#define CYCLE_FACTOR 5         // Screen refresh every 5 loops
#define INPUT_FACTOR 10        // Keyboard poll every 5 loops

// Global state
u8* systemRom;
u8* systemRam;
CPU* pcdCpu;
TDA* textDisplayAdapter;
KCTL* keyboardController;
UART* uartController;
Screen* pcdScreen;
KeyboardInput* keyboardInput;

// Debug flags
bool enableKeyboardDebug = false;
bool enableUartDebug = false;
bool enableTdaDebug = false;

// Status overlay
bool showOverlay = false;
uint32_t loopCount = 0;
uint32_t lastLoopCount = 0;
i64 lastClocks = 0;
uint32_t loopsPerSecond = 0;
uint32_t clocksPerSecond = 0;

// UART connection
int uartCom1 = 0;
int uartCom2 = 0;
bool usingSerial = false;

// Keyboard event handler
void handleKeyEvent(u16 keyCode, u16 mod) {
    if (keyCode > 0) {
        keyboardController->update(keyCode & 0xFF, mod & 0xFF);
        textDisplayAdapter->update();
        pcdScreen->refresh();
    }
}

// Multi-key event handler
void handleMultiKeyEvent(const u8* keycodes, u8 keyCount, u8 mod) {
    if (keyCount > 0) {
        keyboardController->updateMultiKey(keycodes, keyCount, mod);
        textDisplayAdapter->update();
        pcdScreen->refresh();
    }
}

// Main loop
bool mainLoop() {
    static int inputCounter = 0;
    static int refreshCounter = 0;
    static clock_t lastSecond = clock();
    bool exit = false;
    bool clearKbdInt = false;

    loopCount++;

    // Update stats every second
    clock_t now = clock();
    if ((now - lastSecond) >= CLOCKS_PER_SEC) {
        i64 currentClocks = pcdCpu->getClock();
        loopsPerSecond = loopCount - lastLoopCount;
        clocksPerSecond = (uint32_t)(currentClocks - lastClocks);
        lastLoopCount = loopCount;
        lastClocks = currentClocks;
        lastSecond = now;
    }

    // Poll keyboard input
    inputCounter++;
    if (inputCounter >= INPUT_FACTOR) {
        exit = !keyboardInput->poll();
        inputCounter = 0;

        // Poll UART
        uartController->poll();
        if (usingSerial) {
            uartController->pollSerial();
        }

        clearKbdInt = true;
    }

    // Update screen periodically
    refreshCounter++;
    if (refreshCounter >= CYCLE_FACTOR) {
        refreshCounter = 0;

        if (pcdScreen->registers.busy) {
            pcdScreen->advance(1);
        }

        textDisplayAdapter->update();
        pcdScreen->refresh();

        // Draw overlay if enabled
        if (showOverlay) {
            Screen_DOS* dosScreen = static_cast<Screen_DOS*>(pcdScreen);
            char buf[64];
            sprintf(buf, "LPS:%lu CPS:%lu", (unsigned long)loopsPerSecond, (unsigned long)clocksPerSecond);
            dosScreen->drawOverlayText(2, 2, buf);
        }
    }

    // Execute CPU instructions (Moira executes one instruction per call)
    // Higher values = faster emulation but less responsive input
    static const int INSTRUCTIONS_PER_LOOP = 5000;
    for (int i = 0; i < INSTRUCTIONS_PER_LOOP; i++) {
        pcdCpu->execute();
    }

    if (clearKbdInt) {
        keyboardController->clear();
    }

    return exit;
}

// Print usage
void printUsage(const char* programName) {
    std::cout << "PCD-68 Emulator for DOS" << std::endl;
    std::cout << "Usage: " << programName << " [ROM_FILE] [OPTIONS]" << std::endl;
    std::cout << std::endl;
    std::cout << "Options:" << std::endl;
    std::cout << "  -nf              Disable E-Ink emulation effects" << std::endl;
    std::cout << "  -debug-uart      Enable UART debug mode" << std::endl;
    std::cout << "  -debug-tda       Enable TDA debug mode" << std::endl;
    std::cout << "  -debug-kbd       Enable keyboard debug mode" << std::endl;
    std::cout << "  -debug-all       Enable all debug modes" << std::endl;
    std::cout << "  -com1 <port>     Connect UART1 to COM port (1-4)" << std::endl;
    std::cout << "  -com2 <port>     Connect UART2 to COM port (1-4)" << std::endl;
    std::cout << std::endl;
    std::cout << "Press ESC to exit the emulator." << std::endl;
}

int main(int argc, char** argv) {
    std::cout << "PCD-68 Emulator for DOS" << std::endl;
    std::cout << "Copyright (c) 2024, Jon Sharp" << std::endl;
    std::cout << std::endl;

    // Allocate ROM + RAM
    systemRom = (u8*)malloc(CPU::ROM_SIZE);
    systemRam = (u8*)malloc(CPU::RAM_SIZE);

    if (systemRom == nullptr || systemRam == nullptr) {
        std::cerr << "Unable to allocate memory for system RAM + ROM" << std::endl;
        return -1;
    }

    // Clear memory
    memset(systemRom, 0, CPU::ROM_SIZE);
    memset(systemRam, 0, CPU::RAM_SIZE);

    // Default settings
    bool fullEmulation = false;

    // Process command line arguments
    std::string romFile;
    bool romProvided = false;

    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];

        if (arg == "-nf") {
            fullEmulation = false;
        } else if (arg == "-debug-uart") {
            enableUartDebug = true;
        } else if (arg == "-debug-tda") {
            enableTdaDebug = true;
        } else if (arg == "-debug-kbd") {
            enableKeyboardDebug = true;
        } else if (arg == "-debug-all") {
            enableUartDebug = true;
            enableTdaDebug = true;
            enableKeyboardDebug = true;
        } else if (arg == "-com1" && i+1 < argc) {
            uartCom1 = atoi(argv[++i]);
            usingSerial = true;
        } else if (arg == "-com2" && i+1 < argc) {
            uartCom2 = atoi(argv[++i]);
            usingSerial = true;
        } else if (arg == "-h" || arg == "--help" || arg == "/?") {
            printUsage(argv[0]);
            return 0;
        } else if (!romProvided && arg[0] != '-') {
            romFile = arg;
            romProvided = true;
        }
    }

    // Load ROM file
    if (!romProvided) {
        std::cerr << "Error: No ROM file specified" << std::endl;
        std::cerr << "Usage: " << argv[0] << " <rom_file>" << std::endl;
        return -1;
    }

    std::ifstream programBinaryFile(romFile.c_str(), std::ios::binary);
    if (!programBinaryFile.is_open()) {
        std::cerr << "Failed to open ROM file: " << romFile << std::endl;
        return -1;
    }

    programBinaryFile.seekg(0, programBinaryFile.end);
    int size = programBinaryFile.tellg();
    programBinaryFile.seekg(0, programBinaryFile.beg);

    std::cout << "Loading ROM: " << romFile << " (" << size << " bytes)" << std::endl;

    programBinaryFile.read(reinterpret_cast<char*>(systemRom), size);
    programBinaryFile.close();

    // Create CPU
    pcdCpu = new CPU();

    // Create peripherals
    pcdScreen = new Screen_DOS(Screen::BASE_ADDR,
                               sizeof(Screen::Registers) + sizeof(Screen::framebufferMem),
                               fullEmulation);

    textDisplayAdapter = new TDA(pcdCpu, pcdScreen,
                                  TDA::BASE_ADDR,
                                  sizeof(TDA::textMapMem) + sizeof(TDA::Registers));

    keyboardController = new KCTL(pcdCpu, KCTL::BASE_ADDR, sizeof(KCTL::Registers));

    uartController = new UART(pcdCpu, UART::BASE_ADDR, sizeof(UART::Registers));

    // Enable debug modes
    if (enableUartDebug) {
        uartController->setDebugMode(true);
    }
    if (enableTdaDebug) {
        textDisplayAdapter->setDebugMode(true);
    }
    if (enableKeyboardDebug) {
        keyboardController->setDebugMode(true);
    }

    // Create keyboard input
    keyboardInput = createKeyboardInput();
    if (enableKeyboardDebug) {
        keyboardInput->setDebugMode(true);
    }
    keyboardInput->setKeyEventCallback(handleKeyEvent);
    keyboardInput->setKeyMultiEventCallback(handleMultiKeyEvent);
    if (keyboardInput->init() != 0) {
        std::cerr << "Failed to initialize keyboard" << std::endl;
        return -1;
    }

    // Attach peripherals to CPU
    pcdCpu->attachPeripheral(pcdScreen);
    pcdCpu->attachPeripheral(textDisplayAdapter);
    pcdCpu->attachPeripheral(keyboardController);
    pcdCpu->attachPeripheral(uartController);

    // Initialize peripherals
    int result = pcdScreen->init();
    if (result != 0) {
        std::cerr << "Failed to initialize screen" << std::endl;
        return -1;
    }

    result = uartController->init();
    if (result != 0) {
        std::cerr << "Failed to initialize UART" << std::endl;
        return -1;
    }

    // Connect UART to serial ports if specified
    if (usingSerial) {
        uartController->connectSerial(uartCom1, uartCom2);
    }

    // Reset peripherals
    keyboardController->reset();
    textDisplayAdapter->reset();
    uartController->reset();

    // Reset and start CPU
    pcdCpu->reset();
    pcdCpu->setIPL(0x00);  // Clear interrupts

    // Initial screen update
    textDisplayAdapter->update();
    pcdScreen->refresh();

    std::cout << "Running... (Press ESC to exit)" << std::endl;

    // Main emulation loop
    while (!mainLoop()) {
        // Continue running
    }

    // Cleanup
    std::cout << std::endl;
    std::cout << "Exiting..." << std::endl;
    std::cout << "Total clocks: " << pcdCpu->getClock() << std::endl;

    delete keyboardInput;
    delete uartController;
    delete keyboardController;
    delete textDisplayAdapter;
    delete pcdScreen;
    delete pcdCpu;

    free(systemRam);
    free(systemRom);

    return 0;
}

#endif // __DJGPP__
