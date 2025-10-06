# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(pcd68_emulator_tests)

# Add PCD-68 emulator source files
target_sources(app PRIVATE
    # Moira CPU emulator
    ../src/Moira/Moira.cpp
    ../src/Moira/MoiraDebugger.cpp

    # Test files
    src/test_basic_sanity.cpp
    src/test_cpu_basic.cpp
    src/test_move.cpp
    src/test_arithmetic.cpp
    src/test_logical.cpp
    src/test_branches.cpp
    src/test_addressing_modes.cpp
    src/test_compare.cpp
    src/test_mul_div.cpp
    src/test_bit_ops.cpp
    src/test_stack_misc.cpp
)

# Include directories
target_include_directories(app PRIVATE
    ../src
    ../src/Moira
    src
)

# Compiler definitions
target_compile_definitions(app PRIVATE
    USE_MINIMAL_DISPATCH=1
    USE_ZEPHYR=1
)

# C++ standard
set_property(TARGET app PROPERTY CXX_STANDARD 17)
