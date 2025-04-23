# PCD-68 Homepage
#

# Define ScrnBase, location in memory containing the start of video memory
.equ ScrnBase, 0x810000
.equ ScrnBaseMirror, 0x430000
.equ TDABase, 0x410000
.equ TDASize, 80 * 23
#.equ TDASize, 50 * 37
.equ KCTLBase, 0x420000
.equ KCTLStatus, 0x420000
.equ KCTLKeycode, 0x420001
.equ KCTLMod, 0x420002
.equ EndOfStack, 0xBFFFFF
.equ ScreenWidth, 80
.equ TextMode, 2                    // 1 for 50-col, 2 for 80-col

//.equ ModLeftShift, 1                // 0x0001
//.equ ModRightShift, 2               // 0x0002
//.equ ModCtrl, 6                     // 0x0040
//.equ ModAlt, 8                      // 0x0100
//.equ ModMeta, 10                    // 0x0400

.equ ModLeftShift, 0x0001
.equ ModRightShift, 0x0002
.equ ModCtrl, 0x0040
.equ ModAlt, 0x0100
.equ ModMeta, 0x0400

.org 0x000000
vectors:
    dc.l    EndOfStack              // Initial SP
    dc.l    start                   // Start of program code
    dc.l    bus_error_handler       // Bus error
    dc.l    address_error_handler   // Address error
    dc.l    illegal_inst_handler    // Illegal instruction
    dc.l    div_by_zero_handler     // Div by zero
    dc.l    chk_exc_handler         // CHK exception
    dc.l    trapv_exc_handler       // TRAPV exception
    dc.l    priv_violation_handler  // Privilege violation
    dc.l    trace_exception_handler // TRACE exception
    dc.l    0x000000    // Line-A emulator
    dc.l    0x000000    // Line-F emulator
    dc.l    0xFAFAAA    // Reserved (unused)
    dc.l    0x000000    // Co-proc protocol violation
    dc.l    format_error_handler    // Format error
    dc.l    uninit_int_handler      // Uninitialized Interrupt
    dc.l    0x000000    // Reserved (NOT USED)
    dc.l    0x000000    // Reserved (NOT USED)
    dc.l    0x000000    // Reserved (NOT USED)
    dc.l    0x000000    // Reserved (NOT USED)
    dc.l    0x000000    // Reserved (NOT USED)
    dc.l    0x000000    // Reserved (NOT USED)
    dc.l    0x000000    // Reserved (NOT USED)
    dc.l    0x000000    // Reserved (NOT USED)
    dc.l    0x000000    // Spurious Interrupt
    dc.l    0x000000    // IRQ Level 1
    dc.l    0x000000    // IRQ Level 2 (EXT Interrupt)
    dc.l    keyboard_handler    // IRQ Level 3
    dc.l    0x000000    // IRQ Level 4 (VDP Horizontal Interrupt)
    dc.l    0x000000    // IRQ Level 5
    dc.l    0x000000    // IRQ Level 6 (VDP Vertical Interrupt)
    dc.l    0x000000    // IRQ Level 7
    dc.l    trap_handler        // TRAP #00 Exception
    dc.l    trap_handler    // TRAP #01 Exception
    dc.l    trap_handler    // TRAP #02 Exception
    dc.l    trap_handler    // TRAP #03 Exception
    dc.l    trap_handler    // TRAP #04 Exception
    dc.l    trap_handler    // TRAP #05 Exception
    dc.l    trap_handler    // TRAP #06 Exception
    dc.l    trap_handler    // TRAP #07 Exception
    dc.l    trap_handler    // TRAP #08 Exception
    dc.l    trap_handler    // TRAP #09 Exception
    dc.l    trap_handler    // TRAP #10 Exception
    dc.l    trap_handler    // TRAP #11 Exception
    dc.l    trap_handler    // TRAP #12 Exception
    dc.l    trap_handler    // TRAP #13 Exception
    dc.l    trap_handler    // TRAP #14 Exception
    dc.l    trap_handler    // TRAP #15 Exception
    dc.l    0x000000    // (FP) Branch or Set on Unordered Condition
    dc.l    0x000000    // (FP) Inexact Result
    dc.l    0x000000    // (FP) Divide by Zero
    dc.l    0x000000    // (FP) Underflow
    dc.l    0x000000    // (FP) Operand Error
    dc.l    0x000000    // (FP) Overflow
    dc.l    0x000000    // (FP) Signaling NAN
    dc.l    0x000000    // (FP) Unimplemented Data Type
    dc.l    0x000000    // MMU Configuration Error
    dc.l    0x000000    // MMU Illegal Operation Error
    dc.l    0x000000    // MMU Access Violation Error
    dc.l    0x000000    // Reserved (NOT USED)
    dc.l    0x000000    // Reserved (NOT USED)
    dc.l    0x000000    // Reserved (NOT USED)
    dc.l    0x000000    // Reserved (NOT USED)
    dc.l    0x000000    // Reserved (NOT USED)

