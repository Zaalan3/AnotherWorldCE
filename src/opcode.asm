section .text

public _executeThread
public blitBuffer

; iy = pc 
; i = var array 
; sps = call stack 

currentScreen:=$E30010
lcdRis:=$E30020 
lcdIcr:=$E30028
lcdPalette:=$E30200

timer1Counter:=$F20000
timer1Reload:=$F20004 
timerControl:=$F20030
gfxFillScreenFastCode:=$E30800	

threadStack:=$0720	; end of textShadow
polygonVars:=$E30A00


macro loadHLVarAddr offset 
	ld c,(iy+offset) 
	ld b,3 
	mlt bc 
	ld hl,i  
	add hl,bc
end macro 


; a = page number
; hl = vram page
getBuffer:  
	ld bc,160*20 ; offset from top border
	cp a,$FE
	jr nz,.compFF 
	ld hl,(_vbuffer2)
	add hl,bc
	ret 
.compFF:
	cp a,$FF 
	jr nz,.getpage 
	ld hl,(_vbuffer3)
	add hl,bc
	ret 
.getpage: 
	ld bc,$D40000 + 160*20
	ld l,a
	ld h,$96 ; page size = $9600 (160*240)
	mlt hl 
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,bc
	ret 

; -------------------------------------------------------

_executeThread: 
	di 
	pop hl
	pop de 
	push hl 
	push hl 
	push ix
	ld iy,(_bytecodePtr)	; iy = thread PC
	add iy,de 
	ld hl,_vmVar
	ld i,hl 	; i = var pointer 
	ld.sis sp,threadStack 	 
fetchOpcode: 	; return point for opcodes
	ld a,(iy+0) 
	cp a,$20
	jr nc,drawOpcode
	ld l,a 
	ld h,3 
	mlt hl 
	ld de,opcodeTable 
	add hl,de 
	ld hl,(hl)
	jp (hl) 
drawOpcode: 
	bit 7,a 
	jq nz,opcode80 
	bit 6,a 
	jq nz,opcode40
	jq killThread
	
opcode80: 
	ld h,a 	; offset encoded in opcode
	ld l,(iy+1) 
	add.sis hl,hl 	; offset = (opcode<<8 + pc[1])*2 
	push hl  		
	ld de,0 
	ld bc,0
	ld c,(iy+3) ; bc = y
	ld a,199	; if y > 199 : x += (y - 199) 
	sub a,c  
	jr nc,.skipXadd
	neg 	
	ld e,a 
	ld c,199 
.skipXadd: 
	or a,a 
	sbc hl,hl 
	ld l,(iy+2) 
	add hl,de 
	pop de 		; de = offset 
	ld ix,(_poly1Ptr)
	ld (_polygonBase),ix
	add ix,de 
	
	; ix = polygon ptr , (iy+0) = color , (+1) = x , (+3) = y , (+5) = zoom
	pea iy+4
	ld iy,polygonVars
	ld (iy+0),$FF 
	ld (iy+1),hl 
	ld (iy+3),bc 
	ld de,256
	ld (iy+5),de 
	; load temporary stack for polygons
	call _drawPolygon
	pop iy
	ld hl,_vmVar
	ld i,hl
	jq fetchOpcode 

opcode40: 
	rla 	; shift out top 2 bits
	rla 
	or a,a
	sbc hl,hl ; offset 
	ld h,(iy+1) 
	ld l,(iy+2)
	add.sis hl,hl
	push hl
	pop ix 
	ld h,0	
	ld l,(iy+3) ; hl = x
	lea iy,iy+4
	; x opcode bits 
	; 11 => x+=256 
	; 10 => no change 
	; 01 => x = var[x] 
	; 00 => x = x<<8 + *pc++ 
.testop1:
	rla 
	jq nc,.testop2
	rla 
	jq nc,.getY
	inc h 	; x += 256
	jq .getY 
.testop2: 
	rla 
	jq nc,.xword
	ld b,l 	; x = var[x] 
	ld c,3 
	mlt bc 
	ld hl,i 
	add hl,bc 
	ld hl,(hl) 
	jq .getY 
