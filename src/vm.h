#ifndef AWVM_H 
#define AWVM_H 
	
#include <stdint.h>
#include <stdbool.h>

#define NUMVARS 256 
#define NUMTHREADS 64 
#define SIZEPOLY2 25108
#define SIZEPAL 2048 

struct vmData { 
	uint24_t var[NUMVARS]; 
	uint24_t threadPC[NUMTHREADS]; 
	uint8_t threadFlag[NUMTHREADS];
	uint24_t reqThreadPC[NUMTHREADS]; 
	uint8_t reqThreadFlag[NUMTHREADS]; 
}; 

extern uint16_t recipTable[1024]; 
extern uint8_t edgeList[4096];

extern uint8_t* bytecodePtr; 
extern uint8_t* poly1Ptr; 
extern uint8_t* poly2Ptr; 

extern uint8_t currentPalette;
extern uint8_t palettes[SIZEPAL];

extern struct vmData vm; 

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

void savestate(); 
void loadstate(); 

#endif 

