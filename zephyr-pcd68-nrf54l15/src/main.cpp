#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/display.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/drivers/spi.h>
#include <zephyr/logging/log.h>
#include <zephyr/sys/printk.h>
#include <zephyr/devicetree.h>

#include "PCD68_CPU.h"
// TODO: Re-enable peripherals after optimizing dispatch
// #include "TDA.h"
// #include "KCTL.h"
// #include "UART.h"
// #include "Screen_Zephyr.h"
// #include "KeyboardInput_Zephyr.h"
#include "Storage_Zephyr.h"
#include "text_demo.h"
#include <new>  // For placement new

// External declarations from text_demo.h
extern unsigned char text_demo_bin[];
extern unsigned int text_demo_bin_len;

LOG_MODULE_REGISTER(pcd68_main, CONFIG_LOG_DEFAULT_LEVEL);

// Global static CPU object
static CPU global_cpu;

// Global emulator components
unsigned char* systemRom = nullptr;
unsigned char* systemRam = nullptr;
// Use dynamic allocation - static allocation is 544KB which exceeds available RAM
static CPU* pcdCpu = nullptr;
// TODO: Re-enable after Musashi migration
// static TDA* textDisplayAdapter = nullptr;
// static KCTL* keyboardController = nullptr;
// static UART* uartController = nullptr;
// TODO: Re-enable after Musashi migration
// static Screen_Zephyr pcdScreenStatic(0x810000);
// static Screen_Zephyr* pcdScreen = &pcdScreenStatic;
// static KeyboardInput_Zephyr* keyboardInput = nullptr;
static Storage_Zephyr* storage = nullptr;

// Emulation timing for nRF54L15 (128MHz)
static uint32_t cycles_per_iteration = 1000;
static uint32_t target_cpu_hz = CONFIG_PCD68_TARGET_CPU_MHZ * 1000000;
static uint32_t iteration_delay_us = (cycles_per_iteration * 1000000) / target_cpu_hz;

// Thread stacks - reduced for nRF54L15 256KB RAM
K_THREAD_STACK_DEFINE(emulation_stack, 2048);
K_THREAD_STACK_DEFINE(display_stack, 1024);
K_THREAD_STACK_DEFINE(input_stack, 1024);

struct k_thread emulation_thread;
struct k_thread display_thread;
struct k_thread input_thread;

// Synchronization
K_SEM_DEFINE(display_sem, 0, 1);
K_MUTEX_DEFINE(cpu_mutex);

// Display refresh rate for e-paper (lower refresh for power savings)
#define DISPLAY_REFRESH_RATE 10
#define DISPLAY_REFRESH_MS (1000 / DISPLAY_REFRESH_RATE)

// Forward declarations
void emulation_thread_entry(void *p1, void *p2, void *p3);
void display_thread_entry(void *p1, void *p2, void *p3);
void input_thread_entry(void *p1, void *p2, void *p3);
static void test_display_splash(const struct device *display_dev);

static int init_hardware(void)
{
    LOG_INF("Initializing hardware for PCD68 on nRF54L15");

#ifdef CONFIG_PCD68_EPAPER_DISPLAY
    const struct device *display_dev = DEVICE_DT_GET(DT_CHOSEN(zephyr_display));
    if (!device_is_ready(display_dev)) {
        LOG_WRN("E-paper display not ready, continuing without display");
    } else {
        LOG_INF("E-paper display initialized successfully");

        // Show boot splash screen to test display
        test_display_splash(display_dev);
    }
#else
    LOG_INF("Display support disabled");
#endif

    return 0;
}