.xword: 
	ld h,l 
	ld l,(iy+0) 
	inc iy
	
	; same format for y
.getY: 
	ex de,hl 	; de = x
	or a,a 
	sbc hl,hl 
	ld l,(iy+0)
	inc iy
.testop3: 
	rla 
	jq nc,.testop4 
	rla 
	jr .getzoom
.testop4: 
	rla 
	jq nc,.yword
	ld b,l 	; y = var[y] 
	ld c,3 
	mlt bc 
	ld hl,i 
	add hl,bc 
	ld hl,(hl) 
	jq .getzoom 
.yword: 
	ld h,l 
	ld l,(iy+0) 
	inc iy
	
	; zoom opcode bits: 
	; 11 => zoom = 64 , use poly2ptr 
	; 10 => zoom = *pc++ 
	; 01 => zoom = vars[*pc++] 
	; 00 => zoom = 64 
.getzoom: 
	push hl ; y 
	push de ; x 
	or a,a 
	sbc hl,hl 
	ld l,(iy+0)
	inc iy
	ld de,(_poly1Ptr)
.testop5:
	rla 
	jq nc,.testop6
	rla 
	jq nc,.testend 
	ld de,(_poly2Ptr)
	jq .zoomdefault 
.testop6: 
	rla 
	jq nc,.zoomdefault 
	ld b,l 	; zoom = var[zoom] 
	ld c,3 
	mlt bc 
	ld hl,i 
	add hl,bc 
	ld hl,(hl)
	jq .testend 
.zoomdefault: 
	ld l,64
	dec iy
.testend: 
	ld (_polygonBase),de 
	add ix,de 
	; ix = polygon ptr , (iy+0) = color , (+1) = x , (+3) = y , (+5) = zoom
	pop de ; x 
	pop bc ; y 
	push iy
	ld iy,polygonVars
	ld (iy+0),$FF 
	ld (iy+1),de 
	ld (iy+3),bc 
	add hl,hl  ; 10.8 -> 8.8
	add hl,hl
	ld (iy+5),hl
	call _drawPolygon
	ld hl,_vmVar
	ld i,hl
	pop iy
	jq fetchOpcode
	
; sound opcodes left unimplemented
; -------------------------------------------------------
playSound: 
playMusic: 
	lea iy,iy+6 
	jp fetchOpcode  

; loads part or screen 
; arg1 => file id
loadFile: 
	or a,a 
	sbc hl,hl
	ld h,(iy+1)
	ld l,(iy+2)
	pea iy+3
	push hl
	call _loadResource	; returns 0 if new part loaded
	pop hl
	pop iy
	pop ix 
	or a,a 
	ret z 
	push ix
	jp fetchOpcode
	
; mov and arithmetic
; -------------------------------------------------------
; var[pc[1]] = pc[2]<<8 + pc[3] 
; pc+=4  
movconst: 
	loadHLVarAddr 1 
	ld b,(iy+2) 
	ld c,(iy+3)
	ld (hl),bc 
	lea iy,iy+4 
	jp fetchOpcode 

; var[pc[1]] = var[pc[2]] 
; pc += 3 
movvar: 
	loadHLVarAddr 1 
	ex de,hl
	loadHLVarAddr 2 
	ldi
	ldi 
	lea iy,iy+3 
	jp fetchOpcode 
	
; var[pc[1]] += pc[2]<<8 + pc[3] 
; pc += 4 
addconst: 
	loadHLVarAddr 1 
	ld de,(hl) 
	ex de,hl 
	ld b,(iy+2) 
	ld c,(iy+3) 
	add.sis hl,bc 
	ex de,hl 
	ld (hl),de 
	lea iy,iy+4 
	jp fetchOpcode 
	
; var[pc[1]] += var[pc[2]] 
; pc += 3 
addvar: 
	loadHLVarAddr 1 
	ld de,(hl) 
	push de
	ex de,hl 
	loadHLVarAddr 2 
	ld bc,(hl) 
	pop hl  
	add.sis hl,bc 
	ex de,hl 
	ld (hl),de 
	lea iy,iy+3 
	jp fetchOpcode 

