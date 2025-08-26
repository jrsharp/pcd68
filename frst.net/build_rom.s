; FRST.netROM - Complete assembly source for vasm
; This file includes all components in the correctorder

; Memory locations and constants
ScrnBase	equ	$430002
TDABase	equ	$410000
KCTLBase	equ	$420000
UARTBase	equ	$450000
UART1_BASE	equ	$450000
UART1_TX	equ	$450000
UART1_RX	equ	$450001
UART1_STATUS	equ	$450002
UART1_CONTROL	equ	$450003

; UART2 register definitions
UART2_BASE	equ	$450000
UART2_TX	equ	$450004
UART2_RX	equ	$450005
UART2_STATUS	equ	$450006
UART2_CONTROL	equ	$450007

; Memory sizes
TDASize	equ	80 * 23

; Aether modem buffer constants
AT_CMD_BUFFER_SIZE	equ	256
AT_RESPONSE_BUFFER_SIZE	equ	512

; New KCTL register definitions
KCTLStatus	equ	$420000      ; Status/control register
KCTLCount	equ	$420001       ; Number of reports in queue
KCTLReportSize	equ	$420002  ; Number of active keys in currentreport
KCTLModifiers	equ	$420003   ; Modifier byte
KCTLKeys	equ	$420004        ; Startof key array (7 bytes,one per key)
KCTLNextReport	equ	$42000B  ; Advance to nextreport(write any value)

; Status register bitmasks
STATUS_REPORT_AVAILABLE	equ	$01
STATUS_QUEUE_FULL	equ	$02
STATUS_CLEAR_INTERRUPT	equ	$04
STATUS_KEYBOARD_ENABLED	equ	$08

; UI Constants
ScreenWidth	equ	80
ScreenHeight	equ	23
TextMode	equ	2               ; 1 for 50-col,2 for 80-col
GraphicsMode	equ	0           ; 0 = NONE mode (TDA disabled for artmode)
MaxMenuItems	equ	20          ; Maximum items in a menu
MaxContentSize	equ	1024      ; Maximum contentbuffer size

; Artmode constants
PictureWidth	equ	400
PictureHeight	equ	300

; Key definitions
KEY_ENTER	equ	13
KEY_ESC	equ	27
KEY_BACKSPACE	equ	8

; Pre-calculated addresses  
TDA_TEXT_BASE	equ	TDABase + 1
TDA_TEXT_END	equ	TDABase + 1 + 1840  ; 80 * 23
TDA_LINE1	equ	TDABase + 1 + 80    ; Line 1 (80 chars)  
TDA_LINE3	equ	TDABase + 1 + 240   ; Line 3 (80 * 3)
TDA_LINE19	equ	TDABase + 1 + 1520  ; Line 19 (80 * 19)
TDA_LINE21	equ	TDABase + 1 + 1680  ; Line 21 (80 * 21)
; More pre-calculated screen positions
TDA_HEADER	equ	TDABase + 1 + 80    ; Header line (line 1)  
TDA_HEADER_55	equ	TDABase + 1 + 80 + 55  ; Position 55 in header
TDA_HEADER_END	equ	TDABase + 1 + 159   ; End of header line  
TDA_STATUS	equ	TDABase + 1 + 1520  ; Status line (line 19)
TDA_STATUS_30	equ	TDABase + 1 + 1520 + 30  ; Status + 30
TDA_STATUS_50	equ	TDABase + 1 + 1520 + 50  ; Status + 50
TDA_STATUS_52	equ	TDABase + 1 + 1520 + 52  ; Status + 52
TDA_STATUS_54	equ	TDABase + 1 + 1520 + 54  ; Status + 54
TDA_STATUS_55	equ	TDABase + 1 + 1520 + 55  ; Status + 55
TDA_STATUS_END	equ	TDABase + 1 + 1599  ; End of status line
TDA_FOOTER_END	equ	TDABase + 1 + 1759  ; End of footer line (21*80-1)
; Pre-calculated screen calculations  
SCREENWIDTH_MINUS1	equ	79

	section code
	org	$000000

; Exception vector table (68000 format)
initial_stack_pointer:
    dc.l    $00800000             ; Initial stack pointer

reset_vector:
    dc.l    start                ; Resetvector

