/* ======================================================================
 * AETHER MODEM AT COMMAND CLIENT LIBRARY
 * ======================================================================
 * 68k Assembly implementation for PCD-68 vintage computer networking
 * Implements the Aether protocol AT command set for LoRa mesh networking
 * 
 * Compatible with the VINTAGE_COMPUTER_DEMO.md specification
 * ======================================================================
 */

/* ======================================================================
 * CONSTANTS AND DEFINITIONS
 * ====================================================================== */

/* UART1 register addresses (for aether modem) */
.equ UART1_BASE, 0x450000
.equ UART1_TX, UART1_BASE + 0x00
.equ UART1_RX, UART1_BASE + 0x01
.equ UART1_STATUS, UART1_BASE + 0x02
.equ UART1_CONTROL, UART1_BASE + 0x03

/* UART control and status bits */
.equ UART_RX_ENABLE, 0x01
.equ UART_TX_ENABLE, 0x02
.equ UART_RX_INT_EN, 0x04
.equ UART_TX_INT_EN, 0x08
.equ UART_RX_READY, 0x01
.equ UART_TX_EMPTY, 0x02

/* AT command response codes */
.equ AT_OK, 0
.equ AT_ERROR, 1
.equ AT_TIMEOUT, 2
.equ AT_BUSY, 3

/* Buffer sizes */
.equ AT_CMD_BUFFER_SIZE, 64
.equ AT_RESPONSE_BUFFER_SIZE, 128
.equ AT_MAX_PARAMS, 8

/* Timeouts (in polling loops) */
.equ AT_DEFAULT_TIMEOUT, 50000
.equ AT_LONG_TIMEOUT, 100000

/* Network status values */
.equ NET_DISCONNECTED, 0
.equ NET_CONNECTING, 1
.equ NET_CONNECTED, 2
.equ NET_ERROR, 3

/* ======================================================================
 * GLOBAL STATE VARIABLES
 * ====================================================================== */

.section .data
.align 2

/* UART buffers */
at_cmd_buffer:
    .ds.b   AT_CMD_BUFFER_SIZE
at_response_buffer:
    .ds.b   AT_RESPONSE_BUFFER_SIZE

/* State variables */
modem_initialized:
    .ds.b   1
network_status:
    .ds.b   1
device_alias:
    .ds.b   32
current_chat_room:
    .ds.b   32

/* Response parsing */
last_response_code:
    .ds.b   1
response_length:
    .ds.w   1

/* Message notification handlers */
chat_message_handler:
    .ds.l   1
network_event_handler:
    .ds.l   1

/* ======================================================================
 * PUBLIC API FUNCTIONS
 * ====================================================================== */

.section .text

/* Initialize the aether modem
 * Returns: AT_OK on success, error code on failure
 */
.global aether_init
aether_init:
    movem.l %d1-%d7/%a0-%a6, -(%sp)
    
    /* Initialize UART1 for 9600 baud, 8-N-1 */
    moveb   #0x03, UART1_CONTROL  /* UART_RX_ENABLE | UART_TX_ENABLE = 0x01 | 0x02 = 0x03 */
    
    /* Clear buffers */
    lea     at_cmd_buffer, %a0
    moveq   #0, %d0
    move.w  #AT_CMD_BUFFER_SIZE-1, %d1
clear_cmd_buf:
    move.b  %d0, (%a0)+
    dbra    %d1, clear_cmd_buf
    
    lea     at_response_buffer, %a0
    move.w  #AT_RESPONSE_BUFFER_SIZE-1, %d1
clear_resp_buf:
    move.b  %d0, (%a0)+
    dbra    %d1, clear_resp_buf
    
    /* Reset state */
    moveb   #0, modem_initialized
    moveb   #NET_DISCONNECTED, network_status
    
    /* Send initial AT command to test modem */
    lea     str_at, %a0
    bsr     send_at_command
    cmpi.b  #AT_OK, %d0
    bne     init_failed
    
    /* Initialize the LoRa hardware */
    lea     str_at_init, %a0
    bsr     send_at_command
    cmpi.b  #AT_OK, %d0
    bne     init_failed
    
    /* Set device alias to "PCD68" */
    lea     str_at_alias_pcd68, %a0
    bsr     send_at_command
    cmpi.b  #AT_OK, %d0
    bne     init_failed
    
    /* Mark as initialized */
    moveb   #1, modem_initialized
    moveq   #AT_OK, %d0
    bra     init_done
    
init_failed:
    moveq   #AT_ERROR, %d0
    
init_done:
    movem.l (%sp)+, %d1-%d7/%a0-%a6
    rts

/* Connect to the Aether mesh network
 * Returns: AT_OK on success, error code on failure
 */