; var[pc[1]] -= var[pc[2]] 
; pc += 3 	
subvar: 
	loadHLVarAddr 1 
	ld de,(hl) 
	push de
	ex de,hl 
	loadHLVarAddr 2 
	ld bc,(hl) 
	pop hl  
	or a,a 
	sbc.sis hl,bc 
	ex de,hl 
	ld (hl),de 
	lea iy,iy+3 
	jp fetchOpcode 
	
; var[pc[1]] &= pc[2]<<8 + pc[3]
; pc += 4 
andconst: 
	loadHLVarAddr 1 
	ld de,(hl) 
	ld a,(iy+3)
	and a,e 
	ld (hl),a 
	inc hl 
	ld a,(iy+2) 
	and a,d 
	ld (hl),a 
	lea iy,iy+4 
	jp fetchOpcode

; var[pc[1]] |= pc[2]<<8 + pc[3]
; pc += 4 
orconst: 
	loadHLVarAddr 1 
	ld de,(hl) 
	ld a,(iy+3)
	or a,e 
	ld (hl),a 
	inc hl 
	ld a,(iy+2) 
	or a,d 
	ld (hl),a 
	lea iy,iy+4 
	jp fetchOpcode
	
; var[pc[1]] <<= pc[2]<<8 + pc[3] 
; pc += 4 
; ( in what world is this value ever greater than a nibble?) 
shl: 
	loadHLVarAddr 1
	ld de,(hl)
	ex de,hl 
	ld b,(iy+3) 
.loop:
	add.sis hl,hl 
	djnz .loop 
	ex de,hl 
	ld (hl),de 
	lea iy,iy+4
	jp fetchOpcode 
	
	
; var[pc[1]] >>= pc[2]<<8 + pc[3] 
; pc += 4 
shr: 
	loadHLVarAddr 1
	ld de,(hl)
	ex de,hl
	ld b,(iy+3)  
.loop:
	srl h 
	rr l
	djnz .loop 
	ex de,hl 
	ld (hl),de 
	lea iy,iy+4
	jp fetchOpcode 	
	

;program control
; -------------------------------------------------------
	
; calls subroutine 
; push(pc - *bytecodePtr + 3) 
; pc = pc[1]<<8 + pc[2] + *bytecodePtr
jsr: 	
	ld de,(_bytecodePtr)
	lea hl,iy+3 
	or a,a 
	sbc hl,de 
	push.sis hl 
	ld h,(iy+1)
	ld l,(iy+2) 
	add hl,de 
	push hl 
	pop iy 
	jp fetchOpcode 
	
;return from subroutine 
; pc = pop() + bytecodePtr 
rfs: 
	ld iy,(_bytecodePtr) 
	pop.sis de 
	add iy,de 
	jp fetchOpcode 
	

; pc = pc[1]<<8 + pc[2] + *bytecodePtr
jump: 
	or a,a 
	sbc hl,hl
	ld h,(iy+1)
	ld l,(iy+2) 
	ld de,(_bytecodePtr)
	add hl,de 
	push hl 
	pop iy
	jp fetchOpcode
	
;  if ( --var[pc[1]] !=0 ) pc = pc[2]<<8 + pc[3] + *bytecodePtr 
;  else pc += 4 
jumpnz: 
	loadHLVarAddr 1 
	ld de,(hl) 
	ex de,hl
	ld bc,1 
	or a,a 
	sbc.sis hl,bc
	ex de,hl 
	ld (hl),de  
	jr Z,.zero 
	ld b,(iy+2)
	ld c,(iy+3)
	ld iy,(_bytecodePtr)
	add iy,bc 
	jp fetchOpcode
.zero: 
	lea iy,iy+4 
	jp fetchOpcode
	
; variable length jump if condition is true 
; arg1 = opcode 
; arg2 = a 
; arg3 = b ( variable based on opcode ) 
; arg4 = offset to jump to
; 6 conditions based on bottom 3 bits of opcode