; Exception vectors - using defaulthandler for most
    dc.l    default_handler       ; Bus error
    dc.l    default_handler       ; Address error
    dc.l    default_handler       ; Illegal instruction
    dc.l    default_handler       ; Zero divide
    dc.l    default_handler       ; CHK instruction
    dc.l    default_handler       ; TRAPV instruction
    dc.l    default_handler       ; Privilege violation
    dc.l    default_handler       ; Trace
    dc.l    default_handler       ; Line A emulator
    dc.l    default_handler       ; Line F emulator
    dc.l    default_handler       ; Reserved
    dc.l    default_handler       ; Reserved
    dc.l    default_handler       ; Formaterror (68010+)
    dc.l    default_handler       ; Uninitialized interrupt
    dc.l    default_handler       ; Reserved
    dc.l    default_handler       ; Reserved
    dc.l    default_handler       ; Reserved
    dc.l    default_handler       ; Reserved
    dc.l    default_handler       ; Reserved
    dc.l    default_handler       ; Reserved
    dc.l    default_handler       ; Reserved
    dc.l    default_handler       ; Reserved
    dc.l    default_handler       ; Spurious interrupt
    dc.l    default_handler       ; Level 1 interruptautovector
    dc.l    keyboard_handler      ; Level 2 interruptautovector (keyboard)
    dc.l    default_handler       ; Level 3 interruptautovector
    dc.l    uart1_interrupt_handler  ; Level 4 interruptautovector (UART1)
    dc.l    uart2_interrupt_handler  ; Level 5 interruptautovector (UART2)
    dc.l    default_handler       ; Level 6 interruptautovector
    dc.l    default_handler       ; Level 7 interruptautovector (NMI)

; TRAP vectors
    rept    32
    dc.l    default_handler
    endr

	org	$002000
start:
    ; Initialize TDA (Terminal Display Adapter)
    movea.l #TDABase,a2
    move.b  #TextMode,(a2)+     ; Set80-column mode
    
    ; Clear the screen
    jsr     clear_screen
    
    ; Initialize variables
    clr.l   current_menu_id     
    clr.l   current_selection

    ; Setup display
    move.l  #1,display_needs_update
    
    ; Enable keyboard
    movea.l #KCTLStatus,a0
    move.b  #STATUS_KEYBOARD_ENABLED,(a0)
    
    ; Main loop
main_loop:
    ; Check if display needs updating
    tst.l   display_needs_update
    beq     check_input
    
    ; Update display
    jsr     update_display
    move.l  #0,display_needs_update
    
check_input:
    ; Process keyboard input
    jsr     process_keyboard_input
    
    ; Continue main loop
    bra     main_loop

; Defaultexception handler
default_handler:
    rts

; Keyboard interrupthandler
keyboard_handler:
    ; Save registers
    movem.l d0-d7/a0-a6,-(sp)
    
    ; Clear interrupt
    movea.l #KCTLStatus,a0
    move.b  #STATUS_CLEAR_INTERRUPT,(a0)
    
    ; Setflag for main loop to process
    move.l  #1,keyboard_input_ready
    
    ; Restore registers and return
    movem.l (sp)+,d0-d7/a0-a6
    rte

; UART interrupthandlers (placeholder)
uart1_interrupt_handler:
uart2_interrupt_handler:
    rts

; Missing functions - minimal placeholders
process_keyboard_input:
    ; Check if keyboard input is available
    tst.l   keyboard_input_ready
    beq.s   no_input
    ; Clear flag
    clr.l   keyboard_input_ready
    ; Placeholder - just mark display for update
    move.l  #1,display_needs_update
no_input:
    rts

update_display:
    ; Basic display update - draw header
    movea.l #TDA_HEADER,a0
    lea     header_title,a1
    jsr     copy_string
    rts

copy_string:
    move.b  (a1)+,d0
    beq.s   copy_done
    move.b  d0,(a0)+
    bra.s   copy_string
copy_done:
    rts

; Include utility functions and other components
	include "utility_functions_mot.s"

; Data section
	section data
handle_incoming_chat_simple:
    dc.l    0
footer_commands:
    dc.b    "[M]sg [C]hat [N]et [B]ull [F]iles [W]ho [S]et [ESC]Menu",0
selection_text:
    dc.b    "Select:",0
status_text:
    dc.b    "Aether:",0
version_text_length:
    dc.l    16
