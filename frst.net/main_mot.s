;
 * FRST.net terminal interface
 


ScrnBase	equ	$430002
TDABase	equ	$410000
KCTLBase	equ	$420000
UARTBase	equ	$450000
UART1_BASE	equ	$450000
UART1_TX	equ	UART1_BASE + $00
UART1_RX	equ	UART1_BASE + $01
UART1_STATUS	equ	UART1_BASE + $02
UART1_CONTROL	equ	UART1_BASE + $03


UART2_BASE	equ	$450000
UART2_TX	equ	UART2_BASE + $04
UART2_RX	equ	UART2_BASE + $05
UART2_STATUS	equ	UART2_BASE + $06
UART2_CONTROL	equ	UART2_BASE + $07


TDASize	equ	80 * 23


KCTLStatus	equ	$420000      
KCTLCount	equ	$420001       
KCTLReportSize	equ	$420002  
KCTLModifiers	equ	$420003   
KCTLKeys	equ	$420004        
KCTLNextReport	equ	$42000B  


STATUS_REPORT_AVAILABLE	equ	$01
STATUS_QUEUE_FULL	equ	$02
STATUS_CLEAR_INTERRUPT	equ	$04
STATUS_KEYBOARD_ENABLED	equ	$08


ScreenWidth	equ	80
ScreenHeight	equ	23
TextMode	equ	2               
GraphicsMode	equ	0           
MaxMenuItems	equ	20          
MaxContentSize	equ	1024      


PictureWidth	equ	400
PictureHeight	equ	300
PictureSize	equ	120000       


KEY_ENTER	equ	13
KEY_ESC	equ	27
KEY_BACKSPACE	equ	8
KEY_H	equ	104                
KEY_M	equ	109                
KEY_B	equ	98                 
KEY_Q	equ	113                
KEY_J	equ	106                
KEY_K	equ	107                
KEY_A	equ	97                 
KEY_C	equ	99                 
KEY_D	equ	100                
KEY_U	equ	117                
KEY_T	equ	116                
KEY_UP_ARROW	equ	16          
KEY_DOWN_ARROW	equ	17        
KEY_LEFT_ARROW	equ	18        
KEY_RIGHT_ARROW	equ	19       
KEY_QUESTION	equ	63          
KEY_0	equ	48                 
KEY_1	equ	49                 
KEY_2	equ	50                 
KEY_3	equ	51                 
KEY_4	equ	52                 
KEY_5	equ	53                 
KEY_6	equ	54                 
KEY_7	equ	55                 
KEY_8	equ	56                 
KEY_9	equ	57                 


KEY_TAB	equ	9                
KEY_SPACE	equ	32             
KEY_TILDE	equ	126            
KEY_BACKTICK	equ	96          


MOD_SHIFT	equ	$01           
MOD_CTRL	equ	$02            
MOD_ALT	equ	$04             
MOD_META	equ	$08            


MODE_CHAT	equ	0              
MODE_TERMINAL	equ	1          


EndOfStack	equ	$BFFFFF


	xdef	key_home
	xdef	key_back
	xdef	key_help
	xdef	key_quit
	xdef	finish_key_input
	xdef	navigation_stack
	xdef	navigation_stack_pos
	xdef	content_ptr
	xdef	set_display_update_flag


	org	$000000
vectors:
    dc.l    EndOfStack           
    dc.l    start                
    dc.l    default_handler      
    dc.l    default_handler      
    dc.l    default_handler      
    dc.l    default_handler      
    dc.l    default_handler      
    dc.l    default_handler      
    dc.l    default_handler      
    dc.l    default_handler      
    dc.l    $000000             
    dc.l    $000000             
    dc.l    $FAFAAA             
    dc.l    $000000             
    dc.l    default_handler      
    dc.l    default_handler      
    dc.l    $000000
    dc.l    $000000
    dc.l    $000000
    dc.l    $000000
    dc.l    $000000
    dc.l    $000000
    dc.l    $000000
    dc.l    $000000
    dc.l    $000000
    dc.l    $000000
    dc.l    $000000
    dc.l    keyboard_handler     
    dc.l    uart1_interrupt_handler  
    dc.l    uart2_interrupt_handler  
    dc.l    $000000
    dc.l    $000000
    
	rept	32
    dc.l    $000000
	endr


	section code
	org	$001000
start:
    
    move.l  #TDABase, a2
    move.b   #TextMode, (a2)+    
    
    
    jsr	    clear_screen

    
    move.l   #0, current_menu_id     
    move.l   #0, current_selection   
    move.l   #0, navigation_stack_pos 
    move.l   #0, display_needs_update 
    move.l   #0, refresh_lock        
    move.l   #0, picture_mode_active 
    move.l   #0, d6                 
    clr.l    d0
    
    
    move.l   #0, navigation_stack    
    addil   #1, navigation_stack_pos 
    
    
    jsr	    init_menu_system
    
    
    jsr	    init_scroll_system
    
    
    
    move.b   #STATUS_CLEAR_INTERRUPT, KCTLStatus
    move.b   #0, KCTLCount
    move.b   #0, KCTLReportSize
    
    
    move.b   #STATUS_KEYBOARD_ENABLED, KCTLStatus
    
    
    move.b KCTLStatus, d0
    orib    #STATUS_KEYBOARD_ENABLED, d0   
    move.b   d0, KCTLStatus
    
    
    move.l  #TDABase + 1 + (19 * ScreenWidth) + 70, a2
    move.b   KCTLStatus, d0
    lsrl    #4, d0             
    andil   #$F, d0
    addil   #'0', d0
    cmp.l    #'9', d0
    ble	    init_high_ok
    addil   #7, d0             
init_high_ok:
    move.b   d0, (a2)+
    
    move.b   KCTLStatus, d0
    andil   #$F, d0           
    addil   #'0', d0
    cmp.l    #'9', d0
    ble	    init_low_ok
    addil   #7, d0             
init_low_ok:
    move.b   d0, (a2)
    
    
    
    move    #$2000, sr         
    
    
    jsr	    draw_header          
    jsr	    draw_footer
    
    
    jsr	    clear_content_area   
    jsr	    draw_content_area

    
    move.l   #1, display_needs_update
    
    
    jsr	    draw_borders
    
    
    jsr	    draw_status
    

main_loop:
    
    cmp.l    #1, chat_mode_active
    beq	    chat_mode_loop
    
    
    cmp.l    #1, uart2_mode_active
    beq	    uart2_mode_loop
    
    
    cmp.l    #1, debug_mode_active
    beq	    debug_mode_loop
    
    
    cmp.l    #1, picture_mode_active
    beq	    art_mode_loop
    
    
    jsr	    process_text_mode
    bra	    main_loop

chat_mode_loop:
    
    move.b   KCTLCount, d0
    cmp.l    #0, d0
    beq	    chat_mode_no_input   
    
    
    jsr	    process_chat_keyboard_input
    bra	    main_loop

chat_mode_no_input:
    
    addil   #1, chat_poll_counter
    cmp.l    #1000, chat_poll_counter  
    blt	    chat_skip_poll
    
    move.l   #0, chat_poll_counter
    
    
    move.l   #0, chat_timeout_counter
    cmp.l    #10000, chat_timeout_counter  
    bge	    chat_skip_poll              
    
    
    cmp.l    #1, chat_network_disabled
    beq	    skip_aether_poll
    jsr	    aether_poll_safe           
skip_aether_poll:
    jsr	    update_chat_display_if_needed
    
chat_skip_poll:
    
    move.l   #1000, d0
chat_delay_loop:
    subil   #1, d0
    bne	    chat_delay_loop
    bra	    main_loop

uart2_mode_loop:
    
    move.b   KCTLCount, d0
    cmp.l    #0, d0
    beq	    uart2_mode_no_input   
    
    
    jsr	    process_uart2_keyboard_input
    bra	    main_loop

uart2_mode_no_input:
    
    jsr	    uart2_poll_incoming
    
    
    move.l   #1000, d0
uart2_delay_loop:
    subil   #1, d0
    bne	    uart2_delay_loop
    bra	    main_loop

debug_mode_loop:
    
    move.b   KCTLCount, d0
    cmp.l    #0, d0
    beq	    debug_mode_no_input   
    
    
    jsr	    process_debug_input
    bra	    main_loop

debug_mode_no_input:
    
    move.l   #1000, d0
debug_delay_loop:
    subil   #1, d0
    bne	    debug_delay_loop
    bra	    main_loop

art_mode_loop:
    
    move.b   KCTLCount, d0
    cmp.l    #0, d0
    beq	    main_loop              
    
    
    move.l  #KCTLKeys, a0
    move.b   (a0), d0
    
    
    cmp.b    #KEY_T, d0
    beq	    exit_art_mode
    
    
    cmp.b    #KEY_J, d0
    beq	    next_image
    
    
    cmp.b    #KEY_K, d0
    beq	    previous_image
    
    
    cmp.b    #KEY_C, d0
    beq	    process_key_chat
    
    
    move.b   #1, KCTLNextReport
    bra	    main_loop

next_image:
    
    jsr	    switch_to_next_image
    move.b   #1, KCTLNextReport     
    bra	    main_loop

previous_image:
    
    jsr	    switch_to_previous_image
    move.b   #1, KCTLNextReport     
    bra	    main_loop

exit_art_mode:
    
    jsr	    enter_text_mode
    move.b   #1, KCTLNextReport     
    bra	    main_loop


process_text_mode:
    
    move.l   #'A', d0
    jsr	    add_debug_trace
    
    
    move.l  #TDABase + 1 + (19 * ScreenWidth) + 2, a2
    
    
    move.b   main_loop_toggle, d0
    cmp.b    #'/', d0
    beq	    toggle_to_backslash
    
    move.b   #'/', d0
    move.b   d0, main_loop_toggle
    bra	    toggle_done
    
toggle_to_backslash:
    move.b   #'\\', d0
    move.b   d0, main_loop_toggle
    
toggle_done:
    move.b   d0, (a2)
    
    
    
    
    move.b   KCTLStatus, d0
    btst    #3, d0              
    bne	    keyboard_enabled_ok
    
    
    orib    #STATUS_KEYBOARD_ENABLED, d0
    move.b   d0, KCTLStatus
    
keyboard_enabled_ok:
    
    move.l   #'B', d0
    jsr	    add_debug_trace
    
    
    move.b   KCTLStatus, d0
    btst    #1, d0              
    beq	    queue_not_full
    
    
    move.l   #'Q', d0            
    jsr	    add_debug_trace
    
clear_full_queue:
    move.b   #1, KCTLNextReport   
    move.b   KCTLStatus, d0
    btst    #1, d0              
    bne	    clear_full_queue     
    
    
    move.l   #0, key_debounce_timer
    
queue_not_full:
    
    cmp.l    #0, key_debounce_timer
    beq	    debounce_expired
    
    
    subil   #1, key_debounce_timer
    
    
    move.l   key_debounce_timer, d0
    andil   #1023, d0         
    cmp.l    #0, d0
    bne	    skip_debounce_trace
    move.l   #'W', d0          
    jsr	    add_debug_trace
skip_debounce_trace:
    
    bra	    main_loop_continue

debounce_expired:
    
    move.l   #'E', d0
    jsr	    add_debug_trace
    
    
    move.b   KCTLCount, d0
    cmp.l    #0, d0
    beq	    main_loop_continue   
    
    
    move.l   #'K', d0
    jsr	    add_debug_trace
    
    
    jsr	    process_keyboard_input
    
    
    move.l   #'X', d0
    jsr	    add_debug_trace

main_loop_continue:
    
    move.l   #'L', d0
    jsr	    add_debug_trace
    
    
    cmp.l    #1, display_needs_update
    bne	    main_loop_delay      

    
    move.l   #'R', d0
    jsr	    add_debug_trace

    
    cmp.l    #1, refresh_lock
    bne	    perform_refresh      
    
    
    cmp.l    #0, d6
    beq	    main_loop_delay      

perform_refresh:
    
    move.l   #'T', d0
    jsr	    add_debug_trace
    
    
    move.l   #1, refresh_lock
    
    
    jsr	    clear_header_area

    
    jsr	    draw_header
    
    
    jsr	    clear_content_area
    
    
    jsr	    draw_content_area
    
    
    jsr	    draw_status
    
    
    jsr	    draw_footer
    
    
    jsr	    draw_borders
    
    
    move.l   #0, display_needs_update
    
    
    move.l   #10000, d0
unlock_delay_loop:
    subil   #1, d0
    bne	    unlock_delay_loop
    move.l   #0, refresh_lock     
    
main_loop_delay:
    
    move.l   #50, d0
delay_loop:
    subil   #1, d0
    bne	    delay_loop
    
    
    addil   #1, delay_counter
    cmp.l    #500, delay_counter  
    blt	    skip_counter_update
    
    
    move.l   #0, delay_counter
    addil   #1, counter_value
    
    
    move.l   delay_counter, d0
    andil   #31, d0           
    cmp.l    #0, d0
    bne	    skip_status_update
    jsr	    draw_status
skip_status_update:
    
skip_counter_update:
    rts


draw_status:
    
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    move.l   d3, -(sp)
    move.l   d4, -(sp)
    move.l   d5, -(sp)
    move.l   d6, -(sp)
    move.l   d7, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    move.l   a2, -(sp)
    
    
    cmp.l    #1, chat_mode_active
    beq	    draw_chat_status_line
    
    
    move.l   #19, d0
    muls    #ScreenWidth, d0
    lea     TDABase + 1, a0
    add.l    d0, a0
    move.l  a0, a2
    
    
    move.b   #'|', (a2)+
    move.b   #' ', (a2)+
    
    move.l   #2, d1            
clear_status_full_loop:
    cmp.l    #ScreenWidth - 1, d1  
    bge	    clear_status_full_end
    move.b   #' ', (a2)+
    add.l    #1, d1
    bra	    clear_status_full_loop
clear_status_full_end:
    
    
    move.l  a0, a2
    add.l    #2, a2            
    
    
    move.b   main_loop_toggle, (a2)+
    
    
    move.b   #'S', (a2)+
    move.b   #':', (a2)+
    move.b   KCTLStatus, d0
    lsrl    #4, d0             
    andil   #$F, d0
    addil   #'0', d0
    cmp.l    #'9', d0
    ble	    status_high_ok_new
    addil   #7, d0             
status_high_ok_new:
    move.b   d0, (a2)+
    
    move.b   KCTLStatus, d0
    andil   #$F, d0           
    addil   #'0', d0
    cmp.l    #'9', d0
    ble	    status_low_ok_new
    addil   #7, d0             
status_low_ok_new:
    move.b   d0, (a2)+
    
    move.b   #' ', (a2)+
    move.b   #'P', (a2)+
    move.b   #':', (a2)+
    move.b   KCTLCount, d1
    addib   #'0', d1
    move.b   d1, (a2)+
    
    
    move.b   #' ', (a2)+
    move.b   #'K', (a2)+
    move.b   #':', (a2)+
    
    
    move.l   d6, d1            
    lsrl    #4, d1             
    andil   #$F, d1
    addil   #'0', d1
    cmp.l    #'9', d1           
    ble	    key_high_digit_ok
    addil   #7, d1             
