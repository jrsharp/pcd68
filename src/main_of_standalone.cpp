/*
 * PCD68 Freestanding Main - No stdlib dependencies
 * Builds with native GCC in freestanding mode
 */

#include "freestanding.h"
#include "openfirmware.h"
#include "PCD68_CPU.h"
#include "KCTL.h"
#include "Screen_OF.h"
#include "TDA.h"
#include "UART.h"
#include "KeyboardInputOF.h"
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

/* Simple UART implementation for OF */
class UART_Simple : public UART {
public:
    UART_Simple() : UART() {}

    void send_byte(int uart, uint8_t byte) override {
        /* For now, just output to OF console */
        of_putchar(byte);
    }

    int recv_byte(int uart) override {
        /* Non-blocking read from OF */
        return of_getchar();
    }

    bool has_data(int uart) override {
        /* Always check */
        return true;
    }
};

/* Status output helper */
static void status(const char *msg) {
    of_print("[PCD68] ");
    of_print(msg);
    of_print("\n");
}

/* Initialize system */
static int init_system() {
    status("PCD68 Freestanding Edition");
    status("=========================");

    /* Show OF environment info */
    of_print("Framebuffer: ");
    of_print_hex((uint32_t)of_env.fb_addr);
    of_print(" ");
    of_print_hex(of_env.fb_width);
    of_print("x");
    of_print_hex(of_env.fb_height);
    of_print("x");
    of_print_hex(of_env.fb_depth);
    of_print("\n");

    /* Allocate memory */
    status("Allocating memory...");
    systemRom = (u8*)of_malloc(CPU::ROM_SIZE);
    systemRam = (u8*)of_malloc(CPU::RAM_SIZE);

    if (!systemRom || !systemRam) {
        status("ERROR: Memory allocation failed!");
        return -1;
    }

    /* Clear memory */
    memset(systemRom, 0, CPU::ROM_SIZE);
    memset(systemRam, 0, CPU::RAM_SIZE);

    /* Load ROM */
    status("Loading ROM...");
    memcpy(systemRom, text_demo_bin, text_demo_bin_len);

    /* Create components using placement new */
    status("Creating CPU...");
    void *cpu_mem = of_malloc(sizeof(CPU));
    pcdCpu = new(cpu_mem) CPU();

    status("Creating Screen...");
    void *screen_mem = of_malloc(sizeof(Screen_OF));
    pcdScreen = new(screen_mem) Screen_OF(Screen::BASE_ADDR, 400 * 300);
    pcdScreen->init();

    status("Creating Keyboard...");
    void *kctl_mem = of_malloc(sizeof(KCTL));
    keyboardController = new(kctl_mem) KCTL();

    void *kbd_mem = of_malloc(sizeof(KeyboardInputOF));
    keyboardInput = new(kbd_mem) KeyboardInputOF();

    status("Creating TDA...");
    void *tda_mem = of_malloc(sizeof(TDA));
    textDisplayAdapter = new(tda_mem) TDA(pcdScreen);
    pcdCpu->attachPeripheral(textDisplayAdapter);

    status("Creating UART...");
    void *uart_mem = of_malloc(sizeof(UART_Simple));
    uartController = new(uart_mem) UART_Simple();
    pcdCpu->attachPeripheral(uartController);

    /* Attach keyboard */
    pcdCpu->attachPeripheral(keyboardController);

    /* Reset system */
    status("Resetting CPU...");
    pcdCpu->reset();
    pcdCpu->setIPL(0x00);

    status("System ready!");
    status("Press ESC to exit");
    of_print("\n");

    return 0;
}

/* Main emulation loop */
static void run_emulation() {
    const int CYCLES_PER_BATCH = 500;
    const int REFRESH_INTERVAL = 10000;
    const int INPUT_INTERVAL = 1000;

    int refresh_counter = 0;
    int input_counter = 0;

    while (true) {
        /* Execute CPU */
        int cycles = pcdCpu->execute(CYCLES_PER_BATCH);

        /* Update counters */
        refresh_counter += cycles;
        input_counter += cycles;

        /* Refresh display */
        if (refresh_counter >= REFRESH_INTERVAL) {
            textDisplayAdapter->update();
            pcdScreen->refresh();
            refresh_counter = 0;
        }

        /* Poll input */
        if (input_counter >= INPUT_INTERVAL) {
            keyboardInput->pollEvents();
            input_counter = 0;

            /* Check for exit */
            int key = of_getchar();
            if (key == 27) { /* ESC */
                break;
            }
        }

        /* Handle keyboard interrupts */
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

/* Entry point from Open Firmware */
extern "C" int pcd68_start(int (*client_interface)(struct of_args *)) {
    /* Initialize OF interface */
    if (of_init(client_interface) != 0) {
        return -1;
    }

    /* Initialize PCD68 */
    if (init_system() != 0) {
        return -1;
    }

    /* Run emulation */
    run_emulation();

    /* Clean exit */
    status("Shutting down...");

    return 0;
}

/* Alternative entry for different OF loaders */
extern "C" void _start(int (*client_interface)(struct of_args *)) {
    pcd68_start(client_interface);
    of_exit();
}