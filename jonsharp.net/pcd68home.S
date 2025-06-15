/* JonSharp.net Cyberterminal
 * An interactive information terminal simulating a gopher-like experience
 * Content served is a versioned release of the "best of" jonsharp.net.
 * Enhanced with Art Mode Support - Press 'p' to view bitmap images!
 */

/* Define memory locations and constants */
.equ ScrnBase, 0x430002
.equ TDABase, 0x410000
.equ KCTLBase, 0x420000
.equ UARTBase, 0x450000
.equ UART1_BASE, 0x450000
.equ UART1_TX, UART1_BASE + 0x00
.equ UART1_RX, UART1_BASE + 0x01
.equ UART1_STATUS, UART1_BASE + 0x02
.equ UART1_CONTROL, UART1_BASE + 0x03

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
.equ GraphicsMode, 0           /* 0 = NONE mode (TDA disabled for art mode) */
.equ MaxMenuItems, 20          /* Maximum items in a menu */
.equ MaxContentSize, 1024      /* Maximum content buffer size */

/* Art mode constants */
.equ PictureWidth, 400
.equ PictureHeight, 300
.equ PictureSize, 120000       /* 400 * 300 bytes for 8bpp framebuffer */

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
.equ KEY_A, 97                 /* 'a' for Art mode */
.equ KEY_C, 99                 /* 'c' for Chat mode */
.equ KEY_D, 100                /* 'd' for Debug mode */
.equ KEY_T, 116                /* 't' for Text mode (return from art mode) */
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
    movel   #0, picture_mode_active /* Start in text mode */
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
    
    /* ENABLE CPU interrupts at a safe level - allow UART communication */
    /* Instead of completely disabling interrupts, set priority to allow UART */
    move    #0x2000, %sr         /* Enable interrupts, disable only priority 0-7 */
    
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
    /* Check if we're in chat mode */
    cmpl    #1, chat_mode_active
    beq     chat_mode_loop
    
    /* Check if we're in debug mode */
    cmpl    #1, debug_mode_active
    beq     debug_mode_loop
    
    /* Check if we're in art mode */
    cmpl    #1, picture_mode_active
    beq     art_mode_loop
    
    /* Normal text mode processing */
    jsr     process_text_mode
    bra     main_loop

chat_mode_loop:
    /* ASYNC CHAT MODE - Safe polling without blocking */
    moveb   KCTLCount, %d0
    cmpl    #0, %d0
    beq     chat_mode_no_input   /* No input, continue */
    
    /* Process keyboard input for chat mode */
    jsr     process_chat_keyboard_input
    bra     main_loop

chat_mode_no_input:
    /* Periodic background tasks - NON-BLOCKING with timeout protection */
    addil   #1, chat_poll_counter
    cmpl    #1000, chat_poll_counter  /* Every 1000 cycles (reduced frequency) */
    blt     chat_skip_poll
    
    movel   #0, chat_poll_counter
    
    /* CRITICAL: Add timeout protection to prevent infinite loops */
    movel   #0, chat_timeout_counter
    cmpl    #10000, chat_timeout_counter  /* Timeout after 10000 cycles */
    bge     chat_skip_poll              /* Skip if timeout reached */
    
    /* Poll for incoming messages (only if network enabled) */
    cmpl    #1, chat_network_disabled
    beq     skip_aether_poll
    jsr     aether_poll_safe           /* Non-blocking version */
skip_aether_poll:
    jsr     update_chat_display_if_needed
    
chat_skip_poll:
    /* Add delay to prevent tight loop */
    movel   #1000, %d0
chat_delay_loop:
    subil   #1, %d0
    bne     chat_delay_loop
    bra     main_loop

debug_mode_loop:
    /* Debug mode - check for ESC key and numbered shortcuts */
    moveb   KCTLCount, %d0
    cmpl    #0, %d0
    beq     debug_mode_no_input   /* No input, continue */
    
    /* Process keyboard input for debug mode */
    jsr     process_debug_input
    bra     main_loop

debug_mode_no_input:
    /* Add delay to prevent tight loop */
    movel   #1000, %d0
debug_delay_loop:
    subil   #1, %d0
    bne     debug_delay_loop
    bra     main_loop

art_mode_loop:
    /* Art mode - check for 't', 'j', 'k' keys */
    moveb   KCTLCount, %d0
    cmpl    #0, %d0
    beq     main_loop              /* No input, continue */
    
    /* Get the key */
    moveal  #KCTLKeys, %a0
    moveb   (%a0), %d0
    
    /* Check if it's the 't' key */
    cmpb    #KEY_T, %d0
    beq     exit_art_mode
    
    /* Check if it's the 'j' key (next image) */
    cmpb    #KEY_J, %d0
    beq     next_image
    
    /* Check if it's the 'k' key (previous image) */
    cmpb    #KEY_K, %d0
    beq     previous_image
    
    /* Check if it's the 'c' key (Chat mode) */
    cmpb    #KEY_C, %d0
    beq     process_key_chat
    
    /* Consume the key and continue */
    moveb   #1, KCTLNextReport
    bra     main_loop

next_image:
    /* Move to next image */
    jsr     switch_to_next_image
    moveb   #1, KCTLNextReport     /* Consume the 'j' key */
    bra     main_loop

previous_image:
    /* Move to previous image */
    jsr     switch_to_previous_image
    moveb   #1, KCTLNextReport     /* Consume the 'k' key */
    bra     main_loop

exit_art_mode:
    /* Return to text mode */
    jsr     enter_text_mode
    moveb   #1, KCTLNextReport     /* Consume the 't' key */
    bra     main_loop

/* Process text mode (existing main loop logic) */
process_text_mode:
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
    rts

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
    
    /* Check if we're in chat mode */
    cmpl    #1, chat_mode_active
    beq     draw_chat_status_line
    
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
    bra     draw_status_done

draw_chat_status_line:
    /* Calculate position for status line (line 19) */
    movel   #19, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw left border and clear entire line */
    moveb   #'|', (%a2)+
    moveb   #' ', (%a2)+
    
    /* Clear the entire status line first */
    movel   #2, %d1            /* Start after left border + space */
clear_chat_status_loop:
    cmpl    #ScreenWidth - 1, %d1  /* Stop before right border */
    bge     clear_chat_status_end
    moveb   #' ', (%a2)+
    addl    #1, %d1
    bra     clear_chat_status_loop
clear_chat_status_end:
    
    /* Reset to start position after border */
    moveal  %a0, %a2
    addl    #2, %a2            /* Skip | and space */
    
    /* Show network status */
    lea     net_status_msg, %a5
    jsr     print_string_no_advance
    
    /* Show connection status */
    moveb   network_status, %d0
    cmpi.b  #2, %d0  /* NET_CONNECTED */
    beq     show_chat_connected
    cmpi.b  #1, %d0  /* NET_CONNECTING */
    beq     show_chat_connecting
    
    /* Disconnected */
    lea     status_disconnected_msg, %a5
    jsr     print_string_no_advance
    bra     chat_status_continue
    
show_chat_connecting:
    lea     status_connecting_msg, %a5
    jsr     print_string_no_advance
    bra     chat_status_continue
    
show_chat_connected:
    lea     status_connected_msg, %a5
    jsr     print_string_no_advance
    
    /* Add neighbor count if connected */
    moveb   #' ', (%a2)+
    lea     neighbors_short_msg, %a5
    jsr     print_string_no_advance
    movew   neighbor_count, %d0
    jsr     display_decimal_number_short
    
chat_status_continue:
    /* Close status line with right border */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + ScreenWidth - 1, %a2
    moveb   #'|', (%a2)

draw_status_done:
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
    
    /* Check if we're in chat mode */
    cmpl    #1, chat_mode_active
    beq     draw_chat_footer
    
    /* CRITICAL FIX: Save A2 before calling print_string_no_advance */
    /* because print_string_no_advance restores ALL registers */
    movel   %a2, -(%sp)         /* Save current screen position */
    lea     footer_commands, %a5
    jsr     print_string_no_advance
    movel   (%sp)+, %a2         /* Restore screen position */
    bra     finish_footer_draw

draw_chat_footer:
    /* Draw chat input prompt and current input */
    moveb   #'>', (%a2)+
    moveb   #' ', (%a2)+
    
    /* Check if there's any input to display */
    cmpl    #0, chat_input_length
    bne     show_live_input
    
    /* Show static prompt when no input - check network status */
    movel   %a2, -(%sp)         /* Save current screen position */
    cmpl    #1, chat_network_disabled
    beq     use_bare_bones_footer
    lea     chat_footer_prompt, %a5
    bra     print_footer_prompt
use_bare_bones_footer:
    lea     chat_bare_bones_footer_prompt, %a5
print_footer_prompt:
    jsr     print_string_no_advance
    movel   (%sp)+, %a2         /* Restore screen position */
    bra     finish_footer_draw
    
show_live_input:
    /* Display current chat input */
    jsr     display_chat_input_line
    bra     finish_footer_draw

finish_footer_draw:
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
    /* CRITICAL: Save all registers to prevent corruption */
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Add debug trace */
    movel   #'P', %d0
    jsr     add_debug_trace
    
    /* Check if there are any keys in the report */
    moveb   KCTLReportSize, %d5
    beq     finish_key_input     /* No keys in report, finish */
    
    /* Read the first key from the report */
    moveal  #KCTLKeys, %a0
    moveb   (%a0), %d0
    
    /* Check if we're in chat mode - handle chat input differently */
    cmpl    #1, chat_mode_active
    beq     process_chat_keyboard_input
    
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
    cmpb    #KEY_A, %d0        /* 'a' for Art mode */
    beq     process_key_picture
    cmpb    #KEY_C, %d0        /* 'c' for Chat mode */
    beq     process_key_chat
    cmpb    #KEY_D, %d0        /* 'd' for Debug mode */
    beq     process_key_debug
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
    cmpb    #KEY_6, %d0
    beq     jump_section_6
    cmpb    #KEY_7, %d0
    beq     jump_section_7
    cmpb    #KEY_8, %d0
    beq     jump_section_8
    cmpb    #KEY_9, %d0
    beq     jump_section_9
    cmpb    #KEY_0, %d0
    beq     jump_top
    
    bra     finish_key_input

/* Process keyboard input in chat mode - PHASE 1: SIMPLE BUFFER */
process_chat_keyboard_input:
    /* Use same register save pattern as debug mode - KEEP THIS WORKING PATTERN */
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    movel   %a0, -(%sp)
    
    /* Re-read the key after register save */
    moveal  #KCTLKeys, %a0
    moveb   (%a0), %d0
    
    /* Check for ESC key to exit chat mode */
    cmpb    #KEY_ESC, %d0
    beq     exit_chat_mode_irc
    
    /* Check for backspace key */
    cmpb    #KEY_BACKSPACE, %d0
    beq     handle_simple_backspace
    
    /* Check for Enter key */
    cmpb    #KEY_ENTER, %d0
    beq     handle_simple_enter
    
    /* Check for arrow keys - NETWORK READY NAVIGATION */
    cmpb    #KEY_UP_ARROW, %d0
    beq     chat_up_arrow
    cmpb    #KEY_DOWN_ARROW, %d0
    beq     chat_down_arrow
    
    /* Handle printable characters only */
    cmpl    #32, %d0           /* Space */
    blt     finish_chat_key_input   /* Ignore non-printable */
    cmpl    #126, %d0          /* Tilde */
    bgt     finish_chat_key_input   /* Ignore non-printable */
    
    /* Add character to simple buffer with bounds check */
    jsr     simple_add_char
    bra     finish_chat_key_input

