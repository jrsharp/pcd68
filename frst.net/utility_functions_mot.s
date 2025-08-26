








	xref	menu_table
	xref	content_table
	xref	current_menu_id
	xref	current_selection
	xref	view_state
	xref	header_title
	xref	version_text
	xref	version_text_length
	xref	status_text
	xref	selection_text
	xref	footer_commands




	xdef	print_string
print_string:
    
    move.l   a5,-(sp)
    
    
print_loop:
    move.b   (a5)+,d0
    beq	    print_done
    
    
    move.b   d0,(a2)+
    
    bra	    print_loop
    
print_done:
    
    move.l   (sp)+,a5
    rts

; Print a null-terminated string pointed to by A5 at the current position in A2,
; without advancing to next line - WITH BOUNDS CHECKING 
	xdef	print_string_no_advance
print_string_no_advance:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    move.l   #TDA_TEXT_END,d1
    
    
print_no_advance_loop:
    move.b   (a5)+,d0
    beq	    print_no_advance_done
    
    
    cmp.l    d1,a2
    bge	    print_no_advance_done  
    
    
    move.b   d0,(a2)+
    
    bra	    print_no_advance_loop
    
print_no_advance_done:
    
    movem.l (sp)+,d0-d7/a0-a6
    rts


	xdef	clear_header_area
clear_header_area:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    move.l   #1,d7             
clear_header_area_line_loop:
    cmp.l    #2,d7            
    bge	    clear_header_area_done
    
    
    muls    #ScreenWidth,d7
    lea     TDA_TEXT_BASE,a0
    add.l    d7,a0
    move.l  a0,a2
    
    
    move.l   #0,d6             
clear_header_area_char_loop:
    cmp.l    #ScreenWidth,d6   
    bge	    clear_header_area_next_line
    
    
    move.b   #' ',(a2)+
    
    add.l    #1,d6
    bra	    clear_header_area_char_loop
    
clear_header_area_next_line:
    
    divs    #ScreenWidth,d7
    
    add.l    #1,d7
    bra	    clear_header_area_line_loop
    
clear_header_area_done:
    
    move.l  #TDA_LINE1,a2
    
    
    movem.l (sp)+,d0-d7/a0-a6
    rts


	xdef	clear_content_area
clear_content_area:
    
    move.l   #3,d7             
clear_area_line_loop:
    cmp.l    #18,d7            
    bge	    clear_area_done
    
    
    muls    #ScreenWidth,d7
    lea     TDA_TEXT_BASE,a0
    add.l    d7,a0
    move.l  a0,a2
    
    
    move.l   #0,d6             
clear_area_char_loop:
    cmp.l    #ScreenWidth,d6   
    bge	    clear_area_next_line
    
    
    move.b   #' ',(a2)+
    
    add.l    #1,d6
    bra	    clear_area_char_loop
    
clear_area_next_line:
    
    divs    #ScreenWidth,d7
    
    add.l    #1,d7
    bra	    clear_area_line_loop
    
clear_area_done:
    
    move.l  #TDA_LINE3,a2
    rts


	xdef	clear_screen
clear_screen:
    
    move.l  #TDA_TEXT_BASE,a2
    
    
    move.l   #0,d7             
clear_screen_line_loop:
    cmp.l    #ScreenHeight,d7
    bge	    clear_screen_done
    
    move.l   #0,d6             
clear_screen_char_loop:
    cmp.l    #ScreenWidth,d6
    bge	    clear_screen_next_line
    
    
    move.b   #' ',(a2)+
    
    add.l    #1,d6
    bra	    clear_screen_char_loop
    
clear_screen_next_line:
    add.l    #1,d7
    bra	    clear_screen_line_loop
    
clear_screen_done:
    rts


	xdef	draw_borders
draw_borders:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    move.l  #TDA_TEXT_BASE,a2
    
    
    move.b   #'+',(a2)+
    move.l   #1,d0
top_border_loop:
    cmp.l    #SCREENWIDTH_MINUS1,d0
    bge	    top_border_end
    move.b   #'-',(a2)+
    add.l    #1,d0
    bra	    top_border_loop
