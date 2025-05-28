#!/usr/bin/env python3
"""
Convert GIMP header file to binary format for PCD-68 picture mode
"""

import re
import sys

def convert_header_to_binary(header_file, output_file):
    """Convert GIMP header file to binary format"""
    
    with open(header_file, 'r') as f:
        content = f.read()
    
    # Extract width and height
    width_match = re.search(r'static unsigned int width = (\d+);', content)
    height_match = re.search(r'static unsigned int height = (\d+);', content)
    
    if not width_match or not height_match:
        print("Error: Could not find width/height in header file")
        return False
    
    width = int(width_match.group(1))
    height = int(height_match.group(1))
    
    print(f"Image dimensions: {width}x{height}")
    
    # Extract the data array
    data_match = re.search(r'static unsigned char header_data\[\] = \{([^}]+)\};', content, re.DOTALL)
    
    if not data_match:
        print("Error: Could not find header_data array")
        return False
    
    data_str = data_match.group(1)
    
    # Parse the data values
    data_values = []
    for match in re.finditer(r'\b(\d+)\b', data_str):
        data_values.append(int(match.group(1)))
    
    print(f"Found {len(data_values)} data values")
    
    # Verify we have the expected amount of data
    expected_size = width * height
    if len(data_values) != expected_size:
        print(f"Warning: Expected {expected_size} values, got {len(data_values)}")
    
    # Write binary file
    with open(output_file, 'wb') as f:
        for value in data_values:
            f.write(bytes([value]))
    
    print(f"Converted to binary file: {output_file}")
    return True

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 convert_artwork.py input.h output.bin")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    if convert_header_to_binary(input_file, output_file):
        print("Conversion successful!")
    else:
        print("Conversion failed!")
        sys.exit(1) 