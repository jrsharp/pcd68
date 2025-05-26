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

/* Reference the external variables from generated menu structures */
.extern menu_table
.extern content_table
.extern current_menu_id
.extern current_selection
.extern view_state
.extern header_title
.extern version_text
.extern version_text_length
.extern status_text
.extern selection_text
.extern footer_commands

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

/* Clear the header area of the screen based on updated layout */
.global clear_header_area
clear_header_area:
    /* Position at the start of header area (line 1) */
    movel   #1, %d7             /* Start at line 1 */
clear_header_area_line_loop:
    cmpl    #2, %d7            /* End at line 1 (before line 2) */
    bge     clear_header_area_done
    
    /* Position at start of this line */
    muls    #ScreenWidth, %d7
    lea     TDABase + 1, %a0
    addl    %d7, %a0
    moveal  %a0, %a2
    
    /* Clear entire line with spaces - no borders */
    movel   #0, %d6             /* Start at beginning of line */
clear_header_area_char_loop:
    cmpl    #ScreenWidth, %d6   /* Fill entire line */
    bge     clear_header_area_next_line
    
    /* Write space to clear area */
    moveb   #' ', (%a2)+
    
    addl    #1, %d6
    bra     clear_header_area_char_loop
    
clear_header_area_next_line:
    /* Convert line position back from offset */
    divs    #ScreenWidth, %d7
    
    addl    #1, %d7
    bra     clear_header_area_line_loop
    
clear_header_area_done:
    /* Reset cursor position to start of header area */
    moveal  #TDABase + 1 + (80 * 1), %a2
    rts

/* Clear the content area of the screen based on updated layout */
.global clear_content_area
clear_content_area:
    /* Position at the start of content area (line 3) */
    movel   #3, %d7             /* Start at line 3 */
clear_area_line_loop:
    cmpl    #18, %d7            /* End at line 17 (before line 18) */
    bge     clear_area_done
    
    /* Position at start of this line */
    muls    #ScreenWidth, %d7
    lea     TDABase + 1, %a0
    addl    %d7, %a0
    moveal  %a0, %a2
    
    /* Clear entire line with spaces - no borders */
    movel   #0, %d6             /* Start at beginning of line */
clear_area_char_loop:
    cmpl    #ScreenWidth, %d6   /* Fill entire line */
    bge     clear_area_next_line
    
    /* Write space to clear area */
    moveb   #' ', (%a2)+
    
    addl    #1, %d6
    bra     clear_area_char_loop
    
clear_area_next_line:
    /* Convert line position back from offset */
    divs    #ScreenWidth, %d7
    
    addl    #1, %d7
    bra     clear_area_line_loop
    
clear_area_done:
    /* Reset cursor position to start of content area */
    moveal  #TDABase + 1 + (80 * 3), %a2
    rts

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
/* clear_content_area function moved to pcd68home.S */    
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
    
    /* Draw border after header area (line 2) */
    movel   #2, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw border line */
    moveb   #'\'', (%a2)+
    movel   #1, %d0
header_border_loop:
    cmpl    #ScreenWidth - 1, %d0
    bge     header_border_end
    moveb   #'-', (%a2)+
    addl    #1, %d0
    bra     header_border_loop
header_border_end:
    moveb   #'\'', (%a2)+
    
    /* Draw border after content area (line 18) */
    movel   #18, %d0
    muls    #ScreenWidth, %d0
    lea     TDABase + 1, %a0
    addl    %d0, %a0
    moveal  %a0, %a2
    
    /* Draw border line */
    moveb   #'.', (%a2)+
    movel   #1, %d0
content_border_loop:
    cmpl    #ScreenWidth - 1, %d0
    bge     content_border_end
    moveb   #'-', (%a2)+
    addl    #1, %d0
    bra     content_border_loop
