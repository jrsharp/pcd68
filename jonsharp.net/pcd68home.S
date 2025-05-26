/* JonSharp.net Cyberterminal
 * An interactive information terminal simulating a gopher-like experience
 * Content served is a versioned release of the "best of" jonsharp.net.
 */

/* Define memory locations and constants */
.equ ScrnBase, 0x810000
.equ TDABase, 0x410000
.equ KCTLBase, 0x420000
.equ UARTBase, 0x450000

/* Memory sizes */
.equ TDASize, 80 * 23

/* New KCTL register definitions */
.equ KCTLStatus, 0x420000      /* Status/control register */
.equ KCTLCount, 0x420001       /* Number of reports in queue */
.equ KCTLReportSize, 0x420002  /* Number of active keys in current report */
.equ KCTLModifiers, 0x420003   /* Modifier byte */
.equ KCTLKeys, 0x420004        /* Start of key array (7 bytes, one per key) */
.equ KCTLNextReport, 0x42000B  /* Advance to next report (write any value) */

/* Status register bit masks */
.equ STATUS_REPORT_AVAILABLE, 0x01
.equ STATUS_QUEUE_FULL, 0x02
.equ STATUS_CLEAR_INTERRUPT, 0x04
.equ STATUS_KEYBOARD_ENABLED, 0x08

/* UI Constants */
.equ ScreenWidth, 80
.equ ScreenHeight, 23
.equ TextMode, 2               /* 1 for 50-col, 2 for 80-col */
.equ MaxMenuItems, 20          /* Maximum items in a menu */
.equ MaxContentSize, 1024      /* Maximum content buffer size */

/* Key Constants */
.equ KEY_ENTER, 13
.equ KEY_ESC, 27
.equ KEY_BACKSPACE, 8
.equ KEY_H, 104                /* 'h' for Help */
.equ KEY_M, 109                /* 'm' for Main */
.equ KEY_B, 98                 /* 'b' for Back */
.equ KEY_Q, 113                /* 'q' for Quit */
.equ KEY_J, 106                /* 'j' for scroll down */
.equ KEY_K, 107                /* 'k' for scroll up */
.equ KEY_UP_ARROW, 16          /* Up arrow key (SDL maps to ASCII 16) */
.equ KEY_DOWN_ARROW, 17        /* Down arrow key (SDL maps to ASCII 17) */
.equ KEY_LEFT_ARROW, 18        /* Left arrow key */
.equ KEY_RIGHT_ARROW, 19       /* Right arrow key */
.equ KEY_QUESTION, 63          /* '?' (deprecated, now using 'h') */
.equ KEY_0, 48                 /* '0' - Jump to top */
.equ KEY_1, 49                 /* '1' - Menu item 1 */
.equ KEY_2, 50                 /* '2' - Menu item 2 */
.equ KEY_3, 51                 /* '3' - Menu item 3 */
.equ KEY_4, 52                 /* '4' - Menu item 4 */
.equ KEY_5, 53                 /* '5' - Menu item 5 */
.equ KEY_6, 54                 /* '6' - Menu item 6 */
.equ KEY_7, 55                 /* '7' - Menu item 7 */
.equ KEY_8, 56                 /* '8' - Menu item 8 */
.equ KEY_9, 57                 /* '9' - Menu item 9 */

/* End of Memory */
.equ EndOfStack, 0xBFFFFF

/* Provide exported symbols for the menu system */
.global key_home
.global key_back
.global key_help
.global key_quit
.global finish_key_input
.global navigation_stack
.global navigation_stack_pos
.global content_ptr
.global set_display_update_flag

/* Program entry point */
.org 0x000000
vectors:
    dc.l    EndOfStack           /* Initial SP */
    dc.l    start                /* Start of program code */
    dc.l    default_handler      /* Bus error */
    dc.l    default_handler      /* Address error */
    dc.l    default_handler      /* Illegal instruction */
    dc.l    default_handler      /* Div by zero */
    dc.l    default_handler      /* CHK exception */
    dc.l    default_handler      /* TRAPV exception */
    dc.l    default_handler      /* Privilege violation */
    dc.l    default_handler      /* TRACE exception */
    dc.l    0x000000             /* Line-A emulator */
    dc.l    0x000000             /* Line-F emulator */
    dc.l    0xFAFAAA             /* Reserved (unused) */
    dc.l    0x000000             /* Co-proc protocol violation */
    dc.l    default_handler      /* Format error */
    dc.l    default_handler      /* Uninitialized Interrupt */
    dc.l    0x000000
    dc.l    0x000000
    dc.l    0x000000
    dc.l    0x000000
    dc.l    0x000000
    dc.l    0x000000
    dc.l    0x000000
    dc.l    0x000000
    dc.l    0x000000
    dc.l    0x000000
    dc.l    0x000000
    dc.l    keyboard_handler     /* IRQ Level 3 (keyboard) */
    dc.l    0x000000
    dc.l    0x000000
    dc.l    0x000000
    dc.l    0x000000
    /* Fill remaining vectors */
    .rept 32
    dc.l    0x000000
    .endr

