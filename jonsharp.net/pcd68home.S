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

# UART peripheral addresses
.equ UART_BASE, 0x450000

# UART1 registers
.equ UART1_TX, UART_BASE + 0x00    // Transmit register
.equ UART1_RX, UART_BASE + 0x01    // Receive register
.equ UART1_STATUS, UART_BASE + 0x02 // Status register
.equ UART1_CONTROL, UART_BASE + 0x03 // Control register

# UART2 registers
.equ UART2_TX, UART_BASE + 0x04    // Transmit register
.equ UART2_RX, UART_BASE + 0x05    // Receive register
.equ UART2_STATUS, UART_BASE + 0x06 // Status register
.equ UART2_CONTROL, UART_BASE + 0x07 // Control register

# UART control bits
.equ CTRL_RX_ENABLE, 0x01          // Enable receiver
.equ CTRL_TX_ENABLE, 0x02          // Enable transmitter
.equ CTRL_RX_INT_EN, 0x04          // Enable RX interrupt
.equ CTRL_TX_INT_EN, 0x08          // Enable TX interrupt
.equ CTRL_LOOPBACK, 0x80           // Loopback mode

# UART status bits
.equ STAT_RX_READY, 0x01           // Data available
.equ STAT_TX_EMPTY, 0x02           // Transmitter empty

# Add a buffer area definition for the UART monitor
.equ UartBufferStart, TDABase + 1 + (80 * 15)  // Start of UART monitor area (line 15)
.equ UartBufferLines, 6                        // Number of lines for UART buffer
.equ UartBufferWidth, 80                       // Width of buffer area
.equ UartBufferEnd, UartBufferStart + (UartBufferLines * UartBufferWidth) - 1  // End address of buffer

# Keep track of the current write position in the buffer
.equ UartBufferCursorVar, 0x100000  // Memory address to store current buffer position

# Modify the init_uart function to clear the UART buffer area and initialize the cursor
init_uart:
    // Clear any pending data in UART registers
    moveb   UART1_STATUS, %d0     // Read and discard status
    moveb   UART1_RX, %d0         // Read and discard any pending data
    moveb   UART2_STATUS, %d0     // Same for UART2
    moveb   UART2_RX, %d0
    
    // Initialize UART1 - first try with just polling, no interrupts
    moveb   #0x03, UART1_CONTROL  // CTRL_RX_ENABLE | CTRL_TX_ENABLE
    
    // Initialize UART2 - also just polling
    moveb   #0x03, UART2_CONTROL  // CTRL_RX_ENABLE | CTRL_TX_ENABLE
    
    // Show indicator that UART initialization has completed
    moveal  #TDABase + 1 + (80 * 14), %a0
    moveb   #'U', (%a0)+
    moveb   #'A', (%a0)+
    moveb   #'R', (%a0)+
    moveb   #'T', (%a0)+
    moveb   #' ', (%a0)+
    moveb   #'M', (%a0)+
    moveb   #'O', (%a0)+
    moveb   #'N', (%a0)+
    moveb   #'I', (%a0)+
    moveb   #'T', (%a0)+
    moveb   #'O', (%a0)+
    moveb   #'R', (%a0)+
    moveb   #':', (%a0)+
    
    // Clear the UART buffer area
    moveal  #UartBufferStart, %a0
    movel   #(UartBufferLines * UartBufferWidth) - 1, %d7
clear_uart_buffer:
    moveb   #' ', (%a0)+
    dbra    %d7, clear_uart_buffer
    
    // Initialize buffer cursor position to start of buffer
    moveal  #UartBufferCursorVar, %a0
    movel   #UartBufferStart, (%a0)
    
    rts