key_high_digit_ok:
    move.b   d1, (a2)+
    
    
    move.l   d6, d1
    andil   #$F, d1
    addil   #'0', d1
    cmp.l    #'9', d1           
    ble	    key_low_digit_ok
    addil   #7, d1             
key_low_digit_ok:
    move.b   d1, (a2)+
    
    
    move.b   #'(', (a2)+
    
    
    cmp.l    #32, d6
    blt	    key_not_printable
    cmp.l    #126, d6
    bgt	    key_not_printable
    
    
    move.b   d6, (a2)+
    bra	    key_end_char_display
    
key_not_printable:
    move.b   #'?', (a2)+
    
key_end_char_display:
    move.b   #')', (a2)+
    
    
    move.b   #' ', (a2)+
    move.b   #'V', (a2)+
    move.b   #':', (a2)+
    move.l   view_state, d0
    addib   #'0', d0
    move.b   d0, (a2)+
    
    move.b   #' ', (a2)+
    move.b   #'M', (a2)+
    move.b   #':', (a2)+
    move.l   current_menu_id, d0
    addib   #'0', d0
    move.b   d0, (a2)+
    
    move.b   #' ', (a2)+
    move.b   #'S', (a2)+
    move.b   #':', (a2)+
    move.l   current_selection, d0
    addib   #'0', d0
    move.b   d0, (a2)+
    
    
    
    
    
    move.l  #TDABase + 1 + (19 * ScreenWidth) + ScreenWidth - 7, a2
    move.b   #'C', (a2)+
    move.b   #':', (a2)+
    
    
    move.l   counter_value, d0
    
    
    divu    #10, d0
    move.w   d0, d2           
    swap    d0                
    addib   #'0', d2          
    move.b   d2, (a2)+        
    
    
    move.w   d0, d0           
    addib   #'0', d0          
    move.b   d0, (a2)+        
    
    
    move.l  #TDABase + 1 + (19 * ScreenWidth) + ScreenWidth - 1, a2
    move.b   #'|', (a2)
    bra	    draw_status_done

draw_chat_status_line:
    
    move.l   #19, d0
    muls    #ScreenWidth, d0
    lea     TDABase + 1, a0
    add.l    d0, a0
    move.l  a0, a2
    
    
    move.b   #'|', (a2)+
    move.b   #' ', (a2)+
    
    
    move.l   #2, d1            
clear_chat_status_loop:
    cmp.l    #ScreenWidth - 1, d1  
    bge	    clear_chat_status_end
    move.b   #' ', (a2)+
    add.l    #1, d1
    bra	    clear_chat_status_loop
clear_chat_status_end:
    
    
    move.l  a0, a2
    add.l    #2, a2            
    
    
    
chat_status_continue:
    
    move.l  #TDABase + 1 + (19 * ScreenWidth) + ScreenWidth - 1, a2
    move.b   #'|', (a2)

draw_status_done:
    
    move.l   (sp)+, a2
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d7
    move.l   (sp)+, d6
    move.l   (sp)+, d5
    move.l   (sp)+, d4
    move.l   (sp)+, d3
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts



add_debug_trace:
    
    move.l   d1, -(sp)
    move.l   a2, -(sp)
    
    
    move.l  #TDABase + 1 + (19 * ScreenWidth) + 55, a2
    
    
    move.l   #0, d1
find_trace_slot:
    cmp.l    #10, d1           
    bge	    trace_slot_found
    cmp.b    #' ', (a2)
    beq	    trace_slot_found
    add.l    #1, a2
    add.l    #1, d1
    bra	    find_trace_slot
    
trace_slot_found:
    move.b   d0, (a2)
    
    
    move.l   (sp)+, a2
    move.l   (sp)+, d1
    rts


update_status_line:
    jsr	    draw_status
    rts


draw_footer:
    
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    move.l   a2, -(sp)
    
    
    move.l   #21, d0
    muls    #ScreenWidth, d0
    lea     TDABase + 1, a0
    add.l    d0, a0
    move.l  a0, a2
    
    
    move.b   #'|', (a2)+
    move.b   #' ', (a2)+
    
    
    cmp.l    #1, chat_mode_active
    beq	    draw_chat_footer
    
    
    
    move.l   a2, -(sp)         
    lea     footer_commands, a5
    jsr	    print_string_no_advance
    move.l   (sp)+, a2         
    bra	    finish_footer_draw

draw_chat_footer:
    
    move.b   #'>', (a2)+
    move.b   #' ', (a2)+
    
    
    cmp.l    #0, chat_input_length
    bne	    show_live_input
    
    
    move.l   a2, -(sp)         
    cmp.l    #1, chat_network_disabled
    beq	    use_bare_bones_footer
    lea     chat_footer_prompt, a5
    bra	    print_footer_prompt
use_bare_bones_footer:
    lea     chat_bare_bones_footer_prompt, a5
print_footer_prompt:
    jsr	    print_string_no_advance
    move.l   (sp)+, a2         
    bra	    finish_footer_draw
    
show_live_input:
    
    jsr	    display_chat_input_line
    bra	    finish_footer_draw

finish_footer_draw:
    
    move.l   a2, a1
    subal   a0, a1
    sub.l    #ScreenWidth, a1
    sub.l    #2, a1            
    move.l   #ScreenWidth - 2, d0
    sub.l    a1, d0
    
    move.l   #0, d1
cmd_space_loop:
    cmp.l    d0, d1
    bge	    cmd_space_end
    move.b   #' ', (a2)+
    add.l    #1, d1
    bra	    cmd_space_loop
cmd_space_end:
    
    
    move.l  #TDABase + 1 + (21 * ScreenWidth) + ScreenWidth - 1, a2
    move.b   #'|', (a2)+
    
    
    move.l   (sp)+, a2
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


process_keyboard_input:
    
    movem.l d0-d7/a0-a6, -(sp)
    
    
    move.l   #'P', d0
    jsr	    add_debug_trace
    
    
    move.b   KCTLReportSize, d5
    beq	    finish_key_input     
    
    
    move.l  #KCTLKeys, a0
    move.b   (a0), d0
    
    
    cmp.l    #1, chat_mode_active
    beq	    process_chat_keyboard_input
    
    
    move.l   d0, d6
    
    
    cmp.b    #KEY_ESC, d0
    beq	    process_key_home
    cmp.b    #KEY_M, d0        
    beq	    process_key_home
    cmp.b    #KEY_H, d0        
    beq	    process_key_home
    cmp.b    #KEY_B, d0
    beq	    process_key_back
    cmp.b    #KEY_Q, d0
    beq	    process_key_quit
    cmp.b    #KEY_A, d0        
    beq	    process_key_picture
    cmp.b    #KEY_C, d0        
    beq	    process_key_chat
    cmp.b    #KEY_D, d0        
    beq	    process_key_debug
    cmp.b    #KEY_U, d0        
    beq	    process_key_uart2
    cmp.b    #KEY_J, d0        
    beq	    process_key_scroll_down
    cmp.b    #KEY_K, d0        
    beq	    process_key_scroll_up
    cmp.b    #KEY_DOWN_ARROW, d0  
    beq	    process_key_scroll_down
    cmp.b    #KEY_UP_ARROW, d0    
    beq	    process_key_scroll_up
    
    
    cmp.b    #KEY_1, d0
    beq	    jump_section_1
    cmp.b    #KEY_2, d0
    beq	    jump_section_2
    cmp.b    #KEY_3, d0
    beq	    jump_section_3
    cmp.b    #KEY_4, d0
    beq	    jump_section_4
    cmp.b    #KEY_5, d0
    beq	    jump_section_5
    cmp.b    #KEY_6, d0
    beq	    jump_section_6
    cmp.b    #KEY_7, d0
    beq	    jump_section_7
    cmp.b    #KEY_8, d0
    beq	    jump_section_8
    cmp.b    #KEY_9, d0
    beq	    jump_section_9
    cmp.b    #KEY_0, d0
    beq	    jump_top
    
    bra	    finish_key_input


process_chat_keyboard_input:
    
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    move.l   a0, -(sp)
    
    
    move.l  #KCTLKeys, a0
    move.b   (a0), d0
    
    
    cmp.b    #KEY_TAB, d0
    beq	    hand.le_tab_toggle
    
    
    cmp.b    #KEY_ESC, d0
    beq	    exit_chat_mode_irc
    
    
    cmp.b    #KEY_BACKSPACE, d0
    beq	    hand.le_simple_backspace
    
    
    cmp.b    #KEY_ENTER, d0
    beq	    hand.le_mode_enter
    
    
    cmp.b    #KEY_UP_ARROW, d0
    beq	    chat_up_arrow
    cmp.b    #KEY_DOWN_ARROW, d0
    beq	    chat_down_arrow
    
    
    cmp.l    #32, d0           
    blt	    finish_chat_key_input   
    cmp.l    #126, d0          
    bgt	    finish_chat_key_input   
    
    
    
    move.b   KCTLModifiers, d1
    
    
    move.l   d1, modifier_debug_byte
    
    
    
    btst    #0, d1              
    bne	    apply_shift_transform
    btst    #1, d1              
    beq	    no_shift_mod
    
apply_shift_transform:
    
    
    
    cmp.b    #'1', d0
    beq	    inline_shift_1
    cmp.b    #'2', d0
    beq	    inline_shift_2
    cmp.b    #'3', d0
    beq	    inline_shift_3
    cmp.b    #'4', d0
    beq	    inline_shift_4
    cmp.b    #'5', d0
    beq	    inline_shift_5
    cmp.b    #'6', d0
    beq	    inline_shift_6
    cmp.b    #'7', d0
    beq	    inline_shift_7
    cmp.b    #'8', d0
    beq	    inline_shift_8
    cmp.b    #'9', d0
    beq	    inline_shift_9
    cmp.b    #'0', d0
    beq	    inline_shift_0
    
    
    cmp.b    #'a', d0
    blt	    check_shift_symbols
    cmp.b    #'z', d0
    bgt	    check_shift_symbols
    sub.b    #32, d0             
    bra	    no_shift_mod
    
check_shift_symbols:
    
    cmp.b    #'-', d0
    beq	    inline_shift_minus
    cmp.b    #'=', d0
    beq	    inline_shift_equals
    cmp.b    #';', d0
    beq	    inline_shift_semicolon
    cmp.b    #'\'', d0
    beq	    inline_shift_apostrophe
    cmp.b    #',', d0
    beq	    inline_shift_comma
    cmp.b    #'.', d0
    beq	    inline_shift_period
    cmp.b    #'/', d0
    beq	    inline_shift_slash
    bra	    no_shift_mod
    
inline_shift_1:
    move.b   #'!', d0
    bra	    no_shift_mod
inline_shift_2:
    move.b   #'@', d0
    bra	    no_shift_mod
inline_shift_3:
    move.b   #'#', d0
    bra	    no_shift_mod
inline_shift_4:
    move.b   #'$', d0
    bra	    no_shift_mod
inline_shift_5:
    move.b   #'%', d0
    bra	    no_shift_mod
inline_shift_6:
    move.b   #'^', d0
    bra	    no_shift_mod
inline_shift_7:
    move.b   #'&', d0
    bra	    no_shift_mod
inline_shift_8:
    move.b   #'*', d0
    bra	    no_shift_mod
inline_shift_9:
    move.b   #'(', d0
    bra	    no_shift_mod
inline_shift_0:
    move.b   #')', d0
    bra	    no_shift_mod
inline_shift_minus:
    move.b   #'_', d0
    bra	    no_shift_mod
inline_shift_equals:
    move.b   #'+', d0
    bra	    no_shift_mod
inline_shift_semicolon:
    move.b   #':', d0
    bra	    no_shift_mod
inline_shift_apostrophe:
    move.b   #'"', d0
    bra	    no_shift_mod
inline_shift_comma:
    move.b   #'<', d0
    bra	    no_shift_mod
inline_shift_period:
    move.b   #'>', d0
    bra	    no_shift_mod
inline_shift_slash:
    move.b   #'?', d0
    
no_shift_mod:
    
    move.l   chat_input_length, d2
    cmp.l    #70, d2
    bge	    finish_chat_key_input
    
    lea     chat_input_buffer, a1
    move.b   d0, (a1,d2)
    addql   #1, chat_input_length
    bra	    finish_chat_key_input


hand.le_tab_toggle:
    
    move.l   input_mode, d1
    cmp.l    #MODE_CHAT, d1
    beq	    tab_switch_to_terminal
    
    
    move.l   #MODE_CHAT, input_mode
    bra	    finish_chat_key_input
    
tab_switch_to_terminal:
    
    move.l   #MODE_TERMINAL, input_mode
    bra	    finish_chat_key_input


hand.le_mode_enter:
    
    move.l   input_mode, d1
    cmp.l    #MODE_TERMINAL, d1
    beq	    hand.le_terminal_mode_enter
    
    
    bra	    hand.le_simple_enter
    
hand.le_terminal_mode_enter:
    
    move.l   chat_input_length, d1
    cmp.l    #0, d1
    beq	    finish_chat_key_input
    
    
    lea     chat_input_buffer, a0
    move.l   chat_input_length, d1
    
terminal_send_loop:
    cmp.l    #0, d1
    beq	    terminal_send_cr
    move.b   (a0)+, d0
    move.b   d0, UART1_TX
    subql   #1, d1
    bra	    terminal_send_loop
    
terminal_send_cr:
    
    move.b   #13, UART1_TX
    move.b   #10, UART1_TX
    
    
    clr.l    chat_input_length
    bra	    finish_chat_key_input

hand.le_simple_backspace:
    
    jsr	    simple_remove_char
    bra	    finish_chat_key_input

chat_up_arrow:
    
    jsr	    navigate_input_history_up
    bra	    finish_chat_key_input

chat_down_arrow:
    
    jsr	    navigate_input_history_down
    bra	    finish_chat_key_input

hand.le_simple_enter:
    
    move.l   chat_input_length, d1
    cmp.l    #0, d1
    beq	    finish_chat_key_input    
    
    
    jsr	    add_to_input_history
    
    
    jsr	    enhanced_send_message
    
    
    clr.l    chat_input_length  
    clr.l    input_history_index
    bra	    finish_chat_key_input

exit_chat_mode_irc:
    
    move.l   #0, chat_mode_active
    jsr	    set_display_update_flag
    bra	    finish_chat_key_input


finish_chat_key_input:
    
    jsr	    simple_update_footer
    
    
    move.b   #1, KCTLNextReport
    
    
    move.l   (sp)+, a0
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts

jump_top:
    move.l   #0, scroll_offset
    jsr	    set_display_update_flag
    bra	    finish_key_input


jump_section_1:
    move.l   #8, scroll_offset    
    jsr	    set_display_update_flag
    bra	    finish_key_input

jump_section_2:
    move.l   #17, scroll_offset   
    jsr	    set_display_update_flag
    bra	    finish_key_input

jump_section_3:
    move.l   #35, scroll_offset   
    jsr	    set_display_update_flag
    bra	    finish_key_input

jump_section_4:
    move.l   #52, scroll_offset   
    jsr	    set_display_update_flag
    bra	    finish_key_input

