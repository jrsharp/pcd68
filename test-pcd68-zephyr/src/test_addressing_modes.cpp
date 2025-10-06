/*
 * Addressing Mode Tests
 * Tests various 68000 addressing modes: indirect, displacement, indexed, etc.
 */

#include <zephyr/ztest.h>
#include "test_helper.h"

ZTEST_SUITE(addressing_modes, NULL, NULL, NULL, NULL, NULL);

ZTEST(addressing_modes, test_address_register_indirect)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: A0 points to 0x600, write value at 0x600
    cpu.writeA(0, 0x600);
    cpu.write_word(0x600, 0x1234);

    // MOVE.W (A0),D0  - Address Register Indirect
    cpu.write_word(0x400, 0x3010);  // MOVE.W (A0),D0

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(0), 0x1234, "D0 should contain value from (A0)");
    printk("✓ Address register indirect test passed\n");
}

ZTEST(addressing_modes, test_address_register_indirect_postincrement)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: A1 points to 0x700
    cpu.writeA(1, 0x700);
    cpu.write_word(0x700, 0x5678);

    // MOVE.W (A1)+,D1  - Post-increment
    cpu.write_word(0x400, 0x3219);  // MOVE.W (A1)+,D1

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(1), 0x5678, "D1 should contain value from (A1)");
    zassert_equal(cpu.readA(1), 0x702, "A1 should increment by 2");
    printk("✓ Post-increment test passed\n");
}

ZTEST(addressing_modes, test_address_register_indirect_predecrement)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: A2 points to 0x702, value at 0x700
    cpu.writeA(2, 0x702);
    cpu.write_word(0x700, 0x9ABC);

    // MOVE.W -(A2),D2  - Pre-decrement
    cpu.write_word(0x400, 0x3422);  // MOVE.W -(A2),D2

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(2), 0x9ABC, "D2 should contain value");
    zassert_equal(cpu.readA(2), 0x700, "A2 should decrement by 2 before read");
    printk("✓ Pre-decrement test passed\n");
}

ZTEST(addressing_modes, test_address_register_displacement)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: A3 points to 0x800, value at 0x810
    cpu.writeA(3, 0x800);
    cpu.write_word(0x810, 0xDEF0);

    // MOVE.W (16,A3),D3  - Address register with displacement
    cpu.write_word(0x400, 0x362B);  // MOVE.W (d16,A3),D3
    cpu.write_word(0x402, 0x0010);  // displacement = +16

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(3), 0xDEF0, "D3 should contain value from (A3+16)");
    printk("✓ Address register with displacement test passed\n");
}

ZTEST(addressing_modes, test_absolute_short_addressing)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);

    // Write value at absolute address 0x900
    cpu.write_word(0x900, 0x2468);

    // MOVE.W $900,D4  - Absolute short addressing
    cpu.write_word(0x400, 0x3838);  // MOVE.W (xxx).W,D4
    cpu.write_word(0x402, 0x0900);  // address = 0x900

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(4), 0x2468, "D4 should contain value from absolute address");
    printk("✓ Absolute short addressing test passed\n");
}

ZTEST(addressing_modes, test_absolute_long_addressing)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);

    // Write value at absolute address 0x1000
    cpu.write_word(0x1000, 0xACE0);

    // MOVE.W $1000,D5  - Absolute long addressing
    cpu.write_word(0x400, 0x3A39);  // MOVE.W (xxx).L,D5
    cpu.write_long(0x402, 0x00001000);  // address = 0x1000

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(5), 0xACE0, "D5 should contain value from absolute long address");
    printk("✓ Absolute long addressing test passed\n");
}

ZTEST(addressing_modes, test_pc_relative_displacement)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Write value at 0x412 (PC=0x402 + displacement of 0x10)
    cpu.write_word(0x412, 0xBEEF);

    // MOVE.W (d16,PC),D6  - PC-relative with displacement
    cpu.write_word(0x400, 0x3C3A);  // MOVE.W (d16,PC),D6
    cpu.write_word(0x402, 0x0010);  // displacement = +16

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(6), 0xBEEF, "D6 should contain value from PC+displacement");
    printk("✓ PC-relative addressing test passed\n");
}

ZTEST(addressing_modes, test_immediate_mode)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // MOVE.W #$CAFE,D7  - Immediate data
    cpu.write_word(0x400, 0x3E3C);  // MOVE.W #imm,D7
    cpu.write_word(0x402, 0xCAFE);  // immediate value

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(7), 0xCAFE, "D7 should contain immediate value");
    printk("✓ Immediate addressing test passed\n");
}

ZTEST(addressing_modes, test_write_to_memory_indirect)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D0 = 0x1234, A4 = 0xA00
    cpu.writeD(0, 0x1234);
    cpu.writeA(4, 0xA00);

    // MOVE.W D0,(A4)  - Write to address register indirect
    cpu.write_word(0x400, 0x3880);  // MOVE.W D0,(A4)

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    uint16_t value = cpu.read16(0xA00);
    zassert_equal(value, 0x1234, "Memory at (A4) should contain D0 value");
    printk("✓ Write to memory (indirect) test passed\n");
}

ZTEST(addressing_modes, test_stack_operations)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // SP is A7, set to 0x1000
    cpu.writeA(7, 0x1000);
    cpu.writeD(1, 0xABCD);

    // MOVE.W D1,-(A7)  - Push D1 onto stack
    cpu.write_word(0x400, 0x3F01);  // MOVE.W D1,-(A7)

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readA(7), 0x0FFE, "SP should decrement by 2");
    uint16_t stack_value = cpu.read16(0x0FFE);
    zassert_equal(stack_value, 0xABCD, "Stack should contain D1 value");
    printk("✓ Stack push test passed\n");
}
