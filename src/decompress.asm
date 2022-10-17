include 'ti84pceg.inc'

section .text 

public _decompressVRAM
public decompressPage

extern getBuffer 
extern _vramBackup

_decompressVRAM: 
	pop hl 
	pop iy 	; iy = data pointer 
	push hl 
	push hl 
	
	ld hl,ti.mpLcdPalette
	ld de,ti.mpLcdPalette+1 
	ld bc,32 
	xor a,a 
	ld (hl),a 
	ldir
	
	ld a,0
	call decompressPage 
	ld a,1
	call decompressPage
	ld a,2
	call decompressPage
	ld a,3
	ld iy,_vramBackup
	
decompressPage:
	push ix 
	call getBuffer
	push hl 
	pop ix	; ix = output pointer  
	
	ld hl,(iy) 	; get block count
	lea iy,iy+3 
	ld de,1
.outer: 
	ld a,(iy) 	; get flag byte 
	inc iy 
	ld b,8
.inner: 
	exx 
	rla 
	; 1 = rle 
	jq c,.rle 
.literal: 
	ex af,af' 
	ld bc,0 
	
	ld c,(iy) 	; get number of literal bytes 
	inc iy 
	inc bc
	lea de,ix+0 ; copy bytes 
	lea hl,iy+0 
	add ix,bc 
	add iy,bc 
	ldir 
	
	exx
	ex af,af' 
	or a,a 
	sbc hl,de 
	jq z,.end  
	djnz .inner
	jq .outer 
	
.rle: 
	ex af,af'
	ld bc,0 
	
	ld a,(iy) 		; a = color 
	ld c,(iy+1) 	; bc = length 
	inc bc			; length + 1  
	lea iy,iy+2
	
	lea hl,ix+0		; find address
	ld (hl),a 
	lea de,ix+1 
	add ix,bc 
	ldir 			; copy from offset 
	
	exx
	ex af,af' 
	or a,a 
	sbc hl,de 
	jq z,.end 
	djnz .inner
	jq .outer
	
.end: 
	pop ix 
	ret 
	
	