jumpcond: 
	ld a,(iy+1) 
	loadHLVarAddr 2 
	ld de,(hl)
	lea iy,iy+3
	bit 7,a
	jr Z,.word 
.var:
	ld c,(iy+0) 
	ld b,3 
	mlt bc 
	ld hl,i  
	add hl,bc
	ld hl,(hl)
	inc iy
	jr .skipbyte
.word: 
	bit 6,a 
	jr Z,.byte 
	ld h,(iy+0) 
	ld l,(iy+1) 
	lea iy,iy+2 
	jr .skipbyte
.byte: 
	ld h,0
	ld l,(iy+0) 
	inc iy 
.skipbyte: 
	ld bc,$8000 ; shift into positive range
	add hl,bc
	ex de,hl
	add hl,bc
	or a,a 
	sbc.sis hl,de 	; set flags for a - b 
	push af 
	
	and a,00000111b ; mask bottom 3 bits 
	ld h,3
	ld l,a 
	mlt hl
	ld de,condtable 
	add hl,de
	ld hl,(hl)
	pop af
	jp (hl) ; sub opcode
	
.return:
	lea iy,iy+2 
	jp fetchOpcode 
	
.loadoffset: 
	ld de,0
	ld d,(iy+0) 
	ld e,(iy+1) 
	ld iy,(_bytecodePtr) 
	add iy,de 
	jp fetchOpcode 


beq: 
	jq Z,jumpcond.loadoffset
	jq jumpcond.return
	
bne: 
	jq nz,jumpcond.loadoffset
	jq jumpcond.return
	
bgt: 
	jq Z,jumpcond.return
	jq nc,jumpcond.loadoffset
	jq jumpcond.return	
	
bge: 
	jq nc,jumpcond.loadoffset
	jq jumpcond.return	
	
blt: 
	jq c,jumpcond.loadoffset
	jq jumpcond.return		
	
ble: 
	jq Z,jumpcond.loadoffset
	jq c,jumpcond.loadoffset
	jq jumpcond.return	
	
; flag settings for a - b 
; 0 = a == b  
; 1 = a != b 
; 2 = a > b    
; 3 = a >= b 
; 4 = a < b  
; 5 = a <= b 
; S Z X H X P/V N C
condtable: 
	emit 3: beq
	emit 3: bne
	emit 3: bgt
	emit 3: bge
	emit 3: blt
	emit 3: ble 
	emit 3: jumpcond.return 
	emit 3: jumpcond.return 

;thread management
; -------------------------------------------------------
	
; stop current thread and go to next 
breakThread: 
	lea hl,iy+1	; return pc for thread
	ld de,(_bytecodePtr) 
	or a,a 
	sbc hl,de 
	pop ix
	ret 

; sets thread to inactive ( PC = $FFFFFF ) 
killThread: 
	scf 
	sbc hl,hl 
	pop ix
	ret
	
; reqThreadPC[pc[1]] = pc[2]<<8 + pc[3]
setThreadPC: 
	; fetch thread address 
	ld c,(iy+1) 
	ld b,3 
	mlt bc 
	ld hl,_reqThreadPC  
	add hl,bc
	ex de,hl 
	
	or a,a 
	sbc hl,hl
	ld h,(iy+2)
	ld l,(iy+3) 
	ex de,hl 
	ld (hl),de 
	lea iy,iy+4
	jp fetchOpcode
	
; set reqFlags for threads 
; arg1 = start thread 
; arg2 = end thread
; arg3 = flag 
resetThreads: 
	or a,a 
	sbc hl,hl
	ld l,(iy+1)
	ld a,(iy+2) 
	and a,$3F
	sub a,l ; bc = count 
	ld bc,0 
	ld c,a 
	
	ld a,(iy+3) 
	lea iy,iy+4
	cp a,2
	jr Z,.kill 
	ld de,_reqThreadFlag
	add hl,de 
	push hl 
	pop de 
	inc de 
	ld (hl),a 
	ld a,c 
	or a,a
	jr Z,.skip 
	ldir 
