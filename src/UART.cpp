#include "UART.h"
#include <iostream>
#include <iomanip>
#include <sstream>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include <emscripten/websocket.h>
// Define constants for the WebSocket event types
// These are arbitrary values as WebSocket events don't use the EMSCRIPTEN_EVENT_* constants
// They're just used to identify the event type in the callback functions
#define EMSCRIPTEN_WEBSOCKET_MESSAGE_CALLBACK 0 // Message event
#define EMSCRIPTEN_WEBSOCKET_OPEN_CALLBACK 0 // Open event
#endif

UART::UART(CPU* cpu, uint32_t start, uint32_t size) :
    Peripheral(start, size) {
    this->cpu = cpu;
    this->debugMode = false;

#ifdef __EMSCRIPTEN__
    websocketId[UART1] = -1;
    websocketId[UART2] = -1;
    connected[UART1] = false;
    connected[UART2] = false;
#else
    serialFd[UART1] = -1;
    serialFd[UART2] = -1;
    serialConnected[UART1] = false;
    serialConnected[UART2] = false;
    
    pipeFdIn[UART1] = -1;
    pipeFdIn[UART2] = -1;
    pipeFdOut[UART1] = -1;
    pipeFdOut[UART2] = -1;
    pipeConnected[UART1] = false;
    pipeConnected[UART2] = false;
#endif
}

int UART::init() {
    // Initialize both UARTs
    for (int i = 0; i < 2; i++) {
        // Set default register values
        registers.uart[i].txData = 0;
        registers.uart[i].rxData = 0;
        registers.uart[i].status = STAT_TX_EMPTY;  // TX buffer is initially empty
        registers.uart[i].control = 0;            // Both UARTs are disabled by default
        registers.uart[i].baudrate = BAUD_9600;   // Default to 9600 baud
        
        // Clear FIFOs
        std::lock_guard<std::mutex> rxLock(rxMutex);
        std::lock_guard<std::mutex> txLock(txMutex);
        while (!rxFifo[i].empty()) rxFifo[i].pop();
        while (!txFifo[i].empty()) txFifo[i].pop();
    }
    
    return 0;
}

void UART::reset() {
    init();
}

u8 UART::read8(u32 addr) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        u32 offset = addr - BASE_ADDR;
        
        // Handle UART1 registers
        if (offset <= UART1_CONTROL) {
            switch (offset) {
                case UART1_RX:
                    // Reading from RX data register clears RX_READY bit
                    {
                        std::lock_guard<std::mutex> lock(rxMutex);
                        if (!rxFifo[UART1].empty()) {
                            registers.uart[UART1].rxData = rxFifo[UART1].front();
                            rxFifo[UART1].pop();
                            
                            // If FIFO is now empty, clear RX_READY bit
                            if (rxFifo[UART1].empty()) {
                                registers.uart[UART1].status &= ~STAT_RX_READY;
                                updateInterrupts(UART1);
                            }
                        }
                    }
                    return registers.uart[UART1].rxData;
                    
                case UART1_STATUS:
                    return registers.uart[UART1].status;
                    
                case UART1_CONTROL:
                    return registers.uart[UART1].control;
                    
                case UART1_TX:
                    // TX register is write-only, reading returns 0
                    return 0;
            }
        }
        
        // Handle UART2 registers
        if (offset >= UART2_TX && offset <= UART2_CONTROL) {
            switch (offset) {
                case UART2_RX:
                    // Reading from RX data register clears RX_READY bit
                    {
                        std::lock_guard<std::mutex> lock(rxMutex);
                        if (!rxFifo[UART2].empty()) {
                            registers.uart[UART2].rxData = rxFifo[UART2].front();
                            rxFifo[UART2].pop();
                            
                            // If FIFO is now empty, clear RX_READY bit
                            if (rxFifo[UART2].empty()) {
                                registers.uart[UART2].status &= ~STAT_RX_READY;
                                updateInterrupts(UART2);
                            }
                        }
                    }
                    return registers.uart[UART2].rxData;
                    
                case UART2_STATUS:
                    return registers.uart[UART2].status;
                    
                case UART2_CONTROL:
                    return registers.uart[UART2].control;
                    
                case UART2_TX:
                    // TX register is write-only, reading returns 0
                    return 0;
            }
        }
    }
    
    return 0;
}

