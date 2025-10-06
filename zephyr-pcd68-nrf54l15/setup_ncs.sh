#!/bin/bash
# Setup nRF Connect SDK for PCD68 nRF54L15 project

set -e

echo "Setting up nRF Connect SDK environment for PCD68..."

# Check if we're in the right directory
if [ ! -f "CMakeLists.txt" ]; then
    echo "Error: Run this script from the zephyr-pcd68-nrf54l15 directory"
    exit 1
fi

# Create Python virtual environment for NCS
if [ ! -d ".venv-ncs" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv .venv-ncs
fi

# Activate virtual environment
source .venv-ncs/bin/activate

# Install west
echo "Installing west..."
pip3 install west

# Initialize west workspace
if [ ! -d ".west" ]; then
    echo "Initializing west workspace..."
    west init -l .
    west update
fi

echo ""
echo "NCS environment setup complete!"
echo ""
echo "To use:"
echo "  source .venv-ncs/bin/activate"
echo "  ./build_nrf54l15.sh"