; IRQ routine/stub for playing SID music.
; Contributed by RB, modified to work without KERNAL ROM.
; xa65 assembler syntax.

.word $cf00
*=$cf00

musicinit = $b000
musicplay = musicinit + 3

jmp startmusic
jmp stopmusic

startmusic:
sei
pha
lda #$35 ; disable BASIC/KERNAL ROMs
sta $01
lda $02a6 ; PAL NTSC check
sta system
ldx #<irq
ldy #>irq
stx $0314
sty $0315
ldx #<nmi
ldy #>nmi
stx $fffa ; make sure hitting RESTORE with ROMs disabled does not crash the machine
sty $fffb
lda #$7f
sta $dc0d
sta $dd0d
lda $dc0d ; ack any pending CIA irqs
lda $dd0d
lda #$2e
sta $d012
lda #$1b
sta $d011
lda #$01
sta $d019
sta $d01a
pla
jsr musicinit
lda #$37 ; enable ROMs
sta $01
cli
rts

stopmusic:
sei
ldx #$31
ldy #$ea
stx $0314
sty $0315
lda #$81
sta $dc0d
sta $dd0d
lda #$00
sta $d019
sta $d01a
ldx #$00
reinit:
lda sidingame,x
sta $d400,x
inx
cpx #25
bne reinit
cli
rts


irq:
asl $d019
lda #$fa
sta $d012
lda #$35 ; disable ROMs
sta $01
jsr musicplayer
lda #$37 ; enable ROMs
sta $01
jmp $ea31

nmi:
sei
pha
lda #$7f
sta $dd0d
lda $dd0d
pla
rti

musicplayer:
lda system
cmp #1
beq pal
dec ntscdelay
bpl pal
lda #5 ; on NTSC, skip every 6th call
sta ntscdelay
rts
pal:
jsr musicplay
rts

system: .byte 0
ntscdelay: .byte 0

sidingame:
.byte $00,$0b,$07,$07, $00,$34,$22,$00, $40,$00,$00,$00, $29,$2a,$00,$1a
.byte $00,$00,$20,$14, $68,$00,$00,$00, $0f
