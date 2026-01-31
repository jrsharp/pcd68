# PowerPC Cross-Compilation Toolchain Setup for OpenBSD

Since OpenBSD's base clang doesn't include PowerPC target, you have several options:

## Option 1: Build GCC Cross-Compiler (Recommended)

This gives you a proper PowerPC toolchain:

```bash
# Install build dependencies
doas pkg_add gmake gmp mpfr libmpc texinfo

# Create build directory
mkdir ~/ppc-toolchain
cd ~/ppc-toolchain

# Download sources
ftp https://ftp.gnu.org/gnu/binutils/binutils-2.41.tar.xz
ftp https://ftp.gnu.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.xz

# Extract
tar xf binutils-2.41.tar.xz
tar xf gcc-13.2.0.tar.xz

# Build binutils
mkdir build-binutils && cd build-binutils
../binutils-2.41/configure \
    --target=powerpc-elf \
    --prefix=$HOME/ppc-toolchain \
    --disable-nls \
    --disable-werror
gmake -j4
gmake install
cd ..

# Add to PATH
export PATH=$HOME/ppc-toolchain/bin:$PATH

# Build GCC
mkdir build-gcc && cd build-gcc
../gcc-13.2.0/configure \
    --target=powerpc-elf \
    --prefix=$HOME/ppc-toolchain \
    --disable-nls \
    --enable-languages=c,c++ \
    --without-headers \
    --with-gnu-as \
    --with-gnu-ld
gmake all-gcc -j4
gmake install-gcc
cd ..
```

After this, you'll have `powerpc-elf-gcc` and `powerpc-elf-g++`.

## Option 2: Use Pre-built Toolchain in Docker/Linux VM

Create a Linux container or VM with PowerPC cross-tools:

```bash
# In a Debian/Ubuntu container:
apt-get update
apt-get install gcc-powerpc-linux-gnu g++-powerpc-linux-gnu

# Build PCD68
make -f Makefile.of
```

## Option 3: Use Online Compiler Service

Godbolt Compiler Explorer supports PowerPC:
https://godbolt.org/

## Option 4: Build on Another Machine

If you have access to:
- Linux machine with powerpc cross-compiler
- macOS with MacPorts/Homebrew powerpc toolchain
- Another OpenBSD machine with custom packages

Build there and transfer the binary.

## Option 5: NetBSD's Cross-Build Tools

NetBSD has excellent cross-compilation support:

```bash
# Get NetBSD source
ftp https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.0/source/sets/src.tgz
tar xf src.tgz

# Build cross-compiler
cd src
./build.sh -U -m macppc tools

# This creates cross-compiler in obj/tooldir.*/bin/
```

## Quick Solution: Remote Build

For immediate results, you could:

1. Set up SSH to a Linux VPS (even a free tier AWS/Oracle Cloud)
2. Install PowerPC cross-compiler there
3. Build PCD68 remotely
4. Transfer binary back

Example using a Debian VPS:
```bash
# On remote machine
sudo apt-get install gcc-powerpc-linux-gnu g++-powerpc-linux-gnu make git
git clone your-repo
cd pcd68-cpp
make -f Makefile.of

# Transfer back
scp remote:~/pcd68-cpp/pcd68.elf .
```

## For Your Immediate Needs

Since you want to test quickly, I recommend:

1. **Fastest**: Use a Linux VM/container with pre-built cross-compiler
2. **Most educational**: Build the GCC cross-compiler (takes ~30 min)
3. **Most convenient**: Set up a small Linux VPS for builds

The binary format (ELF) will work fine with Open Firmware regardless of where it's built.