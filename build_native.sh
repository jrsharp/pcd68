#!/bin/sh
# Native build script for PCD68 on PowerBook G4
# Run this directly on your PowerBook running OpenBSD

set -e

echo "PCD68 Native Freestanding Build"
echo "==============================="

# Detect OS and set compiler
OS=$(uname)
case "$OS" in
    OpenBSD)
        CC="egcc"
        CXX="eg++"
        OBJCOPY="gobjcopy"
        echo "Detected OpenBSD - using egcc/eg++"
        ;;
    Darwin)
        CC="gcc"
        CXX="g++"
        OBJCOPY="objcopy"
        echo "Detected macOS - using gcc/g++"
        ;;
    Linux)
        CC="gcc"
        CXX="g++"
        OBJCOPY="objcopy"
        echo "Detected Linux - using gcc/g++"
        ;;
    *)
        echo "Unknown OS: $OS"
        exit 1
        ;;
esac

# Check for compiler
if ! command -v $CC >/dev/null 2>&1; then
    echo "Error: $CC not found!"
    echo "On OpenBSD: pkg_add gcc g++"
    exit 1
fi

# Compiler flags
ARCH_FLAGS="-mcpu=7450 -mtune=7450"
FREESTANDING="-ffreestanding -nostdlib -nostartfiles -nodefaultlibs -fno-builtin"
CXX_FLAGS="-fno-exceptions -fno-rtti -fno-threadsafe-statics"
OPT_FLAGS="-O2 -g"
DEFINES="-DMOIRA_NO_THROW -DFREESTANDING"
INCLUDES="-I./src -I./src/Moira"

echo "Compiler: $CXX"
echo "Architecture: PowerPC G4 7450"
echo ""

# Clean previous build
echo "Cleaning..."
rm -f src/*.o src/Moira/*.o pcd68.elf pcd68.bin

# Compile C++ files
echo "Compiling C++ sources..."
for cpp in \
    src/main_of_standalone.cpp \
    src/freestanding.cpp \
    src/openfirmware.cpp \
    src/PCD68_CPU.cpp \
    src/Screen.cpp \
    src/Screen_OF.cpp \
    src/KeyboardInput.cpp \
    src/KeyboardInputOF.cpp \
    src/KCTL.cpp \
    src/TDA.cpp \
    src/UART.cpp \
    src/Moira/Moira.cpp \
    src/Moira/MoiraDebugger.cpp
do
    obj="${cpp%.cpp}.o"
    echo "  $cpp -> $obj"
    $CXX $ARCH_FLAGS $FREESTANDING $CXX_FLAGS $OPT_FLAGS $DEFINES $INCLUDES \
        -c "$cpp" -o "$obj"
done

# Create startup code
echo "Creating startup code..."
cat > start.s <<'EOF'
    .section .text.startup
    .global _start
_start:
    # Entry from OF: r3 = client interface
    mr      31, 3          # Save OF pointer

    # Clear BSS (if needed)
    lis     4, __bss_start@ha
    addi    4, 4, __bss_start@l
    lis     5, __bss_end@ha
    addi    5, 5, __bss_end@l
    li      6, 0
1:  cmpw    4, 5
    bge     2f
    stw     6, 0(4)
    addi    4, 4, 4
    b       1b
2:
    # Call main
    mr      3, 31
    bl      pcd68_start

    # Return to OF
    blr

    .section .bss
    .global __bss_start
__bss_start:
    .space 4
    .global __bss_end
__bss_end:
EOF

echo "Assembling startup..."
$CC $ARCH_FLAGS -c start.s -o start.o

# Create linker script
echo "Creating linker script..."
cat > link.ld <<'EOF'
OUTPUT_FORMAT("elf32-powerpc")
OUTPUT_ARCH(powerpc)
ENTRY(_start)

SECTIONS {
    . = 0x100000;

    .text : {
        *(.text.startup)
        *(.text*)
        *(.rodata*)
    }

    .data : {
        *(.data*)
        *(.sdata*)
    }

    .bss : {
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        __bss_end = .;
    }

    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}
EOF

# Link
echo "Linking..."
OBJS="start.o"
OBJS="$OBJS src/main_of_standalone.o"
OBJS="$OBJS src/freestanding.o"
OBJS="$OBJS src/openfirmware.o"
OBJS="$OBJS src/PCD68_CPU.o"
OBJS="$OBJS src/Screen.o"
OBJS="$OBJS src/Screen_OF.o"
OBJS="$OBJS src/KeyboardInput.o"
OBJS="$OBJS src/KeyboardInputOF.o"
OBJS="$OBJS src/KCTL.o"
OBJS="$OBJS src/TDA.o"
OBJS="$OBJS src/UART.o"
OBJS="$OBJS src/Moira/Moira.o"
OBJS="$OBJS src/Moira/MoiraDebugger.o"

ld -T link.ld -o pcd68.elf $OBJS

# Convert to binary
echo "Creating binary..."
$OBJCOPY -O binary pcd68.elf pcd68.bin

# Show results
echo ""
echo "Build complete!"
echo "==============="
ls -lh pcd68.elf pcd68.bin
echo ""
file pcd68.elf
echo ""
echo "To test in Open Firmware:"
echo "  1. Copy pcd68.bin to a USB drive or partition"
echo "  2. Boot to OF (Cmd+Option+O+F)"
echo "  3. Type: boot ud:,\\pcd68.bin"
echo ""
echo "Or via network (TFTP):"
echo "  boot enet:192.168.1.100,pcd68.bin"