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

.equ    GPIO_BTN_DN_MSK, 0x00400000   @ Mask for falling-edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x00800000   @ Mask for rising-edge event on GP21
.equ    GPIO_BTN,  21                 @ Specify pin for the GPIO button

.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)


@ Entry point to the ASM portion of the program
main_asm:
    bl    init_btn                      @ Use asm_gpio_set_irq C function to set up rising and falling-edge interrutps
    bl    install_gpio_isr              @ Execute the subroutine to install the interrupt handler for button presses/releases
loop:
    wfi                                 @ Wait here until any interrupt fires
    b     loop                          @ Always branch back to loop

init_btn:
    push    {lr}                        @ Push the link register to the stack as nested subroutines will be used
    
    movs    r0, #GPIO_BTN               @ Store the pin nuber of the button to r0
    bl      asm_gpio_init               @ Call the subroutine to initialise the button pin
    movs    r0, #GPIO_BTN               @ Once again, store the pin number of the button pin to r0
    movs    r1, #GPIO_DIR_IN            @ We want this pin to be set as an input
    bl      asm_gpio_set_dir            @ Call the subroutine to set the button pin as an input
    movs    r0, #GPIO_BTN               @ Once again, store the pin number of the enable button pin to r0
    bl      asm_gpio_set_irq            @ Call the subroutine to enable a rising and falling-edge interrupts at this pin

    pop     {pc}                        @ Pop the link register from the stack to the program counter                       


//
// Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
//
install_gpio_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)        @ Load the address of the RAM vector table to r2
    ldr     r1, [r2]                                    @ Load the value stored at this address to r1
    movs    r2, #GPIO_ISR_OFFSET                        @ Load the offset value associated with the GPIO ISR to r2
    add     r2, r1                                      @ The correct address is now stored in r2
    ldr     r0, =gpio_isr                               @ Load the address of the interrupt handler to r0
    str     r0, [r2]                                    @ The gpio_isr handler is now stored at the correct offset for GPIO in the vector table

    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   @ Load the address of the interrupt clear-pending register to r2
    ldr     r0, =0x2000                                 @ Load a mask with a high value at bit 13 to r0
    str     r0, [r2]                                    @ Write the mask value to the ICPR register

    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   @ Load the address of the interrupt set-enable register to r2
    ldr     r0, =0x2000                                 @ Once again, load the mask value to r0
    str     r0, [r2]                                    @ Write the mask value to the ISER register

    bx      lr                      

//
// Service the pending interrupt from the GPIO
//
.thumb_func
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
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)        @ Load the address of the raw interrupts register into r2
    ldr     r0, =GPIO_BTN_DN_MSK                                @ Load the enable button mask into r0
    str     r0, [r2]                                            @ Push this value to the raw interrupts register to disable the pending interrupt from GPIO
    b       finish

    rising_edge:
    ldr     r0, =rising_edge_msg
    bl      printf                                              @ Print rising-edge message
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)        @ Load the address of the raw interrupts register into r2
    ldr     r0, =GPIO_BTN_UP_MSK                                @ Load the enable button mask into r0
    str     r0, [r2]                                            @ Push this value to the raw interrupts register to disable the pending interrupt from GPIO
    b       finish

    finish:
    pop     {pc}                                                @ Exit the interrupt handler

install_alrm_isr:

alrm_isr:

set_alarm:


.align 4
falling_edge_msg:         .asciz "Button pressed.\n"
rising_edge_msg:          .asciz "Button released.\n"

.data
