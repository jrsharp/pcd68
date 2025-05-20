/* JonSharp.net Cyberterminal
 * An interactive information terminal simulating a gopher-like experience
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
.equ KEY_H, 104                /* 'h' for Home */
.equ KEY_B, 98                 /* 'b' for Back */
.equ KEY_Q, 113                /* 'q' for Quit */
.equ KEY_QUESTION, 63          /* '?' for Help */
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

/* Function prototypes - internal for this file */

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
    
    /* Initialize keyboard controller */
    /* First, clear any pending interrupts and reports */
    moveb   #STATUS_CLEAR_INTERRUPT, KCTLStatus
    moveb   #0, KCTLCount
    moveb   #0, KCTLReportSize
    
    /* Then enable keyboard with interrupts - write the correct enable bit */
    moveb   #STATUS_KEYBOARD_ENABLED, KCTLStatus
    
    /* Make another read-modify-write to ensure the enable bit sticks */
    moveb   KCTLStatus, %d0
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
    
    /* Enable CPU interrupts */
    move    #0x2000, %sr         /* Enable all interrupts */
    
    /* Display debug text first (move to line 21, col 1, respecting borders) */
    moveal  #TDABase + 1 + (80 * 21) + 1, %a2
    moveb   #'M', (%a2)+
    moveb   #'e', (%a2)+
    moveb   #'n', (%a2)+
    moveb   #'u', (%a2)+
    moveb   #':', (%a2)+
    moveb   #' ', (%a2)+
    movel   #0, %d0              /* Main menu ID */
    jsr     get_menu_item_count
    addib   #'0', %d0            /* Convert to ASCII */
    moveb   %d0, (%a2)+
    
    /* Display initial screen */
    jsr     draw_header          /* This also calls draw_borders internally */
    jsr     draw_footer
    
    /* Initial display of content */
    jsr     clear_content_area   /* Clear content area first */
    jsr     display_current_menu

    /* Set initial update flag to true to ensure display refreshes */
    movel   #1, display_needs_update
    
    /* Draw all borders including the bottom border (once) */
    jsr     draw_borders
    
    /* Initialize counter display */
    jsr     update_status_line_with_counter
    
    /* Initial dummy key press to test keyboard processing */
    movel   #KEY_B, %d6         /* Simulate 'b' key */
    jsr     update_status_line   /* Show it on the status line */
    
    /* Write direct debug info about what we expect to see */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 60, %a2
    moveb   #'K', (%a2)+
    moveb   #'e', (%a2)+
    moveb   #'y', (%a2)+
    moveb   #':', (%a2)+
    moveb   #'b', (%a2)

/* Main Program Loop */
main_loop:
    /* Debug marker to show we're in the main loop - changes with each iteration */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 25, %a2
    
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
    
    /* Poll keyboard status directly as a test */
    moveb   KCTLStatus, %d0
    
    /* Display raw status byte - line 19, position 30 */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 30, %a2
    moveb   #'S', (%a2)+
    moveb   #':', (%a2)+
    
    /* Display status in hex */
    movel   %d0, %d1
    lsrl    #4, %d1             /* High nibble */
    andil   #0xF, %d1
    addil   #'0', %d1
    cmpl    #'9', %d1
    ble     status_high_ok
    addil   #7, %d1             /* Convert A-F */
status_high_ok:
    moveb   %d1, (%a2)+
    
    movel   %d0, %d1
    andil   #0xF, %d1           /* Low nibble */
    addil   #'0', %d1
    cmpl    #'9', %d1
    ble     status_low_ok
    addil   #7, %d1             /* Convert A-F */
status_low_ok:
    moveb   %d1, (%a2)
    
    /* Display KCTL report count in position 35 */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 35, %a2
    moveb   #'P', (%a2)+
    moveb   #':', (%a2)+
    moveb   KCTLCount, %d1
    addib   #'0', %d1
    moveb   %d1, (%a2)
    
    /* Direct keyboard polling approach - check for key input regardless of status */
    /* This is a workaround for potential issues with interrupt and flag handling */
    
    /* Ensure keyboard is enabled */
    moveb   KCTLStatus, %d0
    btst    #3, %d0              /* Test STATUS_KEYBOARD_ENABLED bit */
    bne     keyboard_already_enabled
    
    /* Keyboard not enabled, enable it */
    orib    #STATUS_KEYBOARD_ENABLED, %d0
    moveb   %d0, KCTLStatus
    
    /* Show that we enabled the keyboard */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 50, %a2
    moveb   #'E', (%a2)
    
keyboard_already_enabled:
    /* Now check for key input */
    moveb   KCTLCount, %d0
    cmpl    #0, %d0
    beq     direct_poll_check_done

    /* Show we've detected a key using direct polling */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 55, %a2
    moveb   #'D', (%a2)+
    
    /* Process it */
    moveb   KCTLReportSize, %d0
    cmpl    #0, %d0
    beq     direct_poll_check_done
    
    /* Have a report with keys - process first key */
    moveal  #KCTLKeys, %a0
    moveb   (%a0), %d0          /* Get first key */
    movel   %d0, %d6            /* Store in d6 for key display */
    
    /* Set status line update flag */
    movel   #1, display_needs_update
    
    /* Force refresh to happen */
    movel   #0, refresh_lock
    
    /* Update status line with key info */
    jsr     update_status_line
    
    /* Consume the report */
    moveb   #1, KCTLNextReport

direct_poll_check_done:
    /* Continue with normal interrupt-based handling */
    /* Check if a keyboard report is available */
    moveb   KCTLStatus, %d0
    btst    #0, %d0              /* Test REPORT_AVAILABLE bit */
    beq     main_loop_continue   /* No report available, continue */

    /* Process keyboard input - this will also update the status line */
    jsr     process_keyboard_input
    
    /* Force a display update when key is pressed */
    movel   #1, display_needs_update
    
    /* Wait a moment to see the key press */
    movel   #5000, %d0
key_delay_loop:
    subil   #1, %d0
    bne     key_delay_loop

main_loop_continue:
    /* Check if display needs updating */
    cmpl    #1, display_needs_update
    bne     main_loop_delay      /* No update needed, skip drawing */

    /* Process even if locked for key presses */
    cmpl    #1, refresh_lock
    bne     perform_refresh      /* Not locked, perform refresh normally */
    
    /* Check if we have a key press (d6 non-zero) to override lock */
    cmpl    #0, %d6
    beq     main_loop_delay      /* No key press and locked, skip drawing */

