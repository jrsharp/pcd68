#!/usr/bin/env python3
"""
Convert daj1bit.h image data to bit-packed format for PCD68 assembly program.
This script reads the GIMP-generated header file and converts the 1-bit indexed
image data into efficiently bit-packed bytes for ROM storage.
"""

import re
import sys

def parse_image_header(filename):
    """Parse the GIMP header file to extract image data."""
    with open(filename, 'r') as f:
        content = f.read()
    
    # Extract width and height
    width_match = re.search(r'static unsigned int width = (\d+);', content)
    height_match = re.search(r'static unsigned int height = (\d+);', content)
    
    if not width_match or not height_match:
        raise ValueError("Could not find width/height in header file")
    
    width = int(width_match.group(1))
    height = int(height_match.group(1))
    
    print(f"Image dimensions: {width}x{height}")
    
    # Extract the image data array
    data_start = content.find('static unsigned char header_data[] = {')
    if data_start == -1:
        raise ValueError("Could not find header_data array")
    
    # Find the closing brace
    brace_count = 0
    data_start = content.find('{', data_start)
    i = data_start
    while i < len(content):
        if content[i] == '{':
            brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                data_end = i
                break
        i += 1
    else:
        raise ValueError("Could not find end of header_data array")
    
    # Extract the data section
    data_section = content[data_start+1:data_end]
    
    # Parse the numbers
    numbers = re.findall(r'\d+', data_section)
    pixel_data = [int(n) for n in numbers]
    
    print(f"Found {len(pixel_data)} pixels")
    
    if len(pixel_data) != width * height:
        print(f"Warning: Expected {width * height} pixels, got {len(pixel_data)}")
    
    return width, height, pixel_data

def pack_bits(pixel_data):
    """Pack 1-bit pixel data into bytes (8 pixels per byte)."""
    packed_bytes = []
    
    # Process 8 pixels at a time
    for i in range(0, len(pixel_data), 8):
        byte_value = 0
        
        # Pack 8 bits into one byte (MSB first)
        for bit_pos in range(8):
            if i + bit_pos < len(pixel_data):
                pixel = pixel_data[i + bit_pos]
                # Convert to bit: 0 = black, 1 = white
                bit = 1 if pixel != 0 else 0
                byte_value |= (bit << (7 - bit_pos))
        
        packed_bytes.append(byte_value)
    
    return packed_bytes

def generate_assembly_data(packed_bytes, output_file, label_name="picture_data"):
    """Generate assembly data section with the packed image data."""
    with open(output_file, 'w') as f:
        f.write("/* Bit-packed image data for PCD68 */\n")
        f.write("/* Generated from image header file */\n")
        f.write("/* 400x300 pixels, 1 bit per pixel, packed into bytes */\n\n")
        
        f.write(".section .rodata\n")
        
        # Use the provided label name
        f.write(f"{label_name}:\n")
        
        # Write data in chunks of 16 bytes per line
        for i in range(0, len(packed_bytes), 16):
            chunk = packed_bytes[i:i+16]
            hex_values = [f"0x{byte:02X}" for byte in chunk]
            f.write(f"    .byte {', '.join(hex_values)}\n")
        
        f.write(f"\n/* Total bytes: {len(packed_bytes)} */\n")
        f.write(f"/* Original pixels: {len(packed_bytes) * 8} */\n")

def main():
    if len(sys.argv) < 2 or len(sys.argv) > 4:
        print("Usage: python3 convert_image.py <input_header_file> [output_file] [label_name]")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) >= 3 else "picture_data.S"
    label_name = sys.argv[3] if len(sys.argv) == 4 else "picture_data"
    
    try:
        # Parse the input file
        width, height, pixel_data = parse_image_header(input_file)
        
        # Pack the bits
        packed_bytes = pack_bits(pixel_data)
        
        print(f"Packed {len(pixel_data)} pixels into {len(packed_bytes)} bytes")
        print(f"Compression ratio: {len(pixel_data)}/{len(packed_bytes)} = {len(pixel_data)/len(packed_bytes):.1f}:1")
        
        # Generate assembly output
        generate_assembly_data(packed_bytes, output_file, label_name)
        
        print(f"Generated assembly data in {output_file} with label '{label_name}'")
        
        # Also generate a C-style array for verification
        c_output = "picture_data.h"
        with open(c_output, 'w') as f:
            f.write("/* Bit-packed image data for verification */\n")
            f.write(f"#define PICTURE_WIDTH {width}\n")
            f.write(f"#define PICTURE_HEIGHT {height}\n")
            f.write(f"#define PICTURE_DATA_SIZE {len(packed_bytes)}\n\n")
            f.write(f"static const unsigned char {label_name}[] = {{\n")
            
            for i in range(0, len(packed_bytes), 16):
                chunk = packed_bytes[i:i+16]
                hex_values = [f"0x{b:02X}" for b in chunk]
                f.write(f"    {', '.join(hex_values)}")
                if i + 16 < len(packed_bytes):
                    f.write(",")
                f.write("\n")
            
            f.write("};\n")
        
        print(f"Also generated C header in {c_output}")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 