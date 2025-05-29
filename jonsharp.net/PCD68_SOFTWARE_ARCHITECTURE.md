# 🏗️ **PCD-68 Software Architecture Design Document**
*Derived from the jonsharp.net ROM - First Working Interactive System*

## 📋 **Executive Summary**

The jonsharp.net ROM represents the **first fully functional interactive software** for the PCD-68 platform. This document extracts the proven architectural patterns and essential routines to establish a foundation for future PCD-68 software development and a standardized "PCD-68 Toolbox."

---

## 🔧 **Core Hardware Abstraction Layer**

### **Memory Map Constants**
```assembly
.equ TDABase, 0x410000      /* Terminal Display Adapter */
.equ KCTLBase, 0x420000     /* Keyboard Controller */
.equ UARTBase, 0x450000     /* Serial Communications */
.equ ScrnBase, 0x810000     /* Screen Buffer */
```

### **Display Constants**
```assembly
.equ ScreenWidth, 80
.equ ScreenHeight, 23
.equ TextMode, 2            /* 80-column mode */
```

### **KCTL Register Definitions** ⭐
```assembly
.equ KCTLStatus, 0x420000      /* Status/control register */
.equ KCTLCount, 0x420001       /* Reports in queue */
.equ KCTLReportSize, 0x420002  /* Active keys in current report */
.equ KCTLKeys, 0x420004        /* Key array (7 bytes) */
.equ KCTLNextReport, 0x42000B  /* Advance to next report */

/* Status bits */
.equ STATUS_REPORT_AVAILABLE, 0x01
.equ STATUS_QUEUE_FULL, 0x02
.equ STATUS_KEYBOARD_ENABLED, 0x08
```

---

## ⌨️ **Keyboard Input Management** ⭐

### **Core Input Loop Pattern**
```assembly
keyboard_check:
    /* 1. Ensure controller enabled */
    moveb   KCTLStatus, %d0
    btst    #3, %d0
    bne     check_queue_status
    orib    #STATUS_KEYBOARD_ENABLED, %d0
    moveb   %d0, KCTLStatus

check_queue_status:
    /* 2. Handle queue full condition */
    moveb   KCTLStatus, %d0
    btst    #1, %d0
    beq     check_debounce
    /* Clear full queue aggressively */
clear_queue_loop:
    moveb   #1, KCTLNextReport
    moveb   KCTLStatus, %d0
    btst    #1, %d0
    bne     clear_queue_loop

check_debounce:
    /* 3. Debounce timing (50 cycles proven optimal) */
    cmpl    #0, key_debounce_timer
    beq     process_input
    subil   #1, key_debounce_timer
    rts

process_input:
    /* 4. Read and process key */
    moveb   KCTLCount, %d0
    cmpl    #0, %d0
    beq     no_input
    moveb   KCTLKeys, %d0     /* Get first key */
    /* Process key... */
    jsr     finish_key_input

finish_key_input:
    /* 5. Consume ALL reports aggressively */
consume_all:
    moveb   KCTLCount, %d0
    cmpl    #0, %d0
    beq     all_consumed
    moveb   #1, KCTLNextReport
    bra     consume_all
all_consumed:
    movel   #50, key_debounce_timer
```

### **Key Processing Wrapper Pattern**
```assembly
/* Always wrap key functions to ensure report consumption */
process_key_help:
    jsr     key_help
    bra     finish_key_input
```

---

## 🖥️ **Display Management System**

### **Screen Layout Framework** 
```
Line 0:   +---- Top Border ----+
Line 1:   | Header (Title)     |
Line 2:   | Header (Subtitle)  |  
Line 3:   \---- Header Border --\
Lines 4-17: Content Area (14 lines)
Line 18:  .---- Content Border --.
Line 19:  | Status/Debug Line  |
Line 20:  +---- Status Border --+
Line 21:  | Command Footer     |
Line 22:  +---- Bottom Border --+
```

### **Essential Display Functions**
```assembly
/* Core display routines */
clear_screen()              /* Full screen clear */
clear_content_area()        /* Clear lines 4-17 only */
draw_borders()              /* Draw all border lines */
draw_header()               /* Header with title/version */
draw_footer()               /* Command line */
draw_status()               /* Debug/status information */

/* Text rendering */
print_string()              /* Basic null-terminated string */
print_multiline_string()    /* Handles \n properly */
print_string_no_advance()   /* No cursor advancement */
center_text()               /* Centered text placement */
```

### **Anti-Flicker Refresh Pattern**
```assembly
display_refresh:
    cmpl    #1, display_needs_update
    bne     skip_refresh
    cmpl    #1, refresh_lock
    bne     perform_refresh
    /* Check for key override */
    cmpl    #0, current_key
    beq     skip_refresh

perform_refresh:
    movel   #1, refresh_lock
    jsr     clear_content_area
    jsr     draw_content_area
    jsr     draw_status
    /* Delay before unlock */
    movel   #10000, %d0
delay_loop:
    subil   #1, %d0
    bne     delay_loop
    movel   #0, refresh_lock
```

---

## 🏛️ **Application Framework Architecture**

### **Main Loop Pattern**
```assembly
main_loop:
    /* 1. Debug/monitoring */
    jsr     update_main_loop_indicator
    
    /* 2. Keyboard processing */
    jsr     keyboard_check
    
    /* 3. Display management */
    jsr     display_refresh
    
    /* 4. System timing */
    jsr     main_loop_delay
    
    /* 5. Periodic tasks */
    jsr     periodic_updates
    
    bra     main_loop
```