/* Program start */
.section .text, "ax"
.org 0x001000
start:
    /* Initialize TDA */
    moveal  #TDABase, %a2
    moveb   #TextMode, (%a2)+    /* Set column mode (font) */
    
    /* Clear screen first */
    jsr     clear_screen

    /* Initialize variables */
    movel   #0, current_menu_id     /* Start with main menu (ID 0) */
    movel   #0, current_selection   /* No item selected initially */
    movel   #0, navigation_stack_pos /* Reset navigation stack position */
    movel   #0, display_needs_update /* No update needed yet */
    movel   #0, refresh_lock        /* Add lock to prevent constant refreshing */
    movel   #0, %d6                 /* Initialize keyboard debug value */
    clrl    %d0
    
    /* Initialize navigation stack with main menu */
    movel   #0, navigation_stack    /* First entry is main menu (ID 0) */
    addil   #1, navigation_stack_pos /* Increment stack position */
    
    /* Initialize menu system - ensure proper linkage */
    jsr     init_menu_system
    
    /* Initialize scrolling system */
    jsr     init_scroll_system
    
    /* Initialize keyboard controller */
    /* First, clear any pending interrupts and reports */
    moveb   #STATUS_CLEAR_INTERRUPT, KCTLStatus
    moveb   #0, KCTLCount
    moveb   #0, KCTLReportSize
    
    /* Then enable keyboard with interrupts - write the correct enable bit */
    moveb   #STATUS_KEYBOARD_ENABLED, KCTLStatus
    
    /* Make another read-modify-write to ensure the enable bit sticks */
    moveb KCTLStatus, %d0
    orib    #STATUS_KEYBOARD_ENABLED, %d0   /* Set the enable bit without clearing others */
    moveb   %d0, KCTLStatus
    
    /* Display info about keyboard status after init */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 70, %a2
    moveb   KCTLStatus, %d0
    lsrl    #4, %d0             /* High nibble */
    andil   #0xF, %d0
    addil   #'0', %d0
    cmpl    #'9', %d0
    ble     init_high_ok
    addil   #7, %d0             /* Convert A-F */
init_high_ok:
    moveb   %d0, (%a2)+
    
    moveb   KCTLStatus, %d0
    andil   #0xF, %d0           /* Low nibble */
    addil   #'0', %d0
    cmpl    #'9', %d0
    ble     init_low_ok
    addil   #7, %d0             /* Convert A-F */
init_low_ok:
    moveb   %d0, (%a2)
    
    /* DISABLE CPU interrupts for debugging - use pure polling */
    move    #0x2700, %sr         /* Disable all interrupts */
    
    /* Display initial screen */
    jsr     draw_header          /* This also calls draw_borders internally */
    jsr     draw_footer
    
    /* Initial display of content */
    jsr     clear_content_area   /* Clear content area first */
    jsr     draw_content_area

    /* Set initial update flag to true to ensure display refreshes */
    movel   #1, display_needs_update
    
    /* Draw all borders */
    jsr     draw_borders
    
    /* Initialize counter display */
    jsr     draw_status
    
/* Main Program Loop */
main_loop:
    /* Debug marker - add trace A for main loop start */
    movel   #'A', %d0
    jsr     add_debug_trace
    
    /* Debug marker to show we're in the main loop - changes with each iteration */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 2, %a2
    
    /* Toggle between two characters to show loop is running */
    moveb   main_loop_toggle, %d0
    cmpb    #'/', %d0
    beq     toggle_to_backslash
    
    moveb   #'/', %d0
    moveb   %d0, main_loop_toggle
    bra     toggle_done
    
toggle_to_backslash:
    moveb   #'\\', %d0
    moveb   %d0, main_loop_toggle
    
toggle_done:
    moveb   %d0, (%a2)
    
    /* Hybrid approach: Interrupt signals availability, polling handles hardware */
    
    /* First, ensure keyboard controller stays enabled (hardware requirement) */
    moveb   KCTLStatus, %d0
    btst    #3, %d0              /* Test STATUS_KEYBOARD_ENABLED bit */
    bne     keyboard_enabled_ok
    
    /* Keyboard not enabled, re-enable it */
    orib    #STATUS_KEYBOARD_ENABLED, %d0
    moveb   %d0, KCTLStatus
    
keyboard_enabled_ok:
    /* Add trace B for keyboard check */
    movel   #'B', %d0
    jsr     add_debug_trace
    
    /* Check for queue full condition and force clear if needed */
    moveb   KCTLStatus, %d0
    btst    #1, %d0              /* Test STATUS_QUEUE_FULL bit */
    beq     queue_not_full
    
    /* Queue is full - force clear ALL reports aggressively */
    movel   #'Q', %d0            /* Q = Queue full, clearing */
    jsr     add_debug_trace
    
clear_full_queue:
    moveb   #1, KCTLNextReport   /* Consume one report */
    moveb   KCTLStatus, %d0
    btst    #1, %d0              /* Check if still full */
    bne     clear_full_queue     /* Keep clearing until not full */
    
    /* Reset debounce timer after clearing full queue */
    movel   #0, key_debounce_timer
    
queue_not_full:
    /* Check debounce timer first */
    cmpl    #0, key_debounce_timer
    beq     debounce_expired
    
    /* Debounce timer still active, decrement and skip input */
    subil   #1, key_debounce_timer
    
    /* Add debug trace every 1000 cycles to show we're waiting */
    movel   key_debounce_timer, %d0
    andil   #1023, %d0         /* Check if multiple of 1024 */
    cmpl    #0, %d0
    bne     skip_debounce_trace
    movel   #'W', %d0          /* W = Waiting in debounce */
    jsr     add_debug_trace
skip_debounce_trace:
    
    bra     main_loop_continue

debounce_expired:
    /* Add trace E for debounce expired */
    movel   #'E', %d0
    jsr     add_debug_trace
    
    /* Pure polling approach - check if reports are pending */
    moveb   KCTLCount, %d0
    cmpl    #0, %d0
    beq     main_loop_continue   /* No input ready, continue */
    
    /* Add debug trace before processing input */
    movel   #'K', %d0
    jsr     add_debug_trace
    
    /* Process the keyboard input with pure polling */
    jsr     process_keyboard_input
    
    /* Add debug trace after processing input */
    movel   #'X', %d0
    jsr     add_debug_trace