jump:
    bra     end_loop

.org 0x001000
start:
    movel   #0, %d3

    moveal  #(TDABase + TDASize + 1), %a4
	moveal	#KCTLKeycode, %a3
# moveal	#KCTLMod, %a6

	moveal	#TDABase, %a2
    moveb   #TextMode, (%a2)+          // Set TDA column mode (font)

screen_top:
    lea     loadingString, %a5

msg1:
    moveb   (%a5)+, %d0
	moveb	%d0, (%a2)+
    cmpb    #10, %d0 // check for newline
	bne     nullcheck
    jsr     newline
nullcheck:
    cmpb    #0, %d0  // check for null char
	bne     msg1

    lea     loadingString2, %a5
msg2:
    moveb   (%a5)+, %d0
	moveb	%d0, (%a2)+
    cmpb    #10, %d0 // check for newline
	bne     nullcheck2
    jsr     newline

nullcheck2:
    cmpb    #0, %d0  // check for null char
	bne     msg2

    lea     loadingString3, %a5
msg3:
    moveb   (%a5)+, %d0
	moveb	%d0, (%a2)+
    cmpb    #10, %d0 // check for newline
	bne     nullcheck3
    jsr     newline
nullcheck3:
    cmpb    #0, %d0  // check for null char
	bne     msg3

	moveal	#TDABase + 1 + (80 * 22), %a2

end_loop:

	movel	#1000, %d1
delay_loop:
	nop
	nop
	subi	#1, %d1
	bne     delay_loop
	bra     end_loop

newline:
    // get current line:
    movel   %a2, %d7
    subil   #TDABase, %d7
    divuw   #80, %d7
    addil   #1, %d7
    muluw   #80, %d7

	moveal	#TDABase + 1, %a2
    addal   %d7, %a2
    rts

end:
.org 0x002000
keyboard_handler:
    movew   (%a3), %d2
    moveb   %d2, (%a2)+
    cmpl    %a2, %a4
    bhis    keyboard_ret
    moveal  #TDABase + 1 + (80 * 22), %a2
keyboard_ret:
    rte

.org 0x002100
bus_error_handler:
    nop
    nop
    bra     bus_error_handler

.org 0x002200
address_error_handler:
    nop
    nop
    bra     address_error_handler

.org 0x002300
illegal_inst_handler:
    nop
    nop
    bra     illegal_inst_handler

.org 0x002400
div_by_zero_handler:
    nop
    nop
    bra     div_by_zero_handler

.org 0x002500
chk_exc_handler:
    nop
    nop
    bra     chk_exc_handler

.org 0x002600
trapv_exc_handler:
    nop
    nop
    bra     trapv_exc_handler

.org 0x002700
priv_violation_handler:
    nop
    nop
    bra     priv_violation_handler

.org 0x002800
trace_exception_handler:
    nop
    nop
    bra     trace_exception_handler

.org 0x002900
format_error_handler:
    nop
    nop
    bra     format_error_handler

.org 0x002A00
uninit_int_handler:
    nop
    nop
    bra     uninit_int_handler

.org 0x002B00
trap_handler:
    nop
    nop
    bra     trap_handler

// String data
.org 0x003000
loadingString:
.string "==============\n JonSharp.net \n==============\n"
loadingString2:
.string "Welcome to JonSharp.net -- back online -- now on PCD-68!\n\n"
.align 2
loadingString3:
.string "PCD-68 is a virtual retro computer of my design.  It exists currently as an\nemulated computer -- brought to your browser through the magic of Emscripten.\nSoon, the following links will be functional.\n\nIn the meantime, enjoy the demo. :)\n\nProjects\n--------\n 1. PCD-68\n 2. Gameboy Color Terminal\n 3. TAD\n 4. Retrocomputing\n\nMisc\n----\n 5. More about me\n 6. Twitter?\n\n<type_below:>\n\n"
