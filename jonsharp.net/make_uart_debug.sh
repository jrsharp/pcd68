#!/bin/bash -xe

# Build the debug version of the UART test program

# Check for m68k toolchain
if command -v m68k-elf-rosco-gcc >/dev/null 2>&1; then
    # Using rosco-m68k toolchain
    m68k-elf-rosco-gcc -O0 -s -g -o pcd68uart_debug jonsharp.net/pcd68uart_debug.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -mpcrel -T jonsharp.net/pcd68.lds
    m68k-elf-rosco-objcopy -O binary pcd68uart_debug pcd68uart_debug.bin
    m68k-elf-rosco-objcopy -O ihex pcd68uart_debug pcd68uart_debug.hex
elif command -v m68k-elf-gcc >/dev/null 2>&1; then
    # Using standard m68k-elf toolchain
    m68k-elf-gcc -O0 -s -g -o pcd68uart_debug jonsharp.net/pcd68uart_debug.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -mpcrel -T jonsharp.net/pcd68.lds
    m68k-elf-objcopy -O binary pcd68uart_debug pcd68uart_debug.bin
    m68k-elf-objcopy -O ihex pcd68uart_debug pcd68uart_debug.hex
elif command -v m68k-unknown-elf-gcc >/dev/null 2>&1; then
    # Using m68k-unknown-elf toolchain
    m68k-unknown-elf-gcc -O0 -s -g -o pcd68uart_debug jonsharp.net/pcd68uart_debug.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -mpcrel -T jonsharp.net/pcd68.lds
    m68k-unknown-elf-objcopy -O binary pcd68uart_debug pcd68uart_debug.bin
    m68k-unknown-elf-objcopy -O ihex pcd68uart_debug pcd68uart_debug.hex
else
    echo "Error: m68k toolchain not found. Please install m68k-elf-gcc or m68k-unknown-elf-gcc."
    exit 1
fi

# Make the script executable
chmod +x ./pcd68uart_debug

# Save the current directory to return to it later
CURRENT_DIR=$(pwd)

echo "Build complete. Run the debug version with:"
echo "$CURRENT_DIR/zig-out/bin/pcd68 $CURRENT_DIR/jonsharp.net/pcd68uart_debug.bin"

# Check for existing processes using the UART ports
UART1_PORT=8080
UART2_PORT=8081
for PORT in $UART1_PORT $UART2_PORT; do
  PIDS=$(lsof -i :$PORT -sTCP:LISTEN -t 2>/dev/null)
  if [ -n "$PIDS" ]; then
    echo "Killing processes using port $PORT: $PIDS"
    echo $PIDS | xargs kill -9 2>/dev/null
  fi
done
sleep 1

# Start the UART server in the background
echo "Starting dual UART websocket server..."
# Use the dual_uart_server.py script from the current directory
python3 "$CURRENT_DIR/dual_uart_server.py" --uart1 $UART1_PORT --uart2 $UART2_PORT &
SERVER_PID=$!

# Wait briefly to check if server started successfully
sleep 2
if ! ps -p $SERVER_PID > /dev/null; then
  echo "WARNING: UART server failed to start. Running in loopback mode only."
  echo "You can still test using loopback mode by pressing '1' or '2' in the program."
fi

# Function to clean up on exit
cleanup() {
  if [ -n "$SERVER_PID" ]; then
    echo "Stopping UART server..."
    kill $SERVER_PID 2>/dev/null || true
  fi
  # Return to the original directory before exiting
  cd "$CURRENT_DIR" 2>/dev/null || true
  exit 0
}

# Set up trap for clean exit
trap cleanup INT TERM EXIT

echo "Starting PCD-68 emulator with UART test program (debug version)..."
echo "Diagnostic features:"
echo "- Text at top of screen shows if TDA is working"
echo "- Status line shows activity tick and interrupt indicators"
echo "- Press 1 to toggle UART1 loopback mode"
echo "- Press 2 to toggle UART2 loopback mode"
echo "- Press 3 to display UART register contents"
echo ""

# Run the emulator with absolute paths
"$CURRENT_DIR/zig-out/bin/pcd68" "$CURRENT_DIR/jonsharp.net/pcd68uart_debug.bin"

# Cleanup will be handled by trap 