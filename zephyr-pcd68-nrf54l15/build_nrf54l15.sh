#!/bin/bash
# Build script for PCD68 nRF54L15 project

set -e

echo "Building PCD68 for nRF54L15-DK..."

# Check if we're in the right directory
if [ ! -f "CMakeLists.txt" ]; then
    echo "Error: Run this script from the zephyr-pcd68-nrf54l15 directory"
    exit 1
fi

# Activate local Python virtual environment
if [ -d ".venv" ]; then
    echo "Activating local Python virtual environment..."
    source .venv/bin/activate
fi

# Set up NCS environment
export NCS_ROOT=/home/jrsharp/ncs/v3.0.2
export ZEPHYR_BASE=$NCS_ROOT/zephyr

# Add toolchain to PATH if needed
if [ -d "/mnt2/zephyr-sdk/zephyr-sdk-0.17.0" ]; then
    export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
    export ZEPHYR_SDK_INSTALL_DIR=/mnt2/zephyr-sdk/zephyr-sdk-0.17.0
fi

echo "Using NCS at: $NCS_ROOT"
echo "Using Zephyr at: $ZEPHYR_BASE"

# Clean previous build
if [ -d "build" ]; then
    echo "Cleaning previous build..."
    rm -rf build
fi

# Build with west from proper NCS workspace
echo "Building with west from NCS workspace..."
cd $NCS_ROOT
west build -s $(realpath $OLDPWD) -b nrf54l15dk/nrf54l15/cpuapp --build-dir $(realpath $OLDPWD)/build
cd $OLDPWD

# Check build size
if [ -f "build/zephyr/zephyr.elf" ]; then
    echo ""
    echo "Build successful!"
    echo ""
    echo "=== Binary Size Information ==="
    arm-zephyr-eabi-size build/zephyr/zephyr.elf

    echo ""
    echo "=== Flash Usage ==="
    FLASH_SIZE=$(arm-zephyr-eabi-size build/zephyr/zephyr.elf | tail -1 | awk '{print $1+$2}')
    AVAILABLE_FLASH=$((1400 * 1024))  # 1400KB partition
    FLASH_PERCENT=$((FLASH_SIZE * 100 / AVAILABLE_FLASH))

    echo "Flash used: ${FLASH_SIZE} bytes (${FLASH_PERCENT}% of 1400KB)"

    if [ $FLASH_SIZE -gt $AVAILABLE_FLASH ]; then
        echo "WARNING: Flash usage exceeds partition size!"
        exit 1
    else
        echo "Flash usage OK - $(($AVAILABLE_FLASH - $FLASH_SIZE)) bytes remaining"
    fi

    echo ""
    echo "To flash: nrfutil device program --firmware build/zephyr/zephyr.hex"
    echo "Or manually copy build/zephyr/zephyr.hex to the device"
else
    echo "Build failed!"
    exit 1
fi