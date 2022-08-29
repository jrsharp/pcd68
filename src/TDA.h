#pragma once

#include "CPU.h"
#include "Peripheral.h"
#include "Screen.h"
#include <cstring>
#include <stdint.h>

extern u8 systemRam[];

class TDA : public Peripheral {

public:
    /**
     * Video/Text mode
     */
    enum Mode : u8 {
        COL50 = 0x01,
        COL80 = 0x02,
    };

    /**
     * Struct for TDA's registers
     */
    struct Registers {
        Mode mode;
    };

    static constexpr u32 BASE_ADDR = 0x410000;

    /**
     * Constructor
     *
     * @param cpu CPU instance
     * @param screen Screen instance
     * @param start base address
     * @param size size of memory
     */
    TDA(CPU* cpu, Screen* screen, uint32_t start, uint32_t size);

    void update();

    void reset() override;
    u8 read8(u32 addr) override;
    u16 read16(u32 addr) override;
    void write8(u32 addr, u8 val) override;
    void write16(u32 addr, u16 val) override;

    unsigned char textMapMem[50 * 37];

private:
    CPU* cpu;
    Screen* screen;
    Registers registers;
    bool refreshFlag;
    int five_by_thirteen[(16 * (128 - 32))] = {
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //    32 ' '
        0x00, 0x00, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, //    33 '!'
        0x00, 0x00, 0x50, 0x50, 0x50, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //    34 '"'
        0x00, 0x00, 0x28, 0x28, 0x78, 0x50, 0x50, 0xF0, 0xA0, 0xA0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //    35 '#'
        0x00, 0x00, 0x20, 0x78, 0xA0, 0xA0, 0x70, 0x28, 0x28, 0xF0, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, //    36 '$'
        0x00, 0x00, 0x00, 0xD0, 0xD0, 0x20, 0x20, 0x40, 0x40, 0xB0, 0xB0, 0x00, 0x00, 0x00, 0x00, 0x00, //    37 '%'
        0x00, 0x00, 0x00, 0x40, 0xA0, 0xA0, 0x40, 0xA0, 0xA0, 0xA0, 0x50, 0x00, 0x00, 0x00, 0x00, 0x00, //    38 '&'
        0x00, 0x00, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //    39 '''
        0x00, 0x20, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x20, 0x00, 0x00, 0x00, 0x00, //    40 '('
        0x00, 0x40, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x40, 0x00, 0x00, 0x00, 0x00, //    41 ')'
        0x00, 0x00, 0x20, 0xA8, 0x70, 0xA8, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //    42 '*'
        0x00, 0x00, 0x00, 0x00, 0x20, 0x20, 0xF8, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //    43 '+'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x20, 0x40, 0x00, 0x00, 0x00, 0x00, //    44 ','
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //    45 '-'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x60, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    46 '.'
        0x00, 0x00, 0x00, 0x10, 0x10, 0x20, 0x20, 0x40, 0x40, 0x80, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, //    47 '/'
        0x00, 0x00, 0x60, 0x90, 0x90, 0xB0, 0xD0, 0x90, 0x90, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    48 '0'
        0x00, 0x00, 0x20, 0x60, 0xA0, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, //    49 '1'
        0x00, 0x00, 0x60, 0x90, 0x90, 0x10, 0x10, 0x20, 0x40, 0x80, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, //    50 '2'
        0x00, 0x00, 0x60, 0x90, 0x10, 0x10, 0x60, 0x10, 0x10, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    51 '3'
        0x00, 0x00, 0x90, 0x90, 0x90, 0x90, 0x70, 0x10, 0x10, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, //    52 '4'
        0x00, 0x00, 0xF0, 0x80, 0x80, 0xE0, 0x90, 0x10, 0x10, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    53 '5'
        0x00, 0x00, 0x60, 0x90, 0x80, 0x80, 0xE0, 0x90, 0x90, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    54 '6'
        0x00, 0x00, 0xF0, 0x10, 0x10, 0x20, 0x20, 0x40, 0x40, 0x80, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, //    55 '7'
        0x00, 0x00, 0x60, 0x90, 0x90, 0x90, 0x60, 0x90, 0x90, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    56 '8'
        0x00, 0x00, 0x60, 0x90, 0x90, 0x90, 0x70, 0x10, 0x10, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    57 '9'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x60, 0x60, 0x00, 0x00, 0x60, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    58 ':'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x60, 0x60, 0x00, 0x00, 0x20, 0x20, 0x40, 0x00, 0x00, 0x00, 0x00, //    59 ';'
        0x00, 0x00, 0x00, 0x00, 0x10, 0x20, 0x40, 0x80, 0x40, 0x20, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, //    60 '<'
        0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x00, 0x00, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //    61 '='
        0x00, 0x00, 0x00, 0x00, 0x80, 0x40, 0x20, 0x10, 0x20, 0x40, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, //    62 '>'
        0x00, 0x00, 0x60, 0x90, 0x90, 0x10, 0x20, 0x40, 0x40, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, //    63 '?'
        0x00, 0x00, 0x60, 0x90, 0x90, 0xB0, 0xB0, 0xB0, 0xB0, 0x80, 0x70, 0x00, 0x00, 0x00, 0x00, 0x00, //    64 '@'
        0x00, 0x00, 0x60, 0x90, 0x90, 0x90, 0x90, 0xF0, 0x90, 0x90, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //    65 'A'
        0x00, 0x00, 0xE0, 0x90, 0x90, 0x90, 0xE0, 0x90, 0x90, 0x90, 0xE0, 0x00, 0x00, 0x00, 0x00, 0x00, //    66 'B'
        0x00, 0x00, 0x70, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x70, 0x00, 0x00, 0x00, 0x00, 0x00, //    67 'C'
        0x00, 0x00, 0xE0, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0xE0, 0x00, 0x00, 0x00, 0x00, 0x00, //    68 'D'
        0x00, 0x00, 0xF0, 0x80, 0x80, 0x80, 0xF0, 0x80, 0x80, 0x80, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, //    69 'E'
        0x00, 0x00, 0xF0, 0x80, 0x80, 0x80, 0xF0, 0x80, 0x80, 0x80, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, //    70 'F'
        0x00, 0x00, 0x60, 0x90, 0x80, 0x80, 0x80, 0xB0, 0x90, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    71 'G'
        0x00, 0x00, 0x90, 0x90, 0x90, 0x90, 0xF0, 0x90, 0x90, 0x90, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //    72 'H'
        0x00, 0x00, 0x70, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x70, 0x00, 0x00, 0x00, 0x00, 0x00, //    73 'I'
        0x00, 0x00, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    74 'J'
        0x00, 0x00, 0x90, 0x90, 0x90, 0xA0, 0xC0, 0xA0, 0x90, 0x90, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //    75 'K'
        0x00, 0x00, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, //    76 'L'
        0x00, 0x00, 0x90, 0x90, 0xF0, 0xB0, 0x90, 0x90, 0x90, 0x90, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //    77 'M'
        0x00, 0x00, 0x90, 0x90, 0xD0, 0xD0, 0xB0, 0xB0, 0x90, 0x90, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //    78 'N'
        0x00, 0x00, 0x60, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    79 'O'
        0x00, 0x00, 0xE0, 0x90, 0x90, 0x90, 0xE0, 0x80, 0x80, 0x80, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, //    80 'P'
        0x00, 0x00, 0x60, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0xB0, 0x70, 0x10, 0x00, 0x00, 0x00, 0x00, //    81 'Q'
        0x00, 0x00, 0xE0, 0x90, 0x90, 0x90, 0xE0, 0xA0, 0x90, 0x90, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //    82 'R'
        0x00, 0x00, 0x60, 0x90, 0x80, 0x80, 0x60, 0x10, 0x10, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    83 'S'
        0x00, 0x00, 0xF8, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, //    84 'T'
        0x00, 0x00, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    85 'U'
        0x00, 0x00, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x60, 0x60, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    86 'V'
        0x00, 0x00, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0xB0, 0xF0, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //    87 'W'
        0x00, 0x00, 0x90, 0x90, 0x90, 0x60, 0x60, 0x60, 0x90, 0x90, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //    88 'X'
        0x00, 0x00, 0x88, 0x88, 0x50, 0x50, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, //    89 'Y'
        0x00, 0x00, 0xF0, 0x10, 0x10, 0x20, 0x40, 0x40, 0x80, 0x80, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, //    90 'Z'
        0x00, 0x70, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x70, 0x00, 0x00, 0x00, 0x00, //    91 '['
        0x00, 0x00, 0x00, 0x80, 0x80, 0x40, 0x40, 0x20, 0x20, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, //    92 '\'
        0x00, 0xE0, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0xE0, 0x00, 0x00, 0x00, 0x00, //    93 ']'
        0x00, 0x00, 0x60, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //    94 '^'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x00, 0x00, 0x00, 0x00, //    95 '_'
        0x00, 0x40, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //    96 '`'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x60, 0x90, 0x70, 0x90, 0xB0, 0x50, 0x00, 0x00, 0x00, 0x00, 0x00, //    97 'a'
        0x00, 0x00, 0x80, 0x80, 0x80, 0xA0, 0xD0, 0x90, 0x90, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    98 'b'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x60, 0x90, 0x80, 0x80, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //    99 'c'
        0x00, 0x00, 0x10, 0x10, 0x10, 0x70, 0x90, 0x90, 0x90, 0x90, 0x70, 0x00, 0x00, 0x00, 0x00, 0x00, //   100 'd'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x60, 0x90, 0xF0, 0x80, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //   101 'e'
        0x00, 0x00, 0x30, 0x40, 0x40, 0x40, 0xF0, 0x40, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, //   102 'f'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x60, 0x90, 0x90, 0x90, 0x70, 0x10, 0x90, 0x60, 0x00, 0x00, 0x00, //   103 'g'
        0x00, 0x00, 0x80, 0x80, 0x80, 0xA0, 0xD0, 0x90, 0x90, 0x90, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //   104 'h'
        0x00, 0x00, 0x00, 0x20, 0x00, 0x60, 0x20, 0x20, 0x20, 0x20, 0x70, 0x00, 0x00, 0x00, 0x00, 0x00, //   105 'i'
        0x00, 0x00, 0x00, 0x20, 0x00, 0x20, 0x20, 0x20, 0x20, 0x20, 0xA0, 0xA0, 0x40, 0x00, 0x00, 0x00, //   106 'j'
        0x00, 0x00, 0x80, 0x80, 0x80, 0x90, 0xA0, 0xC0, 0xA0, 0x90, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //   107 'k'
        0x00, 0x00, 0x60, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x70, 0x00, 0x00, 0x00, 0x00, 0x00, //   108 'l'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0xF0, 0xB0, 0x90, 0x90, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //   109 'm'
        0x00, 0x00, 0x00, 0x00, 0x00, 0xA0, 0xD0, 0x90, 0x90, 0x90, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //   110 'n'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x60, 0x90, 0x90, 0x90, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //   111 'o'
        0x00, 0x00, 0x00, 0x00, 0x00, 0xE0, 0x90, 0x90, 0x90, 0xE0, 0x80, 0x80, 0x80, 0x00, 0x00, 0x00, //   112 'p'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x70, 0x90, 0x90, 0x90, 0x70, 0x10, 0x10, 0x10, 0x00, 0x00, 0x00, //   113 'q'
        0x00, 0x00, 0x00, 0x00, 0x00, 0xB0, 0xC0, 0x80, 0x80, 0x80, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, //   114 'r'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x60, 0x90, 0xC0, 0x30, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //   115 's'
        0x00, 0x00, 0x00, 0x40, 0x40, 0xF0, 0x40, 0x40, 0x40, 0x40, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, //   116 't'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0x90, 0x90, 0x90, 0x90, 0x70, 0x00, 0x00, 0x00, 0x00, 0x00, //   117 'u'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0x90, 0x90, 0x90, 0x60, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, //   118 'v'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0x90, 0x90, 0xB0, 0xF0, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //   119 'w'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0x90, 0x60, 0x60, 0x90, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, //   120 'x'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0x90, 0x90, 0x90, 0x90, 0x70, 0x10, 0x60, 0x00, 0x00, 0x00, //   121 'y'
        0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x10, 0x20, 0x40, 0x80, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, //   122 'z'
        0x00, 0x10, 0x20, 0x20, 0x20, 0x20, 0xC0, 0x20, 0x20, 0x20, 0x20, 0x10, 0x00, 0x00, 0x00, 0x00, //   123 '{'
        0x00, 0x00, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, //   124 '|'
        0x00, 0x80, 0x40, 0x40, 0x40, 0x40, 0x30, 0x40, 0x40, 0x40, 0x40, 0x80, 0x00, 0x00, 0x00, 0x00, //   125 '}'
        0x00, 0x00, 0x48, 0xA8, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //   126 '~'
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF  //   127 'block'
    };