handle_simple_backspace:
    /* Remove last character from simple buffer */
    jsr     simple_remove_char
    bra     finish_chat_key_input

chat_up_arrow:
    /* Navigate through input history - NETWORK READY */
    jsr     navigate_input_history_up
    bra     finish_chat_key_input

chat_down_arrow:
    /* Navigate through input history - NETWORK READY */
    jsr     navigate_input_history_down
    bra     finish_chat_key_input

handle_simple_enter:
    /* Check if we have any input */
    movel   chat_input_length, %d1
    cmpl    #0, %d1
    beq     finish_chat_key_input    /* No input to send */
    
    /* NETWORK READY: Add to input history first */
    jsr     add_to_input_history
    
    /* Send message (local for now, network-ready) */
    jsr     enhanced_send_message
    
    /* Clear input buffer and reset navigation */
    clrl    chat_input_length  
    clrl    input_history_index
    bra     finish_chat_key_input

exit_chat_mode_irc:
    /* Exit chat mode and return to main mode */
    movel   #0, chat_mode_active
    jsr     set_display_update_flag
    bra     finish_chat_key_input

/* KEEP WORKING PATTERN: Chat mode register cleanup - same as debug mode */
finish_chat_key_input:
    /* Update the footer display */
    jsr     simple_update_footer
    
    /* Consume the key report */
    moveb   #1, KCTLNextReport
    
    /* Restore registers - same pattern as debug mode */
    movel   (%sp)+, %a0
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

jump_top:
    movel   #0, scroll_offset
    jsr     set_display_update_flag
    bra     finish_key_input

/* Section-to-line mapping follows: */
jump_section_1:
    movel   #8, scroll_offset    /* Line 8 = Section 1 */
    jsr     set_display_update_flag
    bra     finish_key_input

jump_section_2:
    movel   #17, scroll_offset   /* Line 17 = Section 2 */
    jsr     set_display_update_flag
    bra     finish_key_input

jump_section_3:
    movel   #35, scroll_offset   /* Line 35 = Section 3 */
    jsr     set_display_update_flag
    bra     finish_key_input

jump_section_4:
    movel   #52, scroll_offset   /* Line 52 = Section 4 */
    jsr     set_display_update_flag
    bra     finish_key_input

jump_section_5:
    movel   #64, scroll_offset   /* Line 64 = Section 5 */
    jsr     set_display_update_flag
    bra     finish_key_input

jump_section_6:
jump_section_7:
jump_section_8:
jump_section_9:
    movel   #79, scroll_offset   /* Line 79 = Section last */
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

process_key_picture:
    jsr     enter_picture_mode
    bra     finish_key_input

process_key_chat:
    jsr     process_chat_mode
    bra     finish_key_input

process_key_debug:
    jsr     process_debug_mode
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
    
    /* CRITICAL: Restore all registers saved by process_keyboard_input */
    movem.l (%sp)+, %d0-%d7/%a0-%a6
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
    /* CRITICAL: This function is called from everywhere, must be reentrant */
    /* No registers modified, but add protection for future safety */
    movem.l %d0-%d1/%a0, -(%sp)
    movel   #1, display_needs_update
    movem.l (%sp)+, %d0-%d1/%a0
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
    /* CRITICAL: Save ALL registers for reentrancy */
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    movel   scroll_offset, %d0
    movel   content_total_lines, %d1
    subl    #15, %d1                /* Content area height */
    cmpl    %d1, %d0
    bge     scroll_down_done
    addl    #1, %d0
    movel   %d0, scroll_offset
    jsr     set_display_update_flag
scroll_down_done:
    /* CRITICAL: Restore ALL registers */
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Scroll up function */
key_scroll_up:
    /* CRITICAL: Save ALL registers for reentrancy */
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    movel   scroll_offset, %d0
    cmpl    #0, %d0
    ble     scroll_up_done
    subl    #1, %d0
    movel   %d0, scroll_offset
    jsr     set_display_update_flag
scroll_up_done:
    /* CRITICAL: Restore ALL registers */
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Initialize scrolling system */
init_scroll_system:
    /* CRITICAL: Save ALL registers for reentrancy */
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
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
    /* CRITICAL: Restore ALL registers */
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Display the current menu or content */
display_current_menu:
    /* CRITICAL: Save ALL registers for reentrancy */
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
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
    /* CRITICAL: Save ALL registers for reentrancy */
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Add debug trace */
    movel   #'D', %d0
    jsr     add_debug_trace
    
    /* Check if we're in chat mode */
    cmpl    #1, chat_mode_active
    beq     draw_chat_content
    
    /* Display scrolling content */
    jsr     draw_scrolling_content
    /* CRITICAL: Restore ALL registers */
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

draw_chat_content:
    /* Display IRC-style chat history */
    jsr     draw_chat_history_irc
    /* CRITICAL: Restore ALL registers */
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Draw scrolling content */
draw_scrolling_content:
    /* CRITICAL: Save ALL registers for reentrancy */
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
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
    /* CRITICAL: Restore ALL registers */
    movem.l (%sp)+, %d0-%d7/%a0-%a6
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

/* Art Mode Functions */

/* Enter art mode */
enter_picture_mode:
    /* Save registers */
    movel   %d0, -(%sp)
    movel   %a0, -(%sp)
    
    /* Disable TDA by setting mode to NONE (0) */
    moveal  #TDABase, %a0
    moveb   #GraphicsMode, (%a0)
    
    /* Clear the entire framebuffer to white */
    jsr     clear_full_framebuffer
    
    /* Draw the complete picture */
    jsr     draw_picture
    
    /* Set art mode flag */
    movel   #1, picture_mode_active
    
    /* Restore registers */
    movel   (%sp)+, %a0
    movel   (%sp)+, %d0
    rts

/* Clear entire framebuffer to white */
clear_full_framebuffer:
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %a0, -(%sp)
    
    moveal  #ScrnBase, %a0
    movel   #0, %d1
    
clear_full_loop:
    cmpl    #PictureSize, %d1      /* Clear all pixels */
    bge     clear_full_done
    moveb   #0xFF, (%a0)+          /* White pixel */
    addl    #1, %d1
    bra     clear_full_loop
    
clear_full_done:
    movel   (%sp)+, %a0
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Enter text mode */
enter_text_mode:
    /* Save registers */
    movel   %d0, -(%sp)
    movel   %a0, -(%sp)
    
    /* Re-enable TDA */
    moveal  #TDABase, %a0
    moveb   #TextMode, (%a0)
    
    /* Clear art mode flag */
    movel   #0, picture_mode_active
    
    /* Force display update */
    movel   #1, display_needs_update
    
    /* Restore registers */
    movel   (%sp)+, %a0
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
    .string "JonSharp.net Cyberterminal (limited) Access"
version_text:
    .string "[sampler ROM v1.3-2025]"
.equ version_text_length, 23

footer_commands:
    .string "Keys: j=down, k=up, 0=top, 1-9=sections, a=art mode, c=chat mode, t=text mode"
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
    .dc.l    0
status_update_counter:
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

/* Art mode variables */
picture_mode_active:
    .dc.l    0               /* Flag for art mode (0=text, 1=art) */

/* Chat mode variables */
chat_mode_active:
    .dc.l    0               /* Flag for chat mode (0=off, 1=active) */

/* Network disable flag - set to 1 to disable all UART/aether functions */
chat_network_disabled:
    .dc.l    1               /* 1=disabled (bare-bones), 0=enabled (full network) */

/* Debug mode variables */
debug_mode_active:
    .dc.l    0               /* Flag for debug mode (0=off, 1=active) */
chat_network_status:
    .dc.l    0               /* Network status (0=disconnected, 1=connecting, 2=connected) */
chat_input_buffer:
    .ds.b    80              /* Buffer for typing chat messages */
chat_input_length:
    .dc.l    0               /* Current length of input buffer */

/* Enhanced message system - network ready */
chat_history_lines:
    .dc.l    0               /* Number of lines in chat history */
chat_history_scroll:
    .dc.l    0               /* Current scroll position (0 = bottom) */
chat_history_buffer:
.ds.b    1440            /* Chat history buffer (18 lines x 80 chars) */
temp_chat_line:
.ds.b    81             /* Temporary buffer for building chat lines */

/* Message metadata for network integration */
current_room:
.ds.b    32             /* Current chat room name */
message_counter:
    .dc.l    0               /* Local message counter */
last_message_time:
    .dc.l    0               /* Timestamp of last message */

/* Input history for arrow key navigation */
input_history_buffer:
.ds.b    800            /* 10 previous messages x 80 chars */
input_history_count:
    .dc.l    0               /* Number of stored input lines */
input_history_index:
    .dc.l    0               /* Current position in input history */

/* Activity indicator for chat mode */
activity_indicator:
    .dc.b    '*'            /* Activity indicator character */
    .ds.b    1              /* Padding for alignment */

/* Async chat variables */
chat_poll_counter:
    .dc.l    0              /* Counter for async polling */
chat_display_dirty:
    .dc.l    0              /* Flag to indicate display needs update */
chat_timeout_counter:
    .dc.l    0              /* Timeout counter to prevent infinite loops */

/* IRC-style chat data added to existing chat variables */

/* Multi-image support */
.equ NumImages, 2            /* Number of images available */
current_image_index:
    .dc.l    0               /* Current image index (0-based) */

/* Image data table - pointers to each image */
.align 4
image_data_table:
    .dc.l    picture_data2   /* Image 0: first image */
    .dc.l    picture_data    /* Image 1: second image */

/* Include the bit-packed image data */
.include "picture_data.S"
.include "picture_data2.S"

/* Draw picture from bit-packed data */
draw_picture:
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
    
    /* Get current image data pointer from table */
    movel   current_image_index, %d0
    lsll    #2, %d0                    /* Multiply by 4 (pointer size) */
    lea     image_data_table, %a1
    movel   (%a1,%d0), %a1             /* Load image data pointer */
    
    /* Initialize destination pointer */
    moveal  #ScrnBase, %a0             /* Destination: framebuffer */
    
    /* Process all 15,000 bytes of bit-packed data */
    /* Each byte contains 8 pixels, total = 15,000 * 8 = 120,000 pixels */
    movel   #15000, %d0            /* Total bytes to process */
    
byte_loop:
    /* Check if we're done */
    cmpl    #0, %d0
    beq     picture_complete
    
    /* Get next byte of bit-packed data */
    moveb   (%a1)+, %d7
    
    /* Process all 8 bits in this byte (MSB first) */
    movel   #8, %d6                /* Bit counter */
    
bit_loop:
    /* Check if we're done with this byte */
    cmpl    #0, %d6
    beq     next_byte
    
    /* Extract the most significant bit */
    movel   %d7, %d3
    lsrl    #7, %d3                /* Get MSB */
    andl    #1, %d3                /* Mask to single bit */
    
    /* Convert bit to pixel value: 1=white (0xFF), 0=black (0x00) */
    cmpl    #1, %d3
    beq     set_white_pixel
    moveb   #0x00, (%a0)+          /* Black pixel for bit 0 */
    bra     next_bit
    
set_white_pixel:
    moveb   #0xFF, (%a0)+          /* White pixel for bit 1 */
    