main_loop_continue:
    /* Add trace L for main loop continue */
    movel   #'L', %d0
    jsr     add_debug_trace
    
    /* Check if display needs updating */
    cmpl    #1, display_needs_update
    bne     main_loop_delay      /* No update needed, skip drawing */

    /* Add trace R for refresh start */
    movel   #'R', %d0
    jsr     add_debug_trace

    /* Process display update with proper locking */
    cmpl    #1, refresh_lock
    bne     perform_refresh      /* Not locked, perform refresh normally */
    
    /* Check if we have a key press (d6 non-zero) to override lock */
    cmpl    #0, %d6
    beq     main_loop_delay      /* No key press and locked, skip drawing */

perform_refresh:
    /* Add trace T for refresh executing */
    movel   #'T', %d0
    jsr     add_debug_trace
    
    /* Lock refreshing to prevent constant flickering */
    movel   #1, refresh_lock
    
    /* Clear the header area (preserving borders) */
    jsr     clear_header_area

    /* draw/update current menu content */
    jsr     draw_header
    
    /* Clear the content area (preserving borders) */
    jsr     clear_content_area
    
    /* Display current menu content */
    jsr     draw_content_area
    
    /* Draw the consolidated status line */
    jsr     draw_status
    
    /* Draw the commands line */
    jsr     draw_footer
    
    /* redraw borders */
    jsr     draw_borders
    
    /* Reset update flag */
    movel   #0, display_needs_update
    
    /* Delay before releasing lock to prevent too-frequent updates */
    movel   #10000, %d0
unlock_delay_loop:
    subil   #1, %d0
    bne     unlock_delay_loop
    movel   #0, refresh_lock     /* Release lock */
    
main_loop_delay:
    /* Small delay to prevent CPU thrashing */
    movel   #50, %d0
delay_loop:
    subil   #1, %d0
    bne     delay_loop
    
    /* Increment delay counter for approximately one second updates */
    addil   #1, delay_counter
    cmpl    #500, delay_counter  /* Adjusted for slower updates to reduce overhead */
    blt     skip_counter_update
    
    /* Reset delay counter and increment the visible counter */
    movel   #0, delay_counter
    addil   #1, counter_value
    
    /* Update status line directly without full screen refresh - but only occasionally */
    movel   delay_counter, %d0
    andil   #31, %d0           /* Only update every 32 cycles */
    cmpl    #0, %d0
    bne     skip_status_update
    jsr     draw_status
skip_status_update:
    
skip_counter_update:
    /* Continue the main loop */
    bra     main_loop



/* Consolidated status line drawing with all debug information */
draw_status:
    /* Save registers */
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    movel   %d3, -(%sp)
    movel   %d4, -(%sp)
    movel   %d5, -(%sp)
    movel   %d6, -(%sp)
    movel   %d7, -(%sp)
    movel   %a0, -(%sp)
    movel   %a1, -(%sp)
    movel   %a2, -(%sp)
    
    /* Calculate position for status line (line 19) */
    movel   #19, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw left border and clear entire line */
    moveb   #'|', (%a2)+
    moveb   #' ', (%a2)+
    
    movel   #2, %d1            /* Start after left border + space */
clear_status_full_loop:
    cmpl    #ScreenWidth - 1, %d1  /* Stop before right border */
    bge     clear_status_full_end
    moveb   #' ', (%a2)+
    addl    #1, %d1
    bra     clear_status_full_loop
clear_status_full_end:
    
    /* Reset to start position after border */
    moveal  %a0, %a2
    addl    #2, %a2            /* Skip | and space */
    
    /* === DEBUG SECTION 1: Main Loop (positions 2-10) === */
    moveb   main_loop_toggle, (%a2)+
    
    /* === DEBUG SECTION 2: Keyboard Status (positions 11-25) === */
    moveb   #'S', (%a2)+
    moveb   #':', (%a2)+
    moveb   KCTLStatus, %d0
    lsrl    #4, %d0             /* High nibble */
    andil   #0xF, %d0
    addil   #'0', %d0
    cmpl    #'9', %d0
    ble     status_high_ok_new
    addil   #7, %d0             /* Convert A-F */
status_high_ok_new:
    moveb   %d0, (%a2)+
    
    moveb   KCTLStatus, %d0
    andil   #0xF, %d0           /* Low nibble */
    addil   #'0', %d0
    cmpl    #'9', %d0
    ble     status_low_ok_new
    addil   #7, %d0             /* Convert A-F */
status_low_ok_new:
    moveb   %d0, (%a2)+
    
    moveb   #' ', (%a2)+
    moveb   #'P', (%a2)+
    moveb   #':', (%a2)+
    moveb   KCTLCount, %d1
    addib   #'0', %d1
    moveb   %d1, (%a2)+
    
    /* === DEBUG SECTION 3: Key Code (positions 26-35) === */
    moveb   #' ', (%a2)+
    moveb   #'K', (%a2)+
    moveb   #':', (%a2)+
    
    /* Display the key code in hex */
    movel   %d6, %d1            /* D6 should contain the key code */
    lsrl    #4, %d1             /* Get high nibble */
    andil   #0xF, %d1
    addil   #'0', %d1
    cmpl    #'9', %d1           /* Convert A-F */
    ble     key_high_digit_ok
    addil   #7, %d1             /* Convert A-F */
key_high_digit_ok:
    moveb   %d1, (%a2)+
    
    /* Low nibble */
    movel   %d6, %d1
    andil   #0xF, %d1
    addil   #'0', %d1
    cmpl    #'9', %d1           /* Convert A-F */
    ble     key_low_digit_ok
    addil   #7, %d1             /* Add 7 to get from '9'+1 to 'A' */
key_low_digit_ok:
    moveb   %d1, (%a2)+
    
    /* Add ASCII value if it's a printable character */
    moveb   #'(', (%a2)+
    
    /* Check if it's printable */
    cmpl    #32, %d6
    blt     key_not_printable
    cmpl    #126, %d6
    bgt     key_not_printable
    
    /* It's printable */
    moveb   %d6, (%a2)+
    bra     key_end_char_display
    
