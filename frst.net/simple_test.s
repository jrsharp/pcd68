; Simple test file for vasm
TDABase	equ	$410000
TextMode equ 2

	org	$1000
start:
    move.l  #$410000,a2
    move.b  #2,(a2)+
    rts