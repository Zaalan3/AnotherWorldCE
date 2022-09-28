section .text 

public _initAsm 
public _cleanupAsm
public spiCmd 
public spiParam 

extern _palettes
lcdControl:=$E30018
lcdVBP:=$E30007

_initAsm: 
	; set bpp = 4
	ld a,(lcdControl) 
	and a,11110001b ; mask out bpp
	or a,0100b ; 4bpp 
	ld (lcdControl),a  
	
	; set vertical back porch to 100 so FPS = 50 
	ld a,100 
	ld (lcdVBP),a 
	
	ret 
	
_cleanupAsm: 
	ret 
	


	