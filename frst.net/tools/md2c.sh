#!/bin/bash
# md2c.sh - Convert markdown directory structure to C header
# For PCD-68 cyberterminal content system

# Usage: ./md2c.sh <content_dir> <output_header>
# Example: ./md2c.sh content/ cyberterminal_content.h

set -e

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <content_dir> <output_header>"
    exit 1
fi

CONTENT_DIR="${1%/}" # Remove trailing slash if present
OUTPUT_HEADER="$2"
TEMP_DIR=$(mktemp -d)

# Ensure content directory exists
if [ ! -d "$CONTENT_DIR" ]; then
    echo "Error: Content directory '$CONTENT_DIR' not found"
    exit 1
fi

# Menu ID counter (used to assign unique IDs)
MENU_ID=0
# Array to store all content files
declare -a CONTENT_FILES
# Array to store all menu definitions
declare -a MENU_DEFS

# Function to escape C string
escape_c_string() {
    # Replace backslashes, quotes, and special chars
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g'
}

# Function to extract frontmatter from markdown
extract_frontmatter() {
    local file="$1"
    # Extract content between --- markers
    sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d' > "$TEMP_DIR/frontmatter.tmp"
}

# Function to extract content from markdown (stripping frontmatter)
extract_content() {
    local file="$1"
    # Skip frontmatter and get the rest
    sed '1,/^---$/d' "$file" | sed '1,/^---$/d' > "$TEMP_DIR/content.tmp"
}

# Function to get a field from frontmatter
get_frontmatter_field() {
    local field="$1"
    grep -E "^$field:" "$TEMP_DIR/frontmatter.tmp" | sed "s/^$field: *//g" | tr -d '\r' | tr -d '"' || echo ""
}