top_border_end:
    move.b   #'+',(a2)+
    
    
    move.l   #2,d0
    muls    #ScreenWidth,d0
    lea     TDA_TEXT_BASE,a0
    add.l    d0,a0
    move.l  a0,a2
    
    
    move.b   #39,(a2)+
    move.l   #1,d0
header_border_loop:
    cmp.l    #SCREENWIDTH_MINUS1,d0
    bge	    header_border_end
    move.b   #'-',(a2)+
    add.l    #1,d0
    bra	    header_border_loop
header_border_end:
    move.b   #39,(a2)+
    
    
    move.l   #18,d0
    muls    #ScreenWidth,d0
    lea     TDA_TEXT_BASE,a0
    add.l    d0,a0
    move.l  a0,a2
    
    
    move.b   #'.',(a2)+
    move.l   #1,d0
content_border_loop:
    cmp.l    #SCREENWIDTH_MINUS1,d0
    bge	    content_border_end
    move.b   #'-',(a2)+
    add.l    #1,d0
    bra	    content_border_loop
content_border_end:
    move.b   #'.',(a2)+
    
    
    move.l   #20,d0
    muls    #ScreenWidth,d0
    lea     TDA_TEXT_BASE,a0
    add.l    d0,a0
    move.l  a0,a2
    
    
    move.b   #'+',(a2)+
    move.l   #1,d0
status_border_loop:
    cmp.l    #SCREENWIDTH_MINUS1,d0
    bge	    status_border_end
    move.b   #'-',(a2)+
    add.l    #1,d0
    bra	    status_border_loop
status_border_end:
    move.b   #'+',(a2)+
    
    
    move.l   #22,d0
    muls    #ScreenWidth,d0
    lea     TDA_TEXT_BASE,a0
    add.l    d0,a0
    move.l  a0,a2
    
    
    move.b   #'+',(a2)+
    move.l   #1,d0
bottom_border_loop:
    cmp.l    #SCREENWIDTH_MINUS1,d0
    bge	    bottom_border_end
    move.b   #'-',(a2)+
    add.l    #1,d0
    bra	    bottom_border_loop
bottom_border_end:
    move.b   #'+',(a2)+
    
    
    movem.l (sp)+,d0-d7/a0-a6
    rts


	xdef	center_text
center_text:
    
    move.l   a2,-(sp)
    move.l   d0,-(sp)
    move.l   d1,-(sp)
    move.l   d2,-(sp)
    
    
    move.l  a5,a0
    move.l   #0,d0             
center_length_loop:
    move.b   (a0)+,d1
    cmp.b    #0,d1             
    beq	    center_length_done
    add.l    #1,d0
    bra	    center_length_loop
    
center_length_done:
    
    move.l   #ScreenWidth,d1
    sub.l    #2,d1             
    sub.l    d0,d1            
    divs    #2,d1             
    
    
    move.l   #0,d2
center_padding_loop:
    cmp.l    d1,d2
    bge	    center_padding_done
    move.b   #' ',(a2)+
    add.l    #1,d2
    bra	    center_padding_loop
    
center_padding_done:
    
    jsr	    print_string_no_advance
    
    
    move.l   (sp)+,d2
    move.l   (sp)+,d1
    move.l   (sp)+,d0
    move.l   (sp)+,a2
    rts


	xdef	draw_header
draw_header:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    jsr	    draw_borders
    
    
    move.l  #TDA_HEADER,a2
    
    
    move.b   #'|',(a2)+
    move.b   #' ',(a2)+
    
    
    lea     header_title,a5
    jsr	    print_string_no_advance
    
    
    move.l  #TDA_HEADER_55,a2
    
    
    lea     version_text,a5
    jsr	    print_string_no_advance
    
    
    move.l  #TDA_HEADER_END,a2
    move.b   #'|',(a2)
    
    
    movem.l (sp)+,d0-d7/a0-a6
    rts


	xdef	draw_footer
