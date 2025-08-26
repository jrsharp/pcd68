#!/bin/bash -xe

# Check for m68k toolchain
if command -v m68k-elf-rosco-gcc >/dev/null 2>&1; then
    # Using rosco-m68k toolchain
    m68k-elf-rosco-gcc -O0 -s -g -o pcd68uart pcd68uart.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -mpcrel -T pcd68.lds
    m68k-elf-rosco-objcopy -O binary pcd68uart pcd68uart.bin
    m68k-elf-rosco-objcopy -O ihex pcd68uart pcd68uart.hex
elif command -v m68k-elf-gcc >/dev/null 2>&1; then
    # Using standard m68k-elf toolchain
    m68k-elf-gcc -O0 -s -g -o pcd68uart pcd68uart.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -mpcrel -T pcd68.lds
    m68k-elf-objcopy -O binary pcd68uart pcd68uart.bin
    m68k-elf-objcopy -O ihex pcd68uart pcd68uart.hex
elif command -v m68k-unknown-elf-gcc >/dev/null 2>&1; then
    # Using m68k-unknown-elf toolchain
    m68k-unknown-elf-gcc -O0 -s -g -o pcd68uart pcd68uart.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -mpcrel -T pcd68.lds
    m68k-unknown-elf-objcopy -O binary pcd68uart pcd68uart.bin
    m68k-unknown-elf-objcopy -O ihex pcd68uart pcd68uart.hex
else
    echo "Error: m68k toolchain not found. Please install m68k-elf-gcc or m68k-unknown-elf-gcc."
    exit 1
fi

# Make the script executable
chmod +x ./pcd68uart

echo "Build complete. Use pcd68uart.bin with the emulator." 