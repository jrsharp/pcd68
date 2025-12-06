/*
 * Copyright (c) 2024, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 *
 * DOS UART implementation for PCD-68
 * Uses BIOS int 14h for serial port access
 */

#ifdef __DJGPP__

#include "UART_DOS.h"
#include <dpmi.h>
#include <iostream>

// BIOS int 14h functions
#define BIOS_SERIAL_INIT    0x00
#define BIOS_SERIAL_SEND    0x01
#define BIOS_SERIAL_RECV    0x02
#define BIOS_SERIAL_STATUS  0x03

// Baudrate codes for BIOS int 14h
// Bits 7-5: baud rate (000=110, 001=150, 010=300, 011=600, 100=1200, 101=2400, 110=4800, 111=9600)
// Bits 4-3: parity (00=none, 01=odd, 11=even)
// Bit 2: stop bits (0=1, 1=2)
// Bits 1-0: word length (10=7bits, 11=8bits)
#define BIOS_BAUD_9600_8N1  0xE3  // 9600 baud, no parity, 1 stop, 8 bits

UART::UART(CPU* cpu, uint32_t start, uint32_t size) :
    Peripheral(start, size),
    cpu(cpu),
    debugMode(false) {

    comPort[0] = 0;
    comPort[1] = 0;
    serialConnected[0] = false;
    serialConnected[1] = false;

    statusReadCount[0] = 0;
    statusReadCount[1] = 0;
    lastStatusReadReport[0] = 0;
    lastStatusReadReport[1] = 0;
}

int UART::init() {
    reset();
    return 0;
}

void UART::reset() {
    // Clear registers
    for (int i = 0; i < 2; i++) {
        registers.uart[i].txData = 0;
        registers.uart[i].rxData = 0;
        registers.uart[i].status = STAT_TX_EMPTY;  // TX buffer empty
        registers.uart[i].control = 0;
        registers.uart[i].baudrate = BAUD_9600;

        // Clear FIFOs
        while (!rxFifo[i].empty()) rxFifo[i].pop();
        while (!txFifo[i].empty()) txFifo[i].pop();
    }
}

void UART::biosInitSerial(int port, int baudrate) {
    __dpmi_regs regs;
    regs.h.ah = BIOS_SERIAL_INIT;
    regs.h.al = BIOS_BAUD_9600_8N1;  // 9600 8N1 (BIOS only supports up to 9600)
    regs.x.dx = port - 1;  // COM1=0, COM2=1, etc.
    __dpmi_int(0x14, &regs);
}

int UART::biosSendByte(int port, u8 byte) {
    __dpmi_regs regs;
    regs.h.ah = BIOS_SERIAL_SEND;
    regs.h.al = byte;
    regs.x.dx = port - 1;
    __dpmi_int(0x14, &regs);

    // Check bit 7 of AH for error
    return (regs.h.ah & 0x80) ? -1 : 0;
}

int UART::biosReceiveByte(int port, u8* byte) {
    __dpmi_regs regs;
    regs.h.ah = BIOS_SERIAL_RECV;
    regs.x.dx = port - 1;
    __dpmi_int(0x14, &regs);

    // Check bit 7 of AH for error/timeout
    if (regs.h.ah & 0x80) {
        return -1;  // No data or error
    }

    *byte = regs.h.al;
    return 0;
}

int UART::biosGetStatus(int port) {
    __dpmi_regs regs;
    regs.h.ah = BIOS_SERIAL_STATUS;
    regs.x.dx = port - 1;
    __dpmi_int(0x14, &regs);

    // AH = line status, AL = modem status
    return (regs.h.ah << 8) | regs.h.al;
}

int UART::connectSerial(int com1, int com2) {
    if (com1 >= 1 && com1 <= 4) {
        comPort[0] = com1;
        biosInitSerial(com1, BAUD_9600);
        serialConnected[0] = true;
        std::cout << "UART1 connected to COM" << com1 << std::endl;
    }

    if (com2 >= 1 && com2 <= 4) {
        comPort[1] = com2;
        biosInitSerial(com2, BAUD_9600);
        serialConnected[1] = true;
        std::cout << "UART2 connected to COM" << com2 << std::endl;
    }

    return 0;
}

void UART::pollSerial() {
    for (int ch = 0; ch < 2; ch++) {
        if (!serialConnected[ch]) continue;

        // Check for received data
        int status = biosGetStatus(comPort[ch]);
        if (status & 0x0100) {  // Data ready bit in line status
            u8 byte;
            if (biosReceiveByte(comPort[ch], &byte) == 0) {
                if (rxFifo[ch].size() < FIFO_SIZE) {
                    rxFifo[ch].push(byte);
                    registers.uart[ch].status |= STAT_RX_READY;
                } else {
                    registers.uart[ch].status |= STAT_RX_OVERRUN;
                }
            }
        }

        // Send any pending TX data
        while (!txFifo[ch].empty()) {
            u8 byte = txFifo[ch].front();
            if (biosSendByte(comPort[ch], byte) == 0) {
                txFifo[ch].pop();
            } else {
                break;  // TX not ready, try again later
            }
        }

        if (txFifo[ch].empty()) {
            registers.uart[ch].status |= STAT_TX_EMPTY;
        }
    }
}