draw_footer:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    move.l   #19,d0
    muls    #ScreenWidth,d0
    lea     TDA_TEXT_BASE,a0
    add.l    d0,a0
    move.l  a0,a2
    
    
    move.b   #'|',(a2)+
    move.b   #' ',(a2)+
    
    
    lea     status_text,a5
    jsr	    print_string_no_advance
    
    
    move.w   current_menu_id,d0
    jsr	    get_menu_title
    move.l  a0,a5
    jsr	    print_string_no_advance
    
    
    
    move.l   a2,d3
    sub.l    #TDA_STATUS,d3
    cmp.l    #20,d3
    bge	    debug_info_start
    
    
    move.l   #20,d4
    sub.l    d3,d4  
debug_pad_loop:
    cmp.l    #0,d4
    ble	    debug_info_start
    move.b   #' ',(a2)+
    sub.l    #1,d4
    bra	    debug_pad_loop
    
debug_info_start:
    
    move.b   #'|',(a2)+
    move.b   #' ',(a2)+
    
    
    move.b   #'V',(a2)+
    move.b   #':',(a2)+
    move.w   view_state,d0
    addi.b  #'0',d0
    move.b   d0,(a2)+
    move.b   #' ',(a2)+
    
    
    move.l   #68,d0               ; ScreenWidth - 12 = 80 - 12
    
    move.l   a2,d3
    sub.l    #TDA_STATUS,d3
    
    sub.l    d3,d0
    
    
    move.l  #TDA_STATUS,a2
    add.l    d0,a2
    
    
    lea     selection_text,a5
    jsr	    print_string_no_advance
    
    
    move.b   current_selection,d0
    addi.b  #'1',d0
    move.b   d0,(a2)+
    
    
    move.l  #TDA_STATUS_END,a2
    move.b   #'|',(a2)
    
    
    move.l   #21,d0
    muls    #ScreenWidth,d0
    lea     TDA_TEXT_BASE,a0
    add.l    d0,a0
    move.l  a0,a2
    
    
    move.b   #'|',(a2)+
    move.b   #' ',(a2)+
    
    
    lea     footer_commands,a5
    jsr	    print_string_no_advance
    
    
    move.l  #TDA_FOOTER_END,a2
    move.b   #'|',(a2)
    
    
    movem.l (sp)+,d0-d7/a0-a6
    rts


	xdef	get_menu_item_count
get_menu_item_count:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    move.l  #TDA_STATUS_30,a1
    move.b   #'T',(a1)+
    move.b   #':',(a1)+
    
    lea     menu_table,a0
    
    cmp.l    #0,a0
    beq	    menu_table_null
    
    
    move.l   (a0),d1           
    cmp.l    #0,d1
    beq	    menu_def_null
    
    move.b   #'O',(a1)+         
    bra	    menu_table_ok
    
menu_table_null:
    move.b   #'N',(a1)+         
    bra	    menu_table_restore
    
menu_def_null:
    move.b   #'D',(a1)+         
    bra	    menu_table_restore
    
menu_table_ok:
    move.b   #'G',(a1)+         

menu_table_restore:
    
    
    
    lsl.l   #2,d0              
    lea     menu_table,a0
    add.l    d0,a0
    move.l   (a0),a0           
    
    
    cmp.l    #0,a0
    beq	    return_zero_count
    
    
    move.w   4(a0),d0
    
    
    move.l   d0,-(sp)          
    move.l   d1,-(sp)          
    
    move.l  #TDA_STATUS_50,a1
    move.b   #'c',(a1)+         
    move.b   d0,d1
    addi.b  #'0',d1
    move.b   d1,(a1)+
    
    move.l   (sp)+,d1          
    move.l   (sp)+,d0          
    
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

return_zero_count:
    
    move.l   #0,d0
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

	xdef	get_menu_title
	align	2
get_menu_title:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    lsl.l   #2,d0              
    lea     menu_table,a0
    
    
    cmp.l    #0,a0
    beq	    get_menu_title_error_table
    
    add.l    d0,a0
    move.l   (a0),a0           
    
    
    cmp.l    #0,a0
    beq	    get_menu_title_error_def
    
    
    move.l   (a0),a0
    
    
    cmp.l    #0,a0
    beq	    get_menu_title_error_title
    
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

	align	2
get_menu_title_error_table:
    
    lea     menu_title_error_table,a0
    
    movem.l (sp)+,d0-d7/a0-a6
    rts
    
	align	2
