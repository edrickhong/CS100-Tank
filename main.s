;	CS 100 Skeleton File
;	Due Date:
;	Student Name:
;	Section:

;	TITLE "CS100_AS6Skeleton"
; © 2015 DigiPen, All Rights Reserved.


	INCLUDE include.s
FIODIR2 EQU 0X2009C040
PINVAL2 EQU 0X2009C054
ADCcontrolregister equ 0x40034000

 MACRO
 WRITEBITS $BITS_TO_WRITE,$REGISTER_ADDY
 MOV R1,$BITS_TO_WRITE
 LDR R0,=$REGISTER_ADDY
 STR R1,[R0]
 MEND

 MACRO
 SETBITS $BITS_TO_SET,$REG_ADDY
 LDR R0,=$REG_ADDY
 LDR R1,[R0]
 ORR R1,R1,$BITS_TO_SET
 STR R1,[R0]
 MEND

 MACRO;ME SMASHY R0,R1.
 CLEARBITS $BITS_TO_CLEAR,$REG_ADDY
 LDR R0,=$REG_ADDY
 LDR R1,[R0]
 BIC R1,R1,$BITS_TO_CLEAR
 STR R1,[R0]
 MEND

    GLOBAL __main
	AREA Main, CODE, READONLY
	ALIGN 2; MAKE SURE CODE DOESN'T START ON ODD BYTES
	ENTRY


__main; R0 IS TEMP REGISTER

CONFIG_IO; GET ALL VALUES FROM .INC FILE AND 


  LDR R0,=FIODR2; ; buzzer and lights
 MOV R1,#2_0000000000000000000000111111111; 
 STR R1,[R0]; MAKES ALL 9 LSB ON PORT 2 OUTPUTS
 LDR R0,=FIODR0;
 MOV R1,#0; (ALL P0 AS INPUT)
 STR R1,[R0]
 MOV R4,#1; CLEAR R2 COUNTER
 BL INIT_PWM
 
 bl Init_ADC
 SETBITS #(1 << 24),0x40034000 ; tell adc to start reading
 
 
 ;r0 is my result register
  
Handle_Input

	bl Start_Converting_Y
	LDR R1,=0X4001800C	; this is the prescalar register
	;shift the result right by 4
	;clear all other bits
	asr r7,#4
	bic r7,#2_11111111111111111111111111110000
	str r7,[r1]

 B Handle_Input

INIT_PWM
 SETBITS #2_1000000,0x400FC0C4;PWM POWER ON
; 2. Reset and hold the PWM module  Set bit 1 at 0x4001 8004.  (Timer Control Register)
 SETBITS #2_10,0x40018004
;3. Peripheral clock: In the PCLKSEL0 register (Table 40), select PCLK_PWM1.  Set bit 12 at 0x400F C1A8 (Clock input to PWM 1:1)
 SETBITS #0X1000,0x400FC1A8
;4. Pins: Select which pin the PWM1 attaches to through the PINSEL registers. Attach PWM1 to P2[0] where our speaker is.  PINSEL4, that is, 0x4002 C010 should have its least significant bits set to 01.
 SETBITS #01,0X4002C010
 CLEARBITS #2_10,0X4002C010;NOT EFFICIENT
;5. Select pin modes for port pins with PWM1 functions through the PINMODE registers (Section 8.5). PINMODE4, send Binary LSB 10 to 0x4002C050 so that the pin has neither a pull-up nor a pull-down resistor attached to it.
 WRITEBITS #2_10,0x4002C050
;Now to set up the Period, Pulse Width, and finally enable PWM output.
;6. Attach the system clock ->prescaler -> PWM -- write 0x00000000 to the CounT Control Register (0x4001 8070).
 WRITEBITS #0,0x40018070
;7. Set up the prescaler to count every 250 clock cycles by storing 250 to the address of the Prescale Register (0x4001 800C)
 WRITEBITS #249,0x4001800C
