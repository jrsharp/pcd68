#!/bin/sh
# Cross-compile PCD68 for PowerPC on OpenBSD amd64
# Requires powerpc cross-compiler

set -e

echo "PCD68 PowerPC Cross-Compilation Build"
echo "======================================"
echo ""

# First, check if we need to install the cross-compiler
if ! command -v powerpc-linux-gnu-gcc >/dev/null 2>&1; then
    echo "PowerPC cross-compiler not found!"
    echo ""
    echo "To install on OpenBSD, you have a few options:"
    echo ""
    echo "Option 1: Build cross-compiler from source using binutils/gcc"
    echo "  This is complex but gives you full control"
    echo ""
    echo "Option 2: Use clang with PowerPC target (if available)"
    echo "  clang -target powerpc-unknown-openbsd"
    echo ""
    echo "Option 3: Install Linux cross-compiler in a chroot"
    echo "  Or use a Linux VM/Docker container"
    echo ""
    echo "For now, let's try using clang..."
    echo ""

    # Try clang
    if command -v clang >/dev/null 2>&1; then
        CC="clang -target powerpc-unknown-elf"
        CXX="clang++ -target powerpc-unknown-elf"
        echo "Found clang - will attempt PowerPC cross-compilation"
    else
        echo "Error: No suitable compiler found"
        echo "Please install clang: pkg_add clang"
        exit 1
    fi
else
    CC="powerpc-linux-gnu-gcc"
    CXX="powerpc-linux-gnu-g++"
    echo "Found PowerPC cross-compiler"
fi

# For now, let's use clang if available
if command -v clang >/dev/null 2>&1; then
    echo "Using clang for cross-compilation..."
    CC="clang"
    CXX="clang++"
    TARGET_FLAGS="-target powerpc-unknown-elf -mcpu=7450"
    AS="clang"
    LD="ld.lld"
    OBJCOPY="llvm-objcopy"
else
    echo "Clang not found - please install it:"
    echo "  doas pkg_add clang"
    exit 1
fi

# Compiler flags
ARCH_FLAGS="$TARGET_FLAGS"
FREESTANDING="-ffreestanding -nostdlib -nostartfiles -nodefaultlibs -fno-builtin"
CXX_FLAGS="-fno-exceptions -fno-rtti -fno-threadsafe-statics -std=c++11"
OPT_FLAGS="-O2 -g"
DEFINES="-DMOIRA_NO_THROW -DFREESTANDING -D__powerpc__"
INCLUDES="-I./src -I./src/Moira"

echo "Compiler: $CXX"
echo "Target: PowerPC (32-bit big-endian)"
echo "CPU: PowerPC G4 7450"
echo ""

# Clean
echo "Cleaning..."
rm -f src/*.o src/Moira/*.o pcd68.elf pcd68.bin *.o

# Compile sources
echo "Compiling sources..."

compile_cpp() {
    src=$1
    obj="${src%.cpp}.o"
    echo "  $src -> $obj"
    $CXX $ARCH_FLAGS $FREESTANDING $CXX_FLAGS $OPT_FLAGS $DEFINES $INCLUDES \
        -c "$src" -o "$obj" || return 1
}

# Compile each source file
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
    compile_cpp "$cpp" || {
        echo "Compilation failed!"
        exit 1
    }
done

# Create startup assembly
echo "Creating startup code..."
cat > start_ppc.s <<'EOF'
    .text
    .globl _start
    .type _start, @function
_start:
    # Entry from OF: r3 = client interface
    mr      31, 3          # Save OF pointer

    # Set up initial stack if needed
    # OF should have already set this up

    # Clear BSS
    lis     4, __bss_start@ha
    addi    4, 4, __bss_start@l
    lis     5, __bss_end@ha
    addi    5, 5, __bss_end@l
    li      6, 0
.Lclear_bss:
    cmplw   4, 5
    bge     .Lbss_done
    stw     6, 0(4)
    addi    4, 4, 4
    b       .Lclear_bss
.Lbss_done:

    # Call main
    mr      3, 31
    bl      pcd68_start

    # Return to OF
    blr

    .size _start, .-_start

    .section .bss
    .globl __bss_start
    .globl __bss_end
__bss_start:
    .space 4
__bss_end:
EOF

echo "Assembling startup..."
$AS $TARGET_FLAGS -c start_ppc.s -o start.o || {
    echo "Assembly failed!"
    exit 1
}

# Create linker script
echo "Creating linker script..."
cat > ppc.ld <<'EOF'
OUTPUT_FORMAT("elf32-powerpc", "elf32-powerpc", "elf32-powerpc")
OUTPUT_ARCH(powerpc:common)
ENTRY(_start)

SECTIONS
{
    . = 0x100000;

    .text : {
        *(.text.startup)
        *(.text .text.*)
        *(.rodata .rodata.*)
    }

    . = ALIGN(4);
    .data : {
        *(.data .data.*)
        *(.sdata .sdata.*)
    }

    . = ALIGN(4);
    .bss : {
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    }

    /DISCARD/ : {
        *(.comment)
        *(.note.*)
        *(.eh_frame*)
    }
}
EOF

# Link
echo "Linking..."
OBJS=""
OBJS="$OBJS start.o"
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

$LD -T ppc.ld -o pcd68.elf $OBJS || {
    echo "Linking failed!"
    echo "Trying with clang directly..."
    $CXX $ARCH_FLAGS $FREESTANDING -T ppc.ld -o pcd68.elf $OBJS
}

# Convert to binary
echo "Creating binary..."
if command -v llvm-objcopy >/dev/null 2>&1; then
    llvm-objcopy -O binary pcd68.elf pcd68.bin
elif command -v objcopy >/dev/null 2>&1; then
    objcopy -O binary pcd68.elf pcd68.bin
else
    echo "Warning: No objcopy found - ELF file only"
fi

# Show results
echo ""
echo "Build complete!"
echo "==============="
ls -lh pcd68.elf pcd68.bin 2>/dev/null || ls -lh pcd68.elf
echo ""
file pcd68.elf
echo ""
echo "Transfer to PowerBook and load in OF:"
echo "  boot hd:,\\pcd68.elf"