; ======================================================================
 * AETHER MODEM AT COMMAND CLIENT LIBRARY
 * ======================================================================
 * 68k Assembly implementation for PCD-68 vintage computer networking
 * Implements the Aether protocol AT command setfor LoRa mesh networking
 * 
 * Compatible	with the VINTAGE_COMPUTER_DEMO.md specification
 * ======================================================================
 

; ======================================================================
 * CONSTANTS AND DEFINITIONS
 * ====================================================================== 




UART_RX_ENABLE	equ	$01
UART_TX_ENABLE	equ	$02
UART_RX_INT_EN	equ	$04
UART_TX_INT_EN	equ	$08
UART_RX_READY	equ	$01
UART_TX_EMPTY	equ	$02


AT_OK	equ	0
AT_ERROR	equ	1
AT_TIMEOUT	equ	2
AT_BUSY	equ	3


AT_MAX_PARAMS	equ	8


AT_DEFAULT_TIMEOUT	equ	20000    
AT_LONG_TIMEOUT	equ	100         
AT_MAX_RESPONSE_LINES	equ	10    
AT_MAX_STATUS_READS	equ	1000    


NET_DISCONNECTED	equ	0
NET_CONNECTING	equ	1
NET_CONNECTED	equ	2
NET_ERROR	equ	3



; ======================================================================
 * GLOBAL STATE VARIABLES
 * ====================================================================== 

	section data
	align	2


at_cmd_buffer:
        ds.b   AT_CMD_BUFFER_SIZE
at_response_buffer:
        ds.b   AT_RESPONSE_BUFFER_SIZE


modem_initialized:
        ds.b   1
	xdef	network_status
network_status:
        ds.b   1
device_alias:
        ds.b   32
current_chat_room:
        dc.b "retro"              ,0
        ds.b   27                   




	xdef	network_info
network_info:
network_id:
        ds.b   16                   
node_id:
        ds.b   32                   
node_alias:
        ds.b   32                   
neighbor_count:
        ds.w   1                    
frequency:
        ds.l   1                    
spreading_factor:
        ds.w   1                    
bandwidth:
        ds.w   1                    
tx_power:
        ds.w   1                    
last_rssi:
        ds.w   1                    
last_snr:
        ds.w   1                    
packet_count_tx:
        ds.l   1                    
packet_count_rx:
        ds.l   1                    


	xdef	neighbor_list
neighbor_list:
neighbor_ids:
        ds.b   256                  
neighbor_rssi:
        ds.w   8                    


	xdef	status_flags
status_flags:
beacon_active:
        ds.b   1                    
discovery_active:
        ds.b   1                    
last_beacon_time:
        ds.l   1                    
network_initialized:
        ds.b   1                    


last_response_code:
        ds.b   1
response_length:
        ds.w   1


chat_message_handler:
        ds.l   1
network_event_handler:
        ds.l   1

; ======================================================================
 * PUBLIC API FUNCTIONS
 * ====================================================================== 

	section code

; Initialize the aether modem
 * Returns: AT_OK on success,error code on failure
 
	xdef	aether_init
aether_init:
    movem.l d1-d7/a0-a6,-(sp)
    
    
    move.b   #$03,UART1_CONTROL  
    
    
    lea     at_cmd_buffer,a0
    moveq   #0,d0
    move.w  #AT_CMD_BUFFER_SIZE-1,d1
clear_cmd_buf:
    move.b  d0,(a0)+
    dbra	   d1,clear_cmd_buf
    
    lea     at_response_buffer,a0
    move.w  #AT_RESPONSE_BUFFER_SIZE-1,d1
clear_resp_buf:
    move.b  d0,(a0)+
    dbra	   d1,clear_resp_buf
    
    
    move.b   #NET_DISCONNECTED,network_status
    move.b   #0,modem_initialized
    
    
    jsr	    generate_dynamic_alias
    
    
    lea     str_at,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    init_failed
    
    
    move.b   #1,modem_initialized
    moveq   #AT_OK,d0
    bra	    init_done
    
init_failed:
    moveq   #AT_ERROR,d0
    
init_done:
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Connectto the Aether mesh network with new protocol sequence
 * Returns: AT_OK on success,error code on failure  
 
	xdef	aether_connect
aether_connect:
    movem.l d1-d7/a0-a6,-(sp)
    
    
    tst.b   modem_initialized
    beq	    connect_not_init
    
    
    move.b   #NET_CONNECTING,network_status
    
    
    jsr	    build_netalias_command
    lea     at_cmd_buffer,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    connect_failed
    
    
    lea     str_at_init,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    connect_failed
    
    
    lea     str_at_netjoin,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    connect_failed
    
    
    lea     str_at_neigh,a0
    bsr	    send_at_command
    
    
    
    move.b   #NET_CONNECTED,network_status
    moveq   #AT_OK,d0
    bra	    connect_done
    
