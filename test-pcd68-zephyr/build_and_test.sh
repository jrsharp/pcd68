#!/bin/bash
# Build and run PCD-68 emulator tests on QEMU Cortex-M33

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
BOARD="mps3/an547"

echo "========================================="
echo "PCD-68 Emulator Test Suite"
echo "Target: QEMU Cortex-M33 (${BOARD})"
echo "========================================="
echo

# Clean build directory if requested
if [ "$1" == "clean" ]; then
    echo "Cleaning build directory..."
    rm -rf "${BUILD_DIR}"
fi

# Build the test suite
echo "Building test suite..."
west build -b "${BOARD}" -d "${BUILD_DIR}" "${SCRIPT_DIR}"

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo
echo "Build successful!"
echo

# Run tests on QEMU
echo "Running tests on QEMU..."
echo "========================================="
west build -d "${BUILD_DIR}" -t run

echo
echo "========================================="
echo "Tests complete!"