perform_refresh:
    
    /* Lock refreshing to prevent constant flickering */
    movel   #1, refresh_lock
    
    /* Clear the content area (preserving borders) */
    jsr     clear_content_area
    
    /* Display current menu content */
    jsr     display_current_menu
    
    /* Draw the status line with key information - pass key value in D6 */
    jsr     update_status_line
    
    /* Draw the commands line */
    jsr     update_commands_line
    
    /* Draw only the side and internal borders, not bottom border */
    jsr     refresh_borders
    
    /* Explicitly redraw the bottom border (line 22) which might be getting clobbered */
    movel   #22, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw bottom border line */
    moveb   #'+', (%a2)+
    movel   #0, %d0
refresh_bottom_border_loop:
    cmpl    #ScreenWidth - 2, %d0
    bge     refresh_bottom_border_end
    moveb   #'-', (%a2)+
    addl    #1, %d0
    bra     refresh_bottom_border_loop
refresh_bottom_border_end:
    moveb   #'+', (%a2)+
    
    /* Reset update flag */
    movel   #0, display_needs_update
    
    /* Delay before releasing lock to prevent too-frequent updates */
    movel   #100000, %d0
unlock_delay_loop:
    subil   #1, %d0
    bne     unlock_delay_loop
    movel   #0, refresh_lock     /* Release lock */

main_loop_delay:
    /* Small delay to prevent CPU thrashing */
    movel   #500, %d0
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
    
    /* Update status line directly without full screen refresh */
    jsr     update_status_line_with_counter
    
    /* Direct keyboard test: every few seconds inject a simulated key report */
    addil   #1, kbd_test_counter
    cmpl    #5, kbd_test_counter  /* Every 5 seconds */
    blt     skip_counter_update
    
    /* Reset the test counter */
    movel   #0, kbd_test_counter
    
    /* Make sure keyboard is enabled */
    moveb   KCTLStatus, %d0
    orib    #STATUS_KEYBOARD_ENABLED, %d0
    moveb   %d0, KCTLStatus
    
    /* Simulate a keyboard report being available */
    moveb   #1, KCTLReportSize   /* Set report size to 1 key */
    moveb   #97, KCTLKeys        /* ASCII 'a' */
    
    /* Set the report available flag */
    moveb   KCTLStatus, %d0
    orib    #STATUS_REPORT_AVAILABLE, %d0
    moveb   %d0, KCTLStatus
    
skip_counter_update:
    /* Continue the main loop */
    bra     main_loop

/* Update status line with counter value for debugging */
update_status_line_with_counter:
    /* Save registers */
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    movel   %a0, -(%sp)
    movel   %a2, -(%sp)
    
    /* Calculate position for status line (line 19) */
    movel   #19, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw left border */
    moveb   #'|', (%a2)+
    moveb   #' ', (%a2)+
    
    /* Clear status line with spaces first */
    movel   #1, %d1            /* Start after left border + space */
clear_counter_status_loop:
    cmpl    #ScreenWidth - 2, %d1  /* Stop before right border */
    bge     clear_counter_status_end
    moveb   #' ', (%a2)+
    addl    #1, %d1
    bra     clear_counter_status_loop
clear_counter_status_end:
    
    /* Position for counter display - right-aligned (5 chars before the end - "C: nnn") */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + ScreenWidth - 7, %a2
    
    /* Display the simple counter format "C: " */
    moveb   #'C', (%a2)+
    moveb   #':', (%a2)+
    moveb   #' ', (%a2)+
    
    /* Convert counter to decimal digits */
    movel   counter_value, %d0
    
    /* Handle hundreds */
    divu    #100, %d0
    movew   %d0, %d2           /* Save quotient (hundreds) */
    swap    %d0                /* Get remainder in lower word */
    addib   #'0', %d2          /* Convert to ASCII */
    moveb   %d2, (%a2)+        /* Display hundred digit */
    
    /* Handle tens */
    movew   %d0, %d0           /* Clear upper word */
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
    movel   (%sp)+, %a0
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Update status line with keyboard input information */
update_status_line:
    /* Save registers */
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %d6, -(%sp)
    movel   %a0, -(%sp)
    movel   %a2, -(%sp)
    
    /* Calculate position for status line (line 19) */
    movel   #19, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw left border */
    moveb   #'|', (%a2)+
    moveb   #' ', (%a2)+
    
    /* Clear status line with spaces first */
    movel   #1, %d1            /* Start after left border + space */
clear_status_loop:
    cmpl    #ScreenWidth - 2, %d1  /* Stop before right border */
    bge     clear_status_end
    moveb   #' ', (%a2)+
    addl    #1, %d1
    bra     clear_status_loop
clear_status_end:
    
    /* Reset position after clearing */
    moveal  #TDABase + 1 + (19 * ScreenWidth), %a2
    addl    #2, %a2            /* Skip left border and space */
    
    /* Show key information */
    lea     key_debug_text, %a5  /* "Key: " text */
    jsr     print_string_no_advance
    
    /* Display the key code in hex */
    movel   %d6, %d1            /* D6 should contain the key code from caller */
    lsrl    #4, %d1             /* Get high nibble */
    andil   #0xF, %d1
    addil   #'0', %d1
    cmpl    #'9', %d1           /* Convert A-F */
    ble     status_high_digit_ok
    addil   #7, %d1             /* Add 7 to get from '9'+1 to 'A' */
status_high_digit_ok:
    moveb   %d1, (%a2)+
    
    /* Low nibble */
    movel   %d6, %d1
    andil   #0xF, %d1
    addil   #'0', %d1
    cmpl    #'9', %d1           /* Convert A-F */
    ble     status_low_digit_ok
    addil   #7, %d1             /* Add 7 to get from '9'+1 to 'A' */
status_low_digit_ok:
    moveb   %d1, (%a2)+
    
    /* Add ASCII value if it's a printable character */
    moveb   #' ', (%a2)+
    moveb   #'(', (%a2)+
    
    /* Check if it's printable */
    cmpl    #32, %d6
    blt     status_not_printable
    cmpl    #126, %d6
    bgt     status_not_printable
    
    /* It's printable */
    moveb   %d6, (%a2)+
    bra     status_end_char_display
    
status_not_printable:
    moveb   #'?', (%a2)+
    
status_end_char_display:
    moveb   #')', (%a2)+
    
    /* Calculate position for selection indicator (right side) */
    /* Position cursor for selection at a specific location near the right edge */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + ScreenWidth - 9, %a2
    
    /* Draw selection indicator */
    lea     selection_text, %a5
    jsr     print_string_no_advance
    
    /* Draw current selection number */
    moveb   current_selection, %d0
    addib   #'1', %d0
    moveb   %d0, (%a2)+
    
    /* Close status line with right border */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + ScreenWidth - 1, %a2
    moveb   #'|', (%a2)
    
    /* Restore registers */
    movel   (%sp)+, %a2
    movel   (%sp)+, %a0
    movel   (%sp)+, %d1
    movel   (%sp)+, %d6
    movel   (%sp)+, %d0
    rts

