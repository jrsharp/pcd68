/*
 * Bit Manipulation Tests
 * Tests BSET, BCLR, BTST, BCHG, and other bit operations
 */

#include <zephyr/ztest.h>
#include "test_helper.h"

ZTEST_SUITE(bit_operations, NULL, NULL, NULL, NULL, NULL);

ZTEST(bit_operations, test_btst_set)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D0 = 0x08 (bit 3 set)
    cpu.writeD(0, 0x08);

    // BTST #3,D0  - Test bit 3
    cpu.write_word(0x400, 0x0800);  // BTST #imm,D0
    cpu.write_word(0x402, 0x0003);  // bit number = 3

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(0), 0x08, "D0 should be unchanged");
    // Z flag should be clear (bit is set)
    printk("✓ BTST (bit set) test passed\n");
}

ZTEST(bit_operations, test_btst_clear)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D1 = 0x08 (bit 2 clear)
    cpu.writeD(1, 0x08);

    // BTST #2,D1  - Test bit 2
    cpu.write_word(0x400, 0x0801);  // BTST #imm,D1
    cpu.write_word(0x402, 0x0002);  // bit number = 2

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(1), 0x08, "D1 should be unchanged");
    // Z flag should be set (bit is clear)
    printk("✓ BTST (bit clear) test passed\n");
}

ZTEST(bit_operations, test_bset_immediate)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D2 = 0x00
    cpu.writeD(2, 0x00);

    // BSET #5,D2  - Set bit 5
    cpu.write_word(0x400, 0x08C2);  // BSET #imm,D2
    cpu.write_word(0x402, 0x0005);  // bit number = 5

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(2), 0x20, "D2 should have bit 5 set (0x20)");
    printk("✓ BSET immediate test passed\n");
}

ZTEST(bit_operations, test_bclr_immediate)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D3 = 0xFF
    cpu.writeD(3, 0xFF);

    // BCLR #4,D3  - Clear bit 4
    cpu.write_word(0x400, 0x0883);  // BCLR #imm,D3
    cpu.write_word(0x402, 0x0004);  // bit number = 4

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(3), 0xEF, "D3 should have bit 4 clear (0xEF)");
    printk("✓ BCLR immediate test passed\n");
}

ZTEST(bit_operations, test_bchg_immediate)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D4 = 0x55 (01010101)
    cpu.writeD(4, 0x55);

    // BCHG #0,D4  - Toggle bit 0
    cpu.write_word(0x400, 0x0844);  // BCHG #imm,D4
    cpu.write_word(0x402, 0x0000);  // bit number = 0

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(4), 0x54, "D4 should have bit 0 toggled (0x54)");
    printk("✓ BCHG immediate test passed\n");
}

ZTEST(bit_operations, test_bset_register)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D0 = 3 (bit number), D5 = 0x00
    cpu.writeD(0, 3);
    cpu.writeD(5, 0x00);

    // BSET D0,D5  - Set bit specified by D0
    cpu.write_word(0x400, 0x01C5);  // BSET D0,D5

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(5), 0x08, "D5 should have bit 3 set (0x08)");
    printk("✓ BSET register test passed\n");
}

ZTEST(bit_operations, test_bclr_register)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D1 = 7 (bit number), D6 = 0xFF
    cpu.writeD(1, 7);
    cpu.writeD(6, 0xFF);

    // BCLR D1,D6  - Clear bit specified by D1
    cpu.write_word(0x400, 0x0386);  // BCLR D1,D6

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(6), 0x7F, "D6 should have bit 7 clear (0x7F)");
    printk("✓ BCLR register test passed\n");
}

ZTEST(bit_operations, test_btst_register)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D2 = 4 (bit number), D7 = 0x10 (bit 4 set)
    cpu.writeD(2, 4);
    cpu.writeD(7, 0x10);

    // BTST D2,D7  - Test bit specified by D2
    cpu.write_word(0x400, 0x0547);  // BTST D2,D7

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(7), 0x10, "D7 should be unchanged");
    // Z flag should be clear (bit is set)
    printk("✓ BTST register test passed\n");
}

ZTEST(bit_operations, test_bchg_register)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D3 = 2 (bit number), D0 = 0x04 (bit 2 set)
    cpu.writeD(3, 2);
    cpu.writeD(0, 0x04);

    // BCHG D3,D0  - Toggle bit specified by D3
    cpu.write_word(0x400, 0x0740);  // BCHG D3,D0

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(0), 0x00, "D0 should have bit 2 toggled (0x00)");
    printk("✓ BCHG register test passed\n");
}

ZTEST(bit_operations, test_bit_ops_on_high_bits)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D1 = 0x00000000
    cpu.writeD(1, 0x00000000);

    // BSET #31,D1  - Set bit 31 (highest bit)
    cpu.write_word(0x400, 0x08C1);  // BSET #imm,D1
    cpu.write_word(0x402, 0x001F);  // bit number = 31

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(1), 0x80000000, "D1 should have bit 31 set");
    printk("✓ Bit ops on high bits test passed\n");
}
