#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/display.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/drivers/spi.h>
#include <zephyr/logging/log.h>
#include <zephyr/sys/printk.h>
#include <zephyr/storage/flash_map.h>
#include <zephyr/fs/fs.h>
#include <zephyr/fs/littlefs.h>

#include "PCD68_CPU.h"
#include "TDA.h"
#include "KCTL.h"
#include "UART.h"
#include "Screen_Zephyr.h"
#include "KeyboardInput_Zephyr.h"
#include "Storage_Zephyr.h"

LOG_MODULE_REGISTER(pcd68_main, CONFIG_PCD68_DEBUG_LEVEL);

// Global emulator components
static u8* systemRom = nullptr;
static u8* systemRam = nullptr;
static CPU* pcdCpu = nullptr;
static TDA* textDisplayAdapter = nullptr;
static KCTL* keyboardController = nullptr;
static UART* uartController = nullptr;
static Screen_Zephyr* pcdScreen = nullptr;
static KeyboardInput_Zephyr* keyboardInput = nullptr;
static Storage_Zephyr* storage = nullptr;

// Emulation timing
static uint32_t cycles_per_iteration = 1000;
static uint32_t target_cpu_hz = CONFIG_PCD68_TARGET_CPU_MHZ * 1000000;
static uint32_t iteration_delay_us = (cycles_per_iteration * 1000000) / target_cpu_hz;

// Thread stacks
K_THREAD_STACK_DEFINE(emulation_stack, 8192);
K_THREAD_STACK_DEFINE(display_stack, 4096);
K_THREAD_STACK_DEFINE(input_stack, 2048);

struct k_thread emulation_thread;
struct k_thread display_thread;
struct k_thread input_thread;

// Synchronization
K_SEM_DEFINE(display_sem, 0, 1);
K_MUTEX_DEFINE(cpu_mutex);

// Display refresh rate (Hz)
#define DISPLAY_REFRESH_RATE 30
#define DISPLAY_REFRESH_MS (1000 / DISPLAY_REFRESH_RATE)

// Forward declarations
void emulation_thread_entry(void *p1, void *p2, void *p3);
void display_thread_entry(void *p1, void *p2, void *p3);
void input_thread_entry(void *p1, void *p2, void *p3);

static int init_hardware(void)
{
    LOG_INF("Initializing hardware for PCD68 on ESP32-S3");
    
    // Initialize display
    const struct device *display_dev = DEVICE_DT_GET(DT_CHOSEN(zephyr_display));
    if (!device_is_ready(display_dev)) {
        LOG_ERR("Display device not ready");
        return -ENODEV;
    }
    
    // Get display capabilities
    struct display_capabilities caps;
    display_get_capabilities(display_dev, &caps);
    LOG_INF("Display: %dx%d, pixel format: %d", 
            caps.x_resolution, caps.y_resolution, caps.current_pixel_format);
    
    return 0;
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
    
    size_t rom_size = CONFIG_PCD68_ROM_SIZE_KB * 1024;
    systemRom = new u8[rom_size];
    memset(systemRom, 0xFF, rom_size);
    
    // Try to load ROM from storage
    if (!storage->loadRom(rom_filename, systemRom, rom_size)) {
        LOG_WRN("Failed to load ROM from storage, using default pattern");
        // Initialize with a basic pattern or embedded ROM
        // For now, just a simple infinite loop at reset vector
        systemRom[0] = 0x00;  // Initial SP high
        systemRom[1] = 0x00;
        systemRom[2] = 0x10;
        systemRom[3] = 0x00;  // Initial SP low (0x001000)
        systemRom[4] = 0x00;  // Initial PC high
        systemRom[5] = 0x00;
        systemRom[6] = 0x00;
        systemRom[7] = 0x08;  // Initial PC low (0x000008)
        // Simple infinite loop: BRA.S *
        systemRom[8] = 0x60;
        systemRom[9] = 0xFE;
    }
    
    return 0;
}

