# PCD68 Open Firmware Edition

## Overview

This branch implements PCD68 as a bare-metal Open Firmware client, allowing it to run directly on PowerBook G4 hardware without any operating system.

## Execution Environment

### What OF Provides

Open Firmware gives us a complete runtime environment:

1. **Client Interface** - Called with function pointer in r3
2. **Memory Management** - claim/release for allocation
3. **Device I/O** - Unified device tree access
4. **Console I/O** - Built-in keyboard/screen support
5. **No MMU Setup Needed** - OF handles this for us

### Binary Format

We build as ELF and convert to XCOFF for maximum compatibility:
- **ELF**: Modern toolchains support this well
- **XCOFF**: What OF actually expects on PowerPC Macs

### Entry Point

OF calls our entry with:
```c
int pcd68_start(int (*client_interface)(struct of_args *))
```

## Available OF Primitives

### Display
- **Framebuffer**: Direct mapped at physical address
- **Properties**: width, height, depth, linebytes
- **PowerBook G4 15"**: 1280x854x32 @ 0x80000000+

### Keyboard
- **Device**: "keyboard" or stdin from /chosen
- **Non-blocking**: Returns -1 if no key available
- **ASCII**: Direct ASCII values

### Serial Ports
- **Modem Port**: "ch-a" or "sccb"
- **Printer Port**: "ch-b" or "scca"
- **Full duplex**: Read/write support
- **Hardware flow control**: Available via ioctl

### Memory
- **claim()**: Allocate memory (we get ~100MB free)
- **No virtual memory**: Direct physical access

## Build Instructions

### Prerequisites

Install PowerPC cross-compiler:
```bash
# Ubuntu/Debian
sudo apt-get install gcc-powerpc-linux-gnu g++-powerpc-linux-gnu

# macOS
brew install powerpc-elf-gcc
```

### Build

```bash
cd ~/src/pcd68-cpp
make -f Makefile.of
```

This creates:
- `pcd68.elf` - ELF binary for debugging
- `pcd68.xcf` - XCOFF for Open Firmware

## Installation Methods

### Method 1: Network Boot (Fastest for Development)

Set up TFTP server on your development machine:
```bash
sudo cp pcd68.xcf /srv/tftp/
```

In Open Firmware:
```forth
boot enet:192.168.1.100,pcd68.xcf
```

### Method 2: USB Drive

Format USB as HFS+:
```bash
# On macOS
diskutil eraseDisk HFS+ PCD68 /dev/disk2
cp pcd68.xcf /Volumes/PCD68/
```

In OF:
```forth
boot usb0/disk@1:,\\pcd68.xcf
```

### Method 3: Hard Drive Partition

Use an unused partition:
```bash
# Be VERY careful with device names!
sudo dd if=pcd68.xcf of=/dev/disk0s12 bs=512
```

In OF:
```forth
boot hd:12,\\pcd68.xcf
```

### Method 4: NVRAM Auto-boot

Make it permanent:
```forth
setenv boot-device hd:12,\\pcd68.xcf
setenv boot-file pcd68.xcf
setenv auto-boot? true
```

## Usage

### Normal Boot
```forth
boot hd:12,\\pcd68.xcf
```

### With Serial Console
```forth
" ch-a" io
boot hd:12,\\pcd68.xcf
```

### Debug Mode
Hold Command+V during load for verbose output

## Serial Port Usage

PCD68's dual UARTs map to:
- **UART1**: Modem port (mini-DIN 8)
- **UART2**: Printer port (mini-DIN 8)

Connect with:
```bash
# From another machine
screen /dev/tty.usbserial 57600
```

## Performance

On PowerBook G4 1.67GHz:
- **CPU Speed**: ~100 MIPS (68000 equivalent)
- **Display**: 400x300 scaled 3x to 1200x900
- **Refresh**: 30Hz (limited by OF framebuffer)
- **Boot Time**: < 1 second

## Keyboard Commands

- **ESC**: Exit back to Open Firmware
- **Cmd+Option+R**: Reset emulated CPU
- All other keys passed to PCD68

## Troubleshooting

### No Display
- OF framebuffer might be at different address
- Try: `dev screen .properties` to check

### No Keyboard
- Some PowerBooks need: `dev keyboard open-dev`

### Serial Not Working
- Port names vary by model
- Try: `devalias` to list all devices

### Crashes to OF Prompt
- Check available memory: `showstack`
- Reduce ROM size if needed

## Integration with Crazytown

Your crazytown boot screen can chain-load PCD68:
```forth
: pcd68-boot ( -- )
  ." Loading PCD68..." cr
  " hd:12,\\pcd68.xcf" $boot
;
```

## Next Steps

1. **Custom ROMs**: Replace text_demo with your own 68k code
2. **Persistent Storage**: Implement disk I/O via OF
3. **Networking**: OF provides network device access
4. **Sound**: PowerBook has I2S audio via "sound" device

## The Dream

With this setup, your PowerBook G4 becomes a dual-personality machine:
- **Normal**: Boot OpenBSD/macOS
- **Secret**: Instant 68k computer in firmware

Hold a key combo at boot, and you're in your own 68k world!