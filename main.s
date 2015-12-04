
	INCLUDE include.s
		
BaseSpeed equ 30 ;we will use 50 for now cos why not
TurnSpeed equ 50
Factor equ 1
Range equ 1

 
 ;We will be adjusting individual wheel speeds on the fly to do the turning

    GLOBAL __main
	AREA Main, CODE, READONLY
	ALIGN 2; MAKE SURE CODE DOESN'T START ON ODD BYTES
	ENTRY


__main

;these are the pins that control the motors. Set them to output
	ldr r0,=DDR0
	mov r1,#2_1111
	str r1,[r0]
	
	
	mov r9,#0 ; we will store the angle bias into r9. This is a signed number
	
	
	
	
	bl INIT_PWM
	bl INIT_ADC

 
 
 
 ;r0 is my result register
  
Handle_Input

	bl Read_Sensor
	
	
	bl Process; we will have Process over here instead

	B Handle_Input
	




Read_Sensor  ;r1 r2 r3

	SETBITS #1,Adcr0  ;read pin 0
	CLEARBITS #(2_11111110),Adcr0

	SETBITS #(1 << 24),Adcr0 ; START
	CLEARBITS #(2_11 << 25),Adcr0

	
;load in the  ADGR register

	LDR R0,=Adgr  
	

;check if conversion is complete
Converting_Y   ;Front
	LDR R1,[R0]
	TST R1,#(1 << 31)
	BEQ Converting_Y
	
	
	
	push {r1}

	
Start_Converting_X  ;Left

	SETBITS #2,Adcr0  ;read pin 0
	CLEARBITS #(2_11111101),Adcr0

	SETBITS #(1 << 24),Adcr0 ; START
	CLEARBITS #(2_11 << 25),Adcr0
;load in the  ADGR register 

	LDR R0,=Adgr
	
	;check if conversion is complete
	
Converting_X
	LDR R1,[R0]
	TST R1,#(1 << 31)
	BEQ Converting_X
	
	push {r1}
	
Start_Converting_Z

	SETBITS #4,Adcr0  ;read pin 0
	CLEARBITS #(2_11111011),Adcr0

	SETBITS #(1 << 24),Adcr0 ; START
	CLEARBITS #(2_11 << 25),Adcr0
	
	
	LDR R0,=Adgr

Converting_Z  ;FIXME:Right  We cannot seem to read from here

	LDR R1,[R0]
	TST R1,#(1 << 31)
	BEQ Converting_Z
	
	push {r1}
	
	;format the results r1 r2 r3
	
	;result is in r1
	
	;shift the result right by 4
	;clear all other bits
	
	pop {r3}
	pop {r2}
	pop {r1}
	
	ldr r4,=0xFFFFF000
	
	ASR r1,#4
	BIC r1,r4   ;#2_1111 1111 1111 1111 1111 0000 0000 0000
	
	ASR r2,#4
	BIC r2,r4
	
	ASR r3,#4
	BIC r3,r4


	nop
	
	
	
	bx lr
	
	

	
	
Process 

;r1 r2 and r3 are reserved  (Fs Ls Rs)

	push {lr}
	
	
;---------------Debug Sensors Start------------------


	sub r4,r2,r3  ; L - R
	
	
	cmp r4,#0
	bpl Correct_Right
	
;case r4 < 0, turn left
Go_Left

	bl Left
	
	b Process_Exit
	
	
Correct_Right ;course correct or go right

	mov r5,#1900
	cmp r4,r5
	bpl Go_Right

; r4 < r5

;Course Correction

	cmp r1,#Range
	bpl Go_Right  ; if front is in range (go right by default. set a flag to turn left or right)

;else correct course
	cmp r9,#0
	bpl Right_Forward
	
	b Go_Left ; r9 <0
	
Right_Forward
	cbnz Go_Right 
	
	bl Forward ;r9 = 0
	
	b Process_Exit
	
Go_Right


; r4 >=r5

	bl Right

;---------------Debug Sensors End------------------

Process_Exit
	
	pop {lr};restore return address
	
	
	SETBITS #2_111,LoadEnabler ; latch the results

	bx lr
	
	
Forward

	ldr r0,=Port0
	mov r1,#2_1010;#2_0101
	str r1,[r0]
	
	
	;reset to the base speed
	ldr r0,= Match1
	mov r1, #BaseSpeed
	str r1,[r0]
	 
	ldr r0,=Match2
	str r1,[r0]
	
	bx lr

Left

	ldr r0,=Port0
	mov r1,#2_1010;#2_0101
	str r1,[r0]
	
	
	;reset to the base speed
	ldr r0,= Match1
	mov r1, #BaseSpeed
	str r1,[r0]
	 
	ldr r0,=Match2
	add r1, #TurnSpeed
	str r1,[r0]
	
	sub r9,#1
	
	bx lr