next_bit:
    /* Shift byte left for next bit */
    lsll    #1, %d7
    
    /* Decrement bit counter */
    subl    #1, %d6
    bra     bit_loop
    
next_byte:
    /* Decrement byte counter */
    subl    #1, %d0
    bra     byte_loop
    
picture_complete:
    /* Restore registers */
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

/* Switch to next image */
switch_to_next_image:
    movel   %d0, -(%sp)
    
    /* Increment current image index */
    movel   current_image_index, %d0
    addl    #1, %d0
    
    /* Check if we need to wrap around */
    cmpl    #NumImages, %d0
    blt     next_image_no_wrap
    movel   #0, %d0                /* Wrap to first image */
    
next_image_no_wrap:
    movel   %d0, current_image_index
    
    /* Clear screen and redraw new image */
    jsr     clear_full_framebuffer
    jsr     draw_picture
    
    movel   (%sp)+, %d0
    rts

/* Switch to previous image */
switch_to_previous_image:
    movel   %d0, -(%sp)
    
    /* Decrement current image index */
    movel   current_image_index, %d0
    subl    #1, %d0
    
    /* Check if we need to wrap around */
    cmpl    #0, %d0
    bge     prev_image_no_wrap
    movel   #NumImages-1, %d0      /* Wrap to last image */
    
prev_image_no_wrap:
    movel   %d0, current_image_index
    
    /* Clear screen and redraw new image */
    jsr     clear_full_framebuffer
    jsr     draw_picture
    
    movel   (%sp)+, %d0
    rts

/* ======================================================================
 * CHAT MODE FUNCTIONS
 * ====================================================================== */

/* Process chat mode activation */
process_chat_mode:
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    movel   %a0, -(%sp)
    
    /* Check if already in chat mode */
    cmpl    #1, chat_mode_active
    beq     toggle_chat_off
    
    /* Enter chat mode - ASYNC SAFE VERSION */
    movel   #1, chat_mode_active
    
    /* Initialize chat system */
    jsr     clear_text_screen
    jsr     init_chat_history
    jsr     display_chat_interface
    
    /* Initialize async polling counter */
    movel   #0, chat_poll_counter
    movel   #0, chat_display_dirty
    
    bra     chat_mode_done
    
toggle_chat_off:
    /* Exit chat mode */
    movel   #0, chat_mode_active
    jsr     set_display_update_flag  /* Return to normal content display */
    
chat_mode_done:
    movel   (%sp)+, %a0
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Initialize aether modem if needed */
initialize_aether_if_needed:
    movel   %d0, -(%sp)
    
    /* Check if network functionality is disabled */
    cmpl    #1, chat_network_disabled
    beq     aether_init_disabled
    
    /* Check if already connected */
    cmpl    #2, chat_network_status  /* 2 = connected */
    beq     aether_init_done
    
    /* Set status to connecting */
    movel   #1, chat_network_status
    
    /* Initialize and connect to aether network with new protocol */
    jsr     aether_init
    cmpl    #0, %d0  /* AT_OK */
    bne     aether_init_failed
    
    jsr     aether_connect  /* Uses new AT+NETALIAS → AT+INIT → AT+NETJOIN sequence */
    cmpl    #0, %d0  /* AT_OK */
    bne     aether_init_failed
    
    /* Join default chat room */
    lea     default_chat_room_name, %a0
    jsr     aether_chat_join
    
    /* Set up chat message handler */
    movea.l #handle_incoming_chat_simple, %a0
    jsr     aether_set_chat_handler
    
    /* Set status to connected */
    movel   #2, chat_network_status
    bra     aether_init_done
    
aether_init_failed:
    /* Allow debugging even if init failed */
    movel   #2, chat_network_status  /* Allow debugging */
    bra     aether_init_done
    
aether_init_disabled:
    /* Network disabled - set status to disconnected */
    movel   #0, chat_network_status
    
aether_init_done:
    movel   (%sp)+, %d0
    rts

/* Display chat interface */
display_chat_interface:
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %a0, -(%sp)
    movel   %a1, -(%sp)
    
    /* Draw header using existing function - changes title to "Chat Mode" */
    jsr     draw_chat_header
    
    /* Display chat history in content area (Lines 4-17) */  
    jsr     display_chat_history
    
    /* Draw status line (line 19) and footer (line 21) using standard system */
    jsr     draw_status
    jsr     draw_footer
    
    movel   (%sp)+, %a1
    movel   (%sp)+, %a0
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* MINIMAL chat interface - matches debug mode simplicity */
display_chat_interface_minimal:
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %a0, -(%sp)
    movel   %a1, -(%sp)
    
    /* Display minimal header */
    moveal  #TDABase + 1, %a1
    lea     chat_minimal_header_msg, %a0
    jsr     copy_string_to_screen
    
    /* Display available commands */
    moveal  #TDABase + 1 + (2 * ScreenWidth), %a1
    lea     chat_minimal_commands_msg, %a0
    jsr     copy_string_to_screen
    
    /* Display prompt at bottom */
    moveal  #TDABase + 1 + (22 * ScreenWidth), %a1
    lea     chat_minimal_prompt_msg, %a0
    jsr     copy_string_to_screen
    
    movel   (%sp)+, %a1
    movel   (%sp)+, %a0
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Display chat history - SIMPLIFIED VERSION */
display_chat_history:
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    movel   %a0, -(%sp)
    movel   %a1, -(%sp)
    
    /* Get number of lines to display */
    movel   chat_history_lines, %d0
    cmpl    #14, %d0
    ble     history_lines_ok
    movel   #14, %d0  /* Limit to 14 lines (avoid overlap with input area) */
    
history_lines_ok:
    cmpl    #0, %d0
    beq     history_done
    
    /* D0 = lines to display */
    /* Start with first line in buffer */
    lea     chat_history_buffer, %a0
    /* Start displaying at screen line 4 */
    moveal  #TDABase + 1 + (4 * ScreenWidth), %a1
    
simple_history_loop:
    /* Copy exactly 80 characters from buffer line to screen line */
    movel   #80, %d1
copy_buffer_line:
    moveb   (%a0)+, (%a1)+
    subql   #1, %d1
    bne     copy_buffer_line
    
    /* Move to next screen line - just add ScreenWidth */
    movel   %a1, %d2
    subl    #80, %d2                  /* Back to start of current line */
    addl    #ScreenWidth, %d2         /* Add full line width */
    moveal  %d2, %a1                  /* Next screen line */
    
    /* Next history line */
    subql   #1, %d0
    bne     simple_history_loop
    
history_done:
    movel   (%sp)+, %a1
    movel   (%sp)+, %a0
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Clear text screen (for chat mode) */
clear_text_screen:
    movel   %d0, -(%sp)
    movel   %a0, -(%sp)
    
    moveal  #TDABase + 1, %a0
    movel   #(ScreenWidth * ScreenHeight)-1, %d0
clear_text_loop:
    moveb   #' ', (%a0)+
    dbra    %d0, clear_text_loop
    
    movel   (%sp)+, %a0
    movel   (%sp)+, %d0
    rts

/* Initialize chat history buffer */
init_chat_history:
    movel   %d0, -(%sp)
    movel   %a0, -(%sp)
    
    /* Clear the chat history buffer */
    lea     chat_history_buffer, %a0
    movel   #1440, %d0              /* Buffer size */
clear_history_loop:
    moveb   #' ', (%a0)+
    subql   #1, %d0
    bne     clear_history_loop
    
    /* Initialize history line count */
    movel   #0, chat_history_lines
    
    movel   (%sp)+, %a0
    movel   (%sp)+, %d0
    rts

/* Draw chat mode header - reuses existing border layout */
draw_chat_header:
    movel   %d0, -(%sp)
    movel   %a0, -(%sp)
    movel   %a2, -(%sp)
    movel   %a5, -(%sp)
    
    /* Call existing border drawing routine */
    jsr     draw_borders
    
    /* Position at header content area (line 1) */
    moveal  #TDABase + 1 + ScreenWidth, %a2
    
    /* Draw left border and space */
    moveb   #'|', (%a2)+
    moveb   #' ', (%a2)+
    
    /* Draw chat mode title - check if network is disabled */
    cmpl    #1, chat_network_disabled
    beq     use_bare_bones_header
    lea     chat_header_msg, %a5
    bra     print_header_title
use_bare_bones_header:
    lea     chat_bare_bones_header_msg, %a5
print_header_title:
    jsr     print_string_no_advance
    
    /* Position cursor for connection status (right side) */
    moveal  #TDABase + 1 + ScreenWidth + 55, %a2
    
    /* Show connection status - check if network is disabled first */
    cmpl    #1, chat_network_disabled
    beq     show_header_disabled
    
    cmpl    #2, chat_network_status  /* 2 = connected */
    beq     show_header_connected
    cmpl    #1, chat_network_status  /* 1 = connecting */
    beq     show_header_connecting
    
    /* Disconnected */
    lea     status_disconnected_msg, %a5
    jsr     print_string_no_advance
    bra     chat_header_done

show_header_disabled:
    lea     status_disabled_msg, %a5
    jsr     print_string_no_advance
    bra     chat_header_done
    
show_header_connecting:
    lea     status_connecting_msg, %a5
    jsr     print_string_no_advance
    bra     chat_header_done
    
show_header_connected:
    lea     status_connected_msg, %a5
    jsr     print_string_no_advance
    
chat_header_done:
    /* Close header line with right border */
    moveal  #TDABase + 1 + ScreenWidth + ScreenWidth - 1, %a2
    moveb   #'|', (%a2)
    
    movel   (%sp)+, %a5
    movel   (%sp)+, %a2
    movel   (%sp)+, %a0
    movel   (%sp)+, %d0
    rts

/* Copy string to screen helper with bounds checking */
copy_string_to_screen:
    /* CRITICAL: Save ALL registers for reentrancy */
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* A0 = source string, A1 = destination screen location */
    /* Calculate maximum characters that fit on current line */
    movel   %a1, %d1
    subl    #TDABase + 1, %d1        /* Get offset from screen start */
    divu    #ScreenWidth, %d1        /* Get current line number */
    swap    %d1                       /* Get remainder = column position */
    moveq   #ScreenWidth, %d0
    subl    %d1, %d0                  /* D0 = chars remaining on line */
    subq    #1, %d0                   /* Leave space for line end */
    
    /* Check screen bounds */
    cmpl    #TDABase + 1 + (ScreenWidth * ScreenHeight), %a1
    bge     copy_string_done_bounds   /* Beyond screen end */
    
copy_string_loop:
    /* Check remaining space on line */
    tst.l   %d0
    beq     copy_string_done_bounds   /* No more space on line */
    
    /* Copy character if not null */
    moveb   (%a0)+, %d1
    beq     copy_string_done_bounds
    moveb   %d1, (%a1)+
    subq    #1, %d0
    bra     copy_string_loop
    
copy_string_done_bounds:
    /* CRITICAL: Restore ALL registers */
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts



/* Display simple network status (2 lines only for chat mode) */
display_simple_network_status:
    movel   %d0, -(%sp)
    movel   %a0, -(%sp)
    movel   %a1, -(%sp)
    
    /* Line 2: Connection Status */
    moveal  #TDABase + 1 + (2 * ScreenWidth), %a1
    cmpl    #2, chat_network_status  /* 2 = connected */
    beq     show_simple_connected
    cmpl    #1, chat_network_status  /* 1 = connecting */
    beq     show_simple_connecting
    
    /* Disconnected */
    lea     status_disconnected_msg, %a0
    jsr     copy_string_to_screen
    bra     simple_status_done
    
