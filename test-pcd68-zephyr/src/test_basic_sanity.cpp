/*
 * Basic Sanity Tests
 * Verifies test infrastructure before testing CPU instructions
 */

#include <zephyr/ztest.h>
#include "test_helper.h"

ZTEST_SUITE(basic_sanity, NULL, NULL, NULL, NULL, NULL);

ZTEST(basic_sanity, test_memory_allocation)
{
    printk("Creating TestMemory object...\n");
    TestMemory cpu;

    printk("Checking RAM allocation... ram=%p\n", cpu.ram);
    // Verify RAM was allocated
    zassert_not_null(cpu.ram, "RAM should be allocated");

    // Verify we can write and read
    printk("Writing to RAM...\n");
    cpu.ram[0] = 0x42;
    printk("Reading from RAM...\n");
    zassert_equal(cpu.ram[0], 0x42, "Should be able to write/read RAM");

    printk("✓ Memory allocation test passed\n");
}

ZTEST(basic_sanity, test_reset_vector)
{
    TestMemory cpu;

    // Set reset vectors
    cpu.write_long(0, 0x00001000);  // Initial SP
    cpu.write_long(4, 0x00000400);  // Initial PC

    cpu.reset();  // Reset to load vectors

    // Verify PC was set correctly
    uint32_t pc = cpu.getPC();
    printk("PC after reset: 0x%08x\n", pc);
    zassert_equal(pc, 0x00000400, "PC should be 0x400 after reset");

    printk("✓ Reset vector test passed\n");
}

ZTEST(basic_sanity, test_register_access)
{
    TestMemory cpu;

    // Test data register access
    cpu.writeD(0, 0x12345678);
    uint32_t d0 = cpu.readD(0);
    printk("D0: 0x%08x\n", d0);
    zassert_equal(d0, 0x12345678, "D0 should contain written value");

    // Test address register access
    cpu.writeA(1, 0xABCDEF00);
    uint32_t a1 = cpu.readA(1);
    printk("A1: 0x%08x\n", a1);
    zassert_equal(a1, 0xABCDEF00, "A1 should contain written value");

    printk("✓ Register access test passed\n");
}

ZTEST(basic_sanity, test_nop_execution)
{
    TestMemory cpu;

    cpu.write_long(0, 0x00001000);  // SP
    cpu.write_long(4, 0x00000400);  // PC
    // Write NOP instruction (0x4E71)
    cpu.write_word(0x400, 0x4E71);

    cpu.reset();  // Reset AFTER writing instructions

    uint32_t pc_before = cpu.getPC();
    printk("PC before NOP: 0x%08x\n", pc_before);

    cpu.execute();

    uint32_t pc_after = cpu.getPC();
    printk("PC after NOP: 0x%08x\n", pc_after);

    zassert_equal(pc_after, 0x402, "PC should be at 0x402 after NOP at 0x400");

    printk("✓ NOP execution test passed\n");
}
