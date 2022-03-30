PCD-68
======

PCD-68 is a virtual retro computer -- that is, it is a new computer personal 
computer specification implemented in software that emulates real hardware from
the past.  It resembles familiar real hardware from the late 80s/early 90s,
as it draws inspiration from the original Macintosh and Canon Cat, as well as
more modern 68k-based homebrew machines.

## Project Brief

 - 68000 emulation provided by Moira
 - 400x300 B/W Framebuffer/Display
   - Using custom 5x13 font, yields text video mode measuring 80x23 chars
 - 4MB RAM
 - 64k ROM
 - Dual UART (Zilog SCC?)
 - Keyboard I/O

## Zig

 - Selected for convenient and flexible target selection

## TODO / Issues

 - Keyboard input
 - UART
 - Graphics library for WASM: SDL2 will work if targetting Emscripten, but if we want to use native Zig WASM target(s), we will need another solution
   - Maybe just use it as a test case for 'zig build' to invoke entirely external toolchain (emcc,etc.)
   - Worry about native Zig toolchain / graphics later?


