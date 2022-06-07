section .text 

public _drawPolygon 
public _polygonBase 

; debug labels
public polyHierarchy
public polyHierarchy.loop
public fill
public fill.yloop 
public fill.find0
public drawColor
public drawColor.blitline
public drawMask
public drawCopy

extern _vbuffer1 
extern _vbuffer2
extern _vbuffer3

extern _recipTable

color equ iy+0 
x equ iy+1 
y equ iy+3 
zoom equ iy+5
yend equ iy+7 

colorn equ iy+0+8
xn equ iy+1+8
yn equ iy+3+8 
zoomn equ iy+5+8

vertStack:=$D052C0 	; end of pixelShadow
edgeList:=$D03200  ; start of pixelShadow

;TODO: flat line special cases 
;TODO: fix visual glitches(draw pixel not working correctly?)
;TODO: do start and end drawpixel calls

; (zoom) * a >> 8 
mulZoom:  
	ld hl,(zoom)
	ld d,l 
	ld e,a 
	ld l,a 
	mlt hl 
	mlt de 
	ld e,d 
	ld d,0 
	add hl,de 
	ret 
	
; ----------------------------------------------	
;input: 
; ix = polygon ptr 
; (iy+0) = color , (+1) = x , (+3) = y , (+5) = zoom
_drawPolygon:
	ld a,(ix+0)  ; type byte
	cp a,$C0 
	jq c,polyHierarchy
	bit 7,(color)  
	jr Z,.fetchVerts
	and a,$3F 
	ld (color),a 
.fetchVerts: 
	ld hl,(ix+1)  ; if bbw = 0,bbh = 1, and #verts = 4
	ld de,$040100 ; draw a point
	or a,a 
	sbc hl,de 
	jq Z,drawPoint
.copyVerts: 
	add hl,de 
	ld a,h	  
	ex af,af' 
	ld a,l 	; a = bounding box x
	call mulZoom 
	srl h 
	rr l	; x -= (bbw*zoom)/2 
	ex de,hl
	ld hl,(x)
	or a,a 
	sbc hl,de 
	ld (x),l 
	ld (x+1),h 
	ld bc,320
	or a,a 
	sbc hl,bc 
	bit 7,h 
	ret Z
	add hl,bc
	add hl,de ; skip if x + bbw < 0 
	add hl,de
	bit 7,h 
	ret nz 
	

	ex af,af' ; a = bounding box y 
	call mulZoom 
	srl h 
	rr l 	
	ex de,hl  
	ld hl,(y) 
	or a,a 
	sbc hl,de
	ld (y),l 
	ld (y+1),h 
	ld bc,199 
	or a,a 
	sbc hl,bc
	bit 7,h
	ret Z 
	add hl,bc
	add hl,de ; y + ylen < 0 
	add hl,de
	ld (yend),hl
	bit 7,h 
	ret nz 
	
	or a,a 	; store sp 
	sbc hl,hl 
	add hl,sp 
	ld b,(ix+3) ; a = num verts 
	exx 
	ld sp,vertStack  
	lea bc,ix+4 ; start of verts
	exx
.vertloop: 
	exx
	ld a,(bc) ; fetch x 
	inc bc
	call mulZoom
	ld de,(x) 
	add.sis hl,de 
	push hl ; push x on stack 
	ld a,(bc)
	inc bc
	call mulZoom 
	ld de,(y) 
	add.sis hl,de 
	push hl ; push y on stack 
	exx
	djnz .vertloop
	exx 
.scanconvert: 
	or a,a 
	sbc hl,hl 
	add hl,sp 
	exx 
	ld sp,hl	; restore sp 
	exx 
	
	xor a,a 
	ld (SMCedge),a 
	ld a,(ix+3) ; for each edge count = (numVerts/2) - 1 
	or a,a 
	rra 
	dec a 
	push af 
	ex af,af' 
	pop af
	push hl 
	pop ix ; ix = vert pointer 
	call fill  ; fill edge buffer 
	lea ix,ix+6
	ld a,3
	ld (SMCedge),a
	ex af,af'
	call fill
.draw: 
	ld de,(yend) 
	ld hl,199 
	or a,a 
	sbc hl,de 
	bit 7,h 
	jr Z,.skipyendclip 
	ld e,199 
