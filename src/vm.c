
#include <stdlib.h> 
#include <stdint.h>
#include <stdbool.h>
#include <string.h> 
 
#include <tice.h> 
#include <compression.h>
#include <fileioc.h> 
#include <graphx.h> 

#include <debug.h>

#include "vm.h" 
#include "text.h"

extern uint24_t compressPage(uint8_t page); 
extern void decompressVRAM(void *compressed); 

void initAsm(); 
void cleanupAsm();
uint24_t executeThread(uint24_t pc);

uint16_t recipTable[1024];
uint8_t edgeList[1440];

uint8_t* bytecodePtr; 
uint8_t* poly1Ptr; 
uint8_t* poly2Ptr; 

uint8_t currentPalette;
uint8_t palettes[SIZEPAL];

struct vmData vm; 
struct vmData vmBackup; 
uint8_t palBackup;
uint8_t vramBackup[160*200];

bool validSave;

uint8_t* vbuffer1; 
uint8_t* vbuffer2; 
uint8_t* vbuffer3; 

bool loadedNewPart;
uint8_t currentPart; 



static const uint8_t fileTypes[] = { 
	0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, //0x00
	0, 6, 2, 2, 3, 4, 5, 3, 4, 5, 3, 4, 5, 3, 4, 5, //0x10
	3, 4, 5, 3, 4, 5, 3, 4, 5, 3, 4, 5, 0, 0, 0, 0, //0x20 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //0x30 
	0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, //0x40 
	0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //0x50 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //0x60 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4, 5, //0x70 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, //0x80 
	2, 2 	}; 
	

static const uint16_t parts[10][3] = {
//MEMLIST_PART_PALETTE   MEMLIST_PART_CODE   MEMLIST_PART_VIDEO1
	{ 0x14,                    0x15,                0x16}, // protection screens
	{ 0x17,                    0x18,                0x19}, // introduction cinematic
	{ 0x1A,                    0x1B,                0x1C},
	{ 0x1D,                    0x1E,                0x1F},
	{ 0x20,                    0x21,                0x22},
	{ 0x23,                    0x24,                0x25}, // battlechar cinematic
	{ 0x26,                    0x27,                0x28},
	{ 0x29,                    0x2A,                0x2B},
	{ 0x7D,                    0x7E,                0x7F},
	{ 0x7D,                    0x7E,                0x7F}  // password screen
};
	
	
void* getFileDataPtr(uint8_t id) { 
	static char filename[] = "AWaa";	// all files in this format
	ti_var_t f; 
	void* dataPtr = NULL;
	uint8_t charh = (id>>4)&0x0F; 
	uint8_t charl = id&0x0F; 
	filename[2] = charh >= 0x0A ? 'A' + (charh - 0x0A) : '0' + charh; 
	filename[3] = charl >= 0x0A ? 'A' + (charl - 0x0A) : '0' + charl; 
	
	if((f = ti_Open(filename,"r"))) { 
		dataPtr = ti_GetDataPtr(f); 
		ti_Close(f); 
	} else { 
		closeVM();
		os_ClrHomeFull();
		strcpy(os_AppErr1,"FileNotFound: ");
		strcat(os_AppErr1,filename);
		os_ThrowError(OS_E_APPERR1); 
	} 
	
	return dataPtr;
} 

void initVM() {
	gfx_Begin(); 
	gfx_ZeroScreen(); // loads fast clear to cursorImage(0xE30800) 
	gfx_SwapDraw(); 
	gfx_ZeroScreen();
	initAsm(); // init 4bpp and LCD timing
	
	timer_Disable(1);
	timer_SetReload(1, 0);
	timer_Set(1,0);
	timer_Enable(1,TIMER_32K,TIMER_NOINT,TIMER_DOWN); 
	
	vbuffer1 = ((uint8_t*)(0xD40000 + 160*240*2 + 160*20));
	vbuffer2 = ((uint8_t*)(0xD40000 + 160*240*2));
	vbuffer3 = ((uint8_t*)(0xD40000 + 160*240*1));
	
	recipTable[0] = 65535;
	for( uint24_t i = 1; i<1024; i++)
		recipTable[i] = 65536/(i+1); 
	
	memset(vm.var,0,sizeof(vm.var)); 
	currentPart = 0;
	poly2Ptr = getFileDataPtr(0x11); // animation file
	
	srandom(rtc_Time()); 
	vm.var[0x3C] = random();
	vm.var[0x54] = 0x81; 
	
	vm.var[0xBC] = 0x10;
	vm.var[0xC6] = 0x80;
	vm.var[0xF2] = 4000;
	vm.var[0xDC] = 33;
	
	currentPalette = 1;
	loadPart(1); 
} 