content_border_end:
    moveb   #'.', (%a2)+
    
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
    
    /* Position cursor for version */
    moveal  #TDABase + 1 + ScreenWidth + 55, %a2
    
    /* Draw version text */
    lea     version_text, %a5
    jsr     print_string_no_advance
    
    /* Close header line with right border */
    moveal  #TDABase + 1 + ScreenWidth + ScreenWidth - 1, %a2
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
    /* Debug: Check menu_table validity first */
    movel   %d0, -(%sp)          /* Save menu ID */
    movel   %d1, -(%sp)          /* Save d1 */
    
    /* Show menu_table address */
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 30, %a1
    moveb   #'T', (%a1)+
    moveb   #':', (%a1)+
    
    lea     menu_table, %a0
    /* Check if menu_table address is reasonable */
    cmpl    #0, %a0
    beq     menu_table_null
    
    /* Show first entry of menu_table */
    movel   (%a0), %d1           /* Get first menu definition pointer */
    cmpl    #0, %d1
    beq     menu_def_null
    
    moveb   #'O', (%a1)+         /* O = OK, menu_table looks good */
    bra     menu_table_ok
    
menu_table_null:
    moveb   #'N', (%a1)+         /* N = menu_table is null */
    bra     menu_table_restore
    
menu_def_null:
    moveb   #'D', (%a1)+         /* D = menu definition is null */
    bra     menu_table_restore
    
menu_table_ok:
    moveb   #'G', (%a1)+         /* G = Good, continue processing */

menu_table_restore:
    movel   (%sp)+, %d1          /* Restore d1 */
    movel   (%sp)+, %d0          /* Restore menu ID */

    /* Get menu definition from table */
    lsll    #2, %d0              /* Multiply menu ID by 4 for long offset */
    lea     menu_table, %a0
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get menu definition pointer */
    
    /* Check if menu definition is null before using it */
    cmpl    #0, %a0
    beq     return_zero_count
    
    /* Item count is at offset 4 (word) */
    movew   4(%a0), %d0
    
    /* Debug: Show the count we're returning */
    movel   %d0, -(%sp)          /* Save count */
    movel   %d1, -(%sp)          /* Save d1 */
    
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 50, %a1
    moveb   #'c', (%a1)+         /* lowercase c to distinguish from other debug */
    moveb   %d0, %d1
    addib   #'0', %d1
    moveb   %d1, (%a1)+
    
    movel   (%sp)+, %d1          /* Restore d1 */
    movel   (%sp)+, %d0          /* Restore count */
    
    rts

return_zero_count:
    /* Return 0 if menu definition is null */
    movel   #0, %d0
    rts

.global get_menu_title
.align 2
get_menu_title:
    /* Get menu definition from table */
    lsll    #2, %d0              /* Multiply menu ID by 4 for long offset */
    lea     menu_table, %a0
    
    /* Check if menu_table is valid */
    cmpl    #0, %a0
    beq     get_menu_title_error_table
    
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get menu definition pointer */
    
    /* Check if menu definition is valid */
    cmpl    #0, %a0
    beq     get_menu_title_error_def
    
    /* Title pointer is at offset 0 */
    movel   (%a0), %a0
    
    /* Check if title pointer is valid */
    cmpl    #0, %a0
    beq     get_menu_title_error_title
    
    rts

.align 2
get_menu_title_error_table:
    /* Return error message */
    lea     menu_title_error_table, %a0
    rts
    
.align 2
get_menu_title_error_def:
    /* Return error message */
    lea     menu_title_error_def, %a0
    rts
    
.align 2
get_menu_title_error_title:
    /* Return error message */
    lea     menu_title_error_title, %a0
    rts
    
.align 2
menu_title_error_table:
    .asciz "ERROR: Menu table pointer is null"
    
.align 2
menu_title_error_def:
    .asciz "ERROR: Menu definition pointer is null"
    
.align 2
menu_title_error_title:
    .asciz "ERROR: Menu title pointer is null"