u16 UART::read16(u32 addr) {
    // UART is an 8-bit device, so 16-bit reads are not supported directly
    // Instead, we'll do two 8-bit reads and combine them
    u8 lo = read8(addr);
    u8 hi = read8(addr + 1);
    return (hi << 8) | lo;
}

void UART::write8(u32 addr, u8 val) {
    if (addr >= BASE_ADDR && addr < BASE_ADDR + sizeof(registers)) {
        u32 offset = addr - BASE_ADDR;
        
        // Handle UART1 registers
        if (offset <= UART1_CONTROL) {
            switch (offset) {
                case UART1_TX:
                    // Writing to TX register sends data
                    if (registers.uart[UART1].control & CTRL_TX_ENABLE) {
                        registers.uart[UART1].txData = val;
                        
                        if (debugMode) {
                            std::cout << "DEBUG UART1 TX: 0x" << std::hex << std::setw(2) << std::setfill('0') 
                                      << static_cast<int>(val) << " '" << (isprint(val) ? static_cast<char>(val) : '.') 
                                      << "'" << std::dec << std::endl;
                        }
                        
                        // Add to TX FIFO
                        std::lock_guard<std::mutex> lock(txMutex);
                        txFifo[UART1].push(val);
                        
                        // Clear TX_EMPTY bit temporarily (will be set again in poll())
                        registers.uart[UART1].status &= ~STAT_TX_EMPTY;
                        updateInterrupts(UART1);
                    }
                    break;
                    
                case UART1_CONTROL:
                    // Process control register writes
                    processControlWrite(UART1, val);
                    break;
                    
                case UART1_STATUS:
                    // Status register is read-only except for error flags
                    if (val & STAT_RX_OVERRUN) registers.uart[UART1].status &= ~STAT_RX_OVERRUN;
                    if (val & STAT_FRAME_ERR) registers.uart[UART1].status &= ~STAT_FRAME_ERR;
                    if (val & STAT_BREAK) registers.uart[UART1].status &= ~STAT_BREAK;
                    break;
                    
                case UART1_RX:
                    // RX register is read-only
                    break;
            }
        }
        
        // Handle UART2 registers
        if (offset >= UART2_TX && offset <= UART2_CONTROL) {
            switch (offset) {
                case UART2_TX:
                    // Writing to TX register sends data
                    if (registers.uart[UART2].control & CTRL_TX_ENABLE) {
                        registers.uart[UART2].txData = val;
                        
                        // Add to TX FIFO
                        std::lock_guard<std::mutex> lock(txMutex);
                        txFifo[UART2].push(val);
                        
                        // Clear TX_EMPTY bit temporarily (will be set again in poll())
                        registers.uart[UART2].status &= ~STAT_TX_EMPTY;
                        updateInterrupts(UART2);
                    }
                    break;
                    
                case UART2_CONTROL:
                    // Process control register writes
                    processControlWrite(UART2, val);
                    break;
                    
                case UART2_STATUS:
                    // Status register is read-only except for error flags
                    if (val & STAT_RX_OVERRUN) registers.uart[UART2].status &= ~STAT_RX_OVERRUN;
                    if (val & STAT_FRAME_ERR) registers.uart[UART2].status &= ~STAT_FRAME_ERR;
                    if (val & STAT_BREAK) registers.uart[UART2].status &= ~STAT_BREAK;
                    break;
                    
                case UART2_RX:
                    // RX register is read-only
                    break;
            }
        }
    }
}

void UART::write16(u32 addr, u16 val) {
    // UART is an 8-bit device, so 16-bit writes are not supported directly
    // Instead, we'll do two 8-bit writes
    write8(addr, val & 0xFF);
    write8(addr + 1, (val >> 8) & 0xFF);
}

