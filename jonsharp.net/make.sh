#!/bin/bash -xe

# Create tools directory if it doesn't exist
mkdir -p tools/output

# Compile the C-based md2asm tool if needed
if [ ! -f tools/md2asm ] || [ tools/md2asm.c -nt tools/md2asm ]; then
    echo "Building md2asm tool..."
    gcc -o tools/md2asm tools/md2asm.c
fi

# Generate menu structures from markdown files
echo "Generating menu structures from markdown files..."
if ./tools/md2asm content > tools/output/menu_structures.S; then
    echo "Menu structures generated successfully"
    MENU_DEFINE="tools/output/menu_structures.S"
else
    echo "Error: Failed to generate menu structures"
    echo "Make sure content directory exists with .md files"
    exit 1
fi

# Build the ROM with generated menu structures
echo "Building ROM with generated content..."
m68k-elf-g++ -O0 -s -g -o pcd68home pcd68home.S utility_functions.S $MENU_DEFINE -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -T pcd68.lds

# Generate the binary files
m68k-elf-objcopy -O binary pcd68home program.bin
m68k-elf-objcopy -O ihex pcd68home program.hex

echo "Build completed successfully"