show_simple_connecting:
    lea     status_connecting_msg, %a0
    jsr     copy_string_to_screen
    bra     simple_status_done
    
show_simple_connected:
    lea     status_connected_msg, %a0
    jsr     copy_string_to_screen
    
simple_status_done:
    movel   (%sp)+, %a1
    movel   (%sp)+, %a0
    movel   (%sp)+, %d0
    rts

/* Display comprehensive network status (AppleTalk Toolbox style) */
display_comprehensive_network_status:
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    movel   %a0, -(%sp)
    movel   %a1, -(%sp)
    
    /* Update network info from aether modem */
    jsr     update_network_status_data
    
    /* Line 2: Network Status */
    moveal  #TDABase + 1 + (2 * ScreenWidth), %a1
    lea     net_status_header, %a0
    jsr     copy_string_to_screen
    
    /* Show connection status - check if network is disabled */
    cmpl    #1, chat_network_disabled
    beq     show_status_disabled
    
    jsr     aether_get_status
    cmpl    #2, %d0  /* NET_CONNECTED */
    beq     show_connected_status
    cmpl    #1, %d0  /* NET_CONNECTING */
    beq     show_connecting_status
    
show_status_disabled:
    /* Network disabled */
    lea     status_disabled_msg, %a0
    jsr     copy_string_to_screen
    bra     status_line_done
    
    /* Disconnected */
    lea     status_disconnected_msg, %a0
    jsr     copy_string_to_screen
    bra     status_line_done
    
show_connecting_status:
    lea     status_connecting_msg, %a0
    jsr     copy_string_to_screen
    bra     status_line_done
    
show_connected_status:
    lea     status_connected_msg, %a0
    jsr     copy_string_to_screen
    
    /* Add neighbor count */
    lea     neighbor_count_prefix, %a0
    jsr     copy_string_to_screen
    movew   neighbor_count, %d0
    jsr     display_decimal_number
    
status_line_done:
    /* Line 3: Network ID and Node Info */
    moveal  #TDABase + 1 + (3 * ScreenWidth), %a1
    lea     net_id_prefix, %a0
    jsr     copy_string_to_screen
    lea     network_id, %a0
    jsr     copy_string_to_screen
    
    /* Add node ID */
    lea     node_id_prefix, %a0
    jsr     copy_string_to_screen
    lea     node_id, %a0
    jsr     copy_string_to_screen
    
    /* Line 4: RF Parameters */
    moveal  #TDABase + 1 + (4 * ScreenWidth), %a1
    lea     rf_params_prefix, %a0
    jsr     copy_string_to_screen
    
    /* Frequency */
    movel   frequency, %d0
    jsr     display_frequency
    
    /* Spreading Factor */
    lea     sf_prefix, %a0
    jsr     copy_string_to_screen
    movew   spreading_factor, %d0
    jsr     display_decimal_number
    
    /* Bandwidth */
    lea     bw_prefix, %a0
    jsr     copy_string_to_screen
    movew   bandwidth, %d0
    jsr     display_decimal_number
    lea     khz_suffix, %a0
    jsr     copy_string_to_screen
    
    /* Line 5: Signal Info */
    moveal  #TDABase + 1 + (5 * ScreenWidth), %a1
    lea     signal_prefix, %a0
    jsr     copy_string_to_screen
    
    /* RSSI */
    lea     rssi_prefix, %a0
    jsr     copy_string_to_screen
    movew   last_rssi, %d0
    jsr     display_signed_number
    lea     dbm_suffix, %a0
    jsr     copy_string_to_screen
    
    /* SNR */
    lea     snr_prefix, %a0
    jsr     copy_string_to_screen
    movew   last_snr, %d0
    jsr     display_signed_number
    
    /* TX Power */
    lea     pwr_prefix, %a0
    jsr     copy_string_to_screen
    movew   tx_power, %d0
    jsr     display_signed_number
    lea     dbm_suffix, %a0
    jsr     copy_string_to_screen
    
    /* Line 6: Neighbors (if any) */
    movew   neighbor_count, %d0
    tst.w   %d0
    beq     no_neighbors_to_show
    
    moveal  #TDABase + 1 + (6 * ScreenWidth), %a1
    lea     neighbors_header, %a0
    jsr     copy_string_to_screen
    
    /* Show first few neighbors */
    jsr     display_neighbor_list
    bra     neighbors_done
    
no_neighbors_to_show:
    moveal  #TDABase + 1 + (6 * ScreenWidth), %a1
    lea     no_neighbors_msg, %a0
    jsr     copy_string_to_screen
    
neighbors_done:
    movel   (%sp)+, %a1
    movel   (%sp)+, %a0
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Update network status data from aether modem */
update_network_status_data:
    movel   %d0, -(%sp)
    
    /* Check if network functionality is disabled */
    cmpl    #1, chat_network_disabled
    beq     update_network_skip
    
    /* Get current network status */
    jsr     aether_get_network_info
    
    /* Get neighbor list */
    jsr     aether_get_neighbors
    
update_network_skip:
    movel   (%sp)+, %d0
    rts

/* Display a decimal number at current screen position */
display_decimal_number:
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    movel   %a0, -(%sp)
    
    /* Convert D0 to decimal string and display */
    tst.w   %d0
    bne     convert_nonzero_display
    moveb   #'0', (%a1)+
    bra     display_decimal_done
    
convert_nonzero_display:
    /* Simple conversion for small numbers */
    move.w  %d0, %d1
    moveq   #0, %d2
    
    /* Count digits */
count_digits:
    divu    #10, %d1
    addq    #1, %d2
    move.w  %d1, %d1
    tst.w   %d1
    bne     count_digits
    
    /* Now convert and display */
    move.w  %d0, %d1
    jsr     convert_to_ascii
    
display_decimal_done:
    movel   (%sp)+, %a0
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    rts

/* Display a signed number */
display_signed_number:
    tst.w   %d0
    bpl     display_positive
    moveb   #'-', (%a1)+
    neg.w   %d0
display_positive:
    jsr     display_decimal_number
    rts

/* Short display functions for footer */
display_frequency_short:
    /* Display frequency in MHz format (e.g., "915MHz") */
    move.w  %d0, %d1
    divu    #1000, %d1  /* Convert Hz to MHz */
    move.w  %d1, %d0
    jsr     display_decimal_number_short
    lea     mhz_suffix, %a5
    jsr     print_string_no_advance
    rts

display_decimal_number_short:
    /* Short decimal display for footer - 1-2 digits max */
    tst.w   %d0
    bne     convert_short_nonzero
    moveb   #'0', (%a2)+
    rts
convert_short_nonzero:
    cmpi.w  #10, %d0
    blt     single_digit_short
    /* Two digits */
    move.w  %d0, %d1
    divu    #10, %d1
    move.w  %d1, %d0
    addib   #'0', %d0
    moveb   %d0, (%a2)+
    swap    %d1
    move.w  %d1, %d0
    addib   #'0', %d0
    moveb   %d0, (%a2)+
    rts
single_digit_short:
    addib   #'0', %d0
    moveb   %d0, (%a2)+
    rts

display_signed_number_short:
    /* Short signed number for footer */
    tst.w   %d0
    bpl     display_positive_short
    moveb   #'-', (%a2)+
    neg.w   %d0
display_positive_short:
    jsr     display_decimal_number_short
    rts

/* Convert number to ASCII and display */
convert_to_ascii:
    /* Simple implementation for numbers < 10000 */
    cmpi.w  #1000, %d1
    blt     check_hundreds
    divu    #1000, %d1
    move.w  %d1, %d0
    addi.b  #'0', %d0
    moveb   %d0, (%a1)+
    swap    %d1
    
check_hundreds:
    cmpi.w  #100, %d1
    blt     check_tens
    divu    #100, %d1
    move.w  %d1, %d0
    addi.b  #'0', %d0
    moveb   %d0, (%a1)+
    swap    %d1
    
check_tens:
    cmpi.w  #10, %d1
    blt     show_units
    divu    #10, %d1
    move.w  %d1, %d0
    addi.b  #'0', %d0
    moveb   %d0, (%a1)+
    swap    %d1
    
show_units:
    move.w  %d1, %d0
    addi.b  #'0', %d0
    moveb   %d0, (%a1)+
    rts

/* Display frequency in MHz */
display_frequency:
    movel   %d1, -(%sp)
    
    /* Convert Hz to MHz (divide by 1,000,000) */
    divu    #1000, %d0  /* First divide by 1000 */
    move.w  %d0, %d1
    divu    #1000, %d1  /* Then by 1000 again */
    move.w  %d1, %d0
    jsr     display_decimal_number
    lea     mhz_suffix, %a0
    jsr     copy_string_to_screen
    
    movel   (%sp)+, %d1
    rts

/* Display neighbor list */
display_neighbor_list:
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %a0, -(%sp)
    
    /* Show up to 3 neighbors on this line */
    movew   neighbor_count, %d0
    cmpi.w  #3, %d0
    ble     show_all_neighbors
    moveq   #3, %d0
    
show_all_neighbors:
    moveq   #0, %d1
    lea     neighbor_ids, %a0
    
show_neighbor_loop:
    cmp.w   %d0, %d1
    bge     neighbors_list_done
    
    /* Show first 8 chars of neighbor ID */
    moveq   #8, %d2
show_neighbor_name:
    moveb   (%a0)+, (%a1)+
    dbra    %d2, show_neighbor_name
    
    /* Skip to next neighbor (32 bytes each) */
    adda.l  #24, %a0  /* Skip remaining 24 bytes */
    
    /* Add separator if not last */
    addq    #1, %d1
    cmp.w   %d0, %d1
    bge     neighbors_list_done
    moveb   #' ', (%a1)+
    
    bra     show_neighbor_loop
    
neighbors_list_done:
    movel   (%sp)+, %a0
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts



/* Update chat input display */
update_chat_input_display:
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %a0, -(%sp)
    movel   %a1, -(%sp)
    
    /* Clear input line with proper bounds checking */
    moveal  #TDABase + 1 + (22 * ScreenWidth), %a1
    movel   #0, %d1
clear_input_line:
    cmpl    #ScreenWidth-1, %d1
    bge     display_prompt
    
    /* Check bounds before writing */
    cmpl    #TDABase + 1 + (23 * ScreenWidth), %a1
    bge     display_prompt  /* Past end of line 22, stop */
    
    moveb   #' ', (%a1)+
    addl    #1, %d1
    bra     clear_input_line
    
display_prompt:
    /* Redisplay prompt */
    moveal  #TDABase + 1 + (22 * ScreenWidth), %a1
    movea.l #chat_input_prompt, %a0
    jsr     copy_string_to_screen
    
    /* Display current input with bounds checking */
    movea.l #chat_input_buffer, %a0
    movel   chat_input_length, %d1
    cmpl    #0, %d1
    beq     input_display_done
    
    /* Calculate remaining space on line 22 */
    movel   #TDABase + 1 + (23 * ScreenWidth), %d0  /* End of line 22 */
    subl    %a1, %d0                                 /* Remaining space */
    cmpl    %d0, %d1                                 /* Compare with input length */
    ble     copy_input_chars                         /* Input fits */
    movel   %d0, %d1                                 /* Limit to available space */
    
