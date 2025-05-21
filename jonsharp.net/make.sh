#!/bin/bash -xe

# Create tools directory if it doesn't exist
mkdir -p tools/output

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required for menu generation"
    echo "Using fallback menu structures"
else
    # Check if PyYAML is installed
    if python3 -c "import yaml" 2>/dev/null; then
        # Generate menu structures from YAML and Markdown content
        echo "Generating menu structures from content..."
        if python3 tools/menu2asm.py content/menu_structure.yaml content/ --output-dir tools/output; then
            # Make sure generated assembly files are included in the build
            if [ -f "tools/output/menu_structures.S" ]; then
                echo "Menu structures generated successfully"
                MENU_DEFINE="tools/output/menu_structures.S"
            fi
        else
            echo "Warning: Menu generation failed"
            echo "Using fallback menu structures"
            MENU_DEFINE=""
        fi
    else
        echo "Warning: PyYAML not installed, required for menu generation"
        echo "Using fallback menu structures"
        MENU_DEFINE=""
    fi
fi

# Compile with real error checking
# If menu generation succeeded, include the generated files directly
if [ -n "$MENU_DEFINE" ] && [ -f "tools/output/menu_structures.S" ]; then
    echo "Using generated menu structures"
    # Use the generated files with the define
    m68k-elf-g++ -O0 -s -g -o pcd68home pcd68home.S utility_functions.S $MENU_DEFINE -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -T pcd68.lds
else
    echo "Using built-in menu structures"
    # Don't use the generated files, build with the fallback 
    m68k-elf-g++ -O0 -s -g -o pcd68home pcd68home.S utility_functions.S -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -T pcd68.lds
fi

# Generate the binary files
m68k-elf-objcopy -O binary pcd68home program.bin
m68k-elf-objcopy -O ihex pcd68home program.hex

echo "Build completed successfully"