.skip:
	jp fetchOpcode

.kill: 
	ld a,c
	ld h,3 
	ld b,h 
	mlt hl 
	mlt bc
	ld de,_reqThreadPC 
	add hl,de
	ld de,$00FFFE 
	ld (hl),de 
	or a,a 
	jr Z,.skip
	push hl 
	pop de 
	inc de
	inc de
	inc de
	ldir 
	jp fetchOpcode
	
; graphics related opcodes 
; -------------------------------------------------------

; arg1 = 16 bit string id
; arg2 = x/8
; arg3 = y
; arg4 = color
drawText: 
	ld hl,(_vbuffer1) 
	ld d,4
	ld e,(iy+3) 
	mlt de
	add hl,de 
	ld e,(iy+4)
	ld d,160 
	mlt de 
	add hl,de 
	ex de,hl 
	ld h,(iy+1) 
	ld l,(iy+2)
	ld a,(iy+5) 
	call _drawString 
	lea iy,iy+6 
	jp fetchOpcode 
	
; arg1 = palette to set to 
; arg2 = n/a 
setPalette: 
	ld a,(iy+1) 
	ld (_currentPalette),a 
	lea iy,iy+3
	jp fetchOpcode
	
; set vbuffer1 
; arg1 = vram page (0 - 3)
setBuffer: 
	ld a,(iy+1)
	call getBuffer 
	ld (_vbuffer1),hl 
	lea iy,iy+2 
	jp fetchOpcode 
	

; fill buffer with color 
; arg1 = buffer 
; arg2 = color 
fillBuffer: 
	ld a,(iy+1) 
	call getBuffer 
	ld de,160*199; bottom of screen
	add hl,de
	ld ix,0 
	add ix,sp 
	ld sp,hl
	ld a,(iy+2) 
	lea iy,iy+3
	ld c,a	; build color mask
	rlca
	rlca
	rlca
	rlca
	or a,c 
	ld h,a 
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld h,a 
	ld l,a
	ex de,hl
	ld b,92
	call gfxFillScreenFastCode
	; write 100 more bytes
	or a,a 
	sbc hl,hl 
	add hl,sp
	ex de,hl 
	ld sp,ix 
	ld bc,100
	push de 
	pop hl 
	dec de
	lddr
	jp fetchOpcode
	
; copies from src buffer arg1 to dst buffer arg2 with optional scrolling
copyBuffer: 
	ld a,(iy+1) 
	cp a,$FE
	jq nc,.noscroll 
	and a,$BF	
	bit 7,a 
	jq Z,.noscroll
.scroll: 
	and a,3 
	call getBuffer
	push hl 	; src 
	ld a,(iy+2) 
	call getBuffer
	push hl 	; dst
	pop ix
	; var[249] is scroll variable
	ld bc,(_vmVar + 249*3) ; bc = scroll
	ld hl,-199 
	or a,a 
	sbc hl,bc ; return if scroll<=-199 or scroll>=199 
	bit 7,h 
	jq Z,.return 
	ld hl,198 
	or a,a 
	sbc hl,bc 
	bit 7,h 
	jq nz,.return
	or a,a 
	sbc hl,bc 
	ld hl,199
	bit 7,b ; if scroll<0
	jr nz,.scrollneg
.scrollpos:	; dst += 160*scroll , len = 160*(200-scroll)
	or a,a 
	sbc hl,bc 
	ld h,160
	ld b,h 
	mlt hl 
	mlt bc ; bc = 160*scroll
	ex de,hl ; de = 160*(200-scroll)
	lea hl,ix+0 ; hl = dst 
	add hl,bc ; dst+= 
	push hl 
	push de 
	pop bc ; bc = len 
	pop de ; de = dst 
	pop hl ; hl = src
	jq .copy