void UART::send(Channel channel, u8 byte) {
    if (registers.uart[channel].control & CTRL_RX_ENABLE) {
        if (debugMode) {
            std::cout << "DEBUG UART" << (channel + 1) << " RX: 0x" << std::hex << std::setw(2) 
                      << std::setfill('0') << static_cast<int>(byte) << " '" 
                      << (isprint(byte) ? static_cast<char>(byte) : '.') << "'" << std::dec << std::endl;
        }
        
        std::lock_guard<std::mutex> lock(rxMutex);
        if (rxFifo[channel].size() < FIFO_SIZE) {
            rxFifo[channel].push(byte);
            
            // Set RX_READY bit
            registers.uart[channel].status |= STAT_RX_READY;
            updateInterrupts(channel);
        } else {
            // FIFO overflow
            registers.uart[channel].status |= STAT_RX_OVERRUN;
            
            if (debugMode) {
                std::cout << "DEBUG UART" << (channel + 1) << " RX OVERFLOW" << std::endl;
            }
        }
    }
}

void UART::poll() {
    // Process both UARTs
    for (int i = 0; i < 2; i++) {
        Channel channel = static_cast<Channel>(i);
        
        // Process TX FIFO if transmitter is enabled
        if (registers.uart[channel].control & CTRL_TX_ENABLE) {
            std::lock_guard<std::mutex> txLock(txMutex);
            if (!txFifo[channel].empty()) {
                // Get byte from TX FIFO
                u8 byte = txFifo[channel].front();
                txFifo[channel].pop();
                
                // Actually transmit the byte
#ifdef __EMSCRIPTEN__
                if (connected[channel]) {
                    sendWebsocket(channel, &byte, 1);
                } else if (debugMode) {
                    // In debug mode, show that byte was dropped due to no connection
                    std::cerr << "DEBUG: UART" << (channel + 1) << " TX byte dropped (WebSocket not connected): 0x" 
                              << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(byte) 
                              << std::dec << std::endl;
                }
#endif
                
                // If loopback is enabled, also send to RX
                if (registers.uart[channel].control & CTRL_LOOPBACK) {
                    send(channel, byte);
                }
            }
            
            // Update TX_EMPTY status
            if (txFifo[channel].empty()) {
                registers.uart[channel].status |= STAT_TX_EMPTY;
                updateInterrupts(channel);
            }
        }
    }
}

void UART::updateInterrupts(Channel channel) {
    // TX interrupt
    if ((registers.uart[channel].status & STAT_TX_EMPTY) && 
        (registers.uart[channel].control & CTRL_TX_INT_EN)) {
        
        // Trigger TX interrupt
        if (channel == UART1) {
            cpu->setIPL(UART1_INT_LEVEL);
        } else {
            cpu->setIPL(UART2_INT_LEVEL);
        }
    }
    // RX interrupt
    else if ((registers.uart[channel].status & STAT_RX_READY) && 
             (registers.uart[channel].control & CTRL_RX_INT_EN)) {
        
        // Trigger RX interrupt
        if (channel == UART1) {
            cpu->setIPL(UART1_INT_LEVEL);
        } else {
            cpu->setIPL(UART2_INT_LEVEL);
        }
    }
    else {
        // No interrupts active for this channel
        // Check if the other channel has an active interrupt before clearing
        Channel otherChannel = (channel == UART1) ? UART2 : UART1;
        bool otherHasInterrupt = 
            ((registers.uart[otherChannel].status & STAT_TX_EMPTY) && 
             (registers.uart[otherChannel].control & CTRL_TX_INT_EN)) ||
            ((registers.uart[otherChannel].status & STAT_RX_READY) && 
             (registers.uart[otherChannel].control & CTRL_RX_INT_EN));
             
        if (!otherHasInterrupt) {
            // No interrupts on either channel, clear IPL
            cpu->setIPL(0);
        }
    }
}