.global aether_connect
aether_connect:
    movem.l %d1-%d7/%a0-%a6, -(%sp)
    
    /* Check if modem is initialized */
    tst.b   modem_initialized
    beq     connect_not_init
    
    /* Set status to connecting */
    moveb   #NET_CONNECTING, network_status
    
    /* Join the network */
    lea     str_at_netjoin, %a0
    bsr     send_at_command
    cmpi.b  #AT_OK, %d0
    bne     connect_failed
    
    /* Check network status */
    lea     str_at_netstat, %a0
    bsr     send_at_command
    cmpi.b  #AT_OK, %d0
    bne     connect_failed
    
    /* Mark as connected */
    moveb   #NET_CONNECTED, network_status
    moveq   #AT_OK, %d0
    bra     connect_done
    
connect_not_init:
    moveq   #AT_ERROR, %d0
    bra     connect_done
    
connect_failed:
    moveb   #NET_ERROR, network_status
    moveq   #AT_ERROR, %d0
    
connect_done:
    movem.l (%sp)+, %d1-%d7/%a0-%a6
    rts

/* Join a chat room
 * Input: A0 = pointer to room name (null-terminated string)
 * Returns: AT_OK on success, error code on failure
 */
.global aether_chat_join
aether_chat_join:
    movem.l %d1-%d7/%a0-%a6, -(%sp)
    
    /* Check if connected */
    cmpi.b  #NET_CONNECTED, network_status
    bne     chat_join_not_connected
    
    /* Build AT+CHATJOIN=<room> command */
    lea     at_cmd_buffer, %a1
    lea     str_at_chatjoin_prefix, %a2
    
    /* Copy prefix */
copy_chatjoin_prefix:
    move.b  (%a2)+, %d0
    beq     copy_room_name
    move.b  %d0, (%a1)+
    bra     copy_chatjoin_prefix
    
copy_room_name:
    /* Copy room name */
    move.l  %a0, %a2
copy_room_loop:
    move.b  (%a2)+, %d0
    move.b  %d0, (%a1)+
    bne     copy_room_loop
    
    /* Save room name for later */
    lea     current_chat_room, %a1
    move.l  %a0, %a2
save_room_loop:
    move.b  (%a2)+, (%a1)+
    bne     save_room_loop
    
    /* Send command */
    lea     at_cmd_buffer, %a0
    bsr     send_at_command
    cmpi.b  #AT_OK, %d0
    bne     chat_join_failed
    
    moveq   #AT_OK, %d0
    bra     chat_join_done
    
chat_join_not_connected:
chat_join_failed:
    moveq   #AT_ERROR, %d0
    
chat_join_done:
    movem.l (%sp)+, %d1-%d7/%a0-%a6
    rts

/* Send a chat message
 * Input: A0 = pointer to message (null-terminated string)
 * Returns: AT_OK on success, error code on failure
 */
.global aether_chat_send
aether_chat_send:
    movem.l %d1-%d7/%a0-%a6, -(%sp)
    
    /* Check if connected */
    cmpi.b  #NET_CONNECTED, network_status
    bne     chat_send_not_connected
    
    /* Calculate message length */
    move.l  %a0, %a2
    moveq   #0, %d2
count_msg_len:
    tst.b   (%a2)+
    beq     build_send_cmd
    addq.w  #1, %d2
    bra     count_msg_len
    
build_send_cmd:
    /* Build AT+CHATSEND=<room>,<len> command */
    lea     at_cmd_buffer, %a1
    lea     str_at_chatsend_prefix, %a3
    
    /* Copy prefix */
copy_send_prefix:
    move.b  (%a3)+, %d0
    beq     copy_send_room
    move.b  %d0, (%a1)+
    bra     copy_send_prefix
    
copy_send_room:
    /* Copy current room name */
    lea     current_chat_room, %a3
copy_send_room_loop:
    move.b  (%a3)+, %d0
    beq     add_comma
    move.b  %d0, (%a1)+
    bra     copy_send_room_loop
    
add_comma:
    move.b  #',', (%a1)+
    
    /* Convert length to decimal and add */
    move.w  %d2, %d0
    bsr     append_decimal
    
    /* Null terminate command */
    clr.b   (%a1)
    
    /* Send command */
    lea     at_cmd_buffer, %a0
    bsr     send_at_command
    cmpi.b  #AT_OK, %d0
    bne     chat_send_failed
    
    /* Now send the actual message data */
    bsr     send_raw_data
    
    moveq   #AT_OK, %d0
    bra     chat_send_done
    
chat_send_not_connected:
chat_send_failed:
    moveq   #AT_ERROR, %d0
    
chat_send_done:
    movem.l (%sp)+, %d1-%d7/%a0-%a6
    rts

/* Get network status
 * Returns: Network status code in D0
 */
.global aether_get_status
aether_get_status:
    move.b  network_status, %d0
    ext.w   %d0
    ext.l   %d0
    rts

