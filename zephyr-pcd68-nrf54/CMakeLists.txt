# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(pcd68_zephyr)

# Get the parent directory path for PCD68 sources
get_filename_component(PCD68_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)

# Add include directories
target_include_directories(app PRIVATE 
    ${PCD68_ROOT}/src
    ${PCD68_ROOT}/src/Moira
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Core PCD68 sources (relative to parent directory)
if(CONFIG_PCD68_USE_LIGHTWEIGHT_VM)
    # Use lightweight VM for embedded targets with limited flash
    target_sources(app PRIVATE
        ${PCD68_ROOT}/src/PCD68_VM.cpp
        ${PCD68_ROOT}/src/TDA.cpp
        ${PCD68_ROOT}/src/KCTL.cpp
        ${PCD68_ROOT}/src/Screen.cpp
    )
else()
    # Use full Moira 68000 emulator
    target_sources(app PRIVATE
        ${PCD68_ROOT}/src/PCD68_CPU.cpp
        ${PCD68_ROOT}/src/TDA.cpp
        ${PCD68_ROOT}/src/KCTL.cpp
        ${PCD68_ROOT}/src/Screen.cpp
        ${PCD68_ROOT}/src/Moira/Moira.cpp
        ${PCD68_ROOT}/src/Moira/MoiraDebugger.cpp
    )
endif()

# Zephyr-specific implementations
target_sources(app PRIVATE
    src/main.cpp
    src/Screen_Zephyr.cpp
    src/Storage_Zephyr.cpp
    src/UART_Zephyr.cpp
)

# Conditional keyboard input implementation
if(CONFIG_PCD68_KEYBOARD_TYPE STREQUAL "BLE_GATT")
    target_sources(app PRIVATE src/KeyboardInput_BLE.cpp)
else()
    target_sources(app PRIVATE src/KeyboardInput_Zephyr.cpp)
endif()

# Set C++ standard
set_property(TARGET app PROPERTY CXX_STANDARD 17)

# Compiler flags for the 68000 emulation - debug build
target_compile_options(app PRIVATE
    -Wno-narrowing
    -DUSE_ZEPHYR=1
    -DNRF54H20_TARGET=1
    -Og               # Debug-friendly optimization
    -g3               # Maximum debug info
    -fno-omit-frame-pointer  # Keep frame pointers for debugging
    -fno-exceptions
    -fno-rtti
    # Removed -flto and aggressive optimizations for debugging
)

# For nRF54H20 specific optimizations - let Zephyr handle floating-point ABI
if(CONFIG_SOC_SERIES_NRF54HX)
    target_compile_options(app PRIVATE
        -mcpu=cortex-m33
        -mthumb
        # Let Zephyr handle floating-point settings to avoid ABI conflicts
    )
endif()