get_menu_title_error_def:
    
    lea     menu_title_error_def,a0
    
    movem.l (sp)+,d0-d7/a0-a6
    rts
    
	align	2
get_menu_title_error_title:
    
    lea     menu_title_error_title,a0
    
    movem.l (sp)+,d0-d7/a0-a6
    rts
    
	align	2
menu_title_error_table:
        dc.b "ERROR: Menu table	pointer is null",0
    
	align	2
menu_title_error_def:
        dc.b "ERROR: Menu definition pointer is null",0
    
	align	2
menu_title_error_title:
        dc.b "ERROR: Menu title pointer is null",0

	xdef	get_menu_entry_type
	align	2
get_menu_entry_type:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    lsl.l   #2,d0               
    lea     menu_table,a0
    add.l    d0,a0
    move.l   (a0),a0           
    
    
    move.l   8(a0),a0          
    
    
    move.l   a0,-(sp)          
    move.l   d1,-(sp)          
    
    move.l  #TDA_STATUS_52,a1
    move.b   #'@',(a1)+
    
    
    move.b   4(a0),d1
    addi.b  #'0',d1
    move.b   d1,(a1)+
    
    move.l   (sp)+,d1          
    move.l   (sp)+,a0          
    
    
    clr.l    d0                  
    move.b   4(a0),d0          
    
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

	xdef	get_menu_target_id
	align	2
get_menu_target_id:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    lsl.l   #2,d0               
    lea     menu_table,a0
    add.l    d0,a0
    move.l   (a0),a0           
    
    
    move.l   8(a0),a0          
    
    
    move.l   a0,d5
    move.l  #TDA_STATUS_54,a2
    move.b   #'G',(a2)+
    move.b   #':',(a2)+
    
    
    move.b   4(a0),d7
    addi.b  #'0',d7
    move.b   d7,(a2)+
    
    
    
    move.b   #'>',(a2)+
    move.w   6(a0),d7
    addi.b  #'0',d7
    move.b   d7,(a2)+
    
    
    
    move.w   6(a0),d0
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

	xdef	get_content_pointer
	align	2
get_content_pointer:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    
    
    
    
    lsl.l   #2,d0               
    lea     content_table,a0
    add.l    d0,a0
    move.l   (a0),a0           
    
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

	xdef	get_menu_item_content_id
	align	2
get_menu_item_content_id:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    
    
    
    
    lsl.l   #2,d0               
    lea     menu_table,a0
    add.l    d0,a0
    move.l   (a0),a0           
    
    
    move.l   8(a0),a0          
    
    
    lsl.l   #2,d1              
    add.l    d1,a0             
    move.l   (a0),a0           
    
    
    clr.l    d0                  
    move.w   6(a0),d0          
    
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

	xdef	get_menu_item_text
	align	2
get_menu_item_text:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    move.l   d0,-(sp)
    move.l   #'I',d0
    jsr	    add_debug_trace
    move.l   (sp)+,d0
    
    
    move.l   d1,-(sp)           
    lsl.l   #2,d0               
    lea     menu_table,a0
    add.l    d0,a0
    move.l   (a0),a0           
    
    
    cmp.l    #0,a0
    bne	    menu_def_ok
    move.l   d0,-(sp)
    move.l   #'M',d0
    jsr	    add_debug_trace
    move.l   (sp)+,d0
    bra	    get_menu_item_error_menu_def
    
menu_def_ok:
    
    move.l   d0,-(sp)
    move.l   #'D',d0
    jsr	    add_debug_trace
    move.l   (sp)+,d0
    
    
    move.l   8(a0),a0          
    
    
    cmp.l    #0,a0
    bne	    array_ok
    move.l   d0,-(sp)
    move.l   #'A',d0
    jsr	    add_debug_trace
    move.l   (sp)+,d0
    bra	    get_menu_item_error_array
    
array_ok:
    
    move.l   d0,-(sp)
    move.l   #'R',d0           
    jsr	    add_debug_trace
    move.l   (sp)+,d0
    
    
    move.l   (sp)+,d1          
    lsl.l   #2,d1              
    add.l    d1,a0             
    move.l   (a0),a0           
    
    
    cmp.l    #0,a0
    bne	    item_ok
    move.l   d0,-(sp)
    move.l   #'P',d0
    jsr	    add_debug_trace
    move.l   (sp)+,d0
    bra	    get_menu_item_error_item
    
