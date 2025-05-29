# PCD-68 UART Test Program (Debug Version)
# Modified to add diagnostic output to help troubleshoot TDA display issues

# Define memory locations and system constants
.equ ScrnBase, 0x810000
.equ ScrnBaseMirror, 0x430000
.equ TDABase, 0x410000
.equ TDASize, 80 * 23
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

# Keyboard modifiers
.equ ModLeftShift, 0x0001
.equ ModRightShift, 0x0002
.equ ModCtrl, 0x0040
.equ ModAlt, 0x0100
.equ ModMeta, 0x0400

.extern keyboard_handler

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
    dc.l    uart1_handler      // IRQ Level 4 - UART1
    dc.l    uart2_handler      // IRQ Level 5 - UART2
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

.org 0x001000
start:
    // Initialize variables
    movel   #0, %d3                  // Clear D3 register
    moveal  #(TDABase + TDASize + 1), %a4  // End of screen memory
    moveal  #KCTLKeycode, %a3        // Keyboard keycode register
    moveal  #KCTLMod, %a6            // Keyboard modifier register

    // Initialize TDA (Text Display Adapter)
    moveal  #TDABase, %a2            // TDA base address
    moveb   #TextMode, (%a2)+        // Set TDA column mode (80 columns)

    // Clear the screen
    moveal  #TDABase+1, %a0          // Text screen memory
    movel   #TDASize-1, %d0          // Screen size counter
clear_screen:
    moveb   #' ', (%a0)+             // Write space character
    dbra    %d0, clear_screen        // Decrement and loop

    // Write a direct message to confirm TDA is working
    moveal  #TDABase+1, %a0
    lea     debug_msg, %a1
debug_copy:
    moveb   (%a1)+, %d0
    beq     debug_done
    moveb   %d0, (%a0)+
    bra     debug_copy
debug_done:

    // Set screen position back to top
    moveal  #TDABase+1, %a2

    // Initialize UART1 and UART2
    jsr     init_uart
    
    // Display ASCII art banner
    lea     banner_line1, %a5
    jsr     print_string
    jsr     newline

    lea     banner_line2, %a5
    jsr     print_string
    jsr     newline

    lea     banner_line3, %a5
    jsr     print_string
    jsr     newline

    lea     banner_line4, %a5
    jsr     print_string
    jsr     newline
    jsr     newline

    // Display welcome message
    lea     welcome_msg, %a5
    jsr     print_string
    jsr     newline
    jsr     newline

    // Display UART information
    lea     uart_info_msg, %a5
    jsr     print_string
    jsr     newline

    // Display debug information
    lea     debug_info_msg, %a5
    jsr     print_string
    jsr     newline

    // Setup cursor positions for UART output
    moveal  #cursor_x1, %a0
    movew   #0, (%a0)                // UART1 cursor X = 0
    moveal  #cursor_y1, %a0
    movew   #12, (%a0)               // UART1 cursor Y = 12

    moveal  #cursor_x2, %a0
    movew   #0, (%a0)                // UART2 cursor X = 0
    moveal  #cursor_y2, %a0
    movew   #17, (%a0)               // UART2 cursor Y = 17

    // Display UART headers
    moveal  #cursor_x, %a0
    movew   #0, (%a0)                // Set cursor X = 0
    moveal  #cursor_y, %a0
    movew   #11, (%a0)               // Set cursor Y = 11

    lea     uart1_header, %a5
    jsr     print_string
    jsr     newline

    moveal  #cursor_x, %a0
    movew   #0, (%a0)                // Set cursor X = 0
    moveal  #cursor_y, %a0
    movew   #16, (%a0)               // Set cursor Y = 16

    lea     uart2_header, %a5
    jsr     print_string
    jsr     newline

    // Try direct UART1 loopback test at startup (debugging)
    moveal  #cursor_x, %a0
    movew   #0, (%a0)
    moveal  #cursor_y, %a0
    movew   #20, (%a0)
    lea     loopback_test_msg, %a5
    jsr     print_string

    // Set loopback mode on UART1
    moveb   #0x83, UART1_CONTROL    // Enable RX, TX, Loopback (0x80 | 0x02 | 0x01)

    // Send a test character
    moveb   #'X', UART1_TX

    // Short delay
    movel   #5000, %d7
