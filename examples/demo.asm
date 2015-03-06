;------------------------------------------------------------------------------
;  This is a direct port of Michael Martin's tutorial project for NES101
;  With some modifications to the tile map, and extra comments, and ported to
;  suit my assembler. - Saf
;  See:
;  http://hackipedia.org/Platform/Nintendo/NES/tutorial,%20NES%20programming%20101/NES101.html
;
;;;;
;  Create an iNES header
.ines {"prog": 1, "char": 1, "mapper": 0, "mirror": 0}

;;;;
;  Here is a good spot to associate zero page memory addresses
;  with quick access variables in the program.
.segment prog 0
.org $0200
sprite:


;;;;
;  Setup the interrupt vectors
.org $FFFA
.dw vblank
.dw main
.dw irq


;;;;
;  Here is our code entry point, which we'll call main.
.org $C000
.scope main
  ;  Disable interrupts and decimal flag
  sei
  cld

  ;  Wait for 2 vblanks
  wait_vb1:
    lda $2002
    bpl wait_vb1
  wait_vb2:
    lda $2002
    bpl wait_vb2

  ;  Now we want to initialize the hardware to a known state
  lda #$00
  ldx #$00
  clear_segments:
    sta $00, X
    sta $0100, X
    sta $0200, X
    sta $0300, X
    sta $0400, X
    sta $0500, X
    sta $0600, X
    sta $0700, X
    inx
    bne clear_segments

  ;  Reset the stack pointer
  ldx #$FF
  txs

  ;  Disable all graphics.
  lda #$00
  sta $2000
  sta $2001

  jsr init_graphics
  jsr init_input
  jsr init_sound
  jsr init_ppu

  ;  Resume interrupts and loop here forever
  cli
  forever:
    jmp forever
.


;;;;
; Set basic PPU registers.  Load background from $0000,
; sprites from $1000, and the name table from $2000.
.scope init_ppu
  lda #$88
  sta $2000
  lda #$1E
  sta $2001
  rts
.


;;;;
;  Initialize all the sprites, palettes, nametables, and scrolling
.scope init_graphics
  jsr init_sprites
  jsr load_palette
  jsr load_name_tables
  jsr init_scrolling
  rts
.


;;;;
;  Initialize the controller input, keeping track of the A button
.scope init_input
  lda #$00
  sta $01    ; $01 = A button
  rts
.

;;;;
;  Initialize the APU to known values
.scope init_sound
  lda #$01
  sta $4015
  lda #$00
  sta $4001
  lda #$40
  sta $4017
  rts
.


;;;;
;  Clear page #2, which we'll use to hold sprite data
;  This subroutine clearly shows why I need to have symbols
;  to refer to bits of RAM in the zero page like dx, etc.
.scope init_sprites
  lda #$00
  ldx #$00
  sprite_clear1:
    sta sprite, x
    inx
    bne sprite_clear1

  ; initialize Sprite 0
  lda #$70
  sta $0200                ; sprite Y coordinate
  lda #$01
  sta $0201                ; sprite + 1 Pattern number
  sta $0203                ; sprite + 3 X coordinate, sprite + 2, color, stays 0.

  ; Set initial value of dx
  lda #$01
  sta $00                 ;  dx = $00
  rts
.

;;;;
;  Load palette into $3F00
.scope load_palette
  lda #$3F
  ldx #$00
  sta $2006
  stx $2006
  loop:
    lda palette, X
    sta $2007
    inx
    cpx #$20
    bne loop
  rts
.

;;;;
; Put the ASCII values from bg into the first name table, at $2400
; The tile values are conveniently mapped to their ASCII values
.scope load_name_tables
  ldy #$00
  ldx #$04
  lda #<bg
  sta $10
  lda #>bg
  sta $11
  lda #$24
  sta $2006
  lda #$00
  sta $2006
  loop:
    lda ($10), Y
    sta $2007
    iny
    bne loop
    inc $11
    dex
    bne loop
  ;  This now clears the second name table?
  ;  I think this is because writing to $2007 auto increments the
  ;  written value
  ldy #$00
  ldx #$04
  lda #$00
  back:
    sta $2007
    iny
    bne back
    dex
    bne back
  rts
.


;;;;
;  This initializes the scrolling storing the scroll
;  value in the zero page variable $02
.scope init_scrolling
  lda #$F0
  sta $02
  rts
.


;;;;
;  Update the sprite, I don't exactly understand this yet.
update_sprite:
  lda #>sprite
  sta $4014                ; Jam page $200-$2FF into SPR-RAM
  lda $0203                ;  sprite+3  Is this right???
  beq hit_left
  cmp #$F7
  bne edge_done
  ; Hit right
  ldx #$FF
  stx $00                   ;  dx
  jsr high_c
  jmp edge_done

hit_left:
  ldx #$01
  stx $00                    ;  dx
  jsr high_c

