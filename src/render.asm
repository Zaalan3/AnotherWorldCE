section .text 

public drawPoint
public drawColor
public drawMask
public drawCopy

extern _vbuffer1 
extern _vbuffer2
extern _vbuffer3

color equ iy+0 
x equ iy+1 
y equ iy+3 
zoom equ iy+5
yend equ iy+7 
	
; ----------------------------------------------

drawPoint:
	ld hl,(x) ; get pixel address
	bit 7,h 
	ret nz
	srl h 
	rr l 
	rl b
	ld de,160 
	or a,a 
	sbc.sis hl,de 
	ret nc
	add hl,de 
	ld a,(y) 
	bit 7,a  
	ret nz 	
	cp a,199
	ret nc 
	ld d,a
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
	
; a = color 
; b = even(0)/odd(1)
; hl = screen pointer
pointcolor:
	rr b 
	jr nc,.even 
.odd: 
	rlca 
	rlca 
	rlca 
	rlca 
	ld c,a 
	ld a,(hl) 
	and a,$0F 
	or a,c 
	ld (hl),a 
	ret 
.even: 
	ld c,a 
	ld a,(hl) 
	and a,$F0
	or a,c 
	ld (hl),a 
	ret 

pointblend:
	rr b 
	jr nc,.even 
.odd: 
	set 7,(hl) 
	ret 
.even: 
	set 3,(hl)
	ret 
	
pointcopy:
	rr b 
	jr nc,.even
.odd: 
	ex de,hl 
	add hl,de
	ld a,(hl)
	and a,$F0
	ld h,a 
	ld a,(de) 
	and a,$0F 
	or a,h 
	ld (de),a 
	ret 
.even: 
	ex de,hl 
	add hl,de
	ld a,(hl)
	and a,$0F
	ld h,a 
	ld a,(de) 
	and a,$F0 
	or a,h 
	ld (de),a 
	ret 

;---------------------------------------------
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
	ld a,(iy+3) 
	cp a,255 ; if left=255 skip 
	jr z,.skipblit 
	or a,a 
	sbc hl,hl 
	ld l,a 
	ex af,af' 
	ld a,(iy+4) ; right edge 
	sub a,l 
	jr z,.point 
	ld c,a ; c = count for ldir 
	
	ld a,i
	lea de,ix+0 ; get first pixel  
	add hl,de 
	ld b,(iy+5) ; b = lsb's 
	srl b	; draw leftmost pixel if odd(doesnt overlap with ldir) 
	jr nc,.fullleft  
	and a,$F0 
	ld e,a 
	ld a,(hl) 
	and a,$0F 
	or a,e
	ld e,ixl 
.fullleft: 
	ld (hl),a 
	
	or a,a 
	sbc hl,hl 
	ld l,(iy+4)
	add hl,de  ; get last pixel
	ld a,i
	srl b ; draw rightmost pixel if even 
	jr c,.fullright 
	and a,$0F 
	ld e,a 
	ld a,(hl) 
	and a,$F0 
	or a,e
	ld e,ixl 
.fullright: 
	ld (hl),a
	dec hl  
	dec c 
	dec c 
	jr z,.pointw
	ld a,159 
	cp a,c 
	jr c,.skipblit 
	push hl 
	pop de 
	dec de 
	ld a,i
	ld (hl),a 
	lddr
	
.skipblit:
	lea iy,iy+6
	exx 
	add ix,de
	djnz .loop 
	ret 
	
.point:
	lea de,ix+0 ; get first pixel  
	add hl,de
	ld a,(iy+5)
	ld c,a 
	srl c 
	and a,1
	xor a,c 
	jr nz,.pointw 
	ld a,i 
	rr c 
	jr nc,.even 
.odd:
	and a,$F0
	ld e,a 
	ld a,(hl) 
	and a,$0F   
	or a,e 
	ld (hl),a
	jr .skipblit 
.even: 
	and a,$0F
	ld e,a 
	ld a,(hl) 
	and a,$F0  
	or a,e 
	ld (hl),a
	jr .skipblit
.pointw: 
	ld a,i
	ld (hl),a 
	jr .skipblit
	
	
	
;---------------------------------------------
drawMask:
	ld ix,(_vbuffer1) ; ix screen offset
	ld d,160 	
	mlt de 
	add ix,de 
	ld de,160
.loop:
	exx
	ld a,(iy+3) 
	cp a,255 ; if left=255 skip 
	jr z,.skipblit 
	or a,a 
	sbc hl,hl 
	ld l,a 
	ex af,af' 
	ld a,(iy+4) ; right edge 
	sub a,l 
	jr z,.point 
	ld b,a ; b = count for loop 
	
	lea de,ix+0 ; get first pixel  
	add hl,de 
	ld a,(hl)
	ld c,(iy+5) ; b = lsb's 
	srl c	 
	jr nc,.fullleft  
	or a,10000000b 
	jr .skipleft 
.fullleft: 
	or a,10001000b
.skipleft:
	ld (hl),a 
	or a,a 
	sbc hl,hl 
	ld l,(iy+4)
	add hl,de  ; get last pixel
	ld a,(hl)
	srl c ; draw rightmost pixel if even 
	jr c,.fullright 
	or a,00001000b 
	jr .skipright 
.fullright: 
	or a,10001000b
.skipright:
	ld (hl),a
	dec hl  
	dec b 
	jr z,.pointw
	ld a,159 
	cp a,b 
	jr c,.skipblit 
	ld d,10001000b 
.fill: 
	ld a,(hl) 
	or a,d 
	ld (hl),a 
	dec hl 
	djnz .fill 

.skipblit:
	lea iy,iy+6
	exx 
	add ix,de
	djnz .loop 
	ret 
	
.point:
	lea de,ix+0 ; get first pixel  
	add hl,de
	ld a,(iy+5)
	ld c,a 
	srl c 
	and a,1
	xor a,c 
	jr nz,.pointw 
	rr c 
	jr nc,.even 
.odd:
	ld a,10000000b
	or a,(hl) 
	ld (hl),a 
	jr .skipblit 
.even: 
	ld a,00001000b
	or a,(hl) 
	ld (hl),a 
	jr .skipblit
.pointw: 
	ld a,10001000b 
	or a,(hl) 
	ld (hl),a 
	jr .skipblit
	
;---------------------------------------------
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
	ld a,(iy+3) 
	cp a,255 ; if left=255 skip 
	jr z,.skipblit 
	or a,a 
	sbc hl,hl 
	ld l,a 
	ld a,(iy+4) ; right edge 
	sub a,l 
	jr z,.point 
	ld c,a
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
	