copy_input_chars:
    tst.l   %d1
    beq     input_display_done
    moveb   (%a0)+, (%a1)+
    subl    #1, %d1
    bra     copy_input_chars
    
input_display_done:
    movel   (%sp)+, %a1
    movel   (%sp)+, %a0
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Handle incoming chat message from network
 * Called by aether modem when +CHAT: notification received
 * Input: A0 = time string, A1 = sender string, A2 = message string
 */
handle_incoming_chat_message:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Only process if we're in chat mode */
    cmpl    #1, chat_mode_active
    bne     incoming_chat_done
    
    /* Build display string: [time] <sender> message */
    lea     temp_chat_line, %a3
    
    /* Add [time] */
    moveb   #'[', (%a3)+
    move.l  %a0, %a4  /* A4 = time string */
copy_time:
    move.b  (%a4)+, %d0
    beq     time_done
    move.b  %d0, (%a3)+
    bra     copy_time
time_done:
    moveb   #']', (%a3)+
    moveb   #' ', (%a3)+
    
    /* Add <sender> */
    moveb   #'<', (%a3)+
    move.l  %a1, %a4  /* A4 = sender string */
copy_sender:
    move.b  (%a4)+, %d0
    beq     sender_done
    move.b  %d0, (%a3)+
    bra     copy_sender
sender_done:
    moveb   #'>', (%a3)+
    moveb   #' ', (%a3)+
    
    /* Add message */
    move.l  %a2, %a4  /* A4 = message string */
copy_message:
    move.b  (%a4)+, %d0
    beq     message_done
    move.b  %d0, (%a3)+
    bra     copy_message
message_done:
    clr.b   (%a3)  /* Null terminate */
    
    /* Add to chat history */
    lea     temp_chat_line, %a0
    jsr     add_chat_line
    
    /* Refresh chat display */
    jsr     display_chat_history
    
incoming_chat_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Simple handler for incoming chat - processes raw +CHAT: line
 * Input: A0 = pointer to raw "+CHAT: [time] <sender> message" line
 */
.align 2
handle_incoming_chat_simple:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Only process if we're in chat mode */
    cmpl    #1, chat_mode_active
    bne     simple_chat_done
    
    /* Simply add the raw line to chat history */
    jsr     add_chat_line
    
    /* Refresh chat display */
    jsr     display_chat_history
    
simple_chat_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Add a line to the chat history buffer
 * Input: A0 = pointer to null-terminated string (max 79 chars)
 */
.align 2
add_chat_line:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Check if buffer is full (max 14 lines to match display area) */
    movel   chat_history_lines, %d0
    cmpl    #14, %d0
    blt     add_line_space_ok
    
    /* Buffer full - shift all lines up by one */
    lea     chat_history_buffer, %a1        /* Destination */
    lea     chat_history_buffer + 80, %a2   /* Source (skip first line) */
    movel   #1040, %d0                      /* Copy 13 lines × 80 chars */
shift_lines_up:
    move.b  (%a2)+, (%a1)+
    subq.l  #1, %d0
    bne     shift_lines_up
    
    /* Clear the last line (line 13, 0-indexed) */
    lea     chat_history_buffer + 1040, %a1  /* Start of last line */
    movel   #80, %d0
clear_last_line:
    move.b  #' ', (%a1)+
    subq.l  #1, %d0
    bne     clear_last_line
    
    /* Set to add at line 13 (last line, 0-indexed) */
    movel   #13, chat_history_lines
    
add_line_space_ok:
    /* Calculate position to add new line */
    movel   chat_history_lines, %d0
    mulu.w  #80, %d0                        /* Line offset */
    lea     chat_history_buffer, %a1
    adda.l  %d0, %a1                        /* A1 = destination in buffer */
    
    /* Copy the string, padding with spaces */
    movel   #80, %d1                        /* Characters per line */
copy_new_line:
    tst.l   %d1
    beq     line_copy_done
    move.b  (%a0), %d0
    beq     pad_remaining                   /* End of string, pad with spaces */
    move.b  %d0, (%a1)+
    addq.l  #1, %a0
    subq.l  #1, %d1
    bra     copy_new_line
    
pad_remaining:
    tst.l   %d1
    beq     line_copy_done
    move.b  #' ', (%a1)+
    subq.l  #1, %d1
    bra     pad_remaining
    
line_copy_done:
    /* Increment line count */
    addq.l  #1, chat_history_lines
    
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Chat mode strings */
.section .rodata
chat_header_msg:
    .string "=== Aether Network party-line chat ==="
chat_bare_bones_header_msg:
    .string "=== BARE-BONES CHAT MODE (network disabled) ==="
chat_status_prefix:
    .string "Network: "
status_disconnected_msg:
    .string "Disconnected"
status_connecting_msg:
    .string "Connecting..."
status_connected_msg:
    .string "Connected to mesh"
status_disabled_msg:
    .string "DISABLED"
chat_input_prompt:
    .string "> Type message (ESC to exit chat mode)"
chat_footer_prompt:
    .string "Type message (ESC to exit chat mode)"
chat_bare_bones_footer_prompt:
    .string "Type message (local only, ESC to exit) - No network"
default_chat_room_name:
    .string "retro"
connecting_message:
    .string "Attempting to connect to Aether network..."
connected_message:
    .string "Connected to Aether network! Chat mode ready."
message_sent_confirmation:
    .string "Message sent successfully!"
message_sent_msg:
    .string "Message sent! (local only)"

/* Chat footer strings */
aether_layer_status_msg:
    .string "LoRa:"
heymac_status_prefix:
    .string "HeyMac:"
mesh_status_prefix:
    .string "Mesh:"
layer_status_up:
    .string "UP"
layer_status_down:
    .string "DOWN"
neighbors_short_prefix:
    .string "Neighbors:"
neighbors_short_msg:
    .string "Neighbors:"
net_status_msg:
    .string "Net: "
chat_commands_msg:
    .string "Enter=Send ESC=Exit"

/* Network Status Display Strings */
net_status_header:
    .string "AETHER: "
neighbor_count_prefix:
    .string " ("
net_id_prefix:
    .string "Net: "
node_id_prefix:
    .string " Node: "
rf_params_prefix:
    .string "RF: "
sf_prefix:
    .string " SF"
bw_prefix:
    .string " BW"
khz_suffix:
    .string "kHz"
mhz_suffix:
    .string "MHz"
signal_prefix:
    .string "Signal: "
rssi_prefix:
    .string "RSSI"
snr_prefix:
    .string " SNR"
pwr_prefix:
    .string " TX"
dbm_suffix:
    .string "dBm"
neighbors_header:
    .string "Neighbors: "
no_neighbors_msg:
    .string "No neighbors discovered (waiting for beacons...)"

/* ======================================================================
 * DEBUG MODE FUNCTIONS 
 * ====================================================================== */

/* Process debug mode activation */
.align 2
process_debug_mode:
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    movel   %a0, -(%sp)
    
    /* Check if already in debug mode */
    cmpl    #1, debug_mode_active
    beq     toggle_debug_off
    
    /* Enter debug mode */
    movel   #1, debug_mode_active
    
    /* Clear screen and display debug interface */
    jsr     clear_text_screen
    jsr     display_debug_interface
    
    bra     debug_mode_done
    
.align 2
toggle_debug_off:
    /* Exit debug mode */
    movel   #0, debug_mode_active
    jsr     set_display_update_flag  /* Return to normal content display */
    
.align 2
debug_mode_done:
    movel   (%sp)+, %a0
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Display debug interface */
.align 2
display_debug_interface:
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %a0, -(%sp)
    movel   %a1, -(%sp)
    
    /* Display debug header */
    moveal  #TDABase + 1, %a1
    lea     debug_header_msg, %a0
    jsr     copy_string_to_screen
    
    /* Display available commands */
    moveal  #TDABase + 1 + (2 * ScreenWidth), %a1
    lea     debug_commands_msg, %a0
    jsr     copy_string_to_screen
    
    moveal  #TDABase + 1 + (4 * ScreenWidth), %a1
    lea     debug_cmd1_msg, %a0
    jsr     copy_string_to_screen
    
    moveal  #TDABase + 1 + (5 * ScreenWidth), %a1
    lea     debug_cmd2_msg, %a0
    jsr     copy_string_to_screen
    
    moveal  #TDABase + 1 + (6 * ScreenWidth), %a1
    lea     debug_cmd3_msg, %a0
    jsr     copy_string_to_screen
    
    moveal  #TDABase + 1 + (7 * ScreenWidth), %a1
    lea     debug_cmd4_msg, %a0
    jsr     copy_string_to_screen
    
    moveal  #TDABase + 1 + (8 * ScreenWidth), %a1
    lea     debug_cmd5_msg, %a0
    jsr     copy_string_to_screen
    
    moveal  #TDABase + 1 + (9 * ScreenWidth), %a1
    lea     debug_cmd6_msg, %a0
    jsr     copy_string_to_screen
    
    /* Display prompt at bottom */
    moveal  #TDABase + 1 + (22 * ScreenWidth), %a1
    lea     debug_prompt_msg, %a0
    jsr     copy_string_to_screen
    
    movel   (%sp)+, %a1
    movel   (%sp)+, %a0
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Process keyboard input in debug mode */
.align 2
process_debug_input:
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    movel   %a0, -(%sp)
    
    /* Read the key */
    moveal  #KCTLKeys, %a0
    moveb   (%a0), %d0
    
    /* Check for ESC key to exit debug mode */
    cmpb    #KEY_ESC, %d0
    beq     exit_debug_mode
    
    /* Check for numbered shortcuts */
    cmpb    #KEY_1, %d0
    beq     debug_cmd_status
    cmpb    #KEY_2, %d0
    beq     debug_cmd_neighbors
    cmpb    #KEY_3, %d0
    beq     debug_cmd_routes
    cmpb    #KEY_4, %d0
    beq     debug_cmd_stats
    cmpb    #KEY_5, %d0
    beq     debug_cmd_netaddr
    cmpb    #KEY_6, %d0
    beq     debug_cmd_recv
    
    bra     consume_debug_key

.align 2
exit_debug_mode:
    movel   #0, debug_mode_active
    jsr     set_display_update_flag  /* Return to normal display */
    bra     consume_debug_key

.align 2
debug_cmd_status:
    lea     debug_status_param, %a0
    jsr     aether_debug_command
    jsr     display_debug_result
    bra     consume_debug_key

.align 2
debug_cmd_neighbors:
    jsr     aether_get_neighbors
    jsr     display_debug_result
    bra     consume_debug_key

.align 2
debug_cmd_routes:
    lea     debug_routes_param, %a0
    jsr     aether_debug_command
    jsr     display_debug_result
    bra     consume_debug_key

.align 2
debug_cmd_stats:
    lea     debug_stats_param, %a0
    jsr     aether_debug_command
    jsr     display_debug_result
    bra     consume_debug_key

.align 2
debug_cmd_netaddr:
    jsr     aether_get_netaddr
    jsr     display_debug_result
    bra     consume_debug_key

.align 2
debug_cmd_recv:
    jsr     aether_recv_messages
    jsr     display_debug_result
    bra     consume_debug_key