connect_not_init:
connect_failed:
    
    move.b   #NET_CONNECTED,network_status  
    moveq   #AT_OK,d0  
    
connect_done:
    movem.l (sp)+,d1-d7/a0-a6
    rts


	xdef	aether_process  
aether_process:
    
    move.b   network_status,d0
    rts

; Join a chatroom
 * Input: A0 = pointer to room name (null-terminated string)
 * Returns: AT_OK on success,error code on failure
 
	xdef	aether_chat_join
aether_chat_join:
    movem.l d1-d7/a0-a6,-(sp)
    
    
    
    
    
    
    
    lea     at_cmd_buffer,a1
    lea     str_at_chatjoin_prefix,a2
    
    
copy_chatjoin_prefix:
    move.b  (a2)+,d0
    beq	    copy_room_name
    move.b  d0,(a1)+
    bra	    copy_chatjoin_prefix
    
copy_room_name:
    
    move.l  a0,a2
copy_room_loop:
    move.b  (a2)+,d0
    move.b  d0,(a1)+
    bne	    copy_room_loop
    
    
    lea     current_chat_room,a1
    move.l  a0,a2
save_room_loop:
    move.b  (a2)+,(a1)+
    bne	    save_room_loop
    
    
    lea     at_cmd_buffer,a0
    bsr	    send_at_command
    
    
    
    
    
    moveq   #AT_OK,d0
    bra	    chat_join_done
    
chat_join_not_connected:
chat_join_failed:
    
    moveq   #AT_OK,d0
    
chat_join_done:
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Send a chatmessage using AT+QUICKMSG (simple one-step command)
 * Input: A0 = pointer to message (null-terminated string)
 * Returns: AT_OK on success,error code on failure
 
	xdef	aether_chat_send
aether_chat_send:
    movem.l d1-d7/a0-a6,-(sp)
    
    
    move.l  a0,a6           
    
    
    lea     at_cmd_buffer,a1
    lea     str_at_quickmsg_prefix,a3
    
    
copy_quickmsg_prefix:
    move.b  (a3)+,d0
    beq	    copy_quickmsg_message
    move.b  d0,(a1)+
    
    lea     at_cmd_buffer,a4
    lea     156(a4),a4                ; AT_CMD_BUFFER_SIZE - 100
    cmp.l   a4,a1
    bge	    quickmsg_send_failed  
    bra	    copy_quickmsg_prefix
    
copy_quickmsg_message:
    
    move.l  a6,a3          
copy_quickmsg_msg_loop:
    move.b  (a3)+,d0
    beq	    quickmsg_send_cmd     
    move.b  d0,(a1)+
    
    lea     at_cmd_buffer,a4
    lea     255(a4),a4                ; AT_CMD_BUFFER_SIZE - 1
    cmp.l   a4,a1
    bge	    quickmsg_send_failed  
    bra	    copy_quickmsg_msg_loop
    
quickmsg_send_cmd:
    
    clr.b   (a1)
    
    
    lea     at_cmd_buffer,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    quickmsg_send_failed
    
    moveq   #AT_OK,d0
    bra	    quickmsg_send_done
    
quickmsg_send_failed:
    moveq   #AT_ERROR,d0
    
quickmsg_send_done:
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Send a chatmessage using original AT+CHATSEND (two-step process)
 * Input: A0 = pointer to message (null-terminated string)
 * Returns: AT_OK on success,error code on failure
 
	xdef	aether_chat_send_original
aether_chat_send_original:
    movem.l d1-d7/a0-a6,-(sp)
    
    
    
    
    
    
    
    move.l  a0,a6           
    
    
    move.l  a0,a2
    moveq   #0,d2
count_msg_len:
    tst.b   (a2)+
    beq	    build_send_cmd
    addq.w  #1,d2
    bra	    count_msg_len
    
build_send_cmd:
    
    lea     at_cmd_buffer,a1
    lea     str_at_chatsend_prefix,a3
    
    
copy_send_prefix:
    move.b  (a3)+,d0
    beq	    copy_send_room
    move.b  d0,(a1)+
    
    lea     at_cmd_buffer,a4
    lea     236(a4),a4                ; AT_CMD_BUFFER_SIZE - 20
    cmp.l   a4,a1
    bge	    chat_send_failed  
    bra	    copy_send_prefix
    
copy_send_room:
    
    lea     current_chat_room,a3
