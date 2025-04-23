#include <stdint.h>

void write_byte(unsigned address, uint8_t b) {
    char* IM=reinterpret_cast <char*>(address);
    *IM = b;
}

int main(int argc, char** argv) {
    unsigned int ScrnBase = 0x810000;
    unsigned int ScrnBaseMirror = 0x430000;
    unsigned int TDABase = 0x410000;
    write_byte(TDABase, 0x02);
    return 0;
}