// Function to add a character to the UART buffer area
// Input: %d0 contains the character to add
add_to_uart_buffer:
    // Save registers we'll modify
    movel   %a0, -(%sp)
    movel   %a1, -(%sp)
    movel   %d1, -(%sp)
    movel   %d2, -(%sp)
    
    // Get current buffer position from memory
    moveal  #UartBufferCursorVar, %a0
    moveal  (%a0), %a1               // A1 now points to current buffer position
    
    // Add the character to the buffer
    moveb   %d0, (%a1)+              // Store character and advance pointer
    
    // Check if we've reached the end of a line
    movel   %a1, %d1                 // Copy current position to D1
    subl    #UartBufferStart, %d1    // Calculate offset from start
    divu    #UartBufferWidth, %d1    // Divide by width to get row, remainder
    swap    %d1                      // Get remainder (column position)
    
    // If we're at the end of a line, wrap to next line
    cmpw    #0, %d1                  // Check if column is 0 (wrapped)
    bne     check_buffer_end         // If not at end of line, skip ahead
    subql   #1, %a1                  // Back up one position 
    addql   #UartBufferWidth, %a1    // Move to next line
    
check_buffer_end:
    // Check if we've reached the end of the buffer
    cmpl    #UartBufferEnd, %a1
    bls     save_position            // If not at end, just save position
    
    // Buffer is full, need to scroll contents up
    movel   #UartBufferStart, %a1    // Reset to start of buffer
    
    // Option 1: Just wrap around to the beginning (simplest)
    // This will overwrite old data in a circular buffer fashion
    
    // Option 2: Scroll the buffer (more complex but preserves more history)
    // We'll implement the scrolling approach
    
    // Save the new position temporarily
    movel   %a1, -(%sp)
    
    // Copy each line up one position (scroll effect)
    moveal  #UartBufferStart, %a0            // Source: start + width (2nd line)
    addl    #UartBufferWidth, %a0
    moveal  #UartBufferStart, %a1            // Destination: start (1st line)
    movel   #(UartBufferLines - 1) * UartBufferWidth, %d2  // Bytes to copy
    
scroll_loop:
    moveb   (%a0)+, (%a1)+            // Copy a byte
    dbra    %d2, scroll_loop          // Continue until all copied
    
    // Clear the last line
    moveal  #UartBufferStart + ((UartBufferLines - 1) * UartBufferWidth), %a1
    movel   #UartBufferWidth - 1, %d2 // Last line bytes (minus 1 for dbra)
    
clear_last_line:
    moveb   #' ', (%a1)+              // Write a space
    dbra    %d2, clear_last_line      // Continue until line is cleared
    
    // Set position to start of last line
    moveal  #UartBufferStart + ((UartBufferLines - 1) * UartBufferWidth), %a1
    movel   (%sp)+, %d1               // Clean up stack
    
save_position:
    // Save new buffer position
    moveal  #UartBufferCursorVar, %a0
    movel   %a1, (%a0)
    
    // Restore registers
    movel   (%sp)+, %d2
    movel   (%sp)+, %d1
    movel   (%sp)+, %a1
    movel   (%sp)+, %a0
    rts

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
    dc.l    uart1_handler       // IRQ Level 4 - UART1
    dc.l    uart2_handler       // IRQ Level 5 - UART2
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

    // Initialize UART
    jsr     init_uart

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

    // Add UART info line
    jsr     newline
    lea     uartInfoString, %a5
    jsr     print_string

	moveal	#TDABase + 1 + (80 * 22), %a2

end_loop:
    // Poll UART for data and check for cursor wrap
    jsr     check_uart
    
    // Display UART status at fixed position
    movel   %a2, %a5              // Save current cursor position
    
    // Clear status area
    moveal  #TDABase + 1 + (80 * 19), %a2
    moveq   #79, %d7
uart_clear:
    moveb   #' ', (%a2)+
    dbra    %d7, uart_clear
    
    // Display status header
    moveal  #TDABase + 1 + (80 * 19), %a2
    moveb   #'U', (%a2)+
    moveb   #'A', (%a2)+
    moveb   #'R', (%a2)+
    moveb   #'T', (%a2)+
    moveb   #':', (%a2)+
    moveb   #' ', (%a2)+
    
    // Show UART1 status register in hex
    moveb   UART1_STATUS, %d0
    moveq   #0, %d6
    moveb   %d0, %d6
    lsr.b   #4, %d6
    cmpi.b  #10, %d6
    blt     hex1
    addi.b  #'A'-10, %d6
    bra     print_hex1