static void test_display_splash(const struct device *display_dev)
{
    LOG_INF("Starting e-paper display test - this should appear in UART");
    printk("DISPLAY TEST: Starting e-paper display boot splash test\n");

    // Test GPIO and SPI access to verify hardware setup
    printk("DISPLAY TEST: Testing GPIO and SPI device access...\n");
    const struct device *gpio1 = DEVICE_DT_GET(DT_NODELABEL(gpio1));
    const struct device *gpio2 = DEVICE_DT_GET(DT_NODELABEL(gpio2));
    const struct device *spi00 = DEVICE_DT_GET(DT_NODELABEL(spi00));

    if (!device_is_ready(gpio1)) {
        printk("DISPLAY TEST: GPIO1 device not ready!\n");
    } else {
        printk("DISPLAY TEST: GPIO1 device ready\n");
    }

    if (!device_is_ready(gpio2)) {
        printk("DISPLAY TEST: GPIO2 device not ready!\n");
    } else {
        printk("DISPLAY TEST: GPIO2 device ready\n");
    }

    if (!device_is_ready(spi00)) {
        printk("DISPLAY TEST: SPI00 device not ready!\n");
    } else {
        printk("DISPLAY TEST: SPI00 device ready\n");
    }

    printk("DISPLAY TEST: Expected pin assignments:\n");
    printk("DISPLAY TEST: SPI00 - SCK:P2.1, MOSI:P2.2\n");
    printk("DISPLAY TEST: Flash CS0:P2.5 (disabled), Display CS1:P1.8\n");
    printk("DISPLAY TEST: Display - DC:P1.6, RST:P1.7, BUSY:P1.9\n");

    // Test the BUSY pin (GPIO1.9) manually
    printk("DISPLAY TEST: Testing BUSY pin (GPIO1.9)...\n");
    if (device_is_ready(gpio1)) {
        // Configure BUSY pin as input
        int ret = gpio_pin_configure(gpio1, 9, GPIO_INPUT);
        if (ret == 0) {
            int busy_val = gpio_pin_get(gpio1, 9);
            printk("DISPLAY TEST: BUSY pin current value: %d (0=busy, 1=ready)\n", busy_val);
        } else {
            printk("DISPLAY TEST: Failed to configure BUSY pin: %d\n", ret);
        }
    }

    // Get display capabilities
    struct display_capabilities caps;
    display_get_capabilities(display_dev, &caps);

    LOG_INF("Display: %dx%d, pixel format: %d", caps.x_resolution, caps.y_resolution, caps.current_pixel_format);
    printk("DISPLAY TEST: Display capabilities - %dx%d, supported formats: 0x%x, current: %d\n",
           caps.x_resolution, caps.y_resolution, caps.supported_pixel_formats, caps.current_pixel_format);

    // Try to explicitly set pixel format to MONO10
    if (caps.supported_pixel_formats & PIXEL_FORMAT_MONO10) {
        printk("DISPLAY TEST: Setting pixel format to MONO10\n");
        int fmt_ret = display_set_pixel_format(display_dev, PIXEL_FORMAT_MONO10);
        if (fmt_ret != 0) {
            printk("DISPLAY TEST: Failed to set MONO10 format: %d\n", fmt_ret);
        }
    } else if (caps.supported_pixel_formats & PIXEL_FORMAT_MONO01) {
        printk("DISPLAY TEST: Setting pixel format to MONO01\n");
        int fmt_ret = display_set_pixel_format(display_dev, PIXEL_FORMAT_MONO01);
        if (fmt_ret != 0) {
            printk("DISPLAY TEST: Failed to set MONO01 format: %d\n", fmt_ret);
        }
    }

    // Create a simple test pattern
    size_t buffer_size = caps.x_resolution * caps.y_resolution / 8;  // Packed monochrome
    u8 *test_buffer = new u8[buffer_size];
    if (!test_buffer) {
        LOG_ERR("Failed to allocate test buffer");
        return;
    }

    // Create a very obvious test pattern with both normal and inverted data
    printk("DISPLAY TEST: Creating test pattern - pixel format: %d\n", caps.current_pixel_format);

    // Pattern 1: Quarters - try different combinations
    memset(test_buffer, 0x00, buffer_size / 4);                    // Quarter 1: All black (0x00)
    memset(test_buffer + buffer_size / 4, 0xFF, buffer_size / 4);  // Quarter 2: All white (0xFF)
    memset(test_buffer + buffer_size / 2, 0xAA, buffer_size / 4);  // Quarter 3: Alternating (0xAA)
    memset(test_buffer + 3 * buffer_size / 4, 0x55, buffer_size / 4); // Quarter 4: Inverted alternating (0x55)

    printk("DISPLAY TEST: Pattern created - Q1:0x00, Q2:0xFF, Q3:0xAA, Q4:0x55\n");

    // Write to display
    struct display_buffer_descriptor desc = {
        .buf_size = buffer_size,
        .width = caps.x_resolution,
        .height = caps.y_resolution,
        .pitch = caps.x_resolution / 8,
    };

    // Make sure display is on
    printk("DISPLAY TEST: Turning off display blanking...\n");
    int blank_ret = display_blanking_off(display_dev);
    if (blank_ret != 0) {
        printk("DISPLAY TEST: Failed to turn off blanking: %d\n", blank_ret);
    } else {
        printk("DISPLAY TEST: Display blanking turned off successfully\n");
    }

    // Add a small delay for e-paper initialization
    k_msleep(100);

    printk("DISPLAY TEST: About to write to display...\n");
    int ret = display_write(display_dev, 0, 0, &desc, test_buffer);
    if (ret == 0) {
        LOG_INF("Boot splash displayed successfully");
        printk("DISPLAY TEST: Boot splash written successfully!\n");

        // Check if busy pin is working during display operation
        printk("DISPLAY TEST: Monitoring BUSY pin during display operation...\n");
        if (device_is_ready(gpio1)) {
            int busy_before = gpio_pin_get(gpio1, 9);
            printk("DISPLAY TEST: BUSY pin before write: %d\n", busy_before);
        }
        k_msleep(100);

        // Try blanking on then off to force refresh
        printk("DISPLAY TEST: Toggling display blanking to force refresh...\n");
        display_blanking_on(display_dev);
        k_msleep(100);
        display_blanking_off(display_dev);

        // Try explicit display update for e-paper
        printk("DISPLAY TEST: Attempting explicit display update...\n");
        int update_ret = display_write(display_dev, 0, 0, &desc, test_buffer);
        if (update_ret == 0) {
            printk("DISPLAY TEST: Second write for update successful\n");
        } else {
            printk("DISPLAY TEST: Second write failed: %d\n", update_ret);
        }

        // Give e-paper time to process and monitor BUSY pin
        printk("DISPLAY TEST: Waiting 5 seconds for e-paper to update...\n");
        for (int i = 0; i < 10; i++) {
            if (device_is_ready(gpio1)) {
                int busy_val = gpio_pin_get(gpio1, 9);
                printk("DISPLAY TEST: BUSY pin after %d seconds: %d\n", i/2, busy_val);
            }
            k_msleep(500);
        }
        printk("DISPLAY TEST: Should see 4-quarter pattern on display now!\n");
        printk("DISPLAY TEST: Expected pattern - Top-left:black, Top-right:white, Bottom-left:checkered, Bottom-right:inverted-checkered\n");
        printk("DISPLAY TEST: If no display output, check VCC power (3.3V) to display!\n");
    } else {
        LOG_ERR("Failed to display boot splash: %d", ret);
        printk("DISPLAY TEST: Boot splash write FAILED with error %d\n", ret);
    }

    delete[] test_buffer;
}

