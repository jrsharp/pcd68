#!/bin/sh
# Final fixes for vasm compatibility

for file in utility_functions_mot.s aether_modem_mot.s content_single_mot.s; do
    echo "Final fixes for $file"
    
    # Fix broken comments (restore spaces after critical words)
    sed -i 's/withoutadvancing/without advancing/g' "$file"
    sed -i 's/nextline/next line/g' "$file"
    sed -i 's/textpointer/text pointer/g' "$file"
    sed -i 's/artmode/art mode/g' "$file"
    sed -i 's/textmode/text mode/g' "$file"
    sed -i 's/artproject/art project/g' "$file"
    sed -i 's/firstplace/first place/g' "$file"
    sed -i 's/bestway/best way/g' "$file"
    sed -i 's/contentmatters/content matters/g' "$file"
    sed -i 's/butwith/but with/g' "$file"
    sed -i 's/like the web,but/like the web, but/g' "$file"
    sed -i 's/presentati	on,where/presentation, where/g' "$file"
    
    # Fix section directives that broke
    sed -i 's/^\.section \.rodata.*$/	section rodata,data/' "$file"
    sed -i 's/^section \.rodata.*$/	section rodata,data/' "$file"
    
    echo "Fixed $file"
done

echo "All files fixed"