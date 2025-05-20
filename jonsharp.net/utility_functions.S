/* PCD-68 Utility Functions */

/* Define memory locations and constants */
.equ ScrnBase, 0x810000
.equ TDABase, 0x410000
.equ KCTLBase, 0x420000
.equ UARTBase, 0x450000

/* Memory sizes */
.equ TDASize, 80 * 23

/* UI Constants */
.equ ScreenWidth, 80
.equ ScreenHeight, 23
.equ TextMode, 2               /* 1 for 50-col, 2 for 80-col */
.equ MaxMenuItems, 20          /* Maximum items in a menu */
.equ MaxContentSize, 1024      /* Maximum content buffer size */

/* Reference the external variables from pcd68home.S */
.extern menu_table
.extern content_text_ptrs
.extern current_menu_id
.extern current_selection
.extern view_state
.extern header_title
.extern version_text
.extern version_text_length
.extern status_text
.extern selection_text
.extern footer_commands

/* Clear the screen */
.global clear_screen
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

/* Clear content area */
.global clear_content_area
clear_content_area:
    /* Loop through content area lines (4-17) - stop before line 18 (border) */
    movel   #4, %d7             /* Start at line 4 */
clear_content_loop:
    cmpl    #18, %d7            /* End at line 17 */
    bge     clear_content_done
    
    /* Calculate position for this line */
    muls    #ScreenWidth, %d7
    lea     TDABase + 1, %a0
    addl    %d7, %a0
    moveal  %a0, %a2
    
    /* Clear this line with spaces, preserving borders */
    movel   #0, %d6             /* Column counter */
clear_content_line:
    cmpl    #ScreenWidth, %d6
    bge     clear_content_next_line
    
    /* Write space character, preserving borders */
    cmpl    #0, %d6
    beq     skip_left_border
    cmpl    #ScreenWidth - 1, %d6
    beq     skip_right_border
    
    /* Write space in content area */
    moveb   #' ', (%a2)+
    bra     continue_clear
    
skip_left_border:
    /* Preserve left border */
    moveb   #'|', (%a2)+
    bra     continue_clear
    
skip_right_border:
    /* Preserve right border */
    moveb   #'|', (%a2)+
    
continue_clear:
    addl    #1, %d6
    bra     clear_content_line
    
clear_content_next_line:
    /* Convert line position back from offset */
    divs    #ScreenWidth, %d7   /* Restore D7 to line number */
    
    /* Increment line counter */
    addl    #1, %d7
    bra     clear_content_loop
    
clear_content_done:
    /* Reset cursor position to start of content area (after left border) */
    moveal  #TDABase + 1 + (80 * 4) + 1, %a2
    rts

/* Draw borders */
.global draw_borders
draw_borders:
    /* Position at the start of screen (line 0) */
    moveal  #TDABase + 1, %a2
    
    /* Draw top border line */
    moveb   #'+', (%a2)+
    movel   #1, %d0
top_border_loop:
    cmpl    #ScreenWidth - 1, %d0
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
    movel   #1, %d0
header_border_loop:
    cmpl    #ScreenWidth - 1, %d0
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
    movel   #1, %d0
content_border_loop:
    cmpl    #ScreenWidth - 1, %d0
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
    movel   #1, %d0
status_border_loop:
    cmpl    #ScreenWidth - 1, %d0
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
    movel   #1, %d0
bottom_border_loop:
    cmpl    #ScreenWidth - 1, %d0
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

/* This function has been completely rewritten to fix line 20 border issue */
.global clear_debug_line
.global utility_clear_debug_line

/* The following function draws a border at line 20 */
.global draw_border_line_20
draw_border_line_20:
    /* Save registers */
    movel   %d0, -(%sp)
    movel   %a0, -(%sp)
    
    /* Calculate position for line 20 */
    movel   #20, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw border line */
    moveb   #'+', (%a2)+
    movel   #1, %d0
border_line_20_loop:
    cmpl    #ScreenWidth - 1, %d0
    bge     border_line_20_end
    moveb   #'-', (%a2)+
    addl    #1, %d0
    bra     border_line_20_loop
