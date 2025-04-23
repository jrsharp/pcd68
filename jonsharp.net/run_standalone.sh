#!/bin/bash
# Simple script to run the PCD-68 emulator with the UART test program
BINARY="pcd68uart.bin"
(cd .. && ./build/pcd68 --binary "jonsharp.net/$BINARY")
