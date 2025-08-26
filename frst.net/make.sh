#!/bin/sh

# Build the ROM using vasm for OpenBSD
echo "Building FRST.net ROM with vasm..."

# Check if vasm is available
VASM_BIN="$HOME/bin/vasm68k_mot"
if [ ! -f "$VASM_BIN" ]; then
    echo "Building vasm assembler first..."
    ./build_vasm.sh
    if [ $? -ne 0 ]; then
        echo "Failed to build vasm. Exiting."
        exit 1
    fi
fi

# Build the ROM using our unified build file
echo "Assembling ROM..."
$VASM_BIN -Fhunkexe build_rom.s -o frst_net.exe
if [ $? -eq 0 ]; then
    echo "ROM executable created: frst_net.exe"
    ls -la frst_net.exe
else
    echo "Assembly failed. Check output above for errors."
    exit 1
fi

# Generate Intel HEX format as well
echo "Creating Intel HEX format..."
$VASM_BIN -Fihex -x build_rom.s -o frst_net.hex
if [ $? -eq 0 ]; then
    echo "Intel HEX ROM created: frst_net.hex"
    ls -la frst_net.hex
fi

echo "Build completed successfully"

