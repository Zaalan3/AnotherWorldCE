include 'ti84pceg.inc' 

section .text 

public _initAsm 
public _cleanupAsm

_initAsm: 
	; set bpp = 4
	ld a,(ti.mpLcdCtrl) 
	and a,11110001b ; mask out bpp
	or a,ti.lcdBpp4
	ld (ti.mpLcdCtrl),a  
	ld a,(ti.mpLcdCtrl+1)
	and a,00001111b 
	ld (ti.mpLcdCtrl+1),a
	
	; set LCD timing 
	ld hl,lcdTiming 
	ld de,ti.mpLcdTiming0 
	ld bc,8 
	ldir
	ld hl,1023 
	ld (ti.mpLcdTiming2+2),hl
	jp spiInit 

_cleanupAsm:
	ld hl,239
	ld (ti.mpLcdTiming2+2),hl
	jp spiEnd
	

lcdTiming: 
	db	63 shl 2 
	db	0 
	db	0 
	db	0 
	dw	74 
	db	0
	db	157 

extern spiInit
extern spiEnd