# Process a single markdown file and return content_id
process_markdown_file() {
    local file="$1"
    local file_basename=$(basename "$file")
    local content_id=${#CONTENT_FILES[@]}
    
    # Extract frontmatter and content
    extract_frontmatter "$file"
    extract_content "$file"
    
    # Get frontmatter fields
    local title=$(get_frontmatter_field "title")
    local order=$(get_frontmatter_field "order")
    local type=$(get_frontmatter_field "type")
    
    # Default values if not specified
    [ -z "$title" ] && title=$(basename "$file" .md)
    [ -z "$order" ] && order="999"  # Default to end of list
    [ -z "$type" ] && type="content"
    
    # Skip if it's an index file - we handle those separately
    if [ "$file_basename" = "_index.md" ]; then
        return 255
    fi
    
    # Read the content and escape it for C
    local content=$(cat "$TEMP_DIR/content.tmp")
    local escaped_content=$(escape_c_string "$content")
    local escaped_title=$(escape_c_string "$title")
    
    # Add to content files array
    CONTENT_FILES+=("{ \"$escaped_title\", \"$type\", $order, \"$escaped_content\" }")
    
    # Return the content ID
    echo $content_id
}

# Process a directory to create a menu
process_directory() {
    local dir="$1"
    local parent_id="$2"
    local current_menu_id=$MENU_ID
    
    echo "Processing directory: $dir (Menu ID: $current_menu_id)" >&2
    
    # Increment menu ID for next use
    MENU_ID=$((MENU_ID + 1))
    
    # Find index file
    local index_file="$dir/_index.md"
    local title=""
    local index_content=""
    
    # If index file exists, extract info from it
    if [ -f "$index_file" ]; then
        extract_frontmatter "$index_file"
        title=$(get_frontmatter_field "title")
        
        # Extract content
        extract_content "$index_file"
        index_content=$(cat "$TEMP_DIR/content.tmp")
        index_content=$(escape_c_string "$index_content")
    else
        # Default title from directory name
        title=$(basename "$dir")
    fi
    
    title=$(escape_c_string "$title")
    
    # Array for menu items
    declare -a menu_items
    
    # Process all markdown files except _index.md in this directory
    for md_file in "$dir"/*.md; do
        if [ -f "$md_file" ] && [ "$(basename "$md_file")" != "_index.md" ]; then
            # Get frontmatter info
            extract_frontmatter "$md_file"
            local item_title=$(get_frontmatter_field "title")
            local item_order=$(get_frontmatter_field "order")
            local item_type=$(get_frontmatter_field "type")
            
            [ -z "$item_title" ] && item_title=$(basename "$md_file" .md)
            [ -z "$item_order" ] && item_order="999"
            [ -z "$item_type" ] && item_type="content"
            
            item_title=$(escape_c_string "$item_title")
            
            # Process file and get content ID
            local item_id=$(process_markdown_file "$md_file")
            
            # Add to menu items
            menu_items+=("{ \"$item_title\", \"$item_type\", $item_order, $item_id }")
        fi
    done
    
    # Process subdirectories (each becomes a submenu)
    for subdir in "$dir"/*/; do
        if [ -d "$subdir" ]; then
            local subdir_id=$MENU_ID
            local subdir_title=$(basename "${subdir%/}") # Remove trailing slash
            
            # Check for index in subdir
            if [ -f "${subdir}_index.md" ]; then
                extract_frontmatter "${subdir}_index.md"
                local sd_title=$(get_frontmatter_field "title")
                local sd_order=$(get_frontmatter_field "order")
                
                [ -n "$sd_title" ] && subdir_title="$sd_title"
                [ -z "$sd_order" ] && sd_order="999"
            else
                sd_order="999"
            fi
            
            subdir_title=$(escape_c_string "$subdir_title")
            
            # Add submenu as item in current menu
            menu_items+=("{ \"$subdir_title\", \"submenu\", $sd_order, $subdir_id }")
            
            # Process the subdirectory
            process_directory "$subdir" $current_menu_id
        fi
    done
    
    # Sort menu items by order
    IFS=$'\n' sorted_items=($(
        for item in "${menu_items[@]}"; do
            # Extract order field (position 2) using regex
            order=$(echo "$item" | grep -o '"[^"]*", "[^"]*", [0-9]*, ' | sed 's/.*", ".*", \([0-9]*\), .*/\1/')
            echo "$order|$item"
        done | sort -n | cut -d'|' -f2-
    ))
    unset IFS
    
    # Generate menu definition
    local menu_def="{\n"
    menu_def+="    $current_menu_id, /* menu_id */\n"
    menu_def+="    $parent_id, /* parent_id */\n"
    menu_def+="    \"$title\", /* title */\n"
    menu_def+="    \"$index_content\", /* content */\n"
    menu_def+="    ${#sorted_items[@]}, /* item_count */\n"
    menu_def+="    { /* items */\n"
    
    for item in "${sorted_items[@]}"; do
        menu_def+="        $item,\n"
    done
    
    menu_def+="    }\n"
    menu_def+="}"
    
    # Add to menu definitions array
    MENU_DEFS+=("$menu_def")
    
    # Return the current menu ID
    return $current_menu_id
}

# Start generating the header file
cat > "$OUTPUT_HEADER" << EOH
/* 
 * Generated Cyberterminal Content
 * DO NOT EDIT - This file is automatically generated by md2c.sh
 */

#ifndef CYBERTERMINAL_CONTENT_H
#define CYBERTERMINAL_CONTENT_H

/* Content item structure */
typedef struct {
    const char* title;
    const char* type;
    int order;
    const char* content;
} ContentItem;

/* Menu item structure */
typedef struct {
    const char* title;
    const char* type;
    int order;
    int target_id;
} MenuItem;

/* Menu structure */
typedef struct {
    int id;
    int parent_id;
    const char* title;
    const char* content;
    int item_count;
    MenuItem items[20]; /* Max 20 items per menu */
} Menu;

EOH

# Process the content directory
process_directory "$CONTENT_DIR" -1
ROOT_MENU_ID=$?

# Add content items to the header
cat >> "$OUTPUT_HEADER" << EOH
/* Content Items */
#define CONTENT_ITEM_COUNT ${#CONTENT_FILES[@]}
const ContentItem content_items[CONTENT_ITEM_COUNT] = {
EOH

for content in "${CONTENT_FILES[@]}"; do
    echo "    $content," >> "$OUTPUT_HEADER"
done

# Close content items
cat >> "$OUTPUT_HEADER" << EOH
};

/* Menu Definitions */
#define MENU_COUNT ${#MENU_DEFS[@]}
#define ROOT_MENU_ID $ROOT_MENU_ID
const Menu menus[MENU_COUNT] = {
EOH

for menu in "${MENU_DEFS[@]}"; do
    echo -e "    $menu," >> "$OUTPUT_HEADER"
done

# Close the header
cat >> "$OUTPUT_HEADER" << EOH
};

#endif /* CYBERTERMINAL_CONTENT_H */
EOH

# Clean up
rm -rf "$TEMP_DIR"

echo "Content successfully processed!"
echo "Generated header: $OUTPUT_HEADER"
echo "Total menus: ${#MENU_DEFS[@]}"
echo "Total content items: ${#CONTENT_FILES[@]}"