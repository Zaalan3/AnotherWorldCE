include 'ti84pceg.inc' 

section .text 

public _initAsm 
public _cleanupAsm
public _backupVRAM 
public _loadVRAM

define cemu 0

_initAsm: 
	di 
	xor a,a 
	ld (ti.usbInited),a
	; set bpp = 4
	ld a,(ti.mpLcdCtrl) 
	and a,11110001b ; mask out bpp
	or a,ti.lcdBpp4
	ld (ti.mpLcdCtrl),a  
	ld a,(ti.mpLcdCtrl+1)
	and a,00001111b 
	ld (ti.mpLcdCtrl+1),a
	
	; set LCD timing 
	
	if cemu = 0
		ld hl,lcdTiming 
		ld de,ti.mpLcdTiming0 
		ld bc,8 
		ldir
		ld hl,1023 
		ld (ti.mpLcdTiming2+2),hl
		call spiInit
	end if
	
	ret

_cleanupAsm:
	ld hl,239
	ld (ti.mpLcdTiming2+2),hl
	call spiEnd
	ret 
	
; Timing = (HSW+HFP+HBP+16*(PPL+1)) * (LPP+1+VSW+1+VFP+VBP)
;Timing = (1+1+1+(63+1)*16)*(74+1+1+157)*2*2 = 957164cc approx 50 fps
; change 157 to 119 for closer to 60 fps
lcdTiming: 
	db	63 shl 2 	; PPL 
	db	0 			; HSW
	db	0 			; HFP 
	db	0 			; HBP 
	dw	74 			; LPP & VSW(0) 
	db	0			; VFP
	db	157 		; VBP
	
_backupVRAM: 
	ld a,0 
	call getBuffer
	ld de,_page0Backup
	ld bc,32000 
	ldir 
	ld a,3 
	call getBuffer
	ld de,_page3Backup
	ld bc,32000 
	ldir 
	ret 
	
_loadVRAM: 
	ld a,0 
	call getBuffer
	ex de,hl 
	ld hl,_page0Backup
	ld bc,32000 
	ldir 
	ld a,3 
	call getBuffer
	ex de,hl 
	ld hl,_page3Backup
	ld bc,32000 
	ldir 
	ret 

extern spiInit
extern spiEnd

extern getBuffer
extern _page0Backup
extern _page3Backup

