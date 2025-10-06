#ifndef KEYBOARDINPUT_ZEPHYR_H
#define KEYBOARDINPUT_ZEPHYR_H

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/input/input.h>

class KCTL;  // Forward declaration

class KeyboardInput_Zephyr {
public:
    KeyboardInput_Zephyr();
    virtual ~KeyboardInput_Zephyr();
    
    bool init();
    void poll();
    void setKeyboardController(KCTL* kctl) { keyboardController = kctl; }
    
private:
    KCTL* keyboardController;
    const struct device* input_dev;
    
    // USB HID key mapping
    static const uint8_t hid_to_ascii[256];
    
    // Input event callback
    static void input_event_handler(struct input_event *evt, void *user_data);
    
    // Current key state
    struct {
        uint8_t modifiers;
        uint8_t keys[6];  // Standard USB HID allows up to 6 simultaneous keys
        uint8_t key_count;
    } current_report;
};

#endif // KEYBOARDINPUT_ZEPHYR_H