border_line_20_end:
    moveb   #'+', (%a2)+
    
    /* Restore registers */
    movel   (%sp)+, %a0
    movel   (%sp)+, %d0
    rts

/* Entry points for both functions redirect to the border-drawing function */
clear_debug_line:
utility_clear_debug_line:
    jsr     draw_border_line_20
    rts

/* Center text */
.global center_text
center_text:
    /* Save A2 and other registers */
    movel   %a2, -(%sp)
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    
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
    subl    #2, %d1             /* Adjust for borders */
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
    jsr     print_string_no_advance
    
    /* Restore registers */
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    movel   (%sp)+, %a2
    rts

/* Draw header */
.global draw_header
draw_header:
    /* Call border drawing routine first */
    jsr     draw_borders
    
    /* Position at header content area (line 1) */
    moveal  #TDABase + 1 + ScreenWidth, %a2
    
    /* Draw left border and space */
    moveb   #'|', (%a2)+
    moveb   #' ', (%a2)+
    
    /* Draw application title */
    lea     header_title, %a5
    jsr     print_string_no_advance
    
    /* Calculate version position - right aligned */
    movel   #ScreenWidth - 2, %d0
    /* Calculate cursor position relative to line start */
    movel   %a2, %d3
    subl    #TDABase + 1 + ScreenWidth, %d3
    /* Calculate remaining space */
    subl    %d3, %d0
    subl    #version_text_length, %d0
    
    /* Position cursor for version */
    moveal  #TDABase + 1 + ScreenWidth, %a2
    addl    %d0, %a2
    
    /* Draw version text */
    lea     version_text, %a5
    jsr     print_string_no_advance
    
    /* Close header line with right border */
    moveal  #TDABase + 1 + ScreenWidth + ScreenWidth - 1, %a2
    moveb   #'|', (%a2)
    
    /* Position at header line 2 for title */
    moveal  #TDABase + 1 + (ScreenWidth * 2), %a2
    
    /* Draw left border and space */
    moveb   #'|', (%a2)+
    
    /* Add current menu title centered */
    movew   current_menu_id, %d0
    jsr     get_menu_title
    moveal  %a0, %a5
    jsr     center_text
    
    /* Close header line 2 with right border */
    moveal  #TDABase + 1 + (ScreenWidth * 2) + ScreenWidth - 1, %a2
    moveb   #'|', (%a2)
    
    rts

/* Draw footer */
.global draw_footer
draw_footer:
    /* Calculate position for status line (line 19) */
    movel   #19, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw left border and space */
    moveb   #'|', (%a2)+
    moveb   #' ', (%a2)+
    
    /* Draw status text */
    lea     status_text, %a5
    jsr     print_string_no_advance
    
    /* Print current menu name */
    movew   current_menu_id, %d0
    jsr     get_menu_title
    moveal  %a0, %a5
    jsr     print_string_no_advance
    
    /* Position for debug info on the status line (middle area) */
    /* Make sure we've moved at least 20 chars to create spacing */
    movel   %a2, %d3
    subl    #TDABase + 1 + (19 * ScreenWidth), %d3
    cmpl    #20, %d3
    bge     debug_info_start
    
    /* Add padding to reach 20 chars from start */
    movel   #20, %d4
    subl    %d3, %d4  /* Calculate needed spaces */
debug_pad_loop:
    cmpl    #0, %d4
    ble     debug_info_start
    moveb   #' ', (%a2)+
    subl    #1, %d4
    bra     debug_pad_loop
    