version_text:
    dc.b    "Aether BBS ROM v1.0",0
header_title:
    dc.b    "FRST.net Aether Test Network",0
view_state:
    dc.l    0
combined_content:
    dc.b    " ==[ FRST.net Aether Test Network BBS ]==\n\n"
    dc.b    " Welcome to the FRST.net Aether Test Network - a decentralized,\n"
    dc.b    " mesh-networked bulletin board system running on PCD-68 hardware\n"
    dc.b    " with LoRa radio connectivity.\n\n"
    dc.b    " ## About the Aether Network\n\n"
    dc.b    " The Aether Test Net is an experimental mesh network that creates\n"
    dc.b    " resilient, community-driven communication without traditional\n"
    dc.b    " infrastructure. Each node can relay messages, creating a self-\n"
    dc.b    " healing network that routes around failures.\n\n"
    dc.b    " This BBS demonstrates the practical application of mesh networking\n"
    dc.b    " for distributed community systems - a modern take on the classic\n"
    dc.b    " bulletin board experience.\n\n"
    dc.b    " ## Current Network Status\n\n"
    dc.b    " Network ID: AEAE0001\n"
    dc.b    " Frequency: 915.0 MHz\n"
    dc.b    " Active Nodes: Scanning...\n"
    dc.b    " Chat Room: #retro\n\n"
    dc.b    " ## BBS Features\n\n"
    dc.b    " [M] Messages - Read and post public messages\n"
    dc.b    " [C] Chat - Join real-time mesh chat rooms\n"
    dc.b    " [N] Network - View active nodes and routing\n"
    dc.b    " [B] Bulletins - System announcements\n"
    dc.b    " [F] Files - Browse shared file listings\n"
    dc.b    " [W] Who's Online - See active users\n"
    dc.b    " [S] Settings - Configure your node\n\n"
    dc.b    " ## Getting Started\n\n"
    dc.b    " Your PCD-68 terminal is equipped with an Aether modem that\n"
    dc.b    " automatically joins the mesh network. Messages are routed\n"
    dc.b    " through neighboring nodes using LoRa radio links.\n\n"
    dc.b    " To post a message, press 'M' and follow the prompts.\n"
    dc.b    " To chat, press 'C' to join the active chat room.\n"
    dc.b    " Press ESC at any time to return to this menu.\n\n"
    dc.b    " ## Technical Details\n\n"
    dc.b    " Protocol: Aether Mesh v1.0\n"
    dc.b    " Radio: LoRa 915MHz ISM Band\n"
    dc.b    " Range: 2-10km typical (terrain dependent)\n"
    dc.b    " Bandwidth: 125kHz\n"
    dc.b    " Spreading Factor: SF7-SF12 adaptive\n"
    dc.b    " Power: 20dBm max\n\n"
    dc.b    " ## About FRST Computer\n\n"
    dc.b    " FRST Computer creates artisan retrocomputers that bridge\n"
    dc.b    " vintage aesthetics with modern capabilities. The Aether\n"
    dc.b    " Test Net showcases our vision of resilient, community-\n"
    dc.b    " owned communication infrastructure.\n\n"
    dc.b    " This BBS ROM is part of our commitment to sustainable,\n"
    dc.b    " repairable, and hackable computing. Source code and\n"
    dc.b    " hardware designs are freely available.\n\n"
    dc.b    " ## System Commands\n\n"
    dc.b    " ESC - Main Menu\n"
    dc.b    " Ctrl+N - Network Status\n"
    dc.b    " Ctrl+R - Refresh Display\n"
    dc.b    " Ctrl+Q - Quick Message\n"
    dc.b    " Ctrl+H - Help\n\n"
    dc.b    " --\n"
    dc.b    " FRST.net Aether Test Network BBS v1.0\n"
    dc.b    " Running on PCD-68 Virtual Retrocomputer\n"
    dc.b    " Visit gopher://frstcomputer.com for more info\n"
    dc.b    " --\n\n"
    dc.b    " Joining Aether mesh network...\n",0
content_table:
    dc.l    combined_content
menu_table:
    dc.l    0

; Variables section
	section bss
current_menu_id:
    ds.l    1
current_selection:
    ds.l    1
display_needs_update:
    ds.l    1
keyboard_input_ready:
    ds.l    1
keyboard_buffer:
    ds.b    256