jump_section_5:
    move.l   #64, scroll_offset   
    jsr	    set_display_update_flag
    bra	    finish_key_input

jump_section_6:
jump_section_7:
jump_section_8:
jump_section_9:
    move.l   #79, scroll_offset   
    jsr	    set_display_update_flag
    bra	    finish_key_input
    

process_key_home:
    jsr	    key_home
    bra	    finish_key_input

process_key_help:
    jsr	    key_help  
    bra	    finish_key_input

process_key_back:
    jsr	    key_back
    bra	    finish_key_input

process_key_quit:
    jsr	    key_quit
    bra	    finish_key_input

process_key_picture:
    jsr	    enter_picture_mode
    bra	    finish_key_input

process_key_chat:
    jsr	    process_chat_mode
    bra	    finish_key_input

process_key_debug:
    jsr	    process_debug_mode
    bra	    finish_key_input

process_key_uart2:
    jsr	    process_uart2_mode
    bra	    finish_key_input

process_key_scroll_down:
    jsr	    key_scroll_down
    bra	    finish_key_input

process_key_scroll_up:
    jsr	    key_scroll_up
    bra	    finish_key_input

finish_key_input:
    
    move.l   #'F', d0
    jsr	    add_debug_trace
    
    
consume_all_reports:
    move.b   KCTLCount, d0
    cmp.l    #0, d0
    beq	    all_consumed
    
    
    move.b   #1, KCTLNextReport
    
    
    move.l   #'C', d0
    jsr	    add_debug_trace
    
    
    move.l   #1000, d0
consume_delay:
    subil   #1, d0
    bne	    consume_delay
    
    bra	    consume_all_reports
    
all_consumed:
    
    move.l   #50, key_debounce_timer    
    
    
    move.l   #'D', d0
    jsr	    add_debug_trace
    
    
    movem.l (sp)+, d0-d7/a0-a6
    rts


process_menu_selection:
    
    move.l  #TDABase + 1 + (19 * ScreenWidth) + 50, a2
    move.b   #'[', (a2)+
    move.w   current_menu_id, d7
    addib   #'0', d7
    move.b   d7, (a2)+
    move.b   #',', (a2)+
    move.w   current_selection, d7
    addib   #'0', d7
    move.b   d7, (a2)+
    move.b   #']', (a2)+
    
    
    move.w   current_menu_id, d0
    move.w   current_selection, d1
    
    
    move.l   #'M', d0
    jsr	    add_debug_trace
    
    
    move.w   current_menu_id, d0    
    move.w   current_selection, d1  
    jsr	    get_menu_entry_type
    
    
    move.l  #TDABase + 1 + (19 * ScreenWidth) + 56, a2
    move.b   #'=', (a2)+
    move.b   d0, d3
    addib   #'0', d3
    move.b   d3, (a2)+
    
    
    cmp.b    #ENTRY_TYPE_SUBMENU, d0
    beq	    process_submenu_debug
    cmp.b    #ENTRY_TYPE_TEXT, d0
    beq	    process_text_debug
    cmp.b    #ENTRY_TYPE_LINK, d0
    beq	    process_link_debug
    
    
    move.l  #TDABase + 1 + (19 * ScreenWidth) + 58, a2
    move.b   #'D', (a2)+
    jsr	    set_display_update_flag
    rts

process_submenu_debug:
    move.l  #TDABase + 1 + (19 * ScreenWidth) + 58, a2
    move.b   #'S', (a2)+
    jmp	    process_submenu

process_text_debug:
    move.l  #TDABase + 1 + (19 * ScreenWidth) + 58, a2
    move.b   #'T', (a2)+
    jmp	    process_text

process_link_debug:
    move.l  #TDABase + 1 + (19 * ScreenWidth) + 58, a2
    move.b   #'L', (a2)+
    jmp	    process_link


process_submenu:
    
    move.w   current_menu_id, d0
    move.w   current_selection, d1
    
    
    move.l   #'S', d0
    jsr	    add_debug_trace
    
    
    move.l  #TDABase + 1 + (19 * ScreenWidth) + 54, a2
    move.b   #'(', (a2)+
    move.w   current_menu_id, d3
    addib   #'0', d3
    move.b   d3, (a2)+
    move.b   #',', (a2)+
    move.w   current_selection, d3
    addib   #'0', d3
    move.b   d3, (a2)+
    move.b   #')', (a2)+
    
    jsr	    get_menu_target_id
    
    
    move.l  #TDABase + 1 + (19 * ScreenWidth) + 60, a2
    move.b   #'>', (a2)+
    move.b   d0, d3
    addib   #'0', d3
    move.b   d3, (a2)+
    
    
    move.l   navigation_stack_pos, d1
    lsll    #2, d1             
    lea     navigation_stack, a0
    move.l   current_menu_id, (a0, d1.l)
    addil   #1, navigation_stack_pos
    
    
    move.w   d0, current_menu_id
    move.w   #0, current_selection
    
    
    jsr	    set_display_update_flag
    rts


process_text:
    
    move.w   current_menu_id, d0
    move.w   current_selection, d1
    
    jsr	    get_content_pointer
    move.l   a0, content_ptr
    
    
    move.l   #1, view_state       
    
    
    jsr	    set_display_update_flag
    
    
    jsr	    print_multiline_string
    
    
    move.l   (sp)+, a5
    move.l   (sp)+, a2
    move.l   (sp)+, d0
    rts


keyboard_handler:
    
    move.b   #STATUS_CLEAR_INTERRUPT, KCTLStatus
    rte


uart1_interrupt_handler:
    movem.l d0-d2/a0-a1, -(sp)
    
    
uart1_skip_log:
    
    move.b   UART1_STATUS, d0
    
    
    btst    #0, d0  
    beq	    uart1_check_tx
    
    
    move.b   UART1_RX, d1
    
    
    cmp.l    #1, chat_mode_active
    bne	    uart1_check_tx
    
    
    jsr	    add_char_to_line_buffer
    
    
    cmpi.b  #13, d1  
    beq	    uart1_line_complete
    cmpi.b  #10, d1  
    beq	    uart1_line_complete
    bra	    uart1_check_tx
    
uart1_line_complete:
    
    jsr	    process_complete_line
    
uart1_check_tx:
    
    btst    #1, d0  
    beq	    uart1_done
    
    
    
    
uart1_done:
    movem.l (sp)+, d0-d2/a0-a1
    rte


default_handler:
    
    move.l  #TDABase + 1 + (80 * (ScreenHeight - 1)), a2
    lea     exception_msg, a5
    jsr	    print_string
    
    
    exception_loop:
    bra	    exception_loop


init_menu_system:
    
    move.l   d0, -(sp)
    move.l   a0, -(sp)
    
    
    lea     menu_table, a0
    move.l   (a0), d0          
    
    
    lea     content_table, a0
    move.l   (a0), d0          
    
    
    move.w   #0, d0             
    jsr	    get_menu_item_count 
    
    
    move.l   (sp)+, a0
    move.l   (sp)+, d0
    rts


set_display_update_flag:
    
    
    movem.l d0-d1/a0, -(sp)
    move.l   #1, display_needs_update
    movem.l (sp)+, d0-d1/a0
    rts


process_link:
    
    lea     link_unavailable_msg, a0
    move.l   a0, content_ptr
    
    
    move.l   #1, view_state       
    
    
    jsr	    set_display_update_flag
    rts


key_home:
    
    move.l   #0, navigation_stack_pos
    move.l   #0, navigation_stack    
    addil   #1, navigation_stack_pos
    
    
    move.l   #0, current_menu_id
    move.l   #0, current_selection
    move.l   #0, view_state       
    
    
    jsr	    set_display_update_flag
    rts


key_back:
    
    cmp.l    #1, view_state
    beq	    return_to_menu_view
    
    
    cmp.l    #1, navigation_stack_pos
    ble	    finish_key_input     
    
    
    subil   #1, navigation_stack_pos
    move.l   navigation_stack_pos, d0
    sub.l    #1, d0              
    lsll    #2, d0              
    lea     navigation_stack, a0
    move.l   (a0, d0.l), d0
    
    
    move.l   d0, current_menu_id
    move.l   #0, current_selection
    
    
    jsr	    set_display_update_flag
    rts


return_to_menu_view:
    move.l   #0, view_state       
    
    
    jsr	    set_display_update_flag
    rts


key_help:
    
    move.l   #'H', d0
    jsr	    add_debug_trace
    
    
    cmp.l    #1, view_state
    beq	    key_help_already_done
    
    
    lea     help_text, a0
    move.l   a0, content_ptr
    
    
    move.l   #1, view_state       
    
    
    move.l   #'1', d0
    jsr	    add_debug_trace
    
    
    jsr	    set_display_update_flag

key_help_already_done:
    rts


key_quit:
    
    jsr	    key_home
    rts


key_scroll_down:
    
    movem.l d0-d7/a0-a6, -(sp)
    
    move.l   scroll_offset, d0
    move.l   content_total_lines, d1
    sub.l    #15, d1                
    cmp.l    d1, d0
    bge	    scroll_down_done
    add.l    #1, d0
    move.l   d0, scroll_offset
    jsr	    set_display_update_flag
scroll_down_done:
    
    movem.l (sp)+, d0-d7/a0-a6
    rts


key_scroll_up:
    
    movem.l d0-d7/a0-a6, -(sp)
    
    move.l   scroll_offset, d0
    cmp.l    #0, d0
    ble	    scroll_up_done
    sub.l    #1, d0
    move.l   d0, scroll_offset
    jsr	    set_display_update_flag
scroll_up_done:
    
    movem.l (sp)+, d0-d7/a0-a6
    rts


init_scroll_system:
    
    movem.l d0-d7/a0-a6, -(sp)
    
    
    move.l   #0, d0
    lea     combined_content, a0
count_lines_loop:
    move.b   (a0)+, d1
    cmp.b    #0, d1
    beq	    count_lines_done
    cmp.b    #10, d1             
    bne	    count_lines_loop
    add.l    #1, d0
    bra	    count_lines_loop
count_lines_done:
    move.l   d0, content_total_lines
    
    movem.l (sp)+, d0-d7/a0-a6
    rts


display_current_menu:
    
    movem.l d0-d7/a0-a6, -(sp)
    
    
    move.l   #'D', d0
    jsr	    add_debug_trace
    
    
    cmp.l    #0, view_state
    beq	    draw_menu_view
    cmp.l    #1, view_state
    beq	    draw_text_content_view
    
    
    jmp	    draw_menu_view


draw_content_area:
    
    movem.l d0-d7/a0-a6, -(sp)
    
    
    move.l   #'D', d0
    jsr	    add_debug_trace
    
    
    cmp.l    #1, chat_mode_active
    beq	    draw_chat_content
    
    
    jsr	    draw_scrolling_content
    
    movem.l (sp)+, d0-d7/a0-a6
    rts

draw_chat_content:
    
    jsr	    draw_chat_history_irc
    
    movem.l (sp)+, d0-d7/a0-a6
    rts


draw_scrolling_content:
    
    movem.l d0-d7/a0-a6, -(sp)
    
    
    jsr	    clear_content_area
    
    
    move.l  #TDABase + 1 + (3 * 80), a2
    
    
    lea     combined_content, a0
    move.l   scroll_offset, d0
    move.l   #0, d1
    
find_start_loop:
    cmp.l    d0, d1
    bge	    find_start_done
skip_line_loop:
    move.b   (a0)+, d2
    cmp.b    #0, d2
    beq	    find_start_done
    cmp.b    #10, d2
    bne	    skip_line_loop
    add.l    #1, d1
    bra	    find_start_loop
    
find_start_done:
    
    move.l   #0, d3
    
display_content_loop:
    cmp.l    #15, d3
    bge	    display_content_done
    move.l   #0, d1
    
display_line_loop:
    cmp.l    #78, d1                
    bge	    line_too_long
    move.b   (a0)+, d2
    cmp.b    #0, d2
    beq	    display_content_done
    cmp.b    #10, d2
    beq	    line_done
    move.b   d2, (a2)+
    add.l    #1, d1
    bra	    display_line_loop
    
line_too_long:
    move.b   (a0)+, d2
    cmp.b    #0, d2
    beq	    display_content_done
    cmp.b    #10, d2
    bne	    line_too_long
    
line_done:
    add.l    #1, d3
    move.l  #TDABase + 1 + (3 * 80), a2
    move.l   d3, d1
    muls    #80, d1
    add.l    d1, a2
    bra	    display_content_loop
    
display_content_done:
    
    movem.l (sp)+, d0-d7/a0-a6
    rts


draw_menu_view:
    
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    move.l   d3, -(sp)
    move.l   d4, -(sp)
    move.l   d5, -(sp)
    move.l   d6, -(sp)
    move.l   d7, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    move.l   a2, -(sp)
    move.l   a5, -(sp)
    
    
    move.w   current_menu_id, d0
    jsr	    get_menu_content
    cmp.l    #0, a0
    beq	    skip_menu_content
    
    
    move.l  #TDABase + 1 + (80 * 3), a2
    move.l  a0, a5
    jsr	    print_multiline_string
    
    
    move.l  a2, a0            
    subal   #TDABase + 1, a0   
    move.l   a0, d0            
    divu    #ScreenWidth, d0   
    move.w   d0, d5            
    
    
    add.w    #2, d5
    bra	    start_menu_items
    
skip_menu_content:
    
    move.w   #3, d5             
    
start_menu_items:
    
    move.w   current_menu_id, d0
    jsr	    get_menu_item_count
    move.w   d0, d7            
    
    
    cmp.w    #7, d5
    bge	    menu_start_ok
    move.w   #7, d5
    
menu_start_ok:
    
    cmp.w    #18, d5
    ble	    menu_line_ok
    move.w   #18, d5
    
menu_line_ok:
    
    move.w   #0, d6             
display_menu_loop:
    cmp.w    d7, d6            
    bge	    display_menu_end
    
    
    move.l   d5, d0             
    add.l    d6, d0             
    muls    #80, d0            
    lea     TDABase + 1, a0
    add.l    d0, a0
    move.l  a0, a2
    
    
    cmp.w    current_selection, d6
    bne	    display_menu_item_normal
    
    
    move.b   #'>', (a2)+
    move.b   #' ', (a2)+
    bra	    display_menu_item_number
    
display_menu_item_normal:
    
    move.b   #' ', (a2)+
    move.b   #' ', (a2)+
    
display_menu_item_number:
    
    move.b   d6, d0
    addib   #'1', d0
    move.b   d0, (a2)+
    move.b   #'.', (a2)+
    move.b   #' ', (a2)+
    
    
    move.w   current_menu_id, d0
    move.w   d6, d1

    jsr	    get_menu_item_text
    move.l  a0, a5

    
    jsr	    print_string
    
    
    add.w    #1, d6
    bra	    display_menu_loop
    
display_menu_end:
    
    move.l   (sp)+, a5
    move.l   (sp)+, a2
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d7
    move.l   (sp)+, d6
    move.l   (sp)+, d5
    move.l   (sp)+, d4
    move.l   (sp)+, d3
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


