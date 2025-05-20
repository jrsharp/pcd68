#!/bin/bash -xe

# Compile with real error checking - removed -mpcrel flag and added utility_functions.S
m68k-elf-g++ -O0 -s -g -o pcd68home pcd68home.S utility_functions.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -T pcd68.lds

# Generate the binary files
m68k-elf-objcopy -O binary pcd68home program.bin
m68k-elf-objcopy -O ihex pcd68home program.hex

echo "Build completed successfully"

m68k-elf-g++ -O0 -s -g -o pcd68uart pcd68uart.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -T pcd68.lds
m68k-elf-objcopy -O binary pcd68uart uart.bin
m68k-elf-objcopy -O ihex pcd68uart uart.hex

m68k-elf-g++ -O0 -s -g -o kbdtest kbd_report_test.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -T pcd68.lds
m68k-elf-objcopy -O binary kbdtest kbdtest.bin
m68k-elf-objcopy -O ihex kbdtest kbdtest.hex

#m68k-elf-g++ -O0 -s -g -o pcd68ud pcd68uart_debug.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -mpcrel -T pcd68.lds
#m68k-elf-objcopy -O binary pcd68ud ud.bin
#m68k-elf-objcopy -O ihex pcd68ud ud.hex
