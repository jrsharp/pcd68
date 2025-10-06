# PCD-68 Motorola 68000 Emulator Test Suite

Automated test suite for the PCD-68 68000 CPU emulator using Zephyr's ztest framework.

## Overview

This test suite validates the cached runtime dispatch system implementation of the Motorola 68000 emulator. Tests run on QEMU emulating an ARM Cortex-M33 processor (MPS3 AN547 board).

## Test Coverage (104 Total Test Cases)

### Basic Sanity Tests (`test_basic_sanity.cpp`) - 4 tests
- Memory allocation verification
- Reset vector functionality
- Register access (data and address registers)
- NOP instruction execution

### CPU Basic Tests (`test_cpu_basic.cpp`) - 4 tests
- CPU initialization and reset
- NOP instruction execution
- Multiple NOP sequences
- Opcode cache functionality

### MOVE Instructions (`test_move.cpp`) - 9 tests
- MOVEQ (quick immediate moves)
- MOVE with various data sizes (byte, word, long)
- MOVEA (address register moves)
- Immediate addressing mode
- Flag setting behavior

### Arithmetic Instructions (`test_arithmetic.cpp`) - 11 tests
- ADD/SUB (register-to-register, word and long)
- ADDQ/SUBQ (quick arithmetic)
- ADDA/SUBA (address register arithmetic, word and long)
- CMP (compare)

### Logical Instructions (`test_logical.cpp`) - 13 tests
- AND/OR operations (register and immediate)
- TST (test operand - zero, negative, positive)
- CLR (clear operand)
- ASL/ASR (arithmetic shifts - immediate and register)
- LSL/LSR (logical shifts - immediate and register)

### Branch and Control Flow (`test_branches.cpp`) - 10 tests
- BRA (unconditional branch)
- BEQ/BNE (conditional branches - taken and not taken)
- BHI/BLS (unsigned conditional branches)
- JMP (absolute jump)
- JSR/RTS (subroutine calls with stack)
- LEA (load effective address - absolute and PC-relative)

### Addressing Modes (`test_addressing_modes.cpp`) - 10 tests
- Address register indirect: (An)
- Post-increment: (An)+
- Pre-decrement: -(An)
- Displacement: (d16,An)
- Absolute short: (xxx).W
- Absolute long: (xxx).L
- PC-relative: (d16,PC)
- Immediate: #data
- Write to memory modes
- Stack operations with addressing modes

### Comparison Tests (`test_compare.cpp`) - 10 tests
- CMP (equal, greater, less)
- CMPI (immediate comparison)
- CMPA (address register comparison)
- TST (zero, negative, positive)
- Byte, word, and long comparisons

### Multiply/Divide (`test_mul_div.cpp`) - 11 tests
- MULU (unsigned multiply - simple, large, immediate)
- MULS (signed multiply - positive, negative, both negative)
- DIVU (unsigned divide - simple, with remainder)
- DIVS (signed divide - positive, negative dividend)

### Bit Operations (`test_bit_ops.cpp`) - 10 tests
- BTST (test bit - set and clear, register and immediate)
- BSET (set bit - register and immediate)
- BCLR (clear bit - register and immediate)
- BCHG (toggle bit - register and immediate)
- Operations on high bits (bit 31)

### Stack and Misc (`test_stack_misc.cpp`) - 12 tests
- PEA (push effective address)
- LINK/UNLK (stack frame management)
- EXT (sign extension - byte to word, word to long, positive values)
- SWAP (swap register halves)
- NOT (logical complement)
- NEG/NEGX (two's complement negation)
- EXG (exchange registers - data and address)
- MOVEM (move multiple registers - to/from memory)

## Building and Running

### Prerequisites
- Zephyr SDK installed and configured
- QEMU with ARM support
- West build tool

### Quick Start
```bash
cd test-pcd68-zephyr
./build_and_test.sh
```

### Manual Build
```bash
# Build for QEMU Cortex-M33
west build -b mps3/an547

# Run tests on QEMU
west build -t run
```

### Clean Build
```bash
./build_and_test.sh clean
```

## Configuration

- **Board**: `mps3/an547` (ARM Cortex-M33)
- **Stack Size**: 8KB (main and test threads)
- **Heap Size**: 16KB
- **CPU Emulator RAM**: 64KB per test
- **Opcode Cache**: 128 entries (1.28KB)

## Test Memory Layout

Each test uses a `TestMemory` class that provides:
- 64KB of emulated 68000 RAM
- Big-endian memory access (as per 68000 architecture)
- Reset vector at address 0x0000
- Initial SP at 0x1000
- Initial PC at 0x0400

## Implementation Details

The test suite validates the **cached runtime dispatch** approach:
- 128-entry direct-mapped opcode cache
- Cache hits execute at table lookup speed
- Cache misses trigger runtime decode and cache update
- Expected cache hit rate: 90%+

### Dispatch Configuration
- `USE_MINIMAL_DISPATCH=1`: Enables runtime decode with caching
- `USE_ZEPHYR=1`: Zephyr-specific configuration

## Memory Usage

Typical memory footprint on ARM Cortex-M33:
- **Flash**: ~140KB (6.5% of 2MB)
- **RAM**: ~44KB (5.7% of 760KB)
  - Opcode cache: 1.28KB
  - Test memory: 64KB per test instance
  - Stack: 8KB
  - Heap: 16KB

## Adding New Tests

1. Create a new test file in `src/` (e.g., `test_myfeature.cpp`)
2. Add to `CMakeLists.txt`:
   ```cmake
   target_sources(app PRIVATE
       src/test_myfeature.cpp
   )
   ```
3. Use the `TestMemory` helper class for memory access
4. Follow the existing test patterns:
   ```cpp
   ZTEST(test_suite_name, test_case_name)
   {
       TestMemory cpu;
       cpu.write_long(0, 0x00001000);  // SP
       cpu.write_long(4, 0x00000400);  // PC
       cpu.reset();

       // Write opcodes and test...
   }
   ```

## Troubleshooting

### Build Fails
- Ensure Zephyr SDK is properly sourced
- Check that `west` can find the Zephyr base
- Verify `USE_MINIMAL_DISPATCH=1` is set in CMakeLists.txt

### Tests Timeout on QEMU
- Increase timeout in prj.conf if needed
- Check for infinite loops in emulator code
- Verify test opcodes are correct

### Cache Misses
- Monitor cache hit rate in real applications
- Adjust `OPCODE_CACHE_SIZE` if needed (power of 2)
- Consider cache statistics instrumentation for debugging

## References

- Zephyr Testing: https://docs.zephyrproject.org/latest/develop/test/ztest.html
- Moira 68000 Emulator: https://github.com/dirkwhoffmann/Moira
- M68000 Programmer's Reference Manual: Motorola, Inc.
