// -----------------------------------------------------------------------------
// This file is part of Moira - A Motorola 68k emulator
//
// Copyright (C) Dirk W. Hoffmann. www.dirkwhoffmann.de
// Licensed under the GNU General Public License v3
//
// See https://www.gnu.org for license information
// -----------------------------------------------------------------------------

#pragma once

/* Set to true to enable address error checking.
 *
 * The Motorola 68k signals an address error violation if a odd memory location
 * is addressed in combination with word or long word addressing.
 *
 * Enable to improve emulation compatibility, disable to gain speed.
 */
#ifdef USE_ZEPHYR
#define EMULATE_ADDRESS_ERROR false  // Disable for embedded to save space and cycles
#else
#define EMULATE_ADDRESS_ERROR false
#endif

/* Set to true to emulate the function code pins FC0 - FC2.
 *
 * Whenever memory is accessed, the function code pins enable external hardware
 * to inspect the access type. If used, these pins are usually connected to an
 * external memory management unit (MMU).
 *
 * Enable to improve emulation compatibility, disable to gain speed.
 */
#ifdef USE_ZEPHYR
#define EMULATE_FC false  // Disable for embedded - no external MMU on nRF54H20
#else
#define EMULATE_FC true
#endif

/* Set to true to enable the disassembler.
 *
 * The disassembler requires a jump table which consumes about 1MB of memory.
 * By disabling the disassembler, you can save this amount of memory.
 */
#ifdef USE_ZEPHYR
#define ENABLE_DASM false  // Disable for embedded targets to save ~1MB
#else
#define ENABLE_DASM true
#endif

/* Minimal instruction set for PCD68 - only include commonly used instructions
 * to drastically reduce code size for embedded targets
 */
#ifdef NRF54H20_TARGET
#define MINIMAL_INSTRUCTION_SET 1
#endif

/* Set to true to build the InstrInfo lookup table.
 *
 * The info table stores information about the instruction (Instr I), the
 * addressing mode (Mode M), and the size attribute (Size S) for all 65536
 * instruction words. The table is meant to provide data for, e.g., external
 * debuggers. It is not needed by Moira itself and therefore disabled by
 * default.
 */
#ifdef USE_ZEPHYR
#define BUILD_INSTR_INFO_TABLE false  // Not needed for embedded runtime
#else
#define BUILD_INSTR_INFO_TABLE true
#endif

/* Set to true to run Moira in a special Musashi compatibility mode.
 *
 * The compatibility mode is used by the test runner application to compare
 * the results computed by Moira and Musashi, respectively.
 *
 * Disable to improve emulation compatibility.
 */
#ifdef USE_ZEPHYR
#define MIMIC_MUSASHI false  // Not needed for production emulation
#else
#define MIMIC_MUSASHI true
#endif