hex1:
    addi.b  #'0', %d6
print_hex1:
    moveb   %d6, (%a2)+
    
    moveq   #0, %d6
    moveb   %d0, %d6
    andi.b  #0x0F, %d6
    cmpi.b  #10, %d6
    blt     hex2
    addi.b  #'A'-10, %d6
    bra     print_hex2
hex2:
    addi.b  #'0', %d6
print_hex2:
    moveb   %d6, (%a2)+
    
    // Add separator and bit test result
    moveb   #' ', (%a2)+
    btst    #0, %d0
    beq     no_data
    moveb   #'1', (%a2)+  // Bit 0 is set
    bra     show_rx
no_data:
    moveb   #'0', (%a2)+  // Bit 0 is not set
    
show_rx:
    // Add separator then display what's in RX register
    moveb   #' ', (%a2)+
    moveb   #'R', (%a2)+
    moveb   #'X', (%a2)+
    moveb   #':', (%a2)+
    moveb   #' ', (%a2)+
    
    // Read and show RX register contents
    moveb   UART1_RX, %d0
    
    // Show in hex
    moveq   #0, %d6
    moveb   %d0, %d6
    lsr.b   #4, %d6
    cmpi.b  #10, %d6
    blt     rx_hex1
    addi.b  #'A'-10, %d6
    bra     print_rx_hex1
rx_hex1:
    addi.b  #'0', %d6
print_rx_hex1:
    moveb   %d6, (%a2)+
    
    moveq   #0, %d6
    moveb   %d0, %d6
    andi.b  #0x0F, %d6
    cmpi.b  #10, %d6
    blt     rx_hex2
    addi.b  #'A'-10, %d6
    bra     print_rx_hex2
rx_hex2:
    addi.b  #'0', %d6
print_rx_hex2:
    moveb   %d6, (%a2)+
    
    // Show as ASCII
    moveb   #' ', (%a2)+
    moveb   #'\'', (%a2)+
    moveb   %d0, (%a2)+
    moveb   #'\'', (%a2)+
    
    // Go back to original position
    movel   %a5, %a2
    
    // Small delay
    movel   #500, %d1
delay_loop:
    nop
    nop
    subi    #1, %d1
    bne     delay_loop
    
    // Debug counter for line 20
    movel   debug_counter, %d0
    addil   #1, %d0
    movel   %d0, debug_counter
    
    // Only update every 16 counts (using a mask)
    andi.l  #0x0F, %d0
    bne     skip_counter
    
    // Display counter on line 20
    movel   %a2, %a5
    moveal  #TDABase + 1 + (80 * 20), %a2
    
    // Clear line
    moveq   #20, %d7
clear_count_line:
    moveb   #' ', (%a2)+
    dbra    %d7, clear_count_line
    
    // Set up counter label
    moveal  #TDABase + 1 + (80 * 20), %a2
    moveb   #'C', (%a2)+
    moveb   #'N', (%a2)+
    moveb   #'T', (%a2)+
    moveb   #':', (%a2)+
    moveb   #' ', (%a2)+
    
    // Convert counter to decimal
    movel   debug_counter, %d0
    divu    #10000, %d0
    addi.b  #'0', %d0
    moveb   %d0, (%a2)+
    
    movel   debug_counter, %d0
    divu    #10000, %d0
    swap    %d0
    divu    #1000, %d0
    addi.b  #'0', %d0
    moveb   %d0, (%a2)+
    
    movel   debug_counter, %d0
    divu    #1000, %d0
    swap    %d0
    divu    #100, %d0
    addi.b  #'0', %d0
    moveb   %d0, (%a2)+
    
    movel   debug_counter, %d0
    divu    #100, %d0
    swap    %d0
    divu    #10, %d0
    addi.b  #'0', %d0
    moveb   %d0, (%a2)+
    
    movel   debug_counter, %d0
    divu    #10, %d0
    swap    %d0
    addi.b  #'0', %d0
    moveb   %d0, (%a2)+
    
    // Restore position
    movel   %a5, %a2
    
