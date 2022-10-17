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
	
.loop: 
	ld a,(iy) 	; get flag byte
	cp a,127 
	jr z,.end 
	inc iy
	bit 7,a 
	jr nz,.rle 
	
.literal: 
	and a,01111111b 
	ld bc,0 
	ld c,a		; get number of literal bytes  
	inc bc
	
	lea de,ix+0 ; copy bytes 
	lea hl,iy+0 
	add ix,bc 
	add iy,bc 
	ldir 
 
	jq .loop 
	
.rle: 
	and a,01111111b
	ld bc,0 
	ld c,a 			; bc = length 
	inc bc			; + 1 
	
	ld a,(iy) 		; a = color 
	inc iy
	
	lea hl,ix+0		; find address
	ld (hl),a 
	lea de,ix+1 
	add ix,bc 
	ldir 			; copy from offset 

	jq .loop 
	
.end: 
	pop ix 
	ret 
	
	