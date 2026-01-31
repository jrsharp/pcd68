/*
 * PCD68 Open Firmware Main Entry Point
 *
 * This is called directly by Open Firmware as an XCOFF/ELF binary
 * Entry: pcd68_start(client_interface)
 */

#include <cstring>
#include "PCD68_CPU.h"
#include "KCTL.h"
#include "Screen_OF.h"
#include "TDA.h"
#include "UART.h"
#include "KeyboardInputOF.h"
#include "openfirmware.h"
#include "text_demo.h"

/* Global system components */
u8* systemRom;
u8* systemRam;
CPU* pcdCpu;
TDA* textDisplayAdapter;
KCTL* keyboardController;
UART* uartController;
Screen* pcdScreen;
KeyboardInput* keyboardInput;
i64 interruptDebounceClocks = 0;
i64 lastClock = 0;

/* OF serial handles for UART */
static ihandle serial1_ih = 0;
static ihandle serial2_ih = 0;

/* UART OF callbacks */
class UART_OF : public UART {
public:
    UART_OF() : UART() {}

    void send_byte(int uart, uint8_t byte) override {
        ihandle ih = (uart == 1) ? serial1_ih : serial2_ih;
        if (ih) {
            of_write(ih, &byte, 1);
        }
    }

    int recv_byte(int uart) override {
        ihandle ih = (uart == 1) ? serial1_ih : serial2_ih;
        if (ih) {
            uint8_t byte;
            if (of_read(ih, &byte, 1) == 1) {
                return byte;
            }
        }
        return -1;
    }

    bool has_data(int uart) override {
        /* For now, always check - OF read is non-blocking */
        return true;
    }
};

/* Initialize PCD68 system */
static int pcd68_init() {
    of_print("PCD68 Open Firmware Edition\n");
    of_print("===========================\n");

    /* Allocate memory */
    systemRom = (u8*)of_malloc(CPU::ROM_SIZE);
    systemRam = (u8*)of_malloc(CPU::RAM_SIZE);

    if (!systemRom || !systemRam) {
        of_print("Failed to allocate memory!\n");
        return -1;
    }

    /* Clear memory */
    memset(systemRom, 0, CPU::ROM_SIZE);
    memset(systemRam, 0, CPU::RAM_SIZE);

    /* Load default ROM (text_demo) */
    of_print("Loading internal ROM...\n");
    memcpy(systemRom, text_demo_bin, text_demo_bin_len);

    /* Create CPU */
    pcdCpu = new CPU();
    of_print("CPU: 68000 initialized\n");

    /* Create screen */
    pcdScreen = new Screen_OF(Screen::BASE_ADDR, 400 * 300);
    pcdScreen->init();
    of_print("Display: 400x300 initialized\n");

    /* Create keyboard */
    keyboardController = new KCTL();
    keyboardInput = new KeyboardInputOF();
    of_print("Keyboard: initialized\n");

    /* Create TDA */
    textDisplayAdapter = new TDA(pcdScreen);
    pcdCpu->attachPeripheral(textDisplayAdapter);
    of_print("TDA: Text Display Adapter initialized\n");

    /* Create UART */
    uartController = new UART_OF();
    pcdCpu->attachPeripheral(uartController);
    of_print("UART: Dual UART initialized\n");

    /* Attach keyboard controller */
    pcdCpu->attachPeripheral(keyboardController);

    /* Try to open serial ports */
    serial1_ih = of_open("ch-a");  /* PowerBook modem port */
    if (!serial1_ih) {
        serial1_ih = of_open("sccb");  /* Alternative name */
    }
    serial2_ih = of_open("ch-b");  /* PowerBook printer port */
    if (!serial2_ih) {
        serial2_ih = of_open("scca");  /* Alternative name */
    }

    if (serial1_ih) {
        of_print("Serial 1: connected to modem port\n");
    }
    if (serial2_ih) {
        of_print("Serial 2: connected to printer port\n");
    }

    /* Reset and start CPU */
    pcdCpu->reset();
    pcdCpu->setIPL(0x00);
    of_print("\nStarting emulation... (Press ESC to exit)\n\n");

    return 0;
}

/* Main emulation loop */
static void pcd68_run() {
    int cycles = 0;
    int refresh_counter = 0;
    int input_counter = 0;

    while (true) {
        /* Run CPU for a batch of cycles */
        cycles = pcdCpu->execute(500);

        /* Update peripherals */
        refresh_counter += cycles;
        input_counter += cycles;

        /* Refresh display periodically */
        if (refresh_counter > 10000) {
            textDisplayAdapter->update();
            pcdScreen->refresh();
            refresh_counter = 0;
        }

        /* Poll keyboard */
        if (input_counter > 1000) {
            keyboardInput->pollEvents();
            input_counter = 0;
        }

        /* Process keyboard interrupts */
        if (keyboardController->registers.pendingInterrupt &&
            pcdCpu->getIRQ() == 0) {
            if (lastClock + interruptDebounceClocks < pcdCpu->getClock()) {
                pcdCpu->setIPL(keyboardController->registers.interruptLevel);
                lastClock = pcdCpu->getClock();
                keyboardController->registers.pendingInterrupt = false;
            }
        } else if (keyboardController->registers.restoreInterrupt) {
            pcdCpu->setIPL(0x00);
            keyboardController->registers.restoreInterrupt = false;
        }
    }
}

/* Cleanup */
static void pcd68_cleanup() {
    of_print("\nShutting down PCD68...\n");

    /* Close serial ports */
    if (serial1_ih) of_close(serial1_ih);
    if (serial2_ih) of_close(serial2_ih);

    /* No need to free memory - OF will reclaim it */
}

/* Main entry point from Open Firmware */
extern "C" {

/*
 * OF calls us with:
 * r3 = client interface function pointer
 * r4 = reserved (usually 0)
 * r5 = reserved (usually 0)
 */
int pcd68_start(int (*client_interface)(struct of_args *)) {
    /* Initialize OF client interface */
    of_init(client_interface);

    /* Initialize PCD68 */
    if (pcd68_init() != 0) {
        of_print("PCD68 initialization failed!\n");
        return -1;
    }

    /* Run emulation */
    pcd68_run();

    /* Cleanup */
    pcd68_cleanup();

    /* Return to OF */
    return 0;
}

/* Alternative entry point names for compatibility */
void _start(int (*client_interface)(struct of_args *)) {
    pcd68_start(client_interface);
}

} /* extern "C" */