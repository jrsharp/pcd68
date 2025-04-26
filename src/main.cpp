#include <chrono>
#include <fstream>
#include <iostream>
#include <stdlib.h>
#include <thread>
#include <stdio.h>
#include <string>

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

// For native builds, UART connection options
#ifndef __EMSCRIPTEN__
std::string uartSerialDevice1, uartSerialDevice2;
std::string uartPipeIn1, uartPipeOut1, uartPipeIn2, uartPipeOut2;
bool usingSerial = false;
bool usingPipes = false;
#endif

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
            
#ifndef __EMSCRIPTEN__
            // Poll serial ports or pipes for native builds
            if (usingSerial) {
                uartController->pollSerial();
            }
            else if (usingPipes) {
                uartController->pollPipes();
            }
#endif
            
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

// Print usage information
void printUsage(const char* programName) {
    std::cout << "Usage: " << programName << " [ROM_FILE] [OPTIONS]" << std::endl;
    std::cout << "Options:" << std::endl;
    std::cout << "  -nf              Disable full E-Ink emulation" << std::endl;
    std::cout << "  -debug-uart      Enable UART debug mode (trace data flow)" << std::endl;
    std::cout << "  -debug-tda       Enable TDA debug mode (trace text display updates)" << std::endl;
    std::cout << "  -debug-all       Enable all debug modes" << std::endl;
#ifndef __EMSCRIPTEN__
    std::cout << "  -serial1 <dev>    Connect UART1 to serial device (e.g., /dev/tty.usbserial)" << std::endl;
    std::cout << "  -serial2 <dev>    Connect UART2 to serial device" << std::endl;
    std::cout << "  -pipe-in1 <path>  Input pipe for UART1 (e.g., /tmp/uart1_in)" << std::endl;
    std::cout << "  -pipe-out1 <path> Output pipe for UART1 (e.g., /tmp/uart1_out)" << std::endl;
    std::cout << "  -pipe-in2 <path>  Input pipe for UART2" << std::endl;
    std::cout << "  -pipe-out2 <path> Output pipe for UART2" << std::endl;
#endif
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
    bool fullEmulation = false;
    bool enableUartDebug = false;
    bool enableTdaDebug = false;
    
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
        } else if (arg == "-debug-all") {
            enableUartDebug = true;
            enableTdaDebug = true;
        } else if (arg == "-h" || arg == "--help") {
            printUsage(argv[0]);
            return 0;
#ifndef __EMSCRIPTEN__
        } else if (arg == "-serial1" && i+1 < argc) {
            uartSerialDevice1 = argv[++i];
            usingSerial = true;
        } else if (arg == "-serial2" && i+1 < argc) {
            uartSerialDevice2 = argv[++i];
            usingSerial = true;
        } else if (arg == "-pipe-in1" && i+1 < argc) {
            uartPipeIn1 = argv[++i];
            usingPipes = true;
        } else if (arg == "-pipe-out1" && i+1 < argc) {
            uartPipeOut1 = argv[++i];
            usingPipes = true;
        } else if (arg == "-pipe-in2" && i+1 < argc) {
            uartPipeIn2 = argv[++i];
        } else if (arg == "-pipe-out2" && i+1 < argc) {
            uartPipeOut2 = argv[++i];
#endif
        } else if (!romProvided) {
            romFile = arg;
            romProvided = true;
        }
    }
    
    // Load program into systemRom memory
    if (!romProvided) {
        memcpy(systemRom, text_demo_bin, text_demo_bin_len);
    } else {
        std::ifstream programBinaryFile(romFile, std::ios::binary);
        if (!programBinaryFile.is_open()) {
            std::cerr << "Failed to open ROM file: " << romFile << std::endl;
            return -1;
        }
        
        programBinaryFile.seekg(0, programBinaryFile.end);
        int size = programBinaryFile.tellg();
        programBinaryFile.seekg(0, programBinaryFile.beg);

        std::cout << "Loading file: " << romFile << " (" << size << " bytes)" << std::endl;

        programBinaryFile.read(reinterpret_cast<char*>(systemRom + 0x00), size);
    }

    // Start with a CPU
    pcdCpu = new CPU();

    // Set up peripherals
    pcdScreen = new Screen_SDL(Screen::BASE_ADDR, sizeof(Screen::Registers) + sizeof(Screen::framebufferMem), fullEmulation);
    textDisplayAdapter = new TDA(pcdCpu, pcdScreen, TDA::BASE_ADDR, sizeof(TDA::textMapMem) + sizeof(TDA::Registers));
    keyboardController = new KCTL(pcdCpu, KCTL::BASE_ADDR, sizeof(KCTL::Registers));
    uartController = new UART(pcdCpu, UART::BASE_ADDR, sizeof(UART::Registers));

    // Enable debug modes if requested
    if (enableUartDebug) {
        uartController->setDebugMode(true);
    }
    
    if (enableTdaDebug) {
        textDisplayAdapter->setDebugMode(true);
    }

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
#else
    // For native builds, check for serial or pipe connections
    if (usingSerial) {
        // Check required arguments
        if (uartSerialDevice1.empty()) {
            std::cerr << "Serial device for UART1 must be specified with -serial1" << std::endl;
            return -1;
        }
        
        result = uartController->connectSerial(
            uartSerialDevice1.c_str(), 
            uartSerialDevice2.empty() ? nullptr : uartSerialDevice2.c_str()
        );
        
        if (result != 0) {
            std::cerr << "Failed to connect UART to serial ports" << std::endl;
            return -1;
        }
    }
    else if (usingPipes) {
        // Check required arguments
        if (uartPipeIn1.empty() || uartPipeOut1.empty()) {
            std::cerr << "Both input and output pipes for UART1 must be specified with -pipe-in1 and -pipe-out1" << std::endl;
            return -1;
        }
        
        result = uartController->connectPipes(
            uartPipeIn1.c_str(),
            uartPipeOut1.c_str(),
            uartPipeIn2.empty() ? nullptr : uartPipeIn2.c_str(),
            uartPipeOut2.empty() ? nullptr : uartPipeOut2.c_str()
        );
        
        if (result != 0) {
            std::cerr << "Failed to connect UART to named pipes" << std::endl;
            return -1;
        }
    }
#endif

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