void UART::processControlWrite(Channel channel, u8 value) {
    u8 oldControl = registers.uart[channel].control;
    registers.uart[channel].control = value;
    
    // Handle control register changes
    
    // If TX was disabled and is now enabled, set TX_EMPTY flag
    if (!(oldControl & CTRL_TX_ENABLE) && (value & CTRL_TX_ENABLE)) {
        registers.uart[channel].status |= STAT_TX_EMPTY;
    }
    
    // If error reset is requested, clear error flags
    if (value & CTRL_RESET_ERR) {
        registers.uart[channel].status &= ~(STAT_RX_OVERRUN | STAT_FRAME_ERR | STAT_BREAK);
    }
    
    // Update interrupts based on new control settings
    updateInterrupts(channel);
}

#ifdef __EMSCRIPTEN__
// Define WebSocket callbacks
static EM_BOOL websocket1_callback(int eventType, const EmscriptenWebSocketMessageEvent *event, void *userData);
static EM_BOOL websocket2_callback(int eventType, const EmscriptenWebSocketMessageEvent *event, void *userData);
static EM_BOOL websocket_open_callback(int eventType, const EmscriptenWebSocketOpenEvent *event, void *userData);

// Callback function to handle websocket messages for UART1
EM_BOOL websocket1_callback(int eventType, const EmscriptenWebSocketMessageEvent *event, void *userData) {
    if (eventType == EMSCRIPTEN_WEBSOCKET_MESSAGE_CALLBACK) {
        // Get UART instance from user data
        UART* uart = reinterpret_cast<UART*>(userData);
        
        if (event->numBytes > 0) {
            // Process received data
            uart->onWebsocketData(UART::UART1, event->data, event->numBytes);
        }
        
        return EM_TRUE;
    }
    return EM_FALSE;
}

// Callback function to handle websocket messages for UART2
EM_BOOL websocket2_callback(int eventType, const EmscriptenWebSocketMessageEvent *event, void *userData) {
    if (eventType == EMSCRIPTEN_WEBSOCKET_MESSAGE_CALLBACK) {
        // Get UART instance from user data
        UART* uart = reinterpret_cast<UART*>(userData);
        
        if (event->numBytes > 0) {
            // Process received data
            uart->onWebsocketData(UART::UART2, event->data, event->numBytes);
        }
        
        return EM_TRUE;
    }
    return EM_FALSE;
}

// Callback for websocket open events
EM_BOOL websocket_open_callback(int eventType, const EmscriptenWebSocketOpenEvent *event, void *userData) {
    if (eventType == EMSCRIPTEN_WEBSOCKET_OPEN_CALLBACK) {
        // We can't determine the channel from this event directly
        // Use the open event to mark the socket as connected
        UART* uartInstance = reinterpret_cast<UART*>(userData);
        
        // Find which socket this is for
        for (int ch = 0; ch < 2; ch++) {
            if (uartInstance->websocketId[ch] == event->socket) {
                uartInstance->connected[ch] = true;
                std::cout << "WebSocket " << (ch + 1) << " connection established!" << std::endl;
                break;
            }
        }
        
        return EM_TRUE;
    }
    
    return EM_FALSE;
}