/* Draw command footer line with only commands (replaces the key debug info) */
update_commands_line:
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
    /* A report is available, read its size */
    moveb   KCTLReportSize, %d5  /* Get number of keys in report */
    
    /* Display report size for debugging - line 19, position 15 */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 15, %a2
    moveb   #'R', (%a2)+
    moveb   #':', (%a2)+
    addb    #'0', %d5
    moveb   %d5, (%a2)
    
    /* Check if there are any keys in the report */
    moveb   KCTLReportSize, %d5
    beq     finish_key_input     /* No keys in report, finish */
    
    /* Read the first key from the report */
    moveal  #KCTLKeys, %a0
    moveb   (%a0), %d0
    
    /* Store key in D6 for status line update */
    movel   %d0, %d6
    
    /* Debug output for key code - line 19, position 20 */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 20, %a2
    moveb   #'K', (%a2)+
    moveb   #':', (%a2)+
    
    /* Display key code in hex */
    movel   %d0, %d1
    lsrl    #4, %d1             /* High nibble */
    andil   #0xF, %d1
    addil   #'0', %d1
    cmpl    #'9', %d1
    ble     debug_high_ok
    addil   #7, %d1             /* Convert A-F */
debug_high_ok:
    moveb   %d1, (%a2)+
    
    movel   %d0, %d1
    andil   #0xF, %d1           /* Low nibble */
    addil   #'0', %d1
    cmpl    #'9', %d1
    ble     debug_low_ok
    addil   #7, %d1             /* Convert A-F */
debug_low_ok:
    moveb   %d1, (%a2)
    
    /* Update the status line immediately */
    jsr     update_status_line
    
    /* Force display refresh to show key press */
    movel   #1, display_needs_update
    
    /* Reset the refresh lock to ensure update happens */
    movel   #0, refresh_lock
    
    /* Show debug marker to indicate key processing */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 10, %a2
    moveb   #'*', (%a2)
    
    /* Process the key based on its value */
    cmpb    #KEY_ESC, %d0
    beq     key_home
    cmpb    #KEY_H, %d0
    beq     key_home
    cmpb    #KEY_B, %d0
    beq     key_back
    cmpb    #KEY_QUESTION, %d0
    beq     key_help
    cmpb    #KEY_Q, %d0
    beq     key_quit
    
    /* Check for numeric keys for menu selection */
    cmpb    #KEY_1, %d0
    blt     finish_key_input
    cmpb    #KEY_9, %d0
    bgt     finish_key_input
    
    /* Convert key to menu item index (0-based) */
    subb    #KEY_1, %d0
    
    /* Check if this is a valid menu item */
    movew   current_menu_id, %d1
    jsr     get_menu_item_count
    cmpb    %d0, %d2
    bge     finish_key_input     /* Invalid menu item, finish */
    
    /* Valid menu item, set as current selection */
    moveb   %d0, current_selection
    
    /* Process the menu selection */
    jsr     process_menu_selection
    
finish_key_input:
    /* Advance to next report */
    moveb   #1, KCTLNextReport
    rts

/* Process the menu selection */
process_menu_selection:
    /* Load the selected menu item */
    movew   current_menu_id, %d0
    movew   current_selection, %d1
    
    /* Get the entry type */
    jsr     get_menu_entry_type
    
    /* Process based on type */
    cmpb    #ENTRY_TYPE_SUBMENU, %d0
    beq     process_submenu
    cmpb    #ENTRY_TYPE_TEXT, %d0
    beq     process_text
    cmpb    #ENTRY_TYPE_LINK, %d0
    beq     process_link
    
    /* Default action */
    jsr     set_display_update_flag
    rts

/* Process submenu selection */
process_submenu:
    /* Get the target menu ID */
    movew   current_menu_id, %d0
    movew   current_selection, %d1
    jsr     get_menu_target_id
    
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
    movew   #1, view_state       /* 1 = content view */
    
    /* Update display */
    jsr     set_display_update_flag
    rts

/* Process external link */
process_link:
    /* For now, just show a "link not available" message */
    lea     link_unavailable_msg, %a0
    movel   %a0, content_ptr
    
    /* Set state to content view */
    movew   #1, view_state       /* 1 = content view */
    
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
    movew   #0, current_menu_id
    movew   #0, current_selection
    movew   #0, view_state       /* 0 = menu view */
    
    /* Update display */
    jsr     set_display_update_flag
    rts

/* Go back to previous menu */
key_back:
    /* Check if we're in content view */
    cmpw    #1, view_state
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
    movew   %d0, current_menu_id
    movew   #0, current_selection
    
    /* Update display */
    jsr     set_display_update_flag
    rts

/* Return from content view to menu view */
return_to_menu_view:
    movew   #0, view_state       /* 0 = menu view */
    
    /* Update display */
    jsr     set_display_update_flag
    rts

/* Show help screen */
key_help:
    /* Set content pointer to help text */
    lea     help_text, %a0
    movel   %a0, content_ptr
    
    /* Set state to content view */
    movew   #1, view_state       /* 1 = content view */
    
    /* Update display */
    jsr     set_display_update_flag
    rts

/* Quit function (only useful in UART test mode) */
key_quit:
    /* For now, just go back to main menu */
    jsr     key_home
    rts

/* Set flag to update display */
set_display_update_flag:
    movel   #1, display_needs_update
    rts

/* Display the current menu or content */
display_current_menu:
    /* Check view state */
    cmpw    #0, view_state
    beq     display_menu_view
    cmpw    #1, view_state
    beq     display_content_view
    
    /* Default to menu view if state is invalid */
    jmp     display_menu_view

/* Display a menu */
display_menu_view:
    /* Position cursor in title area (line 2) */
    moveal  #TDABase + 1 + (80 * 2), %a2
    
    /* Draw a leading pipe for the title area */
    moveb   #'|', (%a2)+
    
    /* Display menu title centered */
    movew   current_menu_id, %d0
    jsr     get_menu_title
    
    /* Store title pointer */
    moveal  %a0, %a5
    
    /* Simple print of title - just to debug */
    moveb   #' ', (%a2)+
    jsr     print_string_no_advance
    
    /* Add a pipe at the end */
    moveal  #TDABase + 1 + (80 * 2) + 79, %a2
    moveb   #'|', (%a2)
    
    /* Move to content area for menu items (line 4) */
    moveal  #TDABase + 1 + (80 * 4), %a2
    
    /* Print menu items */
    movew   current_menu_id, %d0
    jsr     get_menu_item_count
    movew   %d0, %d7            /* Menu item count */
    
    /* Loop through menu items */
    movew   #0, %d6             /* Current item index */
