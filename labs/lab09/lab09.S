#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified                 @ Specify unified assembly syntax
.cpu    cortex-m0plus           @ Specify CPU type is Cortex M0+
.thumb                          @ Specify thumb assembly for RP2040
.global main_asm                @ Provide program starting address to the linker
.align 4                        @ Specify code alignment

.equ    DIR_IN,   4             @ Specify input direction for a GPIO pin
.equ    DIR_OUT,  1              @ Specify output direction for a GPIO pin 

.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)

@ Entry point to the ASM portion of the program
main_asm:
@ Enable and initialise the RP2040 ADC to allow the temperature diode to be read.
    bl      asm_adc_init
    ldr     r0, =DIR_IN                             @ load the input direction to r0
    bl      asm_adc_select_input                    @ select the input
    bl      install_alrm_isr                        @i nstall the alarm
    ldr     r4, =#DFLT_ALARM_TIME                   @ set the default alarm time
    bl      set_alarm                               @ branch to set alarm
    ldr     r0, =(TIMER_BASE + TIMER_INTE_OFFSET)   @ load into r0
    ldr     r1, =#1                                 @ set r1 to 1
    str     r1, [r0]                                @ store r1 in r0

loop:
    @ interrupt loop - read the adc continuously
    wfi    
    bl      asm_adc_read 
    b       loop

@ Use an alarm interrupt handler to implement an infinite loop that periodically reads the temperature diode value (e.g., every 1 second) and store it to a shared data-segment (you can re-use your own code from assignment #01 to initialise the alarm ISR and the alarm interrupt handler).
@ Call an appropriate function, that you define in the C portion of your code, to convert the raw temperature diode reading into an actual temperature reading and pass the raw value retrieved from the shared data segment to that function.

// set_alarm, install_alrm_isr and alrm_isr from my assignment 1

// Enable alarm timer interrupts and set an alarm
set_alarm:
    // Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
    ldr     r1, =(TIMER_BASE + TIMER_TIMELR_OFFSET)
    ldr     r2, [r1]
    movs    r1, r4
    add     r1, r1, r2
    // Push the updated value to (TIMER_BASE + TIMER_ALARM0_OFFSET)
    ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET)
    str     r1, [r2]
    // Exit subroutine
    bx      lr

// Sets up the alrm_isr in the RAM vector table and enables the correct interrupt
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

// Service the pending interrupt from the ALARM0 TIMER
alrm_isr:
    // Perform required functionality (e.g. toggle the LED)
    // Subroutine to toggle the LED GPIO pin value
    push    {lr}                                         @ Store the link register to the stack as we will call nested subroutines
    ldr     r0, =(TIMER_BASE + TIMER_INTR_OFFSET)        @ r0 is timer info
    ldr     r1, =#1                                      @ load 1 into r1
    str     r1, [r0]                                     @ store in address of r0
    bl      set_alarm                                    @ branch to set alarm

    // Exit ISR
    pop     {pc}                      @ Pop the link register from the stack to the program counter

@ Set data alignment
.data
    .align 4
