;
; Lab4.asm
;
; Created: 2023-12-06 17:44:43
; Author : warcr701
;

	; --- lab4spel.asm

	.equ	VMEM_SZ     = 5		; #rows on display
	.equ	AD_CHAN_X   = 0		; ADC0=PA0, PORTA bit 0 X-led
	.equ	AD_CHAN_Y   = 1		; ADC1=PA1, PORTA bit 1 Y-led
	.equ	GAME_SPEED  = 70	; inter-run delay (millisecs)
	.equ	PRESCALE    = 7		; AD-prescaler value
	.equ	BEEP_PITCH  = 40	; Victory beep pitch
	.equ	BEEP_LENGTH = 100	; Victory beep length
	
	; ---------------------------------------
	; --- Memory layout in SRAM
	.dseg
	.org	SRAM_START
POSX:	.byte	1	; Own position
POSY:	.byte 	1
TPOSX:	.byte	1	; Target position
TPOSY:	.byte	1
LINE:	.byte	1	; Current line	
VMEM:	.byte	VMEM_SZ ; Video MEMory
SEED:	.byte	1	; Seed for Random

	; ---------------------------------------
	; --- Macros for inc/dec-rementing
	; --- a byte in SRAM
	.macro INCSRAM	; inc byte in SRAM
		lds	r16,@0
		inc	r16
		sts	@0,r16
	.endmacro

	.macro DECSRAM	; dec byte in SRAM
		lds	r16,@0
		dec	r16
		sts	@0,r16
	.endmacro

	; ---------------------------------------
	; --- Code
	.cseg
	.org 	$0
	jmp	START
	.org	INT0addr
	jmp	MUX
	.org INT_VECTORS_SIZE



START:
	;***			; sätt stackpekaren
	ldi r16, HIGH(RAMEND)
	out SPH, r16
	ldi r16, LOW(RAMEND)
	out SPL, r16

	call	HW_INIT	


	call	WARM
RUN:

	call	JOYSTICK
	call	ERASE_VMEM
	call	UPDATE

/*** 	Vänta en stund så inte spelet går för fort 	***
	
*** 	Avgör om träff				 	***/


	call MOVEMENT_DELAY
	call CHECK_FOR_HIT
	brne NO_HIT
		
	ldi	r16,BEEP_LENGTH
	call	BEEP
	call	WARM
NO_HIT:
	jmp	RUN

	; ---------------------------------------
	; --- Multiplex display
MUX:	
	push r16
	push r17
	push r18
	in r16, SREG
	push r16
	push ZL
	push ZH

/*** 	skriv rutin som handhar multiplexningen och ***
*** 	utskriften till diodmatrisen. Öka SEED.		***/
	
	;shut off current line display
	ldi r16, 0
	out PORTB, r16


	lds r17, LINE
	ldi ZH, HIGH(VMEM)
	ldi ZL, LOW(VMEM)

	;setting which line to display to
	mov r18, r17
	swap r18
	lsl r18
	in r16, PORTA
	andi r16, $0F ; Mask 
	or r16, r18
	out PORTA, r16

	;read from memory what is in that line and display it
	add ZL, r17
	clr r16
	adc ZH, r16
	ld r16, Z
	out PORTB, r16
	
	;increment line number
	inc r17
	cpi r17, 5
	brne MUX_DONE
	ldi r17, $00
	
MUX_DONE: 
	sts LINE, r17

	lds r16, SEED
	inc r16
	sts SEED, r16

	pop ZH
	pop ZL
	pop r16
	out SREG, r16
	pop r18
	pop r17
	pop r16
	reti
	
		
	; ---------------------------------------
	; --- JOYSTICK Sense stick and update POSX, POSY
	; --- Uses r16
JOYSTICK:	

/*** 	skriv kod som ökar eller minskar POSX beroende 	***
*** 	på insignalen från A/D-omvandlaren i X-led...	***

*** 	...och samma för Y-led 				***/

CONVERT_X:  ; A/D Converting of X value
	ldi r16, (1 << ADLAR) | 0
	out ADMUX, r16
	sbi ADCSRA, ADSC