Right

	ldr r0,=Port0
	mov r1,#2_1010;#2_0101
	str r1,[r0]
	
	
	;reset to the base speed
	ldr r0,= Match1
	mov r1, #TurnSpeed
	str r1,[r0]
	 
	ldr r0,=Match2
	mov r1, #BaseSpeed
	str r1,[r0]
	
	add r9,#1
	
	bx lr





	
;--------------Init stuff. This will be here untiil I figure out how this assembler works-------------------------------



;NOTE: This should be fixed now. Please check

;we need to switch on the pwm. Get this done I guess  (p2.0 and p2.1)

INIT_PWM
 SETBITS #2_1000000,Pconp;PWM POWER ON


; 2. Reset and hold the PWM module  Set bit 1 at 0x4001 8004.  (Timer Control Register)
 SETBITS #2_10,Tcr


;3. Peripheral clock: In the PCLKSEL0 register (Table 40), select PCLK_PWM1.  Set bit 12 at 0x400F C1A8 (Clock input to PWM 1:1)
 SETBITS #0X1000,PclkSel0  ; (basically 1 << 12)


;4. Pins: Select which pin the PWM1 attaches to through the PINSEL registers. Attach PWM1 to P2[0] where our speaker is.  PINSEL4, that is, 0x4002 C010 should have its least significant bits set to 01.
 SETBITS #0101,PinSel4  ;sets pins 2.0 and 2.1 to pwm
 CLEARBITS #2_1010,PinSel4;NOT EFFICIENT


;5. Select pin modes for port pins with PWM1 functions through the PINMODE registers (Section 8.5). PINMODE4, send Binary LSB 10 to 0x4002C050 so that the pin has neither a pull-up nor a pull-down resistor attached to it.
 WRITEBITS #2_1010,PinMode4  ;write 10


;Now to set up the Period, Pulse Width, and finally enable PWM output.
;6. Attach the system clock ->prescaler -> PWM -- write 0x00000000 to the CounT Control Register (0x4001 8070).
 WRITEBITS #0,CounterTimercr


;7. Set up the prescaler to count every 250 clock cycles by storing 250 to the address of the Prescale Register (0x4001 800C)
 
 
 ;WRITEBITS #249,Prescaler
 
 WRITEBITS #(0xF << 10),Prescaler
 
 
;8. Set the PWM to reset when it reaches 100 counts by: (A) storing 100 in PWM1 Match Register 0 (0x4001 8018)
 WRITEBITS #100,Match0


;9. Tell the PWM to turn off output when it reaches 50 by storing 50 in PWM1MatchRegister 1 (0x4001 801C)
 WRITEBITS #50,Match1
 WRITEBITS #50,Match2 ;And PWM1MatchRegister 2


;10. (B)Update the PWM timing with Match0 and Match1  by "latching" them in: load 11 to the LSB of (0x4001 8050)
 
 SETBITS #2_111,LoadEnabler  ;latch m0 m1 and m2 ;LoadEnabler allows the values written in match registers to take affect in the next clock cycle
 
 
 ;SETBITS #2_1111,LoadEnabler;And Match2 and Match3


;11. (C)Make Match0 reset the PWM (Match0 is period) by sending #2_00010 to MatchControlReg (0x4001 8014)
 
 WRITEBITS #2,Matchcr
 
 
 
 ;WRITEBITS #2_00010010,Matchcr


;12. Enable PWM1 to output using the PWM Control Register by sending 1 to the 9th bit of (0x4001 804C) (you can store 0x00200)
 SETBITS #(3 << 9),PWMcr  ;enable Match1 and Match2 to output a pwm signal


;13. Start the timer that feeds the PWM by removing the reset, enabling and starting: send a #9 to the TimerControlReg(0x4001 8004)
 WRITEBITS #2_1001,Tcr


	BX LR
 
 
 
INIT_ADC  ;targeting pins : p0.23 p0.24 p0.25  Fs Ls Rs
;enable adc in pconp
	SETBITS #(1 << 12),Pconp
	
	
;enable adc in the ad0cr register
	WRITEBITS #(1 << 21),Adcr0
	
	
;set the peripheral clock
	SETBITS #(2_11 << 24),PclkSel0
	SETBITS #(1<<11),Adcr0; increase adc read prescale by 8
	
;set the pimode-PINSEL to adc (i think the problem was here. Actually, it is)

	CLEARBITS #(2_111111 << 14),PinSel1
	SETBITS #(2_010101 << 14),PinSel1  ;2_0101
	
	
;No pullup no pull down

	
	CLEARBITS #(2_111111 << 14),PinMode1
	SETBITS #(2_101010 << 14),PinMode1;#0xA8000      ;#0x28000
	
	
	
	

	
	BX LR
	
	
 END