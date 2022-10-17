
section .text 

public _compressPage

public writeFlagBit
public writeLiteral
public writeReference
public findMatch
public findLongestMatch

extern getBuffer
extern _vramBackup

IY_VARS:=$E30B80 

MAX_MATCH_LENGTH:=256 	; 10 bits for match length
MAX_OFFSET:=256

dataStart equ iy+0 
dataCurrent equ iy+3
dataEnd equ iy+6  

flagBits equ iy+9  
flagPtr equ iy+10 

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
	ld ix,_vramBackup+3
	ld iy,IY_VARS
	
	ld (dataStart),hl
	ld (dataCurrent),hl
    ld de,160*200 
    add hl,de
    ld (dataEnd),hl 
	
	or a,a 
	sbc hl,hl 
	ld (blockCount),hl 
	; initialize flag byte
	ld (flagBits),9
	ld (flagPtr),ix
	inc ix 
	; initialize first literal 
	scf 
	sbc hl,hl 
	ld (litCountPtr),hl 
	jq .literal
	
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
	; shift flag byte up by remaining bits 
	ld b,(flagBits) 
	dec b 
	jr z,.skipshr 
	ld hl,(flagPtr) 
	ld a,(hl) 
.shiftr: 
	rla 
	djnz .shiftr 
	ld (hl),a 
.skipshr: 
	lea hl,ix+0 
	ld de,_vramBackup
	or a,a 
	sbc hl,de 
	
	ld de,(blockCount) 
	ld ix,_vramBackup 
	ld (ix),de 
	
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
	or a,a 
	call writeFlagBit	; new 0 flag bit to signify new literal 
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
	push hl 
	scf 
	call writeFlagBit ; 1 to flag bit for RLE 
	
	ld hl,(dataCurrent) ; find offset from current
	ld a,(hl) 
	
	pop de 			; store length - 1
	dec de
	
	ld (ix+0),a		; color  
	ld (ix+1),e		; length 
	lea ix,ix+2
	
	scf 
	sbc hl,hl		; invalidate last literal  
	ld (litCountPtr),hl 
	
	ld hl,(blockCount) 
	inc hl 
	ld (blockCount),hl
	ret 
	
	
; writes a flag bit to the current flag byte. 
; Fetches a new flag byte if last ran out of bits. 
writeFlagBit:
	push af
	ld a,(flagBits)
	dec a 
	jr nz,.write 
.new: 	
	; fetch new flag byte if out of bits  
	xor a,a 
	lea hl,ix
	ld (hl),a 
	inc ix 
	ld (flagPtr),hl
	ld a,8
.write: 
	ld (flagBits),a
	pop af 
	ld hl,(flagPtr) 
	rl (hl) 
	ret 
	
	
findLengthRLE:
	ld b,255
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
	
	
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; writes a back-reference to the output. 
; format: 
; ; 0 			  15
; oooooooo llllllll
; hl = length  
; de = matchPtr 
writeReference: 
	push hl 
	scf 
	call writeFlagBit ; 1 to flag bit for references 
	
	ld hl,(dataCurrent) ; find offset from current
	or a,a 
	sbc hl,de 
	dec hl 			; store offset - 1
	 
	pop de 			; store length - 1
	dec de
	
	ld (ix+0),l		; offset  
	ld (ix+1),e		; length 
	lea ix,ix+2
	
	scf 
	sbc hl,hl		; invalidate last literal  
	ld (litCountPtr),hl 
	ret 

; finds match within current data window 
findMatch:
	; bunch of bounds testing
	ld hl,(dataCurrent)
	ld de,(dataStart) 
	or a,a 
	sbc hl,de 
	ld a,h 
	or a,a 
	jr nz,.gt256 
.lt256: 
	push hl 
	pop bc 
	inc bc
	ld hl,(dataStart)
	jr .match 
.gt256: 
	ld bc,MAX_OFFSET
	ld hl,(dataCurrent)
	or a,a 
	sbc hl,bc 
	inc bc
.match: 	
	call findLongestMatch
	exx 
	ret 

; hl = start of input
; bc = input length 
; out: 
; hl' = length or 0 if none found 
; de' = match ptr or NULL if none found 
findLongestMatch: 
	exx 
	or a,a 
	sbc hl,hl 	; set match to NULL 
	ex de,hl 
	sbc hl,hl 
	exx  
.nextMatch: 
	ld de,(dataCurrent) 
    ld a,(de)
    inc de 
    cpir     	; search for matching byte 
    ret po
.findLength: 
    push hl 	; hl = start of match 
	push hl 
	xor a,a		; limit to 256 bytes
.lloop:			; find end of match 
	ex af,af' 
	dec a 
	jr z,.llend 
	ex af,af'
	ld a,(de) 
    inc de
    cpi 
    jr z,.lloop 
.llend: 
    pop de 
    or a,a 
    sbc hl,de	; length = matchEnd - matchStart
	dec de 
	push de
	push hl
	exx 
	; compare to current longest match 
	pop bc
	or a,a 
	sbc hl,bc 	; if newLength > oldLength : oldMatch = newMatch
	jq nc,.lt 
.gt: 
	push bc 
	pop hl 
	pop de 
	jr .cont 
.lt: 
	add hl,bc 
	pop bc
.cont: 
	exx 
	pop hl
	dec hl
	bit 7,b	; return if bc underflowed
	ret nz 
	ld a,c 
	or a,a 
	ret z 
	jq .nextMatch
	
	