display_menu_loop:
    cmpw    %d7, %d6
    bge     display_menu_end
    
    /* Position cursor for this menu item - using content area lines */
    movel   %d6, %d0
    addl    #4, %d0             /* Start at line 4 (first content line) */
    muls    #80, %d0            /* 80 characters per line (use muls not mull) */
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Add left border pipe */
    moveb   #'|', (%a2)+
    
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
    
    /* Display menu item text */
    movew   current_menu_id, %d0
    movew   %d6, %d1
    
    /* Try to get menu item directly from string pointers */
    cmpl    #0, %d0
    bne     not_main_menu
    
    /* Handle main menu items manually */
    cmpl    #0, %d6
    bne     not_main_item1
    lea     main_menu_item1, %a5
    bra     print_item_text
    
not_main_item1:
    cmpl    #1, %d6
    bne     not_main_item2
    lea     main_menu_item2, %a5
    bra     print_item_text
    
not_main_item2:
    cmpl    #2, %d6
    bne     not_main_item3
    lea     main_menu_item3, %a5
    bra     print_item_text
    
not_main_item3:
    cmpl    #3, %d6
    bne     not_main_item4
    lea     main_menu_item4, %a5
    bra     print_item_text
    
not_main_item4:
    cmpl    #4, %d6
    bne     use_normal_lookup
    lea     main_menu_item5, %a5
    bra     print_item_text
    
not_main_menu:
    /* Continue with normal lookup for other menus */
    
use_normal_lookup:
    jsr     get_menu_item_text
    moveal  %a0, %a5

print_item_text:
    /* Print the menu item text */
    jsr     print_string
    
    /* Next menu item */
    addw    #1, %d6
    bra     display_menu_loop
    
display_menu_end:
    rts

/* Display content view */
display_content_view:
    /* Position cursor at content area start */
    moveal  #TDABase + 1 + (80 * 2), %a2
    
    /* Display content from pointer */
    moveal  content_ptr, %a5
    jsr     print_string
    rts

/* Clear the content area of the screen based on our layout */
clear_content_area:
    /* Position at the start of content area (line 4) */
    movel   #4, %d7             /* Start at line 4 */
clear_area_line_loop:
    cmpl    #18, %d7            /* End at line 17 (before line 18) */
    bge     clear_area_done
    
    /* Position at start of this line */
    muls    #ScreenWidth, %d7
    lea     TDABase + 1, %a0
    addl    %d7, %a0
    moveal  %a0, %a2
    
    /* Draw left border pipe */
    moveb   #'|', (%a2)+
    
    /* Clear rest of line until right border */
    movel   #1, %d6             /* Start after left border */
clear_area_char_loop:
    cmpl    #ScreenWidth - 1, %d6  /* Stop before right border */
    bge     clear_area_next_line
    
    /* Write space to clear area */
    moveb   #' ', (%a2)+
    
    addl    #1, %d6
    bra     clear_area_char_loop
    
clear_area_next_line:
    /* Draw right border */
    moveb   #'|', (%a2)
    
    /* Convert line position back from offset */
    divs    #ScreenWidth, %d7
    
    addl    #1, %d7
    bra     clear_area_line_loop
    
clear_area_done:
    /* Reset cursor position to start of content area (after left border) */
    moveal  #TDABase + 1 + (80 * 4) + 1, %a2
    rts

/* Clear the entire screen */
clear_screen:
    /* Position at the start of screen */
    moveal  #TDABase + 1, %a2
    
    /* Fill entire screen with spaces */
    movel   #0, %d7             /* Line counter */
clear_screen_line_loop:
    cmpl    #ScreenHeight, %d7
    bge     clear_screen_done
    
    movel   #0, %d6             /* Column counter */
clear_screen_char_loop:
    cmpl    #ScreenWidth, %d6
    bge     clear_screen_next_line
    
    /* Write space character */
    moveb   #' ', (%a2)+
    
    addl    #1, %d6
    bra     clear_screen_char_loop
    
clear_screen_next_line:
    addl    #1, %d7
    bra     clear_screen_line_loop
    
clear_screen_done:
    rts

/* Center text pointed to by A5 at current position in A2 */
center_text:
    /* Save A2 */
    movel   %a2, -(%sp)
    
    /* Calculate text length */
    moveal  %a5, %a0
    movel   #0, %d0             /* Counter */
center_length_loop:
    moveb   (%a0)+, %d1
    cmpb    #0, %d1             /* Check for null terminator */
    beq     center_length_done
    addl    #1, %d0
    bra     center_length_loop
    
center_length_done:
    /* Calculate padding */
    movel   #ScreenWidth, %d1
    subl    %d0, %d1            /* Screen width - text length */
    divs    #2, %d1             /* Divide by 2 for left padding */
    
    /* Add left padding */
    movel   #0, %d2
center_padding_loop:
    cmpl    %d1, %d2
    bge     center_padding_done
    moveb   #' ', (%a2)+
    addl    #1, %d2
    bra     center_padding_loop
    
center_padding_done:
    /* Print the text */
    jsr     print_string
    
    /* Restore A2 */
    movel   (%sp)+, %a2
    rts

/* Draw all borders on the screen based on layout */
draw_borders:
    /* Position at the start of screen (line 0) */
    moveal  #TDABase + 1, %a2
    
    /* Draw top border line */
    moveb   #'+', (%a2)+
    movel   #0, %d0
top_border_loop:
    cmpl    #ScreenWidth - 2, %d0
    bge     top_border_end
    moveb   #'-', (%a2)+
    addl    #1, %d0
    bra     top_border_loop
top_border_end:
    moveb   #'+', (%a2)+
    
    /* Draw border after header area (line 3) */
    movel   #3, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw border line */
    moveb   #'+', (%a2)+
    movel   #0, %d0
header_border_loop:
    cmpl    #ScreenWidth - 2, %d0
    bge     header_border_end
    moveb   #'-', (%a2)+
    addl    #1, %d0
    bra     header_border_loop
header_border_end:
    moveb   #'+', (%a2)+
    
    /* Draw border after content area (line 18) */
    movel   #18, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw border line */
    moveb   #'+', (%a2)+
    movel   #0, %d0
content_border_loop:
    cmpl    #ScreenWidth - 2, %d0
    bge     content_border_end
    moveb   #'-', (%a2)+
    addl    #1, %d0
    bra     content_border_loop
content_border_end:
    moveb   #'+', (%a2)+
    
    /* Draw border after status area (line 20) */
    movel   #20, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw status border line */
    moveb   #'+', (%a2)+
    movel   #0, %d0
status_border_loop:
    cmpl    #ScreenWidth - 2, %d0
    bge     status_border_end
    moveb   #'-', (%a2)+
    addl    #1, %d0
    bra     status_border_loop