.skipyendclip: 
	ld a,e 
	ld hl,199
	ld de,(y)
	or a,a 
	sbc hl,de 
	bit 7,h 
	ret nz
	bit 7,d 
	jr Z,.skipyclip
	ld e,0
.skipyclip:
	sub a,e 
	ret c
	jr nz,$+3
	inc a 
	ld b,a
	ld a,(color)
	ld iy,edgeList
	ld c,e
	ld d,6 
	mlt de 
	add iy,de
	ld e,c
	cp a,16
	jp Z,drawMask
	cp a,17
	jp nc,drawCopy
	jp drawColor 
	
	
; ----------------------------------------------
; mesh type data structure. child poly's can be other hierarchies
polyHierarchy: 
	and a,$3F 
	cp a,2 
	ret nz
	ld a,(ix+1) ; x -= bbw*zoom
	call mulZoom 
	ex de,hl 
	ld hl,(x)
	or a,a 
	sbc hl,de 
	ld (x),l 
	ld (x+1),h 
	ld a,(ix+2) ; y -= bbw h*zoom 
	call mulZoom 
	ex de,hl
	ld hl,(y) 
	or a,a 
	sbc hl,de 
	ld (y),l
	ld (y+1),h
	ld b,(ix+3) ; b = num polygons 
	inc b 
	lea ix,ix+4
.loop:
	ld a,(ix+2) 
	call mulZoom 
	ld de,(x) 
	add hl,de 
	ld (xn),hl 
	ld a,(ix+3)
	call mulZoom 
	ld de,(y) 
	add hl,de 
	ld (yn),hl 
	ld hl,(zoom) 
	ld (zoomn),hl 
	ld a,$FF
	ld h,(ix+0) ; offset 
	ld l,(ix+1) 
	bit 7,h 
	jr Z,.recurse 
	ld a,(ix+4) 
	and a,$7F 
	lea ix,ix+2
.recurse: 
	lea ix,ix+4 
	ld (colorn),a 
	add.sis hl,hl
	ex de,hl 
	push ix 
	push iy 
	push bc 
	ld ix,(_polygonBase) 
	add ix,de
	lea iy,iy+8  ; data for polygon 
	call _drawPolygon
	pop bc 
	pop iy 
	pop ix 
	djnz .loop 
	ret 
	
; ----------------------------------------------	
	
x0 equ ix+9 
y0 equ ix+6
x1 equ ix+3 
y1 equ ix+0
xlast equ ix-3 
ylast equ ix-6
; ix = vert list ptr, a = num edges
; fills edge buffer (iy+0 = left, iy+3 = right)
; ix = ptr to points, b = numEdges
fill:  
	push iy
.start:
	push af
	; store x0 and y0
	lea de,ylast
	lea hl,y0 
	ld bc,6 
	ldir 
	
.dy:	
	ld hl,(y1)
	ld de,(ylast) 
	or a,a
	sbc.sis hl,de
	jq Z,.next 	; dy=0
	jq p,.getRecip
	ex de,hl  
	or a,a 
	sbc hl,hl 
	sbc.sis hl,de   ; hl = abs(dy)
	ld de,(x1)  ; swap p0 and p1 to preserve positive y direction
	ld bc,(xlast) 
	ld (xlast),de 
	ld (x1),bc 
	ld de,(y1) 
	ld bc,(ylast) 
	ld (ylast),de 
	ld (y1),bc 
	
.getRecip: 
	ex de,hl 
	ld hl,_recipTable-2 ; entry for 1 at index 0 
	add hl,de
	add hl,de
	ld hl,(hl)
	ex de,hl
.dx: 
	ld hl,(x1) 
	ld bc,(xlast) 
	or a,a 
	sbc hl,bc
	jq nz,.mult 
	ld iy,0 
	jr .skipMult
.mult:
	ld b,h ; bc = dx
	ld c,l
	; dx * 1/dy
	; iy = de*bc 16.8
	ld h,d 
	ld l,b 
	mlt hl 
	bit 7,b 
	jr Z,$+5 
	or a,a
	sbc hl,de 
	push hl ; iy = hl<<8  
	dec sp 
	pop iy 
	inc sp 
	ld iyl,0 
	ld h,e 
	ld l,c 
	mlt hl
	ld a,h 
	or a,a 
	sbc hl,hl 
	ld l,a 
	ld a,b 
	ld b,d  
	ld d,a 
	mlt de 
	mlt bc 
	add hl,de 
	add hl,bc 
	ex de,hl 
	add iy,de 