draw_text_content_view:
    
    move.l   d0, -(sp)
    move.l   a2, -(sp)
    move.l   a5, -(sp)
    
    
    move.l   #'C', d0
    jsr	    add_debug_trace
    
    
    move.l  #TDABase + 1 + (80 * 3), a2
    
    
    move.l  content_ptr, a5
    cmp.l    #0, a5
    beq	    content_ptr_null
    
    
    move.b   (a5), d0
    cmp.b    #0, d0
    beq	    content_empty
    
    
    jsr	    print_multiline_string
    
    
    move.l   (sp)+, a5
    move.l   (sp)+, a2
    move.l   (sp)+, d0
    rts
    
content_ptr_null:
    
    lea     content_null_msg, a5
    jsr	    print_string
    
    
    move.l   (sp)+, a5
    move.l   (sp)+, a2
    move.l   (sp)+, d0
    rts
    
content_empty:
    
    lea     content_empty_msg, a5
    jsr	    print_string
    
    
    move.l   (sp)+, a5
    move.l   (sp)+, a2
    move.l   (sp)+, d0
    rts




enter_picture_mode:
    
    move.l   d0, -(sp)
    move.l   a0, -(sp)
    
    
    move.l  #TDABase, a0
    move.b   #GraphicsMode, (a0)
    
    
    jsr	    clear_full_framebuffer
    
    
    jsr	    draw_picture
    
    
    move.l   #1, picture_mode_active
    
    
    move.l   (sp)+, a0
    move.l   (sp)+, d0
    rts


clear_full_framebuffer:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    
    move.l  #ScrnBase, a0
    move.l   #0, d1
    
clear_full_loop:
    cmp.l    #PictureSize, d1      
    bge	    clear_full_done
    move.b   #$FF, (a0)+          
    add.l    #1, d1
    bra	    clear_full_loop
    
clear_full_done:
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


enter_text_mode:
    
    move.l   d0, -(sp)
    move.l   a0, -(sp)
    
    
    move.l  #TDABase, a0
    move.b   #TextMode, (a0)
    
    
    move.l   #0, picture_mode_active
    
    
    move.l   #1, display_needs_update
    
    
    move.l   (sp)+, a0
    move.l   (sp)+, d0
    rts


ENTRY_TYPE_SUBMENU	equ	0
ENTRY_TYPE_TEXT	equ	1
ENTRY_TYPE_LINK	equ	2
MAX_MENU_ID	equ	5     


.section .rodata, "a"
	org	$003000


	xdef	header_title
	xdef	version_text
	xdef	version_text_length
	xdef	footer_commands
	xdef	status_text
	xdef	selection_text
	xdef	key_debug_text
	xdef	counter_text

header_title:
    .string "JonSharp.net Cyberterminal (limited) Access"
version_text:
    .string "[sampler ROM v1.3-2025]"
version_text_length	equ	23

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


help_text:
    .ascii "JonSharp.net Cyberterminal Help\n\n"
    .ascii "Navigation Commands:\n"
    .ascii "  - Use number keys (1-9) to select menu items\n"
    .ascii "  - Press M to return to the main menu\n"
    .ascii "  - Press B to go back to the previous menu\n"
    .ascii "  - Press H to display this help screen\n"
    .ascii "  - Press Q to quit (when available)\n\n"
    .ascii "Chat Mode Features:\n"
    .ascii "  - Enhanced keyboard: Shift+1 = !, Shift+2 = @, etc.\n"
    .ascii "  - TAB key toggles between Chat and Terminal modes\n"
    .ascii "  - Chat mode: messages sent via AT+QUICKMSG\n"
    .ascii "  - Terminal mode: raw AT commands sent directly\n"
    .ascii "  - Arrow keys navigate input history\n\n"
    .ascii "The cyberterminal provides access to jonsharp.net\n"
    .ascii "content and Aether mesh networking.\n\n"
    .asciz "Press B to return to your previous location."

; Each menu item is:
   - pointer to text (4 bytes)
   - type (1 byte) 
   - padding (1 byte)
   - target/data field (2 bytes)
     For submenu: target menu ID
     For text/link: low 2 bytes of content pointer 
   
   Total size: 8 bytes per menu item
   
   IMPORTANT: Content pointers are stored in separate fields (text_ptrs, link_ptrs)
   and retrieved using the item index as a lookup key



	xdef	menu_table
	xdef	content_table

	align	4
	xdef	current_menu_id
	xdef	current_selection
	xdef	view_state
	xdef	display_needs_update

current_menu_id:
    .dc.l    0               
current_selection:
    .dc.l    0               
view_state:
    .dc.l    0               
display_needs_update:
    .dc.l    0               

content_ptr:
    .dc.l    0               
navigation_stack_pos:
    .dc.l    0               
refresh_lock:
    .dc.l    0               
counter_value:
    .dc.l    0               
delay_counter:
    .dc.l    0
status_update_counter:
    .dc.l    0               
navigation_stack:
    .ds.l    16              
main_loop_toggle:
    .byte    '/'             
    .align 2                 
kbd_event_counter:
    .dc.l    0               
kbd_test_counter:
    .dc.l    0               
keyboard_input_ready:
    .dc.l    0               
key_debounce_timer:
    .dc.l    0               


scroll_offset:
    .dc.l    0               
content_total_lines:
    .dc.l    0               


picture_mode_active:
    .dc.l    0               


chat_mode_active:
    .dc.l    0               


uart2_mode_active:
    .dc.l    0               
uart2_input_buffer:
    .ds.b    80              
uart2_input_length:
    .dc.l    0               
uart2_interrupt_counter:
    .dc.l    0               


input_mode:
    .dc.l    MODE_CHAT       


modifier_debug_byte:
    .dc.l    0               


chat_network_disabled:
    .dc.l    0               


debug_mode_active:
    .dc.l    0               
chat_network_status:
    .dc.l    0               
chat_input_buffer:
    .ds.b    80              
chat_input_length:
    .dc.l    0               


chat_history_lines:
    .dc.l    0               
chat_history_scroll:
    .dc.l    0               
chat_history_buffer:
.ds.b    1440            
temp_chat_line:
.ds.b    81             


current_room:
.ds.b    32             
message_counter:
    .dc.l    0               
last_message_time:
    .dc.l    0               


input_history_buffer:
.ds.b    800            
input_history_count:
    .dc.l    0               
input_history_index:
    .dc.l    0               


activity_indicator:
    .dc.b    '*'            
    .ds.b    1              


chat_poll_counter:
    .dc.l    0              
chat_display_dirty:
    .dc.l    0              
chat_timeout_counter:
    .dc.l    0              




NumImages	equ	2            
current_image_index:
    .dc.l    0               


	align	4
image_data_table:
    .dc.l    picture_data2   
    .dc.l    picture_data    


	include	"picture_data_mot.s"
	include	"picture_data2_mot.s"


draw_picture:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    move.l   d3, -(sp)
    move.l   d4, -(sp)
    move.l   d5, -(sp)
    move.l   d6, -(sp)
    move.l   d7, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    
    
    move.l   current_image_index, d0
    lsll    #2, d0                    
    lea     image_data_table, a1
    move.l   (a1,d0), a1             
    
    
    move.l  #ScrnBase, a0             
    
    
    
    move.l   #15000, d0            
    
byte_loop:
    
    cmp.l    #0, d0
    beq	    picture_complete
    
    
    move.b   (a1)+, d7
    
    
    move.l   #8, d6                
    
bit_loop:
    
    cmp.l    #0, d6
    beq	    next_byte
    
    
    move.l   d7, d3
    lsrl    #7, d3                
    and.l    #1, d3                
    
    
    cmp.l    #1, d3
    beq	    set_white_pixel
    move.b   #$00, (a0)+          
    bra	    next_bit
    
set_white_pixel:
    move.b   #$FF, (a0)+          
    
next_bit:
    
    lsll    #1, d7
    
    
    sub.l    #1, d6
    bra	    bit_loop
    
next_byte:
    
    sub.l    #1, d0
    bra	    byte_loop
    
picture_complete:
    
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d7
    move.l   (sp)+, d6
    move.l   (sp)+, d5
    move.l   (sp)+, d4
    move.l   (sp)+, d3
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


switch_to_next_image:
    move.l   d0, -(sp)
    
    
    move.l   current_image_index, d0
    add.l    #1, d0
    
    
    cmp.l    #NumImages, d0
    blt	    next_image_no_wrap
    move.l   #0, d0                
    
next_image_no_wrap:
    move.l   d0, current_image_index
    
    
    jsr	    clear_full_framebuffer
    jsr	    draw_picture
    
    move.l   (sp)+, d0
    rts


switch_to_previous_image:
    move.l   d0, -(sp)
    
    
    move.l   current_image_index, d0
    sub.l    #1, d0
    
    
    cmp.l    #0, d0
    bge	    prev_image_no_wrap
    move.l   #NumImages-1, d0      
    
prev_image_no_wrap:
    move.l   d0, current_image_index
    
    
    jsr	    clear_full_framebuffer
    jsr	    draw_picture
    
    move.l   (sp)+, d0
    rts

; ======================================================================
 * CHAT MODE FUNCTIONS
 * ====================================================================== 


process_chat_mode:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    move.l   a0, -(sp)
    
    
    cmp.l    #1, chat_mode_active
    beq	    toggle_chat_off
    
    
    move.l   #1, chat_mode_active
    
    
    jsr	    clear_text_screen
    jsr	    init_chat_history
    jsr	    display_chat_interface
    
    
    jsr	    initialize_aether_safe
    
    
    move.l   #0, chat_poll_counter
    move.l   #0, chat_display_dirty
    
    bra	    chat_mode_done
    
toggle_chat_off:
    
    move.l   #0, chat_mode_active
    jsr	    set_display_update_flag  
    
chat_mode_done:
    move.l   (sp)+, a0
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


initialize_aether_if_needed:
    move.l   d0, -(sp)
    
    
    cmp.l    #1, chat_network_disabled
    beq	    aether_init_disabled
    
    
    cmp.l    #2, chat_network_status  
    beq	    aether_init_done
    
    
    move.l   #1, chat_network_status
    
    
    lea     log_aether_init_start, a0
    jsr	    add_chat_line
    
    
    jsr	    aether_init
    cmp.l    #0, d0  
    bne	    aether_init_failed
    
    
    lea     log_aether_connecting, a0
    jsr	    add_chat_line
    
    jsr	    aether_connect  
    cmp.l    #0, d0  
    bne	    aether_init_failed
    
    
    lea     log_aether_connected, a0
    jsr	    add_chat_line
    
    
    lea     default_chat_room_name, a0
    jsr	    aether_chat_join
    
    
    movea.l #hand.le_incoming_chat_simple, a0
    jsr	    aether_set_chat_hand.ler
    
    
    move.l   #2, chat_network_status
    bra	    aether_init_done
    
aether_init_failed:
    
    lea     log_aether_failed, a0
    jsr	    add_chat_line
    
    
    move.l   #2, chat_network_status  
    bra	    aether_init_done
    
aether_init_disabled:
    
    move.l   #0, chat_network_status
    
aether_init_done:
    move.l   (sp)+, d0
    rts


initialize_aether_safe:
    move.l   d0, -(sp)
    
    
    cmp.l    #1, chat_network_disabled
    beq	    aether_safe_disabled
    
    
    cmp.l    #2, chat_network_status  
    beq	    aether_safe_done
    
    
    lea     log_aether_init_start, a0
    jsr	    add_chat_line
    jsr	    display_chat_history  
    
    
    jsr	    test_uart_connectivity
    cmp.l    #0, d0
    bne	    aether_safe_failed
    
    
    move.l   #1, chat_network_status  
    
    
    jsr	    aether_init_with_timeout
    cmp.l    #0, d0  
    bne	    aether_safe_failed
    
    
    lea     log_aether_connecting, a0
    jsr	    add_chat_line
    jsr	    display_chat_history  
    
    
    jsr	    aether_connect_with_timeout
    cmp.l    #0, d0  
    bne	    aether_safe_failed
    
    
    lea     log_aether_connected, a0
    jsr	    add_chat_line
    jsr	    display_chat_history  
    move.l   #2, chat_network_status  
    bra	    aether_safe_done
    
aether_safe_failed:
    
    lea     log_aether_failed, a0
    jsr	    add_chat_line
    jsr	    display_chat_history  
    move.l   #2, chat_network_status  
    bra	    aether_safe_done
    
aether_safe_disabled:
    
    move.l   #0, chat_network_status
    
aether_safe_done:
    move.l   (sp)+, d0
    rts

; Test if UART is responsive without blocking
 * Returns: 0 if responsive, 1 if not responsive
 
test_uart_connectivity:
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    
    
    moveq   #10, d1  
    
test_uart_loop:
    move.b   UART1_STATUS, d0
    
    
    moveq   #100, d2
test_delay:
    subql   #1, d2
    bne	    test_delay
    
    subql   #1, d1
    bne	    test_uart_loop
    
    
    moveq   #0, d0  
    
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    rts


aether_init_with_timeout:
    move.l   d1, -(sp)
    
    
    move.b   #$07, UART1_CONTROL  
    
    
    move.b   UART1_CONTROL, d1
    lea     log_uart_control_set, a0
    jsr	    add_chat_line
    jsr	    display_chat_history
    
    
    lea     log_uart_interrupts, a0
    jsr	    add_chat_line
    jsr	    display_chat_history
    
    
    jsr	    send_at_command_async
    
    
    moveq   #0, d0  
    
    move.l   (sp)+, d1
    rts


aether_connect_with_timeout:
    move.l   d1, -(sp)
    
    
    jsr	    send_netalias_command_async
    
    
    jsr	    send_init_command_async
    
    
    jsr	    send_netjoin_command_async
    
    
    moveq   #0, d0  
    
    move.l   (sp)+, d1
    rts


send_at_command_async:
    move.l   d0, -(sp)
    move.l   a0, -(sp)
    
    
    lea     str_at_test, a0
    jsr	    send_string_async
    
    move.l   (sp)+, a0
    move.l   (sp)+, d0
    rts


send_netalias_command_async:
    move.l   d0, -(sp)
    move.l   a0, -(sp)
    
    
    lea     str_netalias_cmd, a0
    jsr	    send_string_async
    
    move.l   (sp)+, a0
    move.l   (sp)+, d0
    rts


send_init_command_async:
    move.l   d0, -(sp)
    move.l   a0, -(sp)
    
    
    lea     str_init_cmd, a0
    jsr	    send_string_async
    
    move.l   (sp)+, a0
    move.l   (sp)+, d0
    rts


send_netjoin_command_async:
    move.l   d0, -(sp)
    move.l   a0, -(sp)
    
    
    lea     str_netjoin_cmd, a0
    jsr	    send_string_async
    
    move.l   (sp)+, a0
    move.l   (sp)+, d0
    rts


send_string_async:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    
    
send_string_loop:
    move.b   (a0)+, d0
    beq	    send_string_done
    
    
    moveq   #100, d2  
async_wait_tx_ready:
    move.b   UART1_STATUS, d1
    btst    #1, d1  
    bne	    async_tx_is_ready
    
    
    moveq   #10, d1
