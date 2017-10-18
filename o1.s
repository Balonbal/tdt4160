.thumb
.syntax unified

.include "gpio_constants.s"     // Register-adresser og konstanter for GPIO

.text
	.global Start
	
Start:
	//Navigere til riktig adresse

	LDR R0, =BUTTON_PORT 	//Button
	LDR R2, =LED_PORT	//Led
	
	LDR R1, =PORT_SIZE

	MUL R0, R0, R1 //Port*portstørrelse
	MUL R2, R2, R1 //Samme for LED

	LDR R1, =GPIO_BASE
	ADD R0, R0, R1 //Base + port*portstørrelse
	ADD R2, R2, R1

	LDR R1, =GPIO_PORT_DIN
	ADD R5, R0, R1 //Set R5 til Button addressen

	LDR R1, =GPIO_PORT_DOUTSET
	ADD R6, R2, R1 //Set R6 til set (på)

	LDR R1, =GPIO_PORT_DOUTCLR
	ADD R7, R2, R1 //Set R7 til clear (av)
	
	//Verdier for å sjekke mot
	MOV R0, #1
	LSL R2, R0, #BUTTON_PIN //R2 har nå en ener på button pin
	LSL R3, R0, #LED_PIN	//R3 har nå 1 for led set/clear
	B Check
Check:
	LDR R0, [R5]	//Last verdi i knappen
	AND R0, R0, R2  //Alle andre enn knapp-biten blir 0
	CMP R0, #0	//Sjekker om knapp biten også var 0
	BEQ Led_pa 	//Skru på led om knapp på
	B Led_av	//Skru led av
Led_pa:
	STR R3, [R6]
	B Check
Led_av:
	STR R3, [R7]
	B Check

NOP // Behold denne på bunnen av fila

