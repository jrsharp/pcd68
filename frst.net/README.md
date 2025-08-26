FRST.net -- as a demonstration ROM for the PCD-68 virtual retro computer
    (with direct access to FRST:Net Aether mesh test net)

==========

## Overview

The FRST.net Cyberterminal is a ROM image for the PCD-68 retro computer
emulator (as realized in the FRST Computer Model 1 Cyberterminal) that provides
a BBS-like interface to access information on the FRST:Net test net -- an
experimental mesh networking stack -- both virtual and real..

The Aether mesh network is exposed via an Aether "modem" attached to one of the
PCD-68 UARTs.  This Aether modem communicates via AT commands, resembling a
HAYES modem, but instead of the telephone network, the Aether modem exposes the
Aether mesh network, made up of real and virtual LoRa radio nodes.

The Aether mesh layer provides a foundation for information sharing, live chat,
bulletin board interaction and games.  This ROM provides a complete Aether mesh
experience, providing a simple to use information terminal for people of all
backgrounds.

## Features

- **Single-Key Navigation**: Use single keystrokes to navigate between modes and content

## Keyboard Input Flow

The keyboard input system follows this flow:

1. **Hardware Interrupt**: Keyboard controller (at 0x420000) triggers an interrupt
2. **Keyboard Handler**: Reads key from keyboard controller registers
3. **process_keyboard_input**: 
   - Gets keystroke from keyboard buffer
   - Stores key code in register D6 for display
   - Calls `process_keystroke` function

4. **process_keystroke**:
   - Handles navigation keys (h, b, ?, q)
   - Routes to menu-specific handlers based on current_menu_id
   - Uses branch table to efficiently handle different keys

5. **Display Update**:
   - Sets display_needs_update flag
   - Main loop checks this flag and refreshes screen when needed

## Navigation

The cyberterminal uses single-key navigation:

- `h` - Return to home/main menu
- `?` - Display help
