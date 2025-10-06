# PCD68 Zephyr Port for ESP32-S3

This directory contains a Zephyr RTOS port of the PCD68 emulator targeting ESP32-S3 microcontrollers. It allows running the complete 68000-based PCD68 system on embedded hardware.

## Features

- Complete 68000 CPU emulation via Moira library
- Memory-mapped peripherals (TDA, KCTL, UART)
- Display output via Zephyr framebuffer driver
- Support for LCD displays (ILI9341, SSD1306, etc.)
- Native E-paper display support (Waveshare 4.2", SSD16xx series)
- Automatic scaling from PCD68's 400x300 to any display resolution
- USB HID keyboard input support
- LittleFS storage for ROM files
- Multi-threaded architecture for smooth emulation
- Configurable CPU throttling
- Hardware-accelerated E-Ink display characteristics

## Hardware Requirements

### Minimum Configuration
- ESP32-S3 development board (8MB+ flash, 8MB+ PSRAM recommended)
- SPI display (320x240 or larger recommended)
- USB keyboard (via ESP32-S3 USB host)

### Recommended Hardware

**For LCD Displays:**
- ESP32-S3-DevKitM-1 or ESP32-S3-Box
- ILI9341 320x240 SPI LCD display
- USB-A connector for keyboard
- MicroSD card slot (optional, for additional ROM storage)

**For E-paper Displays:**
- ESP32-S3 with sufficient GPIO pins
- Waveshare 4.2" E-paper display (400x300 native resolution - perfect match!)
- Waveshare 2.9" or 2.13" E-paper displays (with scaling)
- Any SSD1680/SSD1681/SSD16xx compatible E-paper display
- USB keyboard or GPIO matrix keyboard
- External RTC (recommended for E-paper refresh timing)

## Quick Start

### Method 1: As Part of Main Repository

```bash
cd pcd68-cpp/zephyr-pcd68
west init -l .
west update
west build -b esp32s3_devkitm -- -DCONF_FILE=prj.conf
west flash
```

### Method 2: As Standalone West Workspace

```bash
# Create new workspace
mkdir pcd68-zephyr-workspace
cd pcd68-zephyr-workspace

# Initialize with this project as manifest
west init -m https://github.com/yourrepo/pcd68-cpp --mr main -- zephyr-pcd68
west update

# Build and flash
west build zephyr-pcd68 -b esp32s3_devkitm
west flash
```

## Directory Structure

```
zephyr-pcd68/
├── CMakeLists.txt          # Zephyr build configuration
├── Kconfig                 # Configuration options
├── prj.conf               # Project configuration for ESP32-S3
├── west.yml               # West manifest for external dependencies
├── README.md              # This file
└── src/
    ├── main.cpp           # Main application entry point
    ├── Screen_Zephyr.cpp  # Zephyr-specific display implementation
    ├── Screen_Zephyr.h
    ├── KeyboardInput_Zephyr.cpp  # Zephyr keyboard input handler
    ├── KeyboardInput_Zephyr.h
    ├── Storage_Zephyr.cpp # LittleFS storage implementation
    └── Storage_Zephyr.h
```

## Configuration

Key configuration options in `prj.conf`:

```
CONFIG_PCD68_RAM_SIZE_MB=4              # Emulated RAM size
CONFIG_PCD68_ROM_SIZE_KB=64             # ROM size
CONFIG_PCD68_CPU_THROTTLE=y             # Throttle CPU speed
CONFIG_PCD68_TARGET_CPU_MHZ=8           # Target 68000 speed
CONFIG_PCD68_DISPLAY_DRIVER="ILI9341"   # Display driver
CONFIG_PCD68_KEYBOARD_TYPE="USB_HID"    # Input method
CONFIG_PCD68_ENABLE_EINK_EMULATION=n    # E-Ink characteristics
```

Additional configuration via `menuconfig`:

```bash
west build -t menuconfig
```

## Wiring Guide

### ESP32-S3 to ILI9341 LCD Display

| ESP32-S3 Pin | ILI9341 Pin | Function |
|--------------|-------------|----------|
| GPIO18       | CS          | Chip Select |
| GPIO19       | DC          | Data/Command |
| GPIO20       | RST         | Reset |
| GPIO21       | SDA/MOSI    | SPI Data |
| GPIO22       | SCL/SCLK    | SPI Clock |
| 3.3V         | VCC         | Power |
| GND          | GND         | Ground |

### ESP32-S3 to Waveshare 4.2" E-paper Display

| ESP32-S3 Pin | E-paper Pin | Function |
|--------------|-------------|----------|
| GPIO18       | CS          | Chip Select |
| GPIO19       | DC          | Data/Command |
| GPIO20       | RST         | Reset |
| GPIO21       | DIN         | SPI Data (MOSI) |
| GPIO22       | CLK         | SPI Clock |
| GPIO23       | BUSY        | Busy Status |
| 3.3V         | VCC         | Power |
| GND          | GND         | Ground |

**Note:** Waveshare 4.2" displays are 400x300 resolution, matching PCD68's native framebuffer perfectly with no scaling required!

### Generic SSD16xx E-paper Display

| ESP32-S3 Pin | SSD16xx Pin | Function |
|--------------|-------------|----------|
| GPIO18       | CS          | Chip Select |
| GPIO19       | D/C         | Data/Command |
| GPIO20       | RES         | Reset |
| GPIO21       | SDA         | SPI Data |
| GPIO22       | SCL         | SPI Clock |
| GPIO23       | BUSY        | Busy Status |
| 3.3V         | VDD         | Power |
| GND          | VSS         | Ground |

### USB Keyboard Connection

Connect USB keyboard to ESP32-S3's USB host connector (if available) or use GPIO matrix for custom keyboard.

## Loading ROMs

### Built-in ROM
The default configuration includes a basic test ROM. For the full jonsharp.net ROM:

1. Copy `../jonsharp.net/program.bin` to the flash filesystem during build
2. Or upload via serial/WiFi after boot

### Runtime ROM Loading
ROMs are stored in LittleFS at `/pcd68/roms/`. You can:

- Upload via serial console
- Load from SD card (if configured)
- Download via WiFi (if enabled)

## Performance

Typical performance on ESP32-S3 @ 240MHz:
- 68000 emulation: ~8MHz (throttled, configurable)
- Display refresh: 30 FPS
- RAM usage: ~4MB + emulated system RAM
- Flash usage: ~2MB application + ROM storage

## Debugging

Enable debug output by setting:
```
CONFIG_PCD68_DEBUG_LEVEL=2
```

Monitor serial output at 115200 baud:
```bash
west build -t flash && west build -t monitor
```

## Display Driver Architecture

### Framebuffer Integration

PCD68-Zephyr leverages Zephyr's framebuffer driver subsystem, providing compatibility with a wide range of displays:

**Supported Display Types:**
- **LCD Displays**: ILI9341, ST7735, SSD1306 (via display API)
- **E-paper Displays**: SSD1680, SSD1681, SSD1675 (via display API with framebuffer)
- **Framebuffer Devices**: Any display with Zephyr framebuffer support

**Framebuffer Advantages:**
- Unified API across different display types
- Hardware-specific optimizations handled by Zephyr drivers
- Automatic buffer management and refresh scheduling
- Built-in scaling and format conversion
- E-paper partial refresh support

### E-paper Display Features

The PCD68 emulator is particularly well-suited for E-paper displays:

1. **Resolution Match**: Waveshare 4.2" (400x300) matches PCD68's native resolution exactly
2. **Monochrome Content**: PCD68's B&W graphics are perfect for E-paper
3. **Low Refresh Rate**: E-paper's slow refresh matches retro computer characteristics
4. **Power Efficiency**: Ideal for battery-powered retro computing projects
5. **Persistence**: Display remains visible without power (like old CRTs)

**E-paper Specific Optimizations:**
- Configurable refresh strategies (full/partial)
- Intelligent dirty region tracking
- Temperature compensation support
- Power-saving deep sleep between updates
- Ghosting emulation for authentic retro feel

### Framebuffer Configuration

Configure display type in device tree or Kconfig:

```dts
/ {
    chosen {
        zephyr,display = &display;
    };
};

&display {
    status = "okay";
    width = <400>;
    height = <300>;
};
```

Or via Kconfig:
```
CONFIG_DISPLAY=y
CONFIG_FRAMEBUFFER=y
CONFIG_SSD16XX=y                    # For E-paper displays
CONFIG_ILI9341=y                    # For LCD displays
```

## Development

### Adding New Display Drivers

1. Display drivers are handled automatically via Zephyr's display subsystem
2. Add device tree overlay for your specific display
3. Configure framebuffer options in `prj.conf`
4. PCD68 will automatically detect and use any framebuffer-compatible display

### Adding Input Methods

1. Create new input handler class based on `KeyboardInput_Zephyr`
2. Add configuration option in `Kconfig`
3. Integrate in `main.cpp`

## Troubleshooting

### Build Issues
- Ensure Zephyr SDK 0.16+ is installed
- Verify ESP-IDF components are available
- Check that all submodules are updated with `west update`

### Runtime Issues
- Monitor serial output for initialization errors
- Verify display wiring and SPI configuration
- Check flash partition sizes for ROM storage
- Ensure sufficient PSRAM for emulated system memory

### Performance Issues
- Disable E-Ink emulation for faster display
- Reduce CPU throttling or disable entirely
- Lower display refresh rate
- Optimize compiler flags for speed over size

## Integration with Main Repository

This Zephyr port is designed to:
- Share source code with the main PCD68 emulator
- Reference `../src/` for core emulation components
- Provide platform-specific implementations only
- Support both in-tree and external west project usage

The `CMakeLists.txt` uses relative paths to reference core PCD68 sources:
```cmake
target_sources(app PRIVATE
    ${PCD68_ROOT}/src/PCD68_CPU.cpp
    ${PCD68_ROOT}/src/TDA.cpp
    # ... other core sources
)
```

## License

Same as main PCD68 project. See `../LICENSE.md`.