int UART::connectWebsocket(const char* url1, const char* url2) {
    // Check if emscripten websocket API is supported
    if (!emscripten_websocket_is_supported()) {
        std::cerr << "Warning: WebSockets are not supported in this browser. UART connections will not work." << std::endl;
        return 0; // Non-fatal error, continue with degraded functionality
    }
    
    // Connect first UART
    if (url1) {
        EmscriptenWebSocketCreateAttributes attr;
        emscripten_websocket_init_create_attributes(&attr);
        attr.url = url1;
        attr.protocols = "binary";
        
        websocketId[UART1] = emscripten_websocket_new(&attr);
        if (websocketId[UART1] < 0) {
            std::cerr << "Warning: WebSocket creation for UART1 failed. UART1 will not be available." << std::endl;
            websocketId[UART1] = -1;
            connected[UART1] = false;
            // Continue with degraded functionality
        } else {
            // Set up callbacks - pass this pointer as userData
            emscripten_websocket_set_onmessage_callback(websocketId[UART1], this, websocket1_callback);
            emscripten_websocket_set_onopen_callback(websocketId[UART1], this, websocket_open_callback);
            
            connected[UART1] = false; // Will be set to true when open event is received
        }
    }
    
    // Connect second UART if URL is provided
    if (url2) {
        EmscriptenWebSocketCreateAttributes attr;
        emscripten_websocket_init_create_attributes(&attr);
        attr.url = url2;
        attr.protocols = "binary";
        
        websocketId[UART2] = emscripten_websocket_new(&attr);
        if (websocketId[UART2] < 0) {
            std::cerr << "Warning: WebSocket creation for UART2 failed. UART2 will not be available." << std::endl;
            websocketId[UART2] = -1;
            connected[UART2] = false;
            // Continue with degraded functionality
        } else {
            // Set up callbacks - pass this pointer as userData
            emscripten_websocket_set_onmessage_callback(websocketId[UART2], this, websocket2_callback);
            emscripten_websocket_set_onopen_callback(websocketId[UART2], this, websocket_open_callback);
            
            connected[UART2] = false; // Will be set to true when open event is received
        }
    }
    
    return 0; // Always return success to allow emulator to continue
}

void UART::sendWebsocket(Channel channel, const u8* data, size_t length) {
#ifdef __EMSCRIPTEN__
    if (connected[channel] && length > 0 && websocketId[channel] >= 0) {
        // Cast the const pointer to non-const since the API requires it
        void* dataPtr = const_cast<void*>(static_cast<const void*>(data));
        emscripten_websocket_send_binary(websocketId[channel], dataPtr, length);
    } else if (debugMode && length > 0) {
        // In debug mode, show that data was attempted to be sent but dropped
        std::cerr << "DEBUG: Data sent to unconnected UART" << (channel + 1) << " WebSocket, dropping " 
                  << length << " bytes" << std::endl;
    }
#endif
}

void UART::onWebsocketData(Channel channel, const u8* data, size_t length) {
    // Debug output for incoming websocket data
    if (debugMode) {
        std::ostringstream hexDump;
        hexDump << "DEBUG WebSocket UART" << (channel + 1) << " received " << length << " bytes:";
        
        for (size_t i = 0; i < length && i < 16; i++) {
            hexDump << " " << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(data[i]);
        }
        
        if (length > 16) {
            hexDump << " ...";
        }
        
        std::cout << hexDump.str() << std::dec << std::endl;
    }
    
    // Add data to RX FIFO if receiver is enabled
    if (registers.uart[channel].control & CTRL_RX_ENABLE) {
        std::lock_guard<std::mutex> lock(rxMutex);
        
        for (size_t i = 0; i < length; i++) {
            if (rxFifo[channel].size() < FIFO_SIZE) {
                rxFifo[channel].push(data[i]);
            } else {
                // FIFO overflow
                registers.uart[channel].status |= STAT_RX_OVERRUN;
                
                if (debugMode) {
                    std::cout << "DEBUG UART" << (channel + 1) << " WebSocket RX OVERFLOW" << std::endl;
                }
                break;
            }
        }
        
        // Set RX_READY status bit if data was received
        if (!rxFifo[channel].empty()) {
            registers.uart[channel].status |= STAT_RX_READY;
            updateInterrupts(channel);
        }
    } else if (debugMode) {
        std::cout << "DEBUG UART" << (channel + 1) << " RX disabled, dropping websocket data" << std::endl;
    }
}
#endif