.skipMult: 
	lea de,iy+0
	ld hl,(xlast-1) ; hl = x0*256
	ld l,0
	exx 
	ld bc,(ylast) 
	ld hl,200 
	or a,a 
	sbc.sis hl,bc  
	jq m,.next
	or a,a 
	sbc hl,hl 
	sbc.sis hl,bc 
	jq m,.clipY1 	; find line intersection with 0 if y0 < 0	
	jq Z,.clipY1
.find0: 
	ld a,l 
	or a,a 
	sbc hl,hl
	lea de,iy+0
	ld b,8
	; hl = (dx/dy)*abs(y0)
	; assumes abs(y0) 8 bits or less 
.mulloop: 
	add hl,hl 
	rla 
	jr nc,$+3 
	add hl,de 
	djnz .mulloop
	push hl 
	exx 
	pop bc 
	add hl,bc 
	exx 
	ld c,0
.clipY1: 
	ld de,(y1)	; go to next if y1 < 0
	bit 7,d 
	jr nz,.next
	ld hl,200  
	or a,a 
	sbc.sis hl,de 
	jp p,.noclip 
	ld e,199
.noclip: 
	ld a,e 	; a = y1 
.ycounter: 
	sub a,c	; a = y counter
	inc a
.getEdge: 
	ld b,6
	mlt bc 
	ld iy,edgeList ; iy = edge pointer 
	add iy,bc
	exx 
	ld b,a
.yloop: 
	ld (iy+0),hl
SMCedge:=$-1
	lea iy,iy+6
	add hl,de
	djnz .yloop 
.next:
	lea ix,ix+6 
	pop af 
	dec a
	jq nz,.start
	pop iy
	ret 
	

	
; ----------------------------------------------

drawPoint:
	ld hl,(x) ; get pixel address
	bit 7,h 
	ret nz
	srl h 
	rr l 
	rl b
	ld d,(y) 
	bit 7,d 
	ret nz 
	ld e,160	
	mlt de
	add.sis hl,de 
	ex de,hl
	ld a,(color)
	ld hl,(_vbuffer1) 
	add hl,de
	cp a,16 
	jq Z,pointblend 
	cp a,17
	jq Z,pointcopy
	
	
pointcolor:
	rr b 
	jr nc,.even 
.odd: 
	ld b,a 
	ld a,(hl) 
	and a,$F0 
	or a,b 
	ld (hl),a 
	ret 
.even: 
	rlca 
	rlca 
	rlca 
	rlca 
	ld b,a 
	ld a,(hl) 
	and a,$0F 
	or a,b 
	ld (hl),a 
	ret 

pointblend:
	rr b 
	jr nc,.even 
.odd: 
	ld a,(hl)
	or a,00001000b 
	ld (hl),a 
	ret 
.even: 
	ld a,(hl) 
	or a,10000000b
	ld (hl),a 
	ret 
	
pointcopy:
	rr b 
	jr nc,.even 
.odd: 
	ex de,hl 
	ld bc,$D40000 + 160*20
	add hl,de
	ld a,(hl)
	and a,$0F
	ld h,a 
	ld a,(de) 
	and a,$F0 
	or a,h 
	ld (de),a 
	ret 
.even: 
	ex de,hl 
	ld bc,$D40000 + 160*20
	add hl,de
	ld a,(hl)
	and a,$F0
	ld h,a 
	ld a,(de) 
	and a,$0F 
	or a,h 
	ld (de),a 
	ret 


; a = color 
; e = y start 
; b = y length 
; iy = scan edges  
drawColor:
	ld ix,(_vbuffer1) ; ix screen offset
	ld d,160 	
	mlt de 
	add ix,de 
	ld de,160
	exx 
	ld bc,0
	ld l,a ; get color mask
	rlca 
	rlca 
	rlca 
	rlca 
	or a,l
	ld i,a
	exx 
.loop: 
	exx
.clipend:	
	ld a,(iy+2)
	and a,(iy+5) 
	rla 
	jq c,.skipblit
	ld hl,(iy+4) ; x end
	bit 7,h 
	jr nz,.skipblit
	ld de,319
	sbc.sis hl,de 
	jp m,.clipstart
	or a,a 
	sbc hl,hl
	ex de,hl 
