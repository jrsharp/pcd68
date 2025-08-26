#!/bin/sh
# Convert GNU AS syntax to vasm Motorola syntax for FRST.net project

if [ $# -ne 2 ]; then
    echo "Usage: $0 input.S output.s"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

echo "Converting $INPUT to $OUTPUT..."

# Start with a clean copy
cp "$INPUT" "$OUTPUT"

# Remove preprocessor comments
sed -i 's|/\*.*\*/||g' "$OUTPUT"
sed -i 's|/\*|;|g' "$OUTPUT"
sed -i 's|\*/||g' "$OUTPUT"

# Convert .equ directives (format: .equ name, value -> name equ value)
sed -i 's/^\.equ \([^,]*\), \(.*\)/\1	equ	\2/' "$OUTPUT"

# Convert other directives
sed -i 's/^\.global \(.*\)/	xdef	\1/' "$OUTPUT"
sed -i 's/^\.extern \(.*\)/	xref	\1/' "$OUTPUT"
sed -i 's/^\.text/	section	code/' "$OUTPUT"
sed -i 's/^\.data/	section	data/' "$OUTPUT"
sed -i 's/^\.bss/	section	bss/' "$OUTPUT"

# Convert data directives
sed -i 's/^\.byte/	dc.b/' "$OUTPUT"
sed -i 's/^\.word/	dc.w/' "$OUTPUT"
sed -i 's/^\.long/	dc.l/' "$OUTPUT"
sed -i 's/^\.ascii "\(.*\)"/	dc.b	'\''\1'\''/' "$OUTPUT"
sed -i 's/^\.asciz "\(.*\)"/	dc.b	'\''\1'\'',0/' "$OUTPUT"
sed -i 's/^\.string "\(.*\)"/	dc.b	'\''\1'\'',0/' "$OUTPUT"

# Convert space allocation
sed -i 's/^\.space \([^,]*\),\([^,]*\)/	dcb.b	\1,\2/' "$OUTPUT"
sed -i 's/^\.space \([^,]*\)/	ds.b	\1/' "$OUTPUT"
sed -i 's/^\.skip \([^,]*\)/	ds.b	\1/' "$OUTPUT"

# Convert alignment
sed -i 's/^\.align \(.*\)/	align	\1/' "$OUTPUT"
sed -i 's/^\.balign \(.*\)/	align	\1/' "$OUTPUT"

# Convert org directive
sed -i 's/^\.org \(.*\)/	org	\1/' "$OUTPUT"

# Convert rept/endr
sed -i 's/^\.rept \(.*\)/	rept	\1/' "$OUTPUT"
sed -i 's/^\.endr/	endr/' "$OUTPUT"

# Convert macro directives
sed -i 's/^\.macro \(.*\)/\1	macro/' "$OUTPUT"
sed -i 's/^\.endm/	endm/' "$OUTPUT"

# Convert include directives - need to change .S to .s for converted files
sed -i 's/^\.include "\(.*\)\.S"/	include	"\1_mot.s"/' "$OUTPUT"
sed -i 's/^\.include "\(.*\)"/	include	"\1"/' "$OUTPUT"

# Convert hex numbers from 0x to $
sed -i 's/0x\([0-9a-fA-F][0-9a-fA-F]*\)/\$\1/g' "$OUTPUT"

# Remove % from register names
sed -i 's/%\([ad][0-7]\)/\1/g' "$OUTPUT"
sed -i 's/%sp/sp/g' "$OUTPUT"
sed -i 's/%pc/pc/g' "$OUTPUT"
sed -i 's/%sr/sr/g' "$OUTPUT"
sed -i 's/%ccr/ccr/g' "$OUTPUT"

# Fix immediate addressing - ensure # is used
sed -i 's/move\.\([bwl]\) \$\([0-9a-fA-F][0-9a-fA-F]*\),/move.\1 #\$\2,/g' "$OUTPUT"
sed -i 's/move\.\([bwl]\) \([0-9][0-9]*\),/move.\1 #\2,/g' "$OUTPUT"
sed -i 's/cmp\.\([bwl]\) \$\([0-9a-fA-F][0-9a-fA-F]*\),/cmp.\1 #\$\2,/g' "$OUTPUT"
sed -i 's/cmp\.\([bwl]\) \([0-9][0-9]*\),/cmp.\1 #\2,/g' "$OUTPUT"
sed -i 's/add\.\([bwl]\) \$\([0-9a-fA-F][0-9a-fA-F]*\),/add.\1 #\$\2,/g' "$OUTPUT"
sed -i 's/add\.\([bwl]\) \([0-9][0-9]*\),/add.\1 #\2,/g' "$OUTPUT"
sed -i 's/sub\.\([bwl]\) \$\([0-9a-fA-F][0-9a-fA-F]*\),/sub.\1 #\$\2,/g' "$OUTPUT"
sed -i 's/sub\.\([bwl]\) \([0-9][0-9]*\),/sub.\1 #\2,/g' "$OUTPUT"
sed -i 's/and\.\([bwl]\) \$\([0-9a-fA-F][0-9a-fA-F]*\),/and.\1 #\$\2,/g' "$OUTPUT"
sed -i 's/or\.\([bwl]\) \$\([0-9a-fA-F][0-9a-fA-F]*\),/or.\1 #\$\2,/g' "$OUTPUT"

# Fix lea instructions - they don't use # for addresses
sed -i 's/lea #\$/lea \$/g' "$OUTPUT"

# Convert .set to = or equ
sed -i 's/^\.set \([^,]*\), \(.*\)/\1 = \2/' "$OUTPUT"

# Convert section directives that might have parameters
sed -i 's/^\.section\s\+\.text/	section code/' "$OUTPUT"
sed -i 's/^\.section\s\+\.data/	section data/' "$OUTPUT"
sed -i 's/^\.section\s\+\.bss/	section bss/' "$OUTPUT"

echo "Conversion complete: $OUTPUT"
echo "Note: Manual review may still be needed for complex macros and conditional assembly."