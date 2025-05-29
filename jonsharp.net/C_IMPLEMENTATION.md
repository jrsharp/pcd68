# PCD-68 C Implementation Guide

This guide documents the progress on implementing C programs for the PCD-68 emulator, particularly focusing on memory-mapped peripherals.

## Memory Addresses

Based on examining the assembly code and testing, we've identified the following memory-mapped I/O addresses:

- **Screen Framebuffer**: 0x810000
- **Text Display Adapter (TDA)**: 0x410000
- **Keyboard Controller (KCTL)**: 0x420000
- **UART**: 0x450000

## Peripheral Headers

We've created C headers for each peripheral to simplify access:

### TDA (Text Display Adapter)

The TDA provides text-mode display capabilities with different character sizes:
- Register 0: Text mode (1 for 50-column, 2 for 80-column)
- Address space after register 0 is the character buffer (80x23 characters)

### KCTL (Keyboard Controller)

The KCTL provides access to keyboard input with a USB-like report system:
- Register 0: Status/control register (flags for report availability, etc.)
- Register 1: Number of reports in queue
- Register 2: Number of active keys in current report
- Register 3: Modifier byte
- Registers 4-10: Key array (7 bytes, one key code per byte)
- Register 11: Advance to next report (write any value)

## Current Progress

We've successfully created and tested several minimal C programs:

1. **minimal_display.c** - Successfully displays text on the screen using the TDA
2. **kbd_minimal.c** - Displays keyboard status without processing interrupts
3. **kbd_debug.c** - More detailed debugging of keyboard registers
4. **kbd_interrupt.c** - Test program with proper interrupt handling

## Working Display Code

Direct memory-mapped writes to the TDA work correctly. The following code initializes the TDA and displays text:

```c
/* Initialize TDA */
volatile unsigned char* tda = (volatile unsigned char*)TDA_BASE;
tda[0] = TEXT_MODE_80COL;  /* Set 80-column mode */

/* Clear the screen with spaces */
for (int i = 0; i < 80 * 23; i++) {
    tda[i+1] = ' ';
}

/* Display a message */
const char* message = "Hello, PCD-68!";
for (int i = 0; message[i] != 0; i++) {
    tda[i+1] = message[i];
}
```

## Resolving the Keyboard Interrupt Issue

The main issue with keyboard handling in C code was related to interrupt handling. Our analysis revealed several key differences between the assembly and C implementations:

1. **Interrupt Vector Table**: The C code was missing a proper interrupt handler at position 27 (IRQ Level 3)
2. **Interrupt Enabling**: The C code wasn't enabling interrupts with the appropriate status register value
3. **Interrupt Handler**: The interrupt handler wasn't properly defined with `__attribute__((interrupt))`

### The Solution

We've created a new test program (`kbd_interrupt.c`) that demonstrates correct keyboard handling:

```c
// Define the interrupt handler with the proper attribute
void __attribute__((interrupt)) keyboard_handler(void) {
    // Handle keyboard interrupt
    // (Keep this simple - just increment a counter)
    key_received++;

    // CRITICAL: Must clear the interrupt in the handler
    kctl[0] |= KCTL_STATUS_CLEAR_INTERRUPT;
}

// Set up the vector table with the handler at position 27
__attribute__((section(".vectors")))
vector_function vectors[] = {
    (vector_function)0xBFFFFF,  /* 0: Initial stack pointer */
    (vector_function)main,      /* 1: Reset vector (main program) */
    /* ... other vectors ... */
    (vector_function)keyboard_handler, /* 27: Level 3 interrupt autovector (keyboard) */
    /* ... remaining vectors ... */
};

// In main(), enable keyboard and interrupts
int main(void) {
    // ... initialization ...

    // Enable keyboard
    kctl[0] = KCTL_STATUS_KEYBOARD_ENABLED;

    // Enable interrupts in supervisor mode
    __asm__ __volatile__ ("move.w #0x2000, %sr");

    // ... main loop ...
}
```

## C Runtime Support

Since we're compiling with `-nostdlib`, we need to provide our own implementations of certain functions for math operations:

```c
// Division operation
int __divsi3(int numerator, int denominator) {
    int quotient = 0;
    int sign = 1;

    if (numerator < 0) {
        numerator = -numerator;
        sign = -sign;
    }

    if (denominator < 0) {
        denominator = -denominator;
        sign = -sign;
    }

    while (numerator >= denominator) {
        numerator -= denominator;
        quotient++;
    }

    return sign > 0 ? quotient : -quotient;
}

// Modulo operation
int __modsi3(int numerator, int denominator) {
    int remainder = numerator;

    if (remainder < 0) {
        remainder = -remainder;
    }

    if (denominator < 0) {
        denominator = -denominator;
    }

    while (remainder >= denominator) {
        remainder -= denominator;
    }

    return numerator < 0 ? -remainder : remainder;
}
```

## Best Practices for Memory-Mapped I/O

1. **Always use `volatile`** for memory-mapped registers to prevent compiler optimizations
2. **Structured access** makes code more readable:
   ```c
   typedef struct {
       volatile uint8_t status;
       volatile uint8_t count;
       // ... other registers ...
   } KCTL_Registers;
   #define KCTL ((volatile KCTL_Registers*)KCTL_BASE)
   ```
3. **Use helper macros** for common operations:
   ```c
   #define kctl_has_report() (KCTL->status & KCTL_STATUS_REPORT_AVAILABLE)
   #define kctl_next_report() (KCTL->next_report = 1)
   ```

## Building and Running C Programs

### Building:
```bash
m68k-elf-gcc -O0 -s -g -o program_name program_name.c -nostdlib -fomit-frame-pointer -mno-rtd -m68000 -msoft-float -mpcrel -T minimal.lds
m68k-elf-objcopy -O binary program_name program_name.bin
m68k-elf-objcopy -O ihex program_name program_name.hex
```

### Running:
```bash
./zig-out/bin/pcd68 ./jonsharp.net/program_name.bin -debug-kbd
```

## Next Steps

1. **Port the Cyberterminal**: Now that we've resolved the keyboard interrupt issues, we can port the full cyberterminal application to C.

2. **Add UART Support**: Implement and test the UART peripheral interface in C.

3. **Create a C Library**: Build a reusable library of functions for PCD-68 C development.

4. **Documentation**: Create comprehensive documentation for C programming on the PCD-68 platform.