status_border_end:
    moveb   #'+', (%a2)+
    
    /* Draw border after footer area (line 22) */
    movel   #22, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw bottom border line */
    moveb   #'+', (%a2)+
    movel   #0, %d0
bottom_border_loop:
    cmpl    #ScreenWidth - 2, %d0
    bge     bottom_border_end
    moveb   #'-', (%a2)+
    addl    #1, %d0
    bra     bottom_border_loop
bottom_border_end:
    moveb   #'+', (%a2)+
    
    /* Draw vertical borders */
    movel   #1, %d7             /* Start at line 1 */
vertical_borders_loop:
    cmpl    #22, %d7            /* Until line 22 */
    bge     vertical_borders_end
    
    /* Skip border lines which we already drew */
    cmpl    #3, %d7
    beq     vertical_next_line
    cmpl    #18, %d7
    beq     vertical_next_line
    cmpl    #20, %d7
    beq     vertical_next_line
    
    /* Draw left border */
    muls    #ScreenWidth, %d7
    lea     TDABase + 1, %a0
    addl    %d7, %a0
    moveb   #'|', (%a0)
    
    /* Draw right border */
    addl    #ScreenWidth - 1, %a0
    moveb   #'|', (%a0)
    
    /* Back to line index */
    divs    #ScreenWidth, %d7
    
vertical_next_line:
    addl    #1, %d7
    bra     vertical_borders_loop
    
vertical_borders_end:
    rts

/* Draw header at top of screen */
draw_header:
    /* Call border drawing routine */
    jsr     draw_borders
    
    /* Position at header content area (line 1) */
    moveal  #TDABase + 1 + ScreenWidth, %a2
    
    /* Draw header title */
    moveb   #'|', (%a2)+
    moveb   #' ', (%a2)+
    
    lea     header_title, %a5
    jsr     print_string_no_advance
    
    /* Fill remaining space */
    movel   %a2, %a1
    subal   #TDABase + 1 + ScreenWidth, %a1
    movel   #ScreenWidth - 2, %d0
    subl    %a1, %d0
    subl    #version_text_length, %d0 /* Reserve space for version */
    
    movel   #0, %d1
header_space_loop:
    cmpl    %d0, %d1
    bge     header_space_end
    moveb   #' ', (%a2)+
    addl    #1, %d1
    bra     header_space_loop
header_space_end:
    
    /* Draw version text */
    lea     version_text, %a5
    jsr     print_string_no_advance
    
    /* Close header line */
    moveb   #'|', (%a2)+
    
    /* Position at header line 2 */
    moveal  #TDABase + 1 + (ScreenWidth * 2), %a2
    
    /* Draw header line 2 (title area) */
    moveb   #'|', (%a2)+
    moveb   #' ', (%a2)+
    
    /* Add current menu title centered */
    movew   current_menu_id, %d0
    jsr     get_menu_title
    moveal  %a0, %a5
    jsr     center_text
    
    /* Close header line 2 */
    moveal  #TDABase + 1 + (80 * 2) + 79, %a2
    moveb   #'|', (%a2)
    
    rts

/* Draw footer at bottom of screen */
draw_footer:
    /* Calculate position for status line (line 19) */
    movel   #19, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw line with navigation info and status */
    moveb   #'|', (%a2)+
    moveb   #' ', (%a2)+
    
    /* Draw current menu/state indicator */
    lea     status_text, %a5
    jsr     print_string_no_advance
    
    /* Print current menu name */
    movew   current_menu_id, %d0
    jsr     get_menu_title
    moveal  %a0, %a5
    jsr     print_string_no_advance
    
    /* Fill remaining space */
    movel   %a2, %a1
    subal   %a0, %a1
    subl    #ScreenWidth, %a1
    subl    #2, %a1            /* Account for | and space */
    movel   #ScreenWidth - 2, %d0
    subl    %a1, %d0
    subl    #12, %d0           /* Reserve space for "Sel: _" */
    
    movel   #0, %d1
footer_space_loop:
    cmpl    %d0, %d1
    bge     footer_space_end
    moveb   #' ', (%a2)+
    addl    #1, %d1
    bra     footer_space_loop
footer_space_end:
    
    /* Draw selection indicator */
    lea     selection_text, %a5
    jsr     print_string_no_advance
    
    /* Draw current selection number */
    moveb   current_selection, %d0
    addib   #'1', %d0
    moveb   %d0, (%a2)+
    
    /* Fill remaining space */
    movel   %a2, %a1
    subal   %a0, %a1
    subl    #ScreenWidth, %a1
    subl    #2, %a1            /* Account for | and space */
    movel   #ScreenWidth - 2, %d0
    subl    %a1, %d0
    
    movel   #0, %d1
footer_end_space_loop:
    cmpl    %d0, %d1
    bge     footer_end_space_end
    moveb   #' ', (%a2)+
    addl    #1, %d1
    bra     footer_end_space_loop
footer_end_space_end:
    
    /* Close status line */
    moveb   #'|', (%a2)+
    
    /* Position for commands line (line 21) */
    movel   #21, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw commands list */
    moveb   #'|', (%a2)+
    moveb   #' ', (%a2)+
    
    lea     footer_commands, %a5
    jsr     print_string_no_advance
    
    /* Fill rest of the line with spaces */
    movel   %a2, %a1
    subal   %a0, %a1
    subl    #ScreenWidth, %a1
    subl    #2, %a1            /* Account for | and space */
    movel   #ScreenWidth - 2, %d0
    subl    %a1, %d0
    
    movel   #0, %d1
commands_space_loop:
    cmpl    %d0, %d1
    bge     commands_space_end
    moveb   #' ', (%a2)+
    addl    #1, %d1
    bra     commands_space_loop
commands_space_end:
    
    /* Close command line */
    moveb   #'|', (%a2)+
    
    rts

/* Clear the debug line (line 20) - replaced with a border line, not debug info */
clear_debug_line:
    /* call the utility function to draw the border instead of debug info */
    jsr     utility_clear_debug_line
    rts

/* Refresh only the necessary borders without redrawing the bottom border */
refresh_borders:
    /* Save registers */
    movel   %d0, -(%sp)
    movel   %d7, -(%sp)
    movel   %d6, -(%sp)
    movel   %a0, -(%sp)
    movel   %a2, -(%sp)
    
    /* Draw border after content area (line 18) */
    movel   #18, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw border line */
    moveb   #'+', (%a2)+
    movel   #0, %d0
content_border_refresh_loop:
    cmpl    #ScreenWidth - 2, %d0
    bge     content_border_refresh_end
    moveb   #'-', (%a2)+
    addl    #1, %d0
    bra     content_border_refresh_loop
content_border_refresh_end:
    moveb   #'+', (%a2)+
    
    /* Draw border after status area (line 20) */
    movel   #20, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw status border line */
    moveb   #'+', (%a2)+
    movel   #0, %d0
