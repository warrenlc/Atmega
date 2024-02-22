.equ T_HALF = 5
.equ T = T_HALF * 2

INIT:
	ldi r16,HIGH(RAMEND)
	out SPH,r16
	ldi r16,LOW(RAMEND)
	out SPL,r16
	call PORTS_SETUP

MAIN:
	call START_BIT
	call DATA
	call PRINT

	; Extra delay to make sure we don't read the last databit as a startbit
	; for next iteration of the program
	ldi r16, T
	call DELAY

	rjmp MAIN

START_BIT:
	call FIND
	breq START_BIT

	ldi r16,T_HALF
	call DELAY
	
	call FIND
	breq START_BIT
	
	ret

DATA:
	; read data and store result in r20
	clr r20

	call READ_DATA_BIT

	ret

READ_DATA_BIT:
	; wait T and then read bit 4 times
	ldi r21, 4
READ_DATA_BIT_LOOP:
	;dec r21

	ldi r16, T
	call DELAY
	in r17, PINA
	swap r17
	or r20, r17
	lsr r20
	
	;cpi r21, 0
	dec r21
	brne READ_DATA_BIT_LOOP

	ret

PRINT:
	; outputs r20 to PORTB
	out PORTB, r20
	ret

FIND:
	clr r21
	sbic PINA, 0
	dec r21
	ret

PORTS_SETUP:
	clr r16
	out DDRA, r16
	ldi r16, $8F
	out DDRB, r16
	ret

DELAY:
	sbi PORTB, 7




DELAY_OUTER:
	ldi r17, $1F
DELAY_INNER:
	dec r17
	brne DELAY_INNER
	dec r16
	brne DELAY_OUTER
	cbi PORTB,7
	ret