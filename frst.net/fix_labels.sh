#!/bin/sh
# Fix broken labels that got split during conversion

INPUT="$1"
if [ -z "$INPUT" ]; then
    echo "Usage: $0 filename.s"
    exit 1
fi

echo "Fixing broken labels in $INPUT..."

# Fix broken labels that contain dots
sed -i 's/keyboard_hand\.ler/keyboard_handler/g' "$INPUT"
sed -i 's/uart1_interrupt_hand\.ler/uart1_interrupt_handler/g' "$INPUT" 
sed -i 's/uart2_interrupt_hand\.ler/uart2_interrupt_handler/g' "$INPUT"
sed -i 's/default_hand\.ler/default_handler/g' "$INPUT"

# Fix any other common broken labels
sed -i 's/interrupt_hand\.ler/interrupt_handler/g' "$INPUT"
sed -i 's/exception_hand\.ler/exception_handler/g' "$INPUT"

# Look for pattern like "word.part" and try to fix common ones
sed -i 's/init\.ialization/initialization/g' "$INPUT"
sed -i 's/clear\.screen/clear_screen/g' "$INPUT"
sed -i 's/draw\.pixel/draw_pixel/g' "$INPUT"
sed -i 's/display\.update/display_update/g' "$INPUT"

echo "Fixed labels in: $INPUT"