### **View State Management**
```assembly
/* View states */
.equ VIEW_MENU, 0
.equ VIEW_CONTENT, 1
.equ VIEW_HELP, 2

/* State variables */
view_state:              .dc.l    0
current_menu_id:         .dc.l    0
current_selection:       .dc.l    0
display_needs_update:    .dc.l    0
```

### **Navigation Stack System**
```assembly
navigation_stack:        .ds.l    16  /* Max 16 levels */
navigation_stack_pos:    .dc.l    0

/* Navigation functions */
push_menu_to_stack()     /* Save current location */
pop_menu_from_stack()    /* Return to previous */
reset_navigation()       /* Return to root */
```

---

## 🛠️ **Utility Function Library**

### **String and Text Processing**
```assembly
/* Text output */
print_string(a5=text, a2=position)
print_multiline_string(a5=text, a2=position)  /* Handles \n */
print_string_no_advance(a5=text, a2=position)
center_text(a5=text, a2=line_start)

/* Screen management */
clear_screen()
clear_content_area()
position_cursor(d0=line, d1=column) -> a2
calculate_screen_position(d0=line, d1=column) -> a2
```

### **Debug and Monitoring**
```assembly
/* Debug trace system */
add_debug_trace(d0=character)    /* Add to trace buffer */
draw_status()                    /* Comprehensive status line */
update_status_line()             /* Legacy compatibility */

/* Performance monitoring */
main_loop_counter               /* Loop iteration tracking */
keyboard_event_counter          /* Input event counting */
```

### **Data Structure Helpers**
```assembly
/* Menu system */
get_menu_title(d0=menu_id) -> a0
get_menu_item_count(d0=menu_id) -> d0
get_menu_item_text(d0=menu_id, d1=item_index) -> a0
get_menu_entry_type(d0=menu_id, d1=item_index) -> d0

/* Content management */
get_content_pointer(d0=menu_id, d1=item_index) -> a0
```

---

## 📊 **Data Structure Standards**

### **Menu Definition Format**
```assembly
menu_definition:
    .dc.l   title_ptr           /* Menu title string */
    .dc.w   item_count          /* Number of items */
    .dc.w   reserved            /* Alignment padding */
    .dc.l   items_array_ptr     /* Pointer to item array */

menu_item:
    .dc.l   text_ptr            /* Display text */
    .dc.b   type               /* SUBMENU/TEXT/LINK */
    .dc.b   padding            /* Alignment */
    .dc.w   target_data        /* Menu ID or content index */
```

### **Application State Structure**
```assembly
app_state:
    current_menu_id:        .dc.l   0
    current_selection:      .dc.l   0
    view_state:            .dc.l   0
    display_needs_update:   .dc.l   0
    navigation_stack:       .ds.l   16
    navigation_stack_pos:   .dc.l   0
```

---

## 🎯 **Critical Success Factors** ⭐

### **Keyboard Controller Management**
1. **Always maintain KEYBOARD_ENABLED bit**
2. **Aggressive queue clearing when full** 
3. **50-cycle debounce timing** (not longer!)
4. **Mandatory report consumption after processing**

### **Display System Stability**
1. **Content area boundaries** (lines 4-17)
2. **Anti-flicker refresh locking**
3. **Proper string termination** (`.ascii` + `.asciz` pattern)
4. **Border preservation during updates**

### **Main Loop Architecture**
1. **Non-blocking input processing**
2. **Predictable timing** (500-cycle delay)
3. **Comprehensive debug monitoring**
4. **Graceful error handling**

---

## 🚀 **PCD-68 Toolbox Roadmap**

### **Phase 1: Core Toolbox** (Based on this ROM)
- **Hardware Abstraction Layer**
- **Keyboard Input Manager** 
- **Display Management System**
- **Basic Application Framework**

### **Phase 2: Extended Services**
- **File System Interface**
- **Network Stack Integration**
- **Advanced Graphics Primitives**
- **Audio/Sound Management**

### **Phase 3: Development Tools**
- **Debugger Integration**
- **Performance Monitoring**
- **Memory Management**
- **Inter-Application Communication**

---

## 📝 **Implementation Guidelines**

### **For New Applications**
1. **Include core hardware constants**
2. **Use proven keyboard input pattern**
3. **Follow screen layout standards**
4. **Implement debug trace system**
5. **Maintain navigation stack**

### **For Toolbox Routines**
1. **Preserve register states**
2. **Use consistent calling conventions**
3. **Provide error return codes**
4. **Include comprehensive documentation**

---

## 📚 **Reference Implementation**

This architecture is based on the working `jonsharp.net` ROM, which demonstrates:

- **Stable keyboard input** with proper hardware management
- **Multi-view content system** with smooth navigation  
- **Comprehensive debug monitoring** for development support
- **Responsive user interface** with anti-flicker display management
- **Extensible menu/content framework** for future applications

### **Key Files**
- `pcd68home.S` - Main application framework and keyboard management
- `utility_functions.S` - Core display and text rendering routines
- `menu_structures.S` - Data-driven menu and content system

### **Proven Performance Metrics**
- **50-cycle debounce timer** for optimal responsiveness
- **500-cycle main loop delay** for stable timing
- **10,000-cycle refresh lock** for flicker prevention
- **80x23 character display** with 14-line content area

---

**This architecture provides a solid foundation for the PCD-68 software ecosystem!** 🏆

*Document Version: 1.0*  
*Created: January 2025*  
*Based on: jonsharp.net ROM v1.0-2025* 