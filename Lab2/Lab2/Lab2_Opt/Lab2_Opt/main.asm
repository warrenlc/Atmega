;
; Lab2_Opt.asm
;
; Created: 2023-11-30 19:16:48
; Author : warren
;

.equ N = 1
.equ T = 1

.equ MESSAGE = 0x0060
.def ARG_N = r17
.def COUNTER = r18

ldi COUNTER, T
ldi ARG_N, N
SEND_FIRST: 
	ldi r16, $08
	sbi PORTB,7
DELAY:
	dec COUNTER
	brne DELAY
	deC ARG_N
	brne SEND_FIRST



