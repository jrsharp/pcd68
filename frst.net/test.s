    org $8000
start:
    move.l #$430002,a0
    move.b #65,(a0)
    rts