static int init_storage(void)
{
    LOG_INF("Initializing storage");

    storage = new Storage_Zephyr();
    if (!storage->init()) {
        LOG_ERR("Failed to initialize storage");
        return -EIO;
    }

    return 0;
}

static int load_rom(const char *rom_filename)
{
    LOG_INF("Loading ROM: %s", rom_filename);
    printk("DEBUG: Entering load_rom()\n");

    // Point directly to the embedded text_demo ROM - no copying needed!
    systemRom = (unsigned char*)text_demo_bin;
    size_t rom_size = text_demo_bin_len;
    printk("DEBUG: Using embedded ROM directly: %zu bytes\n", rom_size);

    // Log first few bytes to verify loading
    printk("ROM first 16 bytes: %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x\n",
           systemRom[0], systemRom[1], systemRom[2], systemRom[3],
           systemRom[4], systemRom[5], systemRom[6], systemRom[7],
           systemRom[8], systemRom[9], systemRom[10], systemRom[11],
           systemRom[12], systemRom[13], systemRom[14], systemRom[15]);

    return 0;
}

static int init_emulator(void)
{
    LOG_INF("Initializing PCD68 emulator components");
    printk("DEBUG: Starting init_hardware()\n");

    // Use static allocation for emulated RAM - much better for embedded
    static unsigned char static_ram[32 * 1024];  // 32KB statically allocated to fit in RAM
    systemRam = static_ram;
    size_t ram_size = sizeof(static_ram);

    printk("DEBUG: Using %zu bytes static RAM\n", ram_size);
    memset(systemRam, 0, ram_size);
    printk("DEBUG: Static RAM initialized successfully\n");

    // Load ROM
    printk("DEBUG: Loading ROM\n");
    int ret = load_rom("program.bin");
    if (ret < 0) {
        printk("ERROR: ROM loading failed!\n");
        return ret;
    }
    printk("DEBUG: ROM loaded successfully\n");

    // Use global static CPU object (avoids dynamic allocation)
    printk("DEBUG: Creating Musashi CPU object...\n");
    printk("DEBUG: CPU object size: %zu bytes\n", sizeof(CPU));

    pcdCpu = &global_cpu;
    printk("DEBUG: Musashi CPU created successfully!\n");

    // TODO: Re-enable screen after Musashi migration
    printk("DEBUG: Skipping screen creation during Musashi migration\n");

    // TODO: Create minimal peripherals after Musashi migration complete
    printk("DEBUG: Skipping peripheral creation during Musashi migration\n");

    // TODO: Re-enable keyboard input after Musashi migration
    printk("DEBUG: Skipping keyboard input setup during Musashi migration\n");

    // Skip ALL peripheral attachments for initial 68000 core testing
    printk("DEBUG: Skipping ALL peripheral attachments due to memory constraints\n");
    printk("DEBUG: This will test pure 68000 CPU execution without peripherals\n");

    // Test memory access before CPU reset
    printk("DEBUG: Testing ROM access...\n");
    printk("DEBUG: ROM[0]=0x%02X ROM[1]=0x%02X ROM[2]=0x%02X ROM[3]=0x%02X\n",
           systemRom[0], systemRom[1], systemRom[2], systemRom[3]);
    printk("DEBUG: Testing RAM access...\n");
    systemRam[0] = 0xAA;
    systemRam[1] = 0x55;
    printk("DEBUG: RAM test write/read: wrote 0xAA55, read 0x%02X%02X\n",
           systemRam[0], systemRam[1]);

    // Try calling reset() now that we have a properly allocated CPU object
    printk("DEBUG: Calling CPU reset() with properly allocated object...\n");

    // Read initial stack pointer and program counter from ROM vector table
    // 68000 vector table: 0x0-0x3 = initial SSP, 0x4-0x7 = initial PC
    uint32_t initial_ssp = (systemRom[0] << 24) | (systemRom[1] << 16) |
                          (systemRom[2] << 8) | systemRom[3];
    uint32_t initial_pc = (systemRom[4] << 24) | (systemRom[5] << 16) |
                         (systemRom[6] << 8) | systemRom[7];

    printk("DEBUG: ROM vector table - SSP=0x%08X PC=0x%08X\n", initial_ssp, initial_pc);

    // Create a bootstrap program that will set the CPU state properly
    printk("DEBUG: Creating bootstrap program to initialize CPU state\n");

    // Save original ROM bytes
    uint8_t original_rom[16];
    memcpy(original_rom, systemRom, 16);

    // Create bootstrap code that sets SP and jumps to main program
    // 68000 assembly:
    // move.l #0x00BFFFFF, sp    ; Set stack pointer
    // jmp 0x1000               ; Jump to main program

    // Bootstrap vector table (temporary)
    // Stack at end of 32KB RAM: 0x010000 + 0x8000 = 0x018000
    systemRom[0] = 0x00; systemRom[1] = 0x01; systemRom[2] = 0x80; systemRom[3] = 0x00; // SSP = 0x018000
    systemRom[4] = 0x00; systemRom[5] = 0x00; systemRom[6] = 0x00; systemRom[7] = 0x10; // PC = 0x10 (bootstrap code)

    // Bootstrap code at address 0x10:
    // move.l #0x00018000, sp (0x2E7C 0x00018000)
    systemRom[0x10] = 0x2E; systemRom[0x11] = 0x7C;  // move.l #imm32, sp
    systemRom[0x12] = 0x00; systemRom[0x13] = 0x01;  // 0x00018000
    systemRom[0x14] = 0x80; systemRom[0x15] = 0x00;

    // jmp 0x1000 (0x4EF9 0x00001000)
    systemRom[0x16] = 0x4E; systemRom[0x17] = 0xF9;  // jmp absolute
    systemRom[0x18] = 0x00; systemRom[0x19] = 0x00;  // 0x00001000
    systemRom[0x1A] = 0x10; systemRom[0x1B] = 0x00;

    printk("DEBUG: Bootstrap program created - will set SP and jump to 0x1000\n");

    // Debug: Print the actual ROM values at vector positions
    printk("DEBUG: ROM vector table before reset:\n");
    printk("  [0x00-0x03] SSP: %02X %02X %02X %02X\n",
           systemRom[0], systemRom[1], systemRom[2], systemRom[3]);
    printk("  [0x04-0x07] PC:  %02X %02X %02X %02X\n",
           systemRom[4], systemRom[5], systemRom[6], systemRom[7]);
    printk("  [0x10-0x15] Bootstrap: %02X %02X %02X %02X %02X %02X\n",
           systemRom[0x10], systemRom[0x11], systemRom[0x12],
           systemRom[0x13], systemRom[0x14], systemRom[0x15]);

    // Now attempt a real CPU reset with the bootstrap ROM
    printk("DEBUG: Attempting CPU reset() with statically allocated object...\n");

    pcdCpu->reset();

    printk("DEBUG: CPU reset() completed successfully!\n");

    // Verify the CPU state after reset
    uint32_t pc = pcdCpu->getPC();
    uint32_t sp = pcdCpu->getSP();

    printk("DEBUG: After reset - PC=0x%08X SP=0x%08X\n", pc, sp);

    // The reset() function should have initialized everything properly
    // No need for manual prefetch queue initialization

    printk("DEBUG: CPU initialization completed!\n");
    printk("CPU STATE: PC=0x%08X SP=0x%08X\n",
           pcdCpu->getPC(), pcdCpu->getSP());

    printk("DEBUG: Emulator initialized successfully\n");
    printk("DEBUG: About to return from init_emulator()\n");
    return 0;
}