.align 2
consume_debug_key:
    /* Consume the key report */
    moveb   #1, KCTLNextReport
    
    movel   (%sp)+, %a0
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Minimal chat input processing - MATCHES DEBUG MODE EXACTLY */
.align 2
process_chat_input_minimal:
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    movel   %a0, -(%sp)
    
    /* Read the key */
    moveal  #KCTLKeys, %a0
    moveb   (%a0), %d0
    
    /* Check for ESC key to exit chat mode */
    cmpb    #KEY_ESC, %d0
    beq     exit_chat_mode_minimal
    
    /* For printable characters, show them on screen at fixed location */
    cmpl    #32, %d0           /* Space */
    blt     consume_chat_key_minimal   /* Ignore non-printable */
    cmpl    #126, %d0          /* Tilde */
    bgt     consume_chat_key_minimal   /* Ignore non-printable */
    
    /* Display the character directly at line 12 */
    moveal  #TDABase + 1 + (12 * ScreenWidth), %a1
    lea     chat_key_debug_msg, %a0
    jsr     copy_string_to_screen
    
    /* Display the actual character */
    moveal  #TDABase + 1 + (12 * ScreenWidth) + 20, %a1
    moveb   %d0, (%a1)
    
    bra     consume_chat_key_minimal

.align 2
exit_chat_mode_minimal:
    movel   #0, chat_mode_active
    jsr     set_display_update_flag  /* Return to normal display */
    bra     consume_chat_key_minimal

.align 2
consume_chat_key_minimal:
    /* Consume the key report - EXACT SAME AS DEBUG MODE */
    moveb   #1, KCTLNextReport
    
    movel   (%sp)+, %a0
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Safe non-blocking aether polling */
.align 2
aether_poll_safe:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Check if network functionality is disabled first */
    cmpl    #1, chat_network_disabled
    beq     aether_poll_safe_done
    
    /* Quick status check - if UART not ready, exit immediately */
    move.b  UART1_STATUS, %d0
    btst    #0, %d0  /* RX_READY bit */
    beq     aether_poll_safe_done  /* No data, exit immediately */
    
    /* CRITICAL: Implement timeout protection to prevent freezing */
    move.w  #10, %d7                /* Maximum 10 attempts */
    
aether_poll_safe_loop:
    tst.w   %d7
    beq     aether_poll_safe_done   /* Timeout reached, exit */
    subq.w  #1, %d7
    
    /* Check if data is still available */
    move.b  UART1_STATUS, %d0
    btst    #0, %d0  /* RX_READY bit */
    beq     aether_poll_safe_done   /* No more data, exit */
    
    /* Read ONE byte only - don't call complex aether_poll */
    move.b  UART1_RX, %d0           /* Read the byte directly */
    
    /* Simple processing - just check if it's a newline */
    cmpi.b  #0x0A, %d0              /* LF character */
    beq     aether_poll_safe_done   /* End of line, exit */
    cmpi.b  #0x0D, %d0              /* CR character */
    beq     aether_poll_safe_done   /* End of line, exit */
    
    /* Add small delay to prevent tight loop */
    move.w  #100, %d6
aether_delay_loop:
    subq.w  #1, %d6
    bne     aether_delay_loop
    
    bra     aether_poll_safe_loop
    
aether_poll_safe_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Update chat display only if needed */
.align 2
update_chat_display_if_needed:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Only update if there are new messages or status changes */
    cmpl    #1, chat_display_dirty
    bne     update_chat_display_skip
    
    /* Clear the dirty flag first */
    movel   #0, chat_display_dirty
    
    /* Quick display update - just the essential parts */
    jsr     display_chat_history_quick
    jsr     update_chat_status_line
    
update_chat_display_skip:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Quick chat history display update */
.align 2
display_chat_history_quick:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Only update the message area if we have messages */
    cmpl    #0, chat_history_lines
    beq     history_quick_done
    
    /* Clear message area (lines 4-17) */
    moveal  #TDABase + 1 + (4 * ScreenWidth), %a1
    movel   #(14 * ScreenWidth), %d0
clear_message_area:
    moveb   #' ', (%a1)+
    subql   #1, %d0
    bne     clear_message_area
    
    /* Display history */
    jsr     display_chat_history
    
history_quick_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Update chat status line */
.align 2
update_chat_status_line:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Update status line with message count */
    moveal  #TDABase + 1 + (19 * ScreenWidth), %a1
    lea     chat_status_msg, %a0
    jsr     copy_string_to_screen
    
    /* Show message count */
    movel   chat_history_lines, %d0
    jsr     display_number
    
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Display debug command result */
.align 2
display_debug_result:
    movel   %d0, -(%sp)
    movel   %a0, -(%sp)
    movel   %a1, -(%sp)
    
    /* Clear result area (lines 11-20) */
    moveal  #TDABase + 1 + (11 * ScreenWidth), %a1
    movel   #(9 * ScreenWidth), %d0
.align 2
clear_result_area:
    moveb   #' ', (%a1)+
    subql   #1, %d0
    bne     clear_result_area
    
    /* Display simple result message */
    moveal  #TDABase + 1 + (11 * ScreenWidth), %a1
    lea     debug_result_msg, %a0
    jsr     copy_string_to_screen
    
    movel   (%sp)+, %a1
    movel   (%sp)+, %a0
    movel   (%sp)+, %d0
    rts

/* Debug mode strings */
debug_header_msg:
    .string "=== AETHER DEBUG CONSOLE - PCD68 VALIDATION MODE ==="
debug_commands_msg:
    .string "Available Debug Commands:"
debug_cmd1_msg:
    .string "1 - AT+DEBUG=STATUS   (Layer status check)"
debug_cmd2_msg:
    .string "2 - AT+NEIGH         (Neighbor discovery)"
debug_cmd3_msg:
    .string "3 - AT+DEBUG=ROUTES  (Routing table)" 
debug_cmd4_msg:
    .string "4 - AT+DEBUG=STATS   (Statistics)"
debug_cmd5_msg:
    .string "5 - AT+NETADDR?      (Network address)"
debug_cmd6_msg:
    .string "6 - AT+RECV          (Check messages)"
debug_prompt_msg:
    .string "Press 1-6 for commands, ESC to exit debug mode"
debug_result_msg:
    .string "Command executed successfully!"

/* Chat debug message */
chat_key_debug_msg:
    .string "Chat Key Pressed:"

/* Minimal chat mode strings */
chat_minimal_header_msg:
    .string "=== MINIMAL CHAT MODE - TESTING KEYBOARD ONLY ==="
chat_minimal_commands_msg:
    .string "Press any key to see key code, ESC to exit"
chat_minimal_prompt_msg:
    .string "Key presses will appear above - ESC to exit chat mode"

/* Chat status message */
chat_status_msg:
    .string "Messages: "

/* Debug command parameters */
debug_status_param:
    .string "STATUS"
debug_routes_param:
    .string "ROUTES"
debug_stats_param:
    .string "STATS"

/* ======================================================================
 * AETHER MODEM LIBRARY INTEGRATION
 * ====================================================================== */

.section .text

/* Include the aether modem library */
.include "aether_modem.S"

/* Update chat display with real-time status and refresh
 * Called frequently during chat mode for responsive UI
 */
.align 2
update_chat_display:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Only update if we're in chat mode */
    cmpl    #1, chat_mode_active
    bne     update_chat_done
    
    /* Refresh the entire chat display */
    jsr     display_chat_interface
    
    /* Update network status indicators */
    jsr     update_network_status_display
    
    /* Update message counters and activity indicators */
    jsr     update_chat_indicators
    
update_chat_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Update network status display in real-time */
.align 2
update_network_status_display:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Update status line with current network information */
    moveal  #TDABase + 1 + (1 * ScreenWidth), %a1
    movea.l #chat_status_prefix, %a0
    jsr     copy_string_to_screen
    
    /* Show connection status - use the aether modem's network_status */
    moveb   network_status, %d0
    cmpi.b  #NET_CONNECTED, %d0
    beq     show_net_connected_status
    cmpi.b  #NET_CONNECTING, %d0
    beq     show_net_connecting_status
    
    /* Default to disconnected */
    movea.l #status_disconnected_msg, %a0
    bra     copy_status_msg
    
show_net_connecting_status:
    movea.l #status_connecting_msg, %a0
    bra     copy_status_msg
    
show_net_connected_status:
    movea.l #status_connected_msg, %a0
    
copy_status_msg:
    jsr     copy_string_to_screen
    
    /* Show neighbor count if connected */
    cmpi.b  #NET_CONNECTED, network_status
    bne     status_display_done
    
status_display_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Update chat activity indicators */
.align 2
update_chat_indicators:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Update activity indicator on status line */
    moveal  #TDABase + 1 + (23 * ScreenWidth) + 75, %a1
    
    /* Toggle activity indicator to show system is responsive */
    moveb   activity_indicator, %d0
    cmpi.b  #'*', %d0
    beq     toggle_to_plus
    
    moveb   #'*', %d0
    bra     update_indicator
    
toggle_to_plus:
    moveb   #'+', %d0
    
update_indicator:
    moveb   %d0, activity_indicator
    moveb   %d0, (%a1)
    
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Display a number at current cursor position
 * Input: D0 = number to display
 * Note: A1 should point to current cursor position
 */
.align 2
display_number:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Handle zero case */
    tst.l   %d0
    bne     number_not_zero
    moveb   #'0', (%a1)+
    bra     display_number_done
    
number_not_zero:
    /* Handle negative numbers */
    tst.l   %d0
    bpl     number_positive
    moveb   #'-', (%a1)+
    negl    %d0
    
number_positive:
    /* Convert number to string - use stack for temporary storage */
    lea     -12(%sp), %sp      /* Allocate 12 bytes on stack */
    move.l  %sp, %a2           /* A2 = temporary buffer */
    move.l  %a2, %a3           /* A3 = start of buffer */
    
    /* Add null terminator */
    clr.b   11(%a3)
    
    /* Convert digits from right to left */
    lea     10(%a3), %a2       /* Start from end of buffer */
    
convert_loop:
    tst.l   %d0
    beq     convert_done
    
    /* Divide by 10 */
    move.l  %d0, %d1
    divu    #10, %d1
    swap    %d1                /* Remainder in lower word */
    add.b   #'0', %d1          /* Convert to ASCII */
    move.b  %d1, (%a2)         /* Store digit */
    subq.l  #1, %a2            /* Move to previous position */
    
    /* Quotient for next iteration */
    move.l  %d0, %d1
    divu    #10, %d1
    move.w  %d1, %d0           /* Quotient in D0 */
    ext.l   %d0
    
    bra     convert_loop
    
convert_done:
    /* Copy converted string to screen */
    addq.l  #1, %a2            /* Point to first digit */
    
copy_digits:
    move.b  (%a2)+, %d1
    beq     copy_digits_done
    move.b  %d1, (%a1)+
    bra     copy_digits
    
copy_digits_done:
    lea     12(%sp), %sp       /* Deallocate stack space */
    
display_number_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Quick chat display update - lightweight version for main loop integration
 * Only updates essential status information without full screen refresh
 */
.align 2
update_chat_display_quick:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Only update if we're in chat mode */
    cmpl    #1, chat_mode_active
    bne     update_chat_quick_done
    
    /* Update just the network status line quickly */
    jsr     update_network_status_display
    
    /* Update activity indicator to show responsiveness */
    jsr     update_chat_indicators
    
    /* Poll for any new chat messages and display them */
    jsr     check_and_display_new_messages
    