static int init_emulator(void)
{
    LOG_INF("Initializing PCD68 emulator components");
    
    // Allocate RAM
    size_t ram_size = CONFIG_PCD68_RAM_SIZE_MB * 1024 * 1024;
    systemRam = new u8[ram_size];
    if (!systemRam) {
        LOG_ERR("Failed to allocate %d MB RAM", CONFIG_PCD68_RAM_SIZE_MB);
        return -ENOMEM;
    }
    memset(systemRam, 0, ram_size);
    
    // Load ROM
    int ret = load_rom(CONFIG_PCD68_DEFAULT_ROM);
    if (ret < 0) {
        return ret;
    }
    
    // Create CPU
    pcdCpu = new CPU();
    pcdCpu->setSystemRom(systemRom, CONFIG_PCD68_ROM_SIZE_KB * 1024);
    pcdCpu->setSystemRam(systemRam, ram_size);
    
    // Create peripherals
    textDisplayAdapter = new TDA(0x410000);
    keyboardController = new KCTL(0x420000);
    uartController = new UART(0x450000);
    
    // Create Zephyr-specific screen implementation
    pcdScreen = new Screen_Zephyr(0x810000);
    pcdScreen->init();
    
    // Create Zephyr-specific keyboard input
    keyboardInput = new KeyboardInput_Zephyr();
    keyboardInput->init();
    keyboardInput->setKeyboardController(keyboardController);
    
    // Connect peripherals to CPU
    pcdCpu->addPeripheral(textDisplayAdapter);
    pcdCpu->addPeripheral(keyboardController);
    pcdCpu->addPeripheral(uartController);
    pcdCpu->addPeripheral(pcdScreen);
    
    // Connect TDA to screen
    textDisplayAdapter->setScreen(pcdScreen);
    
    // Reset CPU
    pcdCpu->reset();
    pcdCpu->setIPL(0x00);
    
    LOG_INF("Emulator initialized successfully");
    return 0;
}

void emulation_thread_entry(void *p1, void *p2, void *p3)
{
    ARG_UNUSED(p1);
    ARG_UNUSED(p2);
    ARG_UNUSED(p3);
    
    LOG_INF("Emulation thread started");
    
    uint32_t last_time = k_uptime_get_32();
    uint32_t cycles_executed = 0;
    
    while (1) {
        k_mutex_lock(&cpu_mutex, K_FOREVER);
        
        // Execute CPU cycles
        cycles_executed += pcdCpu->execute(cycles_per_iteration);
        
        // Check for interrupts
        if (keyboardController->hasInterrupt()) {
            pcdCpu->setIPL(0x03);  // Keyboard at level 3
        }
        
        k_mutex_unlock(&cpu_mutex);
        
        // Throttle CPU if enabled
        if (CONFIG_PCD68_CPU_THROTTLE) {
            k_usleep(iteration_delay_us);
        } else {
            k_yield();  // Just yield to other threads
        }
        
        // Periodic status
        uint32_t now = k_uptime_get_32();
        if (now - last_time >= 1000) {
            LOG_DBG("CPU: %u cycles/sec", cycles_executed);
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
    
    LOG_INF("Display thread started");
    
    while (1) {
        // Update display if needed
        if (pcdScreen->needsRefresh()) {
            k_mutex_lock(&cpu_mutex, K_FOREVER);
            pcdScreen->refresh();
            k_mutex_unlock(&cpu_mutex);
        }
        
        k_msleep(DISPLAY_REFRESH_MS);
    }
}

void input_thread_entry(void *p1, void *p2, void *p3)
{
    ARG_UNUSED(p1);
    ARG_UNUSED(p2);
    ARG_UNUSED(p3);
    
    LOG_INF("Input thread started");
    
    while (1) {
        // Poll for keyboard input
        keyboardInput->poll();
        
        // Small delay to avoid excessive polling
        k_msleep(10);
    }
}

int main(void)
{
    printk("PCD68 Emulator for Zephyr/ESP32-S3\n");
    printk("ROM: %dKB, RAM: %dMB\n", 
           CONFIG_PCD68_ROM_SIZE_KB, CONFIG_PCD68_RAM_SIZE_MB);
    
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
    
    // Initialize emulator
    ret = init_emulator();
    if (ret < 0) {
        LOG_ERR("Emulator initialization failed: %d", ret);
        return ret;
    }
    
    // Create threads
    k_thread_create(&emulation_thread, emulation_stack,
                    K_THREAD_STACK_SIZEOF(emulation_stack),
                    emulation_thread_entry,
                    NULL, NULL, NULL,
                    5, 0, K_NO_WAIT);
    k_thread_name_set(&emulation_thread, "pcd68_emu");
    
    k_thread_create(&display_thread, display_stack,
                    K_THREAD_STACK_SIZEOF(display_stack),
                    display_thread_entry,
                    NULL, NULL, NULL,
                    7, 0, K_NO_WAIT);
    k_thread_name_set(&display_thread, "pcd68_display");
    
    k_thread_create(&input_thread, input_stack,
                    K_THREAD_STACK_SIZEOF(input_stack),
                    input_thread_entry,
                    NULL, NULL, NULL,
                    6, 0, K_NO_WAIT);
    k_thread_name_set(&input_thread, "pcd68_input");
    
    LOG_INF("PCD68 emulator started");
    
    // Main thread can do other tasks or sleep
    while (1) {
        k_sleep(K_SECONDS(60));
        
        // Periodic health check
        LOG_INF("System healthy - uptime: %u seconds", k_uptime_get_32() / 1000);
    }
    
    return 0;
}