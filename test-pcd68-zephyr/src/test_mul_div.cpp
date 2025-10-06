/*
 * Multiply and Divide Instruction Tests
 * Tests MULU, MULS, DIVU, DIVS instructions
 */

#include <zephyr/ztest.h>
#include "test_helper.h"

ZTEST_SUITE(mul_div_tests, NULL, NULL, NULL, NULL, NULL);

ZTEST(mul_div_tests, test_mulu_simple)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D0 = 10, D1 = 5
    cpu.writeD(0, 10);
    cpu.writeD(1, 5);

    // MULU D1,D0  - Unsigned multiply
    cpu.write_word(0x400, 0xC0C1);  // MULU D1,D0

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(0), 50, "D0 should contain 10 * 5 = 50");
    printk("✓ MULU simple test passed\n");
}

ZTEST(mul_div_tests, test_mulu_large)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D2 = 1000, D3 = 100
    cpu.writeD(2, 1000);
    cpu.writeD(3, 100);

    // MULU D3,D2  - Result = 100,000
    cpu.write_word(0x400, 0xC4C3);  // MULU D3,D2

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(2), 100000, "D2 should contain 1000 * 100 = 100,000");
    printk("✓ MULU large test passed\n");
}

ZTEST(mul_div_tests, test_mulu_immediate)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D4 = 7
    cpu.writeD(4, 7);

    // MULU #6,D4  - 7 * 6 = 42
    cpu.write_word(0x400, 0xC8FC);  // MULU #imm,D4
    cpu.write_word(0x402, 0x0006);  // immediate = 6

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(4), 42, "D4 should contain 7 * 6 = 42");
    printk("✓ MULU immediate test passed\n");
}

ZTEST(mul_div_tests, test_muls_positive)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D0 = 10, D1 = 5
    cpu.writeD(0, 10);
    cpu.writeD(1, 5);

    // MULS D1,D0  - Signed multiply (both positive)
    cpu.write_word(0x400, 0xC1C1);  // MULS D1,D0

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(0), 50, "D0 should contain 10 * 5 = 50");
    printk("✓ MULS positive test passed\n");
}

ZTEST(mul_div_tests, test_muls_negative)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D2 = -10 (0xFFFFFFF6), D3 = 5
    cpu.writeD(2, 0xFFFFFFF6);  // -10 as 32-bit
    cpu.writeD(3, 5);

    // MULS D3,D2  - (-10) * 5 = -50
    cpu.write_word(0x400, 0xC5C3);  // MULS D3,D2

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    // Result should be -50 (0xFFFFFFCE)
    zassert_equal(cpu.readD(2), 0xFFFFFFCE, "D2 should contain -10 * 5 = -50");
    printk("✓ MULS negative test passed\n");
}

ZTEST(mul_div_tests, test_muls_both_negative)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D4 = -6 (0xFFFFFFFA), D5 = -7 (0xFFFFFFF9)
    cpu.writeD(4, 0xFFFFFFFA);  // -6
    cpu.writeD(5, 0xFFFFFFF9);  // -7

    // MULS D5,D4  - (-6) * (-7) = 42
    cpu.write_word(0x400, 0xC9C5);  // MULS D5,D4

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    zassert_equal(cpu.readD(4), 42, "D4 should contain (-6) * (-7) = 42");
    printk("✓ MULS both negative test passed\n");
}

ZTEST(mul_div_tests, test_divu_simple)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D0 = 100, D1 = 10
    cpu.writeD(0, 100);
    cpu.writeD(1, 10);

    // DIVU D1,D0  - Unsigned divide: 100 / 10 = 10
    cpu.write_word(0x400, 0x80C1);  // DIVU D1,D0

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    // Result: quotient in lower word, remainder in upper word
    uint32_t result = cpu.readD(0);
    uint16_t quotient = result & 0xFFFF;
    uint16_t remainder = (result >> 16) & 0xFFFF;

    zassert_equal(quotient, 10, "Quotient should be 10");
    zassert_equal(remainder, 0, "Remainder should be 0");
    printk("✓ DIVU simple test passed\n");
}

ZTEST(mul_div_tests, test_divu_with_remainder)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D2 = 25, D3 = 7
    cpu.writeD(2, 25);
    cpu.writeD(3, 7);

    // DIVU D3,D2  - 25 / 7 = 3 remainder 4
    cpu.write_word(0x400, 0x84C3);  // DIVU D3,D2

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    uint32_t result = cpu.readD(2);
    uint16_t quotient = result & 0xFFFF;
    uint16_t remainder = (result >> 16) & 0xFFFF;

    zassert_equal(quotient, 3, "Quotient should be 3");
    zassert_equal(remainder, 4, "Remainder should be 4");
    printk("✓ DIVU with remainder test passed\n");
}

ZTEST(mul_div_tests, test_divs_positive)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D4 = 50, D5 = 5
    cpu.writeD(4, 50);
    cpu.writeD(5, 5);

    // DIVS D5,D4  - Signed divide: 50 / 5 = 10
    cpu.write_word(0x400, 0x89C5);  // DIVS D5,D4

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    uint32_t result = cpu.readD(4);
    int16_t quotient = (int16_t)(result & 0xFFFF);
    int16_t remainder = (int16_t)((result >> 16) & 0xFFFF);

    zassert_equal(quotient, 10, "Quotient should be 10");
    zassert_equal(remainder, 0, "Remainder should be 0");
    printk("✓ DIVS positive test passed\n");
}

ZTEST(mul_div_tests, test_divs_negative_dividend)
{
    TestMemory cpu;
    cpu.write_long(0, 0x00001000);
    cpu.write_long(4, 0x00000400);
    // Setup: D6 = -50 (0xFFFFFFCE), D7 = 5
    cpu.writeD(6, 0xFFFFFFCE);  // -50
    cpu.writeD(7, 5);

    // DIVS D7,D6  - (-50) / 5 = -10
    cpu.write_word(0x400, 0x8DC7);  // DIVS D7,D6

    cpu.reset();  // Reset AFTER writing instructions
    cpu.execute();

    uint32_t result = cpu.readD(6);
    int16_t quotient = (int16_t)(result & 0xFFFF);

    zassert_equal(quotient, -10, "Quotient should be -10");
    printk("✓ DIVS negative dividend test passed\n");
}