delay_startup:
    subi    #1, %d7
    bne     delay_startup

    // Check if received (in loopback mode)
    moveb   UART1_STATUS, %d1
    btst    #0, %d1                  // Test RX_READY
    beq     no_loopback_data
    
    // Data received, display it
    moveb   UART1_RX, %d0
    
    moveal  #cursor_x, %a0
    movew   #25, (%a0)
    lea     loopback_success_msg, %a5
    jsr     print_string
    bra     loopback_test_done
    
no_loopback_data:
    moveal  #cursor_x, %a0
    movew   #25, (%a0)
    lea     loopback_failed_msg, %a5
    jsr     print_string

loopback_test_done:
    // Reset UART1 to normal mode
    moveb   #0x0F, UART1_CONTROL    // Enable RX, TX, RX_INT, TX_INT (0x08 | 0x04 | 0x02 | 0x01)

    // Display tick counter
    jsr     update_tick
    
    // Enable interrupts (level 5 and below)
    movew   #0x2700, %sr             // Disable all interrupts temporarily
    movew   #0x2000, %sr             // Enable interrupts, mask level 0

main_loop:
    // Update diagnostic tick to show program is running
    jsr     update_tick
    
    // Check for keyboard input
    moveb   KCTLStatus, %d0          // Read keyboard status
    beq     main_loop_continue       // If no key, continue

    // Read the key
    moveb   KCTLKeycode, %d0         // Get keycode
    moveb   #0, KCTLStatus           // Clear keyboard status

    // Display the keypress
    moveal  #cursor_x, %a0
    movew   #20, (%a0)               // Set X position
    moveal  #cursor_y, %a0
    movew   #21, (%a0)               // Set Y position
    
    moveb   %d0, %d1
    jsr     print_char
    
    // Check for special keys
    cmpb    #'1', %d0                // '1' - Toggle UART1 loopback
    beq     toggle_uart1_loopback
    cmpb    #'2', %d0                // '2' - Toggle UART2 loopback
    beq     toggle_uart2_loopback
    cmpb    #'3', %d0                // '3' - Show UART registers
    beq     show_uart_debug

    // Send the character to both UARTs
    moveb   %d0, UART1_TX            // Send to UART1
    moveb   %d0, UART2_TX            // Send to UART2

    // Direct output to UART area (for debugging)
    moveal  #cursor_x1, %a0
    movew   (%a0), %d2               // Get UART1 X position
    moveal  #cursor_y1, %a0
    movew   (%a0), %d3               // Get UART1 Y position
    
    // Calculate screen position
    movel   #TDABase+1, %a0
    movew   %d3, %d7
    mulu    #80, %d7
    addl    %d7, %a0
    addl    %d2, %a0
    
    // Write the character and update position
    moveb   %d0, (%a0)
    
    // Update cursor position
    addw    #1, %d2
    cmpw    #79, %d2
    ble     direct_uart1_ok
    movew   #0, %d2
    addw    #1, %d3
    cmpw    #15, %d3
    ble     direct_uart1_ok
    movew   #12, %d3
direct_uart1_ok:
    moveal  #cursor_x1, %a0
    movew   %d2, (%a0)
    moveal  #cursor_y1, %a0
    movew   %d3, (%a0)

main_loop_continue:
    // Delay loop
    movel   #1000, %d1
delay_loop:
    subi    #1, %d1
    bne     delay_loop
    bra     main_loop

