/*
 * Zephyr-compatible UART implementation
 * Provides basic UART functionality without file descriptor/networking complexity
 */

#include "UART.h"
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(uart, LOG_LEVEL_DBG);

UART::UART(CPU* cpu, uint32_t start, uint32_t memorySize) : Peripheral(start, memorySize) {
    this->cpu = cpu;
    debugMode = false;
    
    // Initialize Zephyr-specific circular buffers
    for (int i = 0; i < 2; i++) {
        rxHead[i] = rxTail[i] = 0;
        txHead[i] = txTail[i] = 0;
        connected[i] = false;
        statusReadCount[i] = 0;
        lastStatusReadReport[i] = 0;
    }
}

void UART::reset() {
    // Reset all registers - simplified for Zephyr
    for (int i = 0; i < 2; i++) {
        // Clear buffers
        rxHead[i] = rxTail[i] = 0;
        txHead[i] = txTail[i] = 0;
    }
}

void UART::setDebugMode(bool enabled) {
    debugMode = enabled;
    if (debugMode) {
        LOG_INF("UART debug mode %s", enabled ? "enabled" : "disabled");
    }
}

u8 UART::read8(u32 addr) {
    if (addr < getBaseAddress() || addr >= getEndAddress()) {
        return 0;
    }
    
    u32 offset = addr - getBaseAddress();
    Channel channel = (offset >= 0x10) ? Channel::UART2 : Channel::UART1;
    int ch = static_cast<int>(channel);
    u8 reg = offset & 0x0F;
    
    switch (reg) {
        case 0x00: // Status register
            statusReadCount[ch]++;
            return getStatusRegister(channel);
            
        case 0x01: // Data register (read)
            if (!rxFifoEmpty(channel)) {
                u8 data = popRxByte(channel);
                if (debugMode) {
                    LOG_DBG("UART%d RX: 0x%02x ('%c')", ch + 1, data, 
                           (data >= 32 && data < 127) ? data : '.');
                }
                return data;
            }
            return 0;
            
        default:
            return 0;
    }
}

void UART::write8(u32 addr, u8 val) {
    if (addr < getBaseAddress() || addr >= getEndAddress()) {
        return;
    }
    
    u32 offset = addr - getBaseAddress();
    Channel channel = (offset >= 0x10) ? Channel::UART2 : Channel::UART1;
    int ch = static_cast<int>(channel);
    u8 reg = offset & 0x0F;
    
    switch (reg) {
        case 0x00: // Control register
            processControlWrite(channel, val);
            break;
            
        case 0x01: // Data register (write)
            if (!txFifoFull(channel)) {
                pushTxByte(channel, val);
                if (debugMode) {
                    LOG_DBG("UART%d TX: 0x%02x ('%c')", ch + 1, val,
                           (val >= 32 && val < 127) ? val : '.');
                }
                
                // In Zephyr, we can echo data back for testing or log it
                // For now, just log transmitted data
                if (val >= 32 && val < 127) {
                    LOG_INF("UART%d: '%c'", ch + 1, val);
                } else {
                    LOG_INF("UART%d: 0x%02x", ch + 1, val);
                }
            }
            break;
    }
}

u16 UART::read16(u32 addr) {
    return (read8(addr) << 8) | read8(addr + 1);
}

void UART::write16(u32 addr, u16 val) {
    write8(addr, (val >> 8) & 0xFF);
    write8(addr + 1, val & 0xFF);
}

// Private helper methods for Zephyr circular buffer implementation
bool UART::rxFifoEmpty(Channel channel) {
    int ch = static_cast<int>(channel);
    return rxHead[ch] == rxTail[ch];
}

bool UART::rxFifoFull(Channel channel) {
    int ch = static_cast<int>(channel);
    return ((rxTail[ch] + 1) % 256) == rxHead[ch];
}

void UART::pushRxByte(Channel channel, u8 byte) {
    int ch = static_cast<int>(channel);
    if (!rxFifoFull(channel)) {
        rxFifo[ch][rxTail[ch]] = byte;
        rxTail[ch] = (rxTail[ch] + 1) % 256;
        updateInterrupts(channel);
    }
}

u8 UART::popRxByte(Channel channel) {
    int ch = static_cast<int>(channel);
    if (!rxFifoEmpty(channel)) {
        u8 byte = rxFifo[ch][rxHead[ch]];
        rxHead[ch] = (rxHead[ch] + 1) % 256;
        return byte;
    }
    return 0;
}

bool UART::txFifoEmpty(Channel channel) {
    int ch = static_cast<int>(channel);
    return txHead[ch] == txTail[ch];
}

bool UART::txFifoFull(Channel channel) {
    int ch = static_cast<int>(channel);
    return ((txTail[ch] + 1) % 256) == txHead[ch];
}

void UART::pushTxByte(Channel channel, u8 byte) {
    int ch = static_cast<int>(channel);
    if (!txFifoFull(channel)) {
        txFifo[ch][txTail[ch]] = byte;
        txTail[ch] = (txTail[ch] + 1) % 256;
        updateInterrupts(channel);
    }
}

u8 UART::popTxByte(Channel channel) {
    int ch = static_cast<int>(channel);
    if (!txFifoEmpty(channel)) {
        u8 byte = txFifo[ch][txHead[ch]];
        txHead[ch] = (txHead[ch] + 1) % 256;
        return byte;
    }
    return 0;
}

u8 UART::getStatusRegister(Channel channel) {
    int ch = static_cast<int>(channel);
    u8 status = 0;
    
    // Set status bits based on FIFO states
    if (!txFifoFull(channel)) {
        status |= 0x01; // TX ready
    }
    if (!rxFifoEmpty(channel)) {
        status |= 0x02; // RX data available
    }
    if (connected[ch]) {
        status |= 0x04; // Connected
    }
    
    return status;
}

void UART::updateInterrupts(Channel channel) {
    // For Zephyr, interrupts are handled differently
    // This is a simplified implementation
}

void UART::processControlWrite(Channel channel, u8 value) {
    int ch = static_cast<int>(channel);
    
    if (debugMode) {
        LOG_DBG("UART%d control write: 0x%02x", ch + 1, value);
    }
    
    // Process control register bits as needed
    // This is a simplified implementation for Zephyr
}