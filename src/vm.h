#ifndef AWVM_H 
#define AWVM_H 
	
#include <stdint.h>

#define NUMVARS 256 
#define NUMTHREADS 64 
#define SIZEPOLY2 25108
#define SIZEPAL 2048 

extern uint16_t recipTable[1024]; 

extern uint8_t* bytecodePtr; 
extern uint8_t* poly1Ptr; 
extern uint8_t poly2[SIZEPOLY2]; 

extern uint8_t currentPalette;
extern uint8_t palettes[SIZEPAL];

extern uint24_t vmVar[NUMVARS]; 
extern uint24_t threadPC[NUMTHREADS]; 
extern uint8_t threadFlag[NUMTHREADS];
extern uint24_t reqThreadPC[NUMTHREADS]; 
extern uint8_t reqThreadFlag[NUMTHREADS]; 

extern uint8_t* vbuffer1; 
extern uint8_t* vbuffer2; 
extern uint8_t* vbuffer3; 

extern uint8_t currentPart;
 

void initVM(); 
void runVM();
void closeVM(); 

void* getFileDataPtr(uint8_t id);
void loadPart(uint8_t part);  
uint8_t loadResource(uint16_t id);

#endif 