// Show UART register status
show_uart_debug:
    moveal  #cursor_x, %a0
    movew   #0, (%a0)                // Set X position
    moveal  #cursor_y, %a0
    movew   #22, (%a0)               // Set Y position
    
    lea     reg_display_msg, %a5
    jsr     print_string
    
    // Display UART1 registers
    moveb   UART1_STATUS, %d1
    jsr     print_hex_byte
    
    moveal  #cursor_x, %a0
    movew   (%a0), %d7
    addw    #1, %d7
    movew   %d7, (%a0)
    
    moveb   UART1_CONTROL, %d1
    jsr     print_hex_byte
    
    moveal  #cursor_x, %a0
    movew   (%a0), %d7
    addw    #3, %d7
    movew   %d7, (%a0)
    
    // Display UART2 registers
    moveb   UART2_STATUS, %d1
    jsr     print_hex_byte
    
    moveal  #cursor_x, %a0
    movew   (%a0), %d7
    addw    #1, %d7
    movew   %d7, (%a0)
    
    moveb   UART2_CONTROL, %d1
    jsr     print_hex_byte
    
    bra     main_loop

// Toggle UART1 loopback mode
toggle_uart1_loopback:
    moveb   UART1_CONTROL, %d0       // Read control register
    eori.b  #CTRL_LOOPBACK, %d0      // Toggle loopback bit
    moveb   %d0, UART1_CONTROL       // Write back

    // Update status display
    moveal  #cursor_x, %a0
    movew   #30, (%a0)               // Set X position
    moveal  #cursor_y, %a0
    movew   #11, (%a0)               // Set Y position

    btst    #7, %d0                  // Test loopback bit
    beq     uart1_loopback_off

    // Loopback ON
    lea     loopback_on_msg, %a5
    jsr     print_string
    bra     main_loop

uart1_loopback_off:
    lea     loopback_off_msg, %a5
    jsr     print_string
    bra     main_loop

// Toggle UART2 loopback mode
toggle_uart2_loopback:
    moveb   UART2_CONTROL, %d0       // Read control register
    eori.b  #CTRL_LOOPBACK, %d0      // Toggle loopback bit
    moveb   %d0, UART2_CONTROL       // Write back

    // Update status display
    moveal  #cursor_x, %a0
    movew   #30, (%a0)               // Set X position
    moveal  #cursor_y, %a0
    movew   #16, (%a0)               // Set Y position

    btst    #7, %d0                  // Test loopback bit
    beq     uart2_loopback_off

    // Loopback ON
    lea     loopback_on_msg, %a5
    jsr     print_string
    bra     main_loop

uart2_loopback_off:
    lea     loopback_off_msg, %a5
    jsr     print_string
    bra     main_loop

// Initialize UART1 and UART2
init_uart:
    // Initialize UART1
    moveb   #0x03, UART1_CONTROL  // Enable TX/RX (CTRL_RX_ENABLE | CTRL_TX_ENABLE)
    moveb   #0x0F, UART1_CONTROL  // Enable interrupts (CTRL_RX_ENABLE | CTRL_TX_ENABLE | CTRL_RX_INT_EN | CTRL_TX_INT_EN)

    // Initialize UART2
    moveb   #0x03, UART2_CONTROL  // Enable TX/RX (CTRL_RX_ENABLE | CTRL_TX_ENABLE)
    moveb   #0x0F, UART2_CONTROL  // Enable interrupts (CTRL_RX_ENABLE | CTRL_TX_ENABLE | CTRL_RX_INT_EN | CTRL_TX_INT_EN)

    rts

// Print a hex byte
// Input: D1.B = byte to print
print_hex_byte:
    // Save registers
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    
    // Print high nibble
    moveb   %d1, %d0
    lsrb    #4, %d0                  // Get high nibble
    addb    #'0', %d0                // Convert to ASCII
    cmpb    #'9'+1, %d0              // If > '9', adjust for A-F
    blt     high_digit_ok
    addb    #('A'-'0'-10), %d0       // Adjust to 'A'-'F' range
high_digit_ok:
    moveb   %d0, %d1
    jsr     print_char
    
    // Print low nibble
    movel   (%sp), %d1               // Restore original byte
    andb    #0x0F, %d1               // Get low nibble
    addb    #'0', %d1                // Convert to ASCII
    cmpb    #'9'+1, %d1              // If > '9', adjust for A-F
    blt     low_digit_ok
    addb    #('A'-'0'-10), %d1       // Adjust to 'A'-'F' range