key_not_printable:
    moveb   #'?', (%a2)+
    
key_end_char_display:
    moveb   #')', (%a2)+
    
    /* === DEBUG SECTION 4: State Variables (positions 36-50) === */
    moveb   #' ', (%a2)+
    moveb   #'V', (%a2)+
    moveb   #':', (%a2)+
    movel   view_state, %d0
    addib   #'0', %d0
    moveb   %d0, (%a2)+
    
    moveb   #' ', (%a2)+
    moveb   #'M', (%a2)+
    moveb   #':', (%a2)+
    movel   current_menu_id, %d0
    addib   #'0', %d0
    moveb   %d0, (%a2)+
    
    moveb   #' ', (%a2)+
    moveb   #'S', (%a2)+
    moveb   #':', (%a2)+
    movel   current_selection, %d0
    addib   #'0', %d0
    moveb   %d0, (%a2)+
    
    /* === DEBUG SECTION 5: Function Traces (positions 51-70) === */
    /* This section will be populated by individual functions */
    
    /* === DEBUG SECTION 6: Counter (positions 71-79) === */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + ScreenWidth - 7, %a2
    moveb   #'C', (%a2)+
    moveb   #':', (%a2)+
    
    /* Convert counter to decimal digits */
    movel   counter_value, %d0
    
    /* Handle tens */
    divu    #10, %d0
    movew   %d0, %d2           /* Save quotient (tens) */
    swap    %d0                /* Get remainder in lower word */
    addib   #'0', %d2          /* Convert to ASCII */
    moveb   %d2, (%a2)+        /* Display tens digit */
    
    /* Handle ones */
    movew   %d0, %d0           /* Clear upper word */
    addib   #'0', %d0          /* Convert to ASCII */
    moveb   %d0, (%a2)+        /* Display ones digit */
    
    /* Close status line with right border */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + ScreenWidth - 1, %a2
    moveb   #'|', (%a2)
    
    /* Restore registers */
    movel   (%sp)+, %a2
    movel   (%sp)+, %a1
    movel   (%sp)+, %a0
    movel   (%sp)+, %d7
    movel   (%sp)+, %d6
    movel   (%sp)+, %d5
    movel   (%sp)+, %d4
    movel   (%sp)+, %d3
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Add debug trace to status line - call this to mark function entry */
/* Input: D0 = character to display in trace section */
add_debug_trace:
    /* Save registers */
    movel   %d1, -(%sp)
    movel   %a2, -(%sp)
    
    /* Position in trace section (around position 55) */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 55, %a2
    
    /* Find next available slot (look for space) */
    movel   #0, %d1
find_trace_slot:
    cmpl    #10, %d1           /* Max 10 trace chars */
    bge     trace_slot_found
    cmpb    #' ', (%a2)
    beq     trace_slot_found
    addl    #1, %a2
    addl    #1, %d1
    bra     find_trace_slot
    
trace_slot_found:
    moveb   %d0, (%a2)
    
    /* Restore registers */
    movel   (%sp)+, %a2
    movel   (%sp)+, %d1
    rts

/* Legacy compatibility - just calls draw_status */
update_status_line:
    jsr     draw_status
    rts

/* Draw command footer line with only commands */
draw_footer:
    /* Save registers */
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %a0, -(%sp)
    movel   %a2, -(%sp)
    
    /* Position for commands line (line 21) */
    movel   #21, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw left border and space */
    moveb   #'|', (%a2)+
    moveb   #' ', (%a2)+
    
    /* Draw commands list */
    lea     footer_commands, %a5
    jsr     print_string_no_advance
    
    /* Fill remaining space */
    movel   %a2, %a1
    subal   %a0, %a1
    subl    #ScreenWidth, %a1
    subl    #2, %a1            /* Account for | and space */
    movel   #ScreenWidth - 2, %d0
    subl    %a1, %d0
    
    movel   #0, %d1
cmd_space_loop:
    cmpl    %d0, %d1
    bge     cmd_space_end
    moveb   #' ', (%a2)+
    addl    #1, %d1
    bra     cmd_space_loop
cmd_space_end:
    
    /* Close command line with right border */
    moveal  #TDABase + 1 + (21 * ScreenWidth) + ScreenWidth - 1, %a2
    moveb   #'|', (%a2)+
    
    /* Restore registers */
    movel   (%sp)+, %a2
    movel   (%sp)+, %a0
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Process keyboard input */
process_keyboard_input:
    /* Add debug trace */
    movel   #'P', %d0
    jsr     add_debug_trace
    
    /* Check if there are any keys in the report */
    moveb   KCTLReportSize, %d5
    beq     finish_key_input     /* No keys in report, finish */
    
    /* Read the first key from the report */
    moveal  #KCTLKeys, %a0
    moveb   (%a0), %d0
    
    /* Store key in D6 for status line update */
    movel   %d0, %d6
    
    /* Key processing with updated command palette */
    cmpb    #KEY_ESC, %d0
    beq     process_key_home
    cmpb    #KEY_M, %d0        /* 'm' for Main menu */
    beq     process_key_home
    cmpb    #KEY_H, %d0        /* 'h' for Help */
    beq     process_key_home
    cmpb    #KEY_B, %d0
    beq     process_key_back
    cmpb    #KEY_Q, %d0
    beq     process_key_quit
    cmpb    #KEY_J, %d0        /* 'j' for scroll down */
    beq     process_key_scroll_down
    cmpb    #KEY_K, %d0        /* 'k' for scroll up */
    beq     process_key_scroll_up
    cmpb    #KEY_DOWN_ARROW, %d0  /* Down arrow for scroll down */
    beq     process_key_scroll_down
    cmpb    #KEY_UP_ARROW, %d0    /* Up arrow for scroll up */
    beq     process_key_scroll_up
    
    /* Check for numeric keys for section jumping */
    cmpb    #KEY_1, %d0
    beq     jump_section_1
    cmpb    #KEY_2, %d0
    beq     jump_section_2
    cmpb    #KEY_3, %d0
    beq     jump_section_3
    cmpb    #KEY_4, %d0
    beq     jump_section_4
    cmpb    #KEY_5, %d0
    beq     jump_section_5
    cmpb    #KEY_0, %d0
    beq     jump_top
    
    bra     finish_key_input