/* Process incoming notifications and messages
 * Call this periodically to handle async notifications
 * Returns: Number of messages processed in D0
 */
.global aether_poll
aether_poll:
    movem.l %d1-%d7/%a0-%a6, -(%sp)
    
    moveq   #0, %d7  /* Message counter */
    
poll_loop:
    /* Check if data is available */
    move.b  UART1_STATUS, %d0
    btst    #0, %d0  /* RX_READY bit */
    beq     poll_done
    
    /* Read incoming data */
    bsr     read_uart_line
    tst.w   %d0
    beq     poll_done
    
    /* Check if it's a notification */
    lea     at_response_buffer, %a0
    cmpi.b  #'+', (%a0)
    bne     poll_loop  /* Not a notification, continue */
    
    /* Parse notification type */
    lea     str_chatmsg_prefix, %a1
    bsr     string_compare
    tst.b   %d0
    beq     handle_chat_message
    
    /* Add other notification handlers here */
    bra     poll_loop
    
handle_chat_message:
    /* Call chat message handler if set */
    move.l  chat_message_handler, %a0
    cmpa.l  #0, %a0
    beq     poll_continue
    jsr     (%a0)
    
poll_continue:
    addq.w  #1, %d7
    bra     poll_loop
    
poll_done:
    move.w  %d7, %d0
    ext.l   %d0
    movem.l (%sp)+, %d1-%d7/%a0-%a6
    rts

/* Set chat message handler
 * Input: A0 = pointer to handler function
 */
.global aether_set_chat_handler
aether_set_chat_handler:
    move.l  %a0, chat_message_handler
    rts

/* ======================================================================
 * INTERNAL HELPER FUNCTIONS
 * ====================================================================== */

/* Send AT command and wait for response
 * Input: A0 = pointer to command string
 * Returns: Response code in D0
 * Modifies: at_response_buffer contains response
 */
send_at_command:
    movem.l %d1-%d7/%a0-%a6, -(%sp)
    
    /* Send command string */
    move.l  %a0, %a1
send_cmd_loop:
    move.b  (%a1)+, %d0
    beq     send_crlf
    bsr     send_uart_byte
    bra     send_cmd_loop
    
send_crlf:
    /* Send CR+LF */
    moveq   #13, %d0  /* CR */
    bsr     send_uart_byte
    moveq   #10, %d0  /* LF */
    bsr     send_uart_byte
    
    /* Wait for response */
    bsr     read_uart_response
    
    /* Parse response code */
    bsr     parse_response_code
    
    movem.l (%sp)+, %d1-%d7/%a0-%a6
    rts

/* Send a single byte to UART
 * Input: D0 = byte to send
 */
send_uart_byte:
    movem.l %d1-%d2, -(%sp)
    
    move.w  #10000, %d2  /* Timeout counter */
wait_tx_ready:
    move.b  UART1_STATUS, %d1
    btst    #1, %d1  /* TX_EMPTY bit */
    bne     tx_ready
    subq.w  #1, %d2
    bne     wait_tx_ready
    bra     send_byte_done  /* Timeout */
    
tx_ready:
    move.b  %d0, UART1_TX
    
send_byte_done:
    movem.l (%sp)+, %d1-%d2
    rts

/* Read a complete line from UART
 * Returns: Length in D0, data in at_response_buffer
 */
read_uart_line:
    movem.l %d1-%d7/%a0-%a6, -(%sp)
    
    lea     at_response_buffer, %a0
    moveq   #0, %d1  /* Character count */
    move.w  #AT_DEFAULT_TIMEOUT, %d7  /* Timeout */
    
read_char_loop:
    /* Check for timeout */
    subq.w  #1, %d7
    beq     read_timeout
    
    /* Check if character available */
    move.b  UART1_STATUS, %d0
    btst    #0, %d0  /* RX_READY bit */
    beq     read_char_loop
    
    /* Read character */
    move.b  UART1_RX, %d0
    
    /* Check for line endings */
    cmpi.b  #10, %d0  /* LF */
    beq     read_line_done
    cmpi.b  #13, %d0  /* CR */
    beq     read_char_loop  /* Ignore CR, wait for LF */
    
    /* Store character */
    move.b  %d0, (%a0)+
    addq.w  #1, %d1
    
    /* Check buffer overflow */
    cmpi.w  #AT_RESPONSE_BUFFER_SIZE-1, %d1
    bge     read_line_done
    
    bra     read_char_loop
    
read_timeout:
    moveq   #0, %d1
    
read_line_done:
    /* Null terminate */
    clr.b   (%a0)
    move.w  %d1, %d0
    
    movem.l (%sp)+, %d1-%d7/%a0-%a6
    rts

/* Read complete AT command response (may be multiple lines)
 * Returns: Total length in D0
 */
