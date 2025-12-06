/*
 * Copyright (c) 2024, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 *
 * DOS keyboard input implementation for PCD-68
 */

#ifdef __DJGPP__

#include "KeyboardInputDOS.h"
#include <pc.h>
#include <bios.h>
#include <dpmi.h>
#include <conio.h>
#include <go32.h>
#include <sys/farptr.h>
#include <iostream>

// External overlay toggle (defined in main_dos.cpp)
extern bool showOverlay;

// BIOS keyboard data area
#define BIOS_KBD_FLAGS1     0x417   // Shift flags byte 1
#define BIOS_KBD_FLAGS2     0x418   // Shift flags byte 2

// Modifier bit masks (matching USB HID style)
#define MOD_LCTRL   0x01
#define MOD_LSHIFT  0x02
#define MOD_LALT    0x04
#define MOD_RCTRL   0x10
#define MOD_RSHIFT  0x20
#define MOD_RALT    0x40

// Extended scan codes for special keys
#define SCAN_UP     0x48
#define SCAN_DOWN   0x50
#define SCAN_LEFT   0x4B
#define SCAN_RIGHT  0x4D
#define SCAN_HOME   0x47
#define SCAN_END    0x4F
#define SCAN_PGUP   0x49
#define SCAN_PGDN   0x51
#define SCAN_INS    0x52
#define SCAN_DEL    0x53
#define SCAN_F1     0x3B
#define SCAN_F10    0x44
#define SCAN_F11    0x57
#define SCAN_F12    0x58

KeyboardInputDOS::KeyboardInputDOS() :
    pendingKeyCount(0),
    currentModifiers(0),
    debugEnabled(false) {
    for (int i = 0; i < MAX_KEYS_PER_REPORT; i++) {
        pendingKeys[i] = 0;
    }
}

KeyboardInputDOS::~KeyboardInputDOS() {
    // Nothing to clean up
}

int KeyboardInputDOS::init() {
    if (debugEnabled) {
        std::cout << "KeyboardInputDOS: Initialized" << std::endl;
    }
    return 0;
}

u16 KeyboardInputDOS::getModifierState() {
    // Read BIOS keyboard flags
    u8 flags = _farpeekb(_dos_ds, 0x400 + 0x17);  // BIOS data area at 0x40:0x17

    u16 mods = 0;

    if (flags & 0x01) mods |= MOD_RSHIFT;  // Right Shift
    if (flags & 0x02) mods |= MOD_LSHIFT;  // Left Shift
    if (flags & 0x04) mods |= MOD_LCTRL;   // Ctrl
    if (flags & 0x08) mods |= MOD_LALT;    // Alt

    return mods;
}

u16 KeyboardInputDOS::handleExtendedKey(u8 scanCode) {
    // Map extended scan codes to our key codes
    // We use values 16-31 for special keys (matching the SDL implementation)
    switch (scanCode) {
        case SCAN_UP:    return 16;  // Up arrow
        case SCAN_DOWN:  return 17;  // Down arrow
        case SCAN_LEFT:  return 18;  // Left arrow
        case SCAN_RIGHT: return 19;  // Right arrow
        case SCAN_HOME:  return 20;  // Home
        case SCAN_END:   return 21;  // End
        case SCAN_PGUP:  return 22;  // Page Up
        case SCAN_PGDN:  return 23;  // Page Down
        case SCAN_INS:   return 24;  // Insert
        case SCAN_DEL:   return 127; // Delete (ASCII DEL)

        // Function keys F1-F12 -> 128-139
        case SCAN_F1:    return 128;
        case SCAN_F1+1:  return 129;
        case SCAN_F1+2:  return 130;
        case SCAN_F1+3:  return 131;
        case SCAN_F1+4:  return 132;
        case SCAN_F1+5:  return 133;
        case SCAN_F1+6:  return 134;
        case SCAN_F1+7:  return 135;
        case SCAN_F1+8:  return 136;
        case SCAN_F1+9:  return 137;
        case SCAN_F11:   return 138;
        case SCAN_F12:   return 139;

        default:
            return 0;  // Unknown extended key
    }
}

void KeyboardInputDOS::submitPendingKeys() {
    if (pendingKeyCount == 0) {
        return;
    }

    // Try multi-key callback first
    if (keyMultiEventCallback && pendingKeyCount > 1) {
        keyMultiEventCallback(pendingKeys, pendingKeyCount, currentModifiers & 0xFF);
    } else if (keyEventCallback) {
        // Fall back to single key events
        for (int i = 0; i < pendingKeyCount; i++) {
            keyEventCallback(pendingKeys[i], currentModifiers);
        }
    }

    // Clear pending buffer
    pendingKeyCount = 0;
    for (int i = 0; i < MAX_KEYS_PER_REPORT; i++) {
        pendingKeys[i] = 0;
    }
}

bool KeyboardInputDOS::poll() {
    // Update modifier state
    currentModifiers = getModifierState();

    // Check if a key is available
    if (!kbhit()) {
        // No key available, submit any pending keys
        submitPendingKeys();
        return true;  // Continue running
    }

    // Get the key
    int key = getch();

    if (debugEnabled) {
        std::cout << "KeyboardInputDOS: Got key 0x" << std::hex << key << std::dec << std::endl;
    }

    // Check for ESC to exit
    if (key == 27) {  // ESC
        submitPendingKeys();
        return false;  // Exit
    }

    // Check for extended key (0x00 or 0xE0 prefix)
    if (key == 0 || key == 0xE0) {
        // Extended key - get the scan code
        int scanCode = getch();

        if (debugEnabled) {
            std::cout << "KeyboardInputDOS: Extended scan 0x" << std::hex << scanCode << std::dec << std::endl;
        }

        // Check for F1 to toggle overlay (handled here, not passed to emulator)
        if (scanCode == SCAN_F1) {
            showOverlay = !showOverlay;
            return true;
        }

        u16 mappedKey = handleExtendedKey(scanCode);
        if (mappedKey > 0) {
            key = mappedKey;
        } else {
            return true;  // Unknown extended key, ignore
        }
    }

    // Add key to pending buffer
    if (pendingKeyCount < MAX_KEYS_PER_REPORT) {
        pendingKeys[pendingKeyCount++] = key & 0xFF;
    }

    // Submit immediately for responsive feel
    // (DOS doesn't have the event batching issues of windowed systems)
    submitPendingKeys();

    return true;  // Continue running
}

void KeyboardInputDOS::setDebugMode(bool enabled) {
    debugEnabled = enabled;
    if (enabled) {
        std::cout << "KeyboardInputDOS: Debug mode enabled" << std::endl;
    }
}

#endif // __DJGPP__