.global get_menu_entry_type
.align 2
get_menu_entry_type:
    /* Get menu definition */
    movel   %d1, -(%sp)           /* Save item index */
    lsll    #2, %d0               /* Multiply menu ID by 4 for long offset */
    lea     menu_table, %a0
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get menu definition pointer */
    
    /* Get item array pointer */
    movel   8(%a0), %a0          /* Item array pointer at offset 8 */
    
    /* Debug: Show what we found at the item structure address */
    movel   %a0, -(%sp)          /* Save item structure pointer */
    movel   %d1, -(%sp)          /* Save registers we'll modify */
    
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 52, %a1
    moveb   #'@', (%a1)+
    
    /* Show the type byte value we're about to return */
    moveb   4(%a0), %d1
    addib   #'0', %d1
    moveb   %d1, (%a1)+
    
    movel   (%sp)+, %d1          /* Restore registers */
    movel   (%sp)+, %a0          /* Restore item structure pointer */
    
    /* Return the type byte at offset 4 */
    clrl    %d0                  /* Clear upper bits */
    moveb   4(%a0), %d0          /* Get type byte and zero-extend */
    
    rts

.global get_menu_target_id
.align 2
get_menu_target_id:
    /* Get menu definition */
    movel   %d1, -(%sp)           /* Save item index */
    lsll    #2, %d0               /* Multiply menu ID by 4 for long offset */
    lea     menu_table, %a0
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get menu definition pointer */
    
    /* Get item array pointer */
    movel   8(%a0), %a0          /* Item array pointer at offset 8 */
    
    /* Debug - show address and offsets */
    movel   %a0, %d5
    moveal  #TDABase + 1 + (19 * ScreenWidth) + 54, %a2
    moveb   #'G', (%a2)+
    moveb   #':', (%a2)+
    
    /* Display the item type byte */
    moveb   4(%a0), %d7
    addib   #'0', %d7
    moveb   %d7, (%a2)+
    
    /* Display target ID */
    /* Disabled for now - might become relevant again when we introduce cursor movement */
    moveb   #'>', (%a2)+
    movew   6(%a0), %d7
    addib   #'0', %d7
    moveb   %d7, (%a2)+
    */
    
    /* Target menu ID is at offset 6 (word) */
    movew   6(%a0), %d0
    rts

.global get_content_pointer
.align 2
get_content_pointer:
    /* Direct lookup in content_table using content ID */
    /* Input: %d0 = content ID */
    /* Output: %a0 = content pointer */
    
    /* Get pointer from content_table[content_id] */
    lsll    #2, %d0               /* Multiply by 4 for long offset */
    lea     content_table, %a0
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get content pointer */
    
    rts

.global get_menu_item_content_id
.align 2
get_menu_item_content_id:
    /* Get content ID from menu item */
    /* Input: %d0 = menu ID, %d1 = item index */
    /* Output: %d0 = content ID */
    
    /* Save registers */
    movel   %a0, -(%sp)
    
    /* Get menu definition */
    lsll    #2, %d0               /* Multiply menu ID by 4 for long offset */
    lea     menu_table, %a0
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get menu definition pointer */
    
    /* Get item array pointer */
    movel   8(%a0), %a0          /* Item array pointer at offset 8 */
    
    /* Navigate to specific item */
    lsll    #2, %d1              /* Multiply by 4 for long word offset */
    addl    %d1, %a0             /* Get pointer to item pointer */
    movel   (%a0), %a0           /* Dereference to get item structure */
    
    /* Content ID is at offset 6 in the new structure */
    clrl    %d0                  /* Clear upper bits */
    movew   6(%a0), %d0          /* Get content ID (word) and zero-extend */
    
    /* Restore registers */
    movel   (%sp)+, %a0
    rts

