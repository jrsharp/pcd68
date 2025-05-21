# JonSharp.net Cyberterminal Content

## Overview

This directory contains the content for the JonSharp.net cyberterminal. The content is organized in a hierarchical structure using a combination of YAML and Markdown files.

## Structure

- `menu_structure.yaml` - Defines the overall menu hierarchy and navigation
- `_index.md` - Main menu content and description
- Subdirectories contain content for specific sections (about, projects, etc.)

## Adding or Modifying Content

### Menu Structure

The `menu_structure.yaml` file defines the menu hierarchy. Each menu has:

- A unique ID
- A title
- A key prefix (for submenus)
- Parent menu reference (for submenus)
- List of menu items

Each menu item has:

- A unique ID
- A title
- A single-key shortcut (a-z, 0-9)
- Type (submenu or content)
- Order (for sorting)
- Content file path (for content items)

Example:

```yaml
main_menu:
  title: "Main Menu"
  key_prefix: ""  # No prefix for top-level menu
  items:
    - id: "about"
      title: "About Jon Sharp"
      key: "a"
      type: "submenu"
      order: 1
    - id: "projects"
      title: "Projects"
      key: "p"
      type: "submenu"
      order: 2
```

### Content Files

Content is written in Markdown with YAML frontmatter. Each content file must include:

- `title` - The display title
- `key` - The single-key shortcut
- `type` - Usually "content"
- `order` - For sorting in menus

Example:

```markdown
---
title: PCD-68 Computer
key: c
type: content
order: 1
---

# PCD-68 Computer

Content goes here...

[Press 'b' to return to Projects menu]
[Press 'h' to return to Main menu]
```

## Navigation

The cyberterminal uses single-key navigation:

- `h` - Return to home/main menu from anywhere
- `b` - Go back to parent menu
- `?` - Display help (if implemented)
- Single keys (as defined in menu items) to navigate to submenus or view content

## Build Process

The content is processed during the build:

1. `tools/menu2asm.py` processes the YAML and Markdown files
2. Assembly code is generated for menu structures and key handlers
3. The generated code is included in the ROM build

To build:

```bash
cd jonsharp.net
./make.sh
```

## Adding New Sections

To add a new section:

1. Add the new menu to `menu_structure.yaml`
2. Create a directory for the section's content
3. Create an `_index.md` file in that directory
4. Add content files as needed
5. Update parent menu references in the YAML 