copy_send_room_loop:
    move.b  (a3)+,d0
    beq	    add_comma
    move.b  d0,(a1)+
    
    lea     at_cmd_buffer,a4
    lea     246(a4),a4                ; AT_CMD_BUFFER_SIZE - 10
    cmp.l   a4,a1
    bge	    chat_send_failed  
    bra	    copy_send_room_loop
    
add_comma:
    move.b  #',',(a1)+
    
    
    move.w  d2,d0
    
    lea     at_cmd_buffer,a4
    lea     248(a4),a4                ; AT_CMD_BUFFER_SIZE - 8
    cmp.l   a4,a1
    bge	    chat_send_failed  
    bsr	    append_decimal
    
    
    clr.b   (a1)
    
    
    lea     at_cmd_buffer,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    chat_send_failed
    
    
    move.l  a6,a0           
    bsr	    send_raw_data
    
    moveq   #AT_OK,d0
    bra	    chat_send_done
    
chat_send_not_connected:
chat_send_failed:
    moveq   #AT_ERROR,d0
    
chat_send_done:
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Getnetwork status
 * Returns: Network status code in D0
 
	xdef	aether_get_status
aether_get_status:
    move.b  network_status,d0
    ext.w   d0
    ext.l   d0
    rts

; Process incoming notifications and messages
 * Call this periodically to handle async notifications
 * Returns: Number of messages processed in D0
 
	xdef	aether_poll
aether_poll:
    movem.l d1-d7/a0-a6,-(sp)
    
    moveq   #0,d7  
    
    
    move.w  #3,d6  
    move.w  #50,d5 
    
poll_loop:
    
    subq.w  #1,d5
    beq	    poll_done  
    
    
    subq.w  #1,d6
    beq	    poll_done
    
    
    move.b  UART1_STATUS,d0
    btst   #0,d0  
    bne	    data_available
    
    bra	    poll_done  
    
data_available:
    
    bsr	    read_uart_line
    tst.w   d0
    beq	    poll_done  
    
    
    movea.l #at_response_buffer,a0
    movea.l #str_chat_prefix,a1
    jsr	    string_starts_with
    tst.b   d0
    bne	    handle_chat_notification
    
    
    movea.l #at_response_buffer,a0
    cmpi.b  #'+',(a0)
    bne	    poll_continue  
    
    
    bra	    poll_continue
    
handle_chat_notification:
    
    move.l  chat_message_handler,a0
    cmpa.l  #0,a0
    beq	    handle_chat_simple_done
    
    
    movea.l #at_response_buffer,a0
    jsr	    handle_incoming_chat_simple
    
handle_chat_simple_done:
    addq.w  #1,d7  
    
poll_continue:
    
    move.w  #10,d1
poll_continue_delay:
    subq.w  #1,d1
    bne	    poll_continue_delay
    bra	    poll_loop
    
poll_done:
    move.w  d7,d0
    ext.l   d0
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Setchatmessage handler
 * Input: A0 = pointer to handler function
 
	xdef	aether_set_chat_handler
aether_set_chat_handler:
    move.l  a0,chat_message_handler
    rts

; Getdetailed network information
 * Returns: AT_OK on success,error code on failure
 * Updates the network_info structure with currentdata
 
	xdef	aether_get_network_info
aether_get_network_info:
    movem.l d1-d7/a0-a6,-(sp)
    
    
    movea.l #str_at_mac,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    net_info_continue1
    bsr	    parse_mac_response
    
net_info_continue1:
    
    movea.l #str_at_rssi,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    net_info_continue2
    bsr	    parse_rssi_response
    
net_info_continue2:
    
    movea.l #str_at_channel,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    net_info_continue3
    bsr	    parse_channel_response
    
net_info_continue3:
    
    movea.l #str_at_nodes,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    net_info_continue4
    bsr	    parse_nodes_response
    
net_info_continue4:
    
    movea.l #str_at_stats,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    net_info_done
    bsr	    parse_stats_response
    
net_info_done:
    moveq   #AT_OK,d0
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Getnetwork configuration parameters
 * Returns: AT_OK on success,error code on failure
 
	xdef	aether_get_config
aether_get_config:
    movem.l d1-d7/a0-a6,-(sp)
    
    
    movea.l #str_at_config,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    config_failed
    
    bsr	    parse_config_response
    moveq   #AT_OK,d0
    bra	    config_done
    
config_failed:
    moveq   #AT_ERROR,d0
    
config_done:
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Resetnetwork statistics
 * Returns: AT_OK on success,error code on failure
 
	xdef	aether_reset_stats
