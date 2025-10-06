#!/bin/bash
source /home/jrsharp/ncs/v3.1.0/.venv/bin/activate

echo "=== PCD-68 M68000 Emulator Test Execution Report ===" > test_execution_report.txt
echo "Date: $(date)" >> test_execution_report.txt
echo "" >> test_execution_report.txt

# Run the full test suite with timeout
timeout 30 qemu-system-arm -machine mps3-an547 \
    -kernel build/test-pcd68-zephyr/zephyr/zephyr.elf \
    -nographic 2>&1 | tee -a test_execution_report.txt

echo "" >> test_execution_report.txt
echo "=== Test run completed ===" >> test_execution_report.txt
