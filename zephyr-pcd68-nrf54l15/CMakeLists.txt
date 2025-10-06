# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.20.0)

# Include Zephyr boilerplate
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(pcd68_nrf54l15)

# Include PCD68 common source directory
set(PCD68_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../src)

# Core PCD68 emulation sources with optimized Moira dispatch
target_sources(app PRIVATE
    src/main.cpp
    ${PCD68_SRC_DIR}/PCD68_CPU.cpp
    ${PCD68_SRC_DIR}/Moira/Moira.cpp
    ${PCD68_SRC_DIR}/Moira/MoiraDebugger.cpp
    # Essential peripherals - optimized for memory
    ${PCD68_SRC_DIR}/TDA.cpp
    ${PCD68_SRC_DIR}/KCTL.cpp
    src/Storage_Zephyr.cpp
    # Screen support
    ${PCD68_SRC_DIR}/Screen.cpp
    src/Screen_Zephyr.cpp
    # UART support
    src/UART_Zephyr.cpp
    # Keyboard input (stub for now - BLE needs API adaptation for nRF54L15)
    src/KeyboardInput_Zephyr.cpp
)

# Include directories
target_include_directories(app PRIVATE
    src
    ${PCD68_SRC_DIR}
    ${PCD68_SRC_DIR}/Moira
)

# Compiler definitions
target_compile_definitions(app PRIVATE
    ZEPHYR_BUILD=1
    USE_ZEPHYR=1
    PCD68_DISABLE_SOUND=1
    CONFIG_PCD68_ROM_SIZE_KB=64
    CONFIG_PCD68_RAM_SIZE_MB=0
    CONFIG_PCD68_TARGET_CPU_MHZ=128
)

# C++ standard and flags
set_property(TARGET app PROPERTY CXX_STANDARD 17)
set_property(TARGET app PROPERTY CXX_STANDARD_REQUIRED ON)
target_compile_options(app PRIVATE $<$<COMPILE_LANGUAGE:CXX>:-std=gnu++17>)