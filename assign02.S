#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified                                                 @ Specify unified assembly syntax
.cpu    cortex-m0plus                                           @ Specify CPU type is Cortex M0+
.thumb                                                          @ Specify thumb assembly for RP2040
.global main_asm                                                @ Provide program starting address to the linker
.align 4                                                        @ Specify code alignment

@ declare binary sequences for dot, dash and space
.equ    DOT,            0b01    @ let dot be 01  
.equ    DASH,           0b10    @ dash is 10  
.equ    SPACE,          0b11    @ space is 11

.equ    DASH_TIME,      250000          @ a press for longer than 0.25 secs can be considered a dash
.equ    SPACE_TIME,     1000000         @ if more than 1 second, this is a space
.equ    SEQ_DONE,       2000000         @ if more than 2 seconds assume the sequence is done

// from assignment 1
.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000        @ Specify the default alarm timeout
.equ    GPIO_BTN_EN,  21                @ Specify pin for the GP21 button
.equ    GPIO_DIR_IN,   0                @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1                @ Specify output direction for a GPIO pin

.equ    GPIO_BTN_DN_MSK, 0x00400000     @ falling edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x00800000     @ rising edge event on GP21 (twice the falling edge)

// these are to be removed by final code -- just checking alarm code
.equ    LED_VAL_ON,    1                @ Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0                @ Specify value that turns the LED "off"
.equ    GPIO_LED_PIN, 25                @ Specify pin for the built-in LED

// from assignment 1
.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)
@ write binary equivalents of each letter and number based on dot/dash combo
.equ    A,          0b0110                              
.equ    B,          0b10010101
.equ    C,          0b10011001
.equ    D,          0b100101
.equ    E,          0b01
.equ    F,          0b01011001
.equ    G,          0101001                              
.equ    H,          0b01010101
.equ    I,          0b01101010
.equ    J,          0b01101010
.equ    K,          0b100110
.equ    L,          0b01100101
.equ    M,          0b1010                          
.equ    N,          0b1001
.equ    O,          0b101010
.equ    P,          0b01101001
.equ    Q,          0b10100110
.equ    R,          0b011001
.equ    S,          0b010101                              
.equ    T,          0b10
.equ    U,          0b010110
.equ    V,          0b01010110
.equ    W,          0b011010
.equ    X,  	    0b10010110
.equ    Y,          0b10011010                          
.equ    Z,          0b10100101
.equ    ZERO,       0b1010101010
.equ    ONE,        0b0110101010
.equ    TWO,        0b0101101010
.equ    THREE,      0b0101011010
.equ    FOUR,       0b0101010110                        
.equ    FIVE,       0b0101010101
.equ    SIX,        0b1001010101
.equ    SEVEN,      0b1010010101
.equ    EIGHT,      0b1010100101
.equ    NINE,       0b1010101001

@ Entry point to the ASM portion of the program
main_asm:
    bl      init_leds
    bl      init_btn                                @ initialise the button
    bl      get_time
    bl      install_alrm_isr                        @ method to install the alarm isr
    bl      install_gpio_isr                        @ method to install the spio isr
    ldr     r4, =DFLT_ALARM_TIME                    @ load the default alarm time into the r4 register
    bl      set_alarm                               @ Set a new alarm
    // Enable alarm timer interrupts using the (TIMER_BASE + TIMER_INTE_OFFSET) register
    ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)   @ load the value of (TIMER_BASE + TIMER_INTE_OFFSET) into r2
    movs    r1, #1                                  @ move 1 to r1
    str     r1, [r2]                                @ store the value of r1 to the address at r2

main_loop:
    wfi                         @ wait for an interrupt
    b       main_loop           @ Infinite loop 

get_time:
    ldr     r2, =TIMER_BASE
    ldr     r1, [r2, #TIMER_TIMELR_OFFSET]

init_leds:
    push    {lr}
    movs    r0, #GPIO_LED_PIN          @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_init              @ Call the subroutine to initialise the GPIO pin specified by r0
    movs    r0, #GPIO_LED_PIN          @ This value is the GPIO LED pin on the PI PICO board
    movs    r1, #GPIO_DIR_OUT          @ We want this GPIO pin to be setup as an output pin
    bl      asm_gpio_set_dir           @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
    pop     {pc}

init_btn:
//code goes here to initialise the button 
    push    {lr}
    movs    r0, #GPIO_BTN_EN
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN_EN    @ GP21 is the button being used
    movs    r1, #GPIO_DIR_IN    @ set button as input
    bl      asm_gpio_set_dir 
    movs    r0, GPIO_DIR_IN
    bl      asm_gpio_set_dir 
    movs    r0, #GPIO_BTN_EN
    bl      asm_gpio_set_irq
    pop     {pc}

set_alarm:
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
    // Disable pending interrupt from TIMER by writing correct value to (TIMER_BASE + TIMER_INTR_OFFSET)
    ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)
    movs    r1, #1
    str     r1, [r2]
    // Exit ISR
    pop     {pc}                      @ Pop the link register from the stack to the program counter

// From assignment 1: Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
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

.thumb_func

// Service the pending interrupt from the GPIO
gpio_isr:
    push    {lr}
    
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

falling_edge:
    ldr     r0, =falling_edge_msg                                
    bl      printf                                              @ Print falling-edge message   
    // GET TIME & STORE IN R5
    bl      start_timer
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)        @ Load the address of the raw interrupts register into r2
    ldr     r0, =GPIO_BTN_DN_MSK                                @ Load the enable button mask into r0
    str     r0, [r2]                                            @ Push this value to the raw interrupts register to disable the pending interrupt from GPIO
    b       finish

rising_edge:
    ldr     r0, =rising_edge_msg
    bl      printf                                              @ Print rising-edge message
    // GET TIME & STORE IN R6
    // BRANCH TO DOT_DASH SUBROUTINE
    bl      end_timer
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)        @ Load the address of the raw interrupts register into r2
    ldr     r0, =GPIO_BTN_UP_MSK                                @ Load the enable button mask into r0
    str     r0, [r2]                                            @ Push this value to the raw interrupts register to disable the pending interrupt from GPIO
    b       finish

finish:
    pop     {pc}                                                @ Exit the interrupt handler


@ Set data alignment
.data
    .align 4
    falling_edge_msg:   .asciz "Button pressed.\n"
    rising_edge_msg:    .asciz "Button released.\n"