void runVM() { 
	loadedNewPart = false; 
	memcpy(vm.threadFlag,vm.reqThreadFlag,sizeof(vm.threadFlag)); 
	
	tickText();
	for(uint8_t i = 0;i<NUMTHREADS;i++) { 
		if(vm.reqThreadPC[i] != 0xFFFFFF) { 
			if(vm.reqThreadPC[i]==0xFFFE)
				vm.threadPC[i] = 0xFFFFFF;
			else 
				vm.threadPC[i] = vm.reqThreadPC[i]; 
			
			vm.reqThreadPC[i] = 0xFFFFFF; 
		} 
	}
	
	for(uint8_t i = 0;i<NUMTHREADS;i++) { 
		if(vm.threadFlag[i]) continue; 
		if((vm.threadPC[i] != 0xFFFFFF)) { 
			uint24_t newpc = executeThread(vm.threadPC[i]); 
			if (loadedNewPart) break; 
			vm.threadPC[i] = newpc; 
		} 
	} 
	
} 

void closeVM() { 
	cleanupAsm(); 
	gfx_End(); 
} 
	
// loads a file or part
uint8_t loadResource(uint16_t id) { 
	if (id >= 16000)  { 
		loadPart(id - 16000); 
		return 0; 
	} 
	else if (fileTypes[id] == 2) 
	{ 
		// decompress image into vram 
		void* ptr = getFileDataPtr(id);
		zx7_Decompress((void *)(0xD40C80),ptr);
	} 
	
	return 1; 
} 

void loadPart(uint8_t part) { 
	loadedNewPart = true; 
	validSave = false; 
	
	zx7_Decompress(palettes,getFileDataPtr(parts[part][0])); 
	
	bytecodePtr = (uint8_t*)getFileDataPtr(parts[part][1]);
	poly1Ptr = (uint8_t*)getFileDataPtr(parts[part][2]);
	 
	vm.var[0] = currentPart; 
	currentPart = part;
	vm.var[0xE4] = 0x14;

	// reset thread information
	memset(vm.threadFlag,0,sizeof(vm.threadFlag));
	memset(vm.threadPC,0xFF,sizeof(vm.threadPC));
	memset(vm.reqThreadFlag,0,sizeof(vm.reqThreadFlag));
	memset(vm.reqThreadPC,0xFF,sizeof(vm.reqThreadPC));
	
	vm.threadPC[0] = 0; 
} 


void savestate(void) {
	void *freeptr;
	uint24_t freesize = os_MemChk(&freeptr);
	uint24_t total = 0; 
	dbg_printf("%d bytes free\n",freesize); 
	
	vmBackup = vm; 
	palBackup = currentPalette;
	
	drawText(TEXT_SAVING,60);
	for(uint8_t i = 0; i < 4; i++) { 
		uint24_t length = compressPage(i); 
		if(length > freesize) { 
			validSave = false;
			drawText(TEXT_SAVEFAILED,60); 
			return; 
		} 
		
		total += length; 
		dbg_printf("Buffer %d : %d bytes\n",i,length); 
		
		if(i != 3) { 
			memcpy(freeptr,&vramBackup,length); 
			freeptr += length; 
			freesize -= length;
		}
		
	} 
	
	//double ratio = total * (100.0 / (160.0*200.0*4.0)); 
	//dbg_printf("Compression Ratio: %.2f%%\n",ratio);
	drawText(TEXT_SAVESUCCESS,60); // savestate successful text 
	validSave = true; 
} 

void loadstate(void) {
	void *freeptr; 
	if(validSave) { 
		vm = vmBackup; 
		currentPalette = palBackup; 
		os_MemChk(&freeptr);
		decompressVRAM(freeptr); 
		
		drawText(TEXT_LOADSUCCESS,60); 
		return; 
	} 
	
	drawText(TEXT_LOADFAILED,60);
}
