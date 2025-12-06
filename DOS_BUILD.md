# PCD-68 DOS Port

This document describes how to build and run PCD-68 on MS-DOS using DJGPP.

## CPU Core

The DOS port uses the **Moira** 68000 emulator core (same as the native build).

**Requirements:**
- DJGPP with **GCC 12+** (for C++14 binary literal support)
- Modern DJGPP builds available from: https://github.com/andrewwutw/build-djgpp/releases

| GCC Version | Status |
|-------------|--------|
| GCC 14.2.0 | ✅ Recommended |
| GCC 12.2.0 | ✅ Works |
| GCC 10.x | ✅ Works |
| GCC 5.x (old DJGPP) | ❌ Missing C++14 features |

## Requirements

### Cross-compiling from Linux

1. **DJGPP Cross-Compiler**

   Install the DJGPP cross-compiler. On Debian/Ubuntu:
   ```bash
   # Add the DJGPP repository or build from source
   # See: https://github.com/andrewwutw/build-djgpp

   # Or use a pre-built toolchain:
   # The cross-compiler should provide i586-pc-msdosdjgpp-g++
   ```

2. **Alternatively, use Docker**
   ```bash
   docker pull djgpp/djgpp
   docker run -v $(pwd):/src djgpp/djgpp make -f Makefile.dos
   ```

### Native DOS/DJGPP Build

1. Download DJGPP from http://www.delorie.com/djgpp/
2. Install the following packages:
   - djdev205.zip (DJGPP development environment)
   - gcc1220b.zip (GCC C++ compiler)
   - bnu2351b.zip (Binutils)
   - mak43b.zip (Make)

3. Set up environment:
   ```batch
   set DJGPP=C:\DJGPP\DJGPP.ENV
   set PATH=C:\DJGPP\BIN;%PATH%
   ```

## Building

### Cross-compile from Linux

```bash
# Edit Makefile.dos to use your cross-compiler path if needed
make -f Makefile.dos
```

### Native DOS build

```batch
make -f Makefile.dos
```

This produces `pcd68.exe`.

## Running

### Requirements

- **CWSDPMI.EXE** - DPMI server (included with DJGPP)
  - Place in the same directory as pcd68.exe or in PATH

### Usage

```batch
pcd68.exe program.bin [options]

Options:
  -nf              Disable E-Ink emulation effects
  -debug-uart      Enable UART debug output
  -debug-tda       Enable TDA debug output
  -debug-kbd       Enable keyboard debug output
  -debug-all       Enable all debug modes
  -com1 <port>     Connect UART1 to COM port (1-4)
  -com2 <port>     Connect UART2 to COM port (1-4)

Press ESC to exit the emulator.
```

### Examples

```batch
REM Basic usage
pcd68.exe myprog.bin

REM With serial port
pcd68.exe myprog.bin -com1 1

REM With debug output
pcd68.exe myprog.bin -debug-all
```

## Video Modes

The DOS port supports two video modes:

1. **VESA 640x400 or 640x480** (preferred)
   - Full 400x300 display with black border
   - Requires VESA-compatible video card
   - Linear framebuffer support recommended

2. **VGA Mode 13h** (fallback)
   - 320x200 resolution
   - Display is scaled down to fit
   - Works on any VGA card

The emulator automatically tries VESA first and falls back to Mode 13h.

## Serial Port Support

Connect to physical serial ports using the `-com1` and `-com2` options:

```batch
REM Connect UART1 to COM1
pcd68.exe myprog.bin -com1 1

REM Connect both UARTs
pcd68.exe myprog.bin -com1 1 -com2 2
```

Serial communication uses BIOS int 14h and is limited to 9600 baud.

## Memory Requirements

- Minimum: 4MB RAM (for 68000 RAM + overhead)
- Recommended: 8MB+ RAM
- Uses DPMI for protected mode memory access

## Known Limitations

1. **Serial baud rate** - BIOS limits to 9600 baud max
2. **No E-Ink full emulation** - Simplified grayscale effects only
3. **Timing accuracy** - DOS timer resolution is ~55ms (18.2 Hz)
4. **No WebSocket/TCP** - Only COM port serial available

## Troubleshooting

### "No DPMI" error
Install CWSDPMI.EXE in the same directory or PATH.

### Black screen / no video
Your video card may not support VESA. The emulator should fall back to Mode 13h,
but some very old cards may have issues.

### Keyboard not responding
Make sure you're not running in a Windows DOS box with keyboard issues.
Try running in pure DOS mode or DOSBox.

### Out of memory
Ensure you have at least 4MB of extended memory available.
Check with `mem /c /p` command.

## Testing with DOSBox

You can test the DOS build using DOSBox:

```bash
# Mount your build directory
mount c /path/to/pcd68-cpp
c:
pcd68.exe program.bin
```

Configure DOSBox for more memory if needed:
```ini
[dosbox]
memsize=32

[dos]
xms=true
ems=true
```

## Architecture Notes

The DOS port uses:
- **Screen_DOS.cpp** - VGA/VESA graphics
- **KeyboardInputDOS.cpp** - BIOS keyboard input
- **UART_DOS.cpp** - BIOS serial I/O (no threading)
- **main_dos.cpp** - Simplified main loop

All threading and mutex code is removed since DOS is single-threaded.