jump_top:
    movel   #0, scroll_offset
    jsr     set_display_update_flag
    bra     finish_key_input

jump_section_1:
    movel   #6, scroll_offset    /* Line 6 = Section 1 */
    jsr     set_display_update_flag
    bra     finish_key_input

jump_section_2:
    movel   #22, scroll_offset   /* Line 22 = Section 2 */
    jsr     set_display_update_flag
    bra     finish_key_input

jump_section_3:
    movel   #36, scroll_offset   /* Line 36 = Section 3 */
    jsr     set_display_update_flag
    bra     finish_key_input

jump_section_4:
    movel   #58, scroll_offset   /* Line 58 = Section 4 */
    jsr     set_display_update_flag
    bra     finish_key_input

jump_section_5:
    movel   #70, scroll_offset   /* Line 70 = Section 5 */
    jsr     set_display_update_flag
    bra     finish_key_input

/* Key processing wrappers - ensure all keys go through finish_key_input */
process_key_home:
    jsr     key_home
    bra     finish_key_input

process_key_help:
    jsr     key_help  
    bra     finish_key_input

process_key_back:
    jsr     key_back
    bra     finish_key_input

process_key_quit:
    jsr     key_quit
    bra     finish_key_input

process_key_scroll_down:
    jsr     key_scroll_down
    bra     finish_key_input

process_key_scroll_up:
    jsr     key_scroll_up
    bra     finish_key_input

finish_key_input:
    /* Add debug trace to show we're consuming report */
    movel   #'F', %d0
    jsr     add_debug_trace
    
    /* Aggressive report clearing - clear ALL pending reports */
consume_all_reports:
    moveb   KCTLCount, %d0
    cmpl    #0, %d0
    beq     all_consumed
    
    /* Consume one report */
    moveb   #1, KCTLNextReport
    
    /* Add trace to show we consumed a report */
    movel   #'C', %d0
    jsr     add_debug_trace
    
    /* Small delay and check again */
    movel   #1000, %d0
consume_delay:
    subil   #1, %d0
    bne     consume_delay
    
    bra     consume_all_reports
    
all_consumed:
    /* Set much shorter debounce timer */
    movel   #50, key_debounce_timer    /* Reduced from 200,000 to 5,000 to 50 cycles */
    
    /* Add trace to show we finished consuming */
    movel   #'D', %d0
    jsr     add_debug_trace
    rts

/* Process the menu selection */
process_menu_selection:
    /* Debug: Clear a section for our debug info */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 50, %a2
    moveb   #'[', (%a2)+
    movew   current_menu_id, %d7
    addib   #'0', %d7
    moveb   %d7, (%a2)+
    moveb   #',', (%a2)+
    movew   current_selection, %d7
    addib   #'0', %d7
    moveb   %d7, (%a2)+
    moveb   #']', (%a2)+
    
    /* Load the selected menu item */
    movew   current_menu_id, %d0
    movew   current_selection, %d1
    
    /* Add debug trace */
    movel   #'M', %d0
    jsr     add_debug_trace
    
    /* Get the entry type */
    movew   current_menu_id, %d0    /* Reload menu ID */
    movew   current_selection, %d1  /* Reload selection */
    jsr     get_menu_entry_type
    
    /* Debug: Show the type we got back */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 56, %a2
    moveb   #'=', (%a2)+
    moveb   %d0, %d3
    addib   #'0', %d3
    moveb   %d3, (%a2)+
    
    /* Process based on type */
    cmpb    #ENTRY_TYPE_SUBMENU, %d0
    beq     process_submenu_debug
    cmpb    #ENTRY_TYPE_TEXT, %d0
    beq     process_text_debug
    cmpb    #ENTRY_TYPE_LINK, %d0
    beq     process_link_debug
    
    /* Default action - show we took default path */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 58, %a2
    moveb   #'D', (%a2)+
    jsr     set_display_update_flag
    rts

process_submenu_debug:
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 58, %a2
    moveb   #'S', (%a2)+
    jmp     process_submenu

process_text_debug:
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 58, %a2
    moveb   #'T', (%a2)+
    jmp     process_text

process_link_debug:
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 58, %a2
    moveb   #'L', (%a2)+
    jmp     process_link

/* Process submenu selection */
process_submenu:
    /* Get the target menu ID */
    movew   current_menu_id, %d0
    movew   current_selection, %d1
    
    /* Add debug trace */
    movel   #'S', %d0
    jsr     add_debug_trace
    
    /* Debug: Show current menu and selection */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 54, %a2
    moveb   #'(', (%a2)+
    movew   current_menu_id, %d3
    addib   #'0', %d3
    moveb   %d3, (%a2)+
    moveb   #',', (%a2)+
    movew   current_selection, %d3
    addib   #'0', %d3
    moveb   %d3, (%a2)+
    moveb   #')', (%a2)+
    
    jsr     get_menu_target_id
    
    /* Debug: Show target menu ID */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 60, %a2
    moveb   #'>', (%a2)+
    moveb   %d0, %d3
    addib   #'0', %d3
    moveb   %d3, (%a2)+
    
    /* Push current menu to navigation stack */
    movel   navigation_stack_pos, %d1
    lsll    #2, %d1             /* Multiply by 4 for long word offset */
    lea     navigation_stack, %a0
    movel   current_menu_id, (%a0, %d1.l)
    addil   #1, navigation_stack_pos
    
    /* Set the new menu as current */
    movew   %d0, current_menu_id
    movew   #0, current_selection
    
    /* Update display */
    jsr     set_display_update_flag
    rts

