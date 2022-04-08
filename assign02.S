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

.equ    GPIO_BTN_DN_MSK, 0x00400000     @ falling edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x00800000     @ rising edge event on GP21

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
    b       main_asm            @ Infinite loop

main_loop:
    wfi                         @ wait for an interrupt
    b       main_loop           @ Infinite loop 

install_gpio_isr:

install_alrm_isr:

gpio_isr:

alrm_isr:

set_alarm:


@ Set data alignment
.data
    .align 4