async_tx_delay:
    subql   #1, d1
    bne	    async_tx_delay
    
    subql   #1, d2
    bne	    async_wait_tx_ready
    
    
    bra	    send_async_exit
    
async_tx_is_ready:
    
    move.b   d0, UART1_TX
    bra	    send_string_loop
    
send_string_done:
    
    
    moveq   #100, d2
async_wait_cr_ready:
    move.b   UART1_STATUS, d1
    btst    #1, d1
    bne	    async_cr_ready
    moveq   #10, d1
async_cr_delay:
    subql   #1, d1
    bne	    async_cr_delay
    subql   #1, d2
    bne	    async_wait_cr_ready
    bra	    send_async_exit
    
async_cr_ready:
    move.b   #13, UART1_TX
    
    
    moveq   #100, d2
async_wait_lf_ready:
    move.b   UART1_STATUS, d1
    btst    #1, d1
    bne	    async_lf_ready
    moveq   #10, d1
async_lf_delay:
    subql   #1, d1
    bne	    async_lf_delay
    subql   #1, d2
    bne	    async_wait_lf_ready
    bra	    send_async_exit
    
async_lf_ready:
    move.b   #10, UART1_TX
    
send_async_exit:
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


add_char_to_line_buffer:
    movem.l d0-d2/a0, -(sp)
    
    
    move.w   uart_line_pos, d0
    
    
    cmpi.w  #126, d0  
    bge	    uart_add_char_done
    
    
    lea     uart_line_buffer, a0
    move.b   d1, (a0, d0.w)
    
    
    addq.w  #1, d0
    move.w   d0, uart_line_pos
    
uart_add_char_done:
    movem.l (sp)+, d0-d2/a0
    rts


process_complete_line:
    movem.l d0-d2/a0, -(sp)
    
    
    move.w   uart_line_pos, d0
    lea     uart_line_buffer, a0
    move.b   #0, (a0, d0.w)
    
    
    cmpi.w  #0, d0
    beq	    process_line_reset
    
    
    lea     uart_line_buffer, a0
    jsr	    check_for_status_updates
    
    
    lea     uart_line_buffer, a0
    jsr	    add_at_response_to_chat
    
process_line_reset:
    
    move.w   #0, uart_line_pos
    
    movem.l (sp)+, d0-d2/a0
    rts


add_at_response_to_chat:
    movem.l d0-d2/a0-a1, -(sp)
    
    
    lea     uart_rx_buffer, a1
    lea     log_at_prefix, a0
    jsr	    copy_string_simple
    
    
    lea     uart_line_buffer, a0
    jsr	    append_string_simple
    
    
    lea     uart_rx_buffer, a0
    jsr	    add_chat_line
    jsr	    display_chat_history
    
    movem.l (sp)+, d0-d2/a0-a1
    rts


copy_string_simple:
    move.b   (a0)+, (a1)+
    bne	    copy_string_simple
    subq.l  #1, a1  
    rts


append_string_simple:
    move.b   (a0)+, (a1)+
    bne	    append_string_simple
    rts


check_for_status_updates:
    movem.l d0-d2/a0-a1, -(sp)
    
    
    lea     uart_line_buffer, a0
    lea     str_netjoin_connected, a1
    jsr	    string_starts_with
    cmp.l    #1, d0
    beq	    set_connected_status
    
    
    lea     uart_line_buffer, a0
    lea     str_netjoin_disconnected, a1
    jsr	    string_starts_with
    cmp.l    #1, d0
    beq	    set_disconnected_status
    
    bra	    status_check_done
    
set_connected_status:
    
    move.l   #2, chat_network_status  
    bra	    status_check_done
    
set_disconnected_status:
    
    move.l   #0, chat_network_status  
    
status_check_done:
    movem.l (sp)+, d0-d2/a0-a1
    rts




display_chat_interface:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    
    
    jsr	    draw_chat_header
    
      
    jsr	    display_chat_history
    
    
    jsr	    draw_status
    jsr	    draw_footer
    
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


display_chat_interface_minimal:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    
    
    move.l  #TDABase + 1, a1
    lea     chat_minimal_header_msg, a0
    jsr	    copy_string_to_screen
    
    
    move.l  #TDABase + 1 + (2 * ScreenWidth), a1
    lea     chat_minimal_commands_msg, a0
    jsr	    copy_string_to_screen
    
    
    move.l  #TDABase + 1 + (22 * ScreenWidth), a1
    lea     chat_minimal_prompt_msg, a0
    jsr	    copy_string_to_screen
    
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


display_chat_history:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    
    
    move.l   chat_history_lines, d0
    cmp.l    #14, d0
    ble	    history_lines_ok
    move.l   #14, d0  
    
history_lines_ok:
    cmp.l    #0, d0
    beq	    history_done
    
    
    
    lea     chat_history_buffer, a0
    
    move.l  #TDABase + 1 + (4 * ScreenWidth), a1
    
simple_history_loop:
    
    move.l   #80, d1
copy_buffer_line:
    move.b   (a0)+, (a1)+
    subql   #1, d1
    bne	    copy_buffer_line
    
    
    move.l   a1, d2
    sub.l    #80, d2                  
    add.l    #ScreenWidth, d2         
    move.l  d2, a1                  
    
    
    subql   #1, d0
    bne	    simple_history_loop
    
history_done:
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


clear_text_screen:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    
    
    
    move.l   #3, d1
clear_content_lines:
    cmp.l    #18, d1
    bge	    clear_status_area
    
    
    move.l   d1, d0
    muls    #ScreenWidth, d0
    lea     TDABase + 1, a0
    add.l    d0, a0
    add.l    #2, a0               
    
    
    move.l   #ScreenWidth - 3, d0
clear_line_loop:
    move.b   #' ', (a0)+
    subql   #1, d0
    bne	    clear_line_loop
    
    addql   #1, d1
    bra	    clear_content_lines
    
clear_status_area:
    
    move.l   #19, d0
    muls    #ScreenWidth, d0
    lea     TDABase + 1, a0
    add.l    d0, a0
    add.l    #2, a0               
    
    move.l   #ScreenWidth - 3, d0
clear_status_loop:
    move.b   #' ', (a0)+
    subql   #1, d0
    bne	    clear_status_loop
    
    
    move.l   #21, d0
    muls    #ScreenWidth, d0
    lea     TDABase + 1, a0
    add.l    d0, a0
    add.l    #2, a0               
    
    move.l   #ScreenWidth - 3, d0
clear_input_loop:
    move.b   #' ', (a0)+
    subql   #1, d0
    bne	    clear_input_loop
    
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


init_chat_history:
    move.l   d0, -(sp)
    move.l   a0, -(sp)
    
    
    lea     chat_history_buffer, a0
    move.l   #1440, d0              
clear_history_loop:
    move.b   #' ', (a0)+
    subql   #1, d0
    bne	    clear_history_loop
    
    
    move.l   #0, chat_history_lines
    
    move.l   (sp)+, a0
    move.l   (sp)+, d0
    rts


draw_chat_header:
    move.l   d0, -(sp)
    move.l   a0, -(sp)
    move.l   a2, -(sp)
    move.l   a5, -(sp)
    
    
    jsr	    draw_borders
    
    
    move.l  #TDABase + 1 + ScreenWidth, a2
    
    
    move.b   #'|', (a2)+
    move.b   #' ', (a2)+
    
    
    lea     chat_header_msg, a5
    jsr	    print_string_no_advance
    
chat_header_done:
    
    move.l  #TDABase + 1 + ScreenWidth + ScreenWidth - 1, a2
    move.b   #'|', (a2)
    
    move.l   (sp)+, a5
    move.l   (sp)+, a2
    move.l   (sp)+, a0
    move.l   (sp)+, d0
    rts


copy_string_to_screen:
    
    movem.l d0-d7/a0-a6, -(sp)
    
    
    
    move.l   a1, d1
    sub.l    #TDABase + 1, d1        
    divu    #ScreenWidth, d1        
    swap    d1                       
    moveq   #ScreenWidth, d0
    sub.l    d1, d0                  
    subq    #1, d0                   
    
    
    cmp.l    #TDABase + 1 + (ScreenWidth * ScreenHeight), a1
    bge	    copy_string_done_bounds   
    
copy_string_loop:
    
    tst.l   d0
    beq	    copy_string_done_bounds   
    
    
    move.b   (a0)+, d1
    beq	    copy_string_done_bounds
    move.b   d1, (a1)+
    subq    #1, d0
    bra	    copy_string_loop
    
copy_string_done_bounds:
    
    movem.l (sp)+, d0-d7/a0-a6
    rts




display_simple_network_status:
    move.l   d0, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    
    
    move.l  #TDABase + 1 + (2 * ScreenWidth), a1
    cmp.l    #2, chat_network_status  
    beq	    show_simple_connected
    cmp.l    #1, chat_network_status  
    beq	    show_simple_connecting
    
    
    lea     status_disconnected_msg, a0
    jsr	    copy_string_to_screen
    bra	    simple_status_done
    
show_simple_connecting:
    lea     status_connecting_msg, a0
    jsr	    copy_string_to_screen
    bra	    simple_status_done
    
show_simple_connected:
    lea     status_connected_msg, a0
    jsr	    copy_string_to_screen
    
simple_status_done:
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d0
    rts


display_comprehensive_network_status:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    
    
    jsr	    update_network_status_data
    
    
    move.l  #TDABase + 1 + (2 * ScreenWidth), a1
    lea     net_status_header, a0
    jsr	    copy_string_to_screen
    
    
    cmp.l    #1, chat_network_disabled
    beq	    show_status_disabled
    
    jsr	    aether_get_status
    cmp.l    #2, d0  
    beq	    show_connected_status
    cmp.l    #1, d0  
    beq	    show_connecting_status
    
show_status_disabled:
    
    lea     status_disabled_msg, a0
    jsr	    copy_string_to_screen
    bra	    status_line_done
    
    
    lea     status_disconnected_msg, a0
    jsr	    copy_string_to_screen
    bra	    status_line_done
    
show_connecting_status:
    lea     status_connecting_msg, a0
    jsr	    copy_string_to_screen
    bra	    status_line_done
    
show_connected_status:
    lea     status_connected_msg, a0
    jsr	    copy_string_to_screen
    
    
    lea     neighbor_count_prefix, a0
    jsr	    copy_string_to_screen
    move.w   neighbor_count, d0
    jsr	    display_decimal_number
    
status_line_done:
    
    move.l  #TDABase + 1 + (3 * ScreenWidth), a1
    lea     net_id_prefix, a0
    jsr	    copy_string_to_screen
    lea     network_id, a0
    jsr	    copy_string_to_screen
    
    
    lea     node_id_prefix, a0
    jsr	    copy_string_to_screen
    lea     node_id, a0
    jsr	    copy_string_to_screen
    
    
    move.l  #TDABase + 1 + (4 * ScreenWidth), a1
    lea     rf_params_prefix, a0
    jsr	    copy_string_to_screen
    
    
    move.l   frequency, d0
    jsr	    display_frequency
    
    
    lea     sf_prefix, a0
    jsr	    copy_string_to_screen
    move.w   spreading_factor, d0
    jsr	    display_decimal_number
    
    
    lea     bw_prefix, a0
    jsr	    copy_string_to_screen
    move.w   band.width, d0
    jsr	    display_decimal_number
    lea     khz_suffix, a0
    jsr	    copy_string_to_screen
    
    
    move.l  #TDABase + 1 + (5 * ScreenWidth), a1
    lea     signal_prefix, a0
    jsr	    copy_string_to_screen
    
    
    lea     rssi_prefix, a0
    jsr	    copy_string_to_screen
    move.w   last_rssi, d0
    jsr	    display_signed_number
    lea     dbm_suffix, a0
    jsr	    copy_string_to_screen
    
    
    lea     snr_prefix, a0
    jsr	    copy_string_to_screen
    move.w   last_snr, d0
    jsr	    display_signed_number
    
    
    lea     pwr_prefix, a0
    jsr	    copy_string_to_screen
    move.w   tx_power, d0
    jsr	    display_signed_number
    lea     dbm_suffix, a0
    jsr	    copy_string_to_screen
    
    
    move.w   neighbor_count, d0
    tst.w   d0
    beq	    no_neighbors_to_show
    
    move.l  #TDABase + 1 + (6 * ScreenWidth), a1
    lea     neighbors_header, a0
    jsr	    copy_string_to_screen
    
    
    jsr	    display_neighbor_list
    bra	    neighbors_done
    
no_neighbors_to_show:
    move.l  #TDABase + 1 + (6 * ScreenWidth), a1
    lea     no_neighbors_msg, a0
    jsr	    copy_string_to_screen
    
neighbors_done:
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


update_network_status_data:
    move.l   d0, -(sp)
    
    
    cmp.l    #1, chat_network_disabled
    beq	    update_network_skip
    
    
    jsr	    aether_get_network_info
    
    
    jsr	    aether_get_neighbors
    
update_network_skip:
    move.l   (sp)+, d0
    rts


display_decimal_number:
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    move.l   a0, -(sp)
    
    
    tst.w   d0
    bne	    convert_nonzero_display
    move.b   #'0', (a1)+
    bra	    display_decimal_done
    
convert_nonzero_display:
    
    move.w  d0, d1
    moveq   #0, d2
    
    
count_digits:
    divu    #10, d1
    addq    #1, d2
    move.w  d1, d1
    tst.w   d1
    bne	    count_digits
    
    
    move.w  d0, d1
    jsr	    convert_to_ascii
    
display_decimal_done:
    move.l   (sp)+, a0
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    rts


display_signed_number:
    tst.w   d0
    bpl	    display_positive
    move.b   #'-', (a1)+
    neg.w   d0
display_positive:
    jsr	    display_decimal_number
    rts


display_frequency_short:
    
    move.w  d0, d1
    divu    #1000, d1  
    move.w  d1, d0
    jsr	    display_decimal_number_short
    lea     mhz_suffix, a5
    jsr	    print_string_no_advance
    rts

display_decimal_number_short:
    
    tst.w   d0
    bne	    convert_short_nonzero
    move.b   #'0', (a2)+
    rts
convert_short_nonzero:
    cmpi.w  #10, d0
    blt	    single_digit_short
    
    move.w  d0, d1
    divu    #10, d1
    move.w  d1, d0
    addib   #'0', d0
    move.b   d0, (a2)+
    swap    d1
    move.w  d1, d0
    addib   #'0', d0
    move.b   d0, (a2)+
    rts
single_digit_short:
    addib   #'0', d0
    move.b   d0, (a2)+
    rts

display_signed_number_short:
    
    tst.w   d0
    bpl	    display_positive_short
    move.b   #'-', (a2)+
    neg.w   d0
display_positive_short:
    jsr	    display_decimal_number_short
    rts


convert_to_ascii:
    
    cmpi.w  #1000, d1
    blt	    check_hundreds
    divu    #1000, d1
    move.w  d1, d0
    addi.b  #'0', d0
    move.b   d0, (a1)+
    swap    d1
    
check_hundreds:
    cmpi.w  #100, d1
    blt	    check_tens
    divu    #100, d1
    move.w  d1, d0
    addi.b  #'0', d0
    move.b   d0, (a1)+
    swap    d1
    