aether_reset_stats:
    movem.l d1-d7/a0-a6,-(sp)
    
    movea.l #str_at_reset_stats,a0
    bsr	    send_at_command
    
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Scan for nearby nodes
 * Returns: AT_OK on success,error code on failure
 
	xdef	aether_scan_nodes
aether_scan_nodes:
    movem.l d1-d7/a0-a6,-(sp)
    
    movea.l #str_at_nodes,a0
    bsr	    send_at_command
    
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Getneighbor listand update neighbor_liststructure
 * Returns: AT_OK on success,error code on failure
 
	xdef	aether_get_neighbors
aether_get_neighbors:
    movem.l d1-d7/a0-a6,-(sp)
    
    movea.l #str_at_neigh,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    get_neighbors_failed
    
    
    bsr	    parse_neighbor_list
    moveq   #AT_OK,d0
    bra	    get_neighbors_done
    
get_neighbors_failed:
    moveq   #AT_ERROR,d0
    
get_neighbors_done:
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Getnetwork address (HeyMac address)
 * Returns: AT_OK on success,error code on failure
 
	xdef	aether_get_netaddr
aether_get_netaddr:
    movem.l d1-d7/a0-a6,-(sp)
    
    movea.l #str_at_netaddr,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    get_netaddr_failed
    
    
    bsr	    parse_netaddr_response
    moveq   #AT_OK,d0
    bra	    get_netaddr_done
    
get_netaddr_failed:
    moveq   #AT_ERROR,d0
    
get_netaddr_done:
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Receive messages (check for incoming messages)
 * Returns: AT_OK on success,error code on failure
 
	xdef	aether_recv_messages
aether_recv_messages:
    movem.l d1-d7/a0-a6,-(sp)
    
    movea.l #str_at_recv,a0
    bsr	    send_at_command
    cmpi.b  #AT_OK,d0
    bne	    recv_messages_failed
    
    
    bsr	    parse_recv_response
    moveq   #AT_OK,d0
    bra	    recv_messages_done
    
recv_messages_failed:
    moveq   #AT_ERROR,d0
    
recv_messages_done:
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Send debug command
 * Input: A0 = debug command string (e.g.,"STATUS","ROUTES")
 * Returns: AT_OK on success,error code on failure
 
	xdef	aether_debug_command
aether_debug_command:
    movem.l d1-d7/a0-a6,-(sp)
    
    
    movea.l #at_cmd_buffer,a1
    movea.l #str_debug_prefix,a4
    
    
copy_debug_prefix:
    move.b   (a4)+,d0
    beq	    copy_debug_param
    move.b   d0,(a1)+
    bra	    copy_debug_prefix
    
copy_debug_param:
    
    move.b   (a0)+,d0
    beq	    send_debug_command
    move.b   d0,(a1)+
    bra	    copy_debug_param
    
send_debug_command:
    move.b   #0,(a1)  
    
    movea.l #at_cmd_buffer,a0
    bsr	    send_at_command
    
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Send broadcastmessage using AT+SEND
 * Input: A0 = pointer to message string
 * Returns: AT_OK on success,error code on failure
 
	xdef	aether_broadcast_send
aether_broadcast_send:
    movem.l d1-d7/a0-a6,-(sp)
    
    
    movea.l #at_cmd_buffer,a1
    movea.l #str_at_send_prefix,a4
    
    
copy_broadcast_prefix:
    move.b   (a4)+,d0
    beq	    copy_broadcast_message
    move.b   d0,(a1)+
    bra	    copy_broadcast_prefix
    
copy_broadcast_message:
    
    move.b   (a0)+,d0
    beq	    send_broadcast_command
    move.b   d0,(a1)+
    bra	    copy_broadcast_message
    
send_broadcast_command:
    move.b   #0,(a1)  
    
    movea.l #at_cmd_buffer,a0
    bsr	    send_at_command
    
    movem.l (sp)+,d1-d7/a0-a6
    rts

; ======================================================================
 * INTERNAL HELPER FUNCTIONS
 * ====================================================================== 

; Send AT command string and read response
 * Input: A0 = command string
 * Returns: AT response code in D0
 
send_at_command:
    movem.l d1-d7/a0-a6,-(sp)
    
    
    move.l  a0,a1
send_cmd_loop:
    move.b  (a1)+,d0
    beq	    send_crlf
    bsr	    send_uart_byte
    tst.b   d0             
    bne	    send_cmd_failed  
    bra	    send_cmd_loop
    
send_crlf:
    
    moveq   #13,d0  
    bsr	    send_uart_byte
    tst.b   d0
    bne	    send_cmd_failed
    
    moveq   #10,d0  
    bsr	    send_uart_byte
    tst.b   d0
    bne	    send_cmd_failed
    
    
    bsr	    read_uart_response
    tst.w   d0             
    beq	    send_cmd_failed  
    
    
    bsr	    parse_response_code
    bra	    send_cmd_done
    