WAIT_X:
	sbic ADCSRA, ADSC
	rjmp WAIT_X
	in r16, ADCH

	cpi r16, $C0 ; decide if we decrease or increase XPOS
	brsh DEC_X
	cpi r16, $30
	brlo INC_X
	rjmp CONVERT_Y

INC_X:
	lds r16, POSX
	inc r16
	sts POSX, r16
	rjmp CONVERT_Y 

DEC_X:
	lds r16, POSX
	dec r16
	sts POSX, r16


CONVERT_Y: ; A/D Converting of Y value
	ldi r17, (1 << ADLAR) | 1
	out ADMUX, r17
	sbi ADCSRA, ADSC
WAIT_Y:
	sbic ADCSRA, ADSC
	rjmp WAIT_Y
	in r17, ADCH

	cpi r17, $C0 ; decide if we decrease or increase YPOS
	brsh INC_Y
	cpi r17, $30
	brlo DEC_Y
	rjmp JOY_LIM

INC_Y:
	lds r17, POSY
	inc r17
	sts POSY, r17
	rjmp JOY_LIM

DEC_Y:
	lds r17, POSY
	dec r17
	sts POSY, r17

JOY_LIM:
	call	LIMITS		; don't fall off world!
	ret

	; ---------------------------------------
	; --- LIMITS Limit POSX,POSY coordinates	
	; --- Uses r16,r17

LIMITS:
	lds	r16,POSX	; variable
	ldi	r17,7		; upper limit+1
	call	POS_LIM		; actual work
	sts	POSX,r16
	lds	r16,POSY	; variable
	ldi	r17,5		; upper limit+1
	call	POS_LIM		; actual work
	sts	POSY,r16
	ret

POS_LIM:
	ori	r16,0		; negative?
	brmi	POS_LESS	; POSX neg => add 1
	cp	r16,r17		; past edge
	brne	POS_OK
	subi	r16,2

POS_LESS:
	inc	r16	
POS_OK:
	ret

	; ---------------------------------------
	; --- UPDATE VMEM
	; --- with POSX/Y, TPOSX/Y
	; --- Uses r16, r17
UPDATE:	
	clr	ZH 
	ldi	ZL,LOW(POSX)
	call 	SETPOS
	clr	ZH
	ldi	ZL,LOW(TPOSX)
	call	SETPOS
	ret

	; --- SETPOS Set bit pattern of r16 into *Z
	; --- Uses r16, r17
	; --- 1st call Z points to POSX at entry and POSY at exit
	; --- 2nd call Z points to TPOSX at entry and TPOSY at exit
SETPOS:
	ld	r17,Z+  	; r17=POSX
	call SETBIT		; r16=bitpattern for VMEM+POSY
	ld	r17,Z		; r17=POSY Z to POSY
	ldi	ZL,LOW(VMEM)
	add	ZL,r17		; *(VMEM+T/POSY) ZL=VMEM+0..4
	ld	r17,Z		; current line in VMEM
	or	r17,r16		; OR on place
	st	Z,r17		; put back into VMEM
	ret
	
	; --- SETBIT Set bit r17 on r16
	; --- Uses r16, r17
SETBIT:
	ldi	r16,$01		; bit to shift
SETBIT_LOOP:
	dec 	r17			
	brmi 	SETBIT_END	; til done
	lsl 	r16		; shift
	jmp 	SETBIT_LOOP
SETBIT_END:
	ret

	; ---------------------------------------
	; --- Hardware init
	; --- Uses r16
HW_INIT:

/*** 	Konfigurera hårdvara och MUX-avbrott enligt ***
*** 	ditt elektriska schema. Konfigurera 		***
*** 	flanktriggat avbrott på INT0 (PD2).			***/

INIT_PORTS:
	ldi r16, $FF
	out DDRB, r16

	ldi r16, $E0
	out DDRA, r16

	ldi r16, $FB
	out DDRD, r16

