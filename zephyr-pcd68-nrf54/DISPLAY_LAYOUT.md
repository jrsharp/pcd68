# PCD68 Model 4 CyberTerminal Display Layout

## ST7796S 4" 480x320 Display Rendering

The Model 4 CyberTerminal preserves the original PCD68 400x300 framebuffer specification by centering it on the larger 480x320 ST7796S display, creating decorative borders inspired by the Super Game Boy.

```
┌─────────────────────────────────────────────────────────────────┐
│                    ST7796S 480x320 Display                     │
├─────────────────────────────────────────────────────────────────┤
│ ↑10px │                                              │ ↑10px  │
│ ┌─────┴────────────────────────────────────────────┴─────┐    │
│ │40px │               PCD68 Core                   │40px │    │
│ │     │              400x300                       │     │    │
│ │     │        ┌─────────────────────┐             │     │    │
│ │  P  │        │                     │             │  P  │    │
│ │  A  │        │   68000 Emulation   │             │  A  │    │
│ │  T  │        │     Display         │             │  T  │    │
│ │  T  │        │                     │             │  T  │    │
│ │  E  │        │  • Text Mode:       │             │  E  │    │
│ │  R  │        │    80x50 or 80x25   │             │  R  │    │
│ │  N  │        │    characters       │             │  N  │    │
│ │     │        │                     │             │     │    │
│ │     │        │  • Graphics Mode:   │             │     │    │
│ │     │        │    400x300 B/W      │             │     │    │
│ │     │        │    1-bit pixels     │             │     │    │
│ │     │        │                     │             │     │    │
│ │     │        └─────────────────────┘             │     │    │
│ └─────┬────────────────────────────────────────────┬─────┘    │
│       ↓10px                                        ↓10px      │
└─────────────────────────────────────────────────────────────────┘
```

## Border Design

The decorative border consists of three layers:

### Inner Border (0-2 pixels from PCD68 area)
- **Color**: Cyan accent (`0x39E7`)
- **Purpose**: Visual frame for the PCD68 display area
- **Inspiration**: Classic terminal bezel

### Frame Layer (2-4 pixels from PCD68 area)  
- **Color**: Dark blue-gray (`0x18C3`)
- **Purpose**: Creates depth and separation
- **Inspiration**: 80s computer monitor styling

### Outer Pattern (4+ pixels from PCD68 area)
- **Colors**: Purple-gray checkerboard (`0x2104` / `0x4A69`)
- **Pattern**: 6x6 pixel checkerboard
- **Purpose**: Decorative texture
- **Inspiration**: Super Game Boy aesthetic

## Technical Implementation

### Coordinate Mapping
```cpp
// Center calculation for 400x300 on 480x320
const int border_x = (480 - 400) / 2;  // 40px left/right
const int border_y = (320 - 300) / 2;  // 10px top/bottom

// PCD68 pixel (src_x, src_y) maps to:
int dest_x = border_x + src_x;  // 40 + src_x
int dest_y = border_y + src_y;  // 10 + src_y
```

### Rendering Pipeline
1. **Clear Display**: Fill entire 480x320 buffer with border pattern
2. **Generate Borders**: Create layered decorative pattern in unused area
3. **Render PCD68**: Convert 1-bit monochrome to RGB565 in center
4. **Display Update**: Send complete framebuffer to ST7796S

### Performance Characteristics
- **Border Generation**: ~38,400 pixels (480×320 - 400×300)
- **PCD68 Core**: 120,000 pixels (400×300)
- **Color Format**: RGB565 (2 bytes per pixel)
- **Total Buffer**: 307,200 bytes (480×320×2)

## Visual Result

The Model 4 CyberTerminal displays the PCD68's retro computing experience perfectly centered with an authentic 80s aesthetic border, preserving the original 400x300 specification while utilizing the full beautiful 4-inch color display!