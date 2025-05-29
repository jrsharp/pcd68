PCD-68
======

![Render of FRST Computer's Model 1 Computer](doc/Model1Render.png)

PCD-68 is a Motorola 68000-based (m68k) virtual retro computer -- that is, it is
a new personal computer specification implemented in software that emulates 
real hardware from the past.  It resembles familiar, real hardware from the late 
80s/early 90s, as it draws inspiration from the original Macintosh, Canon Cat,
and Palm Pilot as well as more modern 68k-based homebrew machines.

_In time, it will also power the hardware pictured above._

_An interactive demo is live on [JonSharp.net](https://jonsharp.net) now_

## Project Brief

 - 68000 emulation provided by [Moira](https://dirkwhoffmann.github.io/Moira/about.html)
 - 400x300 B/W Framebuffer/Display
   - "Text Display Adapter" - provides text-based graphics modes:
     - 80-column mode: Uses custom 5x13 font (80x23 chars)
     - 50-column mode: Uses IBM CGA font (50x33 chars)
   - Raw Framebuffer graphics mode
 - 4MB RAM
 - 64k ROM
 - Dual UART
 - Keyboard I/O
   - Interrupt-driven

## Zig

 - Selected for convenient and flexible target selection
 - No native zig code (yet)

## Targets

## Zig native targets

Zig build is used to conveniently target supported native targets. (Supported
by the LLVM toolchain provided with Zig)

Active development and testing is taking place on both Ubuntu Linux and macOS.

SDL2 is currently the only external library dependency.

### Emscripten

A web target has been a goal of this project from the start, and while this
would ideally be implemented using the zig wasm32 target, this is currently
being provided by the Emscripten toolchain, primarily for its convenient SDL2
port. The zig build script will invoke Emscripten (em++) externally if the 
"build-web" param is set. (Emscripten must be installed and in the shell's
PATH:

> zig build -Dbuild-web=true 

Emscripten will compile pcd68-cpp, placing the output in ```zig-out/web```.
A convenient python script is provided for testing:

> python3 ./src/emscripten/serve2.py

## UART Connectivity Options

The PCD-68 emulator provides several options for connecting the UART peripherals to external devices or software.

### Web Build (Emscripten)

In the web build, the UARTs connect to WebSockets:

- UART1 connects to `ws://localhost:8080`
- UART2 connects to `ws://localhost:8081` 

### Native Builds (macOS/Linux)

For native builds, you can connect UARTs to hardware serial ports or named pipes:

#### Serial Port Connection

```bash
# Connect UART1 to a serial port
./pcd68 program.bin -serial1 /dev/tty.usbserial

# Connect both UARTs to different serial ports
./pcd68 program.bin -serial1 /dev/tty.usbserial1 -serial2 /dev/tty.usbserial2
```

#### Named Pipes (FIFOs)

Named pipes allow you to communicate with the emulator from other applications or terminal windows:

```bash
# First, create the pipes
mkfifo /tmp/uart1_in /tmp/uart1_out

# Run the emulator with pipes for UART1
./pcd68 program.bin -pipe-in1 /tmp/uart1_in -pipe-out1 /tmp/uart1_out

# In another terminal, send data to the UART
echo "Hello World" > /tmp/uart1_in

# In another terminal, read data sent by the UART
cat /tmp/uart1_out
```

You can also connect UART2 with additional pipes:

```bash
# Create all pipes
mkfifo /tmp/uart1_in /tmp/uart1_out /tmp/uart2_in /tmp/uart2_out

# Connect both UARTs to pipes
./pcd68 program.bin -pipe-in1 /tmp/uart1_in -pipe-out1 /tmp/uart1_out \
                    -pipe-in2 /tmp/uart2_in -pipe-out2 /tmp/uart2_out
```

### Debug Options

Debug mode options provide visibility into data flow:

```bash
# Enable UART debug mode (trace all UART data flow)
./pcd68 program.bin -debug-uart

# Enable Text Display Adapter debug mode (trace text display updates)
./pcd68 program.bin -debug-tda

# Enable all debug modes
./pcd68 program.bin -debug-all
```

With UART debug mode enabled, you'll see detailed logs of all bytes transmitted and received through the UARTs, including data from serial ports, pipes, or WebSockets.

## Command Line Options

```
Usage: ./pcd68 [ROM_FILE] [OPTIONS]
Options:
  -nf              Disable full E-Ink emulation
  -debug-uart      Enable UART debug mode (trace data flow)
  -debug-tda       Enable TDA debug mode (trace text display updates)
  -debug-all       Enable all debug modes
  -serial1 <dev>   Connect UART1 to serial device (e.g., /dev/tty.usbserial)
  -serial2 <dev>   Connect UART2 to serial device
  -pipe-in1 <path> Input pipe for UART1 (e.g., /tmp/uart1_in)
  -pipe-out1 <path> Output pipe for UART1 (e.g., /tmp/uart1_out)
  -pipe-in2 <path> Input pipe for UART2
  -pipe-out2 <path> Output pipe for UART2
```

## TODO / Issues

 - UART (Based on Zilog SCC? Another UART? How closely conforming?)
 - 68k software libraries/routines for graphics/UI/input processing?

## E-Ink emulation

(In progress) E-Ink emulation is now on by default and can be turned off like:

> ./zig-out/bin/pcd68 text_demo.bin -nf