;8. Set the PWM to reset when it reaches 100 counts by: (A) storing 100 in PWM1 Match Register 0 (0x4001 8018)
 WRITEBITS #100,0X40018018
;9. Tell the PWM to turn off output when it reaches 50 by storing 50 in PWM1MatchRegister 1 (0x4001 801C)
 WRITEBITS #50,0X4001801C
;10. (B)Update the PWM timing with Match0 and Match1  by "latching" them in: load 11 to the LSB of (0x4001 8050)
 SETBITS #2_11,0X40018050
;11. (C)Make Match0 reset the PWM (Match0 is period) by sending #2_00010 to MatchControlReg (0x4001 8014)
 WRITEBITS #2_00010,0x40018014
;12. Enable PWM1 to output using the PWM Control Register by sending 1 to the 9th bit of (0x4001 804C) (you can store 0x00200)
 SETBITS #0X200,0x4001804C
;13. Start the timer that feeds the PWM by removing the reset, enabling and starting: send a #9 to the TimerControlReg(0x4001 8004)
 WRITEBITS #2_1001,0x40018004
 BX LR
 
 
 
Init_ADC
	;enable adc in pconp
	SETBITS #(1 << 12),0x400FC0C4
	

;enable adc in the ad0cr register
	WRITEBITS #(1 << 21),ADCcontrolregister
	
	
;set the peripheral clock

	SETBITS #(2_11 << 24),0x400FC1A8
	
	
;set the pimode-PINSEL to adc (i think the problem was here. Actually, it is)
	SETBITS #(2_101 << 14),0x4002C004
	
	
;No pullup no pull down

	ldr r0,=0x4002C040
	mov r1,#0x28000
	str r1,[r0]
	
	bx lr
	
Start_Converting_Y

	SETBITS #1,ADCcontrolregister
	CLEARBITS #(0XFE),ADCcontrolregister
	
;load in the  ADGR register 

	ldr r0,=0x40034004
	
	;check if conversion is complete
	
Converting_Y
	ldr r1,[r0]
	tst r1,#(1 << 31)
	beq Converting_Y
	
	
	;return result
	
	MOV r7,R1
	
	bx lr
	
	
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
	
Start_Converting_X

	SETBITS #1,ADCcontrolregister
	CLEARBITS #(0XFE),ADCcontrolregister
	
;load in the  ADGR register 

	ldr r0,=0x40034004
	
	;check if conversion is complete
	
Converting_X
	ldr r1,[r0]
	tst r1,#(1 << 31)
	beq Converting_X
	
	
	;return result
	
	MOV r7,R1
	
	bx lr

READ_BUTTONS
 LDR R9,=PIN0; LOAD R9 WITH THE ADDRESS OF THE BUTTON VALUES
 LDR R3,[R9]; LOAD R3 WITH THE INFORMATION IN ADDRESS R9
 TST R3,#2_00000100; GIVES ME 100 IF BUTTON NOT PRESSED, 0 IF PRESSED
 LDR R10,=PIN2
 BEQ BUTTON_PRESSED; BUTTON PRESSED, TURN ON LIGHTS.
 MOV R5,#0;BUTTON ISN'T PREVIOUSLY PRESSED.
; R5=0, BUTTON IS MOST RECENTLY NOT PRESSED. R5=1, BUTTON WAS MOST RECENTLY PRESSED 
 B READ_BUTTONS
  
  
BUTTON_PRESSED
 CMP R5,#0
 BNE READ_BUTTONS;BUTTON IS *STILL* PRESSED
 ;NEW PRESS
 ADD R2,R2,#5 ;this delays the timer
 MOV R5,#1;BUTTON IS MOST RECENTLY PRESSED
 LDR R1,=0X4001800C
 STR R2,[R1]
 B READ_BUTTONS

LOOPENDLESSLY
 B LOOPENDLESSLY
 END