edge_done:                ; update X and store it.
  clc
  adc $00                 ;  dx
  sta $0203                ;  sprite+3 Is this right?
  rts

react_to_input:
  lda #$01                ; strobe joypad
  sta $4016
  lda #$00
  sta $4016

  lda $4016               ; Is the A button down?
  AND #$01
  beq not_a
  ldx $01                 ;  a
  bne a_done              ; Only react if the A button wasn't down last time.
  sta $01                 ; Store the 1 in local variable 'a' so that we this is
  jsr reverse_dx          ; only called once per press.
  jmp a_done
  not_a:  
    sta $01                 ; A has been released, so put that zero into 'a'.
  a_done: 
    lda $4016                ; B does nothing
    lda $4016                ; Select does nothing
    lda $4016                ; Start does nothing
    lda $4016                ; Up
    and #$01
    beq not_up
    ldx sprite                ; Load Y value
    cpx #$07
    beq not_up                ; No going past the top of the screen
    dex
    stx sprite

  not_up: 
    lda $4016                ; Down
    and #$01
    beq not_dn
    ldx sprite
    cpx #$DF                  ; No going past the bottom of the screen.
    beq not_dn
    inx
    stx sprite
  not_dn: 
  rts                                ; Ignore left and right, we don't use 'em

reverse_dx:
  lda #$FF
  eor $00          ; dx  Toggles between 0x1 and 0xfe (-1)
  clc
  adc #$01         ; add dx, and store to variable
  sta $00          ; dx
  jsr low_c
  rts

scroll_screen:
  ldx #$00                ; Reset VRAM
  stx $2006
  stx $2006

  ldx $02                 ; scroll                ; Do we need to scroll at all?
  beq no_scroll
  dex
  stx $02                 ; scroll
  lda #$00
  sta $2005                ; Write 0 for Horiz. Scroll value
  stx $2005                ; Write the value of 'scroll' for Vert. Scroll value

no_scroll:
  rts

;;;;
;  I am pretty sure this plays a low C note on the Square wave
low_c:
  pha
  lda #$84
  sta $4000
  lda #$AA
  sta $4002
  lda #$09
  sta $4003
  pla
  rts

;;;;
;  I am pretty sure this plays a high C note on the Square wave
high_c:
  pha
  lda #$86
  sta $4000
  lda #$69
  sta $4002
  lda #$08
  sta $4003
  pla
  rts

;;;;
;  Update everything on every vblank
vblank: 
  jsr scroll_screen
  jsr update_sprite
  jsr react_to_input
  rti


;;;;
;  Don't do anything on IRQ
irq:    
  rti


;;;;
; Palette data stored in the PROG section, to be copied later
palette:
.bytes $0E,$00,$0E,$19,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$01,$21
.bytes $0E,$20,$22,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00


;;;;
; Background data stored in the PROG section to be copied later
bg:
.ascii "                                "
.ascii "                                "
.ascii "   SAF'S 6502 NES ASSEMBLER     "
.ascii "                                "
.ascii "                                "
.ascii "                                "
.ascii "    VSS              RES        "
.ascii "    RDY              PHI2       "
.ascii "    PH1              S0         "
.ascii "    IRQ      6       PHI0       "
.ascii "     NC              NC         "
.ascii "    NMI              NC         "
.ascii "   SYNC      5       R/W        "
.ascii "    VCC              D0         "
.ascii "     A0              D1         "
.ascii "     A1      0       D2         "
.ascii "     A2              D3         "
.ascii "     A3              D4         "
.ascii "     A4      2       D5         "
.ascii "     A5              D6         "
.ascii "     A6              D7         "
.ascii "     A7              A15        "
.ascii "     A8              A14        "
.ascii "     A9              A13        "
.ascii "    A10              A12        "
.ascii "    A11              VSS        "
.ascii "                                "
.ascii "                                "
.ascii "                                "
.ascii "                                "


;;;;
; Attribute table, this is basically the tilemap
.bytes $00,$00,$00,$00,$00,$00,$00,$00,
.bytes $00,$00,$FF,$FF,$FF,$00,$00,$00,
.bytes $00,$00,$FF,$FF,$FF,$00,$00,$00,
.bytes $00,$00,$FF,$FF,$FF,$00,$00,$00,
.bytes $00,$00,$FF,$FF,$FF,$00,$00,$00,
.bytes $00,$00,$FF,$FF,$FF,$00,$00,$00,
.bytes $00,$00,$FF,$FF,$FF,$00,$00,$00,
.bytes $00,$00,$00,$00,$00,$00,$00,$00,



;;;;
;  This is CHR-ROM page 1, which starts at 0x0000, but I'm skipping the first bit because
;  the first bunch of ASCII characters are not represented. This is the commodore 64's 
;  character ROM.  
.segment char 0
.org $0200