low_digit_ok:
    jsr     print_char
    
    // Restore registers
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

// Print a single character at the current cursor position
// Input: D1.B = character to print
print_char:
    // Save registers
    movel   %d0, -(%sp)
    movel   %d7, -(%sp)
    movel   %a0, -(%sp)
    
    // Get current cursor position
    moveal  #cursor_x, %a0
    movew   (%a0), %d0               // X position
    moveal  #cursor_y, %a0
    movew   (%a0), %d7               // Y position
    
    // Calculate screen position: TDABase + 1 + (Y * 80) + X
    movel   #TDABase+1, %a0
    mulu    #80, %d7
    addl    %d7, %a0
    addl    %d0, %a0
    
    // Print the character
    moveb   %d1, (%a0)
    
    // Advance cursor
    addw    #1, %d0
    cmpw    #79, %d0                 // End of line?
    ble     pc_no_wrap
    
    // Wrap to next line
    movew   #0, %d0
    addw    #1, %d7
    cmpw    #22, %d7                 // Bottom of screen?
    ble     pc_no_wrap
    movew   #22, %d7                 // Keep at bottom
    
pc_no_wrap:
    // Save updated cursor position
    moveal  #cursor_x, %a0
    movew   %d0, (%a0)
    moveal  #cursor_y, %a0
    movew   %d7, (%a0)
    
    // Restore registers
    movel   (%sp)+, %a0
    movel   (%sp)+, %d7
    movel   (%sp)+, %d0
    rts

// Print a null-terminated string
// Input: A5 points to string
print_string:
    moveal  #cursor_x, %a0
    movew   (%a0), %d5               // Load cursor X
    moveal  #cursor_y, %a0
    movew   (%a0), %d6               // Load cursor Y

print_loop:
    moveb   (%a5)+, %d0              // Get next character
    beq     print_done               // If 0, end of string

    // Handle newline
    cmpb    #10, %d0                 // Check for newline
    beq     print_newline

    // Calculate screen position: TDABase + 1 + (Y * 80) + X
    movel   #TDABase+1, %a0
    movew   %d6, %d7
    mulu    #80, %d7
    addl    %d7, %a0
    addl    %d5, %a0

    // Print the character
    moveb   %d0, (%a0)

    // Advance cursor
    addw    #1, %d5
    cmpw    #79, %d5                 // End of line?
    ble     print_loop
    
    // Wrap to next line
    movew   #0, %d5
    addw    #1, %d6
    cmpw    #22, %d6                 // Bottom of screen?
    ble     print_loop
    movew   #22, %d6                 // Keep at bottom
    bra     print_loop

print_newline:
    movew   #0, %d5                  // X = 0
    addw    #1, %d6                  // Y++
    cmpw    #22, %d6                 // Check for bottom of screen
    ble     print_loop
    movew   #22, %d6                 // Keep at bottom
    bra     print_loop

print_done:
    // Save cursor position
    moveal  #cursor_x, %a0
    movew   %d5, (%a0)
    moveal  #cursor_y, %a0
    movew   %d6, (%a0)
    rts

// Advance to next line
newline:
    moveal  #cursor_x, %a0
    movew   #0, (%a0)                // X = 0
    moveal  #cursor_y, %a0
    movew   (%a0), %d0
    addw    #1, %d0                  // Y++
    cmpw    #22, %d0                 // Check for bottom of screen
    ble     newline_ok
    movew   #22, %d0                 // Keep at bottom
newline_ok:
    movew   %d0, (%a0)
    rts

// Update diagnostic tick to show program is running
update_tick:
    // Save registers
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %a0, -(%sp)
    
    // Get current tick value
    moveal  #tick_value, %a0
    moveb   (%a0), %d0
    
    // Increment and wrap if needed
    addb    #1, %d0
    cmpb    #'Z'+1, %d0
    blt     tick_ok
    moveb   #'A', %d0
