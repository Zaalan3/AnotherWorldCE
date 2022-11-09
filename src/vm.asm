include 'ti84pceg.inc' 

section .text 

public _initAsm 
public _cleanupAsm


lcdVBP:=ti.mpLcdTiming1+3 

_initAsm: 
	; set bpp = 4
	ld a,(ti.mpLcdCtrl) 
	and a,11110001b ; mask out bpp
	or a,ti.lcdBpp4
	ld (ti.mpLcdCtrl),a  
	ld a,(ti.mpLcdCtrl+1)
	; set vertical back porch to 100 so FPS = 50 
	ld a,100 
	ld (lcdVBP),a 
	
	ret 

_cleanupAsm: 
	ret 



	