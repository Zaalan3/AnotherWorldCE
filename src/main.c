
#include <stdlib.h> 
#include <stdint.h>
#include <stdbool.h>
#include <string.h> 
 
#include <graphx.h> 
#include <keypadc.h>

#include "vm.h" 
#include "text.h" 

// key associations from A-Z
const kb_lkey_t keytable[] = { 
	kb_KeyMath,kb_KeyApps,kb_KeyPrgm,kb_KeyRecip,kb_KeySin,kb_KeyCos,kb_KeyTan, 
	kb_KeyPower,kb_KeySquare,kb_KeyComma,kb_KeyLParen,
	kb_KeyRParen,kb_KeyDiv,kb_KeyLog,kb_Key7,kb_Key8,
	kb_Key9,kb_KeyMul,kb_KeyLn,kb_Key4,kb_Key5,kb_Key6, 
	kb_KeySub,kb_KeySto,kb_Key1,kb_Key2
}; 
	
void getCharAlpha() {
	uint8_t key = 0;
	for(uint8_t i = 0;i<26;i++) { 
		if(kb_IsDown(keytable[i])) { 
			key = 'A' + i; 
			break;
		}
	}
	vm.var[0xDA] = key; 
} 

void getPlayerInput() { 
		// player input
		uint8_t mask = 0;
		uint8_t action = 0;
		uint16_t lr = 0;
		uint16_t ud = 0;
	
		if (kb_IsDown(kb_KeyRight))
		{
			lr = 1;
			mask |= 1;
		} else if (kb_IsDown(kb_KeyLeft))
		{
			lr = 0xFFFF;
			mask |= 2;
		}

		if (kb_IsDown(kb_KeyDown))
		{
			ud = 1;
			mask |= 4;
		} else if (kb_IsDown(kb_KeyUp) || ((currentPart!=9)&&kb_IsDown(kb_Key2nd)))
		{
			ud = 0xFFFF; 
			mask |= 8;
		} 
		
		
		vm.var[0xE5] = ud;
		vm.var[0xFB] = ud; 
		vm.var[0xFC] = lr;
		vm.var[0xFD] = mask; 
		
		if (kb_IsDown(kb_KeyAlpha)) // alpha = action button 
		{
			action = 1; 
			mask |= 0x80; 
		}
		
		
		vm.var[0xFA] = action; 
		vm.var[0xFE] = mask; 
		
} 

int main(void)
{
	uint8_t textTimer = 60;
	initVM(); 
	drawText(0); // test string / intro primer. 
	kb_SetMode(MODE_3_CONTINUOUS); 
	kb_Scan(); 
	
	while(!kb_IsDown(kb_KeyDel)) { 
		if (textTimer) { 
			if(!(--textTimer)) 
				clearText(); 
		} 
			
	
		if(kb_IsDown(kb_KeyZoom)) 
			loadPart(9);
		
		runVM();
		
		kb_Scan();
		
		if(currentPart==9) // password screen 
			getCharAlpha(); 
		
		getPlayerInput(); 
		
		
	} 	
	
	closeVM(); 
	
	return 0;
}