skip_counter:
    bra     end_loop

// Print a null-terminated string
print_string:
print_loop:
    moveb   (%a5)+, %d0        // Get next character
    cmpb    #0, %d0            // Check for null terminator
    beq     print_done         // If null, we're done
    
    cmpb    #10, %d0           // Check for newline
    beq     print_newline      // If newline, handle it
    
    moveb   %d0, (%a2)+        // Write character to screen
    bra     print_loop         // Continue loop
    
print_newline:
    jsr     newline            // Handle newline
    bra     print_loop         // Continue loop
    
print_done:
    rts                        // Return

// Check for UART data without interrupts
check_uart:
    // Check if we need to wrap the cursor
    cmpl    %a2, %a4
    bhi     cursor_ok
    
    // Reset cursor to beginning of line 22
    moveal  #TDABase + 1 + (80 * 22), %a2
    
    // Clear the line
    moveq   #79, %d7
clear_line:
    moveb   #' ', (%a2)+
    dbra    %d7, clear_line
    
    // Reset cursor to beginning of line again
    moveal  #TDABase + 1 + (80 * 22), %a2
    
cursor_ok:
    // Debug marker (just one character to avoid filling the screen)
    moveb   #'+', (%a2)+
    
    // Check UART1 status register for RX data ready
    moveb   UART1_STATUS, %d0
    
    // If status bit 0 is set, read and display the character
    btst    #0, %d0
    beq     check_uart_ret
    
    // Read the character
    moveb   UART1_RX, %d0
    
    // Add to UART buffer area
    jsr     add_to_uart_buffer
    
check_uart_ret:
    rts

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

.org 0x002C00
uart1_handler:
    // Show interrupt indicator at fixed position
    moveal  #TDABase + 1 + (80 * 19), %a5
    moveb   #'I', (%a5)+
    moveb   #'1', (%a5)+
    moveb   #'!', (%a5)+
    
    // Check if it's a receive interrupt
    moveb   UART1_STATUS, %d0
    btst    #0, %d0                  // Test bit 0 (STAT_RX_READY)
    beq     uart1_done
    
    // Read the character and display it
    moveb   UART1_RX, %d0
    cmpi.b  #0, %d0                  // Skip null characters
    beq     uart1_done
    
    // Add to UART buffer area
    jsr     add_to_uart_buffer
    
uart1_done:
    rte

.org 0x002D00
uart2_handler:
    // Show interrupt indicator at fixed position
    moveal  #TDABase + 1 + (80 * 19), %a5
    moveb   #'I', (%a5)+
    moveb   #'2', (%a5)+
    moveb   #'!', (%a5)+
    
    // Check if it's a receive interrupt
    moveb   UART2_STATUS, %d0
    btst    #0, %d0                  // Test bit 0 (STAT_RX_READY)
    beq     uart2_done
    
    // Read the character and display it
    moveb   UART2_RX, %d0
    cmpi.b  #0, %d0                  // Skip null characters
    beq     uart2_done
    
    // Mark the character with a prefix for visibility
    moveb   #'2', (%a2)+             // Prefix with '2' for UART2
    moveb   #':', (%a2)+             // Separator
    moveb   %d0, (%a2)+              // The actual character
    moveb   #' ', (%a2)+             // Add a space for readability
    
    // Wrap around if needed
    cmpl    %a2, %a4
    bhis    uart2_done
    moveal  #TDABase + 1 + (80 * 22), %a2
    
uart2_done:
    rte

// String data
.org 0x003000
loadingString:
.string "==============\n JonSharp.net \n==============\n"
loadingString2:
.string "Welcome to JonSharp.net -- back online -- now on PCD-68!\n\n"
.align 2
loadingString3:
.string "PCD-68 is a virtual retro computer of my design.  It exists currently as an\nemulated computer -- brought to your browser through the magic of Emscripten.\nThis is a UART demo.  chars should appear below...  (you can type, too)\n\n"
.align 2
uartInfoString:
.string "UART enabled - Received characters will be displayed here."

// Add a debug counter in the DATA section
.org 0x003500
debug_counter:
    .dc.l    0
