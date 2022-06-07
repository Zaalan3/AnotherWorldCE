section .text 

public _initAsm 
public _cleanupAsm
public spiCmd 
public spiParam 

extern _palettes
lcdControl:=$E30018

_initAsm: 
	; bpp = 4
	ld hl,(lcdControl) 
	ld a,l
	and a,11110001b ; mask out bpp
	or a,0100b ; 4bpp 
	ld l,a 
;	ld a,h 
;	and a,11111110b ; swap r and b 
;	ld h,a 
	ld (lcdControl),hl 
	ret 
	
_cleanupAsm: 
	ret 
	

; Input: A = parameter
spiParam:
	scf ; First bit is set for data
	db $30 ; jr nc,? ; skips over one byte
; Input: A = command
spiCmd:
	or a,a ; First bit is clear for commands
	ld hl,$0F80818
	call spiWrite
	ld l,h
	ld (hl),001h
spiWait:
	ld l,$0D
spiWait1:
	ld a,(hl)
	and a,$F0
	jr nz,spiWait1
	dec l
spiWait2:
	bit 2,(hl)
	jr nz,spiWait2
	ld l,h
	ld (hl),a
	ret
spiWrite:
	ld b,3
spiWriteLoop:
	rla
	rla
	rla
	ld (hl),a ; send 3 bits
	djnz spiWriteLoop
	ret


	