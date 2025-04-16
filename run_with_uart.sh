#!/bin/bash
# Script to run the PCD-68 emulator with dual UART websocket server

# Ensure script exits on error
set -e

# Check for python3 and websockets
command -v python3 >/dev/null 2>&1 || { echo "Python 3 is required but not installed. Aborting."; exit 1; }
python3 -c "import websockets" >/dev/null 2>&1 || { echo "Python websockets module is required. Please install with: pip install websockets"; exit 1; }

# Default UART ports
UART1_PORT=8080
UART2_PORT=8081

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --uart1)
      UART1_PORT="$2"
      shift 2
      ;;
    --uart2)
      UART2_PORT="$2"
      shift 2
      ;;
    --binary|-b)
      BINARY="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --uart1 PORT     Set port for UART1 (default: 8080)"
      echo "  --uart2 PORT     Set port for UART2 (default: 8081)"
      echo "  --binary|-b FILE Set binary file to load (default: uart_test.bin)"
      echo "  --help|-h        Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set default binary if not specified
if [ -z "$BINARY" ]; then
  BINARY="uart_test.bin"
fi

# Check if binary file exists
if [ ! -f "$BINARY" ]; then
  echo "Binary file not found: $BINARY"
  exit 1
fi

# Start the UART server in the background
echo "Starting dual UART websocket server..."
python3 dual_uart_server.py --uart1 $UART1_PORT --uart2 $UART2_PORT &
SERVER_PID=$!

# Function to clean up on exit
cleanup() {
  echo "Stopping UART server..."
  kill $SERVER_PID 2>/dev/null || true
  exit 0
}

# Set up trap for clean exit
trap cleanup INT TERM EXIT

# Wait for server to start
sleep 1

# Print connection instructions
echo "UART server started!"
echo "Connect to UART1: ws://localhost:$UART1_PORT"
echo "Connect to UART2: ws://localhost:$UART2_PORT"
echo "You can use a WebSocket client like 'websocat' or browser-based tools"
echo

# Run the emulator
echo "Starting PCD-68 emulator with $BINARY..."
./build/pcd68 --binary "$BINARY"

# Note: cleanup will be called automatically via the trap 
