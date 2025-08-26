#!/bin/sh
# Convert GNU AS syntax to vasm Motorola syntax

if [ $# -ne 2 ]; then
    echo "Usage: $0 input.S output_mot.s"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

echo "Converting $INPUT to $OUTPUT..."

# Copy and convert
cp "$INPUT" "$OUTPUT"

# Convert directives
# First remove all existing .equ definitions that will be redefined
sed -i '/^\.equ KEY_ENTER/d' "$OUTPUT"
sed -i '/^\.equ KEY_ESC/d' "$OUTPUT"  
sed -i '/^\.equ KEY_BACKSPACE/d' "$OUTPUT"
# Then convert remaining .equ
sed -i 's/^\.equ \([^,]*\), \(.*\)/\1 equ \2/' "$OUTPUT"
sed -i 's/^\.global/	xdef/' "$OUTPUT"
sed -i 's/^\.extern/	xref/' "$OUTPUT"
sed -i 's/^\.text//' "$OUTPUT"
sed -i 's/^\.data/	section data/' "$OUTPUT"
sed -i 's/^\.bss/	section bss/' "$OUTPUT"
sed -i 's/^\.byte/	dc.b/' "$OUTPUT"
sed -i 's/^\.word/	dc.w/' "$OUTPUT"
sed -i 's/^\.long/	dc.l/' "$OUTPUT"
sed -i 's/^\.ascii "\(.*\)"/	dc.b '\''\1'\''/' "$OUTPUT"
sed -i 's/^\.asciz "\(.*\)"/	dc.b '\''\1'\'',0/' "$OUTPUT"
sed -i 's/^\.align/	align/' "$OUTPUT"
sed -i 's/^\.space \([^,]*\)/	ds.b \1/' "$OUTPUT"
sed -i 's/^\.include "\(.*\)"/	include "\1"/' "$OUTPUT"

# Convert .org to org
sed -i 's/^\.org/	org/' "$OUTPUT"

# Handle .rept/.endr (convert to rept/endr)
sed -i 's/^\.rept/	rept/' "$OUTPUT"
sed -i 's/^\.endr/	endr/' "$OUTPUT"

# Convert hex numbers from 0x to $
sed -i 's/0x\([0-9a-fA-F]*\)/\$\1/g' "$OUTPUT"

# Remove % from register names
sed -i 's/%\([ad][0-7]\)/\1/g' "$OUTPUT"
sed -i 's/%sp/sp/g' "$OUTPUT"
sed -i 's/%pc/pc/g' "$OUTPUT"
sed -i 's/%sr/sr/g' "$OUTPUT"
sed -i 's/%ccr/ccr/g' "$OUTPUT"

# Handle labels and comments
sed -i 's/\/\*/;/' "$OUTPUT"
sed -i 's/\*\///' "$OUTPUT"

echo "Conversion complete. Please review $OUTPUT for any manual adjustments needed."