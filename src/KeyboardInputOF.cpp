/*
 * Open Firmware Keyboard Input Implementation
 */

#include "KeyboardInputOF.h"
#include "KCTL.h"

extern KCTL *keyboardController;

KeyboardInputOF::KeyboardInputOF() {
    /* Nothing to initialize - OF handles keyboard setup */
}

KeyboardInputOF::~KeyboardInputOF() {
    /* Nothing to clean up */
}

void KeyboardInputOF::pollEvents() {
    /* Non-blocking key check */
    int key = of_getchar();

    if (key >= 0) {
        uint8_t pcd_key = of_to_pcd68_key(key);

        if (pcd_key != 0) {
            /* Send to keyboard controller */
            if (keyboardController) {
                keyboardController->keypress(pcd_key);
            }
        }

        /* Check for special keys */
        if (key == 27) { /* ESC - exit emulator */
            of_print("\nExiting PCD68...\n");
            of_exit();
        }
    }
}

uint8_t KeyboardInputOF::of_to_pcd68_key(int of_key) {
    /* Map ASCII/OF keys to PCD68 key codes */
    /* This is a simplified mapping - expand as needed */

    if (of_key >= 'a' && of_key <= 'z') {
        return of_key - 'a' + 0x61; /* ASCII lowercase */
    }
    if (of_key >= 'A' && of_key <= 'Z') {
        return of_key - 'A' + 0x41; /* ASCII uppercase */
    }
    if (of_key >= '0' && of_key <= '9') {
        return of_key; /* ASCII digits */
    }

    switch (of_key) {
    case '\r':
    case '\n':
        return 0x0D; /* Enter */
    case '\b':
    case 127:
        return 0x08; /* Backspace */
    case ' ':
        return 0x20; /* Space */
    case '\t':
        return 0x09; /* Tab */

    /* Special characters */
    case '.': return 0x2E;
    case ',': return 0x2C;
    case ';': return 0x3B;
    case ':': return 0x3A;
    case '!': return 0x21;
    case '?': return 0x3F;
    case '/': return 0x2F;
    case '\\': return 0x5C;
    case '-': return 0x2D;
    case '_': return 0x5F;
    case '=': return 0x3D;
    case '+': return 0x2B;
    case '(': return 0x28;
    case ')': return 0x29;
    case '[': return 0x5B;
    case ']': return 0x5D;
    case '{': return 0x7B;
    case '}': return 0x7D;
    case '\'': return 0x27;
    case '"': return 0x22;
    case '`': return 0x60;
    case '~': return 0x7E;
    case '@': return 0x40;
    case '#': return 0x23;
    case '$': return 0x24;
    case '%': return 0x25;
    case '^': return 0x5E;
    case '&': return 0x26;
    case '*': return 0x2A;
    case '<': return 0x3C;
    case '>': return 0x3E;
    case '|': return 0x7C;

    default:
        return 0; /* Unknown key */
    }
}