void UART::poll() {
    // Process loopback mode
    for (int ch = 0; ch < 2; ch++) {
        if (registers.uart[ch].control & CTRL_LOOPBACK) {
            // In loopback, TX data goes directly to RX
            while (!txFifo[ch].empty()) {
                u8 byte = txFifo[ch].front();
                txFifo[ch].pop();
                if (rxFifo[ch].size() < FIFO_SIZE) {
                    rxFifo[ch].push(byte);
                    registers.uart[ch].status |= STAT_RX_READY;
                }
            }
            registers.uart[ch].status |= STAT_TX_EMPTY;
        }
    }

    // Update interrupts
    updateInterrupts(UART1);
    updateInterrupts(UART2);
}

void UART::send(Channel channel, u8 byte) {
    if (txFifo[channel].size() < FIFO_SIZE) {
        txFifo[channel].push(byte);
        registers.uart[channel].status &= ~STAT_TX_EMPTY;
    }
}

void UART::updateInterrupts(Channel channel) {
    bool shouldInterrupt = false;

    // RX interrupt
    if ((registers.uart[channel].control & CTRL_RX_INT_EN) &&
        (registers.uart[channel].status & STAT_RX_READY)) {
        shouldInterrupt = true;
    }

    // TX interrupt
    if ((registers.uart[channel].control & CTRL_TX_INT_EN) &&
        (registers.uart[channel].status & STAT_TX_EMPTY)) {
        shouldInterrupt = true;
    }

    if (shouldInterrupt) {
        u8 level = (channel == UART1) ? UART1_INT_LEVEL : UART2_INT_LEVEL;
        cpu->setIPL(level);
    }
}

void UART::processControlWrite(Channel channel, u8 value) {
    // Handle reset errors bit
    if (value & CTRL_RESET_ERR) {
        registers.uart[channel].status &= ~(STAT_RX_OVERRUN | STAT_FRAME_ERR | STAT_BREAK);
        value &= ~CTRL_RESET_ERR;  // Self-clearing bit
    }

    registers.uart[channel].control = value;
}

u8 UART::read8(u32 addr) {
    u32 offset = addr - BASE_ADDR;

    switch (offset) {
        case UART1_RX:
            if (!rxFifo[0].empty()) {
                registers.uart[0].rxData = rxFifo[0].front();
                rxFifo[0].pop();
                if (rxFifo[0].empty()) {
                    registers.uart[0].status &= ~STAT_RX_READY;
                }
            }
            return registers.uart[0].rxData;

        case UART1_STATUS:
            statusReadCount[0]++;
            return registers.uart[0].status;

        case UART1_CONTROL:
            return registers.uart[0].control;

        case UART2_RX:
            if (!rxFifo[1].empty()) {
                registers.uart[1].rxData = rxFifo[1].front();
                rxFifo[1].pop();
                if (rxFifo[1].empty()) {
                    registers.uart[1].status &= ~STAT_RX_READY;
                }
            }
            return registers.uart[1].rxData;

        case UART2_STATUS:
            statusReadCount[1]++;
            return registers.uart[1].status;

        case UART2_CONTROL:
            return registers.uart[1].control;

        default:
            return 0;
    }
}

u16 UART::read16(u32 addr) {
    return (read8(addr) << 8) | read8(addr + 1);
}

void UART::write8(u32 addr, u8 val) {
    u32 offset = addr - BASE_ADDR;

    switch (offset) {
        case UART1_TX:
            registers.uart[0].txData = val;
            if (registers.uart[0].control & CTRL_TX_ENABLE) {
                send(UART1, val);
            }
            if (debugMode) {
                std::cout << "UART1 TX: 0x" << std::hex << (int)val << std::dec;
                if (val >= 0x20 && val < 0x7F) {
                    std::cout << " '" << (char)val << "'";
                }
                std::cout << std::endl;
            }
            break;

        case UART1_CONTROL:
            processControlWrite(UART1, val);
            break;

        case UART2_TX:
            registers.uart[1].txData = val;
            if (registers.uart[1].control & CTRL_TX_ENABLE) {
                send(UART2, val);
            }
            if (debugMode) {
                std::cout << "UART2 TX: 0x" << std::hex << (int)val << std::dec;
                if (val >= 0x20 && val < 0x7F) {
                    std::cout << " '" << (char)val << "'";
                }
                std::cout << std::endl;
            }
            break;

        case UART2_CONTROL:
            processControlWrite(UART2, val);
            break;
    }
}

void UART::write16(u32 addr, u16 val) {
    write8(addr, val >> 8);
    write8(addr + 1, val & 0xFF);
}

void UART::setDebugMode(bool enabled) {
    debugMode = enabled;
}

bool UART::isDebugMode() const {
    return debugMode;
}

#endif // __DJGPP__
