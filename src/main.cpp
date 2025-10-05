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
#include "benchmark.h"

#include "text_demo.h"

#ifdef __EMSCRIPTEN__
#    include "emscripten.h"
#    define CYCLE_FACTOR 100   // Reduced refresh rate for better performance
#    define INPUT_FACTOR 10    // Less frequent input polling for web
#else
#    define CYCLE_FACTOR 400   // Dramatically increased for better performance
#    define INPUT_FACTOR 2     // Poll input every iteration for responsiveness
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
PerformanceBenchmark* benchmark = nullptr;

#ifdef __EMSCRIPTEN__
// Exposed functions for JavaScript to load ROMs
extern "C" {
    // Load the internal ROM (text_demo_bin)
    EMSCRIPTEN_KEEPALIVE
    void loadInternalRom() {
        std::cout << "Loading internal ROM (text_demo)..." << std::endl;
        
        // Reset the CPU
        pcdCpu->reset();
        pcdCpu->setIPL(0x00);
        
        // Clear memory
        std::memset(systemRom, 0, CPU::ROM_SIZE);
        std::memset(systemRam, 0, CPU::RAM_SIZE);
        
        // Load the built-in ROM
        std::memcpy(systemRom, text_demo_bin, text_demo_bin_len);
        
        // Reset peripherals
        keyboardController->reset();
        textDisplayAdapter->reset();
        uartController->reset();
        
        // Update display
        textDisplayAdapter->update();
        pcdScreen->refresh();
        
        std::cout << "Internal ROM loaded successfully." << std::endl;
    }
    
    // Load an external ROM from an array buffer
    EMSCRIPTEN_KEEPALIVE
    void loadExternalRom(uint8_t* romData, int size) {
        std::cout << "Loading external ROM, size: " << size << " bytes..." << std::endl;
        
        if (size > CPU::ROM_SIZE) {
            std::cerr << "ROM too large! Maximum size is " << CPU::ROM_SIZE << " bytes." << std::endl;
            return;
        }
        
        // Reset the CPU
        pcdCpu->reset();
        pcdCpu->setIPL(0x00);
        
        // Clear memory
        std::memset(systemRom, 0, CPU::ROM_SIZE);
        std::memset(systemRam, 0, CPU::RAM_SIZE);
        
        // Load the ROM data
        std::memcpy(systemRom, romData, size);
        
        // Reset peripherals
        keyboardController->reset();
        textDisplayAdapter->reset();
        uartController->reset();
        
        // Update display
        textDisplayAdapter->update();
        pcdScreen->refresh();
        
        std::cout << "External ROM loaded successfully." << std::endl;
    }
}
#endif

// For native builds, UART connection options
#ifndef __EMSCRIPTEN__
std::string uartSerialDevice1, uartSerialDevice2;
std::string uartTcpHost1, uartTcpHost2;
int uartTcpPort1 = 0, uartTcpPort2 = 0;
std::string uartPipeIn1, uartPipeOut1, uartPipeIn2, uartPipeOut2;
bool usingSerial = false;
bool usingTcp = false;
bool usingPipes = false;
#endif

// Global variable declaration for debug flags to be used in callback
#ifdef __EMSCRIPTEN__
bool enableKeyboardDebug = false;  // Disable debug now that keyboard input is working
#else
bool enableKeyboardDebug = false;
#endif

// Keyboard event handler callback for single key events
void handleKeyEvent(u16 keyCode, u16 mod) {
    // Add a static counter to track events processed by this handler
    static unsigned int eventCounter = 0;

    if (keyCode > 0) {
        eventCounter++;

        // Debug output disabled for production
        /*
        std::cout << "CALLBACK handleKeyEvent: #" << eventCounter << " code=0x" << std::hex << keyCode 
                  << " mod=0x" << mod << std::dec << " - calling KCTL->update()" << std::endl;
        */

        // Note: We're casting to u8 here, since KCTL expects 8-bit keycodes
        // This limits us to ASCII/Latin-1 range characters
        keyboardController->update(keyCode & 0xFF, mod & 0xFF);
        textDisplayAdapter->update();
        pcdScreen->refresh();
    }
}

// Multi-key event handler callback - more efficient than processing keys individually
void handleMultiKeyEvent(const u8* keycodes, u8 keyCount, u8 mod) {
    // Add a static counter to track reports processed by this handler
    static unsigned int reportCounter = 0;

    if (keyCount > 0) {
        reportCounter++;

        // Debug output disabled for production
        /*
        std::cout << "CALLBACK handleMultiKeyEvent: #" << reportCounter << " count=" << (int)keyCount 
                  << " mod=0x" << std::hex << (int)mod << std::dec << " - calling KCTL->updateMultiKey()" << std::endl;
        */

        // Use the more efficient multi-key update function
        keyboardController->updateMultiKey(keycodes, keyCount, mod);
        textDisplayAdapter->update();
        pcdScreen->refresh();
    }
}

