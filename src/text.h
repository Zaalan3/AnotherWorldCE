#ifndef VMTEXT_H 
#define VMTEXT_H

#include <stdint.h> 

struct StringEntry { 
	uint16_t id; 
	const char * string;
}; 

extern const struct StringEntry stringTable[]; 

extern const uint8_t font[]; 

extern void drawText(uint16_t entry);

extern void clearText(); 


#endif 