.clipstart: 
	add hl,de
	srl h
	rr l
.testlt: 
	ld de,(iy+1) ; x start 
	bit 7,d
	jr Z,.blitline 
	ld de,0  
.blitline:
	srl d 
	rr e
	or a,a 
	sbc.sis hl,de
	ld a,l
	jq Z,.point
	jq p,.noswap
	add hl,de
	ex de,hl
	neg 
.noswap: 
	ld c,a
	add a,e
	cp a,160  
	jr c,.getoffset
	ld a,159 
	sub a,e 
	jq Z,.point
	ld c,a 
.getoffset:
	ex.sis de,hl
	
	lea de,ix+0 ; get first pixel  
	add hl,de 
	push hl 
	pop de 
	inc de 
	ld a,i
	ld (hl),a 
	ldir
.skipblit:
	lea iy,iy+6
	exx 
	add ix,de
	djnz .loop 
	ret 
.point:
	ex.sis hl,de
	lea de,ix+0 ; get first pixel  
	add hl,de
	ld a,i
	ld (hl),a 
	jr .skipblit
	
	

drawMask:
	ld ix,(_vbuffer1) ; ix screen offset
	ld d,160 	
	mlt de 
	add ix,de 
	ld de,160
	exx 
	ld bc,10001000b
	exx 
.loop:
	exx
.clipend:	
	ld hl,(iy+4) ; x end
	bit 7,h 
	jr nz,.skipblit
	ld de,319
	sbc.sis hl,de 
	jp m,.clipstart
	or a,a 
	sbc hl,hl
	ex de,hl 
.clipstart: 
	add hl,de
	srl h
	rr l
	ld de,(iy+1) ; x start 
	bit 7,d
	jr Z,.blitline 
	ld de,0  
.blitline:
	srl d 
	rr e
	or a,a 
	sbc.sis hl,de
	ld a,l 
	jq Z,.point
	jq p,.noswap
	add hl,de
	ex de,hl
	neg 
.noswap: 
	ld b,a 
	ex.sis hl,de
	lea de,ix+0 ; get first pixel  
	add hl,de 
	ld a,(hl) 
	or a,c
	ld (hl),a 
	inc hl
.bloop: 
	ld a,(hl) 
	or a,c
	ld (hl),a 
	inc hl
	djnz .bloop 
.skipblit:
	lea iy,iy+6
	exx 
	add ix,de
	djnz .loop 
	ret 
.point: 
	ex.sis hl,de
	lea hl,ix+0 ; get first pixel  
	add hl,de
	ld a,(hl) 
	or a,c
	ld (hl),a 
	jr .skipblit
	
	
drawCopy:
	ld ix,0 ; ix screen offset
	ld d,160 	
	mlt de 
	add ix,de 
	ld de,160
	exx 
	ld bc,0
	exx 
.loop:
	exx
.clipend:	
	ld hl,(iy+4) ; x end
	bit 7,h 
	jr nz,.skipblit
	ld de,319
	sbc.sis hl,de 
	jp m,.clipstart
	or a,a 
	sbc hl,hl
	ex de,hl 
.clipstart: 
	add hl,de
	srl h
	rr l
	ld de,(iy+1) ; x start 
	bit 7,d
	jr Z,.blitline 
	ld de,0  
.blitline:
	srl d 
	rr e
	or a,a 
	sbc.sis hl,de
	ld a,l 
	jq Z,.point
	jq p,.noswap
	add hl,de
	ex de,hl
	neg 
.noswap: 
	ld c,a 
	ex.sis hl,de
	lea de,ix+0 ; get first pixel  
	add hl,de 
	ex de,hl 
	ld hl,(_vbuffer1) 
	add hl,de 
	push hl 
	ld hl,$D40000 + 160*20 
	add hl,de 
	pop de 
.bloop: 
	ldir
.skipblit:
	lea iy,iy+6
	exx 
	add ix,de
	djnz .loop 
	ret 
.point: 
	ex.sis hl,de
	lea hl,ix+0 ; get first pixel  
	add hl,de 
	ex de,hl 
	ld hl,(_vbuffer1) 
	add hl,de
	add hl,de 
	ld a,(hl) 
	ld hl,$D40000 + 160*20
	add hl,de 
	ld (hl),a 
	jr .skipblit 
	
_polygonBase: 
	emit 3: 0 	


	
	