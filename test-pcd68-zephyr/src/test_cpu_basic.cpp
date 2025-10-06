/*
 * Basic CPU Initialization and Reset Tests
 */

#include <zephyr/ztest.h>
#include "test_helper.h"

ZTEST_SUITE(cpu_basic, NULL, NULL, NULL, NULL, NULL);

ZTEST(cpu_basic, test_cpu_initialization)
{
    TestMemory cpu;

    // Set initial PC and SP in reset vector
    cpu.write_long(0, 0x00001000);  // Initial SP
    cpu.write_long(4, 0x00000400);  // Initial PC

    // Check that PC is set correctly
    zassert_equal(cpu.getPC(), 0x00000400, "PC should be 0x400 after reset");

    printk("✓ CPU initialization test passed\n");
}

ZTEST(cpu_basic, test_nop_instruction)
{
    TestMemory cpu;

    // Setup: PC at 0x400, SP at 0x1000
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Write NOP instruction (0x4E71)
    cpu.write_word(0x400, 0x4E71);

    uint32_t pc_before = cpu.getPC();
    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();
    uint32_t pc_after = cpu.getPC();

    zassert_equal(pc_after, pc_before + 2, "PC should advance by 2 after NOP");

    printk("✓ NOP instruction test passed\n");
}

ZTEST(cpu_basic, test_multiple_nops)
{
    TestMemory cpu;

    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Write 5 NOP instructions
    for (int i = 0; i < 5; i++) {
        cpu.write_word(0x400 + i * 2, 0x4E71);
    }

    uint32_t initial_pc = cpu.getPC();

    // Execute 5 NOPs
    for (int i = 0; i < 5; i++) {
    cpu.reset();  // Reset AFTER writing instructions
        cpu.execute();
    }

    zassert_equal(cpu.getPC(), initial_pc + 10, "PC should advance by 10 after 5 NOPs");

    printk("✓ Multiple NOPs test passed\n");
}

ZTEST(cpu_basic, test_cache_initialization)
{
    TestMemory cpu;

    // The opcode cache should be properly initialized
    // Execute the same NOP multiple times to test cache hits
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Write NOPs
    for (int i = 0; i < 100; i++) {
        cpu.write_word(0x400 + i * 2, 0x4E71);
    }

    // Execute 100 NOPs - this should exercise the cache
    for (int i = 0; i < 100; i++) {
    cpu.reset();  // Reset AFTER writing instructions
        cpu.execute();
    }

    zassert_equal(cpu.getPC(), 0x400 + 200, "PC should be at 0x4C8 after 100 NOPs");

    printk("✓ Opcode cache test passed (100 NOPs executed)\n");
}