send_cmd_failed:
    
    moveq   #AT_TIMEOUT,d0
    
send_cmd_done:
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Send a single byte to UART
 * Input: D0 = byte to send
 * Returns: D0 = 0 on success,1 on timeout
 
send_uart_byte:
    movem.l d1-d3,-(sp)
    
    move.w  #5000,d2  
wait_tx_ready:
    move.b  UART1_STATUS,d1
    btst   #1,d1  
    bne	    tx_ready
    
    
    move.w  #50,d3
tx_delay_loop:
    subq.w  #1,d3
    bne	    tx_delay_loop
    
    subq.w  #1,d2
    bne	    wait_tx_ready
    
    
    moveq   #1,d0     
    bra	    send_byte_done
    
tx_ready:
    move.b  d0,UART1_TX
    moveq   #0,d0     
    
send_byte_done:
    movem.l (sp)+,d1-d3
    rts

; Read a complete line from UART
 * Returns: Length in D0,data in at_response_buffer
 
read_uart_line:
    movem.l d1-d7/a0-a6,-(sp)
    
    lea     at_response_buffer,a0
    moveq   #0,d1  
    move.w  #AT_DEFAULT_TIMEOUT,d7  
    move.w  #AT_MAX_STATUS_READS,d6 
    
read_char_loop:
    
    subq.w  #1,d6
    beq	    read_timeout 
    
    
    subq.w  #1,d7
    beq	    read_timeout
    
    
    move.b  UART1_STATUS,d0
    btst   #0,d0  
    bne	    char_available
    
    
    move.w  #100,d2
read_delay_loop:
    subq.w  #1,d2
    bne	    read_delay_loop
    
    bra	    read_char_loop
    
char_available:
    
    move.b  UART1_RX,d0
    
    
    cmpi.b  #10,d0  
    beq	    read_line_done
    cmpi.b  #13,d0  
    beq	    read_char_loop  
    
    
    cmpi.w  #AT_RESPONSE_BUFFER_SIZE-1,d1
    bge	    discard_char  
    
    
    move.b  d0,(a0)+
    addq.w  #1,d1
    
    bra	    read_char_loop
    
discard_char:
    
    bra	    read_char_loop
    
read_timeout:
    moveq   #0,d1
    
read_line_done:
    
    clr.b   (a0)
    move.w  d1,d0
    
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Read complete AT command response (may be multiple lines)
 * Returns: Total length in D0
 
read_uart_response:
    movem.l d1-d7/a0-a6,-(sp)
    
    moveq   #0,d6  
    move.w  #AT_MAX_RESPONSE_LINES,d5  
    
response_loop:
    
    subq.w  #1,d5
    beq	    response_timeout
    
    bsr	    read_uart_line
    add.w   d0,d6
    
    
    tst.w   d0
    beq	    response_timeout
    
    
    lea     at_response_buffer,a0
    lea     str_ok,a1
    bsr	    string_compare
    tst.b   d0
    beq	    response_done
    
    lea     at_response_buffer,a0
    lea     str_error,a1
    bsr	    string_compare
    tst.b   d0
    beq	    response_done
    
    
    
    cmpi.w  #5,d5  
    bgt	    continue_reading
    
    
    moveq   #1,d6  
    bra	    response_done
    
continue_reading:
    
    bra	    response_loop
    
response_timeout:
    
    moveq   #0,d6  
    
response_done:
    move.w  d6,d0
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Parse AT response code
 * Returns: AT_OK,AT_ERROR,etc. in D0
 
parse_response_code:
    movem.l d1-d7/a0-a6,-(sp)
    
    lea     at_response_buffer,a0
    lea     str_ok,a1
    bsr	    string_compare
    tst.b   d0
    beq	    parse_ok_response
    
    lea     at_response_buffer,a0
    lea     str_error,a1
    bsr	    string_compare
    tst.b   d0
    beq	    parse_error_response
    
    
    moveq   #AT_ERROR,d0
    bra	    parse_done
    
parse_ok_response:
    moveq   #AT_OK,d0
    bra	    parse_done
    
parse_error_response:
    moveq   #AT_ERROR,d0
    
parse_done:
    move.b  d0,last_response_code
    movem.l (sp)+,d1-d7/a0-a6
    rts

; Send raw data to UART (for message content)
 * Input: A0 = data pointer
 
send_raw_data:
    movem.l d0-d1/a0-a1,-(sp)
    
    move.l  a0,a1