INIT_INTERRUPT:
	ldi r16,  (1 << ISC11) | (1 << ISC10) | (1 << ISC01) | (1 << ISC00)
	out MCUCR,r16
	ldi r16,(1<<INT0)|(1<<INT1)
	out GICR,r16
	sei 

INIT_JOYSTICK:
	ldi r16, (1<<ADEN)
	out ADCSRA, r16
	
	ret

	; ---------------------------------------
	; --- WARM start. Set up a new game
WARM:

/*** 	Sätt startposition (POSX,POSY)=(0,2)		***/
	ldi r16, 0
	sts POSX, r16
	ldi r16, 2
	sts POSY, r16

	push	r0		
	push	r0		
	call	RANDOM		; RANDOM returns x,y on stack
	pop r16
	sts TPOSX, r16
	pop r16
	sts TPOSY, r16
	
/*** 	Sätt startposition (TPOSX,POSY)				***/
	call	ERASE_VMEM
	ret

	; ---------------------------------------
	; --- RANDOM generate TPOSX, TPOSY
	; --- in variables passed on stack.
	; --- Usage as:
	; ---	push r0 
	; ---	push r0 
	; ---	call RANDOM
	; ---	pop TPOSX 
	; ---	pop TPOSY
	; --- Uses r16
RANDOM:
	in	r16,SPH
	mov	ZH,r16
	in	r16,SPL
	mov	ZL,r16

/*** 	Använd SEED för att beräkna TPOSX		***
*** 	Använd SEED för att beräkna TPOSX		***/


	;***		; store TPOSX	2..6
	;***		; store TPOSY   0..4

	ldi r16, 0
	std z+4, r16  ; Y = 0

	lds	r16,SEED
	
SEED_MOD_25:
	subi r16, 25
	cpi r16, 25
	brsh SEED_MOD_25

	cpi r16,1

RANDOM_LOOP:
	cpi r16, 5
	brlo RANDOM_DONE
	
	push r16
	ldd r16, z+4   ; Y++
	inc r16
	std z+4, r16
	pop r16

	subi r16, 5
	
	brsh RANDOM_LOOP

RANDOM_DONE:
	inc r16
	inc r16
	std z+3, r16 ;X

	ret


	; ---------------------------------------
	; --- Erase Videomemory bytes
	; --- Clears VMEM..VMEM+4
	
ERASE_VMEM:
	ldi r16, $00
	sts VMEM, r16
	sts VMEM + 1, r16
	sts VMEM + 2, r16
	sts VMEM + 3, r16
	sts VMEM + 4, r16

	ret

	; ---------------------------------------
	; --- BEEP(r16) r16 half cycles of BEEP-PITCH
BEEP:	
								

	
	BEEP_LOOP:
		sbi PORTB, 7
		rcall BEEP_DELAY
		cbi PORTB, 7
		rcall BEEP_DELAY
		dec r16
		brne BEEP_LOOP

	ret


BEEP_DELAY:
	push r16
	
	ldi r16, BEEP_PITCH
	BEEP_DELAY_LOOP:
		dec r16
		brne BEEP_DELAY_LOOP
	
	pop r16
	ret 

CHECK_FOR_HIT:
	push r16
	push r17
	
	lds r16, POSX
	lds r17, TPOSX
	cp r16, r17
	brne CHECK_FOR_HIT_DONE
	
	lds r16, POSY
	lds r17, TPOSY
	cp r16, r17

CHECK_FOR_HIT_DONE:
	pop r17
	pop r16
	ret

MOVEMENT_DELAY:
	push r16
	push r17
	push r18

	ldi r16, GAME_SPEED
MOVEMENT_DELAY_LOOP1:
	ldi r17, 3
MOVEMENT_DELAY_LOOP2:
	ldi r18, 0
MOVEMENT_DELAY_LOOP3:
	dec r18
	brne MOVEMENT_DELAY_LOOP3
	dec r17
	brne MOVEMENT_DELAY_LOOP2
	dec r16
	brne MOVEMENT_DELAY_LOOP1

	pop r18
	pop r17
	pop r16
	ret