void emulation_thread_entry(void *p1, void *p2, void *p3)
{
    ARG_UNUSED(p1);
    ARG_UNUSED(p2);
    ARG_UNUSED(p3);

    LOG_INF("Emulation thread started");
    printk("EMULATION THREAD: Starting 68000 execution loop\n");

    uint32_t last_time = k_uptime_get_32();
    uint32_t cycles_executed = 0;
    uint32_t loop_count = 0;

    // Initial status check - avoid calling methods that might hang
    printk("EMULATION THREAD: Starting without initial CPU state check to avoid hangs\n");
    printk("EMULATION THREAD: Will check CPU state after first execute() call\n");

    while (1) {
        k_mutex_lock(&cpu_mutex, K_FOREVER);

        // Debug CPU state before execute() call
        uint32_t pc_value = pcdCpu->getPC();

        printk("DEBUG: Before execute() - PC=0x%08X\n", pc_value);

        // Check if values look correct
        if (pc_value != 0x00001000) {
            printk("WARNING: PC value incorrect, expected 0x00001000, got 0x%08X\n", pc_value);
        }

        printk("DEBUG: PC value looks valid, calling execute()...\n");

        // Execute CPU cycles using Moira
        pcdCpu->execute();
        cycles_executed += cycles_per_iteration;

        printk("DEBUG: execute() completed successfully!\n");

        k_mutex_unlock(&cpu_mutex);

        loop_count++;

        // More frequent status updates initially (every 1000 loops)
        if (loop_count % 1000 == 0) {
            printk("LOOP %u: Emulation thread running (avoiding CPU state calls for now)\n", loop_count);
        }

        // Yield to other threads
        k_yield();

        // Periodic status - using printk since LOG is disabled
        uint32_t now = k_uptime_get_32();
        if (now - last_time >= 3000) {  // Every 3 seconds
            printk("CPU STATUS: Cycles=%u Loops=%u Uptime=%u ms (CPU state calls disabled)\n",
                   cycles_executed, loop_count, now);
            cycles_executed = 0;
            last_time = now;
        }
    }
}