.global get_menu_item_text
.align 2
get_menu_item_text:
    /* Save additional registers for debugging */
    movel   %d2, -(%sp)
    movel   %d3, -(%sp)
    movel   %a1, -(%sp)
    
    /* Debug: Add trace character for function entry */
    movel   %d0, -(%sp)
    movel   #'I', %d0
    jsr     add_debug_trace
    movel   (%sp)+, %d0
    
    /* Get menu definition */
    movel   %d1, -(%sp)           /* Save item index */
    lsll    #2, %d0               /* Multiply menu ID by 4 for long offset */
    lea     menu_table, %a0
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get menu definition pointer */
    
    /* Debug: Check if menu definition is null */
    cmpl    #0, %a0
    bne     menu_def_ok
    movel   %d0, -(%sp)
    movel   #'M', %d0
    jsr     add_debug_trace
    movel   (%sp)+, %d0
    bra     get_menu_item_error_menu_def
    
menu_def_ok:
    /* Debug: Show menu definition OK */
    movel   %d0, -(%sp)
    movel   #'D', %d0
    jsr     add_debug_trace
    movel   (%sp)+, %d0
    
    /* Get item array pointer */
    movel   8(%a0), %a0          /* Item array pointer at offset 8 */
    
    /* Debug: Check if array pointer is null */
    cmpl    #0, %a0
    bne     array_ok
    movel   %d0, -(%sp)
    movel   #'A', %d0
    jsr     add_debug_trace
    movel   (%sp)+, %d0
    bra     get_menu_item_error_array
    
array_ok:
    /* Debug: Show array OK */
    movel   %d0, -(%sp)
    movel   #'R', %d0           /* R = aRray OK */
    jsr     add_debug_trace
    movel   (%sp)+, %d0
    
    /* Navigate to specific item - our array contains pointers to items */
    movel   (%sp)+, %d1          /* Restore item index */
    lsll    #2, %d1              /* Multiply by 4 for long word offset */
    addl    %d1, %a0             /* Get pointer to item pointer */
    movel   (%a0), %a0           /* Dereference to get item structure */
    
    /* Debug: Check if item pointer is null */
    cmpl    #0, %a0
    bne     item_ok
    movel   %d0, -(%sp)
    movel   #'P', %d0
    jsr     add_debug_trace
    movel   (%sp)+, %d0
    bra     get_menu_item_error_item
    
item_ok:
    /* Debug: Show item OK */
    movel   %d0, -(%sp)
    movel   #'L', %d0           /* L = item Link OK */
    jsr     add_debug_trace
    movel   (%sp)+, %d0
    
    /* Item text pointer is at offset 0 in the simplified structure */
    movel   (%a0), %a0
    
    /* Debug: Check if text pointer is null */
    cmpl    #0, %a0
    bne     text_ok
    movel   %d0, -(%sp)
    movel   #'T', %d0
    jsr     add_debug_trace
    movel   (%sp)+, %d0
    bra     get_menu_item_error_text
    
text_ok:
    /* Debug: Success */
    movel   %d0, -(%sp)
    movel   #'O', %d0
    jsr     add_debug_trace
    movel   (%sp)+, %d0
    
    /* Restore debug registers */
    movel   (%sp)+, %a1
    movel   (%sp)+, %d3
    movel   (%sp)+, %d2
    rts

.align 2
get_menu_item_error_menu_def:
    /* Return error message */
    lea     menu_item_error_menu_def, %a0
    /* Restore debug registers */
    movel   (%sp)+, %a1
    movel   (%sp)+, %d3
    movel   (%sp)+, %d2
    rts

.align 2
get_menu_item_error_array:
    /* Return error message */
    lea     menu_item_error_array, %a0
    /* Restore debug registers */
    movel   (%sp)+, %a1
    movel   (%sp)+, %d3
    movel   (%sp)+, %d2
    rts

.align 2
get_menu_item_error_item:
    /* Return error message */
    lea     menu_item_error_item, %a0
    /* Restore debug registers */
    movel   (%sp)+, %a1
    movel   (%sp)+, %d3
    movel   (%sp)+, %d2
    rts
    
