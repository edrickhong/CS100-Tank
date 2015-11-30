
	INCLUDE include.s
		
		;FIXME: Don't BL more than once	
		
BaseSpeed equ 50 ;we will use 50 for now cos why not
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
	
	bl Forward
 

	bl INIT_ADC
 
 
 
 ;r0 is my result register
  
Handle_Input

	bl Read_Sensor
	
	
	bl Process; we will have Process over here instead

	B Handle_Input
	


;TODO: The macro use here makes the code sub optimal
	
Read_Sensor  ;r1 r2 r3

	SETBITS #1,Adcr0  ;read pin 0
	CLEARBITS #(0XFE),Adcr0
	
;load in the  ADGR register
	LDR R0,=Adgr  
	

;check if conversion is complete
Converting_Y   ;Front
	LDR R1,[R0]
	TST R1,#(1 << 31)
	BEQ Converting_Y
	
	;r0` == 2_0011 0100
	;tst == 2_0000 1000
	;&-----------------
	;       2_0000 0000 ==> Z == 1

	;r0` == 2_0011 1100
	;tst == 2_0000 1000
	;&-----------------
	;       2_0000 1000 ==> Z == 0
	
	
	;0 0 0 0 1 0 0 1 0
	;0 1 1 1 1 1 1 1 1
	
	;0 0 0 0 0 0 0 0
	;1 0 0 0 0 0 0 0
	
Start_Converting_X  ;Left

	SETBITS #2,Adcr0 ;read pin 1
	CLEARBITS #(0XFD),Adcr0
	
;load in the  ADGR register 

	LDR R0,=Adgr
	
	;check if conversion is complete
	
Converting_X
	LDR R2,[R0]
	TST R2,#(1 << 31)
	BEQ Converting_X
	
	
	
Start_Converting_Z

	SETBITS #4,Adcr0
	CLEARBITS #(0XFB),Adcr0


Converting_Z  ;Right

	LDR R3,[R0]
	TST R3,#(1 << 31)
	BEQ Converting_Z
	
	
	
	;format the results r1 r2 r3
	
	;result is in r1
	
	;shift the result right by 4
	;clear all other bits
	
	
	ASR r1,#4
	BIC r1,#0xFFFFFFF0   ;#2_1111 1111 1111 1111 1111 1111 1111 0000
	
	ASR r2,#4
	BIC r2,#0xFFFFFFF0   
	
	ASR r3,#4
	BIC r3,#0xFFFFFFF0   
	
	
	bx lr
	
	
Forward 

	ldr r0,=Port0
	mov r1,#2_0110
	str r1,[r0]
	
	
	;reset to the base speed
	ldr r0,= Match1
	mov r1, #BaseSpeed
	str r1,[r0]
	 
	ldr r0,=Match2
	str r1,[r0]
	 
	 
	bx lr

Right
	bx lr
Left
	bx lr
	
	
Process  ;WheelSpeedR = basespeed * ( SensorR/SensorL) * constant k

	push {lr} ; preserved the return address


;r1 r2 and r3 are reserved  (Fs Ls Rs)




;TODO: This is a mess of branches. Make sure this works. Test the Avoidance first. If that works, test the Correction



;we will do a range check if we feel like we need it

; if (Ls - Rs)  !=0 > there is an obstacle. start turning

;if there is an obstacle. Avoid it 
	cmp r2,r3
	bne Avoid  ;aka if(r2 == r3) {Avoid} else{Check_Front}

;else Ls == Rs. Check front for obstacle. if(obstacle){turn right} else {Correct_Course}


Check_Front
	sub r1,#Range
	bmi Correct_Course  ;if(Fs >= Range){Correct course} else{Turn right}
	
	bl Right
	
	b Process_Exit

Correct_Course  ; if(r9 ==0){Forward} else if(r9 >0){Left} else{Right}
	cmp r9,#0
	bne Correction
	
Go_Straight
	bl Forward
	b Process_Exit

Correction
	cmp r9,#0
	bmi Go_Right

	bl Left
	
	b Process_Exit
	
Go_Right
	bl Right
	b Process_Exit

Avoid

;left wheel

	mov r0,#BaseSpeed

	mul r4,r3,r0
	udiv r4,r2 ; we will throw in k when we need it
	
	ldr r5,=Match1
	str r4,[r5]  ;set the speed to the wheel. (need to check that the output is valid)
	
;right wheel
	mul r5,r2,r0
	udiv r5,r3 ; we will throw in k when we need it
	
	ldr r6,=Match2
	str r5,[r6]  ;set the speed to the wheel. (need to check that the output is valid)
	
;store the angle bias
	sub r5,r6
	add r9,r5
	

Process_Exit
	
	pop {lr};restore return address

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
	
	
;set the pimode-PINSEL to adc (i think the problem was here. Actually, it is)
	SETBITS #(2_10101 << 14),PinSel1  ;2_101
	
	
;No pullup no pull down

	LDR R0,=PinMode0
	MOV R1,#0xA8000      ;#0x28000
	STR R1,[r0]
	
	
	
	SETBITS #(1 << 24),Adcr0 ; tell adc to start reading
	
	BX LR
	
	
 END