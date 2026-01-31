/*
 * Open Firmware Keyboard Input for PCD68
 */

#pragma once

#include "KeyboardInput.h"
#include "openfirmware.h"

class KeyboardInputOF : public KeyboardInput {
public:
    KeyboardInputOF();
    ~KeyboardInputOF();

    void pollEvents() override;

private:
    /* Convert OF key codes to PCD68 format */
    uint8_t of_to_pcd68_key(int of_key);
};