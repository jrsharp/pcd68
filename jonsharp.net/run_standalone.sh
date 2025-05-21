#!/bin/bash
# Simple script to run the PCD-68 emulator with the program.bin file
BINARY="program.bin"
(cd .. && ./zig-out/bin/pcd68 "jonsharp.net/$BINARY")
