---
title: PCD-68 Computer
order: 2
type: content
---

# PCD-68 Computer

The PCD-68 is a Motorola 68000-based virtual retro computer emulator that simulates hardware inspired by late 80s/early 90s computers. It draws inspiration from the original Macintosh, Canon Cat, and modern 68k homebrew machines.

## System Specifications

- 68000 CPU (emulation provided by Moira)
- 400x300 B/W Framebuffer/Display
- Text Display Adapter (TDA) with text-based graphics modes:
  - 80-column mode: Uses custom 5x13 font (80x23 chars)
  - 50-column mode: Uses IBM CGA font (50x33 chars)
- 4MB RAM
- 64KB ROM
- Dual UART (similar to Z80 SCC)
- Interrupt-driven Keyboard I/O

The emulator is being developed to eventually power actual hardware.

## Implementation Details

The emulator supports various connectivity options for the UART peripherals:

### Web Build (Emscripten)

In the web build, the UARTs connect to WebSockets:
- UART1 connects to `ws://localhost:8080`
- UART2 connects to `ws://localhost:8081`

### Native Builds (macOS/Linux)

For native builds, you can connect UARTs to hardware serial ports or named pipes (FIFOs).

## Architecture

### Core Components

1. **PCD68_CPU** - Wrapper around the Moira 68000 emulation core
2. **Screen** - Handles the display with SDL2 backend
3. **TDA (Text Display Adapter)** - Text-based graphics adapter
4. **UART** - Dual-channel UART for connectivity
5. **KCTL (Keyboard Controller)** - Manages keyboard input and interrupts

This project represents my ongoing exploration of vintage computing architectures and modern implementations of classic systems.