debug_info_start:
    /* Add separator */
    moveb   #'|', (%a2)+
    moveb   #' ', (%a2)+
    
    /* Debug: View state */
    moveb   #'V', (%a2)+
    moveb   #':', (%a2)+
    movew   view_state, %d0
    addib   #'0', %d0
    moveb   %d0, (%a2)+
    moveb   #' ', (%a2)+
    
    /* Debug: Menu ID */
    moveb   #'M', (%a2)+
    moveb   #':', (%a2)+
    movew   current_menu_id, %d0
    addib   #'0', %d0
    moveb   %d0, (%a2)+
    moveb   #' ', (%a2)+
    
    /* Debug: Item count */
    moveb   #'C', (%a2)+
    moveb   #':', (%a2)+
    movew   current_menu_id, %d0
    jsr     get_menu_item_count
    addib   #'0', %d0
    moveb   %d0, (%a2)+
    
    /* Calculate position for selection indicator (right side) */
    movel   #ScreenWidth - 12, %d0
    /* Calculate cursor position relative to line start */
    movel   %a2, %d3
    subl    #TDABase + 1 + (19 * ScreenWidth), %d3
    /* Calculate remaining space */
    subl    %d3, %d0
    
    /* Position cursor for selection */
    moveal  #TDABase + 1 + (19 * ScreenWidth), %a2
    addl    %d0, %a2
    
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
    
    /* Close command line with right border */
    moveal  #TDABase + 1 + (21 * ScreenWidth) + ScreenWidth - 1, %a2
    moveb   #'|', (%a2)
    
    rts

/* Menu utility functions */
.global get_menu_item_count
get_menu_item_count:
    /* Get menu definition from table */
    lsll    #2, %d0              /* Multiply menu ID by 4 for long offset */
    lea     menu_table, %a0
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get menu definition pointer */
    
    /* Item count is at offset 4 (word) */
    movew   4(%a0), %d0
    rts

.global get_menu_title
get_menu_title:
    /* Get menu definition from table */
    lsll    #2, %d0              /* Multiply menu ID by 4 for long offset */
    lea     menu_table, %a0
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get menu definition pointer */
    
    /* Title pointer is at offset 0 */
    movel   (%a0), %a0
    rts

.global get_menu_entry_type
get_menu_entry_type:
    /* Get menu definition */
    movel   %d1, -(%sp)           /* Save item index */
    lsll    #2, %d0               /* Multiply menu ID by 4 for long offset */
    lea     menu_table, %a0
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get menu definition pointer */
    
    /* Get item array pointer */
    movel   8(%a0), %a0          /* Item array pointer at offset 8 */
    
    /* Navigate to specific item (each item is 8 bytes) */
    movel   (%sp)+, %d1          /* Restore item index */
    lsll    #3, %d1              /* Multiply by 8 for item offset */
    addl    %d1, %a0
    
    /* Item type is at offset 4 (byte) */
    moveb   4(%a0), %d0
    rts

.global get_menu_target_id
get_menu_target_id:
    /* Get menu definition */
    movel   %d1, -(%sp)           /* Save item index */
    lsll    #2, %d0               /* Multiply menu ID by 4 for long offset */
    lea     menu_table, %a0
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get menu definition pointer */
    
    /* Get item array pointer */
    movel   8(%a0), %a0          /* Item array pointer at offset 8 */
    
    /* Navigate to specific item (each item is 8 bytes) */
    movel   (%sp)+, %d1          /* Restore item index */
    lsll    #3, %d1              /* Multiply by 8 for item offset */
    addl    %d1, %a0
    
    /* Target menu ID is at offset 6 (word) */
    movew   6(%a0), %d0
    rts

.global get_content_pointer
get_content_pointer:
    /* Calculate index into content_text_ptrs table */
    movel   %d1, -(%sp)           /* Save item index */
    
    /* Menu ID * 16 + item index = array index */
    lsll    #4, %d0               /* Multiply menu ID by 16 */
    movel   (%sp)+, %d1           /* Restore item index */
    addl    %d1, %d0              /* Add item index */
    
    /* Get pointer from table */
    lsll    #2, %d0               /* Multiply by 4 for long offset */
    lea     content_text_ptrs, %a0
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get content pointer */
    
    rts

.global get_menu_item_text
get_menu_item_text:
    /* Get menu definition */
    movel   %d1, -(%sp)           /* Save item index */
    lsll    #2, %d0               /* Multiply menu ID by 4 for long offset */
    lea     menu_table, %a0
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get menu definition pointer */
    
    /* Get item array pointer */
    movel   8(%a0), %a0          /* Item array pointer at offset 8 */
    
    /* Navigate to specific item (each item is 8 bytes) */
    movel   (%sp)+, %d1          /* Restore item index */
    lsll    #3, %d1              /* Multiply by 8 for item offset */
    addl    %d1, %a0
    
    /* Item text pointer is at offset 0 */
    movel   (%a0), %a0
    rts 