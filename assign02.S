#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified                                                 @ Specify unified assembly syntax
.cpu    cortex-m0plus                                           @ Specify CPU type is Cortex M0+
.thumb                                                          @ Specify thumb assembly for RP2040
.global main_asm                                                @ Provide program starting address to the linker
.align 4                                                        @ Specify code alignment
//
// declare binary sequences for dot, dash and space
//
.equ    DOT,            0    @ let dot be 0  
.equ    DASH,           1    @ dash is 1  

.equ    DASH_TIME,      200000          @ if less than this time, this is a dash
.equ    SEQ_DONE,       2000000         @ if more than 2 seconds assume the sequence is done

// from assignment 1
.equ    DFLT_STATE_STRT, 1              @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0              @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 3000000        @ Specify the default alarm timeout
.equ    GPIO_BTN_EN,  21                @ Specify pin for the GP21 button
.equ    GPIO_DIR_IN,   0                @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1                @ Specify output direction for a GPIO pin

.equ    GPIO_BTN_DN_MSK, 0x00400000     @ falling edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x00800000     @ rising edge event on GP21 (twice the falling edge)

//
// from assignment 1
//
.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)

//
// Entry point to the ASM portion of the program
//
main_asm:
    push    {lr}
    bl      init_btn                                @ initialise the button
    bl      install_alrm_isr                        @ method to install the alarm isr
    bl      install_gpio_isr                        @ method to install the spio isr                  
    pop     {pc}

//
// Subroutine used to initialise the PI Pico Input Button 
//
init_btn:

    push    {lr}                @ store the link register in the stack
    movs    r0, #GPIO_BTN_EN    @ move the value of the enable button on the PI PICO board into r0
    bl      asm_gpio_init       @ call the subroutine to initialise the enable button
    movs    r0, #GPIO_BTN_EN    @ move the value of the enable button on the PI PICO board into r0
    movs    r1, #GPIO_DIR_IN    @ set button as input
    bl      asm_gpio_set_dir    @ set the enable button as an input button by passing r0 and r1 to this subroutine
    movs    r0, GPIO_DIR_IN     
    bl      asm_gpio_set_dir 
    movs    r0, #GPIO_BTN_EN    @ move the value of the enable button into r0
    bl      asm_gpio_set_irq    @ enable falling-edge and rising-edge interrupts on the enable button
    pop     {pc}                @ pop the link register from the stack to the program counter

//
// Enable alarm timer interrupts and set an alarm
//
set_alarm:
    // Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
    ldr     r1, =(TIMER_BASE + TIMER_TIMELR_OFFSET)
    ldr     r2, [r1]                                @ store the current time in r2

    // add the time delay that the alarm needs to wait for before firing
    ldr     r4, =DFLT_ALARM_TIME                    @ set the delay time for the alarm 
    movs    r1, r4
    add     r1, r1, r2                              @ add the delay time to the current time so the alarm knows when to fire

    // Push the updated alarm time to (TIMER_BASE + TIMER_ALARM0_OFFSET) 
    ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET) 
    str     r1, [r2]

    ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)   @ load the value of (TIMER_BASE + TIMER_INTE_OFFSET) into r2
    movs    r1, #1                                  @ move 1 to r1
    str     r1, [r2]                                @ Alarm enabled here
    
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

//
// Service the pending interrupt from the ALARM0 TIMER
//
.thumb_func
alrm_isr:
    // Perform required functionality (e.g. toggle the LED)
    push    {lr}                                    @ Store the link register to the stack as we will call nested subroutines

    // Disables the pending interrupt by writing the correct value to (TIMER_BASE + TIMER_INTR_OFFSET)
    ldr     r1, =(TIMER_BASE + TIMER_INTR_OFFSET)
    movs    r0, #1
    str     r0, [r1]
            
    // branch to function in .c file to let system know the alarm has been fired and input has stopped
    bl      alarm_call
    
    // Exit ISR
    pop     {pc}                      @ Pop the link register from the stack to the program counter

//
// From assignment 1: Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
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
    ldr     r1, =0x2000                                 @ load the 2 to the power of 13 value to r1 -- since the offset at the start is int #13
    str     r1, [r2]                                    @ store the value of this into the address at r2 -- this should disable the GPIO IRQ
    // Enable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   @ ISER method to enable
    ldr     r1, =0x2000                                 @ this is the same as above
    str     r1, [r2]                                    @ " "
    // Exit subroutine
    bx      lr

//
// Service the pending interrupt from the GPIO
//
.thumb_func
gpio_isr:
    push    {lr}
    bl      watchdog_update
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)  @ Load the memory address that we want to read from to r2
    ldr     r1, [r2]                                            @ Load the interrupt status into r1

    ldr     r0, =GPIO_BTN_DN_MSK                                @ Load the mask for a falling-edge button event into r0
    cmp     r1, r0                                              @ Check if this is equal to the interrupt status
    beq     falling_edge                                        @ If it is, jump to the subroutine that handles falling-edge events

    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)  @ Load the memory address that we want to read from to r2
    ldr     r1, [r2]                                            @ Load the interrupt status into r1
    
    ldr     r0, =GPIO_BTN_UP_MSK                                @ Load the mask for a rising-edge button event into r0
    cmp     r1, r0                                              @ Check if this is equal to the interrupt status
    beq     rising_edge                                         @ If it is, jump to the subroutine that handles rising-edge events


//
// Subroutine that is called when the button is released
//
falling_edge:
 
    bl      start_timer
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)        @ Load the address of the raw interrupts register into r2
    ldr     r0, =GPIO_BTN_DN_MSK                                @ Load the enable button mask into r0
    str     r0, [r2]                                            @ Push this value to the raw interrupts register to disable the pending interrupt from GPIO
    b       finish

//
// Subroutine called when the button is pressed
//
rising_edge:

    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)        @ Load the address of the raw interrupts register into r2
    ldr     r0, =GPIO_BTN_UP_MSK                                @ Load the enable button mask into r0
    str     r0, [r2]                                            @ Push this value to the raw interrupts register to disable the pending interrupt from GPIO
    
    bl      end_timer                                           @ call function in .c to calculate how long the button was pressed for

    // compares the dash time to input time 
    ldr     r1, =DASH_TIME                                      
    cmp     r0, r1
    bgt     dash                                                @ if the input time is greater than the dash time, it is a dash, if it is smaller it is a dot

//
// subroutine to handle dot input
//
dot:
    ldr     r0, =dot_msg                @ prints message when dot inputted
    bl      printf                  
    movs    r0, #0
    bl      morse_parser                @ pass a 0 to the .c file to show a dot has been inputted
    b       finish
//
// subroutine to handle dash input
// 
dash:
    ldr     r0, =dash_msg               @ prints message when dash inputted
    bl      printf
    movs    r0, #1  
    bl      morse_parser                @ pass a 1 to the .c file to show a dash has been inputted
    b       finish
//
// subroutine to reset alarm
//
finish:
    bl      set_alarm                   @ resets alarm as button has been pressed so input must continue
    
    pop     {pc}                        @ Exit the interrupt handler

@ Set data alignment
.data
    .align 4
    dash_msg:           .asciz "-"
    dot_msg:            .asciz "."
