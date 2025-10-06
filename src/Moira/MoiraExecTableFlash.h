// Flash-based exec table for Moira
// This provides a const exec table that can be placed in flash memory

#pragma once

namespace moira {

#if USE_EXEC_TABLE_IN_FLASH && !USE_MINIMAL_DISPATCH

// Simplified approach: const initialized table with basic pattern matching
// This will be placed in .rodata (flash) section
extern const Moira::ExecPtr exec_table_flash[65536];

#endif // USE_EXEC_TABLE_IN_FLASH && !USE_MINIMAL_DISPATCH

} // namespace moira