update_chat_quick_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Check for and display new messages without full interface refresh */
.align 2
check_and_display_new_messages:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* This is called after aether_poll, so any new messages should already be processed */
    /* Just refresh the chat history display area */
    jsr     display_chat_history
    
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* ======================================================================
 * IRC-Style Chat Functions
 * ====================================================================== */

/* IRC-Style Chat Functions */

/* Draw chat history in content area - IRC style */
.align 2
draw_chat_history_irc:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Clear content area first */
    jsr     clear_content_area
    
    /* Start at content area (line 4) */
    moveal  #TDABase + 1 + (4 * ScreenWidth), %a1
    
    /* Display chat history buffer in content area */
    lea     chat_history_buffer, %a0
    movel   chat_history_lines, %d0
    cmpl    #14, %d0                /* Max 14 lines in content area */
    ble     history_lines_fit
    movel   #14, %d0                /* Limit to content area size */
    
history_lines_fit:
    cmpl    #0, %d0
    beq     chat_history_done
    
chat_history_loop:
    /* Copy one line from history buffer */
    movel   #0, %d1
copy_chat_line:
    cmpl    #78, %d1                /* Leave room for borders */
    bge     next_chat_line
    moveb   (%a0)+, %d2
    moveb   %d2, (%a1)+
    addl    #1, %d1
    bra     copy_chat_line
    
next_chat_line:
    /* Move to next screen line - FIXED calculation */
    movel   %a1, %d2
    subl    #TDABase + 1, %d2        /* Get offset from screen start */
    divu    #ScreenWidth, %d2        /* Get current line */
    swap    %d2                       /* Get column position */
    moveq   #ScreenWidth, %d1
    subl    %d2, %d1                  /* Chars to end of line */
    addl    %d1, %a1                  /* Move to start of next line */
    
    subl    #1, %d0
    bne     chat_history_loop
    
chat_history_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Display current chat input in footer */
/* Input: A2 = screen position to write to */
.align 2
display_chat_input_line:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Save the screen position passed in A2 */
    moveal  %a2, %a1
    
    /* Display current input buffer contents */
    lea     chat_input_buffer, %a0
    movel   chat_input_length, %d0
    cmpl    #0, %d0
    beq     input_line_done
    
    /* Limit to available space (about 70 chars) */
    cmpl    #70, %d0
    ble     input_fits
    movel   #70, %d0
    
input_fits:
display_input_chars:
    tst.l   %d0
    beq     input_line_done
    moveb   (%a0)+, (%a1)+
    subl    #1, %d0
    bra     display_input_chars
    
input_line_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Add character to chat input buffer */
.align 2
add_char_to_chat_input:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Check if buffer has room */
    movel   chat_input_length, %d1
    cmpl    #78, %d1                /* Leave room for null terminator */
    bge     add_char_done
    
    /* Add character to buffer - SAFE addressing */
    lea     chat_input_buffer, %a0
    addl    %d1, %a0                /* Move to correct position */
    moveb   %d0, (%a0)              /* Store character safely */
    addl    #1, chat_input_length
    
    /* Trigger display update */
    jsr     set_display_update_flag
    
add_char_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Remove character from chat input buffer */
.align 2
remove_chat_input_char:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Check if buffer has content */
    cmpl    #0, chat_input_length
    beq     remove_char_done
    
    /* Remove last character */
    subl    #1, chat_input_length
    
    /* Trigger display update */
    jsr     set_display_update_flag
    
remove_char_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Send current chat input as message */
.align 2
send_current_chat_input:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Check if there's anything to send */
    cmpl    #0, chat_input_length
    beq     send_input_done
    
    /* Null terminate message - SAFE addressing */
    movel   chat_input_length, %d1
    lea     chat_input_buffer, %a0
    addl    %d1, %a0                /* Move to correct position */
    moveb   #0, (%a0)               /* Store null terminator safely */
    
    /* Check if network functionality is disabled */
    cmpl    #1, chat_network_disabled
    beq     send_input_local_only
    
    /* Send via aether with timeout protection */
    /* Set a timeout counter to prevent hanging */
    movel   #5000, chat_timeout_counter  /* Allow 5000 cycles maximum */
    /* Set A0 to point to start of message buffer for aether_chat_send_safe */
    lea     chat_input_buffer, %a0
    jsr     aether_chat_send_safe
    
send_input_local_only:
    /* Add to chat history as local echo (always do this) */
    lea     chat_input_buffer, %a0
    jsr     add_chat_line
    
    /* Clear input buffer */
    movel   #0, chat_input_length
    
    /* Trigger display update */
    jsr     set_display_update_flag
    
send_input_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* ======================================================================
 * PHASE 1: SIMPLE BUFFER MANAGEMENT FUNCTIONS
 * ====================================================================== */

/* Simple add character - uses same pattern as debug mode functions */
.align 2
simple_add_char:
    /* Use minimal register save like debug functions */
    movel   %d1, -(%sp)
    movel   %a1, -(%sp)
    
    /* Check buffer length (D0 contains character) */
    movel   chat_input_length, %d1
    cmpl    #70, %d1                /* Keep well under 80 char limit */
    bge     simple_add_done
    
    /* Add character to buffer */
    lea     chat_input_buffer, %a1
    moveb   %d0, (%a1,%d1)          /* Simple indexed addressing */
    addql   #1, chat_input_length
    
simple_add_done:
    movel   (%sp)+, %a1
    movel   (%sp)+, %d1
    rts

/* Simple remove character */
.align 2
simple_remove_char:
    /* Check if buffer has content */
    cmpl    #0, chat_input_length
    beq     simple_remove_done
    
    /* Remove last character */
    subql   #1, chat_input_length
    
simple_remove_done:
    rts

/* Simple send message - PHASE 2: Enhanced display */
.align 2
simple_send_message:
    movel   %d1, -(%sp)
    movel   %a0, -(%sp)
    movel   %a1, -(%sp)
    
    /* Check if buffer has content */
    cmpl    #0, chat_input_length
    beq     simple_send_done
    
    /* Build formatted message in temp buffer */
    lea     temp_chat_line, %a1
    
    /* Add local echo prefix ">>> " */
    moveb   #'>', (%a1)+
    moveb   #'>', (%a1)+
    moveb   #'>', (%a1)+
    moveb   #' ', (%a1)+
    
    /* Copy the message content */
    movel   chat_input_length, %d1
    lea     chat_input_buffer, %a0
copy_message_loop:
    tst.l   %d1
    beq     message_copied
    moveb   (%a0)+, (%a1)+
    subql   #1, %d1
    bra     copy_message_loop
    
message_copied:
    /* Null terminate */
    moveb   #0, (%a1)
    
    /* Add formatted line to chat history */
    lea     temp_chat_line, %a0
    jsr     add_chat_line
    
    /* CRITICAL: Refresh the chat display immediately */
    jsr     display_chat_history
    
    /* Show brief confirmation in status area */
    moveal  #TDABase + 1 + (19 * ScreenWidth), %a1
    lea     message_sent_msg, %a0
    jsr     copy_string_to_screen
    
    /* Clear input buffer */
    movel   #0, chat_input_length
    
    /* Trigger display refresh */
    jsr     set_display_update_flag
    
simple_send_done:
    movel   (%sp)+, %a1
    movel   (%sp)+, %a0
    movel   (%sp)+, %d1
    rts

/* Simple footer update - show current buffer */
.align 2
simple_update_footer:
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %a0, -(%sp)
    movel   %a1, -(%sp)
    
    /* Clear footer line (line 21) */
    moveal  #TDABase + 1 + (21 * ScreenWidth), %a1
    movel   #79, %d0
clear_footer_loop:
    moveb   #' ', (%a1)+
    subql   #1, %d0
    bne     clear_footer_loop
    
    /* Show enhanced prompt */
    moveal  #TDABase + 1 + (21 * ScreenWidth), %a1
    
    /* Add prompt: "Type: " */
    moveb   #'T', (%a1)+
    moveb   #'y', (%a1)+
    moveb   #'p', (%a1)+
    moveb   #'e', (%a1)+
    moveb   #':', (%a1)+
    moveb   #' ', (%a1)+
    
    /* Show current buffer contents */
    movel   chat_input_length, %d0
    cmpl    #0, %d0
    beq     footer_done
    
    /* Display buffer (limit to 70 chars) */
    cmpl    #70, %d0
    ble     show_buffer
    movel   #70, %d0
    
show_buffer:
    lea     chat_input_buffer, %a0
show_buffer_loop:
    tst.l   %d0
    beq     footer_done
    moveb   (%a0)+, (%a1)+
    subql   #1, %d0
    bra     show_buffer_loop
    
footer_done:
    /* Show character count at end of line */
    cmpl    #0, chat_input_length
    beq     no_char_count
    
    /* Move to right side and show [count/70] */
    moveal  #TDABase + 1 + (21 * ScreenWidth) + 70, %a1
    moveb   #'[', (%a1)+
    
    /* Simple number display for char count */
    movel   chat_input_length, %d0
    jsr     simple_show_number
    
    moveb   #'/', (%a1)+
    moveb   #'7', (%a1)+
    moveb   #'0', (%a1)+
    moveb   #']', (%a1)+
    
no_char_count:
    movel   (%sp)+, %a1
    movel   (%sp)+, %a0
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

/* Simple number display helper */
.align 2
simple_show_number:
    /* Display 1-2 digit number at current A1 position */
    cmpl    #10, %d0
    blt     single_digit
    
    /* Two digits */
    movel   %d0, %d1
    divu    #10, %d1
    addib   #'0', %d1
    moveb   %d1, (%a1)+
    
    /* Get remainder */
    mulu    #10, %d1
    subl    %d1, %d0
    
single_digit:
    addib   #'0', %d0
    moveb   %d0, (%a1)+
    rts

/* String constants */
local_echo_prefix:
    .string ">>> "

/* Safe chat message handler - just marks display as dirty */
.align 2
handle_incoming_chat_safe:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* For now, just add a simple "Message received" indicator */
    lea     temp_chat_line, %a1
    movea.l #incoming_msg_prefix, %a0
    jsr     copy_string_safe
    
    /* Add the received message (simplified) */
    movea.l #at_response_buffer, %a0
    jsr     copy_string_safe
    
    /* Add line to chat history */
    lea     temp_chat_line, %a0
    jsr     add_chat_line
    
    /* Mark display as dirty for async update */
    movel   #1, chat_display_dirty
    
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Safe string copy without risk of buffer overflow */
.align 2
copy_string_safe:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    movel   #79, %d0  /* Maximum characters to copy */
copy_safe_loop:
    tst.l   %d0
    beq     copy_safe_done
    moveb   (%a0)+, %d1
    tst.b   %d1
    beq     copy_safe_done
    moveb   %d1, (%a1)+
    subl    #1, %d0
    bra     copy_safe_loop
    
copy_safe_done:
    moveb   #0, (%a1)  /* Null terminate */
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* Incoming message prefix */
incoming_msg_prefix:
    .string "< "