check_tens:
    cmpi.w  #10, d1
    blt	    show_units
    divu    #10, d1
    move.w  d1, d0
    addi.b  #'0', d0
    move.b   d0, (a1)+
    swap    d1
    
show_units:
    move.w  d1, d0
    addi.b  #'0', d0
    move.b   d0, (a1)+
    rts


display_frequency:
    move.l   d1, -(sp)
    
    
    divu    #1000, d0  
    move.w  d0, d1
    divu    #1000, d1  
    move.w  d1, d0
    jsr	    display_decimal_number
    lea     mhz_suffix, a0
    jsr	    copy_string_to_screen
    
    move.l   (sp)+, d1
    rts


display_neighbor_list:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    
    
    move.w   neighbor_count, d0
    cmpi.w  #3, d0
    ble	    show_all_neighbors
    moveq   #3, d0
    
show_all_neighbors:
    moveq   #0, d1
    lea     neighbor_ids, a0
    
show_neighbor_loop:
    cmp.w   d0, d1
    bge	    neighbors_list_done
    
    
    moveq   #8, d2
show_neighbor_name:
    move.b   (a0)+, (a1)+
    dbra	   d2, show_neighbor_name
    
    
    adda.l  #24, a0  
    
    
    addq    #1, d1
    cmp.w   d0, d1
    bge	    neighbors_list_done
    move.b   #' ', (a1)+
    
    bra	    show_neighbor_loop
    
neighbors_list_done:
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts




update_chat_input_display:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    
    
    move.l  #TDABase + 1 + (22 * ScreenWidth), a1
    move.l   #0, d1
clear_input_line:
    cmp.l    #ScreenWidth-1, d1
    bge	    display_prompt
    
    
    cmp.l    #TDABase + 1 + (23 * ScreenWidth), a1
    bge	    display_prompt  
    
    move.b   #' ', (a1)+
    add.l    #1, d1
    bra	    clear_input_line
    
display_prompt:
    
    move.l  #TDABase + 1 + (22 * ScreenWidth), a1
    movea.l #chat_input_prompt, a0
    jsr	    copy_string_to_screen
    
    
    movea.l #chat_input_buffer, a0
    move.l   chat_input_length, d1
    cmp.l    #0, d1
    beq	    input_display_done
    
    
    move.l   #TDABase + 1 + (23 * ScreenWidth), d0  
    sub.l    a1, d0                                 
    cmp.l    d0, d1                                 
    ble	    copy_input_chars                         
    move.l   d0, d1                                 
    
copy_input_chars:
    tst.l   d1
    beq	    input_display_done
    move.b   (a0)+, (a1)+
    sub.l    #1, d1
    bra	    copy_input_chars
    
input_display_done:
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts

; Hand.le incoming chat message from network
 * Called by aether modem when +CHAT: notification received
 * Input: A0 = time string, A1 = sender string, A2 = message string
 
hand.le_incoming_chat_message:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    cmp.l    #1, chat_mode_active
    bne	    incoming_chat_done
    
    
    lea     temp_chat_line, a3
    
    
    move.b   #'[', (a3)+
    move.l  a0, a4  
copy_time:
    move.b  (a4)+, d0
    beq	    time_done
    move.b  d0, (a3)+
    bra	    copy_time
time_done:
    move.b   #']', (a3)+
    move.b   #' ', (a3)+
    
    
    move.b   #'<', (a3)+
    move.l  a1, a4  
copy_sender:
    move.b  (a4)+, d0
    beq	    sender_done
    move.b  d0, (a3)+
    bra	    copy_sender
sender_done:
    move.b   #'>', (a3)+
    move.b   #' ', (a3)+
    
    
    move.l  a2, a4  
copy_message:
    move.b  (a4)+, d0
    beq	    message_done
    move.b  d0, (a3)+
    bra	    copy_message
message_done:
    clr.b   (a3)  
    
    
    lea     temp_chat_line, a0
    jsr	    add_chat_line
    
    
    jsr	    display_chat_history
    
incoming_chat_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts

; Simple hand.ler for incoming chat - processes raw +CHAT: line
 * Input: A0 = pointer to raw "+CHAT: [time] <sender> message" line
 
	align	2
hand.le_incoming_chat_simple:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    cmp.l    #1, chat_mode_active
    bne	    simple_chat_done
    
    
    movea.l a0, a1
    cmpi.b  #'+', (a1)
    beq	    hand.le_at_response
    
    
    jsr	    add_chat_line
    bra	    simple_chat_done
    
hand.le_at_response:
    
    move.l  a0, a2
    addq.l  #6, a2  
    cmpi.b  #' ', -1(a2)  
    bne	    log_other_response
    
    
    lea     log_incoming_message, a0
    jsr	    add_chat_line
    
    
    movea.l a1, a0  
    jsr	    add_chat_line
    bra	    simple_chat_done
    
log_other_response:
    
    lea     log_at_response, a0
    jsr	    add_chat_line
    
    
    movea.l a1, a0  
    jsr	    add_chat_line
    
    
    jsr	    display_chat_history
    
simple_chat_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts

; Add a line to the chat history buffer
 * Input: A0 = pointer to null-terminated string (max 79 chars)
 
	align	2
add_chat_line:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    move.l   chat_history_lines, d0
    cmp.l    #14, d0
    blt	    add_line_space_ok
    
    
    lea     chat_history_buffer, a1        
    lea     chat_history_buffer + 80, a2   
    move.l   #1040, d0                      
shift_lines_up:
    move.b  (a2)+, (a1)+
    subq.l  #1, d0
    bne	    shift_lines_up
    
    
    lea     chat_history_buffer + 1040, a1  
    move.l   #80, d0
clear_last_line:
    move.b  #' ', (a1)+
    subq.l  #1, d0
    bne	    clear_last_line
    
    
    move.l   #13, chat_history_lines
    
add_line_space_ok:
    
    move.l   chat_history_lines, d0
    mulu.w  #80, d0                        
    lea     chat_history_buffer, a1
    adda.l  d0, a1                        
    
    
    move.l   #80, d1                        
copy_new_line:
    tst.l   d1
    beq	    line_copy_done
    move.b  (a0), d0
    beq	    pad_remaining                   
    move.b  d0, (a1)+
    addq.l  #1, a0
    subq.l  #1, d1
    bra	    copy_new_line
    
pad_remaining:
    tst.l   d1
    beq	    line_copy_done
    move.b  #' ', (a1)+
    subq.l  #1, d1
    bra	    pad_remaining
    
line_copy_done:
    
    addq.l  #1, chat_history_lines
    
    movem.l (sp)+, d0-d7/a0-a6
    rts


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


log_aether_init_start:
    .string "[NET] Initializing aether modem..."
log_aether_connecting:
    .string "[NET] Modem ready, connecting to network..."
log_aether_connected:
    .string "[NET] Connected! Joining chat room..."
log_aether_failed:
    .string "[NET] Connection failed, debug mode enabled"
log_sending_message:
    .string "[NET] Sending message via AT+QUICKMSG..."
log_send_success:
    .string "[NET] Message sent successfully"
log_send_failed:
    .string "[NET] Message send failed"
log_incoming_message:
    .string "[NET] Incoming chat message:"
log_at_response:
    .string "[NET] AT response:"
log_uart_interrupts:
    .string "[NET] UART interrupts enabled"
str_at_test:
    .string "AT"
str_netalias_cmd:
    .string "AT+NETALIAS=PCD68test"
str_init_cmd:
    .string "AT+INIT"
str_netjoin_cmd:
    .string "AT+NETJOIN"
log_uart_control_set:
    .string "[NET] UART control register configured"
log_uart_interrupt:
    .string "[NET] UART interrupt triggered!"
log_at_prefix:
    .string "[NET] AT: "


uart_rx_buffer:
    .ds.b   256  
uart_line_buffer:
    .ds.b   128  
uart_line_pos:
    .ds.w   1    


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

; ======================================================================
 * DEBUG MODE FUNCTIONS 
 * ====================================================================== 


	align	2
process_debug_mode:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    move.l   a0, -(sp)
    
    
    cmp.l    #1, debug_mode_active
    beq	    toggle_debug_off
    
    
    move.l   #1, debug_mode_active
    
    
    jsr	    clear_text_screen
    jsr	    display_debug_interface
    
    bra	    debug_mode_done
    
	align	2
toggle_debug_off:
    
    move.l   #0, debug_mode_active
    jsr	    set_display_update_flag  
    
	align	2
debug_mode_done:
    move.l   (sp)+, a0
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


	align	2
display_debug_interface:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    
    
    move.l  #TDABase + 1, a1
    lea     debug_header_msg, a0
    jsr	    copy_string_to_screen
    
    
    move.l  #TDABase + 1 + (2 * ScreenWidth), a1
    lea     debug_commands_msg, a0
    jsr	    copy_string_to_screen
    
    move.l  #TDABase + 1 + (4 * ScreenWidth), a1
    lea     debug_cmd1_msg, a0
    jsr	    copy_string_to_screen
    
    move.l  #TDABase + 1 + (5 * ScreenWidth), a1
    lea     debug_cmd2_msg, a0
    jsr	    copy_string_to_screen
    
    move.l  #TDABase + 1 + (6 * ScreenWidth), a1
    lea     debug_cmd3_msg, a0
    jsr	    copy_string_to_screen
    
    move.l  #TDABase + 1 + (7 * ScreenWidth), a1
    lea     debug_cmd4_msg, a0
    jsr	    copy_string_to_screen
    
    move.l  #TDABase + 1 + (8 * ScreenWidth), a1
    lea     debug_cmd5_msg, a0
    jsr	    copy_string_to_screen
    
    move.l  #TDABase + 1 + (9 * ScreenWidth), a1
    lea     debug_cmd6_msg, a0
    jsr	    copy_string_to_screen
    
    
    move.l  #TDABase + 1 + (22 * ScreenWidth), a1
    lea     debug_prompt_msg, a0
    jsr	    copy_string_to_screen
    
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


	align	2
process_debug_input:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    move.l   a0, -(sp)
    
    
    move.l  #KCTLKeys, a0
    move.b   (a0), d0
    
    
    cmp.b    #KEY_ESC, d0
    beq	    exit_debug_mode
    
    
    cmp.b    #KEY_1, d0
    beq	    debug_cmd_status
    cmp.b    #KEY_2, d0
    beq	    debug_cmd_neighbors
    cmp.b    #KEY_3, d0
    beq	    debug_cmd_routes
    cmp.b    #KEY_4, d0
    beq	    debug_cmd_stats
    cmp.b    #KEY_5, d0
    beq	    debug_cmd_netaddr
    cmp.b    #KEY_6, d0
    beq	    debug_cmd_recv
    
    bra	    consume_debug_key

	align	2
exit_debug_mode:
    move.l   #0, debug_mode_active
    jsr	    set_display_update_flag  
    bra	    consume_debug_key

	align	2
debug_cmd_status:
    lea     debug_status_param, a0
    jsr	    aether_debug_command
    jsr	    display_debug_result
    bra	    consume_debug_key

	align	2
debug_cmd_neighbors:
    jsr	    aether_get_neighbors
    jsr	    display_debug_result
    bra	    consume_debug_key

	align	2
debug_cmd_routes:
    lea     debug_routes_param, a0
    jsr	    aether_debug_command
    jsr	    display_debug_result
    bra	    consume_debug_key

	align	2
debug_cmd_stats:
    lea     debug_stats_param, a0
    jsr	    aether_debug_command
    jsr	    display_debug_result
    bra	    consume_debug_key

	align	2
debug_cmd_netaddr:
    jsr	    aether_get_netaddr
    jsr	    display_debug_result
    bra	    consume_debug_key

	align	2
debug_cmd_recv:
    jsr	    aether_recv_messages
    jsr	    display_debug_result
    bra	    consume_debug_key

	align	2
consume_debug_key:
    
    move.b   #1, KCTLNextReport
    
    move.l   (sp)+, a0
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


	align	2
process_chat_input_minimal:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    move.l   a0, -(sp)
    
    
    move.l  #KCTLKeys, a0
    move.b   (a0), d0
    
    
    cmp.b    #KEY_ESC, d0
    beq	    exit_chat_mode_minimal
    
    
    cmp.l    #32, d0           
    blt	    consume_chat_key_minimal   
    cmp.l    #126, d0          
    bgt	    consume_chat_key_minimal   
    
    
    move.l  #TDABase + 1 + (12 * ScreenWidth), a1
    lea     chat_key_debug_msg, a0
    jsr	    copy_string_to_screen
    
    
    move.l  #TDABase + 1 + (12 * ScreenWidth) + 20, a1
    move.b   d0, (a1)
    
    bra	    consume_chat_key_minimal

	align	2
exit_chat_mode_minimal:
    move.l   #0, chat_mode_active
    jsr	    set_display_update_flag  
    bra	    consume_chat_key_minimal

	align	2
consume_chat_key_minimal:
    
    move.b   #1, KCTLNextReport
    
    move.l   (sp)+, a0
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


	align	2
aether_poll_safe:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    cmp.l    #1, chat_network_disabled
    beq	    aether_poll_safe_done
    
    
    move.b  UART1_STATUS, d0
    btst    #0, d0  
    beq	    aether_poll_safe_done  
    
    
    move.w  #10, d7                
    
aether_poll_safe_loop:
    tst.w   d7
    beq	    aether_poll_safe_done   
    subq.w  #1, d7
    
    
    move.b  UART1_STATUS, d0
    btst    #0, d0  
    beq	    aether_poll_safe_done   
    
    
    move.b  UART1_RX, d0           
    
    
    cmpi.b  #$0A, d0              
    beq	    aether_poll_safe_done   
    cmpi.b  #$0D, d0              
    beq	    aether_poll_safe_done   
    
    
    move.w  #100, d6
aether_delay_loop:
    subq.w  #1, d6
    bne	    aether_delay_loop
    
    bra	    aether_poll_safe_loop
    
aether_poll_safe_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts


	align	2
update_chat_display_if_needed:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    cmp.l    #1, chat_display_dirty
    bne	    update_chat_display_skip
    
    
    move.l   #0, chat_display_dirty
    
    
    jsr	    display_chat_history_quick
    jsr	    update_chat_status_line
    
update_chat_display_skip:
    movem.l (sp)+, d0-d7/a0-a6
    rts


	align	2
display_chat_history_quick:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    cmp.l    #0, chat_history_lines
    beq	    history_quick_done
    
    
    move.l  #TDABase + 1 + (4 * ScreenWidth), a1
    move.l   #(14 * ScreenWidth), d0
clear_message_area:
    move.b   #' ', (a1)+
    subql   #1, d0
    bne	    clear_message_area
    
    
    jsr	    display_chat_history
    
history_quick_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts


	align	2
update_chat_status_line:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    move.l  #TDABase + 1 + (19 * ScreenWidth), a1
    lea     chat_status_msg, a0
    jsr	    copy_string_to_screen
    
    
    move.l   chat_history_lines, d0
    jsr	    display_number
    
    movem.l (sp)+, d0-d7/a0-a6
    rts


	align	2