/* Process text content */
process_text:
    /* Get the content pointer */
    movew   current_menu_id, %d0
    movew   current_selection, %d1
    
    jsr     get_content_pointer
    movel   %a0, content_ptr
    
    /* Set state to content view */
    movel   #1, view_state       /* 1 = content view */
    
    /* Update display */
    jsr     set_display_update_flag
    
    /* Display content using multi-line function */
    jsr     print_multiline_string
    
    /* Restore registers */
    movel   (%sp)+, %a5
    movel   (%sp)+, %a2
    movel   (%sp)+, %d0
    rts

/* Keyboard interrupt handler - DISABLED for pure polling debugging */
keyboard_handler:
    /* Just clear the interrupt and return */
    moveb   #STATUS_CLEAR_INTERRUPT, KCTLStatus
    rte

/* Default exception handler */
default_handler:
    /* Display exception message */
    moveal  #TDABase + 1 + (80 * (ScreenHeight - 1)), %a2
    lea     exception_msg, %a5
    jsr     print_string
    
    /* Hang forever */
    exception_loop:
    bra     exception_loop

/* Initialize menu system - ensure proper symbol linkage */
init_menu_system:
    /* Save registers */
    movel   %d0, -(%sp)
    movel   %a0, -(%sp)
    
    /* Force access to menu_table to ensure it's linked */
    lea     menu_table, %a0
    movel   (%a0), %d0          /* Read first entry to force linking */
    
    /* Force access to content_table to ensure it's linked */
    lea     content_table, %a0
    movel   (%a0), %d0          /* Read first entry to force linking */
    
    /* Test menu system basic functionality */
    movew   #0, %d0             /* Test main menu (ID 0) */
    jsr     get_menu_item_count /* This will force all menu functions to link */
    
    /* Restore registers */
    movel   (%sp)+, %a0
    movel   (%sp)+, %d0
    rts

/* Set flag to update display */
set_display_update_flag:
    movel   #1, display_needs_update
    rts

/* Process external link */
process_link:
    /* For now, just show a "link not available" message */
    lea     link_unavailable_msg, %a0
    movel   %a0, content_ptr
    
    /* Set state to content view */
    movel   #1, view_state       /* 1 = content view */
    
    /* Update display */
    jsr     set_display_update_flag
    rts

/* Return to home menu */
key_home:
    /* Reset navigation stack */
    movel   #0, navigation_stack_pos
    movel   #0, navigation_stack    /* First entry is main menu (ID 0) */
    addil   #1, navigation_stack_pos
    
    /* Reset menu state */
    movel   #0, current_menu_id
    movel   #0, current_selection
    movel   #0, view_state       /* 0 = menu view */
    
    /* Update display */
    jsr     set_display_update_flag
    rts

/* Go back to previous menu */
key_back:
    /* Check if we're in content view */
    cmpl    #1, view_state
    beq     return_to_menu_view
    
    /* Check if we can go back in navigation */
    cmpl    #1, navigation_stack_pos
    ble     finish_key_input     /* Already at main menu */
    
    /* Pop previous menu from stack */
    subil   #1, navigation_stack_pos
    movel   navigation_stack_pos, %d0
    subl    #1, %d0              /* Get previous menu position */
    lsll    #2, %d0              /* Multiply by 4 for long word offset */
    lea     navigation_stack, %a0
    movel   (%a0, %d0.l), %d0
    
    /* Set as current menu */
    movel   %d0, current_menu_id
    movel   #0, current_selection
    
    /* Update display */
    jsr     set_display_update_flag
    rts

/* Return from content view to menu view */
return_to_menu_view:
    movel   #0, view_state       /* 0 = menu view */
    
    /* Update display */
    jsr     set_display_update_flag
    rts

/* Show help screen */
key_help:
    /* Add debug trace */
    movel   #'H', %d0
    jsr     add_debug_trace
    
    /* Check if we're already in content view to prevent unnecessary work */
    cmpl    #1, view_state
    beq     key_help_already_done
    
    /* Set content pointer to help text */
    lea     help_text, %a0
    movel   %a0, content_ptr
    
    /* Set state to content view - use long operations for consistency */
    movel   #1, view_state       /* 1 = content view */
    
    /* Add debug trace to show we set view_state */
    movel   #'1', %d0
    jsr     add_debug_trace
    
    /* Update display */
    jsr     set_display_update_flag

key_help_already_done:
    rts

/* Quit function (only useful in UART test mode) */
key_quit:
    /* For now, just go back to main menu */
    jsr     key_home
    rts

/* Scroll down function */
key_scroll_down:
    movel   scroll_offset, %d0
    movel   content_total_lines, %d1
    subl    #15, %d1                /* Content area height */
    cmpl    %d1, %d0
    bge     scroll_down_done
    addl    #1, %d0
    movel   %d0, scroll_offset
    jsr     set_display_update_flag
scroll_down_done:
    rts

/* Scroll up function */
key_scroll_up:
    movel   scroll_offset, %d0
    cmpl    #0, %d0
    ble     scroll_up_done
    subl    #1, %d0
    movel   %d0, scroll_offset
    jsr     set_display_update_flag
scroll_up_done:
    rts

/* Initialize scrolling system */
init_scroll_system:
    /* Calculate total lines in content by counting newlines */
    movel   #0, %d0
    lea     combined_content, %a0
count_lines_loop:
    moveb   (%a0)+, %d1
    cmpb    #0, %d1
    beq     count_lines_done
    cmpb    #10, %d1             /* Newline character */
    bne     count_lines_loop
    addl    #1, %d0
    bra     count_lines_loop
