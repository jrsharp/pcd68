; Simple demo program for PCD-68
; Displays "Hello, PCD-68!" on the screen
;

        ORG     $0000
START:
        ; Set up stack pointer
        move.l  #$840000,a7        ; Stack at top of RAM

        ; Initialize TDA to 80 column mode
        move.b  #$02,$410000       ; TDA mode register (80 column mode)

        ; Clear the screen (fill with spaces)
        lea     $410001,a0         ; Start of character map
        move.l  #(80*23)-1,d0      ; Character count (80 cols x 23 rows - 1) for counter
.clear:
        move.b  #' ',(a0)+         ; Write space
        dbra    d0,.clear          ; Decrement and branch until done

        ; Display message at position (20,10)
        lea     MESSAGE,a0         ; Load message address
        lea     $410001,a1         ; Start of character map
        add.l   #(10*80)+20,a1     ; Position at row 10, column 20
.loop:
        move.b  (a0)+,d0           ; Get next character
        beq.s   .done              ; If zero, we're done
        move.b  d0,(a1)+           ; Write character to screen
        bra.s   .loop              ; Repeat
.done:
        
        ; Wait for key press
.wait:
        move.b  $420000,d0         ; Read keyboard controller status
        beq.s   .wait              ; Loop if no key pressed
        
        ; Exit
        trap    #15                ; Halt

; Message data
MESSAGE:
        dc.b    "Hello, PCD-68!",0

        END     START 