void display_thread_entry(void *p1, void *p2, void *p3)
{
    ARG_UNUSED(p1);
    ARG_UNUSED(p2);
    ARG_UNUSED(p3);

    LOG_INF("Display thread started (disabled during Musashi migration)");

    while (1) {
        // TODO: Re-enable display refresh after Musashi migration
        k_msleep(DISPLAY_REFRESH_MS);
    }
}

void input_thread_entry(void *p1, void *p2, void *p3)
{
    ARG_UNUSED(p1);
    ARG_UNUSED(p2);
    ARG_UNUSED(p3);

    LOG_INF("Input thread started (disabled during Musashi migration)");

    while (1) {
        // TODO: Re-enable keyboard input polling after Musashi migration
        k_msleep(100);
    }
}

int main(void)
{
    printk("PCD68 CyberTerminal for nRF54L15\n");
    printk("ROM: %dKB, RAM: 64KB, CPU: %dMHz\n",
           CONFIG_PCD68_ROM_SIZE_KB, CONFIG_PCD68_TARGET_CPU_MHZ);
    printk("E-paper display: 400x300 B/W\n");

    // Initialize hardware
    int ret = init_hardware();
    if (ret < 0) {
        LOG_ERR("Hardware initialization failed: %d", ret);
        return ret;
    }

    // Initialize storage
    ret = init_storage();
    if (ret < 0) {
        LOG_ERR("Storage initialization failed: %d", ret);
        return ret;
    }

    // Initialize emulator components
    ret = init_emulator();
    if (ret < 0) {
        LOG_ERR("Emulator initialization failed: %d", ret);
        return ret;
    }

    // Create threads
    printk("DEBUG: Creating emulation thread...\n");
    k_tid_t emulation_tid = k_thread_create(&emulation_thread,
                                            emulation_stack,
                                            K_THREAD_STACK_SIZEOF(emulation_stack),
                                            emulation_thread_entry,
                                            NULL, NULL, NULL,
                                            K_PRIO_PREEMPT(5),
                                            0, K_NO_WAIT);
    k_thread_name_set(emulation_tid, "pcd68_cpu");
    printk("DEBUG: Emulation thread created successfully\n");

    k_tid_t display_tid = k_thread_create(&display_thread,
                                          display_stack,
                                          K_THREAD_STACK_SIZEOF(display_stack),
                                          display_thread_entry,
                                          NULL, NULL, NULL,
                                          K_PRIO_PREEMPT(7),
                                          0, K_NO_WAIT);
    k_thread_name_set(display_tid, "pcd68_display");

    k_tid_t input_tid = k_thread_create(&input_thread,
                                        input_stack,
                                        K_THREAD_STACK_SIZEOF(input_stack),
                                        input_thread_entry,
                                        NULL, NULL, NULL,
                                        K_PRIO_PREEMPT(6),
                                        0, K_NO_WAIT);
    k_thread_name_set(input_tid, "pcd68_input");

    LOG_INF("PCD68 emulation started on nRF54L15");
    printk("PCD68 running - press keys to interact\n");

    // Main thread becomes a monitor/heartbeat
    int counter = 0;
    while (1) {
        k_sleep(K_SECONDS(15));
        counter++;
        LOG_INF("System heartbeat %d - uptime: %u ms", counter, k_uptime_get_32());
    }

    return 0;
}