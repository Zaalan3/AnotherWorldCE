section .text 

public _drawString
public _drawText 
public _tickText

extern _stringTable
extern _font

; draw string at top of every screen 
_drawText: 
	call clearText  
	pop de 
	pop hl 
	pop bc  
	push bc  
	push hl 
	push de 
	push ix 
	ld a,c 
	ld (textTimer),a 
	
	ld a,$FF 
	ld de,$D40000
	call _drawString
	; copy to other buffers 
.copy:
	ld hl,$D40000 
	ld de,$D40000 + 160*240 
	ld bc,160*16 
	ldir 
	
	ld hl,$D40000 
	ld de,$D40000 + 160*240*2 
	ld bc,160*16 
	ldir 
	
	ld hl,$D40000 
	ld de,$D40000 + 160*240*3 
	ld bc,160*16 
	ldir 
	
	pop ix 
	ret 
	
_tickText: 
	ld a,0 
textTimer:=$-1 
	or a,a 
	ret z
	dec a 
	ld (textTimer),a 
	ret nz
clearText: 

	ld hl,$D40000 
	xor a,a 
	ld (hl),a 
	ld de,$D40001 
	ld bc,160*20 - 1
	ldir 
	
	ld hl,$D40000 
	ld de,$D40000 + 160*219
	ld bc,160*20
	ldir 
	
	ld hl,$D40000 
	ld de,$D49600
	ld bc,160*20 
	ldir 
	
	ld hl,$D40000 + 160*220 
	ld de,$D49600 + 160*219 
	ld bc,160*40 
	ldir 
	
	ld hl,$D40000 + 160*220
	ld de,$D52C00 + 160*220 
	ld bc,160*40
	ldir
	
	ld hl,$D40000 + 160*220
	ld de,$D5C200 + 160*220 
	ld bc,160*20
	ldir
	
	ret 
	
; hl = string entry 
; de = buffer pointer
; a = color
_drawString: 
	; find string in table
	ld ix,_stringTable
.searchLoop:
	ld bc,(ix+0) 	; ix + 0 = entry number
	or a,a 
	sbc.sis hl,bc
	jr Z,.endsearch
	add hl,bc 
	lea ix,ix+5 
	jr .searchLoop
.endsearch: 
	ld ix,(ix+2)	; ix + 2 = string pointer
	ex de,hl	; hl = buffer pointer
	push hl		; for new lines
	and a,$0F
	ld c,a 	; get color bit mask (c<<4 | c) 
	rlca 
	rlca 
	rlca 
	rlca
	or a,c 
	exx 
	ld c,a 
	exx
	; c' = color mask 
	; ix = string pointer 
	; hl = buffer pointer
.charloop: 
	ld a,(ix+0) 
	inc ix
	or a,a 
	jq Z,.end 	; 0 = string end
	cp a,$0a ; new line 
	jr nz,.skipnewline 
	pop hl	
	ld de,160*8 
	add hl,de 	
	push hl
	jr .charloop 
.skipnewline: 
	call drawCharacter 
	inc hl	; x += 4 
	inc hl
	inc hl
	inc hl
	jr .charloop 
.end: 
	pop hl 
	ret
	
; hl = buffer pointer 
; a = character 
; c' = color mask 
drawCharacter:
	push hl  
	ld de,160 - 4 
	ld b,8
	exx 
	sub a,$20 ; [space] character is start of font
	ld h,32	; 32 bytes per character (4x8) 
	ld l,a 
	mlt hl 
	ld de,_font 
	add hl,de
	exx
.loop:
repeat 4 	
	exx 
	ld a,(hl) 
	inc hl
	ld d,a 
	and a,c 
	ld e,a 
	ld a,d 
	cpl 
	exx  
	and a,(hl) 
	exx 
	or a,e 
	exx 
	ld (hl),a
	inc hl
end repeat
	add hl,de ; y++
	djnz .loop
	pop hl
	ret 