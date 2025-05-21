JonSharp.net -- as a demonstration ROM for the PCD-68 virtual retro computer.
==========

## Overview

The JonSharp.net Cyberterminal is a ROM image for the PCD-68 retro computer emulator (as realized in the FRST Computer Model 1 Cyberterminal) that provides a gopher-like interface to access information about Jon Sharp, his projects, and other content.
It is meant to be a fully-functional personal website experience, showcasing the bespoke personal computer environment of PCD-68 and FRST Computer.

## Features

- **Two-Tier Menu System**: Main menus and submenus provide hierarchical content organization
- **Single-Key Navigation**: Use single keystrokes to navigate between menus and content
- **Human-Editable Content**: Content is stored in Markdown files that can be easily edited
- **YAML-Based Menu Structure**: Define menu hierarchies in a simple YAML format
- **Build-Time Content Generation**: Content is processed during build to create efficient assembly code

## Directory Structure

- `content/`: Contains all the content files and menu structure
  - `menu_structure.yaml`: Defines the menu hierarchy
  - `_index.md`: Main menu content
  - `about/`, `projects/`, etc.: Subdirectories for each section
- `tools/`: Contains the processing tools
  - `menu2asm.py`: Converts YAML/Markdown to assembly code

## Content System Architecture

The cyberterminal uses a multi-stage pipeline to convert human-editable content into an efficient assembly-based menu system:

1. **Content Definition**: Menu structures defined in YAML and content written in Markdown
2. **Build Processing**: Python tools convert these files into assembly structures
3. **Runtime Navigation**: Assembly code handles keyboard input and content display

### Data Structures

The system uses these key data structures:

#### Menu Table (In Assembly)
- Array of pointers to menu definitions
- Each entry represents a different menu (main menu, about, projects, etc.)
- Indexed by menu ID (0 for main menu, 1 for about, etc.)

#### Menu Definition Structures
- Title pointer: Points to the menu's title string
- Item count: Number of items in this menu
- Items array pointer: Points to array of menu item structures

#### Menu Item Structures
- Title pointer: Points to the item's title string
- Type: SUBMENU (0), CONTENT (1), or LINK (2)
- Key: ASCII value of the key that selects this item
- Target: Menu ID for submenus, content ID for content items

#### Content Text Pointers
- Table of pointers to content text
- Accessed using a content ID
- Contains the actual text to display

### Code Generation Pipeline

1. **Python Processing**:
   - `menu2asm.py` reads `menu_structure.yaml` and content files
   - Generates assembly code with menu structures and content
   - Creates key handler code based on menu navigation

2. **Assembly Files Generated**:
   
   - Menu structures are integrated into the ROM image

3. **Global Variables**:
   - `current_menu_id`: Currently displayed menu (0-based index)
   - `current_selection`: Selected item in current menu
   - `view_state`: 0 for menu view, 1 for content view
   - `display_needs_update`: Flag to trigger screen refresh
   - `navigation_stack`: History of visited menus for back navigation

## Keyboard Input Flow

The keyboard input system follows this flow:

1. **Hardware Interrupt**: Keyboard controller (at 0x420000) triggers an interrupt
2. **Keyboard Handler**: Reads key from keyboard controller registers
3. **process_keyboard_input**: 
   - Gets keystroke from keyboard buffer
   - Stores key code in register D6 for display
   - Calls `process_keystroke` function

4. **process_keystroke**:
   - Handles navigation keys (h, b, ?, q)
   - Routes to menu-specific handlers based on current_menu_id
   - Uses branch table to efficiently handle different keys

5. **Menu Selection Processing**:
   - For SUBMENU items: Pushes current menu to navigation stack, navigates to submenu
   - For CONTENT items: Sets view_state to 1, loads content pointer
   - For LINK items: (Currently displays "link unavailable" message)

6. **Display Update**:
   - Sets display_needs_update flag
   - Main loop checks this flag and refreshes screen when needed

## Navigation

The cyberterminal uses single-key navigation:

- `h` - Return to home/main menu
- `b` - Go back to parent menu (pops from navigation stack)
- `?` - Display help
- `q` - Quit application
- Single keys (1-9) - Select menu items or navigate to content

### Menu to Content Relationship

When a content item is selected:
1. `process_text` function is called
2. `get_content_pointer` retrieves the content text pointer
3. `view_state` is set to 1 (content view)
4. Screen is updated to display content

## Build Process

The content generation process is integrated into the build:

1. `menu2asm.py` processes YAML and Markdown files
2. Assembly code is generated for:
   - Menu structures and content text
   - Key handlers for navigation
   - Content pointer lookup functions
3. Generated files are assembled with the rest of the ROM

## Debugging Menu Navigation

If you encounter issues with menu navigation:

1. **Check menu_structures.S**: Ensure it's properly generated with all menu items
2. **Examine current_menu_id and view_state**: These variables control what's displayed
3. **Watch keyboard input**: Debug messages appear on the status line
4. **Check display_needs_update flag**: Must be set to trigger screen refresh

## Customizing Content

1. Edit files in the `content/` directory
2. Ensure menu_structure.yaml properly references your content files
3. Run `make.sh` to build the ROM with updated content
4. Test the ROM in the PCD-68 emulator

## Dependencies

- Python 3
- PyYAML library (`pip install pyyaml`)
- GNU M68K toolchain
