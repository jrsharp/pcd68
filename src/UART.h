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
 * UART - Dual-channel UART peripheral
 * 
 * Designed for easy use in 68k assembly and straightforward mapping to
 * ESP32 hardware. Uses a direct register model with no command registers.
 * 
 * For each channel:
 *   - TX data register (write to send data)
 *   - RX data register (read to get received data)
 *   - Status register (TX ready, RX ready, errors)
 *   - Control register (enable TX/RX, interrupt enables)
 */
class UART : public Peripheral {

public:
    /** UART interrupt levels (68000) */
    static constexpr u8 UART1_INT_LEVEL = 4;
    static constexpr u8 UART2_INT_LEVEL = 5;
    
    /** Default base address for peripheral */
    static constexpr u32 BASE_ADDR = 0x450000;
    
    /** Size of transmit and receive FIFOs */
    static constexpr u32 FIFO_SIZE = 16;
    
    /** Register offsets for UART 1 */
    enum UART1Regs : u8 {
        UART1_TX        = 0x00,  // UART 1 Transmit data (write)
        UART1_RX        = 0x01,  // UART 1 Receive data (read)
        UART1_STATUS    = 0x02,  // UART 1 Status register
        UART1_CONTROL   = 0x03,  // UART 1 Control register
    };
    
    /** Register offsets for UART 2 */
    enum UART2Regs : u8 {
        UART2_TX        = 0x04,  // UART 2 Transmit data (write)
        UART2_RX        = 0x05,  // UART 2 Receive data (read)
        UART2_STATUS    = 0x06,  // UART 2 Status register
        UART2_CONTROL   = 0x07,  // UART 2 Control register
    };

    /** Status register bits - same for both UARTs */
    enum StatusBits : u8 {
        STAT_RX_READY   = 0x01,  // Receiver has data available
        STAT_TX_EMPTY   = 0x02,  // Transmitter buffer is empty
        STAT_RX_OVERRUN = 0x04,  // Receiver overrun error
        STAT_FRAME_ERR  = 0x08,  // Framing error detected
        STAT_BREAK      = 0x10,  // Break condition detected
        STAT_CTS        = 0x20,  // Clear To Send signal active
        STAT_DSR        = 0x40,  // Data Set Ready signal active
        STAT_DCD        = 0x80,  // Data Carrier Detect signal active
    };
    
    /** Control register bits - same for both UARTs */
    enum ControlBits : u8 {
        CTRL_RX_ENABLE  = 0x01,  // Enable receiver
        CTRL_TX_ENABLE  = 0x02,  // Enable transmitter
        CTRL_RX_INT_EN  = 0x04,  // Enable receiver interrupts
        CTRL_TX_INT_EN  = 0x08,  // Enable transmitter interrupts
        CTRL_DTR        = 0x10,  // Data Terminal Ready signal
        CTRL_RTS        = 0x20,  // Request To Send signal
        CTRL_RESET_ERR  = 0x40,  // Reset error flags
        CTRL_LOOPBACK   = 0x80,  // Loopback mode
    };
    
    /** Baudrate settings (stored internally) */
    enum Baudrate : u8 {
        BAUD_300        = 0,
        BAUD_1200       = 1,
        BAUD_2400       = 2,
        BAUD_4800       = 3,
        BAUD_9600       = 4,
        BAUD_19200      = 5,
        BAUD_38400      = 6,
        BAUD_57600      = 7,
        BAUD_115200     = 8
    };
    
    /** Channel identifier */
    enum Channel : u8 {
        UART1 = 0,
        UART2 = 1
    };
    
    /** UART channel state */
    struct UartState {
        u8 txData;      // Transmit data register
        u8 rxData;      // Receive data register
        u8 status;      // Status register
        u8 control;     // Control register 
        u8 baudrate;    // Baudrate setting (internal)
    };
    
    /** UART peripheral state */
    struct Registers {
        UartState uart[2];  // State for both UARTs
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
     * Poll UART for received data and handle TX/RX
     * Should be called periodically
     */
    void poll();
    
    /**
     * Send a byte to the specified UART channel
     * 
     * @param channel UART channel (UART1 or UART2)
     * @param byte Data byte to send
     */
    void send(Channel channel, u8 byte);
    
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
     * Connect to websocket servers
     * 
     * @param url1 Websocket server URL for UART1
     * @param url2 Websocket server URL for UART2
     * @return 0 on success, non-zero on failure
     */
    int connectWebsocket(const char* url1, const char* url2 = nullptr);
    
    /**
     * Send data through websocket
     * 
     * @param channel UART channel
     * @param data Data buffer
     * @param length Length of data
     */
    void sendWebsocket(Channel channel, const u8* data, size_t length);
    
    /**
     * Callback for websocket received data
     * 
     * @param channel UART channel
     * @param data Data buffer
     * @param length Length of data
     */
    void onWebsocketData(Channel channel, const u8* data, size_t length);
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
    void processControlWrite(Channel channel, u8 value);

private:
#ifdef __EMSCRIPTEN__
    std::array<int, 2> websocketId;    // Emscripten websocket ID for each channel
    std::array<bool, 2> connected;     // Websocket connected flag for each channel
#endif
}; 