display_debug_result:
    move.l   d0, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    
    
    move.l  #TDABase + 1 + (11 * ScreenWidth), a1
    move.l   #(9 * ScreenWidth), d0
	align	2
clear_result_area:
    move.b   #' ', (a1)+
    subql   #1, d0
    bne	    clear_result_area
    
    
    move.l  #TDABase + 1 + (11 * ScreenWidth), a1
    lea     debug_result_msg, a0
    jsr	    copy_string_to_screen
    
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d0
    rts


debug_header_msg:
    .string "=== AETHER DEBUG CONSOLE - PCD68 VALIDATION MODE ==="
debug_commands_msg:
    .string "Available	Debug Commands:"
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


chat_key_debug_msg:
    .string "Chat Key Pressed:"


chat_minimal_header_msg:
    .string "=== MINIMAL CHAT MODE - TESTING KEYBOARD ONLY ==="
chat_minimal_commands_msg:
    .string "Press any key to see key code, ESC to exit"
chat_minimal_prompt_msg:
    .string "Key presses will appear above - ESC to exit chat mode"


chat_status_msg:
    .string "Messages: "


debug_status_param:
    .string "STATUS"
debug_routes_param:
    .string "ROUTES"
debug_stats_param:
    .string "STATS"

; ======================================================================
 * AETHER MODEM LIBRARY INTEGRATION
 * ====================================================================== 

	section code


	include	"aether_modem_mot.s"

; Update chat display with real-time status and refresh
 * Called frequently during chat mode for responsive UI
 
	align	2
update_chat_display:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    cmp.l    #1, chat_mode_active
    bne	    update_chat_done
    
    
    jsr	    display_chat_interface
    
    
    jsr	    update_network_status_display
    
    
    jsr	    update_chat_indicators
    
update_chat_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts


	align	2
update_network_status_display:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    move.l  #TDABase + 1 + (1 * ScreenWidth), a1
    movea.l #chat_status_prefix, a0
    jsr	    copy_string_to_screen
    
    
    move.b   network_status, d0
    cmpi.b  #NET_CONNECTED, d0
    beq	    show_net_connected_status
    cmpi.b  #NET_CONNECTING, d0
    beq	    show_net_connecting_status
    
    
    movea.l #status_disconnected_msg, a0
    bra	    copy_status_msg
    
show_net_connecting_status:
    movea.l #status_connecting_msg, a0
    bra	    copy_status_msg
    
show_net_connected_status:
    movea.l #status_connected_msg, a0
    
copy_status_msg:
    jsr	    copy_string_to_screen
    
    
    cmpi.b  #NET_CONNECTED, network_status
    bne	    status_display_done
    
status_display_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts


	align	2
update_chat_indicators:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    move.l  #TDABase + 1 + (23 * ScreenWidth) + 75, a1
    
    
    move.b   activity_indicator, d0
    cmpi.b  #'*', d0
    beq	    toggle_to_plus
    
    move.b   #'*', d0
    bra	    update_indicator
    
toggle_to_plus:
    move.b   #'+', d0
    
update_indicator:
    move.b   d0, activity_indicator
    move.b   d0, (a1)
    
    movem.l (sp)+, d0-d7/a0-a6
    rts

; Display a number at current cursor position
 * Input: D0 = number to display
 * Note: A1 should point to current cursor position
 
	align	2
display_number:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    tst.l   d0
    bne	    number_not_zero
    move.b   #'0', (a1)+
    bra	    display_number_done
    
number_not_zero:
    
    tst.l   d0
    bpl	    number_positive
    move.b   #'-', (a1)+
    negl    d0
    
number_positive:
    
    lea     -12(sp), sp      
    move.l  sp, a2           
    move.l  a2, a3           
    
    
    clr.b   11(a3)
    
    
    lea     10(a3), a2       
    
convert_loop:
    tst.l   d0
    beq	    convert_done
    
    
    move.l  d0, d1
    divu    #10, d1
    swap    d1                
    add.b   #'0', d1          
    move.b  d1, (a2)         
    subq.l  #1, a2            
    
    
    move.l  d0, d1
    divu    #10, d1
    move.w  d1, d0           
    ext.l   d0
    
    bra	    convert_loop
    
convert_done:
    
    addq.l  #1, a2            
    
copy_digits:
    move.b  (a2)+, d1
    beq	    copy_digits_done
    move.b  d1, (a1)+
    bra	    copy_digits
    
copy_digits_done:
    lea     12(sp), sp       
    
display_number_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts

; Quick chat display update - lightweight version for main loop integration
 * Only updates essential status information without full screen refresh
 
	align	2
update_chat_display_quick:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    cmp.l    #1, chat_mode_active
    bne	    update_chat_quick_done
    
    
    jsr	    update_network_status_display
    
    
    jsr	    update_chat_indicators
    
    
    jsr	    check_and_display_new_messages
    
update_chat_quick_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts


	align	2
check_and_display_new_messages:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    
    jsr	    display_chat_history
    
    movem.l (sp)+, d0-d7/a0-a6
    rts

; ======================================================================
 * IRC-Style Chat Functions
 * ====================================================================== 




	align	2
draw_chat_history_irc:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    jsr	    clear_content_area
    
    
    move.l  #TDABase + 1 + (4 * ScreenWidth), a1
    
    
    lea     chat_history_buffer, a0
    move.l   chat_history_lines, d0
    cmp.l    #14, d0                
    ble	    history_lines_fit
    move.l   #14, d0                
    
history_lines_fit:
    cmp.l    #0, d0
    beq	    chat_history_done
    
chat_history_loop:
    
    move.l   #0, d1
copy_chat_line:
    cmp.l    #78, d1                
    bge	    next_chat_line
    move.b   (a0)+, d2
    move.b   d2, (a1)+
    add.l    #1, d1
    bra	    copy_chat_line
    
next_chat_line:
    
    move.l   a1, d2
    sub.l    #TDABase + 1, d2        
    divu    #ScreenWidth, d2        
    swap    d2                       
    moveq   #ScreenWidth, d1
    sub.l    d2, d1                  
    add.l    d1, a1                  
    
    sub.l    #1, d0
    bne	    chat_history_loop
    
chat_history_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts



	align	2
display_chat_input_line:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    move.l  a2, a1
    
    
    lea     chat_input_buffer, a0
    move.l   chat_input_length, d0
    cmp.l    #0, d0
    beq	    input_line_done
    
    
    cmp.l    #70, d0
    ble	    input_fits
    move.l   #70, d0
    
input_fits:
display_input_chars:
    tst.l   d0
    beq	    input_line_done
    move.b   (a0)+, (a1)+
    sub.l    #1, d0
    bra	    display_input_chars
    
input_line_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts


	align	2
add_char_to_chat_input:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    move.l   chat_input_length, d1
    cmp.l    #78, d1                
    bge	    add_char_done
    
    
    lea     chat_input_buffer, a0
    add.l    d1, a0                
    move.b   d0, (a0)              
    add.l    #1, chat_input_length
    
    
    jsr	    set_display_update_flag
    
add_char_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts


	align	2
remove_chat_input_char:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    cmp.l    #0, chat_input_length
    beq	    remove_char_done
    
    
    sub.l    #1, chat_input_length
    
    
    jsr	    set_display_update_flag
    
remove_char_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts


	align	2
send_current_chat_input:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    cmp.l    #0, chat_input_length
    beq	    send_input_done
    
    
    move.l   chat_input_length, d1
    lea     chat_input_buffer, a0
    add.l    d1, a0                
    move.b   #0, (a0)               
    
    
    cmp.l    #1, chat_network_disabled
    beq	    send_input_local_only
    
    
    lea     log_sending_message, a0
    jsr	    add_chat_line
    
    
    
    move.l   #5000, chat_timeout_counter  
    
    lea     chat_input_buffer, a0
    jsr	    aether_chat_send_safe
    
    
    cmp.l    #0, d0  
    beq	    send_success_log
    lea     log_send_failed, a0
    jsr	    add_chat_line
    bra	    send_input_local_only
    
send_success_log:
    lea     log_send_success, a0
    jsr	    add_chat_line
    
send_input_local_only:
    
    lea     chat_input_buffer, a0
    jsr	    add_chat_line
    
    
    move.l   #0, chat_input_length
    
    
    jsr	    set_display_update_flag
    
send_input_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts

; ======================================================================
 * PHASE 1: SIMPLE BUFFER MANAGEMENT FUNCTIONS
 * ====================================================================== 


	align	2
simple_add_char:
    
    move.l   d1, -(sp)
    move.l   a1, -(sp)
    
    
    move.l   chat_input_length, d1
    cmp.l    #70, d1                
    bge	    simple_add_done
    
    
    lea     chat_input_buffer, a1
    move.b   d0, (a1,d1)          
    addql   #1, chat_input_length
    
simple_add_done:
    move.l   (sp)+, a1
    move.l   (sp)+, d1
    rts


	align	2
simple_remove_char:
    
    cmp.l    #0, chat_input_length
    beq	    simple_remove_done
    
    
    subql   #1, chat_input_length
    
simple_remove_done:
    rts


	align	2
simple_send_message:
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    
    
    cmp.l    #0, chat_input_length
    beq	    simple_send_done
    
    
    lea     temp_chat_line, a1
    
    
    move.b   #'>', (a1)+
    move.b   #'>', (a1)+
    move.b   #'>', (a1)+
    move.b   #' ', (a1)+
    
    
    move.l   chat_input_length, d1
    lea     chat_input_buffer, a0
copy_message_loop:
    tst.l   d1
    beq	    message_copied
    move.b   (a0)+, (a1)+
    subql   #1, d1
    bra	    copy_message_loop
    
message_copied:
    
    move.b   #0, (a1)
    
    
    lea     temp_chat_line, a0
    jsr	    add_chat_line
    
    
    jsr	    display_chat_history
    
    
    move.l  #TDABase + 1 + (19 * ScreenWidth), a1
    lea     message_sent_msg, a0
    jsr	    copy_string_to_screen
    
    
    move.l   #0, chat_input_length
    
    
    jsr	    set_display_update_flag
    
simple_send_done:
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    rts


	align	2
simple_update_footer:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    
    
    move.l  #TDABase + 1 + (21 * ScreenWidth), a1
    move.l   #79, d0
clear_footer_loop:
    move.b   #' ', (a1)+
    subql   #1, d0
    bne	    clear_footer_loop
    
    
    move.l  #TDABase + 1 + (21 * ScreenWidth) + 3, a1
    
    
    move.l   input_mode, d0
    cmp.l    #MODE_TERMINAL, d0
    beq	    show_terminal_prompt
    
    
    move.b   #'C', (a1)+
    move.b   #'H', (a1)+
    move.b   #'A', (a1)+
    move.b   #'T', (a1)+
    move.b   #':', (a1)+
    move.b   #' ', (a1)+
    bra	    prompt_done
    
show_terminal_prompt:
    
    move.b   #'A', (a1)+
    move.b   #'T', (a1)+
    move.b   #'>', (a1)+
    move.b   #' ', (a1)+
    
prompt_done:
    
    
    move.l   chat_input_length, d0
    cmp.l    #0, d0
    beq	    footer_done
    
    
    cmp.l    #70, d0
    ble	    show_buffer
    move.l   #70, d0
    
show_buffer:
    lea     chat_input_buffer, a0
show_buffer_loop:
    tst.l   d0
    beq	    footer_done
    move.b   (a0)+, (a1)+
    subql   #1, d0
    bra	    show_buffer_loop
    
footer_done:
    
    cmp.l    #0, chat_input_length
    beq	    no_char_count
    
    
    move.l  #TDABase + 1 + (21 * ScreenWidth) + 70, a1
    move.b   #'[', (a1)+
    
    
    move.l   chat_input_length, d0
    jsr	    simple_show_number
    
    move.b   #'/', (a1)+
    move.b   #'7', (a1)+
    move.b   #'0', (a1)+
    move.b   #']', (a1)+
    
no_char_count:
    
    move.l  #TDABase + 1 + (21 * ScreenWidth) + 68, a1
    move.b   #'T', (a1)+
    move.b   #'A', (a1)+
    move.b   #'B', (a1)+
    move.b   #'=', (a1)+
    move.b   #'?', (a1)+            
    move.b   #' ', (a1)+
    
    
    move.l   modifier_debug_byte, d0
    and.l    #$FF, d0              
    lsrl    #4, d0                 
    addil   #'0', d0
    cmp.l    #'9', d0
    ble	    mod_high_ok
    addil   #7, d0                 
mod_high_ok:
    move.b   d0, (a1)+
    
    
    move.l   modifier_debug_byte, d0
    and.l    #$F, d0
    addil   #'0', d0
    cmp.l    #'9', d0
    ble	    mod_low_ok
    addil   #7, d0
mod_low_ok:
    move.b   d0, (a1)+
    
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


	align	2
simple_show_number:
    
    cmp.l    #10, d0
    blt	    single_digit
    
    
    move.l   d0, d1
    divu    #10, d1
    addib   #'0', d1
    move.b   d1, (a1)+
    
    
    mulu    #10, d1
    sub.l    d1, d0
    
single_digit:
    addib   #'0', d0
    move.b   d0, (a1)+
    rts

; Removed large function definitions to fix relocation issues
 * Core functionality is now inlined in the keyboard input hand.ler
 


local_echo_prefix:
    .string ">>> "


	align	2
hand.le_incoming_chat_safe:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    lea     temp_chat_line, a1
    movea.l #incoming_msg_prefix, a0
    jsr	    copy_string_safe
    
    
    movea.l #at_response_buffer, a0
    jsr	    copy_string_safe
    
    
    lea     temp_chat_line, a0
    jsr	    add_chat_line
    
    
    move.l   #1, chat_display_dirty
    
    movem.l (sp)+, d0-d7/a0-a6
    rts


	align	2
copy_string_safe:
    movem.l d0-d7/a0-a6, -(sp)
    
    move.l   #79, d0  
copy_safe_loop:
    tst.l   d0
    beq	    copy_safe_done
    move.b   (a0)+, d1
    tst.b   d1
    beq	    copy_safe_done
    move.b   d1, (a1)+
    sub.l    #1, d0
    bra	    copy_safe_loop
    
copy_safe_done:
    move.b   #0, (a1)  
    movem.l (sp)+, d0-d7/a0-a6
    rts


incoming_msg_prefix:
    .string "< "


	align	2
aether_chat_send_safe:
    movem.l d0-d7/a0-a6, -(sp)
    
    
    cmp.l    #1, chat_network_disabled
    beq	    aether_send_disabled
    
    
    cmp.l    #0, chat_timeout_counter
    beq	    aether_send_timeout
    
    
    subil   #1, chat_timeout_counter
    
    
    move.b  UART1_STATUS, d0
    btst    #1, d0  
    beq	    aether_send_not_ready  
    
    
    
    jsr	    aether_chat_send        
    bra	    aether_send_done

aether_send_disabled:
    
    moveq   #0, d0  
    bra	    aether_send_done
    
aether_send_not_ready:
    
    moveq   #0, d0  
    bra	    aether_send_done
    
aether_send_timeout:
    
    moveq   #0, d0  
    
