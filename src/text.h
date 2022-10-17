#ifndef VMTEXT_H 
#define VMTEXT_H

#include <stdint.h> 

struct StringEntry { 
	uint16_t id; 
	const char * string;
}; 

extern const struct StringEntry stringTable[]; 

extern const uint8_t font[]; 

extern void drawText(uint16_t entry,uint8_t timer);

extern void tickText(); 

#define TEXT_INTRO 0 
#define TEXT_SAVING 0x2FE 
#define TEXT_LOADING 0x2FF 
#define TEXT_SAVEFAILED 0x300
#define TEXT_SAVESUCCESS 0x302
#define TEXT_LOADFAILED 0x301
#define TEXT_LOADSUCCESS 0x303


#endif 