status_border_refresh_loop:
    cmpl    #ScreenWidth - 2, %d0
    bge     status_border_refresh_end
    moveb   #'-', (%a2)+
    addl    #1, %d0
    bra     status_border_refresh_loop
status_border_refresh_end:
    moveb   #'+', (%a2)+
    
    /* Draw vertical borders (only sides) */
    movel   #1, %d7             /* Start at line 1 */
vertical_borders_refresh_loop:
    cmpl    #22, %d7            /* Until line 22 (but not including line 22) */
    bge     vertical_borders_refresh_end
    
    /* Skip border lines which we already drew */
    cmpl    #3, %d7
    beq     vertical_refresh_next_line
    cmpl    #18, %d7
    beq     vertical_refresh_next_line
    cmpl    #20, %d7
    beq     vertical_refresh_next_line
    
    /* Draw left border */
    muls    #ScreenWidth, %d7
    lea     TDABase + 1, %a0
    addl    %d7, %a0
    moveb   #'|', (%a0)
    
    /* Draw right border */
    addl    #ScreenWidth - 1, %a0
    moveb   #'|', (%a0)
    
    /* Back to line index */
    divs    #ScreenWidth, %d7
    
vertical_refresh_next_line:
    addl    #1, %d7
    bra     vertical_borders_refresh_loop
    
vertical_borders_refresh_end:
    /* Restore registers */
    movel   (%sp)+, %a2
    movel   (%sp)+, %a0
    movel   (%sp)+, %d6
    movel   (%sp)+, %d7
    movel   (%sp)+, %d0
    rts

/* Keyboard interrupt handler */
keyboard_handler:
    /* Save registers immediately */
    movel   %d0, -(%sp)
    movel   %a0, -(%sp)
    
    /* Increment keyboard event counter */
    addil   #1, kbd_event_counter
    
    /* Display an indicator that the interrupt was called - fixed position shows count */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 40, %a0
    moveb   #'I', (%a0)+
    
    /* Show interrupt counter */
    movel   kbd_event_counter, %d0
    divu    #10, %d0
    swap    %d0
    addib   #'0', %d0
    moveb   %d0, (%a0)
    
    /* Display keyboard controller status byte */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 45, %a0
    moveb   KCTLStatus, %d0
    lsrl    #4, %d0             /* High nibble */
    andil   #0xF, %d0
    addil   #'0', %d0
    cmpl    #'9', %d0
    ble     int_high_ok
    addil   #7, %d0             /* Convert A-F */
int_high_ok:
    moveb   %d0, (%a0)+
    
    moveb   KCTLStatus, %d0
    andil   #0xF, %d0           /* Low nibble */
    addil   #'0', %d0
    cmpl    #'9', %d0
    ble     int_low_ok
    addil   #7, %d0             /* Convert A-F */
int_low_ok:
    moveb   %d0, (%a0)
    
    /* Set display update flag to ensure keyboard input is processed */
    movel   #1, display_needs_update
    
    /* Reset the refresh lock to ensure display update happens immediately */
    movel   #0, refresh_lock
    
    /* Clear the interrupt flag - important for clearing pending interrupt */
    moveb   #STATUS_CLEAR_INTERRUPT, KCTLStatus
    
    /* Restore registers */
    movel   (%sp)+, %a0
    movel   (%sp)+, %d0
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
    .string "[v1.0-2025]"
.equ version_text_length, 10

footer_commands:
    .string "Commands: [H]ome [B]ack [?]Help [Q]uit"
status_text:
    .string "Location: "
selection_text:
    .string "Sel: "
key_debug_text:
    .string "Key: "
counter_text:
    .string "Counter: "

exception_msg:
    .string "*** Exception occurred! System halted. ***"

link_unavailable_msg:
    .string "This link is not available in the cyberterminal.\n\nPlease visit jonsharp.net to view this content online."

unknown_menu_title:
    .string "Unknown Menu"
unknown_menu_item_text:
    .string "Unknown item"
unknown_content_text:
    .string "Content not available."

/* Menu Titles */
main_menu_title:
    .string "Main Menu"
about_menu_title:
    .string "About Jon Sharp"
projects_menu_title:
    .string "Projects"
blog_menu_title:
    .string "Blog"
resources_menu_title:
    .string "Resources"
contact_menu_title:
    .string "Contact Information"

/* Main Menu Items */
main_menu_item1:
    .string "About Jon Sharp"
main_menu_item2:
    .string "Projects"
main_menu_item3:
    .string "Blog"
main_menu_item4:
    .string "Resources"
main_menu_item5:
    .string "Contact"

main_menu_items:
    .long main_menu_item1
    .long main_menu_item2
    .long main_menu_item3
    .long main_menu_item4
    .long main_menu_item5

/* About Menu Items */
about_menu_item1:
    .string "Bio"
about_menu_item2:
    .string "Skills & Interests"
about_menu_item3:
    .string "Experience"

about_menu_items:
    .long about_menu_item1
    .long about_menu_item2
    .long about_menu_item3

/* Projects Menu Items */
projects_menu_item1:
    .string "PCD-68 Computer"
projects_menu_item2:
    .string "Hardware Projects"
projects_menu_item3:
    .string "Software Projects (External Link)"

projects_menu_items:
    .long projects_menu_item1
    .long projects_menu_item2
    .long projects_menu_item3

/* Blog Menu Items */
blog_menu_item1:
    .string "Recent Posts"
blog_menu_item2:
    .string "Archives"

blog_menu_items:
    .long blog_menu_item1
    .long blog_menu_item2

/* Resources Menu Items */
resources_menu_item1:
    .string "Links"
resources_menu_item2:
    .string "Downloads"

resources_menu_items:
    .long resources_menu_item1
    .long resources_menu_item2

/* Contact Menu Items */
contact_menu_item1:
    .string "Contact Information"

contact_menu_items:
    .long contact_menu_item1

/* Content Texts */
help_text:
    .string "JonSharp.net Cyberterminal Help\n\n"
    .string "Navigation Commands:\n"
    .string "  - Use number keys (1-9) to select menu items\n"
    .string "  - Press H to return to the home menu\n"
    .string "  - Press B to go back to the previous menu\n"
    .string "  - Press ? to display this help screen\n"
    .string "  - Press Q to quit (when available)\n\n"
    .string "The cyberterminal provides a simplified gopher-like\n"
    .string "interface to jonsharp.net content.\n\n"
    .string "Press B to return to your previous location."