    char font8x8_basic[128][8] = {
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0000 (nul)
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0001
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0002
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0003
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0004
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0005
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0006
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0007
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0008
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0009
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+000A
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+000B
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+000C
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+000D
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+000E
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+000F
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0010
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0011
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0012
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0013
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0014
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0015
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0016
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0017
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0018
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0019
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+001A
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+001B
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+001C
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+001D
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+001E
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+001F
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0020 (space)
        { 0x18, 0x3C, 0x3C, 0x18, 0x18, 0x00, 0x18, 0x00 }, // U+0021 (!)
        { 0x36, 0x36, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0022 (")
        { 0x36, 0x36, 0x7F, 0x36, 0x7F, 0x36, 0x36, 0x00 }, // U+0023 (#)
        { 0x0C, 0x3E, 0x03, 0x1E, 0x30, 0x1F, 0x0C, 0x00 }, // U+0024 ($)
        { 0x00, 0x63, 0x33, 0x18, 0x0C, 0x66, 0x63, 0x00 }, // U+0025 (%)
        { 0x1C, 0x36, 0x1C, 0x6E, 0x3B, 0x33, 0x6E, 0x00 }, // U+0026 (&)
        { 0x06, 0x06, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0027 (')
        { 0x18, 0x0C, 0x06, 0x06, 0x06, 0x0C, 0x18, 0x00 }, // U+0028 (()
        { 0x06, 0x0C, 0x18, 0x18, 0x18, 0x0C, 0x06, 0x00 }, // U+0029 ())
        { 0x00, 0x66, 0x3C, 0xFF, 0x3C, 0x66, 0x00, 0x00 }, // U+002A (*)
        { 0x00, 0x0C, 0x0C, 0x3F, 0x0C, 0x0C, 0x00, 0x00 }, // U+002B (+)
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x0C, 0x0C, 0x06 }, // U+002C (,)
        { 0x00, 0x00, 0x00, 0x3F, 0x00, 0x00, 0x00, 0x00 }, // U+002D (-)
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x0C, 0x0C, 0x00 }, // U+002E (.)
        { 0x60, 0x30, 0x18, 0x0C, 0x06, 0x03, 0x01, 0x00 }, // U+002F (/)
        { 0x3E, 0x63, 0x73, 0x7B, 0x6F, 0x67, 0x3E, 0x00 }, // U+0030 (0)
        { 0x0C, 0x0E, 0x0C, 0x0C, 0x0C, 0x0C, 0x3F, 0x00 }, // U+0031 (1)
        { 0x1E, 0x33, 0x30, 0x1C, 0x06, 0x33, 0x3F, 0x00 }, // U+0032 (2)
        { 0x1E, 0x33, 0x30, 0x1C, 0x30, 0x33, 0x1E, 0x00 }, // U+0033 (3)
        { 0x38, 0x3C, 0x36, 0x33, 0x7F, 0x30, 0x78, 0x00 }, // U+0034 (4)
        { 0x3F, 0x03, 0x1F, 0x30, 0x30, 0x33, 0x1E, 0x00 }, // U+0035 (5)
        { 0x1C, 0x06, 0x03, 0x1F, 0x33, 0x33, 0x1E, 0x00 }, // U+0036 (6)
        { 0x3F, 0x33, 0x30, 0x18, 0x0C, 0x0C, 0x0C, 0x00 }, // U+0037 (7)
        { 0x1E, 0x33, 0x33, 0x1E, 0x33, 0x33, 0x1E, 0x00 }, // U+0038 (8)
        { 0x1E, 0x33, 0x33, 0x3E, 0x30, 0x18, 0x0E, 0x00 }, // U+0039 (9)
        { 0x00, 0x0C, 0x0C, 0x00, 0x00, 0x0C, 0x0C, 0x00 }, // U+003A (:)
        { 0x00, 0x0C, 0x0C, 0x00, 0x00, 0x0C, 0x0C, 0x06 }, // U+003B (;)
        { 0x18, 0x0C, 0x06, 0x03, 0x06, 0x0C, 0x18, 0x00 }, // U+003C (<)
        { 0x00, 0x00, 0x3F, 0x00, 0x00, 0x3F, 0x00, 0x00 }, // U+003D (=)
        { 0x06, 0x0C, 0x18, 0x30, 0x18, 0x0C, 0x06, 0x00 }, // U+003E (>)
        { 0x1E, 0x33, 0x30, 0x18, 0x0C, 0x00, 0x0C, 0x00 }, // U+003F (?)
        { 0x3E, 0x63, 0x7B, 0x7B, 0x7B, 0x03, 0x1E, 0x00 }, // U+0040 (@)
        { 0x0C, 0x1E, 0x33, 0x33, 0x3F, 0x33, 0x33, 0x00 }, // U+0041 (A)
        { 0x3F, 0x66, 0x66, 0x3E, 0x66, 0x66, 0x3F, 0x00 }, // U+0042 (B)
        { 0x3C, 0x66, 0x03, 0x03, 0x03, 0x66, 0x3C, 0x00 }, // U+0043 (C)
        { 0x1F, 0x36, 0x66, 0x66, 0x66, 0x36, 0x1F, 0x00 }, // U+0044 (D)
        { 0x7F, 0x46, 0x16, 0x1E, 0x16, 0x46, 0x7F, 0x00 }, // U+0045 (E)
        { 0x7F, 0x46, 0x16, 0x1E, 0x16, 0x06, 0x0F, 0x00 }, // U+0046 (F)
        { 0x3C, 0x66, 0x03, 0x03, 0x73, 0x66, 0x7C, 0x00 }, // U+0047 (G)
        { 0x33, 0x33, 0x33, 0x3F, 0x33, 0x33, 0x33, 0x00 }, // U+0048 (H)
        { 0x1E, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x1E, 0x00 }, // U+0049 (I)
        { 0x78, 0x30, 0x30, 0x30, 0x33, 0x33, 0x1E, 0x00 }, // U+004A (J)
        { 0x67, 0x66, 0x36, 0x1E, 0x36, 0x66, 0x67, 0x00 }, // U+004B (K)
        { 0x0F, 0x06, 0x06, 0x06, 0x46, 0x66, 0x7F, 0x00 }, // U+004C (L)
        { 0x63, 0x77, 0x7F, 0x7F, 0x6B, 0x63, 0x63, 0x00 }, // U+004D (M)
        { 0x63, 0x67, 0x6F, 0x7B, 0x73, 0x63, 0x63, 0x00 }, // U+004E (N)
        { 0x1C, 0x36, 0x63, 0x63, 0x63, 0x36, 0x1C, 0x00 }, // U+004F (O)
        { 0x3F, 0x66, 0x66, 0x3E, 0x06, 0x06, 0x0F, 0x00 }, // U+0050 (P)
        { 0x1E, 0x33, 0x33, 0x33, 0x3B, 0x1E, 0x38, 0x00 }, // U+0051 (Q)
        { 0x3F, 0x66, 0x66, 0x3E, 0x36, 0x66, 0x67, 0x00 }, // U+0052 (R)
        { 0x1E, 0x33, 0x07, 0x0E, 0x38, 0x33, 0x1E, 0x00 }, // U+0053 (S)
        { 0x3F, 0x2D, 0x0C, 0x0C, 0x0C, 0x0C, 0x1E, 0x00 }, // U+0054 (T)
        { 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x3F, 0x00 }, // U+0055 (U)
        { 0x33, 0x33, 0x33, 0x33, 0x33, 0x1E, 0x0C, 0x00 }, // U+0056 (V)
        { 0x63, 0x63, 0x63, 0x6B, 0x7F, 0x77, 0x63, 0x00 }, // U+0057 (W)
        { 0x63, 0x63, 0x36, 0x1C, 0x1C, 0x36, 0x63, 0x00 }, // U+0058 (X)
        { 0x33, 0x33, 0x33, 0x1E, 0x0C, 0x0C, 0x1E, 0x00 }, // U+0059 (Y)
        { 0x7F, 0x63, 0x31, 0x18, 0x4C, 0x66, 0x7F, 0x00 }, // U+005A (Z)
        { 0x1E, 0x06, 0x06, 0x06, 0x06, 0x06, 0x1E, 0x00 }, // U+005B ([)
        { 0x03, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x40, 0x00 }, // U+005C (\)
        { 0x1E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x1E, 0x00 }, // U+005D (])
        { 0x08, 0x1C, 0x36, 0x63, 0x00, 0x00, 0x00, 0x00 }, // U+005E (^)
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF }, // U+005F (_)
        { 0x0C, 0x0C, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+0060 (`)
        { 0x00, 0x00, 0x1E, 0x30, 0x3E, 0x33, 0x6E, 0x00 }, // U+0061 (a)
        { 0x07, 0x06, 0x06, 0x3E, 0x66, 0x66, 0x3B, 0x00 }, // U+0062 (b)
        { 0x00, 0x00, 0x1E, 0x33, 0x03, 0x33, 0x1E, 0x00 }, // U+0063 (c)
        { 0x38, 0x30, 0x30, 0x3e, 0x33, 0x33, 0x6E, 0x00 }, // U+0064 (d)
        { 0x00, 0x00, 0x1E, 0x33, 0x3f, 0x03, 0x1E, 0x00 }, // U+0065 (e)
        { 0x1C, 0x36, 0x06, 0x0f, 0x06, 0x06, 0x0F, 0x00 }, // U+0066 (f)
        { 0x00, 0x00, 0x6E, 0x33, 0x33, 0x3E, 0x30, 0x1F }, // U+0067 (g)
        { 0x07, 0x06, 0x36, 0x6E, 0x66, 0x66, 0x67, 0x00 }, // U+0068 (h)
        { 0x0C, 0x00, 0x0E, 0x0C, 0x0C, 0x0C, 0x1E, 0x00 }, // U+0069 (i)
        { 0x30, 0x00, 0x30, 0x30, 0x30, 0x33, 0x33, 0x1E }, // U+006A (j)
        { 0x07, 0x06, 0x66, 0x36, 0x1E, 0x36, 0x67, 0x00 }, // U+006B (k)
        { 0x0E, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x1E, 0x00 }, // U+006C (l)
        { 0x00, 0x00, 0x33, 0x7F, 0x7F, 0x6B, 0x63, 0x00 }, // U+006D (m)
        { 0x00, 0x00, 0x1F, 0x33, 0x33, 0x33, 0x33, 0x00 }, // U+006E (n)
        { 0x00, 0x00, 0x1E, 0x33, 0x33, 0x33, 0x1E, 0x00 }, // U+006F (o)
        { 0x00, 0x00, 0x3B, 0x66, 0x66, 0x3E, 0x06, 0x0F }, // U+0070 (p)
        { 0x00, 0x00, 0x6E, 0x33, 0x33, 0x3E, 0x30, 0x78 }, // U+0071 (q)
        { 0x00, 0x00, 0x3B, 0x6E, 0x66, 0x06, 0x0F, 0x00 }, // U+0072 (r)
        { 0x00, 0x00, 0x3E, 0x03, 0x1E, 0x30, 0x1F, 0x00 }, // U+0073 (s)
        { 0x08, 0x0C, 0x3E, 0x0C, 0x0C, 0x2C, 0x18, 0x00 }, // U+0074 (t)
        { 0x00, 0x00, 0x33, 0x33, 0x33, 0x33, 0x6E, 0x00 }, // U+0075 (u)
        { 0x00, 0x00, 0x33, 0x33, 0x33, 0x1E, 0x0C, 0x00 }, // U+0076 (v)
        { 0x00, 0x00, 0x63, 0x6B, 0x7F, 0x7F, 0x36, 0x00 }, // U+0077 (w)
        { 0x00, 0x00, 0x63, 0x36, 0x1C, 0x36, 0x63, 0x00 }, // U+0078 (x)
        { 0x00, 0x00, 0x33, 0x33, 0x33, 0x3E, 0x30, 0x1F }, // U+0079 (y)
        { 0x00, 0x00, 0x3F, 0x19, 0x0C, 0x26, 0x3F, 0x00 }, // U+007A (z)
        { 0x38, 0x0C, 0x0C, 0x07, 0x0C, 0x0C, 0x38, 0x00 }, // U+007B ({)
        { 0x18, 0x18, 0x18, 0x00, 0x18, 0x18, 0x18, 0x00 }, // U+007C (|)
        { 0x07, 0x0C, 0x0C, 0x38, 0x0C, 0x0C, 0x07, 0x00 }, // U+007D (})
        { 0x6E, 0x3B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+007E (~)
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }  // U+007F
    };

    char font8x8_block[32][8] = {
        { 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00 }, // U+2580 (top half)
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF }, // U+2581 (box 1/8)
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF }, // U+2582 (box 2/8)
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF }, // U+2583 (box 3/8)
        { 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF }, // U+2584 (bottom half)
        { 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF }, // U+2585 (box 5/8)
        { 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF }, // U+2586 (box 6/8)
        { 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF }, // U+2587 (box 7/8)
        { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF }, // U+2588 (solid)
        { 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F }, // U+2589 (box 7/8)
        { 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F, 0x3F }, // U+258A (box 6/8)
        { 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F, 0x1F }, // U+258B (box 5/8)
        { 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F }, // U+258C (left half)
        { 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07 }, // U+258D (box 3/8)
        { 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03 }, // U+258E (box 2/8)
        { 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01 }, // U+258F (box 1/8)
        { 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0 }, // U+2590 (right half)
        { 0x55, 0x00, 0xAA, 0x00, 0x55, 0x00, 0xAA, 0x00 }, // U+2591 (25% solid)
        { 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA }, // U+2592 (50% solid)
        { 0xFF, 0xAA, 0xFF, 0x55, 0xFF, 0xAA, 0xFF, 0x55 }, // U+2593 (75% solid)
        { 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // U+2594 (box 1/8)
        { 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 }, // U+2595 (box 1/8)
        { 0x00, 0x00, 0x00, 0x00, 0x0F, 0x0F, 0x0F, 0x0F }, // U+2596 (box bottom left)
        { 0x00, 0x00, 0x00, 0x00, 0xF0, 0xF0, 0xF0, 0xF0 }, // U+2597 (box bottom right)
        { 0x0F, 0x0F, 0x0F, 0x0F, 0x00, 0x00, 0x00, 0x00 }, // U+2598 (box top left)
        { 0x0F, 0x0F, 0x0F, 0x0F, 0xFF, 0xFF, 0xFF, 0xFF }, // U+2599 (boxes left and bottom)
        { 0x0F, 0x0F, 0x0F, 0x0F, 0xF0, 0xF0, 0xF0, 0xF0 }, // U+259A (boxes top-left and bottom right)
        { 0xFF, 0xFF, 0xFF, 0xFF, 0x0F, 0x0F, 0x0F, 0x0F }, // U+259B (boxes top and left)
        { 0xFF, 0xFF, 0xFF, 0xFF, 0xF0, 0xF0, 0xF0, 0xF0 }, // U+259C (boxes top and right)
        { 0xF0, 0xF0, 0xF0, 0xF0, 0x00, 0x00, 0x00, 0x00 }, // U+259D (box top right)
        { 0xF0, 0xF0, 0xF0, 0xF0, 0x0F, 0x0F, 0x0F, 0x0F }, // U+259E (boxes top right and bottom left)
        { 0xF0, 0xF0, 0xF0, 0xF0, 0xFF, 0xFF, 0xFF, 0xFF }, // U+259F (boxes right and bottom)
    };
};
