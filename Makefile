# OpenBSD Makefile for PCD68 CPU Emulator
# Target: OpenBSD 7.7 PowerPC

PROG = pcd68
SRCS = src/main.cpp \
       src/PCD68_CPU.cpp \
       src/TDA.cpp \
       src/KCTL.cpp \
       src/UART.cpp \
       src/Screen.cpp \
       src/Screen_SDL.cpp \
       src/KeyboardInput.cpp \
       src/KeyboardInputSDL.cpp \
       src/Moira/Moira.cpp \
       src/Moira/MoiraDebugger.cpp

# Test program
TEST_PROG = pcd68_test
TEST_SRCS = src/TestPeripheral.cpp \
            src/PCD68_CPU.cpp \
            src/Moira/Moira.cpp \
            src/Moira/MoiraDebugger.cpp

# Compiler and flags
CXX = c++
CXXFLAGS = -std=c++17 -O2 -Wall -Wno-narrowing -DUSE_SDL=1
CPPFLAGS = -I. -Isrc -Isrc/Moira -I/usr/local/include

# SDL2 configuration
.if exists(/usr/local/include/SDL2)
CPPFLAGS += -I/usr/local/include/SDL2
.endif

# Libraries
LDFLAGS = -L/usr/local/lib -O3 -flto
LDADD = -lSDL2 -lstdc++ -lm -lpthread

# Object files
OBJS = ${SRCS:.cpp=.o}
TEST_OBJS = ${TEST_SRCS:.cpp=.o}

# Default target
all: ${PROG}

# Main program
${PROG}: ${OBJS}
	${CXX} ${LDFLAGS} -o ${PROG} ${OBJS} ${LDADD}

# Test program (requires gtest)
test: ${TEST_PROG}
	./${TEST_PROG}

${TEST_PROG}: ${TEST_OBJS}
	${CXX} ${LDFLAGS} -o ${TEST_PROG} ${TEST_OBJS} ${LDADD} -lgtest

# Clean up
clean:
	rm -f ${OBJS} ${TEST_OBJS} ${PROG} ${TEST_PROG}

# Install
install: ${PROG}
	install -c -s -m 755 ${PROG} ${DESTDIR}/usr/local/bin/

# Generate compile_commands.json for development
compile_commands.json:
	@echo '[' > compile_commands.json
	@for src in ${SRCS}; do \
		echo '  {' >> compile_commands.json; \
		echo '    "directory": "'`pwd`'",' >> compile_commands.json; \
		echo '    "command": "${CXX} ${CXXFLAGS} ${CPPFLAGS} -c $$src",' >> compile_commands.json; \
		echo '    "file": "'$$src'"' >> compile_commands.json; \
		echo '  },' >> compile_commands.json; \
	done
	@sed -i '$$s/,$$//' compile_commands.json
	@echo ']' >> compile_commands.json

# Dependencies
.SUFFIXES: .cpp .o

.cpp.o:
	${CXX} ${CXXFLAGS} ${CPPFLAGS} -c $< -o $@

# Header dependencies (basic)
src/main.o: src/main.cpp src/PCD68_CPU.h src/KCTL.h src/Screen_SDL.h src/TDA.h src/UART.h src/KeyboardInput.h src/text_demo.h
src/PCD68_CPU.o: src/PCD68_CPU.cpp src/PCD68_CPU.h src/Moira/Moira.h
src/TDA.o: src/TDA.cpp src/TDA.h
src/KCTL.o: src/KCTL.cpp src/KCTL.h
src/UART.o: src/UART.cpp src/UART.h
src/Screen.o: src/Screen.cpp src/Screen.h
src/Screen_SDL.o: src/Screen_SDL.cpp src/Screen_SDL.h src/Screen.h
src/KeyboardInput.o: src/KeyboardInput.cpp src/KeyboardInput.h
src/KeyboardInputSDL.o: src/KeyboardInputSDL.cpp src/KeyboardInputSDL.h src/KeyboardInput.h
src/Moira/Moira.o: src/Moira/Moira.cpp src/Moira/Moira.h
src/Moira/MoiraDebugger.o: src/Moira/MoiraDebugger.cpp src/Moira/MoiraDebugger.h src/Moira/Moira.h

# Help target
help:
	@echo "Available targets:"
	@echo "  all     - Build pcd68 (default)"
	@echo "  test    - Build and run tests (requires gtest)"
	@echo "  clean   - Remove object files and executables"
	@echo "  install - Install pcd68 to /usr/local/bin"
	@echo "  compile_commands.json - Generate compile commands for IDE"
	@echo "  help    - Show this help message"
	@echo ""
	@echo "Prerequisites:"
	@echo "  pkg_add sdl2"
	@echo "  pkg_add gtest (for tests)"

.PHONY: all test clean install help 
