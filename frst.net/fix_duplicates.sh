#!/bin/sh
# Remove duplicate symbol definitions and fix remaining syntax issues

INPUT="$1"
if [ -z "$INPUT" ]; then
    echo "Usage: $0 filename.s"
    exit 1
fi

echo "Fixing duplicates and syntax issues in $INPUT..."

# Create temp file
TEMP="${INPUT}.tmp"
cp "$INPUT" "$TEMP"

# Remove duplicate KEY definitions (keep only the first occurrence)
awk '
/^KEY_ENTER[[:space:]]+equ/ { if (!seen_key_enter) { print; seen_key_enter=1 } next }
/^KEY_ESC[[:space:]]+equ/ { if (!seen_key_esc) { print; seen_key_esc=1 } next }
/^KEY_BACKSPACE[[:space:]]+equ/ { if (!seen_key_backspace) { print; seen_key_backspace=1 } next }
{ print }
' "$TEMP" > "$INPUT"

# Fix any remaining .rept/.endr that weren't converted
sed -i 's/^[[:space:]]*\.rept \(.*\)/	rept	\1/' "$INPUT"
sed -i 's/^[[:space:]]*\.endr/	endr/' "$INPUT"

# Fix any remaining .org that weren't converted
sed -i 's/^[[:space:]]*\.org \(.*\)/	org	\1/' "$INPUT"

# Fix any remaining .equ that weren't converted
sed -i 's/^[[:space:]]*\.equ \([^,]*\), \(.*\)/\1	equ	\2/' "$INPUT"

# Remove temp file
rm "$TEMP"

echo "Fixed: $INPUT"