// Main loop
bool mainLoop() {
    static int inputCounter = 0;
    bool exit = false, clearKbdInt = false;

    // Process input and update screen
    i64 clocks = pcdCpu->getClock();

    // Prioritize keyboard input polling - do this more frequently
    inputCounter++;
    if (inputCounter >= INPUT_FACTOR) {
        // Poll for keyboard events more aggressively
        exit = !keyboardInput->poll();
        inputCounter = 0;

        // Minimal debug output for web builds to improve performance
#ifndef __EMSCRIPTEN__
        // Static counter for input polling iterations - only show every 100000 cycles for performance
        static unsigned int pollCounter = 0;
        pollCounter++;

        if (enableKeyboardDebug && pollCounter % 100000 == 0) {
            std::cout << "mainLoop - poll #" << pollCounter
                      << " - KCTL report count: " << (int)keyboardController->registers.pendingReportCount
                      << "/" << KCTL::REPORT_STACK_SIZE << std::endl;
        }
#endif

        // Poll UART for data
        uartController->poll();

#ifndef __EMSCRIPTEN__
        // Poll serial ports, TCP sockets, or pipes for native builds
        if (usingSerial) {
            uartController->pollSerial();
        }
        else if (usingTcp) {
            uartController->pollTCP();
        }
        else if (usingPipes) {
            uartController->pollPipes();
        }
#endif

        // Flag to clear keyboard interrupt
        clearKbdInt = true;
    }

    // Input processing / peripheral servicing
    // Detect if we're in graphics/framebuffer mode (TDA disabled) for more frequent updates
    // Check this every cycle to ensure responsive graphics rendering
    bool inGraphicsMode = (textDisplayAdapter->read8(TDA::BASE_ADDR) == 0); // TDA mode == NONE
    
    // Use different update frequencies based on TDA mode
    int updateFactor = CYCLE_FACTOR;
#ifdef __EMSCRIPTEN__
    if (inGraphicsMode) {
        updateFactor = 1;  // Update every single cycle for graphics mode
        // Ensure refresh flag is always set during graphics mode for continuous updates
        pcdScreen->refreshFlag = true;
    }
#endif
    
    if (clocks % updateFactor == 0) {
        // Check/advance busy screen:
        if (pcdScreen->registers.busy) {
            pcdScreen->advance(1);
        }

        textDisplayAdapter->update();
        pcdScreen->refresh();
    }

    // Execute multiple CPU instructions per loop to improve throughput
    // This greatly improves performance for keyboard-intensive applications
#ifdef __EMSCRIPTEN__
    static const int INSTRUCTIONS_PER_LOOP = 5000;  // Significantly increased for web performance
#else
    static const int INSTRUCTIONS_PER_LOOP = 2000;  // Maximized for native performance
#endif
    for (int i = 0; i < INSTRUCTIONS_PER_LOOP; i++) {
        pcdCpu->execute();
    }
    
    if (benchmark) {
        // Record all instructions at once for better performance
        benchmark->recordInstruction(INSTRUCTIONS_PER_LOOP);
        benchmark->recordCycle();
        benchmark->reportPerformance();
    }

    if (clearKbdInt) {
        // Only log keyboard clearing when pending count is nonzero
#ifndef __EMSCRIPTEN__
        if (enableKeyboardDebug && keyboardController->registers.pendingReportCount > 0) {
            std::cout << "mainLoop - Calling keyboardController->clear() - report count: "
                      << (int)keyboardController->registers.pendingReportCount << std::endl;
        }
#endif
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
    std::cout << "  -debug-kbd       Enable keyboard debug mode (trace keyboard events)" << std::endl;
    std::cout << "  -debug-all       Enable all debug modes" << std::endl;
    std::cout << "  -benchmark       Enable performance benchmarking" << std::endl;
#ifndef __EMSCRIPTEN__
    std::cout << "  -serial1 <dev>    Connect UART1 to serial device (e.g., /dev/tty.usbserial)" << std::endl;
    std::cout << "  -serial2 <dev>    Connect UART2 to serial device" << std::endl;
    std::cout << "  -tcp1 <host:port> Connect UART1 to TCP socket (e.g., localhost:8081)" << std::endl;
    std::cout << "  -tcp2 <host:port> Connect UART2 to TCP socket" << std::endl;
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
#ifdef __EMSCRIPTEN__
    bool enableBenchmark = false;  // Disable by default for clean production experience
#else
    bool enableBenchmark = false;
#endif
    // (enableKeyboardDebug is defined globally for access in callback)
    
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
        } else if (arg == "-benchmark") {
            enableBenchmark = true;
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
        } else if (arg == "-tcp1" && i+1 < argc) {
            std::string tcpArg = argv[++i];
            size_t colonPos = tcpArg.find(':');
            if (colonPos != std::string::npos) {
                uartTcpHost1 = tcpArg.substr(0, colonPos);
                uartTcpPort1 = std::stoi(tcpArg.substr(colonPos + 1));
                usingTcp = true;
            } else {
                std::cerr << "Invalid TCP format for -tcp1. Use host:port (e.g., localhost:8081)" << std::endl;
                return -1;
            }
        } else if (arg == "-tcp2" && i+1 < argc) {
            std::string tcpArg = argv[++i];
            size_t colonPos = tcpArg.find(':');
            if (colonPos != std::string::npos) {
                uartTcpHost2 = tcpArg.substr(0, colonPos);
                uartTcpPort2 = std::stoi(tcpArg.substr(colonPos + 1));
                usingTcp = true;
            } else {
                std::cerr << "Invalid TCP format for -tcp2. Use host:port (e.g., localhost:8082)" << std::endl;
                return -1;
            }
        } else if (arg == "-pipe-in1" && i+1 < argc) {
            uartPipeIn1 = argv[++i];
            usingPipes = true;
        } else if (arg == "-pipe-out1" && i+1 < argc) {
            uartPipeOut1 = argv[++i];
            usingPipes = true;
        } else if (arg == "-pipe-in2" && i+1 < argc) {
            uartPipeIn2 = argv[++i];
            usingPipes = true;
        } else if (arg == "-pipe-out2" && i+1 < argc) {
            uartPipeOut2 = argv[++i];
            usingPipes = true;
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
    
    if (enableKeyboardDebug) {
        keyboardController->setDebugMode(true);
    }
    
    // For web builds, disable debug for production
#ifdef __EMSCRIPTEN__
    keyboardController->setDebugMode(false);
    std::cout << "KCTL debug mode disabled for web build" << std::endl;
#endif
    
    // Initialize benchmark if requested
    if (enableBenchmark) {
        benchmark = new PerformanceBenchmark();
        std::cout << "Performance benchmarking enabled" << std::endl;
    }
    
    // Initialize keyboard input
    std::cout << "Creating keyboard input..." << std::endl;
    keyboardInput = createKeyboardInput();
    std::cout << "Keyboard input created successfully" << std::endl;
    
    if (enableKeyboardDebug) {
        std::cout << "Enabling keyboard debug mode..." << std::endl;
        keyboardInput->setDebugMode(true);
    }
    
    std::cout << "Setting keyboard callbacks..." << std::endl;
    keyboardInput->setKeyEventCallback(handleKeyEvent);
    keyboardInput->setKeyMultiEventCallback(handleMultiKeyEvent);
    
    std::cout << "Initializing keyboard input..." << std::endl;
    int kbd_result = keyboardInput->init();
    if (kbd_result != 0) {
        std::cerr << "Failed to initialize keyboard input, result: " << kbd_result << std::endl;
        return -1;
    }
    std::cout << "Keyboard input initialization complete" << std::endl;

    // Attach to CPU
    pcdCpu->attachPeripheral(pcdScreen);
    pcdCpu->attachPeripheral(textDisplayAdapter);
    pcdCpu->attachPeripheral(keyboardController);
    pcdCpu->attachPeripheral(uartController);

    // Any that require init()
    int result = pcdScreen->init();
    result = uartController->init();

    // This keyboard input initialization was moved up

#ifdef __EMSCRIPTEN__
    // Connect UART to websocket for Emscripten target
    const char* webSocketUrl1 = "ws://localhost:8080";
    const char* webSocketUrl2 = "ws://localhost:8081";
    std::cout << "Attempting to connect UART to WebSockets (non-fatal if this fails):" << std::endl;
    std::cout << "  UART1: " << webSocketUrl1 << std::endl;
    std::cout << "  UART2: " << webSocketUrl2 << std::endl;
    uartController->connectWebsocket(webSocketUrl1, webSocketUrl2);
    std::cout << "PCD-68 emulator running with or without WebSocket connections." << std::endl;
    std::cout << "WebSocket connection failures are normal when running in browser." << std::endl;
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
    else if (usingTcp) {
        // Check required arguments
        if (uartTcpHost1.empty() || uartTcpPort1 == 0) {
            std::cerr << "TCP host:port for UART1 must be specified with -tcp1" << std::endl;
            return -1;
        }
        
        result = uartController->connectTCP(
            uartTcpHost1.c_str(),
            uartTcpPort1,
            uartTcpHost2.empty() ? nullptr : uartTcpHost2.c_str(),
            uartTcpPort2
        );
        
        if (result != 0) {
            std::cerr << "Failed to connect UART to TCP sockets" << std::endl;
            return -1;
        }
    }
    else if (usingPipes) {
        // Check required arguments - at least one UART must have both pipes
        bool uart1HasBoth = !uartPipeIn1.empty() && !uartPipeOut1.empty();
        bool uart2HasBoth = !uartPipeIn2.empty() && !uartPipeOut2.empty();
        
        if (!uart1HasBoth && !uart2HasBoth) {
            std::cerr << "At least one UART must have both input and output pipes specified" << std::endl;
            return -1;
        }
        
        result = uartController->connectPipes(
            uartPipeIn1.empty() ? nullptr : uartPipeIn1.c_str(),
            uartPipeOut1.empty() ? nullptr : uartPipeOut1.c_str(),
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
    // pcdCpu->debugger.enableLogging();  // Disabled for maximum performance
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
    
    if (benchmark) {
        benchmark->reportPerformance(true);  // Force final report
        delete benchmark;
    }
    
    std::cout << "Clocks: " << std::dec << pcdCpu->getClock() << std::endl;
    return 0;
}
