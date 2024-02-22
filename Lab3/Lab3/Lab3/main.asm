;
; Lab3.asm
;
; Created: 2023-11-27 10:35:36
; Author : warcr701
;

.org 0
rjmp INIT
.org INT0addr
	rjmp BCD

.org INT1addr
	rjmp MUX

.org INT_VECTORS_SIZE



.dseg
	TIME: .byte 4
	POS: .byte 1

.cseg


INIT:
	ldi r16, HIGH(RAMEND)
	out SPH, r16
	ldi r16, LOW(RAMEND)
	out SPL, r16

INIT_PORTS:
	ldi r16, $FF
	out DDRB, r16
	out DDRA, r16

INIT_TIME:
	ldi r16, 0
	sts TIME, r16
	sts TIME + 1, r16 
	sts TIME + 2, r16
	sts TIME + 3, r16
	sts POS, r16

INTERRUPT_CONFIG:
		ldi r16,  (1 << ISC11) | (1 << ISC10) | (1 << ISC01) | (1 << ISC00)
		out MCUCR,r16
		ldi r16,(1<<INT0)|(1<<INT1)
		out GICR,r16
		sei 


MAIN: 
	rjmp MAIN

; Föreberedelseuppgift 2


BCD:
	push r16
	push r17
	push ZH
	push ZL
	in r16, SREG
	push r16
	
	ldi ZH, HIGH(TIME)
	ldi ZL, LOW(TIME)
	
BCD_LOOP:
	ld r16, Z
	
	inc r16
	ldi r17, $0A
	sbrc ZL, 0		;if 0th bit of ZL is clear then we want to compare to 10, otherwise 6.
	ldi r17, $06

	cp r16, r17		;if we reach 10 or 6 the value needs to be reset
	brne BCD_SAVE
	ldi r16, $00

	BCD_SAVE:
		st z+, r16
		
		; if incremented r16 is 0 the next digit should be incremented
		cpi r16, $00
		breq BCD_GO_AGAIN

		rjmp BCD_DONE

	BCD_GO_AGAIN:
		;inc ZL
		cpi ZL, TIME + 4 ; make sure we don't go out of bounds (after 59:59)
		breq BCD_DONE
		rjmp BCD_LOOP

	BCD_DONE:
		pop r16
		out SREG, r16
		pop ZL
		pop ZH
		pop r17
		pop r16
		reti

MUX:
	push r16
	push r17
	in r16, SREG
	push r16
	push ZH
	push ZL
	push YH
	push YL
	
	ldi ZH, HIGH(DISPLAY_BITS*2)
	ldi ZL, LOW(DISPLAY_BITS*2)
	ldi YH, HIGH(TIME)
	ldi YL, LOW(TIME)

	; clear current display segment
	ldi r16, $00
	out PORTB, r16

	; set Y to point to the time in SRAM we are going to display
	lds r17, POS
	add YL, r17
	adc YH, r16


	; convert the time value to display bit value
	ld r16, Y
	add ZL, r16
	ldi r16, 0
	adc ZH, r16
	lpm r16, Z

	out PORTA, r17	;set which displaysegement we are displaying on
	out PORTB, r16	;display number in on current segment

	inc r17
	cpi r17, 4
	brne MUX_DONE
	ldi r17, $00

	MUX_DONE:
		sts POS, r17

		pop YL	
		pop YH
		pop ZL
		pop ZH
		pop r16
		out SREG, r16
		pop r17
		pop r16
		reti
	


DISPLAY_BITS: ;   0	   1	2	 3	  4    5	6	 7	  8	   9
			.db $3f, $06, $5B, $4F, $66, $6D, $7D, $07, $7F, $67