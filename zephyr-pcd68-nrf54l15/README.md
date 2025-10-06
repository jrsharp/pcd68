# PCD68 for nRF54L15-DK

PCD68 68000 emulator ported to the nRF54L15-DK with e-paper display support.

## Hardware Configuration

- **MCU**: nRF54L15 (128MHz Cortex-M33)
- **Memory**: 256KB RAM, 1.5MB RRAM
- **Display**: 400x300 e-paper display via SPI
- **Flash Layout**: 1.4MB application space, 64KB storage

## E-Paper Display Connections

Connect your 400x300 e-paper display to the nRF54L15-DK:

- **SCK**: P1.05 (SPI SCK)
- **MOSI**: P1.04 (SPI MOSI)
- **CS**: P1.08 (Chip Select)
- **DC**: P1.06 (Data/Command)
- **RST**: P1.07 (Reset)
- **BUSY**: P1.09 (Busy signal)

## Build Instructions

1. Set up nRF Connect SDK environment:
```bash
west init -m https://github.com/nrfconnect/sdk-nrf --mr v2.8.0
west update
```

2. Build the project:
```bash
cd zephyr-pcd68-nrf54l15
west build -b nrf54l15dk/nrf54l15/cpuapp
```

3. Flash to device:
```bash
west flash
```

## Features

- **Full 68000 Emulation**: Moira CPU core with 4MB RAM
- **E-Paper Optimized**: Partial refresh support, power-efficient updates
- **Retro Terminal**: 80x25 and 50x25 text modes via TDA
- **Keyboard Input**: USB HID-style keyboard controller
- **Serial Communication**: UART for external connections
- **ROM Storage**: 64KB partition for storing ROM images

## Memory Layout

```
0x000000 - 0x00FFFF   ROM (64KB)
0x010000 - 0x40FFFF   RAM (4MB)
0x410000              TDA (Text Display Adapter)
0x420000              KCTL (Keyboard Controller)
0x450000              UART
0x810000              Screen Framebuffer (400x300)
```

## Flash Partitions

- **Boot**: 64KB MCUboot bootloader
- **Application**: 1400KB PCD68 emulator
- **Storage**: 64KB for ROM files and settings

## Configuration Options

Key Kconfig options in `prj.conf`:

- `CONFIG_PCD68_EPAPER_DISPLAY=y` - Enable e-paper display
- `CONFIG_PCD68_ROM_SIZE_KB=64` - ROM size
- `CONFIG_PCD68_RAM_SIZE_MB=4` - RAM size
- `CONFIG_PCD68_TARGET_CPU_MHZ=128` - Target frequency

## Power Management

The e-paper display configuration includes:
- 3-second refresh rate for power savings
- Partial refresh for small changes
- Automatic dirty region detection
- Full refresh for large updates

## Development Notes

This port focuses on e-paper displays and single-core architecture, making it simpler than the nRF54H20 multi-core version while providing more application flash space (1.4MB vs 700KB).

The 400x300 resolution perfectly matches PCD68's native framebuffer, eliminating scaling overhead.