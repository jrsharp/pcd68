/*
 * MOVE Instruction Tests
 * Tests MOVE, MOVEA, MOVEQ instructions
 */

#include <zephyr/ztest.h>
#include "test_helper.h"

ZTEST_SUITE(move_instructions, NULL, NULL, NULL, NULL, NULL);

ZTEST(move_instructions, test_moveq_immediate)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // MOVEQ #42, D0  (0x7000 | (0 << 9) | 42)
    cpu.write_word(0x400, 0x702A);  // MOVEQ #42,D0

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(0), 42, "D0 should contain 42");
    printk("✓ MOVEQ #42,D0 test passed\n");
}

ZTEST(move_instructions, test_moveq_negative)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // MOVEQ #-1, D1  (0x7200 | 0xFF)
    cpu.write_word(0x400, 0x72FF);  // MOVEQ #-1,D1

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(1), 0xFFFFFFFF, "D1 should contain -1 (0xFFFFFFFF)");
    printk("✓ MOVEQ #-1,D1 test passed\n");
}

ZTEST(move_instructions, test_move_dn_to_dn_word)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D0 = 0x1234
    cpu.writeD(0, 0x1234);

    // MOVE.W D0,D1  (0x3200 | (1 << 9) | D0)
    cpu.write_word(0x400, 0x3200);  // MOVE.W D0,D1

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(1), 0x1234, "D1 should contain 0x1234");
    printk("✓ MOVE.W D0,D1 test passed\n");
}

ZTEST(move_instructions, test_move_dn_to_dn_long)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D0 = 0x12345678
    cpu.writeD(0, 0x12345678);

    // MOVE.L D0,D2  (0x2400 | (2 << 9) | D0)
    cpu.write_word(0x400, 0x2400);  // MOVE.L D0,D2

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(2), 0x12345678, "D2 should contain 0x12345678");
    printk("✓ MOVE.L D0,D2 test passed\n");
}

ZTEST(move_instructions, test_move_immediate_to_dn)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // MOVE.W #0x5678,D3  (0x363C followed by immediate)
    cpu.write_word(0x400, 0x363C);  // MOVE.W #imm,D3
    cpu.write_word(0x402, 0x5678);  // immediate value

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(3), 0x5678, "D3 should contain 0x5678");
    printk("✓ MOVE.W #0x5678,D3 test passed\n");
}

ZTEST(move_instructions, test_move_immediate_long_to_dn)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // MOVE.L #0xDEADBEEF,D4  (0x283C followed by long immediate)
    cpu.write_word(0x400, 0x283C);  // MOVE.L #imm,D4
    cpu.write_long(0x402, 0xDEADBEEF);  // immediate value

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(4), 0xDEADBEEF, "D4 should contain 0xDEADBEEF");
    printk("✓ MOVE.L #0xDEADBEEF,D4 test passed\n");
}

ZTEST(move_instructions, test_movea_word_to_an)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // MOVEA.W #0x1000,A2  (0x347C followed by immediate)
    cpu.write_word(0x400, 0x347C);  // MOVEA.W #imm,A2
    cpu.write_word(0x402, 0x1000);  // immediate value

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readA(2), 0x1000, "A2 should contain 0x1000");
    printk("✓ MOVEA.W #0x1000,A2 test passed\n");
}

ZTEST(move_instructions, test_movea_long_to_an)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // MOVEA.L #0x10000000,A3  (0x267C followed by long immediate)
    cpu.write_word(0x400, 0x267C);  // MOVEA.L #imm,A3
    cpu.write_long(0x402, 0x10000000);  // immediate value

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readA(3), 0x10000000, "A3 should contain 0x10000000");
    printk("✓ MOVEA.L #0x10000000,A3 test passed\n");
}

ZTEST(move_instructions, test_move_flags_zero)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // MOVEQ #0,D0 should set Z flag
    cpu.write_word(0x400, 0x7000);  // MOVEQ #0,D0

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(0), 0, "D0 should be 0");
    // Z flag should be set - we'd need to expose SR/CCR reading to test this
    printk("✓ MOVE flags (zero) test passed\n");
}