#ifndef __EMSCRIPTEN__
int UART::connectSerial(const char* device1, const char* device2) {
    // Setup first UART
    if (device1) {
        serialFd[UART1] = open(device1, O_RDWR | O_NOCTTY | O_NONBLOCK);
        if (serialFd[UART1] < 0) {
            std::cerr << "Failed to open serial port: " << device1 << std::endl;
            return -1;
        }
        
        struct termios tty;
        memset(&tty, 0, sizeof(tty));
        if (tcgetattr(serialFd[UART1], &tty) != 0) {
            std::cerr << "Error from tcgetattr" << std::endl;
            close(serialFd[UART1]);
            return -1;
        }

        // Set baud rate, 8N1, no flow control
        cfsetospeed(&tty, B9600);
        cfsetispeed(&tty, B9600);
        tty.c_cflag |= (CLOCAL | CREAD);
        tty.c_cflag &= ~CSIZE;
        tty.c_cflag |= CS8;
        tty.c_cflag &= ~PARENB;
        tty.c_cflag &= ~CSTOPB;
        tty.c_cflag &= ~CRTSCTS;
        tty.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
        tty.c_iflag &= ~(IXON | IXOFF | IXANY);
        tty.c_oflag &= ~OPOST;
        tty.c_cc[VMIN] = 0;
        tty.c_cc[VTIME] = 0;
        
        if (tcsetattr(serialFd[UART1], TCSANOW, &tty) != 0) {
            std::cerr << "Error from tcsetattr" << std::endl;
            close(serialFd[UART1]);
            return -1;
        }
        
        serialConnected[UART1] = true;
        std::cout << "Connected to serial port: " << device1 << std::endl;
    }
    
    // Setup second UART if provided
    if (device2) {
        serialFd[UART2] = open(device2, O_RDWR | O_NOCTTY | O_NONBLOCK);
        if (serialFd[UART2] < 0) {
            std::cerr << "Failed to open serial port: " << device2 << std::endl;
            // Don't fail if only UART2 fails
            return 0;
        }
        
        struct termios tty;
        memset(&tty, 0, sizeof(tty));
        if (tcgetattr(serialFd[UART2], &tty) != 0) {
            std::cerr << "Error from tcgetattr" << std::endl;
            close(serialFd[UART2]);
            return 0;
        }

        // Set baud rate, 8N1, no flow control
        cfsetospeed(&tty, B9600);
        cfsetispeed(&tty, B9600);
        tty.c_cflag |= (CLOCAL | CREAD);
        tty.c_cflag &= ~CSIZE;
        tty.c_cflag |= CS8;
        tty.c_cflag &= ~PARENB;
        tty.c_cflag &= ~CSTOPB;
        tty.c_cflag &= ~CRTSCTS;
        tty.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
        tty.c_iflag &= ~(IXON | IXOFF | IXANY);
        tty.c_oflag &= ~OPOST;
        tty.c_cc[VMIN] = 0;
        tty.c_cc[VTIME] = 0;
        
        if (tcsetattr(serialFd[UART2], TCSANOW, &tty) != 0) {
            std::cerr << "Error from tcsetattr" << std::endl;
            close(serialFd[UART2]);
            return 0;
        }
        
        serialConnected[UART2] = true;
        std::cout << "Connected to serial port: " << device2 << std::endl;
    }
    
    return 0;
}

void UART::pollSerial() {
    for (int i = 0; i < 2; i++) {
        if (serialConnected[i]) {
            // Read data
            uint8_t buffer[64];
            int n = read(serialFd[i], buffer, sizeof(buffer));
            if (n > 0) {
                Channel channel = static_cast<Channel>(i);
                if (debugMode) {
                    std::cout << "DEBUG Serial UART" << (i + 1) << " received " << n << " bytes" << std::endl;
                }
                for (int j = 0; j < n; j++) {
                    send(channel, buffer[j]);
                }
            }
            
            // Send any pending data
            std::lock_guard<std::mutex> txLock(txMutex);
            while (!txFifo[i].empty()) {
                uint8_t byte = txFifo[i].front();
                if (write(serialFd[i], &byte, 1) > 0) {
                    txFifo[i].pop();
                    
                    if (debugMode) {
                        std::cout << "DEBUG Serial UART" << (i + 1) << " sent: 0x" 
                                  << std::hex << std::setw(2) << std::setfill('0') 
                                  << static_cast<int>(byte) << " '" 
                                  << (isprint(byte) ? static_cast<char>(byte) : '.') 
                                  << "'" << std::dec << std::endl;
                    }
                } else if (errno == EAGAIN) {
                    // Would block, try again later
                    break;
                } else {
                    // Error
                    std::cerr << "Error writing to serial port" << std::endl;
                    break;
                }
            }
        }
    }
}