tick_ok:
    // Store updated value
    moveb   %d0, (%a0)
    
    // Display the tick
    moveal  #TDABase+1+6, %a0        // Position in status line
    moveb   %d0, (%a0)
    
    // Restore registers
    movel   (%sp)+, %a0
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rts

// UART1 interrupt handler (Level 4)
uart1_handler:
    // Save registers
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %a0, -(%sp)

    // Indicate UART1 interrupt triggered (debug)
    moveal  #TDABase+1+8, %a0        // Position in status line
    moveb   #'1', (%a0)              // Show interrupt occurred

    // Check if RX data available
    moveb   UART1_STATUS, %d0
    btst    #0, %d0                  // Test RX_READY bit
    beq     uart1_check_tx

    // Read received data
    moveb   UART1_RX, %d1

    // Save current cursor position
    moveal  #cursor_x, %a0
    movew   (%a0), %d2
    moveal  #cursor_y, %a0
    movew   (%a0), %d3

    // Set cursor to UART1 output area
    moveal  #cursor_x1, %a0
    movew   (%a0), %d5               // Get UART1 X
    moveal  #cursor_y1, %a0
    movew   (%a0), %d6               // Get UART1 Y

    // Calculate screen position: TDABase + 1 + (Y * 80) + X
    movel   #TDABase+1, %a0
    movew   %d6, %d7
    mulu    #80, %d7
    addl    %d7, %a0
    addl    %d5, %a0

    // Print the character
    moveb   %d1, (%a0)

    // Update UART1 cursor position
    addw    #1, %d5
    cmpw    #79, %d5
    ble     uart1_cursor_ok
    movew   #0, %d5                  // Reset X
    addw    #1, %d6                  // Increment Y
    cmpw    #15, %d6                 // Check if past UART1 region
    ble     uart1_cursor_ok
    movew   #12, %d6                 // Reset to top of UART1 region

uart1_cursor_ok:
    // Save updated UART1 cursor
    moveal  #cursor_x1, %a0
    movew   %d5, (%a0)
    moveal  #cursor_y1, %a0
    movew   %d6, (%a0)

    // Restore original cursor
    moveal  #cursor_x, %a0
    movew   %d2, (%a0)
    moveal  #cursor_y, %a0
    movew   %d3, (%a0)

uart1_check_tx:
    // Check if transmitter empty
    btst    #1, %d0                  // Test TX_EMPTY bit
    beq     uart1_done

    // TX is empty - we could send more data here
    // For debug, indicate TX interrupt
    moveal  #TDABase+1+9, %a0        // Position in status line
    moveb   #'T', (%a0)              // Show TX interrupt

uart1_done:
    // Restore registers
    movel   (%sp)+, %a0
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rte                              // Return from exception

// UART2 interrupt handler (Level 5)
uart2_handler:
    // Save registers
    movel   %d0, -(%sp)
    movel   %d1, -(%sp)
    movel   %a0, -(%sp)

    // Indicate UART2 interrupt triggered (debug)
    moveal  #TDABase+1+10, %a0       // Position in status line
    moveb   #'2', (%a0)              // Show interrupt occurred

    // Check if RX data available
    moveb   UART2_STATUS, %d0
    btst    #0, %d0                  // Test RX_READY bit
    beq     uart2_check_tx

    // Read received data
    moveb   UART2_RX, %d1

    // Save current cursor position
    moveal  #cursor_x, %a0
    movew   (%a0), %d2
    moveal  #cursor_y, %a0
    movew   (%a0), %d3

    // Set cursor to UART2 output area
    moveal  #cursor_x2, %a0
    movew   (%a0), %d5               // Get UART2 X
    moveal  #cursor_y2, %a0
    movew   (%a0), %d6               // Get UART2 Y

    // Calculate screen position: TDABase + 1 + (Y * 80) + X
    movel   #TDABase+1, %a0
    movew   %d6, %d7
    mulu    #80, %d7
    addl    %d7, %a0
    addl    %d5, %a0

    // Print the character
    moveb   %d1, (%a0)

    // Update UART2 cursor position
    addw    #1, %d5
    cmpw    #79, %d5
    ble     uart2_cursor_ok
    movew   #0, %d5                  // Reset X
    addw    #1, %d6                  // Increment Y
    cmpw    #20, %d6                 // Check if past UART2 region
    ble     uart2_cursor_ok
    movew   #17, %d6                 // Reset to top of UART2 region