about_bio_text:
    .string "About Jon Sharp\n\n"
    .string "Jon Sharp is a software engineer and hardware enthusiast\n"
    .string "with a passion for retro computing, embedded systems, and\n"
    .string "open source development.\n\n"
    .string "He created the PCD-68, a virtual retro computer powered\n"
    .string "by a 68000 CPU emulator, as a platform for experimental\n"
    .string "software and hardware development.\n\n"
    .string "Jon enjoys reviving old hardware, exploring retro computer\n"
    .string "architectures, and building electronic projects that blend\n"
    .string "vintage aesthetics with modern capabilities."

about_skills_text:
    .string "Skills & Interests\n\n"
    .string "- 68000 Assembly Programming\n"
    .string "- Embedded System Design\n"
    .string "- C/C++ Development\n"
    .string "- Hardware Prototyping\n"
    .string "- Retrocomputing\n"
    .string "- PCB Design\n"
    .string "- Digital Electronics\n"
    .string "- Emulator Development\n"
    .string "- Operating System Fundamentals\n"
    .string "- Web Technologies\n"
    .string "- Open Source Development"

about_experience_text:
    .string "Experience\n\n"
    .string "Jon has worked on various software and hardware projects,\n"
    .string "focusing on embedded systems and retro computing.\n\n"
    .string "Notable projects include:\n\n"
    .string "- PCD-68: A 68000-based virtual retro computer\n"
    .string "- Custom PCB designs for retro hardware\n"
    .string "- Gopher server for jonsharp.net\n"
    .string "- Various retro computer restoration projects\n"
    .string "- Open source contributions to emulator projects"

projects_pcd68_text:
    .string "PCD-68 Computer\n\n"
    .string "The PCD-68 is a Motorola 68000-based virtual retro computer\n"
    .string "emulator that simulates hardware inspired by late 80s/early\n"
    .string "90s computers. It draws inspiration from the original\n"
    .string "Macintosh, Canon Cat, and modern 68k homebrew machines.\n\n"
    .string "System Specifications:\n\n"
    .string "- 68000 CPU (emulation provided by Moira)\n"
    .string "- 400x300 B/W Framebuffer/Display\n"
    .string "- Text Display Adapter (TDA) with text-based graphics modes\n"
    .string "- 4MB RAM\n"
    .string "- 64KB ROM\n"
    .string "- Dual UART (similar to Z80 SCC)\n"
    .string "- Interrupt-driven Keyboard I/O\n\n"
    .string "The emulator is being developed to eventually power\n"
    .string "actual hardware."

projects_hardware_text:
    .string "Hardware Projects\n\n"
    .string "Jon has worked on various hardware projects, focusing on\n"
    .string "retrocomputing and embedded systems:\n\n"
    .string "- Custom keyboard controllers\n"
    .string "- UART-based communication modules\n"
    .string "- 68k single-board computer designs\n"
    .string "- Display adapters for monochrome screens\n"
    .string "- Interfacing modern hardware with retro systems\n\n"
    .string "Many of these projects have contributed to the development\n"
    .string "of the PCD-68 system, serving as test platforms for concepts\n"
    .string "that would later be implemented in the emulator."

blog_recent_text:
    .string "Recent Blog Posts\n\n"
    .string "Implementing a UART in the PCD-68 Emulator\n"
    .string "May 5, 2025\n\n"
    .string "I recently added a UART peripheral to the PCD-68 emulator,\n"
    .string "inspired by the Zilog 85230 SCC. This allows the virtual\n"
    .string "machine to communicate with external devices through\n"
    .string "serial protocols.\n\n"
    .string "---\n\n"
    .string "Keyboard Input for the PCD-68\n"
    .string "April 20, 2025\n\n"
    .string "The latest addition to the PCD-68 is a proper keyboard\n"
    .string "interface that handles multiple keypresses and modifiers.\n"
    .string "This implementation is inspired by USB HID keyboard reports."

blog_archives_text:
    .string "Blog Archives\n\n"
    .string "2025:\n"
    .string "- Implementing a UART in the PCD-68 Emulator (May 5)\n"
    .string "- Keyboard Input for the PCD-68 (April 20)\n"
    .string "- Text Display Adapter Improvements (March 15)\n"
    .string "- Building a Custom 68k Assembler (February 28)\n"
    .string "- PCD-68 Web Interface Launch (January 10)\n\n"
    .string "2024:\n"
    .string "- Year in Review: Retrocomputing Projects (December 31)\n"
    .string "- First Boot of the PCD-68 Emulator (November 15)\n"
    .string "- Moira 68000 CPU Core Integration (October 5)\n"
    .string "- Project Announcement: PCD-68 (September 1)"

contact_info_text:
    .string "Contact Information\n\n"
    .string "Jon Sharp can be reached through the following channels:\n\n"
    .string "Website: https://jonsharp.net\n"
    .string "Gopher: gopher://jonsharp.net\n"
    .string "Email: jon@jonsharp.net\n\n"
    .string "For project updates and source code:\n"
    .string "GitHub: https://github.com/jonsharp\n\n"
    .string "Feel free to reach out with questions, comments, or\n"
    .string "collaboration ideas related to retrocomputing, 68k\n"
    .string "development, or any of the projects mentioned in\n"
    .string "this cyberterminal."

/* Menu Table Structure */
/* Each menu definition is: 
   - pointer to title (4 bytes)
   - item count (2 bytes) 
   - padding (2 bytes)
   - pointer to item array (4 bytes)
*/

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
.global content_text_ptrs

/* Define menu table - each entry is a pointer to a menu definition */
menu_table:
    .long    main_menu_def    /* Menu ID 0 - Main Menu */
    .long    about_menu_def   /* Menu ID 1 - About */
    .long    projects_menu_def /* Menu ID 2 - Projects */
    .long    blog_menu_def    /* Menu ID 3 - Blog */
    .long    resources_menu_def /* Menu ID 4 - Resources */
    .long    contact_menu_def /* Menu ID 5 - Contact */

/* Main Menu Definition */
main_menu_def:
    .long    main_menu_title  /* Title pointer */
    .word    5                /* Item count */
    .word    0                /* Padding */
    .long    main_menu_items_array /* Item array pointer */

main_menu_items_array:
    /* Item 1 - About */
    .long    main_menu_item1  /* Text pointer */
    .byte    ENTRY_TYPE_SUBMENU /* Type */
    .byte    0                /* Padding */
    .word    1                /* Target menu ID */
    
    /* Item 2 - Projects */
    .long    main_menu_item2  /* Text pointer */
    .byte    ENTRY_TYPE_SUBMENU /* Type */
    .byte    0                /* Padding */
    .word    2                /* Target menu ID */
    
    /* Item 3 - Blog */
    .long    main_menu_item3  /* Text pointer */
    .byte    ENTRY_TYPE_SUBMENU /* Type */
    .byte    0                /* Padding */
    .word    3                /* Target menu ID */
    
    /* Item 4 - Resources */
    .long    main_menu_item4  /* Text pointer */
    .byte    ENTRY_TYPE_SUBMENU /* Type */
    .byte    0                /* Padding */
    .word    4                /* Target menu ID */
    
    /* Item 5 - Contact */
    .long    main_menu_item5  /* Text pointer */
    .byte    ENTRY_TYPE_SUBMENU /* Type */
    .byte    0                /* Padding */
    .word    5                /* Target menu ID */

