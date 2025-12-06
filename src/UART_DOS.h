/*
 * Copyright (c) 2024, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 *
 * DOS UART implementation for PCD-68
 * Simplified version without threading/mutex support
 * Supports COM port serial communication via BIOS
 */

#pragma once

#ifdef __DJGPP__

#include "PCD68_CPU.h"
#include "Peripheral.h"
#include <cstring>
#include <queue>
#include <array>

extern u8* systemRam;

/**
 * UART_DOS - Dual-channel UART peripheral for DOS
 *
 * Uses BIOS int 14h for serial communication.
 * No threading or mutex required since DOS is single-threaded.
 */
class UART : public Peripheral {

public:
    /** UART interrupt levels (68000) */
    static constexpr u8 UART1_INT_LEVEL = 4;
    static constexpr u8 UART2_INT_LEVEL = 5;

    /** Default base address for peripheral */
    static constexpr u32 BASE_ADDR = 0x450000;

    /** Size of transmit and receive FIFOs */
    static constexpr u32 FIFO_SIZE = 256;

    /** Register offsets for UART 1 */
    enum UART1Regs : u8 {
        UART1_TX        = 0x00,
        UART1_RX        = 0x01,
        UART1_STATUS    = 0x02,
        UART1_CONTROL   = 0x03,
    };

    /** Register offsets for UART 2 */
    enum UART2Regs : u8 {
        UART2_TX        = 0x04,
        UART2_RX        = 0x05,
        UART2_STATUS    = 0x06,
        UART2_CONTROL   = 0x07,
    };

    /** Status register bits */
    enum StatusBits : u8 {
        STAT_RX_READY   = 0x01,
        STAT_TX_EMPTY   = 0x02,
        STAT_RX_OVERRUN = 0x04,
        STAT_FRAME_ERR  = 0x08,
        STAT_BREAK      = 0x10,
        STAT_CTS        = 0x20,
        STAT_DSR        = 0x40,
        STAT_DCD        = 0x80,
    };

    /** Control register bits */
    enum ControlBits : u8 {
        CTRL_RX_ENABLE  = 0x01,
        CTRL_TX_ENABLE  = 0x02,
        CTRL_RX_INT_EN  = 0x04,
        CTRL_TX_INT_EN  = 0x08,
        CTRL_DTR        = 0x10,
        CTRL_RTS        = 0x20,
        CTRL_RESET_ERR  = 0x40,
        CTRL_LOOPBACK   = 0x80,
    };

    /** Baudrate settings */
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
        u8 txData;
        u8 rxData;
        u8 status;
        u8 control;
        u8 baudrate;
    };

    /** UART peripheral state */
    struct Registers {
        UartState uart[2];
    };

    /**
     * Constructor
     */
    UART(CPU* cpu, uint32_t start, uint32_t size);

    /**
     * Initialize UART peripheral
     */
    int init();

    /**
     * Poll UART for received data
     */
    void poll();

    /**
     * Send a byte to the specified UART channel
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

    /**
     * Enable or disable debug mode
     */
    void setDebugMode(bool enabled);

    /**
     * Check if debug mode is enabled
     */
    bool isDebugMode() const;

    /**
     * Connect to COM ports
     *
     * @param com1 COM port number for UART1 (1-4, or 0 to disable)
     * @param com2 COM port number for UART2 (1-4, or 0 to disable)
     * @return 0 on success
     */
    int connectSerial(int com1, int com2 = 0);

    /**
     * Poll serial ports for data
     */
    void pollSerial();

protected:
    CPU* cpu;
    Registers registers;

    std::array<std::queue<u8>, 2> rxFifo;
    std::array<std::queue<u8>, 2> txFifo;

    bool debugMode;

    mutable uint32_t statusReadCount[2];
    mutable uint32_t lastStatusReadReport[2];

    void updateInterrupts(Channel channel);
    void processControlWrite(Channel channel, u8 value);

private:
    std::array<int, 2> comPort;        // COM port numbers (1-4)
    std::array<bool, 2> serialConnected;

    // BIOS serial helpers
    void biosInitSerial(int port, int baudrate);
    int biosSendByte(int port, u8 byte);
    int biosReceiveByte(int port, u8* byte);
    int biosGetStatus(int port);
};

#endif // __DJGPP__