count_lines_done:
    movel   %d0, content_total_lines
    rts

/* Display the current menu or content */
display_current_menu:
    /* Add debug trace */
    movel   #'D', %d0
    jsr     add_debug_trace
    
    /* Check view state - use long operations for consistency */
    cmpl    #0, view_state
    beq     draw_menu_view
    cmpl    #1, view_state
    beq     draw_text_content_view
    
    /* Default to menu view if state is invalid */
    jmp     draw_menu_view

/* Draw content area - scrolling text content */
draw_content_area:
    /* Add debug trace */
    movel   #'D', %d0
    jsr     add_debug_trace
    
    /* Display scrolling content */
    jsr     draw_scrolling_content
    rts

/* Draw scrolling content */
draw_scrolling_content:
    /* Clear content area first */
    jsr     clear_content_area
    
    /* Position at content area start (line 3) */
    moveal  #TDABase + 1 + (3 * 80), %a2
    
    /* Find starting position in text based on scroll_offset */
    lea     combined_content, %a0
    movel   scroll_offset, %d0
    movel   #0, %d1
    
find_start_loop:
    cmpl    %d0, %d1
    bge     find_start_done
skip_line_loop:
    moveb   (%a0)+, %d2
    cmpb    #0, %d2
    beq     find_start_done
    cmpb    #10, %d2
    bne     skip_line_loop
    addl    #1, %d1
    bra     find_start_loop
    
find_start_done:
    /* Display 15 lines worth of text */
    movel   #0, %d3
    
display_content_loop:
    cmpl    #15, %d3
    bge     display_content_done
    movel   #0, %d1
    
display_line_loop:
    cmpl    #78, %d1                /* Leave room for borders */
    bge     line_too_long
    moveb   (%a0)+, %d2
    cmpb    #0, %d2
    beq     display_content_done
    cmpb    #10, %d2
    beq     line_done
    moveb   %d2, (%a2)+
    addl    #1, %d1
    bra     display_line_loop
    
line_too_long:
    moveb   (%a0)+, %d2
    cmpb    #0, %d2
    beq     display_content_done
    cmpb    #10, %d2
    bne     line_too_long
    
line_done:
    addl    #1, %d3
    moveal  #TDABase + 1 + (3 * 80), %a2
    movel   %d3, %d1
    muls    #80, %d1
    addl    %d1, %a2
    bra     display_content_loop
    
display_content_done:
    rts

/* Display a menu */
draw_menu_view:
    /* Save registers that we'll be using */
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    movel   %d3, -(%sp)
    movel   %d4, -(%sp)
    movel   %d5, -(%sp)
    movel   %d6, -(%sp)
    movel   %d7, -(%sp)
    movel   %a0, -(%sp)
    movel   %a1, -(%sp)
    movel   %a2, -(%sp)
    movel   %a5, -(%sp)
    
    /* Check if menu has content and display it */
    movew   current_menu_id, %d0
    jsr     get_menu_content
    cmpl    #0, %a0
    beq     skip_menu_content
    
    /* Display menu content starting at line 3 */
    moveal  #TDABase + 1 + (80 * 3), %a2
    moveal  %a0, %a5
    jsr     print_multiline_string
    
    /* Calculate starting position for menu items based on where content ended */
    moveal  %a2, %a0            /* Current position after content */
    subal   #TDABase + 1, %a0   /* Get offset from screen start */
    movel   %a0, %d0            /* Copy to data register for division */
    divu    #ScreenWidth, %d0   /* Get current line number */
    movew   %d0, %d5            /* Store line number in D5 */
    
    /* Add 2 lines of spacing after content */
    addw    #2, %d5
    bra     start_menu_items
    
skip_menu_content:
    /* Start menu items at line 3 if no content */
    movew   #3, %d5             /* Start line for menu items */
    
start_menu_items:
    /* Get menu item count for the loop */
    movew   current_menu_id, %d0
    jsr     get_menu_item_count
    movew   %d0, %d7            /* Store menu item count in d7 */
    
    /* Ensure minimum starting line (line 7 to leave room for content) */
    cmpw    #7, %d5
    bge     menu_start_ok
    movew   #7, %d5
    
menu_start_ok:
    /* Ensure we don't go past the status line (line 18) */
    cmpw    #18, %d5
    ble     menu_line_ok
    movew   #18, %d5
    
menu_line_ok:
    /* Loop through menu items */
    movew   #0, %d6             /* Current item index */
display_menu_loop:
    cmpw    %d7, %d6            /* Compare with item count */
    bge     display_menu_end
    
    /* Position cursor for this menu item */
    movel   %d5, %d0             /* Start with the start line (7 or 4) */
    addl    %d6, %d0             /* Add the item index (0, 1, 2, etc.) */
    muls    #80, %d0            /* 80 characters per line (use muls not mull) */
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Check if this is the current selection */
    cmpw    current_selection, %d6
    bne     display_menu_item_normal
    
    /* Display selection indicator */
    moveb   #'>', (%a2)+
    moveb   #' ', (%a2)+
    bra     display_menu_item_number
    
display_menu_item_normal:
    /* Display normal spacing */
    moveb   #' ', (%a2)+
    moveb   #' ', (%a2)+
    
display_menu_item_number:
    /* Display item number */
    moveb   %d6, %d0
    addib   #'1', %d0
    moveb   %d0, (%a2)+
    moveb   #'.', (%a2)+
    moveb   #' ', (%a2)+
    
    /* Display menu item text - use get_menu_item_text function directly */
    movew   current_menu_id, %d0
    movew   %d6, %d1

    jsr     get_menu_item_text
    moveal  %a0, %a5

    /* Print the menu item text */
    jsr     print_string
    
    /* Next menu item */
    addw    #1, %d6
    bra     display_menu_loop
    