/* About Menu Definition */
about_menu_def:
    .long    about_menu_title /* Title pointer */
    .word    3                /* Item count */
    .word    0                /* Padding */
    .long    about_menu_items_array /* Item array pointer */

about_menu_items_array:
    /* Item 1 - Bio */
    .long    about_menu_item1 /* Text pointer */
    .byte    ENTRY_TYPE_TEXT  /* Type */
    .byte    0                /* Padding */
    .word    1                /* Data value for lookup (item index) */
    
    /* Item 2 - Skills */
    .long    about_menu_item2 /* Text pointer */
    .byte    ENTRY_TYPE_TEXT  /* Type */
    .byte    0                /* Padding */
    .word    2                /* Data value for lookup (item index) */
    
    /* Item 3 - Experience */
    .long    about_menu_item3 /* Text pointer */
    .byte    ENTRY_TYPE_TEXT  /* Type */
    .byte    0                /* Padding */
    .word    3                /* Data value for lookup (item index) */

/* Projects Menu Definition */
projects_menu_def:
    .long    projects_menu_title /* Title pointer */
    .word    3                /* Item count */
    .word    0                /* Padding */
    .long    projects_menu_items_array /* Item array pointer */

projects_menu_items_array:
    /* Item 1 - PCD-68 */
    .long    projects_menu_item1 /* Text pointer */
    .byte    ENTRY_TYPE_TEXT  /* Type */
    .byte    0                /* Padding */
    .word    1                /* Data value for lookup (item index) */
    
    /* Item 2 - Hardware */
    .long    projects_menu_item2 /* Text pointer */
    .byte    ENTRY_TYPE_TEXT  /* Type */
    .byte    0                /* Padding */
    .word    2                /* Data value for lookup (item index) */
    
    /* Item 3 - External Link */
    .long    projects_menu_item3 /* Text pointer */
    .byte    ENTRY_TYPE_LINK  /* Type */
    .byte    0                /* Padding */
    .word    3                /* Data value for lookup (item index) */

/* Blog Menu Definition */
blog_menu_def:
    .long    blog_menu_title  /* Title pointer */
    .word    2                /* Item count */
    .word    0                /* Padding */
    .long    blog_menu_items_array /* Item array pointer */

blog_menu_items_array:
    /* Item 1 - Recent */
    .long    blog_menu_item1  /* Text pointer */
    .byte    ENTRY_TYPE_TEXT  /* Type */
    .byte    0                /* Padding */
    .word    1                /* Data value for lookup (item index) */
    
    /* Item 2 - Archives */
    .long    blog_menu_item2  /* Text pointer */
    .byte    ENTRY_TYPE_TEXT  /* Type */
    .byte    0                /* Padding */
    .word    2                /* Data value for lookup (item index) */

/* Resources Menu Definition */
resources_menu_def:
    .long    resources_menu_title /* Title pointer */
    .word    2                /* Item count */
    .word    0                /* Padding */
    .long    resources_menu_items_array /* Item array pointer */

resources_menu_items_array:
    /* Item 1 - Links */
    .long    resources_menu_item1 /* Text pointer */
    .byte    ENTRY_TYPE_LINK  /* Type */
    .byte    0                /* Padding */
    .word    1                /* Data value for lookup (item index) */
    
    /* Item 2 - Downloads */
    .long    resources_menu_item2 /* Text pointer */
    .byte    ENTRY_TYPE_LINK  /* Type */
    .byte    0                /* Padding */
    .word    2                /* Data value for lookup (item index) */

/* Contact Menu Definition */
contact_menu_def:
    .long    contact_menu_title /* Title pointer */
    .word    1                /* Item count */
    .word    0                /* Padding */
    .long    contact_menu_items_array /* Item array pointer */

contact_menu_items_array:
    /* Item 1 - Contact Info */
    .long    contact_menu_item1 /* Text pointer */
    .byte    ENTRY_TYPE_TEXT  /* Type */
    .byte    0                /* Padding */
    .word    1                /* Data value for lookup (item index) */

/* Content pointer tables */
/* Table format: menu ID * 16 + item index = array index */
content_text_ptrs:
    /* Menu 0 (Main Menu) has no text content */
    .long    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    
    /* Menu 1 (About) text content */
    .long    0                /* Item 0 - not used */
    .long    about_bio_text   /* Item 1 */
    .long    about_skills_text /* Item 2 */
    .long    about_experience_text /* Item 3 */
    .long    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0   /* Padding */
    
    /* Menu 2 (Projects) text content */
    .long    0                /* Item 0 - not used */
    .long    projects_pcd68_text /* Item 1 */
    .long    projects_hardware_text /* Item 2 */
    .long    0                /* Item 3 - External link */
    .long    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0   /* Padding */
    
    /* Menu 3 (Blog) text content */
    .long    0                /* Item 0 - not used */
    .long    blog_recent_text /* Item 1 */
    .long    blog_archives_text /* Item 2 */
    .long    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0   /* Padding */
    
    /* Menu 4 (Resources) has no text content */
    .long    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    
    /* Menu 5 (Contact) text content */
    .long    0                /* Item 0 - not used */
    .long    contact_info_text /* Item 1 */
    .long    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0   /* Padding */

/* Variables section - continue in text section */
    .align 4
.global current_menu_id
.global current_selection
.global view_state

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

/* Helper Functions */

/* Print a null-terminated string pointed to by A5 at the current position in A2 */
.global print_string
print_string:
    /* Save registers */
    movel   %a5, -(%sp)
    
    /* Print characters until null */
print_loop:
    moveb   (%a5)+, %d0
    beq     print_done
    
    /* Write character to TDA */
    moveb   %d0, (%a2)+
    
    bra     print_loop
    
print_done:
    /* Restore registers */
    movel   (%sp)+, %a5
    rts

/* Print a null-terminated string pointed to by A5 at the current position in A2,
   without advancing to next line */
.global print_string_no_advance
print_string_no_advance:
    /* Save registers */
    movel   %a5, -(%sp)
    
    /* Print characters until null */
print_no_advance_loop:
    moveb   (%a5)+, %d0
    beq     print_no_advance_done
    
    /* Write character to TDA */
    moveb   %d0, (%a2)+
    
    bra     print_no_advance_loop
    
print_no_advance_done:
    /* Restore registers */
    movel   (%sp)+, %a5
    rts