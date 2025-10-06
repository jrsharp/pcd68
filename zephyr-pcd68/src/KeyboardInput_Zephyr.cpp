#include "KeyboardInput_Zephyr.h"
#include "KCTL.h"
#include <zephyr/logging/log.h>
#include <zephyr/input/input.h>

LOG_MODULE_DECLARE(pcd68_main);

// Basic HID keycode to ASCII mapping
const uint8_t KeyboardInput_Zephyr::hid_to_ascii[256] = {
    0, 0, 0, 0,           // 0x00-0x03: Reserved
    'a', 'b', 'c', 'd',   // 0x04-0x07: A-D
    'e', 'f', 'g', 'h',   // 0x08-0x0B: E-H
    'i', 'j', 'k', 'l',   // 0x0C-0x0F: I-L
    'm', 'n', 'o', 'p',   // 0x10-0x13: M-P
    'q', 'r', 's', 't',   // 0x14-0x17: Q-T
    'u', 'v', 'w', 'x',   // 0x18-0x1B: U-X
    'y', 'z',             // 0x1C-0x1D: Y-Z
    '1', '2', '3', '4',   // 0x1E-0x21: 1-4
    '5', '6', '7', '8',   // 0x22-0x25: 5-8
    '9', '0',             // 0x26-0x27: 9-0
    '\r', '\x1B', '\b',   // 0x28-0x2A: Enter, Escape, Backspace
    '\t', ' ',            // 0x2B-0x2C: Tab, Space
    '-', '=',             // 0x2D-0x2E: - =
    '[', ']',             // 0x2F-0x30: [ ]
    '\\', 0,              // 0x31-0x32: \ (non-US)
    ';', '\'',            // 0x33-0x34: ; '
    '`',                  // 0x35: `
    ',', '.', '/',        // 0x36-0x38: , . /
    0,                    // 0x39: Caps Lock
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 0x3A-0x45: F1-F12
    0, 0, 0,              // 0x46-0x48: Print Screen, Scroll Lock, Pause
    0, 0, 0,              // 0x49-0x4B: Insert, Home, Page Up
    0, 0, 0,              // 0x4C-0x4E: Delete, End, Page Down
    0, 0, 0, 0,           // 0x4F-0x52: Arrow keys
    0,                    // 0x53: Num Lock
    '/', '*', '-', '+',   // 0x54-0x57: Keypad operators
    '\r',                 // 0x58: Keypad Enter
    '1', '2', '3', '4',   // 0x59-0x5C: Keypad 1-4
    '5', '6', '7', '8',   // 0x5D-0x60: Keypad 5-8
    '9', '0', '.',        // 0x61-0x63: Keypad 9, 0, .
    // Rest initialized to 0
};

KeyboardInput_Zephyr::KeyboardInput_Zephyr()
    : keyboardController(nullptr), input_dev(nullptr)
{
    memset(&current_report, 0, sizeof(current_report));
}

KeyboardInput_Zephyr::~KeyboardInput_Zephyr()
{
}

bool KeyboardInput_Zephyr::init()
{
    LOG_INF("Initializing keyboard input");
    
    // For now, we'll handle input through console or other means
    // In a full implementation, you'd initialize USB HID host or other input device
    
#ifdef CONFIG_INPUT
    // Try to find an input device
    input_dev = DEVICE_DT_GET_ANY(input_gpio_keys);
    if (input_dev && device_is_ready(input_dev)) {
        LOG_INF("Found input device: %s", input_dev->name);
        
        // Register input callback
        input_callback_set(input_dev, input_event_handler, this);
        return true;
    }
#endif
    
    LOG_WRN("No input device found, using console input simulation");
    return true;
}

void KeyboardInput_Zephyr::poll()
{
    // For console-based input simulation, we could read from console here
    // In a real implementation, this would be handled by input callbacks
    
    static uint32_t last_key_time = 0;
    static uint8_t test_key = 0x04;  // 'A' key for testing
    
    // Simple test: inject a key press every 5 seconds for testing
    uint32_t now = k_uptime_get_32();
    if (now - last_key_time > 5000) {
        if (keyboardController) {
            // Simulate key press
            current_report.key_count = 1;
            current_report.keys[0] = test_key++;
            if (test_key > 0x1D) test_key = 0x04;  // A-Z range
            
            // Send report to keyboard controller
            uint8_t report[8] = {0};
            report[0] = current_report.modifiers;
            report[1] = 0;  // Reserved
            memcpy(&report[2], current_report.keys, 6);
            
            keyboardController->receiveReport(report, 8);
            
            LOG_DBG("Sent test key report: 0x%02x", current_report.keys[0]);
        }
        last_key_time = now;
    }
}

void KeyboardInput_Zephyr::input_event_handler(struct input_event *evt, void *user_data)
{
    KeyboardInput_Zephyr *kbd = static_cast<KeyboardInput_Zephyr*>(user_data);
    
    if (!kbd || !kbd->keyboardController) {
        return;
    }
    
    LOG_DBG("Input event: type=%d, code=%d, value=%d", evt->type, evt->code, evt->value);
    
    // Handle different input event types
    switch (evt->type) {
        case INPUT_EV_KEY: {
            uint8_t hid_code = evt->code;  // Assuming direct HID mapping
            
            if (evt->value) {
                // Key press - add to report if not already present
                bool found = false;
                for (int i = 0; i < kbd->current_report.key_count; i++) {
                    if (kbd->current_report.keys[i] == hid_code) {
                        found = true;
                        break;
                    }
                }
                
                if (!found && kbd->current_report.key_count < 6) {
                    kbd->current_report.keys[kbd->current_report.key_count++] = hid_code;
                }
            } else {
                // Key release - remove from report
                for (int i = 0; i < kbd->current_report.key_count; i++) {
                    if (kbd->current_report.keys[i] == hid_code) {
                        // Shift remaining keys down
                        memmove(&kbd->current_report.keys[i], 
                               &kbd->current_report.keys[i + 1],
                               kbd->current_report.key_count - i - 1);
                        kbd->current_report.key_count--;
                        break;
                    }
                }
            }
            
            // Send updated report
            uint8_t report[8] = {0};
            report[0] = kbd->current_report.modifiers;
            report[1] = 0;  // Reserved
            memcpy(&report[2], kbd->current_report.keys, 6);
            
            kbd->keyboardController->receiveReport(report, 8);
            break;
        }
        
        default:
            // Ignore other event types for now
            break;
    }
}