item_ok:
    
    move.l   d0,-(sp)
    move.l   #'L',d0           
    jsr	    add_debug_trace
    move.l   (sp)+,d0
    
    
    move.l   (a0),a0
    
    
    cmp.l    #0,a0
    bne	    text_ok
    move.l   d0,-(sp)
    move.l   #'T',d0
    jsr	    add_debug_trace
    move.l   (sp)+,d0
    bra	    get_menu_item_error_text
    
text_ok:
    
    move.l   d0,-(sp)
    move.l   #'O',d0
    jsr	    add_debug_trace
    move.l   (sp)+,d0
    
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

	align	2
get_menu_item_error_menu_def:
    
    lea     menu_item_error_menu_def,a0
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

	align	2
get_menu_item_error_array:
    
    lea     menu_item_error_array,a0
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

	align	2
get_menu_item_error_item:
    
    lea     menu_item_error_item,a0
    
    movem.l (sp)+,d0-d7/a0-a6
    rts
    
	align	2
get_menu_item_error_text:
    
    lea     menu_item_error_text,a0
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

	align	2
menu_item_error_array:
        dc.b "ERROR: Menu item array pointer is null",0
    
	align	2
menu_item_error_item:
        dc.b "ERROR: Menu item pointer is null",0
    
	align	2
menu_item_error_text:
        dc.b "ERROR: Menu item text pointer is null",0
    
	align	2
menu_item_error_menu_def:
        dc.b "ERROR: Menu definition is null",0


	align	2
	xdef	print_multiline_string
print_multiline_string:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    move.l  a2,a0
    suba.l  #TDA_TEXT_BASE,a0    
    move.l   a0,d3             
    divu    #ScreenWidth,d3    
    move.w   d3,d1             
    
    
    move.l  a2,a0
    suba.l  #TDA_TEXT_BASE,a0    
    move.l   a0,d2             
    divu    #ScreenWidth,d2    
    swap    d2                  
    
	align	2
print_multi_loop:
    move.b   (a5)+,d0
    beq	    print_multi_done
    
    
    cmp.b    #10,d0             
    beq	    handle_newline
    
    
    cmp.w    #17,d1             
    bge	    print_multi_done
    
    
    move.b   d0,(a2)+
    add.w    #1,d2              
    
    
    cmp.w    #ScreenWidth,d2
    blt	    print_multi_loop
    
    
    add.w    #1,d1              
    move.w   #0,d2              
    
    
    move.w   d1,d3
    mulu    #ScreenWidth,d3
    movea.l #TDA_TEXT_BASE,a2
    add.l    d3,a2
    
    bra	    print_multi_loop
    
	align	2
handle_newline:
    
    add.w    #1,d1              
    move.w   #0,d2              
    
    
    move.w   d1,d3
    mulu    #ScreenWidth,d3
    movea.l #TDA_TEXT_BASE,a2
    add.l    d3,a2
    
    bra	    print_multi_loop
    
	align	2
print_multi_done:
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

	xdef	get_menu_content
	align	2
get_menu_content:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    lsl.l   #2,d0              
    lea     menu_table,a0
    add.l    d0,a0
    move.l   (a0),a0           
    
    
    cmp.l    #0,a0
    beq	    return_null_content
    
    
    move.l   12(a0),a0
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

return_null_content:
    
    move.l   #0,a0
    
    movem.l (sp)+,d0-d7/a0-a6
    rts 



	xdef	add_debug_trace
add_debug_trace:
    
    movem.l d0-d7/a0-a6,-(sp)
    
    
    move.l  #TDA_STATUS_55,a2
    
    
    move.l   #0,d1
find_trace_slot:
    cmp.l    #10,d1           
    bge	    trace_slot_found
    cmp.b    #' ',(a2)
    beq	    trace_slot_found
    add.l    #1,a2
    add.l    #1,d1
    bra	    find_trace_slot
    
trace_slot_found:
    
    move.b   d0,(a2)
    
    
    movem.l (sp)+,d0-d7/a0-a6
    rts 