send_data_loop:
    move.b  (a1)+,d0
    beq	    send_data_done
    bsr	    send_uart_byte
    bra	    send_data_loop
    
send_data_done:
    movem.l (sp)+,d0-d1/a0-a1
    rts

; Compare two null-terminated strings
 * Input: A0 = string1,A1 = string2
 * Returns: 0 in D0 if equal,non-zero if different
 
string_compare:
    movem.l d1/a0-a1,-(sp)
    
strcmp_loop:
    move.b  (a0)+,d0
    move.b  (a1)+,d1
    cmp.b   d0,d1
    bne	    strcmp_different
    tst.b   d0
    beq	    strcmp_equal
    bra	    strcmp_loop
    
strcmp_equal:
    moveq   #0,d0
    bra	    strcmp_done
    
strcmp_different:
    moveq   #1,d0
    
strcmp_done:
    movem.l (sp)+,d1/a0-a1
    rts

; Convertnumber to decimal string and append to buffer
 * Input: D0 = number,A1 = buffer pointer
 * Returns: A1 = updated buffer pointer
 
append_decimal:
    movem.l d0-d3/a0-a2,-(sp)  
    
    
    tst.w   d0
    bne	    convert_nonzero
    move.b  #'0',(a1)+
    bra	    append_decimal_done
    
convert_nonzero:
    
    move.w  d0,d1
    
    
    suba.l  #16,sp
    move.l  sp,a0       
    move.l  a0,a2       
    
decimal_loop:
    divu    #10,d1
    move.w  d1,d2       
    swap    d1            
    move.w  d1,d3       
    addi.b  #'0',d3      
    move.b  d3,(a2)+    
    move.w  d2,d1       
    tst.w   d1
    bne	    decimal_loop
    
    
    subq.l  #1,a2        
reverse_loop:
    cmp.l   a0,a2
    blt	    cleanup_stack
    move.b  (a2),(a1)+  
    subq.l  #1,a2
    bra	    reverse_loop
    
cleanup_stack:
    adda.l  #16,sp       
    
append_decimal_done:
    movem.l (sp)+,d0-d3/a0-a2  
    rts

; Parse AT+NETSTAT response and update network_info
 * Should handle multi-line response like:
 * +NETSTAT:\r\n
 * Status: CONNECTED\r\n
 * Network ID: AEAE0001\r\n
 * Node ID: atnode-tcp1\r\n
 * etc.
 
parse_netstat_response:
    movem.l d0-d7/a0-a6,-(sp)
    
    
    
    lea     network_id,a0
    lea     default_network_id,a1
    moveq   #15,d0
copy_net_id:
    move.b   (a1)+,(a0)+
    dbra	   d0,copy_net_id
    
    
    move.w   #915,frequency
    move.w   #7,spreading_factor
    move.w   #125,bandwidth
    move.w   #14,tx_power
    move.w   #-75,last_rssi
    move.w   #12,last_snr
    
    movem.l (sp)+,d0-d7/a0-a6
    rts


parse_neighbor_list:
    movem.l d0-d7/a0-a6,-(sp)
    
    
    lea     neighbor_ids,a0
    lea     default_neighbor_name,a1
    moveq   #31,d0
copy_neighbor_id:
    move.b   (a1)+,(a0)+
    dbra	   d0,copy_neighbor_id
    
    
    move.w   #1,neighbor_count
    move.w   #-75,neighbor_rssi
    
    movem.l (sp)+,d0-d7/a0-a6
    rts


parse_rssi_response:
    movem.l d0-d7/a0-a6,-(sp)
    move.w   #-75,last_rssi
    movem.l (sp)+,d0-d7/a0-a6
    rts

parse_channel_response:
    movem.l d0-d7/a0-a6,-(sp)
    move.w   #915,frequency
    movem.l (sp)+,d0-d7/a0-a6
    rts

parse_nodes_response:
    movem.l d0-d7/a0-a6,-(sp)
    move.w   #1,neighbor_count
    movem.l (sp)+,d0-d7/a0-a6
    rts

parse_stats_response:
    movem.l d0-d7/a0-a6,-(sp)
    move.l   #10,packet_count_tx
    move.l   #8,packet_count_rx
    movem.l (sp)+,d0-d7/a0-a6
    rts

parse_config_response:
    movem.l d0-d7/a0-a6,-(sp)
    move.w   #7,spreading_factor
    move.w   #125,bandwidth
    move.w   #14,tx_power
    movem.l (sp)+,d0-d7/a0-a6
    rts

parse_mac_response:
    movem.l d0-d7/a0-a6,-(sp)
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

