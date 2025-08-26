#!/bin/sh
# Fix vasm Motorola syntax spacing requirements

if [ $# -eq 0 ]; then
    echo "Usage: $0 file1.s [file2.s ...]"
    exit 1
fi

for FILE in "$@"; do
    echo "Fixing vasm spacing in: $FILE"
    
    # Remove spaces after commas in operands
    sed -i 's/, /,/g' "$FILE"
    
    # Fix specific patterns that need spacing fixes
    sed -i 's/\t /\t/g' "$FILE"
    
    echo "Fixed spacing in: $FILE"
done