.align 2
get_menu_item_error_text:
    /* Return error message */
    lea     menu_item_error_text, %a0
    /* Restore debug registers */
    movel   (%sp)+, %a1
    movel   (%sp)+, %d3
    movel   (%sp)+, %d2
    rts

.align 2
menu_item_error_array:
    .asciz "ERROR: Menu item array pointer is null"
    
.align 2
menu_item_error_item:
    .asciz "ERROR: Menu item pointer is null"
    
.align 2
menu_item_error_text:
    .asciz "ERROR: Menu item text pointer is null"
    
.align 2
menu_item_error_menu_def:
    .asciz "ERROR: Menu definition is null"

/* Print a multi-line string with proper newline handling for content display */
.align 2
.global print_multiline_string
print_multiline_string:
    /* Save registers */
    movel   %a5, -(%sp)
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    movel   %d3, -(%sp)
    
    /* Store starting line position (should be line 4) */
    moveal  %a2, %a0
    subal   #TDABase + 1, %a0    /* Get offset from screen start */
    movel   %a0, %d3             /* Copy to data register for division */
    divu    #ScreenWidth, %d3    /* Get current line number */
    movew   %d3, %d1             /* Store current line in D1 */
    
    /* Store column position within line */
    moveal  %a2, %a0
    subal   #TDABase + 1, %a0    /* Get offset from screen start */
    movel   %a0, %d2             /* Copy to data register */
    divu    #ScreenWidth, %d2    /* Get line number in upper word */
    swap    %d2                  /* Get remainder (column) in lower word */
    
.align 2
print_multi_loop:
    moveb   (%a5)+, %d0
    beq     print_multi_done
    
    /* Check for newline character */
    cmpb    #10, %d0             /* ASCII 10 = \n */
    beq     handle_newline
    
    /* Check if we're still within content area bounds */
    cmpw    #17, %d1             /* Don't go past line 16 to leave room for menu items */
    bge     print_multi_done
    
    /* Normal character - write to screen */
    moveb   %d0, (%a2)+
    addw    #1, %d2              /* Increment column */
    
    /* Check for line wrap */
    cmpw    #ScreenWidth, %d2
    blt     print_multi_loop
    
    /* Line wrap - go to next line */
    addw    #1, %d1              /* Next line */
    movew   #0, %d2              /* Reset column */
    
    /* Calculate new screen position */
    movew   %d1, %d3
    mulu    #ScreenWidth, %d3
    lea     TDABase + 1, %a2
    addl    %d3, %a2
    
    bra     print_multi_loop
    
.align 2
handle_newline:
    /* Move to next line */
    addw    #1, %d1              /* Next line */
    movew   #0, %d2              /* Reset column to start */
    
    /* Calculate new screen position */
    movew   %d1, %d3
    mulu    #ScreenWidth, %d3
    lea     TDABase + 1, %a2
    addl    %d3, %a2
    
    bra     print_multi_loop
    
.align 2
print_multi_done:
    /* Restore registers */
    movel   (%sp)+, %d3
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    movel   (%sp)+, %a5
    rts

.global get_menu_content
.align 2
get_menu_content:
    /* Get menu definition from table */
    lsll    #2, %d0              /* Multiply menu ID by 4 for long offset */
    lea     menu_table, %a0
    addl    %d0, %a0
    movel   (%a0), %a0           /* Get menu definition pointer */
    
    /* Check if menu definition is null before using it */
    cmpl    #0, %a0
    beq     return_null_content
    
    /* Content pointer is at offset 12 */
    movel   12(%a0), %a0
    rts

return_null_content:
    /* Return null pointer */
    movel   #0, %a0
    rts 

/* Add debug trace to status line - call this to mark function entry */
/* Input: D0 = character to display in trace section */
.global add_debug_trace
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
    /* Write the trace character */
    moveb   %d0, (%a2)
    
    /* Restore registers */
    movel   (%sp)+, %a2
    movel   (%sp)+, %d1
    rts 
