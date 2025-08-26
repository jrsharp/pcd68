#!/bin/sh
# Fix syntax issues in converted assembly files for vasm

INPUT="$1"
if [ -z "$INPUT" ]; then
    echo "Usage: $0 filename.s"
    exit 1
fi

echo "Fixing syntax issues in $INPUT..."

# Fix section directives with parameters
sed -i 's/^\.section \.text.*$/	section code/' "$INPUT"
sed -i 's/^\.section \.data.*$/	section data/' "$INPUT"
sed -i 's/^\.section \.bss.*$/	section bss/' "$INPUT"

# Fix instruction syntax - vasm doesn't like concatenated move instructions
sed -i 's/moveal/move.l/g' "$INPUT"
sed -i 's/moveb/move.b/g' "$INPUT"
sed -i 's/movel/move.l/g' "$INPUT"
sed -i 's/movew/move.w/g' "$INPUT"

# Fix other concatenated instructions
sed -i 's/cmpb/cmp.b/g' "$INPUT"
sed -i 's/cmpl/cmp.l/g' "$INPUT"
sed -i 's/cmpw/cmp.w/g' "$INPUT"
sed -i 's/addb/add.b/g' "$INPUT"
sed -i 's/addl/add.l/g' "$INPUT"
sed -i 's/addw/add.w/g' "$INPUT"
sed -i 's/subb/sub.b/g' "$INPUT"
sed -i 's/subl/sub.l/g' "$INPUT"
sed -i 's/subw/sub.w/g' "$INPUT"
sed -i 's/andb/and.b/g' "$INPUT"
sed -i 's/andl/and.l/g' "$INPUT"
sed -i 's/andw/and.w/g' "$INPUT"
sed -i 's/orb/or.b/g' "$INPUT"
sed -i 's/orl/or.l/g' "$INPUT"
sed -i 's/orw/or.w/g' "$INPUT"
sed -i 's/tstb/tst.b/g' "$INPUT"
sed -i 's/tstl/tst.l/g' "$INPUT"
sed -i 's/tstw/tst.w/g' "$INPUT"
sed -i 's/clrb/clr.b/g' "$INPUT"
sed -i 's/clrl/clr.l/g' "$INPUT"
sed -i 's/clrw/clr.w/g' "$INPUT"

# Fix branch instructions
sed -i 's/jsr /jsr	/g' "$INPUT"
sed -i 's/jmp /jmp	/g' "$INPUT"
sed -i 's/bsr /bsr	/g' "$INPUT"
sed -i 's/bra /bra	/g' "$INPUT"

# Fix conditional branches
sed -i 's/beq /beq	/g' "$INPUT"
sed -i 's/bne /bne	/g' "$INPUT"
sed -i 's/blt /blt	/g' "$INPUT"
sed -i 's/bgt /bgt	/g' "$INPUT"
sed -i 's/ble /ble	/g' "$INPUT"
sed -i 's/bge /bge	/g' "$INPUT"
sed -i 's/bcc /bcc	/g' "$INPUT"
sed -i 's/bcs /bcs	/g' "$INPUT"
sed -i 's/bpl /bpl	/g' "$INPUT"
sed -i 's/bmi /bmi	/g' "$INPUT"

echo "Fixed syntax in: $INPUT"