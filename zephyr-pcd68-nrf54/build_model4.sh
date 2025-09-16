#!/bin/bash
#
# Build script for PCD68 Model 4 CyberTerminal (nRF54H20)
#

set -e

echo "Building PCD68 Model 4 CyberTerminal firmware..."
echo "Target: nRF54H20-DK with NCS 3.1.0"
echo "========================================="

# Activate virtual environment
if [ -f "../.venv-ncs/bin/activate" ]; then
    echo "Activating NCS virtual environment..."
    source ../.venv-ncs/bin/activate
fi

# Set environment variables for NCS
export ZEPHYR_BASE=$(readlink -f ../zephyr)
export ZEPHYR_SDK_INSTALL_DIR=/mnt2/zephyr-sdk/zephyr-sdk-0.17.0

echo "Using Zephyr: $ZEPHYR_BASE"

# Check for cmake and ninja
if ! command -v cmake &> /dev/null; then
    echo "Error: cmake not found. Please install cmake."
    exit 1
fi

if ! command -v ninja &> /dev/null; then
    echo "Error: ninja not found. Please install ninja-build."
    exit 1
fi

# Clean previous build
echo "Cleaning previous build..."
rm -rf build/

# Build directly with cmake instead of west
echo "Building firmware for nRF54H20-DK (application core)..."
mkdir -p build
cd build

cmake -GNinja \
    -DBOARD=nrf54h20dk/nrf54h20/cpuapp \
    -DCONF_FILE=prj.conf \
    -DZEPHYR_BASE=$ZEPHYR_BASE \
    -DNRF_DIR=$(readlink -f ../../nrf) \
    ..

ninja -v

echo ""
echo "========================================="
echo "Build completed successfully!"
echo ""
echo "Firmware binary: build/zephyr/zephyr.hex"
echo "To flash: west flash"
echo "To monitor: west espmon --port /dev/ttyACM0"
echo ""
echo "Hardware connections for ST7796S display (4\" 480x320):"
echo "  SCK:  P0.08 (nRF54H20-DK pin available)"
echo "  MOSI: P0.09 (nRF54H20-DK pin available)" 
echo "  MISO: P0.10 (nRF54H20-DK pin available)"
echo "  CS:   P0.11 (nRF54H20-DK pin available)"
echo "  DC:   P1.08 (nRF54H20-DK pin available)"
echo "  RST:  P1.06 (nRF54H20-DK pin available)"
echo ""
echo "Pair any Bluetooth HID keyboard to use!"
echo "========================================="