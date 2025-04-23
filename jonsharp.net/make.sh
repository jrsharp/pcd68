#!/bin/bash -xe

m68k-elf-g++ -O0 -s -g -o pcd68home pcd68home.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -mpcrel -T pcd68.lds
m68k-elf-objcopy -O binary pcd68home program.bin
m68k-elf-objcopy -O ihex pcd68home program.hex

m68k-elf-g++ -O0 -s -g -o pcd68uart pcd68uart.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -mpcrel -T pcd68.lds
m68k-elf-objcopy -O binary pcd68uart uart.bin
m68k-elf-objcopy -O ihex pcd68uart uart.hex

m68k-elf-g++ -O0 -s -g -o pcd68ud pcd68uart_debug.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -mpcrel -T pcd68.lds
m68k-elf-objcopy -O binary pcd68ud ud.bin
m68k-elf-objcopy -O ihex pcd68ud ud.hex
