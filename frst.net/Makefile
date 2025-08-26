# Makefile for FRST.net ROM on OpenBSD using vasm
# This requires vasm68k_mot to be built and in your PATH

VASM = $(HOME)/bin/vasm68k_mot
VASM_FLAGS = -Fbin -m68000 -quiet

# Source files - converted to Motorola syntax
SOURCES_MOT = main_mot.s content_single_mot.s utility_functions_mot.s aether_modem_mot.s

# Output files
TARGET = frst_net.bin
HEX_TARGET = frst_net.hex

all: $(TARGET) $(HEX_TARGET)

# Build the ROM binary
$(TARGET): $(SOURCES_MOT)
	$(VASM) $(VASM_FLAGS) -o $(TARGET) main_mot.s

# Convert to Intel HEX format
$(HEX_TARGET): $(SOURCES_MOT)
	$(VASM) -Fihex -m68000 -quiet -o $(HEX_TARGET) main_mot.s

# Conversion rules - GNU AS to Motorola syntax
# This is a simplified conversion - may need manual adjustments
%_mot.s: %.S
	@echo "Converting $< to Motorola syntax..."
	@cp $< $@
	@# Convert directives
	@sed -i 's/^\.equ \([^,]*\), \(.*\)/\1 equ \2/' $@
	@sed -i 's/^\.global/	xdef/' $@
	@sed -i 's/^\.extern/	xref/' $@
	@sed -i 's/^\.text/	section code/' $@
	@sed -i 's/^\.data/	section data/' $@
	@sed -i 's/^\.bss/	section bss/' $@
	@sed -i 's/^\.byte/	dc.b/' $@
	@sed -i 's/^\.word/	dc.w/' $@
	@sed -i 's/^\.long/	dc.l/' $@
	@sed -i 's/^\.ascii/	dc.b/' $@
	@sed -i 's/^\.asciz \(.*\)/	dc.b \1,0/' $@
	@sed -i 's/^\.align/	align/' $@
	@sed -i 's/^\.space/	ds.b/' $@
	@sed -i 's/^\.include "\(.*\)"/	include "\1"/' $@
	@# Convert hex numbers from 0x to $
	@sed -i 's/0x\([0-9a-fA-F]*\)/$$\1/g' $@
	@# Remove % from register names
	@sed -i 's/%\([ad][0-7]\)/\1/g' $@
	@sed -i 's/%sp/sp/g' $@
	@sed -i 's/%pc/pc/g' $@
	@sed -i 's/%sr/sr/g' $@
	@sed -i 's/%ccr/ccr/g' $@
	@echo "Conversion complete. Manual review may be needed for: $@"

# Build vasm if not present
build-vasm:
	./build_vasm.sh

clean:
	rm -f $(TARGET) $(HEX_TARGET) $(SOURCES_MOT) test.s test.bin

.PHONY: all clean build-vasm