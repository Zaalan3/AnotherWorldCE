section .text 

public _drawString

extern _stringTable
extern _font

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
