
section .text 

public _compressPage

public writeLiteral
public writeRLE
public findLengthRLE

extern getBuffer
extern _vramBackup

IY_VARS:=$E30B80 

MAX_MATCH_LENGTH:=256 	; 10 bits for match length
MAX_OFFSET:=256

dataStart equ iy+0 
dataCurrent equ iy+3
dataEnd equ iy+6  

litCountPtr equ iy+13 
blockCount equ iy+16 

; arg0 = vram page
_compressPage: 
	pop hl 
    pop bc  
    push bc  
    push hl   
	push ix
	
    ld a,c 
    call getBuffer ; hl = page pointer 
	; ix = output
	; iy = vars 
	ld ix,_vramBackup
	ld iy,IY_VARS
	
	ld (dataStart),hl
	ld (dataCurrent),hl
    ld de,160*200 
    add hl,de
    ld (dataEnd),hl 
	
	; initialize first literal 
	scf 
	sbc hl,hl 
	ld (litCountPtr),hl 
	
.loop: 
	ld hl,(dataCurrent) ; stop if we're out of bytes 
	ld de,(dataEnd) 
	or a,a 
	sbc hl,de 
	jr nc,.end 
	call findLengthRLE 	; find longest match for current data 
	
	ld bc,3 			; if matchlength < 3 write a literal 
	or a,a 
	sbc hl,bc 
	jr c,.literal 
.reference: 			; otherwise write a RLE  
	add hl,bc 
	push hl 
	call writeRLE 
	pop hl
	ld de,(dataCurrent) 
	add hl,de 
	ld (dataCurrent),hl 
	jr .loop
	
.literal: 
	call writeLiteral
	jr .loop 
	
.end: 
	ld (ix+0),127
	inc ix 
	lea hl,ix+0 
	ld de,_vramBackup
	or a,a 
	sbc hl,de 
	
	pop ix 
	ret 
	
; Writes a literal byte to the output. 
; input: a = byte to write 
writeLiteral:
	ld hl,(litCountPtr)	
	ld de,1 
	add hl,de 
	jr c,.newLiteral ; if litCountPtr = FFFFFF, invalidate it 
	dec hl 
	ld a,(hl) 
	inc a 
	cp a,127
	jr z,.newLiteral ; if literal has reached max size, invalidate 
	ld (hl),a  
	ld hl,(dataCurrent) 
	ld a,(hl) 
	ld (ix),a 
	inc ix 
	inc hl 
	ld (dataCurrent),hl 
	ret 
.newLiteral: 
	ld hl,(dataCurrent)
	ld a,(hl)
	inc hl 
	ld (dataCurrent),hl 
	ld (litCountPtr),ix 
	ld (ix+0),0
	ld (ix+1),a 
	lea ix,ix+2 
	
	ld hl,(blockCount) 
	inc hl 
	ld (blockCount),hl
	ret 
	
writeRLE: 
	ld de,(dataCurrent) ; find offset from current
	ld a,(de) 
	
	dec hl  			; store length - 1
	
	set 7,l			; 1 in bit 7 for rle 
	ld (ix+0),l		; length  	
	ld (ix+1),a		; color
	lea ix,ix+2
	
	scf 
	sbc hl,hl		; invalidate last literal  
	ld (litCountPtr),hl 
	
	ld hl,(blockCount) 
	inc hl 
	ld (blockCount),hl
	ret 
	
findLengthRLE:
	ld b,127
	ld hl,(dataCurrent) 
    ld a,(hl)
    inc hl 
.loop: 
	cp a,(hl) 
	jr nz,.llend 
	inc hl 
	djnz .loop 
.llend: 
	ld de,(dataCurrent) 
	or a,a 
	sbc hl,de 
	ret 
	