display_menu_end:
    /* Restore registers */
    movel   (%sp)+, %a5
    movel   (%sp)+, %a2
    movel   (%sp)+, %a1
    movel   (%sp)+, %a0
    movel   (%sp)+, %d7
    movel   (%sp)+, %d6
    movel   (%sp)+, %d5
    movel   (%sp)+, %d4
    movel   (%sp)+, %d3
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Display text content view */
draw_text_content_view:
    /* Save registers */
    movel   %d0, -(%sp)
    movel   %a2, -(%sp)
    movel   %a5, -(%sp)
    
    /* Add debug trace */
    movel   #'C', %d0
    jsr     add_debug_trace
    
    /* Position cursor at content area start (line 3 per layout) */
    moveal  #TDABase + 1 + (80 * 3), %a2
    
    /* Check if content_ptr is valid and display first few chars as debug */
    moveal  content_ptr, %a5
    cmpl    #0, %a5
    beq     content_ptr_null
    
    /* Display first character as debug marker */
    moveb   (%a5), %d0
    cmpb    #0, %d0
    beq     content_empty
    
    /* Display content using multi-line function */
    jsr     print_multiline_string
    
    /* Restore registers */
    movel   (%sp)+, %a5
    movel   (%sp)+, %a2
    movel   (%sp)+, %d0
    rts
    
content_ptr_null:
    /* Display error message */
    lea     content_null_msg, %a5
    jsr     print_string
    
    /* Restore registers */
    movel   (%sp)+, %a5
    movel   (%sp)+, %a2
    movel   (%sp)+, %d0
    rts
    
content_empty:
    /* Display error message */
    lea     content_empty_msg, %a5
    jsr     print_string
    
    /* Restore registers */
    movel   (%sp)+, %a5
    movel   (%sp)+, %a2
    movel   (%sp)+, %d0
    rts

/* Constants */
.equ ENTRY_TYPE_SUBMENU, 0
.equ ENTRY_TYPE_TEXT, 1
.equ ENTRY_TYPE_LINK, 2
.equ MAX_MENU_ID, 5     /* Highest valid menu ID */

/* Data section with menu strings and content */
.section .rodata, "a"
.org 0x003000

/* UI Strings */
.global header_title
.global version_text
.global version_text_length
.global footer_commands
.global status_text
.global selection_text
.global key_debug_text
.global counter_text

header_title:
    .string "JonSharp.net Cyberterminal Access"
version_text:
    .string "[sampler ROM v1.0-2025]"
.equ version_text_length, 23

footer_commands:
    .string "j=down, k=up, 0=Top, 1-9=Section markers"
status_text:
    .string "Loc: "
selection_text:
    .string "Sel: "
key_debug_text:
    .string "Key: "
counter_text:
    .string "Cnt: "

exception_msg:
    .string "*** Exception occurred! System halted. ***"

link_unavailable_msg:
    .string "External link functionality not available."

unknown_menu_title:
    .string "Unknown Menu"
unknown_menu_item_text:
    .string "Unknown item"
unknown_content_text:
    .string "Content not available."

content_null_msg:
    .string "ERROR: Content pointer is null"

content_empty_msg:
    .string "ERROR: Content is empty"

/* Content Texts */
help_text:
    .ascii "JonSharp.net Cyberterminal Help\n\n"
    .ascii "Navigation Commands:\n"
    .ascii "  - Use number keys (1-9) to select menu items\n"
    .ascii "  - Press M to return to the main menu\n"
    .ascii "  - Press B to go back to the previous menu\n"
    .ascii "  - Press H to display this help screen\n"
    .ascii "  - Press Q to quit (when available)\n\n"
    .ascii "The cyberterminal provides a simplified gopher-like\n"
    .ascii "interface to jonsharp.net content.\n\n"
    .asciz "Press B to return to your previous location."

/* Each menu item is:
   - pointer to text (4 bytes)
   - type (1 byte) 
   - padding (1 byte)
   - target/data field (2 bytes)
     For submenu: target menu ID
     For text/link: low 2 bytes of content pointer 
   
   Total size: 8 bytes per menu item
   
   IMPORTANT: Content pointers are stored in separate fields (text_ptrs, link_ptrs)
   and retrieved using the item index as a lookup key
*/

/* Export these variables for utility_functions.S */
.global menu_table
.global content_table

.align 4
.global current_menu_id
.global current_selection
.global view_state
.global display_needs_update

current_menu_id:
    .dc.l    0               /* Current menu ID */
current_selection:
    .dc.l    0               /* Current menu selection index */
view_state:
    .dc.l    0               /* 0 = menu view, 1 = content view */
display_needs_update:
    .dc.l    0               /* Flag to indicate display needs update */

content_ptr:
    .dc.l    0               /* Pointer to current content */
navigation_stack_pos:
    .dc.l    0               /* Position in navigation stack */
refresh_lock:
    .dc.l    0               /* Lock to prevent constant screen refreshing */
counter_value:
    .dc.l    0               /* Counter for periodic updates */
delay_counter:
    .dc.l    0               /* Delay counter for periodic updates */
navigation_stack:
    .ds.l    16              /* Stack of menu IDs for navigation (max 16 levels) */
main_loop_toggle:
    .byte    '/'             /* Toggle character for main loop debug */
    .align 2                 /* Align to word boundary */
kbd_event_counter:
    .dc.l    0               /* Counter for keyboard interrupt events */
kbd_test_counter:
    .dc.l    0               /* Counter for keyboard test events */
keyboard_input_ready:
    .dc.l    0               /* Flag to indicate keyboard input is ready for processing */
key_debounce_timer:
    .dc.l    0               /* Debounce timer to prevent key repeat */

/* Scrolling variables */
scroll_offset:
    .dc.l    0               /* Current scroll position */
content_total_lines:
    .dc.l    0               /* Total lines in content */