uart2_cursor_ok:
    // Save updated UART2 cursor
    moveal  #cursor_x2, %a0
    movew   %d5, (%a0)
    moveal  #cursor_y2, %a0
    movew   %d6, (%a0)

    // Restore original cursor
    moveal  #cursor_x, %a0
    movew   %d2, (%a0)
    moveal  #cursor_y, %a0
    movew   %d3, (%a0)

uart2_check_tx:
    // Check if transmitter empty
    btst    #1, %d0                  // Test TX_EMPTY bit
    beq     uart2_done

    // TX is empty - we could send more data here
    // For debug, indicate TX interrupt
    moveal  #TDABase+1+11, %a0       // Position in status line
    moveb   #'T', (%a0)              // Show TX interrupt

uart2_done:
    // Restore registers
    movel   (%sp)+, %a0
    movel   (%sp)+, %d1
    movel   (%sp)+, %d0
    rte                              // Return from exception

// Dummy keyboard handler (not used in this program)
keyboard_handler:
    rte

// Exception handlers
bus_error_handler:
    nop
    bra     bus_error_handler

address_error_handler:
    nop
    bra     address_error_handler

illegal_inst_handler:
    nop
    bra     illegal_inst_handler

div_by_zero_handler:
    nop
    bra     div_by_zero_handler

chk_exc_handler:
    nop
    bra     chk_exc_handler

trapv_exc_handler:
    nop
    bra     trapv_exc_handler

priv_violation_handler:
    nop
    bra     priv_violation_handler

trace_exception_handler:
    nop
    bra     trace_exception_handler

format_error_handler:
    nop
    bra     format_error_handler

uninit_int_handler:
    nop
    bra     uninit_int_handler

trap_handler:
    nop
    bra     trap_handler

.align 2
// Variables
cursor_x:       .word   0           // Current cursor X position
cursor_y:       .word   0           // Current cursor Y position
cursor_x1:      .word   0           // UART1 output cursor X
cursor_y1:      .word   0           // UART1 output cursor Y
cursor_x2:      .word   0           // UART2 output cursor X
cursor_y2:      .word   0           // UART2 output cursor Y
tick_value:     .byte   'A'         // Diagnostic tick value
                .byte   0           // Padding

// Strings
debug_msg:          .asciz "PCD-68 UART TEST (Debug Version) - Text display working!"
debug_info_msg:     .asciz "Status: [A] U1[_] U2[_] Keys: 1=U1Loop 2=U2Loop 3=Regs"
welcome_msg:        .asciz "Welcome to the PCD-68 UART Test Program - Debug Version"
uart_info_msg:      .asciz "Press '1' to toggle UART1 loopback, '2' for UART2, '3' for register info"
uart1_header:       .asciz "UART1 Output (IRQ Level 4):                Loopback: OFF"
uart2_header:       .asciz "UART2 Output (IRQ Level 5):                Loopback: OFF"
loopback_on_msg:    .asciz "ON "
loopback_off_msg:   .asciz "OFF"
loopback_test_msg:  .asciz "UART1 loopback test: "
loopback_success_msg: .asciz "SUCCESS!"
loopback_failed_msg:  .asciz "FAILED! "
reg_display_msg:    .asciz "UART Regs: U1S:   U1C:   U2S:   U2C:   "

banner_line1:       .asciz "  _____   _____ _____     __    ___  "
banner_line2:       .asciz " |  __ \\ / ____|  __ \\   /_ |  / _ \\ "
banner_line3:       .asciz " | |__) | |    | |  | |   | | | (_) |"
banner_line4:       .asciz " |  ___/| |    | |  | |   | |  \\__, |" 