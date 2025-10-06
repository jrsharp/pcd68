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
target_sources(app PRIVATE
    ${PCD68_ROOT}/src/PCD68_CPU.cpp
    ${PCD68_ROOT}/src/TDA.cpp
    ${PCD68_ROOT}/src/KCTL.cpp
    ${PCD68_ROOT}/src/UART.cpp
    ${PCD68_ROOT}/src/Screen.cpp
    ${PCD68_ROOT}/src/Moira/Moira.cpp
    ${PCD68_ROOT}/src/Moira/MoiraDebugger.cpp
)

# Zephyr-specific implementations
target_sources(app PRIVATE
    src/main.cpp
    src/Screen_Zephyr.cpp
    src/KeyboardInput_Zephyr.cpp
    src/Storage_Zephyr.cpp
)

# Set C++ standard
set_property(TARGET app PROPERTY CXX_STANDARD 17)

# Compiler flags for the 68000 emulation
target_compile_options(app PRIVATE
    -Wno-narrowing
    -DUSE_ZEPHYR=1
    -DESP32S3_TARGET=1
)

# For ESP32-S3 specific optimizations
if(CONFIG_SOC_SERIES_ESP32S3)
    target_compile_options(app PRIVATE
        -mlongcalls
        -mtext-section-literals
    )
endif()