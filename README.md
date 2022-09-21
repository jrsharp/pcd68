PCD-68
======

![Render of FRST Computer's Model 1 Computer](doc/Model1Render.png)

PCD-68 is a Motorola 68000-based (m68k) virtual retro computer -- that is, it is a
new computer personal computer specification implemented in software that emulates 
real hardware from the past.  It resembles familiar, real hardware from the late 
80s/early 90s, as it draws inspiration from the original Macintosh and Canon Cat, 
as well as more modern 68k-based homebrew machines.

_In time, it will also power the hardware pictured above._

_An initial demo is live on [JonSharp.net](https://jonsharp.net) now_

## Project Brief

 - 68000 emulation provided by [Moira](https://dirkwhoffmann.github.io/Moira/about.html)
 - 400x300 B/W Framebuffer/Display
   - "Text Display Adapter" - provides text-based graphics modes:
     - 80-column mode: Uses custom 5x13 font (80x23 chars)
     - 50-column mode: Uses IBM CGA font (50x33 chars)
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
"BUILD_WEB" environment variable. (Emscripten must be installed and in the
shell's PATH.

> BUILD_WEB=true zig build

Emscripten will compile pcd68-cpp, placing the output in ```zig-out/web```.
A convenient python script is provided for testing:

> python3 ./src/emscripten/serve2.py

## TODO / Issues

 - UART (Based on Zilog SCC? Another UART? How closely conforming?)
 - 68k software libraries/routines for graphics/UI/input processing?

## E-Ink emulation

(In progress) E-Ink emulation is now on by default and can be turned off like:

> ./zig-out/bin/pcd68 text_demo.bin -nf

