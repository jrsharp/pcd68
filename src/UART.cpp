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
    websocketId = -1;
    connected = false;
#endif
}

int UART::init() {
    // Initialize both channels
    for (int i = 0; i < 2; i++) {
        // Initialize registers
        memset(&registers.channel[i], 0, sizeof(ChannelRegs));
        
        // Set default status bits
        registers.channel[i].status = STAT_TX_EMPTY;
        registers.channel[i].cmdReg = 0;
        registers.channel[i].intCtrl = 0;
        registers.channel[i].currentReg = 0;
        
        // Initialize FIFOs
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
        
        // Map offset to appropriate register
        switch (offset) {
            case CTRL_A:
                return readRegister(CHANNEL_A, registers.channel[CHANNEL_A].currentReg);
                
            case DATA_A:
                // Reading from data register clears RX_READY bit
                registers.channel[CHANNEL_A].status &= ~STAT_RX_READY;
                updateInterrupts(CHANNEL_A);
                return registers.channel[CHANNEL_A].rxBuffer;
                
            case CTRL_B:
                return readRegister(CHANNEL_B, registers.channel[CHANNEL_B].currentReg);
                
            case DATA_B:
                // Reading from data register clears RX_READY bit
                registers.channel[CHANNEL_B].status &= ~STAT_RX_READY;
                updateInterrupts(CHANNEL_B);
                return registers.channel[CHANNEL_B].rxBuffer;
                
            default:
                return 0;
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
        
        // Map offset to appropriate register
        switch (offset) {
            case CTRL_A:
                // Handle command/control write for channel A
                // Check if it's a register select or command
                if ((val & 0xF0) == 0) {
                    // Register select command
                    registers.channel[CHANNEL_A].currentReg = val & 0x0F;
                } else {
                    // Command to current register
                    writeRegister(CHANNEL_A, registers.channel[CHANNEL_A].currentReg, val);
                }
                break;
                
            case DATA_A:
                // Writing to data register is transmitting
                registers.channel[CHANNEL_A].txBuffer = val;
                
                // Add to TX FIFO
                std::lock_guard<std::mutex> lock(txMutex);
                txFifo[CHANNEL_A].push(val);
                
                // Set TX_EMPTY bit to indicate buffer can accept more data
                registers.channel[CHANNEL_A].status |= STAT_TX_EMPTY;
                updateInterrupts(CHANNEL_A);
                break;
                
            case CTRL_B:
                // Handle command/control write for channel B
                // Check if it's a register select or command
                if ((val & 0xF0) == 0) {
                    // Register select command
                    registers.channel[CHANNEL_B].currentReg = val & 0x0F;
                } else {
                    // Command to current register
                    writeRegister(CHANNEL_B, registers.channel[CHANNEL_B].currentReg, val);
                }
                break;
                
            case DATA_B:
                // Writing to data register is transmitting
                registers.channel[CHANNEL_B].txBuffer = val;
                
                // Add to TX FIFO
                std::lock_guard<std::mutex> lock(txMutex);
                txFifo[CHANNEL_B].push(val);
                
                // Set TX_EMPTY bit to indicate buffer can accept more data
                registers.channel[CHANNEL_B].status |= STAT_TX_EMPTY;
                updateInterrupts(CHANNEL_B);
                break;
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
    std::lock_guard<std::mutex> lock(txMutex);
    txFifo[channel].push(byte);
    
    // Set STAT_TX_EMPTY if the FIFO is not full
    if (txFifo[channel].size() < FIFO_SIZE) {
        registers.channel[channel].status |= STAT_TX_EMPTY;
    } else {
        registers.channel[channel].status &= ~STAT_TX_EMPTY;
    }
    
    updateInterrupts(channel);
}

u8 UART::receive(Channel channel) {
    std::lock_guard<std::mutex> lock(rxMutex);
    if (rxFifo[channel].empty()) {
        return 0;
    }
    
    u8 byte = rxFifo[channel].front();
    rxFifo[channel].pop();
    
    // If FIFO is now empty, clear RX_READY status
    if (rxFifo[channel].empty()) {
        registers.channel[channel].status &= ~STAT_RX_READY;
    }
    
    updateInterrupts(channel);
    return byte;
}

void UART::poll() {
    // Check transmit FIFOs and handle outgoing data
    for (int i = 0; i < 2; i++) {
        Channel channel = static_cast<Channel>(i);
        
        // Process TX FIFO
        std::lock_guard<std::mutex> txLock(txMutex);
        if (!txFifo[channel].empty() && (registers.channel[channel].cmdReg & CMD_TX_ENABLE)) {
            // Get byte from TX FIFO
            u8 byte = txFifo[channel].front();
            txFifo[channel].pop();
            
            // In a real implementation, this would actually transmit the byte
            // For Emscripten, we'll send it over websocket
#ifdef __EMSCRIPTEN__
            if (connected && channel == CHANNEL_A) {
                sendWebsocket(&byte, 1);
            }
#endif
            
            // Update TX status
            if (txFifo[channel].empty()) {
                registers.channel[channel].status |= STAT_TX_EMPTY;
                updateInterrupts(channel);
            }
        }
        
        // Process RX FIFO
        std::lock_guard<std::mutex> rxLock(rxMutex);
        if (!rxFifo[channel].empty() && (registers.channel[channel].cmdReg & CMD_RX_ENABLE)) {
            // Set RX_READY status bit
            registers.channel[channel].status |= STAT_RX_READY;
            
            // Move data from FIFO to RX buffer
            registers.channel[channel].rxBuffer = rxFifo[channel].front();
            
            // Update interrupts
            updateInterrupts(channel);
        }
    }
}

void UART::updateInterrupts(Channel channel) {
    // Check if any interrupts are pending
    bool hasInterrupt = false;
    
    // RX available interrupt
    if ((registers.channel[channel].status & STAT_RX_READY) && 
        (registers.channel[channel].intCtrl & INT_RX_AVAIL)) {
        hasInterrupt = true;
        registers.channel[channel].status |= STAT_INT_PENDING;
        cpu->setIPL(UART_INT_LEVEL_RX);
    }
    
    // TX empty interrupt
    if ((registers.channel[channel].status & STAT_TX_EMPTY) && 
        (registers.channel[channel].intCtrl & INT_TX_EMPTY)) {
        hasInterrupt = true;
        registers.channel[channel].status |= STAT_INT_PENDING;
        cpu->setIPL(UART_INT_LEVEL_TX);
    }
    
    if (!hasInterrupt) {
        registers.channel[channel].status &= ~STAT_INT_PENDING;
        cpu->setIPL(0); // Clear interrupt if no longer needed
    }
}

void UART::handleCommand(Channel channel, u8 cmd) {
    registers.channel[channel].cmdReg = cmd;
    
    // Handle reset command
    if (cmd & CMD_RESET) {
        // Reset this channel
        memset(&registers.channel[channel], 0, sizeof(ChannelRegs));
        registers.channel[channel].status = STAT_TX_EMPTY;
        
        // Clear FIFOs
        std::lock_guard<std::mutex> rxLock(rxMutex);
        std::lock_guard<std::mutex> txLock(txMutex);
        while (!rxFifo[channel].empty()) rxFifo[channel].pop();
        while (!txFifo[channel].empty()) txFifo[channel].pop();
    }
    
    // Handle interrupts
    if (cmd & CMD_RESET_INT) {
        // Reset interrupt status
        registers.channel[channel].status &= ~STAT_INT_PENDING;
        cpu->setIPL(0);
    }
    
    // Handle error reset
    if (cmd & CMD_RESET_ERR) {
        // Clear error bits
        registers.channel[channel].status &= ~(STAT_TX_UNDERRUN | STAT_BREAK);
    }
}

void UART::writeRegister(Channel channel, u8 regNum, u8 value) {
    // Store in write register
    registers.channel[channel].wr[regNum] = value;
    
    // Handle special cases based on register number
    switch (regNum) {
        case 0: // Command register
            handleCommand(channel, value);
            break;
            
        case 1: // Interrupt control
            registers.channel[channel].intCtrl = value;
            updateInterrupts(channel);
            break;
            
        // Additional register handlers would go here
    }
}

u8 UART::readRegister(Channel channel, u8 regNum) {
    // Handle special cases based on register number
    switch (regNum) {
        case 0: // Status register
            return registers.channel[channel].status;
            
        // Additional register handlers would go here
            
        default:
            // Return from read register array
            return registers.channel[channel].rr[regNum];
    }
}

#ifdef __EMSCRIPTEN__
// Emscripten-specific websocket implementation

// Callback function to handle websocket messages
EM_BOOL websocket_callback(int eventType, const EmscriptenWebSocketMessageEvent *event, void *userData) {
    UART* uart = static_cast<UART*>(userData);
    
    if (eventType == EMSCRIPTEN_WEBSOCKET_MESSAGE_CALLBACK) {
        // Handle received data
        if (event->isText) {
            // Text data (convert to binary)
            const u8* data = reinterpret_cast<const u8*>(event->data);
            uart->onWebsocketData(data, event->numBytes);
        } else {
            // Binary data
            const u8* data = reinterpret_cast<const u8*>(event->data);
            uart->onWebsocketData(data, event->numBytes);
        }
        return EM_TRUE;
    }
    
    return EM_FALSE;
}

// Callback for websocket open/close/error events
EM_BOOL websocket_open_callback(int eventType, const EmscriptenWebSocketOpenEvent *event, void *userData) {
    UART* uart = static_cast<UART*>(userData);
    
    if (eventType == EMSCRIPTEN_WEBSOCKET_OPEN_CALLBACK) {
        // Websocket connected
        std::cout << "Websocket connected" << std::endl;
        return EM_TRUE;
    }
    
    return EM_FALSE;
}

int UART::connectWebsocket(const char* url) {
    // Check if emscripten websocket API is supported
    if (!emscripten_websocket_is_supported()) {
        std::cerr << "WebSockets are not supported" << std::endl;
        return -1;
    }
    
    // Create websocket
    EmscriptenWebSocketCreateAttributes attr;
    emscripten_websocket_init_create_attributes(&attr);
    attr.url = url;
    attr.protocols = "binary";
    
    websocketId = emscripten_websocket_new(&attr);
    if (websocketId < 0) {
        std::cerr << "WebSocket creation failed" << std::endl;
        return -1;
    }
    
    // Set callbacks
    emscripten_websocket_set_onmessage_callback(websocketId, this, websocket_callback);
    emscripten_websocket_set_onopen_callback(websocketId, this, websocket_open_callback);
    
    connected = true;
    return 0;
}

void UART::sendWebsocket(const u8* data, size_t length) {
    if (connected && websocketId >= 0) {
        emscripten_websocket_send_binary(websocketId, data, length);
    }
}

void UART::onWebsocketData(const u8* data, size_t length) {
    // Process incoming data from websocket
    std::lock_guard<std::mutex> lock(rxMutex);
    
    // Add to RX FIFO (channel A)
    for (size_t i = 0; i < length; i++) {
        if (rxFifo[CHANNEL_A].size() < FIFO_SIZE) {
            rxFifo[CHANNEL_A].push(data[i]);
        }
    }
    
    // Set RX_READY status bit
    if (!rxFifo[CHANNEL_A].empty()) {
        registers.channel[CHANNEL_A].status |= STAT_RX_READY;
        updateInterrupts(CHANNEL_A);
    }
}
#endif 