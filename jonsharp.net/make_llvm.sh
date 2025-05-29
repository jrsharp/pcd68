#!/bin/bash -xe

#zig c++ -O0 -march=m68k -s -g -o pcd68home keyboard.c pcd68home.S welcome.h -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -mpcrel -T pcd68.lds

clang++  -target m68k-none-eabi -mcpu=M68000 -o pcd68home.o -c pcd68home.cpp
m68k-unknown-elf-ld pcd68home.o -T pcd68.lds

#m68k-unknown-elf-objcopy -O binary pcd68home program.bin
#m68k-unknown-elf-objcopy -O ihex pcd68home program.hex
