---
title: Bare-metal Macintosh Programming
order: 1
type: content
---

# Bare-metal Macintosh Programming

I've been tinkering with 68000 assembly off and on (mostly off) over the past decade and one of my favorite projects is my progressive attempts at bare-metal (non-Toolbox) programming my Macintosh Plus.

## Part 1: First Steps

The original compact Macintoshes (128k, 512k, and Plus) have long been a subject of my collection and study, but after acquiring a Canon Cat, I began to see the Mac in a slightly new light. The original Macintosh may be a truly unique blend of hardware and software engineering, but what if you looked at the Mac only for its hardware?

If you know the Mac, you know that it was innovative in large part because of its ROM. The Toolbox functions of the ROM really made the Mac what it was. As a result, The MacOS (System) software is inextricably linked to the ROM code, and the two work together in a clever balance of pointers and patched code.

But what if you threw out the ROM and its Toolbox? The Mac might start to look not too different from other 68000-based personal computers of its time. What would you do if someone handed you a Macintosh with no available software?

### A proof-of-concept demo

In my search for information on the Macintosh boot process, I ran across a method for booting arbitrary code on a 68k Macintosh — that is, without Mac OS. This was the starting point I needed to begin exploring my thoughts on alternative software/firmware for the Mac.

I decided my first step was to develop the simplest demo I could think of that would show off some of the Mac's hardware while compact enough to fit into the boot sector (first 1K) of a floppy. So I set out to build a simple bare-metal Macintosh demo written in 68k assembly that displays my own smiling face on the machine's 1-bit framebuffer.

I targeted the Macintosh Plus for the extra RAM and because Mini vMac emulates it by default, but the code should run fine on the 128k/512k as well.

## Part 2: Building Blocks for an OS

After getting a functional demo up and running, I began thinking of more useful solutions. If I could implement a basic terminal, I could use it to port a host of existing software and use it to build a whole new operating environment:

- Port Frotz z-code interpreter for Zork/Infocom games
- Port pforth to create a Forth operating environment
- eLua?
- FreeRTOS demo/shell
- uCLinux?

### Breaking out of the boot block

In order to do anything useful, I needed to use the ROM routines (floppy driver) to read the rest of my code from disk into memory. This saves us the trouble of subsequent disk reads at the expense of initial load time.

### A Condensed Font

After some searching, I came across Christian Neukirchen's 5x13 font. This font seemed like the right mix of efficient and readable. It yields an effective terminal size of 102x26, more than adequate for my needs.

I used bdfe to convert the .bdf font data into a C header file suitable for use with my gcc project.

### Next Steps

In future work, I plan to:
- Improve GCC linker scripts and relocatable code
- Mix C and assembly (calling conventions!)
- Add a Newlib port/implementation
- Create a keyboard input routine

The project repository is available at: https://github.com/jrsharp/HappyJon