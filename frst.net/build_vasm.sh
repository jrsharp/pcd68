#!/bin/sh
# Build vasm assembler for m68k on OpenBSD

VASM_DIR="/tmp/vasm"
VASM_BIN="$HOME/bin/vasm68k_mot"

# Create bin directory if it doesn't exist
mkdir -p "$HOME/bin"

# Check if vasm is already built
if [ -f "$VASM_BIN" ]; then
    echo "vasm68k_mot already exists at $VASM_BIN"
    exit 0
fi

echo "Building vasm for m68k with Motorola syntax..."

# Download and extract vasm if needed
if [ ! -d "$VASM_DIR" ]; then
    echo "Downloading vasm..."
    cd /tmp
    ftp -o vasm.tar.gz http://sun.hasenbraten.de/vasm/release/vasm.tar.gz || exit 1
    tar -xzf vasm.tar.gz || exit 1
fi

cd "$VASM_DIR" || exit 1

# Compile all required object files
echo "Compiling vasm components..."

CC_FLAGS="-I. -Icpus/m68k -Isyntax/mot -DUNIX -DOUTAOUT -DOUTBIN -DOUTCDEF -DOUTELF -DOUTGST -DOUTHANS -DOUTHUNK -DOUTIHEX -DOUTO65 -DOUTPAP -DOUTSREC -DOUTTEST -DOUTTOS -DOUTVOBJ -DOUTWOZ -DOUTXFIL"

# Main components
cc $CC_FLAGS -c vasm.c -o vasm.o || exit 1
cc $CC_FLAGS -c atom.c -o atom.o || exit 1
cc $CC_FLAGS -c expr.c -o expr.o || exit 1
cc $CC_FLAGS -c symtab.c -o symtab.o || exit 1
cc $CC_FLAGS -c symbol.c -o symbol.o || exit 1
cc $CC_FLAGS -c error.c -o error.o || exit 1
cc $CC_FLAGS -c parse.c -o parse.o || exit 1
cc $CC_FLAGS -c reloc.c -o reloc.o || exit 1
cc $CC_FLAGS -c hugeint.c -o hugeint.o || exit 1
cc $CC_FLAGS -c cond.c -o cond.o || exit 1
cc $CC_FLAGS -c listing.c -o listing.o || exit 1
cc $CC_FLAGS -c source.c -o source.o || exit 1
cc $CC_FLAGS -c supp.c -o supp.o || exit 1
cc $CC_FLAGS -c dwarf.c -o dwarf.o || exit 1
cc $CC_FLAGS -c osdep.c -o osdep.o || exit 1

# CPU-specific
cc $CC_FLAGS -c cpus/m68k/cpu.c -o cpu.o || exit 1

# Syntax-specific
cc $CC_FLAGS -c syntax/mot/syntax.c -o syntax.o || exit 1

# Output formats
cc $CC_FLAGS -c output_aout.c -o output_aout.o || exit 1
cc $CC_FLAGS -c output_bin.c -o output_bin.o || exit 1
cc $CC_FLAGS -c output_cdef.c -o output_cdef.o || exit 1
cc $CC_FLAGS -c output_elf.c -o output_elf.o || exit 1
cc $CC_FLAGS -c output_gst.c -o output_gst.o || exit 1
cc $CC_FLAGS -c output_hans.c -o output_hans.o || exit 1
cc $CC_FLAGS -c output_hunk.c -o output_hunk.o || exit 1
cc $CC_FLAGS -c output_ihex.c -o output_ihex.o || exit 1
cc $CC_FLAGS -c output_o65.c -o output_o65.o || exit 1
cc $CC_FLAGS -c output_pap.c -o output_pap.o || exit 1
cc $CC_FLAGS -c output_srec.c -o output_srec.o || exit 1
cc $CC_FLAGS -c output_test.c -o output_test.o || exit 1
cc $CC_FLAGS -c output_tos.c -o output_tos.o || exit 1
cc $CC_FLAGS -c output_vobj.c -o output_vobj.o || exit 1
cc $CC_FLAGS -c output_woz.c -o output_woz.o || exit 1
cc $CC_FLAGS -c output_xfile.c -o output_xfile.o || exit 1

# Link everything
echo "Linking vasm..."
cc -o vasm68k_mot vasm.o atom.o expr.o symtab.o symbol.o error.o parse.o \
   reloc.o hugeint.o cond.o listing.o source.o supp.o dwarf.o osdep.o \
   cpu.o syntax.o \
   output_aout.o output_bin.o output_cdef.o output_elf.o output_gst.o \
   output_hans.o output_hunk.o output_ihex.o output_o65.o output_pap.o \
   output_srec.o output_test.o output_tos.o output_vobj.o output_woz.o \
   output_xfile.o || exit 1

# Install to user's bin directory
echo "Installing to $VASM_BIN..."
cp vasm68k_mot "$VASM_BIN" || exit 1
chmod +x "$VASM_BIN" || exit 1

echo "vasm successfully built and installed to $VASM_BIN"
echo "Add $HOME/bin to your PATH if it's not already there."