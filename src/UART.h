#pragma once

#include "PCD68_CPU.h"
#include "Peripheral.h"
#include <cstring>
#include <queue>
#include <array>
#include <mutex>
#include <vector>

extern u8* systemRam;

/**
 * UART (Universal Asynchronous Receiver/Transmitter) peripheral
 * 
 * Based on the Zilog Z8530 SCC (Serial Communications Controller) used in the Macintosh Plus.
 * Supports two channels (A and B) and interrupt-driven operation.
 * For Emscripten targets, can connect to a websocket server to provide virtual modem functionality.
 */
class UART : public Peripheral {

public:
    /** UART interrupt level (68000) */
    static constexpr u8 UART_INT_LEVEL_TX = 4;
    static constexpr u8 UART_INT_LEVEL_RX = 5;
    
    /** Default base address for peripheral */
    static constexpr u32 BASE_ADDR = 0x450000;
    
    /** Size of transmit and receive FIFOs */
    static constexpr u32 FIFO_SIZE = 16;
    
    /** Register offsets */
    enum RegOffset : u8 {
        CTRL_A      = 0x00,  // Channel A Control
        DATA_A      = 0x01,  // Channel A Data
        CTRL_B      = 0x02,  // Channel B Control
        DATA_B      = 0x03,  // Channel B Data
    };
    
    /** Channel selection */
    enum Channel : u8 {
        CHANNEL_A = 0,
        CHANNEL_B = 1
    };

    /** UART command register bits */
    enum CommandReg : u8 {
        CMD_RX_ENABLE       = 0x01,  // Enable receiver
        CMD_TX_ENABLE       = 0x02,  // Enable transmitter
        CMD_RTS             = 0x04,  // Request To Send
        CMD_RESET           = 0x08,  // Reset channel
        CMD_BREAK           = 0x10,  // Send break
        CMD_DTR             = 0x20,  // Data Terminal Ready
        CMD_RESET_ERR       = 0x40,  // Reset error flags
        CMD_RESET_INT       = 0x80   // Reset interrupt flags
    };
    
    /** UART status register bits */
    enum StatusReg : u8 {
        STAT_RX_READY       = 0x01,  // Receiver data available
        STAT_TX_EMPTY       = 0x02,  // Transmitter buffer empty
        STAT_DCD            = 0x04,  // Data Carrier Detect
        STAT_CTS            = 0x08,  // Clear To Send
        STAT_SYNC_HUNT      = 0x10,  // Synchronization/Hunt mode
        STAT_TX_UNDERRUN    = 0x20,  // Transmitter underrun/EOM
        STAT_BREAK          = 0x40,  // Break detected
        STAT_INT_PENDING    = 0x80   // Interrupt pending
    };
    
    /** UART interrupt control register bits */
    enum InterruptCtrlReg : u8 {
        INT_RX_AVAIL        = 0x01,  // Rx character available interrupt
        INT_TX_EMPTY        = 0x02,  // Tx buffer empty interrupt
        INT_EXT_STATUS      = 0x04,  // External/Status change interrupt
        INT_SPECIAL_RX      = 0x08,  // Special receive condition interrupt
        INT_MASTER_ENABLE   = 0x80   // Master interrupt enable
    };
    
    /** SCC Channel registers */
    struct ChannelRegs {
        // WR0-WR15: Write registers
        u8 wr[16];          // 16 write registers
        // RR0-RR15: Read registers
        u8 rr[16];          // 16 read registers
        
        // Internal state
        u8 rxBuffer;        // Receive buffer
        u8 txBuffer;        // Transmit buffer
        u8 status;          // Status register (RR0)
        u8 cmdReg;          // Command register
        u8 intCtrl;         // Interrupt control register
        u8 currentReg;      // Current register pointer
    };
    
    /** UART registers */
    struct Registers {
        ChannelRegs channel[2]; // Channel A and B registers
    };

    /**
     * Constructor
     *
     * @param cpu CPU instance
     * @param start base address
     * @param size size of memory
     */
    UART(CPU* cpu, uint32_t start, uint32_t size);

    /**
     * Initialize UART peripheral
     * For Emscripten, sets up the websocket connection
     */
    int init();
    
    /**
     * Send a byte to the UART
     * 
     * @param channel Channel to send on (A or B)
     * @param byte Byte to send
     */
    void send(Channel channel, u8 byte);
    
    /**
     * Receive a byte from the UART
     * 
     * @param channel Channel to receive on (A or B)
     * @return The received byte, or 0 if none available
     */
    u8 receive(Channel channel);
    
    /**
     * Poll UART for received data and handle TX/RX
     * Should be called periodically
     */
    void poll();
    
    /**
     * Reset the UART peripheral
     */
    void reset() override;
    
    /**
     * Read from UART registers
     */
    u8 read8(u32 addr) override;
    u16 read16(u32 addr) override;
    
    /**
     * Write to UART registers
     */
    void write8(u32 addr, u8 val) override;
    void write16(u32 addr, u16 val) override;

#ifdef __EMSCRIPTEN__
    /**
     * Connect to websocket server
     * 
     * @param url Websocket server URL
     * @return 0 on success, non-zero on failure
     */
    int connectWebsocket(const char* url);
    
    /**
     * Send data through websocket
     * 
     * @param data Data buffer
     * @param length Length of data
     */
    void sendWebsocket(const u8* data, size_t length);
    
    /**
     * Callback for websocket received data
     * 
     * @param data Data buffer
     * @param length Length of data
     */
    void onWebsocketData(const u8* data, size_t length);
#endif

protected:
    CPU* cpu;                    // CPU instance
    Registers registers;         // UART registers
    
    std::array<std::queue<u8>, 2> rxFifo;  // RX FIFO for both channels
    std::array<std::queue<u8>, 2> txFifo;  // TX FIFO for both channels
    
    std::mutex rxMutex;          // Mutex for RX FIFO access
    std::mutex txMutex;          // Mutex for TX FIFO access

    // Helper methods
    void updateInterrupts(Channel channel);
    void handleCommand(Channel channel, u8 cmd);
    void writeRegister(Channel channel, u8 regNum, u8 value);
    u8 readRegister(Channel channel, u8 regNum);

private:
#ifdef __EMSCRIPTEN__
    int websocketId;             // Emscripten websocket ID
    bool connected;              // Websocket connected flag
#endif
}; 