/* Safe wrapper for aether_chat_send with timeout protection */
.align 2
aether_chat_send_safe:
    movem.l %d0-%d7/%a0-%a6, -(%sp)
    
    /* Check if network functionality is disabled first - CRITICAL! */
    cmpl    #1, chat_network_disabled
    beq     aether_send_disabled
    
    /* Check timeout counter */
    cmpl    #0, chat_timeout_counter
    beq     aether_send_timeout
    
    /* Decrement timeout counter */
    subil   #1, chat_timeout_counter
    
    /* Try to send message with quick return if UART not ready */
    move.b  UART1_STATUS, %d0
    btst    #1, %d0  /* TX_EMPTY bit */
    beq     aether_send_not_ready  /* UART busy, skip this cycle */
    
    /* UART ready - call original function */
    /* A0 already contains message pointer from caller */
    jsr     aether_chat_send        /* Call original function */
    bra     aether_send_done

aether_send_disabled:
    /* Network disabled - return success without any hardware access */
    moveq   #0, %d0  /* AT_OK */
    bra     aether_send_done
    
aether_send_not_ready:
    /* UART not ready - return success anyway to prevent hanging */
    moveq   #0, %d0  /* AT_OK */
    bra     aether_send_done
    
aether_send_timeout:
    /* Timeout reached - return success to prevent hanging */
    moveq   #0, %d0  /* AT_OK */
    
aether_send_done:
    movem.l (%sp)+, %d0-%d7/%a0-%a6
    rts

/* ===============================================
   NETWORK-READY CHAT FEATURES - PHASE 2
   All functions designed for easy aether hookup
   =============================================== */

/* Enhanced message sending with timestamp and room support */
.align 2
enhanced_send_message:
    movem.l %d0-%d2/%a0-%a2, -(%sp)
    
    /* Check if buffer has content */
    cmpl    #0, chat_input_length
    beq     enhanced_send_done
    
    /* Get current timestamp */
    jsr     get_current_time
    movel   %d0, last_message_time
    
    /* Increment message counter */
    addql   #1, message_counter
    
    /* NETWORK HOOK: Check if network is enabled */
    moveb   chat_network_disabled, %d0
    tst.b   %d0
    bne     local_message_only
    
    /* TODO: Add network sending here */
    /* jsr   aether_send_chat_message */
    
local_message_only:
    /* Build formatted message with timestamp and room info */
    lea     temp_chat_line, %a1
    
    /* Add timestamp [HH:MM] */
    moveb   #'[', (%a1)+
    jsr     format_timestamp
    moveb   #']', (%a1)+
    moveb   #' ', (%a1)+
    
    /* Add room indicator if not default */
    lea     current_room, %a0
    tst.b   (%a0)
    beq     no_room_prefix
    
    moveb   #'#', (%a1)+
    jsr     copy_room_name_to_display
    moveb   #':', (%a1)+
    moveb   #' ', (%a1)+
    
no_room_prefix:
    /* Add message prefix */  
    moveb   #'>', (%a1)+
    moveb   #'>', (%a1)+
    moveb   #'>', (%a1)+
    moveb   #' ', (%a1)+
    
    /* Copy the message content */
    movel   chat_input_length, %d1
    lea     chat_input_buffer, %a0
enhanced_copy_loop:
    tst.l   %d1
    beq     enhanced_copied
    moveb   (%a0)+, (%a1)+
    subql   #1, %d1
    bra     enhanced_copy_loop
    
enhanced_copied:
    /* Null terminate */
    moveb   #0, (%a1)
    
    /* Add to chat history */
    lea     temp_chat_line, %a0
    jsr     add_chat_line
    
    /* CRITICAL: Refresh the chat display immediately */
    jsr     display_chat_history
    
    /* Show enhanced confirmation */
    jsr     show_send_confirmation
    
    /* Trigger display refresh */
    jsr     set_display_update_flag
    
enhanced_send_done:
    movem.l (%sp)+, %d0-%d2/%a0-%a2
    rts

/* Input history management - NETWORK READY */
.align 2
add_to_input_history:
    movem.l %d0-%d2/%a0-%a2, -(%sp)
    
    /* Check if we have input to store */
    cmpl    #0, chat_input_length
    beq     add_history_done
    
    /* Find insertion point (circular buffer) */
    movel   input_history_count, %d0
    cmpl    #10, %d0               /* Max 10 history entries */
    blt     history_not_full
    
    /* Buffer is full, shift everything up */
    jsr     shift_input_history
    movel   #9, %d0               /* Insert at position 9 */
    bra     insert_at_position
    
history_not_full:
    /* Insert at current count position */
    addql   #1, input_history_count
    
insert_at_position:
    /* Calculate buffer position: position * 80 bytes */
    mulu    #80, %d0
    lea     input_history_buffer, %a0
    adda.l  %d0, %a0
    
    /* Copy current input to history */
    lea     chat_input_buffer, %a1
    movel   chat_input_length, %d1
copy_to_history:
    tst.l   %d1
    beq     history_copied
    moveb   (%a1)+, (%a0)+
    subql   #1, %d1
    bra     copy_to_history
    
history_copied:
    moveb   #0, (%a0)  /* Null terminate */
    
add_history_done:
    movem.l (%sp)+, %d0-%d2/%a0-%a2
    rts

/* Navigate input history up (older messages) */
.align 2
navigate_input_history_up:
    movem.l %d0-%d2/%a0-%a2, -(%sp)
    
    /* Check if we have history */
    cmpl    #0, input_history_count
    beq     nav_up_done
    
    /* Move to previous entry */
    movel   input_history_index, %d0
    addql   #1, %d0
    
    /* Check bounds */
    cmpl    input_history_count, %d0
    bge     nav_up_done
    
    /* Update index */
    movel   %d0, input_history_index
    
    /* Load history entry into input buffer */
    jsr     load_history_entry
    
    /* Update display */
    jsr     simple_update_footer
    
nav_up_done:
    movem.l (%sp)+, %d0-%d2/%a0-%a2
    rts

/* Navigate input history down (newer messages) */
.align 2
navigate_input_history_down:
    movem.l %d0-%d2/%a0-%a2, -(%sp)
    
    /* Check if we can go down */
    movel   input_history_index, %d0
    cmpl    #0, %d0
    beq     nav_down_clear      /* At newest, clear buffer */
    
    /* Move to next entry */
    subql   #1, %d0
    movel   %d0, input_history_index
    
    /* Load history entry */
    jsr     load_history_entry
    
    /* Update display */
    jsr     simple_update_footer
    bra     nav_down_done
    
nav_down_clear:
    /* Clear input buffer */
    clrl    chat_input_length
    jsr     simple_update_footer
    
nav_down_done:
    movem.l (%sp)+, %d0-%d2/%a0-%a2
    rts

/* Load history entry into input buffer */
.align 2
load_history_entry:
    movem.l %d0-%d2/%a0-%a2, -(%sp)
    
    /* Calculate history position */
    movel   input_history_count, %d0
    subl    input_history_index, %d0
    subql   #1, %d0               /* Convert to 0-based index */
    mulu    #80, %d0
    
    /* Get source and destination */
    lea     input_history_buffer, %a0
    adda.l  %d0, %a0              /* Source */
    lea     chat_input_buffer, %a1 /* Destination */
    
    /* Copy until null terminator */
    clrl    %d1                   /* Length counter */
load_history_loop:
    moveb   (%a0)+, %d0
    tst.b   %d0
    beq     load_history_done
    moveb   %d0, (%a1)+
    addql   #1, %d1
    cmpl    #79, %d1             /* Safety check */
    blt     load_history_loop
    
load_history_done:
    movel   %d1, chat_input_length
    
    movem.l (%sp)+, %d0-%d2/%a0-%a2
    rts

/* Shift input history buffer up (remove oldest) */
.align 2
shift_input_history:
    movem.l %d0-%d2/%a0-%a2, -(%sp)
    
    /* Move entries 1-9 to positions 0-8 */
    movel   #9, %d2              /* Number of entries to move */
    lea     input_history_buffer, %a0
    lea     input_history_buffer+80, %a1  /* Source: entry 1 */
    
shift_loop:
    tst.l   %d2
    beq     shift_done
    
    /* Copy 80 bytes */
    movel   #80, %d1
shift_copy:
    tst.l   %d1
    beq     shift_next
    moveb   (%a1)+, (%a0)+
    subql   #1, %d1
    bra     shift_copy
    
shift_next:
    subql   #1, %d2
    bra     shift_loop
    
shift_done:
    movem.l (%sp)+, %d0-%d2/%a0-%a2
    rts

/* Time and timestamp functions - NETWORK READY */
.align 2
get_current_time:
    /* Simple time counter for now - TODO: Real RTC when available */
    addql   #1, simple_time_counter
    movel   simple_time_counter, %d0
    rts

.align 2
format_timestamp:
    /* Format current time as HH:MM at A1 position */
    /* For now, show simple counter in hex */
    movel   last_message_time, %d0
    
    /* Extract "hours" (high nibble) */
    movel   %d0, %d1
    lsrl    #8, %d1
    andl    #0x0F, %d1
    cmpb    #10, %d1
    blt     hours_digit
    addib   #7, %d1               /* A-F for hex */
hours_digit:
    addib   #'0', %d1
    moveb   %d1, (%a1)+
    
    moveb   %d0, %d1
    lsrl    #4, %d1
    andl    #0x0F, %d1
    cmpb    #10, %d1
    blt     hours_digit2
    addib   #7, %d1
hours_digit2:
    addib   #'0', %d1
    moveb   %d1, (%a1)+
    
    moveb   #':', (%a1)+
    
    /* Extract "minutes" (low nibble) */
    moveb   %d0, %d1
    andl    #0x0F, %d1
    cmpb    #10, %d1
    blt     mins_digit
    addib   #7, %d1
mins_digit:
    addib   #'0', %d1
    moveb   %d1, (%a1)+
    
    moveb   %d0, %d1
    lsrl    #4, %d1
    andl    #0x0F, %d1
    cmpb    #10, %d1
    blt     mins_digit2
    addib   #7, %d1
mins_digit2:  
    addib   #'0', %d1
    moveb   %d1, (%a1)+
    
    rts

/* Room management - NETWORK READY */
.align 2
copy_room_name_to_display:
    /* Copy current room name to A1, max 8 chars for display */
    movel   #8, %d0
room_copy_loop:
    tst.l   %d0
    beq     room_copy_done
    moveb   (%a0)+, %d1
    tst.b   %d1
    beq     room_copy_done
    moveb   %d1, (%a1)+
    subql   #1, %d0
    bra     room_copy_loop
room_copy_done:
    rts

/* Enhanced send confirmation */
.align 2
show_send_confirmation:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    
    /* Show confirmation on status line */
    moveal  #TDABase + 1 + (19 * ScreenWidth), %a1
    
    /* Clear status line first */
    movel   #79, %d0
clear_status:
    moveb   #' ', (%a1)+
    subql   #1, %d0
    bne     clear_status
    
    /* Show enhanced message */
    moveal  #TDABase + 1 + (19 * ScreenWidth), %a1
    lea     enhanced_sent_msg, %a0
    jsr     copy_string_to_screen
    
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

/* Initialize room system - NETWORK READY */
.align 2
init_chat_rooms:
    movem.l %d0-%d1/%a0, -(%sp)
    
    /* Set default room to empty (general chat) */
    lea     current_room, %a0
    moveb   #0, (%a0)
    
    /* Initialize room list for future network use */
    /* TODO: Load room list from aether when enabled */
    
    movem.l (%sp)+, %d0-%d1/%a0
    rts

/* Data storage */
simple_time_counter:
    .dc.l    0

enhanced_sent_msg:
    .string ">>> Message sent! (network ready)                                       "

/* End of network-ready chat functions */


