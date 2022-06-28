; adapted from https://github.com/c1570/MrVSFUnfreeze

* = $0801

!byte $0c,$08,$00,$00,$9e
!byte $30 + start DIV 10000,$30 + start DIV 1000 % 10,$30 + start DIV 100 % 10,$30 + start DIV 10 % 10,$30 + start % 10
!byte $00,$00,$00

cmpr_08:
!binary "build/cmpr_08.bin"

!if * >= $4000 {
!error "cmpr_08.bin too long, reaches to ", *
}

start:
sei
lda #$00
sta $d020
sta $d021
lda #$0b   ; disable screen
sta $d011

waitclr:
lda $d012
bne waitclr
lda $d011
bmi waitclr

ldy #0
cpy_helper:
lda start_helper+$0000,y
sta $0400,y
lda start_helper+$0100,y
sta $0500,y
lda start_helper+$0200,y
sta $0600,y
lda start_helper+$0300,y
sta $0700,y
iny
bne cpy_helper

jmp helper_entry

start_helper:
!pseudopc $0400 {

!src "decompress_faster_v1.asm"

helper_entry:
; first, make room for graphics, so move away compressed data from $4000
lda #$30
sta $01 ; all RAM

lda #0
sta LZSA_DST_LO
lda #(256 - page_count_B)
sta LZSA_DST_HI
lda #<start_B_aligned
sta LZSA_SRC_LO
lda #>start_B_aligned
sta LZSA_SRC_HI
ldx #page_count_B
jsr justcopy   ; copy block B ($A000-... compressed data) to end of memory

lda #00
sta LZSA_DST_LO
lda #$A0
sta LZSA_DST_HI
lda #<start_C
sta LZSA_SRC_LO
lda #>start_C
sta LZSA_SRC_HI
ldx #page_count_koala
jsr justcopy   ; copy koala compressed data to $A000

lda #0
sta LZSA_DST_LO
lda #($A0 - page_count_A)
sta LZSA_DST_HI
lda #<start_A_aligned
sta LZSA_SRC_LO
lda #>start_A_aligned
sta LZSA_SRC_HI
ldx #page_count_A
jsr justcopy   ; copy block A ($6000 compressed data) to end of BASIC RAM

; decompress graphics
lda #$35
sta $01  ; enable I/O

lda #<cmpr_koala
sta LZSA_SRC_LO
lda #>cmpr_koala
sta LZSA_SRC_HI
lda #0
sta LZSA_DST_LO
lda #$60
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST  ; screen mem

lda #0
sta LZSA_DST_LO
lda #$d8
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST  ; col mem

lda #0
sta LZSA_DST_LO
lda #$40
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST  ; bitmap

; enable graphics mode
lda #$3f
sta $dd02  ; enable CIA2 port A output
lda #$c2
sta $dd00  ; select VIC bank 1 ($4000-$7FFF)
lda #$80
sta $d018  ; bitmap at $4000, screen mem at $6000
lda #$18
sta $d016  ; enable multicolor mode
lda #$3b
sta $d011  ; enable graphics, enable screen

; splash is visible now - unpack (most) of the rest already

lda #$30
sta $01 ; all RAM

; $A000-...
lda #<cmpr_A0
sta LZSA_SRC_LO
lda #>cmpr_A0
sta LZSA_SRC_HI
lda #$00
sta LZSA_DST_LO
lda #$A0
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST

; splash screen is visible, wait for key/joy2

lda #$35
sta $01  ; enable I/O

lda #$ff
sta $dc03
lda #$00
sta $dc02
sta $dc01
waitkey:
ldx $dc00
cpx $dc00
bne waitkey
inx
beq waitkey
waitkey2:
ldx $dc00
cpx $dc00
bne waitkey2
inx
bne waitkey2

ldx #$ff
stx $dc02
inx
stx $dc03

; unpack last bits and start

lda #$2b   ; disable screen
sta $d011
waitclr2:
lda $d012
bne waitclr2
lda $d011
bmi waitclr2
lda #$08
sta $d016  ; disable multicolor mode

; move up $0801 compressed data
ldy #0
sty LZSA_SRC_LO
sty LZSA_DST_LO
lda #>$3f00
sta LZSA_SRC_HI
lda #>$6100
sta LZSA_DST_HI
ldx #($40-$08)
jcloop2: lda (lzsa_srcptr),y
sta (lzsa_dstptr),y
iny
bne jcloop2
dec LZSA_SRC_HI
dec LZSA_DST_HI
dex
bne jcloop2

; decompress $0801-$5FFF
lda #<cmpr_08
sta LZSA_SRC_LO
lda #(>cmpr_08) + ($61-$3f)
sta LZSA_SRC_HI
lda #$01
sta LZSA_DST_LO
lda #$08
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST

; decompress $6000
lda #<cmpr_60
sta LZSA_SRC_LO
lda #>cmpr_60
sta LZSA_SRC_HI
lda #$80
sta LZSA_DST_LO
lda #$5E
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST ; $5E80

lda #$37
sta $01  ; standard config
jmp 2076

loop:
lda #$35
sta $01  ; enable I/O
lda #$01
sta $d020
sta $d021
jmp loop



; copy X times 256 bytes from LZSA_SRC to LZSA_DST
justcopy:
ldy #0
jcloop:
lda (lzsa_srcptr),y
sta (lzsa_dstptr),y
iny
bne jcloop
inc <lzsa_srcptr + 1
inc <lzsa_dstptr + 1
dex
bne jcloop
rts
}

; start of block A
start_A:
!binary "build/cmpr_60.bin"
end_A:
page_count_A = (end_A - start_A + 255) DIV 256
start_A_aligned = end_A - page_count_A * 256
cmpr_60 = $A000-(end_A-start_A)
; block A will be copied to end at 9FFF

; start of block C
!if * >= $A000 {
!error "koala compressed data too late"
}
start_C:
!binary "build/cmpr_screen.bin"
!binary "build/cmpr_colmem.bin"
!binary "build/cmpr_bitmap.bin"
end_C:
!if * >= $A000 {
!error "koala compressed data overlapping"
}
cmpr_koala = $A000
; block C will be copied to start at A000

; start of block B
start_B:
!binary "build/cmpr_A0.bin"
end_B:
page_count_B = (end_B - start_B + 255) DIV 256
start_B_aligned = end_B - page_count_B * 256
cmpr_A0 = 65536-(end_B-start_B)
; block B will be copied to end at FFFF



page_count_koala = (end_C - start_C + 255) DIV 256
!if end_C > ($10000 - page_count_B * 256) {
!error "koala compressed data would get overwritten by block B"
}