.bytes $00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 32
.bytes $18,$18,$18,$18,$00,$00,$18,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 33
.bytes $66,$66,$66,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 34
.bytes $66,$66,$FF,$66,$FF,$66,$66,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 35
.bytes $18,$3E,$60,$3C,$06,$7C,$18,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 36
.bytes $62,$66,$0C,$18,$30,$66,$46,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 37
.bytes $3C,$66,$3C,$38,$67,$66,$3F,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 38
.bytes $06,$0C,$18,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 39
.bytes $0C,$18,$30,$30,$30,$18,$0C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 40
.bytes $30,$18,$0C,$0C,$0C,$18,$30,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 41
.bytes $00,$66,$3C,$FF,$3C,$66,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 42
.bytes $00,$18,$18,$7E,$18,$18,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 43
.bytes $00,$00,$00,$00,$00,$18,$18,$30,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 44
.bytes $00,$00,$00,$7E,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 45
.bytes $00,$00,$00,$00,$00,$18,$18,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 46
.bytes $00,$03,$06,$0C,$18,$30,$60,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 47
.bytes $3C,$66,$6E,$76,$66,$66,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 48
.bytes $18,$18,$38,$18,$18,$18,$7E,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 49
.bytes $3C,$66,$06,$0C,$30,$60,$7E,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 50
.bytes $3C,$66,$06,$1C,$06,$66,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 51
.bytes $06,$0E,$1E,$66,$7F,$06,$06,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 52
.bytes $7E,$60,$7C,$06,$06,$66,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 53
.bytes $3C,$66,$60,$7C,$66,$66,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 54
.bytes $7E,$66,$0C,$18,$18,$18,$18,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 55
.bytes $3C,$66,$66,$3C,$66,$66,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 56
.bytes $3C,$66,$66,$3E,$06,$66,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 57
.bytes $00,$00,$18,$00,$00,$18,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 58
.bytes $00,$00,$18,$00,$00,$18,$18,$30,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 59
.bytes $0E,$18,$30,$60,$30,$18,$0E,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 60
.bytes $00,$00,$7E,$00,$7E,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 61
.bytes $70,$18,$0C,$06,$0C,$18,$70,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 62
.bytes $3C,$66,$06,$0C,$18,$00,$18,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 63
.bytes $3C,$66,$6E,$6E,$60,$62,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 64
.bytes $18,$3C,$66,$7E,$66,$66,$66,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 65
.bytes $7C,$66,$66,$7C,$66,$66,$7C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 66
.bytes $3C,$66,$60,$60,$60,$66,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 67
.bytes $78,$6C,$66,$66,$66,$6C,$78,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 68
.bytes $7E,$60,$60,$78,$60,$60,$7E,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 69
.bytes $7E,$60,$60,$78,$60,$60,$60,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 70
.bytes $3C,$66,$60,$6E,$66,$66,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 71
.bytes $66,$66,$66,$7E,$66,$66,$66,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 72
.bytes $3C,$18,$18,$18,$18,$18,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 73
.bytes $1E,$0C,$0C,$0C,$0C,$6C,$38,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 74
.bytes $66,$6C,$78,$70,$78,$6C,$66,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 75
.bytes $60,$60,$60,$60,$60,$60,$7E,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 76
.bytes $63,$77,$7F,$6B,$63,$63,$63,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 77
.bytes $66,$76,$7E,$7E,$6E,$66,$66,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 78
.bytes $3C,$66,$66,$66,$66,$66,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 79
.bytes $7C,$66,$66,$7C,$60,$60,$60,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 80
.bytes $3C,$66,$66,$66,$66,$3C,$0E,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 81
.bytes $7C,$66,$66,$7C,$78,$6C,$66,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 82
.bytes $3C,$66,$60,$3C,$06,$66,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 83
.bytes $7E,$18,$18,$18,$18,$18,$18,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 84
.bytes $66,$66,$66,$66,$66,$66,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 85
.bytes $66,$66,$66,$66,$66,$3C,$18,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 86
.bytes $63,$63,$63,$6B,$7F,$77,$63,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 87
.bytes $66,$66,$3C,$18,$3C,$66,$66,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 88
.bytes $66,$66,$66,$3C,$18,$18,$18,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 89
.bytes $7E,$06,$0C,$18,$30,$60,$7E,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 90
.bytes $3C,$30,$30,$30,$30,$30,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 91
.bytes $0C,$12,$30,$7C,$30,$62,$FC,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 92
.bytes $3C,$0C,$0C,$0C,$0C,$0C,$3C,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 93
.bytes $00,$18,$3C,$7E,$18,$18,$18,$18,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 94
.bytes $00,$10,$30,$7F,$7F,$30,$10,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; Character 95


;;;;
;  Here is sprite data on CHAR ROM page 2
.org $1000

.bytes $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; Character 0: Blank
.bytes $18,$24,$66,$99,$99,$66,$24,$18,$00,$18,$18,$66,$66,$18,$18,$00 ; Character 1: Diamond sprite