int UART::connectPipes(const char* inPipe1, const char* outPipe1, 
                       const char* inPipe2, const char* outPipe2) {
    // Create pipes if they don't exist
    if (inPipe1) {
        mkfifo(inPipe1, 0666);
    }
    if (outPipe1) {
        mkfifo(outPipe1, 0666);
    }
    
    // Open pipes for UART1
    if (inPipe1 && outPipe1) {
        pipeFdIn[UART1] = open(inPipe1, O_RDONLY | O_NONBLOCK);
        if (pipeFdIn[UART1] < 0) {
            std::cerr << "Failed to open input pipe: " << inPipe1 << std::endl;
            return -1;
        }
        
        pipeFdOut[UART1] = open(outPipe1, O_WRONLY | O_NONBLOCK);
        if (pipeFdOut[UART1] < 0) {
            std::cerr << "Failed to open output pipe: " << outPipe1 << std::endl;
            close(pipeFdIn[UART1]);
            return -1;
        }
        
        pipeConnected[UART1] = true;
        std::cout << "Connected to pipes: " << inPipe1 << " and " << outPipe1 << std::endl;
    }
    
    // Setup UART2 pipes if provided
    if (inPipe2 && outPipe2) {
        // Create pipes if they don't exist
        mkfifo(inPipe2, 0666);
        mkfifo(outPipe2, 0666);
        
        pipeFdIn[UART2] = open(inPipe2, O_RDONLY | O_NONBLOCK);
        if (pipeFdIn[UART2] < 0) {
            std::cerr << "Failed to open input pipe: " << inPipe2 << std::endl;
            // Don't fail if only UART2 fails
            return 0;
        }
        
        pipeFdOut[UART2] = open(outPipe2, O_WRONLY | O_NONBLOCK);
        if (pipeFdOut[UART2] < 0) {
            std::cerr << "Failed to open output pipe: " << outPipe2 << std::endl;
            close(pipeFdIn[UART2]);
            return 0;
        }
        
        pipeConnected[UART2] = true;
        std::cout << "Connected to pipes: " << inPipe2 << " and " << outPipe2 << std::endl;
    }
    
    return 0;
}

void UART::pollPipes() {
    for (int i = 0; i < 2; i++) {
        if (pipeConnected[i]) {
            // Read data
            uint8_t buffer[64];
            int n = read(pipeFdIn[i], buffer, sizeof(buffer));
            if (n > 0) {
                Channel channel = static_cast<Channel>(i);
                if (debugMode) {
                    std::cout << "DEBUG Pipe UART" << (i + 1) << " received " << n << " bytes" << std::endl;
                }
                for (int j = 0; j < n; j++) {
                    send(channel, buffer[j]);
                }
            }
            
            // Send any pending data
            std::lock_guard<std::mutex> txLock(txMutex);
            while (!txFifo[i].empty()) {
                uint8_t byte = txFifo[i].front();
                if (write(pipeFdOut[i], &byte, 1) > 0) {
                    txFifo[i].pop();
                    
                    if (debugMode) {
                        std::cout << "DEBUG Pipe UART" << (i + 1) << " sent: 0x" 
                                  << std::hex << std::setw(2) << std::setfill('0') 
                                  << static_cast<int>(byte) << " '" 
                                  << (isprint(byte) ? static_cast<char>(byte) : '.') 
                                  << "'" << std::dec << std::endl;
                    }
                } else if (errno == EAGAIN) {
                    // Would block, try again later
                    break;
                } else {
                    // Error
                    std::cerr << "Error writing to pipe" << std::endl;
                    break;
                }
            }
        }
    }
}
#endif

void UART::setDebugMode(bool enabled) {
    debugMode = enabled;
    std::cout << "UART debug mode " << (enabled ? "enabled" : "disabled") << std::endl;
}

bool UART::isDebugMode() const {
    return debugMode;
} 