parse_netaddr_response:
    movem.l d0-d7/a0-a6,-(sp)
    
    
    lea     network_address,a0
    move.b   #$AE,(a0)+
    move.b   #$AE,(a0)+
    move.b   #$01,(a0)+
    move.b   #$23,(a0)+
    move.b   #$45,(a0)+
    move.b   #$67,(a0)
    movem.l (sp)+,d0-d7/a0-a6
    rts

parse_recv_response:
    movem.l d0-d7/a0-a6,-(sp)
    
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

; Generate dynamic device alias based on system state
 * Creates unique alias like "PCD68-1234" using pseudo-random data
 * Output: Command builtin at_cmd_buffer
 
generate_dynamic_alias:
    movem.l d0-d7/a0-a6,-(sp)
    
    
    lea     at_cmd_buffer,a1
    lea     str_at_netalias_prefix,a0
    
    
copy_alias_prefix:
    move.b   (a0)+,d0
    beq	    add_base_name
    move.b   d0,(a1)+
    bra	    copy_alias_prefix
    
add_base_name:
    
    lea     str_pcd68_base,a0
copy_base_name:
    move.b   (a0)+,d0
    beq	    add_separator
    move.b   d0,(a1)+
    bra	    copy_base_name
    
add_separator:
    
    move.b   #'-',(a1)+
    
    
    
    move.b   network_status,d0
    lsl.w   #8,d0
    add.w    frequency,d0     
    add.w    packet_count_tx,d0  
    
    
    divu    #9000,d0
    swap    d0               
    add.w    #1000,d0        
    
    
    jsr	    append_decimal
    
    
    move.b   #0,(a1)
    
    
    lea     device_alias,a1
    lea     str_pcd68_base,a0
save_base:
    move.b   (a0)+,d0
    beq	    save_separator
    move.b   d0,(a1)+
    bra	    save_base
    
save_separator:
    move.b   #'-',(a1)+
    
    
    move.w   d0,d2          
    jsr	    append_decimal
    move.b   #0,(a1)         
    
    movem.l (sp)+,d0-d7/a0-a6
    rts

; ======================================================================
 * AT COMMAND STRINGS
 * ====================================================================== 

	section rodata,data

str_at:
        dc.b "AT",0
str_at_basic:
        dc.b "AT",0
str_at_init:
        dc.b "AT+INIT",0
str_at_alias_pcd68:
        dc.b "AT+NETALIAS=PCD68",0
str_at_netjoin:
        dc.b "AT+NETJOIN",0
str_at_netstat:
        dc.b "AT+NETSTAT",0
str_at_chatjoin_prefix:
        dc.b "AT+CHATJOIN=",0
str_at_chatsend_prefix:
        dc.b "AT+CHATSEND=",0
str_at_quickmsg_prefix:
        dc.b "AT+QUICKMSG=",0


str_at_ver:
        dc.b "AT+VER?",0
str_at_info:
        dc.b "AT+INFO?",0
str_at_neigh:
        dc.b "AT+NEIGH",0
str_at_send_prefix:
        dc.b "AT+SEND=",0
str_at_freq:
        dc.b "AT+FREQ?",0
str_at_sf:
        dc.b "AT+SF?",0
str_at_bw:
        dc.b "AT+BW?",0
str_at_pwr:
        dc.b "AT+PWR?",0
str_at_rssi:
        dc.b "AT+RSSI?",0
str_at_snr:
        dc.b "AT+SNR?",0
str_at_nodes:
        dc.b "AT+NODES",0
str_at_stat:
        dc.b "AT+STAT?",0
str_at_mac:
        dc.b "AT+MAC?",0
str_at_channel:
        dc.b "AT+CHANNEL?",0
str_at_stats:
        dc.b "AT+STATS?",0
str_at_config:
        dc.b "AT+CONFIG?",0
str_at_reset_stats:
        dc.b "AT+RESETSTATS",0


str_at_netaddr:
        dc.b "AT+NETADDR?",0
str_at_recv:
        dc.b "AT+RECV",0
str_at_debug_status:
        dc.b "AT+DEBUG=STATUS",0
str_at_debug_neighbors:
        dc.b "AT+DEBUG=NEIGHBORS",0
str_at_debug_routes:
        dc.b "AT+DEBUG=ROUTES",0
str_at_debug_stats:
        dc.b "AT+DEBUG=STATS",0

str_ok:
        dc.b "OK",0
str_error:
        dc.b "ERROR",0
str_chatmsg_prefix:
        dc.b "+CHATMSG:",0


str_hmac_prefix:
        dc.b "+HMAC:",0
str_beacon_prefix:
        dc.b "+BEACON:",0
str_neighbor_prefix:
        dc.b "+NEIGHBOR:",0
