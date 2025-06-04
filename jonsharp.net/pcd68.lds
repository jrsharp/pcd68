/* Linker script for PCD68 ROM */
OUTPUT_FORMAT("elf32-m68k", "elf32-m68k", "elf32-m68k")
OUTPUT_ARCH(m68k)

MEMORY {
    rom (rx) : org = 0x000000, l = 4M
    ram (rw) : org = 0x020000, l = 4M
}

SECTIONS {
    .vectors : {
        *(.vectors)
    } > rom
    
    /* Code and read-only data */
    .text : {
        _text_start = .;
        *(.text)
        *(.text.*)
        . = ALIGN(4);
        _text_end = .;
    } > rom

    /* Read-only data (constants) */
    .rodata : {
        _rodata_start = .;
        *(.rodata)
        *(.rodata.*)
        *(.data.rel.ro)
        *(.data.rel.ro.*)
        . = ALIGN(4);
        _rodata_end = .;
    } > rom

    /* Initialized data in RAM, copied from ROM */
    .data : {
        _data_start = .;
        *(.data)
        *(.data.*)
        . = ALIGN(4);
        _data_end = .;
    } > ram AT > rom
    
    _data_load = LOADADDR(.data);
    
    /* Zero-initialized data */
    .bss (NOLOAD) : {
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
        end = .;
        _end = .;
        __end = .;
    } > ram

    /* Stack grows down from the top of RAM */
    _stack_top = 0x410000;
    
    /* Remove unused sections to avoid warnings */
    /DISCARD/ : {
        *(.eh_frame)
        *(.note.gnu.build-id)
        *(.comment)
    }
}