aether_send_done:
    movem.l (sp)+, d0-d7/a0-a6
    rts

; ===============================================
   NETWORK-READY CHAT FEATURES - PHASE 2
   All functions designed for easy aether hookup
   =============================================== 


	align	2
enhanced_send_message:
    movem.l d0-d2/a0-a2, -(sp)
    
    
    cmp.l    #0, chat_input_length
    beq	    enhanced_send_done
    
    
    jsr	    get_current_time
    move.l   d0, last_message_time
    
    
    addql   #1, message_counter
    
    
    move.b   chat_network_disabled, d0
    tst.b   d0
    bne	    local_message_only
    
    
    jsr	    send_message_via_at_command
    
local_message_only:
    
    lea     temp_chat_line, a1
    
    
    move.b   #'[', (a1)+
    jsr	    format_timestamp
    move.b   #']', (a1)+
    move.b   #' ', (a1)+
    
    
    lea     current_room, a0
    tst.b   (a0)
    beq	    no_room_prefix
    
    move.b   #'#', (a1)+
    jsr	    copy_room_name_to_display
    move.b   #':', (a1)+
    move.b   #' ', (a1)+
    
no_room_prefix:
      
    move.b   #'>', (a1)+
    move.b   #'>', (a1)+
    move.b   #'>', (a1)+
    move.b   #' ', (a1)+
    
    
    move.l   chat_input_length, d1
    lea     chat_input_buffer, a0
enhanced_copy_loop:
    tst.l   d1
    beq	    enhanced_copied
    move.b   (a0)+, (a1)+
    subql   #1, d1
    bra	    enhanced_copy_loop
    
enhanced_copied:
    
    move.b   #0, (a1)
    
    
    lea     temp_chat_line, a0
    jsr	    add_chat_line
    
    
    jsr	    display_chat_history
    
    
    jsr	    show_send_confirmation
    
    
    jsr	    set_display_update_flag
    
enhanced_send_done:
    movem.l (sp)+, d0-d2/a0-a2
    rts


	align	2
send_message_via_at_command:
    movem.l d0-d2/a0-a2, -(sp)
    
    
    lea     at_quickmsg_buffer, a1
    
    
    lea     str_quickmsg_prefix, a0
    jsr	    copy_string_simple
    
    
    lea     chat_input_buffer, a0
    move.l   chat_input_length, d0
copy_message_to_at:
    tst.l   d0
    beq	    at_message_copied
    move.b   (a0)+, (a1)+
    subql   #1, d0
    bra	    copy_message_to_at
    
at_message_copied:
    
    move.b   #0, (a1)
    
    
    lea     at_quickmsg_buffer, a0
    jsr	    send_string_async
    
    
    lea     log_sending_message, a0
    jsr	    add_at_response_to_chat
    
    movem.l (sp)+, d0-d2/a0-a2
    rts




	align	2
add_to_input_history:
    movem.l d0-d2/a0-a2, -(sp)
    
    
    cmp.l    #0, chat_input_length
    beq	    add_history_done
    
    
    move.l   input_history_count, d0
    cmp.l    #10, d0               
    blt	    history_not_full
    
    
    jsr	    shift_input_history
    move.l   #9, d0               
    bra	    insert_at_position
    
history_not_full:
    
    addql   #1, input_history_count
    
insert_at_position:
    
    mulu    #80, d0
    lea     input_history_buffer, a0
    adda.l  d0, a0
    
    
    lea     chat_input_buffer, a1
    move.l   chat_input_length, d1
copy_to_history:
    tst.l   d1
    beq	    history_copied
    move.b   (a1)+, (a0)+
    subql   #1, d1
    bra	    copy_to_history
    
history_copied:
    move.b   #0, (a0)  
    
add_history_done:
    movem.l (sp)+, d0-d2/a0-a2
    rts


	align	2
navigate_input_history_up:
    movem.l d0-d2/a0-a2, -(sp)
    
    
    cmp.l    #0, input_history_count
    beq	    nav_up_done
    
    
    move.l   input_history_index, d0
    addql   #1, d0
    
    
    cmp.l    input_history_count, d0
    bge	    nav_up_done
    
    
    move.l   d0, input_history_index
    
    
    jsr	    load_history_entry
    
    
    jsr	    simple_update_footer
    
nav_up_done:
    movem.l (sp)+, d0-d2/a0-a2
    rts


	align	2
navigate_input_history_down:
    movem.l d0-d2/a0-a2, -(sp)
    
    
    move.l   input_history_index, d0
    cmp.l    #0, d0
    beq	    nav_down_clear      
    
    
    subql   #1, d0
    move.l   d0, input_history_index
    
    
    jsr	    load_history_entry
    
    
    jsr	    simple_update_footer
    bra	    nav_down_done
    
nav_down_clear:
    
    clr.l    chat_input_length
    jsr	    simple_update_footer
    
nav_down_done:
    movem.l (sp)+, d0-d2/a0-a2
    rts


	align	2
load_history_entry:
    movem.l d0-d2/a0-a2, -(sp)
    
    
    move.l   input_history_count, d0
    sub.l    input_history_index, d0
    subql   #1, d0               
    mulu    #80, d0
    
    
    lea     input_history_buffer, a0
    adda.l  d0, a0              
    lea     chat_input_buffer, a1 
    
    
    clr.l    d1                   
load_history_loop:
    move.b   (a0)+, d0
    tst.b   d0
    beq	    load_history_done
    move.b   d0, (a1)+
    addql   #1, d1
    cmp.l    #79, d1             
    blt	    load_history_loop
    
load_history_done:
    move.l   d1, chat_input_length
    
    movem.l (sp)+, d0-d2/a0-a2
    rts


	align	2
shift_input_history:
    movem.l d0-d2/a0-a2, -(sp)
    
    
    move.l   #9, d2              
    lea     input_history_buffer, a0
    lea     input_history_buffer+80, a1  
    
shift_loop:
    tst.l   d2
    beq	    shift_done
    
    
    move.l   #80, d1
shift_copy:
    tst.l   d1
    beq	    shift_next
    move.b   (a1)+, (a0)+
    subql   #1, d1
    bra	    shift_copy
    
shift_next:
    subql   #1, d2
    bra	    shift_loop
    
shift_done:
    movem.l (sp)+, d0-d2/a0-a2
    rts


	align	2
get_current_time:
    
    addql   #1, simple_time_counter
    move.l   simple_time_counter, d0
    rts

	align	2
format_timestamp:
    
    
    move.l   last_message_time, d0
    
    
    move.l   d0, d1
    lsrl    #8, d1
    and.l    #$0F, d1
    cmp.b    #10, d1
    blt	    hours_digit
    addib   #7, d1               
hours_digit:
    addib   #'0', d1
    move.b   d1, (a1)+
    
    move.b   d0, d1
    lsrl    #4, d1
    and.l    #$0F, d1
    cmp.b    #10, d1
    blt	    hours_digit2
    addib   #7, d1
hours_digit2:
    addib   #'0', d1
    move.b   d1, (a1)+
    
    move.b   #':', (a1)+
    
    
    move.b   d0, d1
    and.l    #$0F, d1
    cmp.b    #10, d1
    blt	    mins_digit
    addib   #7, d1
mins_digit:
    addib   #'0', d1
    move.b   d1, (a1)+
    
    move.b   d0, d1
    lsrl    #4, d1
    and.l    #$0F, d1
    cmp.b    #10, d1
    blt	    mins_digit2
    addib   #7, d1
mins_digit2:  
    addib   #'0', d1
    move.b   d1, (a1)+
    
    rts


	align	2
copy_room_name_to_display:
    
    move.l   #8, d0
room_copy_loop:
    tst.l   d0
    beq	    room_copy_done
    move.b   (a0)+, d1
    tst.b   d1
    beq	    room_copy_done
    move.b   d1, (a1)+
    subql   #1, d0
    bra	    room_copy_loop
room_copy_done:
    rts


	align	2
show_send_confirmation:
    movem.l d0-d1/a0-a1, -(sp)
    
    
    move.l  #TDABase + 1 + (19 * ScreenWidth) + 2, a1
    
    
    move.l   #77, d0  
clear_status:
    move.b   #' ', (a1)+
    subql   #1, d0
    bne	    clear_status
    
    
    move.l  #TDABase + 1 + (19 * ScreenWidth) + 2, a1
    lea     enhanced_sent_msg, a0
    jsr	    copy_string_to_screen
    
    movem.l (sp)+, d0-d1/a0-a1
    rts


	align	2
init_chat_rooms:
    movem.l d0-d1/a0, -(sp)
    
    
    lea     current_room, a0
    move.b   #0, (a0)
    
    
    
    
    movem.l (sp)+, d0-d1/a0
    rts


simple_time_counter:
    .dc.l    0

enhanced_sent_msg:
    .string ">>> Message sent! (network ready)                                       "

str_netjoin_connected:
    .string "+NETJOIN: CONNECTED"

str_netjoin_disconnected:
    .string "+NETJOIN: DISCONNECTED"

str_quickmsg_prefix:
    .string "AT+QUICKMSG="


at_quickmsg_buffer:
    .ds.b   128  



; ======================================================================
 * UART2 TERMINAL MODE FUNCTIONS  
 * ====================================================================== 


	align	2
process_uart2_mode:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   d2, -(sp)
    move.l   a0, -(sp)
    
    
    cmp.l    #1, uart2_mode_active
    beq	    toggle_uart2_off
    
    
    move.l   #1, uart2_mode_active
    
    
    jsr	    uart2_init
    
    
    jsr	    clear_text_screen
    jsr	    display_uart2_interface
    
    
    move.l   #0, uart2_input_length
    
    bra	    uart2_mode_done
    
toggle_uart2_off:
    
    move.l   #0, uart2_mode_active
    jsr	    set_display_update_flag  
    
uart2_mode_done:
    move.l   (sp)+, a0
    move.l   (sp)+, d2
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


	align	2
uart2_init:
    
    move.b   #$07, UART2_CONTROL  
    rts


	align	2
display_uart2_interface:
    move.l   d0, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    
    
    move.l  #TDABase + 1, a1
    lea     uart2_header_msg, a0
    jsr	    copy_string_to_screen
    
    
    move.l  #TDABase + 1 + (2 * ScreenWidth), a1
    lea     uart2_instructions_msg, a0
    jsr	    copy_string_to_screen
    
    
    move.l  #TDABase + 1 + (21 * ScreenWidth), a1
    lea     uart2_prompt_msg, a0
    jsr	    copy_string_to_screen
    
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d0
    rts


	align	2
process_uart2_keyboard_input:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    
    
    move.l  #KCTLKeys, a0
    move.b   (a0), d0
    
    
    cmp.b    #KEY_ESC, d0
    beq	    exit_uart2_mode
    
    
    cmp.b    #KEY_BACKSPACE, d0
    beq	    uart2_backspace
    
    
    cmp.b    #KEY_ENTER, d0
    beq	    uart2_send_line
    
    
    cmp.l    #32, d0           
    blt	    finish_uart2_key_input   
    cmp.l    #126, d0          
    bgt	    finish_uart2_key_input   
    
    
    move.l   uart2_input_length, d1
    cmp.l    #70, d1
    bge	    finish_uart2_key_input
    
    lea     uart2_input_buffer, a1
    move.b   d0, (a1,d1)
    addql   #1, uart2_input_length
    
    
    move.b   d0, UART2_TX
    
    
    jsr	    uart2_update_input_display
    bra	    finish_uart2_key_input

exit_uart2_mode:
    move.l   #0, uart2_mode_active
    jsr	    set_display_update_flag
    bra	    finish_uart2_key_input

uart2_backspace:
    
    cmp.l    #0, uart2_input_length
    beq	    finish_uart2_key_input
    subql   #1, uart2_input_length
    jsr	    uart2_update_input_display
    bra	    finish_uart2_key_input

uart2_send_line:
    
    move.b   #13, UART2_TX      
    move.b   #10, UART2_TX      
    
    
    move.l   #0, uart2_input_length
    jsr	    uart2_update_input_display
    bra	    finish_uart2_key_input

finish_uart2_key_input:
    
    move.b   #1, KCTLNextReport
    
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


	align	2
uart2_update_input_display:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    move.l   a1, -(sp)
    
    
    move.l  #TDABase + 1 + (21 * ScreenWidth), a1
    lea     uart2_prompt_msg, a0
    jsr	    copy_string_to_screen
    
    
    move.l  #TDABase + 1 + (21 * ScreenWidth) + 3, a1  
    lea     uart2_input_buffer, a0
    move.l   uart2_input_length, d1
    
uart2_copy_input_loop:
    tst.l   d1
    beq	    uart2_input_done
    move.b   (a0)+, (a1)+
    subql   #1, d1
    bra	    uart2_copy_input_loop
    
uart2_input_done:
    move.l   (sp)+, a1
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


	align	2
uart2_poll_incoming:
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    
    
    move.b   UART2_STATUS, d0
    btst    #0, d0            
    beq	    uart2_poll_done
    
    
    move.b   UART2_RX, d1
    
    
    move.l  #TDABase + 1 + (10 * ScreenWidth), a1
    lea     uart2_rx_prefix, a0
    jsr	    copy_string_to_screen
    
    
    move.l  #TDABase + 1 + (10 * ScreenWidth) + 5, a1  
    move.b   d1, (a1)
    
uart2_poll_done:
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rts


	align	2
uart2_interrupt_handler:
    
    move.l   d0, -(sp)
    move.l   d1, -(sp)
    move.l   a0, -(sp)
    
    
    addql   #1, uart2_interrupt_counter
    
    
    move.l  #TDABase + 1 + 78, a0    
    move.b   #'I', (a0)
    
    
    move.b   UART2_STATUS, d0
    btst    #0, d0                  
    beq	    uart2_int_check_tx
    
    
    move.b   UART2_RX, d1
    
    
    move.l  #TDABase + 1 + 70, a0
    move.b   d1, (a0)
    
    
    cmp.l    #1, uart2_mode_active
    bne	    uart2_int_check_tx
    
    
    move.l  #TDABase + 1 + 75, a0
    move.b   #'R', (a0)
    
    
    move.l  #TDABase + 1 + (8 * ScreenWidth), a1
    lea     uart2_rx_prefix, a0
    jsr	    copy_string_to_screen
    
    
    move.l  #TDABase + 1 + (8 * ScreenWidth) + 4, a1
    move.b   d1, (a1)
    
    
    move.l  #TDABase + 1 + (9 * ScreenWidth), a1
    move.b   #' ', (a1)  
    
uart2_int_check_tx:
    
    btst    #1, d0                  
    beq	    uart2_int_done
    
    
    move.l  #TDABase + 1 + 76, a0
    move.b   #'T', (a0)
    
uart2_int_done:
    
    move.l   (sp)+, a0
    move.l   (sp)+, d1
    move.l   (sp)+, d0
    rte


uart2_header_msg:
    .string "=== PCD68 UART2 Terminal Mode === Direct Serial Communication"
uart2_instructions_msg:
    .string "Type to send via UART2 | Enter=newline | ESC=exit | Null-modem ready!"
uart2_prompt_msg:
    .string "> "
uart2_rx_prefix:
    .string "RX: "