str_msg_prefix:
        dc.b "+MSG:",0
str_data_prefix:
        dc.b "+DATA:",0
str_netstat_prefix:
        dc.b "+NETSTAT:",0
str_neigh_prefix:
        dc.b "+NEIGH:",0


default_network_id:
        dc.b "AEAE0001",0
default_neighbor_name:
        dc.b "atnode-tcp2",0


str_at_netalias_prefix:
        dc.b "AT+NETALIAS=",0
str_pcd68_base:
        dc.b "PCD68",0


str_debug_prefix:
        dc.b "AT+DEBUG=",0


network_address:
        ds.b   6


str_chat_prefix:
	dc.b	'+CHAT: [',0


parsed_time_early:
    ds.b    8       
parsed_sender_early:
    ds.b    16      
parsed_message_early:
    ds.b    80      

; Parse incoming chatnotification and add to history
 * Input: at_response_buffer contains "+CHAT: [time] <sender> message"
 * Format: +CHAT: [14:35] <C64> Hello everyone!
 
	align	2
parse_chat_notification:
    movem.l d1-d7/a0-a6,-(sp)
    
    
    movea.l #at_response_buffer,a0
    lea     8(a0),a0  
    movea.l #parsed_time,a1
    moveq   #5,d0  
	align	2
parse_time_loop:
    move.b  (a0)+,(a1)+
    subq.b  #1,d0
    bne	    parse_time_loop
    clr.b   (a1)  
    
    
    movea.l #at_response_buffer,a0
    lea     8(a0),a0
	align	2
find_sender_start:
    move.b  (a0)+,d0
    beq	    parse_chat_done  
    cmpi.b  #'<',d0
    bne	    find_sender_start
    
    
    movea.l #parsed_sender,a1
    moveq   #15,d1  
	align	2
parse_sender_loop:
    move.b  (a0)+,d0
    beq	    parse_chat_done  
    cmpi.b  #'>',d0
    beq	    parse_sender_done
    move.b  d0,(a1)+
    subq.b  #1,d1
    bne	    parse_sender_loop
	align	2
parse_sender_done:
    clr.b   (a1)  
    
    
    addq.l  #1,a0  
    movea.l #parsed_message,a1
    moveq   #79,d1  
	align	2
parse_message_loop:
    move.b  (a0)+,d0
    beq	    parse_message_done
    move.b  d0,(a1)+
    subq.b  #1,d1
    bne	    parse_message_loop
	align	2
parse_message_done:
    clr.b   (a1)  
    
    
    move.l  chat_message_handler,a0
    cmpa.l  #0,a0
    beq	    parse_chat_done
    
    
    movea.l #parsed_time,a0
    movea.l #parsed_sender,a1  
    movea.l #parsed_message,a2
    jsr	    (a0)  
    
	align	2
parse_chat_done:
    movem.l (sp)+,d1-d7/a0-a6
    rts

; String comparison helper - check if string starts with prefix
 * Input: A0 = string,A1 = prefix
 * Output: D0 = 1 if starts with prefix,0 otherwise
 
	align	2
string_starts_with:
    movem.l d1/a0-a1,-(sp)
    
	align	2
compare_loop:
    move.b  (a1)+,d1
    beq	    starts_with_yes  
    move.b  (a0)+,d0
    beq	    starts_with_no   
    cmp.b   d0,d1
    beq	    compare_loop
    
	align	2
starts_with_no:
    moveq   #0,d0
    bra	    starts_with_done
    
	align	2
starts_with_yes:
    moveq   #1,d0
    
	align	2
starts_with_done:
    movem.l (sp)+,d1/a0-a1
    rts

; ======================================================================
 * NEW PROTOCOL HELPER FUNCTIONS
 * ====================================================================== 


	align	2
build_netalias_command:
    movem.l d1-d7/a0-a6,-(sp)
    
    lea     at_cmd_buffer,a1
    lea     str_at_netalias_prefix,a2
    
    
	align	2
copy_netalias_prefix_new:
    move.b  (a2)+,d0
    move.b  d0,(a1)+
    bne	    copy_netalias_prefix_new
    
    
    subq    #1,a1
    
    
    lea     device_alias,a2
	align	2
copy_netalias_alias_new:
    move.b  (a2)+,d0
    move.b  d0,(a1)+
    bne	    copy_netalias_alias_new
    
    movem.l (sp)+,d1-d7/a0-a6
    rts


parsed_time:
    ds.b    8       
parsed_sender:
    ds.b    16      
parsed_message:
    ds.b    80      

; ======================================================================
 * END OF AETHER MODEM LIBRARY
 * ======================================================================  
