#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.align  4

.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout

.equ    GPIO_BTN_DN_MSK, 0x00040000   @ Bit-18 for falling-edge event on GP20
.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x04000000   @ Bit-26 for falling-edge event on GP22

.equ    GPIO_BTN_DN,  20              @ Specify pin for the "down" button
.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_BTN_UP,  22              @ Specify pin for the "up" button
.equ    GPIO_LED_PIN, 25              @ Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    LED_VAL_ON,    1              @ Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              @ Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)

@ Main entry point into the ASM portion of the code
main_asm:
    bl      init_leds           // Same as previous labs
    bl      init_btns           // Use asm_gpio_set_irq C function to setup falling-edge interrutps
    bl      install_alrm_isr    // See below
    bl      install_gpio_isr    // See below
    ldr     r4, =DFLT_ALARM_TIME
    bl      set_alarm           // Set a new alarm
// Enable alarm timer interrupts using the (TIMER_BASE + TIMER_INTE_OFFSET) register
    ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)
    movs    r1, #1
    str     r1, [r2]
// this loop waits for an interrupt
main_loop:  
    wfi                         // Wait here until any interrupt fires
    b       main_loop

init_leds:
    push    {lr}
    movs    r0, #GPIO_LED_PIN          @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_init               @ Call the subroutine to initialise the GPIO pin specified by r0
    movs    r0, #GPIO_LED_PIN          @ This value is the GPIO LED pin on the PI PICO board
    movs    r1, #GPIO_DIR_OUT          @ We want this GPIO pin to be setup as an output pin
    bl      asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
    pop     {pc}
init_btns:
//code goes here to initialise the buttons
    @ move button pins to r0 and set IRQ --- down button (GPIO20)
    push    {lr}
    movs    r0, #GPIO_BTN_DN
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN_DN    @ this value is the down button
    movs    r1, #GPIO_DIR_IN    @ set button as input
    bl      asm_gpio_set_dir 
    movs    r0, GPIO_DIR_IN
    bl      asm_gpio_set_dir 
    movs    r0, #GPIO_BTN_DN
    bl      asm_gpio_set_irq
    @ same for the en button (GPIO21)
    movs    r0, #GPIO_BTN_EN
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN_EN    @ this value is the en button
    movs    r1, #GPIO_DIR_IN    @ set button as input
    bl      asm_gpio_set_dir 
    movs    r0, GPIO_DIR_IN
    bl      asm_gpio_set_dir 
    movs    r0, #GPIO_BTN_EN
    bl      asm_gpio_set_irq
    @ same for the up button (GPIO22)
    movs    r0, #GPIO_BTN_UP
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN_UP    @ this value is the up button
    movs    r1, #GPIO_DIR_IN    @ set button as input
    bl      asm_gpio_set_dir 
    movs    r0, GPIO_DIR_IN
    bl      asm_gpio_set_dir 
    movs    r0, #GPIO_BTN_UP
    bl      asm_gpio_set_irq
    pop     {pc}
//
// Enable alarm timer interrupts and set an alarm
//
set_alarm:
    // Enable alarm timer interrupts using the (TIMER_BASE + TIMER_INTE_OFFSET) register
    //ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)
    //movs    r1, #1
    //str     r1, [r2]
    // Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
    ldr     r1, =(TIMER_BASE + TIMER_TIMELR_OFFSET)
    ldr     r2, [r1]
    movs    r1, r4
    add     r1, r1, r2
    ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET)
    str     r1, [r2]
    // Add the time delay you want to wait for to the current timer count
    // Push the updated value to (TIMER_BASE + TIMER_ALARM0_OFFSET)
    // Exit subroutine
    bx      lr

//
// Sets up the alrm_isr in the RAM vector table and enables the correct interrupt
//
install_alrm_isr:
    // Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)
    ldr     r1, [r2]
    movs    r2, #ALRM_ISR_OFFSET
    add     r2, r1
    // Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table
    ldr     r0, =alrm_isr
    str     r0, [r2]
    // Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    movs    r1, #1
    str     r1, [r2]

    // Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    movs    r1, #1
    str     r1, [r2]
    // Exit subroutine
    bx      lr

.thumb_func
//
// Service the pending interrupt from the ALARM0 TIMER
//


alrm_isr:
    // Perform required functionality (e.g. toggle the LED)
    // Disable pending interrupt from TIMER by writing correct value to (TIMER_BASE + TIMER_INTR_OFFSET)
    // Exit ISR
@ Subroutine to toggle the LED GPIO pin value
    push    {lr}                      @ Store the link register to the stack as we will call nested subroutines
    ldr     r1, =(TIMER_BASE + TIMER_INTR_OFFSET)
    movs    r0, #1
    str     r0, [r1]
    movs    r0, #GPIO_LED_PIN         @ Set the pushbutton pin number to r0 for use by asm_gpio_get
    bl      asm_gpio_get              @ Get current the value of the LED GPIO pin (returns to r0)
    cmp     r0, #LED_VAL_OFF          @ Check if the LED GPIO pin value is "off"
    beq     led_set_on                @ If it is "off" then then jump code to to turn it on
led_set_off:
    movs    r1, #LED_VAL_OFF          @ The LED is currently "on" so we want to turn it "off"
    b       led_set_state             @ Jump to portion of code where we set the state of the LED
led_set_on:
    movs    r1, #LED_VAL_ON           @ The LED is currently "off" so we want to turn it "on"
led_set_state:
    movs    r0, #GPIO_LED_PIN         @ Set the LED GPIO pin number to r0 for use by asm_gpio_put
    bl      asm_gpio_put              @ Update the the value of the LED GPIO pin (based on value in r1)
    bl      set_alarm
    ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)
    movs    r1, #1
    str     r1, [r2]
    ldr     r0, =msg1
    bl      printf
    pop     {pc}                      @ Pop the link register from the stack to the program counter

//
// Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
//
install_gpio_isr:
    // Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)
    ldr     r1, [r2]                                    @ load the value into r1
    movs    r2, #GPIO_ISR_OFFSET                        @ move the GPIO_ISR_OFFSET value into r2
    add     r2, r1                                      @ add the two values to find the location of the interrupt in the vector table and store its value in r2
    // Store the address of the gpio_isr handler to the correct offset for GPIO in the vector table
    ldr     r0, =gpio_isr                               @ load the interrupt into r0
    str     r0, [r2]                                    @ store the value of the interrupt into the address at r2
    // Disable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   @ ICPR method to disable
    ldr     r1, =0x2000                                 @ load the 2 to the power of 13 value to r1
    str     r1, [r2]                                    @ store the value of this into the address at r2 -- this should disable the GPIO IRQ
    // Enable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   @ ISER method to enable
    ldr     r1, =0x2000                                 @ this is the same as above
    str     r1, [r2]                                    @ " "
    // Exit subroutine
    bx      lr
//
.thumb_func

gpio_isr:

// Perform required functionality based on the button press event that was detected

// FIX THIS ASAP

.align 4
msg1:    .asciz "The LED has been toggled\n"
msg2:    .asciz "The LED is currently flashing.\n"
msg3:    .asciz "LED is currently not flashing.\n"
msg4:    .asciz "The flashing time interval has been set back to the original value.\n"
msg5:    .asciz "The flashing time interval has been halved.\n"
msg6:    .asciz "The flashing time interval has been doubled.\n"

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME