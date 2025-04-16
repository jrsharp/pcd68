#include "UART.h"
#include <iostream>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include <emscripten/websocket.h>
#endif

UART::UART(CPU* cpu, uint32_t start, uint32_t size) :
    Peripheral(start, size) {
    this->cpu = cpu;

#ifdef __EMSCRIPTEN__
    websocketId[UART1] = -1;
    websocketId[UART2] = -1;
    connected[UART1] = false;
    connected[UART2] = false;
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
        std::lock_guard<std::mutex> lock(rxMutex);
        if (rxFifo[channel].size() < FIFO_SIZE) {
            rxFifo[channel].push(byte);
            
            // Set RX_READY bit
            registers.uart[channel].status |= STAT_RX_READY;
            updateInterrupts(channel);
        } else {
            // FIFO overflow
            registers.uart[channel].status |= STAT_RX_OVERRUN;
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
    UART* uart = static_cast<UART*>(userData);
    
    if (eventType == EMSCRIPTEN_WEBSOCKET_MESSAGE_CALLBACK) {
        // Handle received data
        if (event->isText) {
            // Text data (convert to binary)
            const u8* data = reinterpret_cast<const u8*>(event->data);
            uart->onWebsocketData(UART::UART1, data, event->numBytes);
        } else {
            // Binary data
            const u8* data = reinterpret_cast<const u8*>(event->data);
            uart->onWebsocketData(UART::UART1, data, event->numBytes);
        }
        return EM_TRUE;
    }
    
    return EM_FALSE;
}

// Callback function to handle websocket messages for UART2
EM_BOOL websocket2_callback(int eventType, const EmscriptenWebSocketMessageEvent *event, void *userData) {
    UART* uart = static_cast<UART*>(userData);
    
    if (eventType == EMSCRIPTEN_WEBSOCKET_MESSAGE_CALLBACK) {
        // Handle received data
        if (event->isText) {
            // Text data (convert to binary)
            const u8* data = reinterpret_cast<const u8*>(event->data);
            uart->onWebsocketData(UART::UART2, data, event->numBytes);
        } else {
            // Binary data
            const u8* data = reinterpret_cast<const u8*>(event->data);
            uart->onWebsocketData(UART::UART2, data, event->numBytes);
        }
        return EM_TRUE;
    }
    
    return EM_FALSE;
}

// Callback for websocket open events
EM_BOOL websocket_open_callback(int eventType, const EmscriptenWebSocketOpenEvent *event, void *userData) {
    if (eventType == EMSCRIPTEN_WEBSOCKET_OPEN_CALLBACK) {
        // Get which socket this is (stored in user data high bits)
        uintptr_t channel = reinterpret_cast<uintptr_t>(userData) >> 32;
        UART* uart = reinterpret_cast<UART*>(reinterpret_cast<uintptr_t>(userData) & 0xFFFFFFFF);
        
        std::cout << "WebSocket for UART" << (channel+1) << " connected" << std::endl;
        return EM_TRUE;
    }
    
    return EM_FALSE;
}

int UART::connectWebsocket(const char* url1, const char* url2) {
    // Check if emscripten websocket API is supported
    if (!emscripten_websocket_is_supported()) {
        std::cerr << "WebSockets are not supported" << std::endl;
        return -1;
    }
    
    // Connect first UART
    if (url1) {
        EmscriptenWebSocketCreateAttributes attr;
        emscripten_websocket_init_create_attributes(&attr);
        attr.url = url1;
        attr.protocols = "binary";
        
        websocketId[UART1] = emscripten_websocket_new(&attr);
        if (websocketId[UART1] < 0) {
            std::cerr << "WebSocket creation for UART1 failed" << std::endl;
            return -1;
        }
        
        // Set up callbacks
        emscripten_websocket_set_onmessage_callback(websocketId[UART1], this, websocket1_callback);
        
        // Create userData that includes both the channel and the this pointer
        void* userData = reinterpret_cast<void*>((static_cast<uintptr_t>(UART1) << 32) | reinterpret_cast<uintptr_t>(this));
        emscripten_websocket_set_onopen_callback(websocketId[UART1], userData, websocket_open_callback);
        
        connected[UART1] = true;
    }
    
    // Connect second UART if URL is provided
    if (url2) {
        EmscriptenWebSocketCreateAttributes attr;
        emscripten_websocket_init_create_attributes(&attr);
        attr.url = url2;
        attr.protocols = "binary";
        
        websocketId[UART2] = emscripten_websocket_new(&attr);
        if (websocketId[UART2] < 0) {
            std::cerr << "WebSocket creation for UART2 failed" << std::endl;
            // Don't return error - continue with just UART1
        } else {
            // Set up callbacks
            emscripten_websocket_set_onmessage_callback(websocketId[UART2], this, websocket2_callback);
            
            // Create userData that includes both the channel and the this pointer
            void* userData = reinterpret_cast<void*>((static_cast<uintptr_t>(UART2) << 32) | reinterpret_cast<uintptr_t>(this));
            emscripten_websocket_set_onopen_callback(websocketId[UART2], userData, websocket_open_callback);
            
            connected[UART2] = true;
        }
    }
    
    return 0;
}

void UART::sendWebsocket(Channel channel, const u8* data, size_t length) {
    if (connected[channel] && websocketId[channel] >= 0) {
        emscripten_websocket_send_binary(websocketId[channel], data, length);
    }
}

void UART::onWebsocketData(Channel channel, const u8* data, size_t length) {
    // Add data to RX FIFO if receiver is enabled
    if (registers.uart[channel].control & CTRL_RX_ENABLE) {
        std::lock_guard<std::mutex> lock(rxMutex);
        
        for (size_t i = 0; i < length; i++) {
            if (rxFifo[channel].size() < FIFO_SIZE) {
                rxFifo[channel].push(data[i]);
            } else {
                // FIFO overflow
                registers.uart[channel].status |= STAT_RX_OVERRUN;
                break;
            }
        }
        
        // Set RX_READY status bit if data was received
        if (!rxFifo[channel].empty()) {
            registers.uart[channel].status |= STAT_RX_READY;
            updateInterrupts(channel);
        }
    }
}
#endif 