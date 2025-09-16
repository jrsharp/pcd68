// Lightweight PCD68 Virtual Machine for embedded targets
// Replaces full 68000 emulation with a simple bytecode interpreter
// to drastically reduce flash usage on nRF54H20

#pragma once

#include <stdint.h>
#include <string.h>

// Define Moira types for compatibility when VM is used
#ifndef USE_ZEPHYR
#include "Moira/Moira.h"
#else
namespace moira {
    typedef uint8_t u8;
    typedef uint16_t u16;
    typedef uint32_t u32;
}
using namespace moira;
#endif

#include "Peripheral.h"

namespace pcd68 {

enum Opcode : uint8_t {
    // Memory operations
    OP_LOAD_IMM = 0x01,    // Load immediate value to register
    OP_LOAD_MEM,           // Load from memory to register  
    OP_STORE_MEM,          // Store register to memory
    
    // Arithmetic
    OP_ADD,                // Add two registers
    OP_SUB,                // Subtract
    OP_MUL,                // Multiply
    OP_DIV,                // Divide
    OP_MOD,                // Modulo
    OP_INC,                // Increment register
    OP_DEC,                // Decrement register
    
    // Logic
    OP_AND,                // Bitwise AND
    OP_OR,                 // Bitwise OR
    OP_XOR,                // Bitwise XOR
    OP_NOT,                // Bitwise NOT
    OP_SHL,                // Shift left
    OP_SHR,                // Shift right
    
    // Control flow
    OP_JMP,                // Jump to address
    OP_JZ,                 // Jump if zero
    OP_JNZ,                // Jump if not zero
    OP_JEQ,                // Jump if equal
    OP_JNE,                // Jump if not equal
    OP_JLT,                // Jump if less than
    OP_JGT,                // Jump if greater than
    OP_CALL,               // Call subroutine
    OP_RET,                // Return from subroutine
    
    // I/O
    OP_IN,                 // Read from peripheral
    OP_OUT,                // Write to peripheral
    
    // System
    OP_HALT,               // Stop execution
    OP_NOP,                // No operation
    OP_INT,                // Software interrupt
    
    OP_MAX
};

class PCD68_VM {
public:
    static constexpr size_t NUM_REGISTERS = 16;
    static constexpr size_t STACK_SIZE = 1024;
    static constexpr size_t MAX_PERIPHERALS = 8;
    
    PCD68_VM();
    ~PCD68_VM() = default;
    
    // Initialize VM with ROM and RAM
    void init(uint8_t* rom, size_t romSize, uint8_t* ram, size_t ramSize);
    
    // Register peripheral device
    void registerPeripheral(uint32_t address, Peripheral* device);
    
    // Execute one instruction
    void step();
    
    // Execute until halt or cycles limit
    void run(uint32_t maxCycles = 0);
    
    // Reset VM state
    void reset();
    
    // Interrupt handling
    void raiseInterrupt(uint8_t level);
    
    // Get current state
    uint32_t getPC() const { return pc; }
    uint32_t getRegister(uint8_t reg) const { return registers[reg & 0xF]; }
    bool isHalted() const { return halted; }
    
private:
    // VM state
    uint32_t registers[NUM_REGISTERS];
    uint32_t pc;           // Program counter
    uint32_t sp;           // Stack pointer
    uint32_t flags;        // Status flags
    bool halted;
    
    // Memory
    uint8_t* rom;
    size_t romSize;
    uint8_t* ram;
    size_t ramSize;
    uint32_t stack[STACK_SIZE];
    
    // Peripherals
    struct PeripheralMapping {
        uint32_t address;
        Peripheral* device;
    };
    PeripheralMapping peripherals[MAX_PERIPHERALS];
    uint8_t numPeripherals;
    
    // Interrupt state
    uint8_t pendingInterrupts;
    uint8_t interruptMask;
    
    // Helper methods
    uint8_t fetchByte();
    uint16_t fetchWord();
    uint32_t fetchLong();
    
    uint32_t readMemory(uint32_t address, uint8_t size);
    void writeMemory(uint32_t address, uint32_t value, uint8_t size);
    
    Peripheral* findPeripheral(uint32_t address);
    
    void push(uint32_t value);
    uint32_t pop();
    
    void setFlag(uint8_t flag, bool value);
    bool getFlag(uint8_t flag) const;
};

} // namespace pcd68