.scrollneg: ; src += 160*-scroll , len = 160*(200+scroll)
	add hl,bc
	ld h,160
	mlt hl 
	ex de,hl ; de =  160*(200+scroll)
	or a,a 
	sbc hl,hl 
	sbc hl,bc 
	ld h,160 
	mlt hl ; hl = 160*-scroll
	pop bc  
	add hl,bc ; src+= 
	push de 
	pop bc 
	lea de,ix+0
	jq .copy
.noscroll:
	call getBuffer
	ld a,(iy+2) 
	ex de,hl
	call getBuffer
	ex de,hl 
	ld bc,160*199
.copy: 
	ldir
.cret:
	lea iy,iy+3
	jp fetchOpcode
.return:
	pop hl 
	jr .cret
	
; arg1 = buffer to blit
blitBuffer: 
	ld a,(iy+1) 
	or a,a 
	sbc hl,hl 
	ld (_vmVar + 247*3),hl ; this variable gets reset every blit for some reason 
	cp a,$FE 
	jr Z,.setScreen
	cp a,$FF
	jr nz,.getPage 
.swap:
	ld hl,(_vbuffer2) 
	ld de,(_vbuffer3) 
	ld (_vbuffer3),hl 
	ld (_vbuffer2),de
	jq .setScreen 
.getPage: 
	ld bc,$D40000
	ld l,a
	ld h,$96 ; page size = $9600 (160*240)
	mlt hl 
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,bc
	ld (_vbuffer2),hl
.setScreen: 
	call waitTimer
	call waitVComp
	ld hl,(_vbuffer2) 
	ld (currentScreen),hl
.copyPalette: 
	ld a,(_currentPalette)
	ld d,a 
	ld e,32
	mlt de 
	ld hl,_palettes
	add hl,de 
	ld de,lcdPalette
	ld bc,32 
	ldir
	
	;wait [0xFF] frames 
	ld a,(_vmVar + 255*3)
	ld h,a ; timer counter = 163*4*([0xFF])
	ld l,163 
	mlt hl 
	add hl,hl
	add hl,hl
	ex de,hl 
	ld hl,timerControl
	res 0,(hl)
	ld (timer1Counter),de
	set 0,(hl) 
	
.skipwait: 
	lea iy,iy+2 
	jp fetchOpcode
	
waitVComp:
	ld a,1000b 
	ld (lcdIcr),a
.loop: 	; wait until front porch to swap palette
	ld a,(lcdRis)
	bit 3,a 
	jr Z,.loop 
	ret 
	
waitTimer:
	or a,a 
	sbc hl,hl 
	ex de,hl 
.loop: 
	ld hl,(timer1Counter)
	sbc hl,de 
	jr nz,.loop
	ret 
	
	
opcodeTable: 
	emit 3: movconst	; 0x00 
	emit 3: movvar 
	emit 3: addvar
	emit 3: addconst 
	emit 3: jsr 		; 0x04 
	emit 3: rfs 
	emit 3: breakThread
	emit 3: jump 
	emit 3: setThreadPC ; 0x08 
	emit 3: jumpnz 
	emit 3: jumpcond
	emit 3: setPalette
	emit 3: resetThreads ; 0x0C 
	emit 3: setBuffer 
	emit 3: fillBuffer
	emit 3: copyBuffer
	emit 3: blitBuffer	; 0x10 
	emit 3: killThread 
	emit 3: drawText
	emit 3: subvar 
	emit 3: andconst	; 0x14 
	emit 3: orconst
	emit 3: shl
	emit 3: shr  
	emit 3: playSound 	; 0x18 
	emit 3: loadFile
	emit 3: playMusic ;0x1A
	

extern _bytecodePtr
extern _poly1Ptr
extern _poly2Ptr

extern _currentPalette
extern _palettes

extern _vmVar
extern _reqThreadPC
extern _reqThreadFlag

extern _vbuffer1 
extern _vbuffer2
extern _vbuffer3

extern _drawPolygon
extern _polygonBase 

extern _drawString
extern _loadResource

extern polyHierarchy
extern polyHierarchy.loop
extern fill
extern fill.yloop 
extern fill.find0 

extern drawColor
extern drawColor.blitline
extern drawMask
extern drawCopy