read_uart_response:
    movem.l %d1-%d7/%a0-%a6, -(%sp)
    
    moveq   #0, %d6  /* Total length */
    
response_loop:
    bsr     read_uart_line
    add.w   %d0, %d6
    
    /* Check if this is the final response line */
    lea     at_response_buffer, %a0
    lea     str_ok, %a1
    bsr     string_compare
    tst.b   %d0
    beq     response_done
    
    lea     at_response_buffer, %a0
    lea     str_error, %a1
    bsr     string_compare
    tst.b   %d0
    beq     response_done
    
    /* Continue reading */
    bra     response_loop
    
response_done:
    move.w  %d6, %d0
    movem.l (%sp)+, %d1-%d7/%a0-%a6
    rts

/* Parse AT response code
 * Returns: AT_OK, AT_ERROR, etc. in D0
 */
parse_response_code:
    movem.l %d1-%d7/%a0-%a6, -(%sp)
    
    lea     at_response_buffer, %a0
    lea     str_ok, %a1
    bsr     string_compare
    tst.b   %d0
    beq     parse_ok_response
    
    lea     at_response_buffer, %a0
    lea     str_error, %a1
    bsr     string_compare
    tst.b   %d0
    beq     parse_error_response
    
    /* Default to error if unrecognized */
    moveq   #AT_ERROR, %d0
    bra     parse_done
    
parse_ok_response:
    moveq   #AT_OK, %d0
    bra     parse_done
    
parse_error_response:
    moveq   #AT_ERROR, %d0
    
parse_done:
    move.b  %d0, last_response_code
    movem.l (%sp)+, %d1-%d7/%a0-%a6
    rts

/* Send raw data to UART (for message content)
 * Input: A0 = data pointer
 */
send_raw_data:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    
    move.l  %a0, %a1
send_data_loop:
    move.b  (%a1)+, %d0
    beq     send_data_done
    bsr     send_uart_byte
    bra     send_data_loop
    
send_data_done:
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

/* Compare two null-terminated strings
 * Input: A0 = string1, A1 = string2
 * Returns: 0 in D0 if equal, non-zero if different
 */
string_compare:
    movem.l %d1/%a0-%a1, -(%sp)
    
strcmp_loop:
    move.b  (%a0)+, %d0
    move.b  (%a1)+, %d1
    cmp.b   %d0, %d1
    bne     strcmp_different
    tst.b   %d0
    beq     strcmp_equal
    bra     strcmp_loop
    
strcmp_equal:
    moveq   #0, %d0
    bra     strcmp_done
    
strcmp_different:
    moveq   #1, %d0
    
strcmp_done:
    movem.l (%sp)+, %d1/%a0-%a1
    rts

/* Convert number to decimal string and append to buffer
 * Input: D0 = number, A1 = buffer pointer
 * Returns: A1 = updated buffer pointer
 */
append_decimal:
    movem.l %d0-%d3/%a0, -(%sp)
    
    /* Handle zero case */
    tst.w   %d0
    bne     convert_nonzero
    move.b  #'0', (%a1)+
    bra     append_decimal_done
    
convert_nonzero:
    /* Convert to decimal */
    move.w  %d0, %d1
    lea     -16(%sp), %a0  /* Temporary buffer on stack */
    move.l  %a0, %a2
    
decimal_loop:
    divu    #10, %d1
    move.w  %d1, %d2
    swap    %d1
    addi.b  #'0', %d1
    move.b  %d1, (%a2)+
    move.w  %d2, %d1
    tst.w   %d1
    bne     decimal_loop
    
    /* Reverse string into buffer */
    subq.l  #1, %a2
reverse_loop:
    cmp.l   %a0, %a2
    blt     append_decimal_done
    move.b  (%a2), (%a1)+
    subq.l  #1, %a2
    bra     reverse_loop
    
append_decimal_done:
    adda.l  #16, %sp  /* Clean up stack */
    movem.l (%sp)+, %d0-%d3/%a0
    rts

/* ======================================================================
 * AT COMMAND STRINGS
 * ====================================================================== */

.section .rodata

str_at:
    .string "AT"
str_at_init:
    .string "AT+INIT"
str_at_alias_pcd68:
    .string "AT+NETALIAS=PCD68"
str_at_netjoin:
    .string "AT+NETJOIN"
str_at_netstat:
    .string "AT+NETSTAT"
str_at_chatjoin_prefix:
    .string "AT+CHATJOIN="
str_at_chatsend_prefix:
    .string "AT+CHATSEND="

str_ok:
    .string "OK"
str_error:
    .string "ERROR"
str_chatmsg_prefix:
    .string "+CHATMSG:"

/* ======================================================================
 * END OF AETHER MODEM LIBRARY
 * ====================================================================== */ 