#include <iostream>
#include <fstream>
#include <thread>
#include <stdlib.h>

#include "CPU.h"
#include "TDA.h"

#if(USE_SDL==1)
#include "Screen_SDL.h"
#include <chrono>
#else
#include "Screen_Memory.h"
#endif

u8 systemRom[CPU::ROM_SIZE];    // ROM
u8 systemRam[CPU::RAM_SIZE];    // RAM
Screen* pcdScreen;              // Screen instance

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

    programBinaryFile.read(reinterpret_cast<char *>(systemRom + 0x1000), size);

    // Random pixels to system ram used for fb:
    /*
    uint8_t * ptr = (uint8_t*)systemRam + 0x10000;
    for (int i = 0; i < (400 * 300); i++) {
        *ptr++ = rand();
    }
    */

    // Init screen:
    pcdScreen = new Screen(0x400000, 8);
    int result = pcdScreen->init();
    TDA* textDisplayAdapter = new TDA(0x410000, ((80 * 23) + 8));

    CPU* pcdCpu = new CPU();
    pcdCpu->attachPeripheral(pcdScreen);
    pcdCpu->attachPeripheral(textDisplayAdapter);

    pcdCpu->reset();

    bool exit = false;

    // Initial screen:
    updateScreen();

    while (!exit) {

#if(USE_SDL == 1)
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            switch (event.type) {
                case SDL_QUIT:
                    exit = true;
                    break;
            }
        }
#endif

        // Update screen:
        if (pcdCpu->getClock() % 50000 == 0) {
            updateScreen();
        }

        //std::cout << "\n\nBefore Instruction: \n\n" << std::endl;
        //pcdCpu->printState();
        
        // Advance CPU:
        pcdCpu->execute();
#if(USE_SDL==1)
        // Throttle:
        //std::this_thread::sleep_for(std::chrono::nanoseconds(1));
#endif
        
        //std::cout << "\n\nAfter: \n\n" << std::endl;
        //pcdCpu->printState();
    }

    return 0;
}
