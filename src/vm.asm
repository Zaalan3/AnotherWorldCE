include 'ti84pceg.inc' 

section .text 

public _initAsm 
public _cleanupAsm

lcdVBackPorch:=ti.mpLcdTiming1+3
lcdVFrontPorch:=ti.mpLcdTiming1+2

; TODO: configure DMA and porch timing for VSYNC interface: 
; 	*	DMA needs to be slower than SPI refresh 
;	*   need long SPI back porch for data transfer 
;	*	target FPS = 50 
_initAsm: 
	; set bpp = 4
	ld a,(ti.mpLcdCtrl) 
	and a,11110001b ; mask out bpp
	or a,ti.lcdBpp4
	ld (ti.mpLcdCtrl),a  
	ld a,(ti.mpLcdCtrl+1)
	; set LCD timing 
	ld a,255
	ld (lcdVBackPorch),a
	ld a,24
	ld (lcdVFrontPorch),a
	jp spiInit 

_cleanupAsm: 
	jp spiEnd

extern spiInit
extern spiEnd
