#include "hardware/regs/addressmap.h"
#include "hardware/regs/m0plus.h"

.syntax unified                 @ Specify unified assembly syntax
.cpu    cortex-m0plus           @ Specify CPU type is Cortex M0+
.thumb                          @ Specify thumb assembly for RP2040
.global main_asm                @ Provide program starting address to the linker
.align 4                        @ Specify code alignment

.equ    SLEEP_TIME, 500         @ Specify the sleep time (in ms)
.equ    LED_GPIO_PIN, 25        @ Specify the pin that the LED is connected to
.equ    LED_GPIO_OUT, 1         @ Specify the direction of the GPIO pin
.equ    LED_VALUE_ON, 1         @ Specify the value that turns the LED "on"
.equ    LED_VALUE_OFF, 0        @ Specify the value that turns the LED "off"
.equ    SVC_ISR_OFFSET, 0x2C    @ The SVC is entry 11 in the vector table
.equ    SVC_MAX_INSTRS, 0x01    @ Maximum allowed SVC subroutines

@ Entry point to the ASM portion of the program
main_asm:
    bl      init_gpio_led       @ Initialise the GPIO LED pin
    bl      install_svc_isr     @ Install the SVC interrupt service routine
loop:
    svc     #0                  @ Call the SVC ISR with value 0 (turns on LED)
    nop                         @ Add a no-op instruction for alignment after SVC
    bl      do_sleep            @ Short pause before proceeding
    svc     #1                  @ Call the SVC ISR with value 1 (turns off LED)
    nop                         @ Add a no-op instruction for alignment after SVC
    bl      do_sleep            @ Add a short pause before proceeding
    b       loop                @ Always jump back to the start of the loop

@ Subroutine used to introduce a short delay in the application
do_sleep:
    @ Add assembly code to implement the sleep delay using sleep_ms
    push    {lr}                 @ Store the link register to the stack as we will call nested subroutines
    ldr     r0, =SLEEP_TIME      @ Set the value of SLEEP_TIME we want to wait for
    bl      sleep_ms             @ Sleep until SLEEP_TIME has elapsed then toggle the LED GPIO pin
    pop     {pc}                 @ Pop the link register from the stack to the program counter
@ Subroutine used to initialise the PI Pico built-in LED
init_gpio_led:
    @ Add assembly code to initialise the LED GPIO pin>
    movs    r0, #LED_GPIO_PIN           @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_init               @ Call the subroutine to initialise the GPIO pin specified by r0
    movs    r0, #LED_GPIO_PIN           @ This value is the GPIO LED pin on the PI PICO board
    movs    r1, #LED_GPIO_OUT           @ We want this GPIO pin to be setup as an output pin
    bl      asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
@ Subroutine used to install the SVC interrupt service handler
install_svc_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ ARM Cortex-M0+ registers start at PPB_BASE. the M0_PLUS_VTOR_OFFSET holds the vector table offset address. Add them and load into r2
    ldr     r1, [r2]                                @ Load the value at the address found at r2 into the register r1
    movs    r2, #SVC_ISR_OFFSET                     @ move the value of #SVC_ISR_OFFSET into r2
    add     r2, r1                                  @ adds the value in r1 to the current value of r2
    ldr     r0, =svc_isr                            @ load the value of svc_isr into r0
    str     r0, [r2]                                @ store the value in r0 to the address found in r2
    b       loop                                    @ loop -- replaced bx lr with this since code was getting stuck in an infinite loop when bx lr was present

@ SVC interrupt service handler routine
.thumb_func                     @ Required for all interrupt service routines
svc_isr:
    push    {lr}                @ Store the link register to the stack as we will call nested subroutines
    ldr     r0, [sp, #0x1C]     @ Store the value at the address found at sp into r0 with an offset of 28
    subs    r0, #0x2            @ subtract 2 from the value in r0
    ldr     r0, [r0]            @ Load the value at the address found in r0 into r0
    ldr     r1, =#0xFF          @ load 255 into register r1
    ands    r0, r1              @ logically and r0 and r1
    cmp     r0, #SVC_MAX_INSTRS @ compare the value in r0 with the value of #SVC_MAX_INSTRS
    bgt     svc_done            @ if the Z,N,V flags are all clear OR if Z is clear, but N and V both set then branch to svc_done
    adr     r1, svc_jmptbl      @ load the address of svc_jmptl into r1
    lsls    r0, #2              @ logically shift r0 left by 2 bits
    ldr     r1, [r1, r0]        @ Store the value at the address found at r1 into r1 with the offset of r0
    mov     pc, r1              @ move the value in r1 into pc register
svc_done:
    pop     {pc}                @ Pop the link register from the stack to the program counter

@ First function of SVC subroutine - turn on the LED
svc_num0:
    @<TODO – add assembly code to turn on the LED>
    movs    r0, #LED_GPIO_PIN   @ Set the LED GPIO pin number to r0 for use by asm_gpio_get
    movs    r1, #LED_VALUE_ON   @ want to turn LED on
    bl      asm_gpio_put        @ Update the the value of the LED GPIO pin (based on value in r1)
    b       svc_done            @ Branch back to the main ISR when done
    
@ Second function of SVC subroutine - turn off the LED
svc_num1:
    @<TODO – add assembly code to turn off the LED>
    movs    r0, #LED_GPIO_PIN   @ Set the LED GPIO pin number to r0 for use by asm_gpio_get
    movs    r1, #LED_VALUE_OFF  @ want to turn LED off
    bl      asm_gpio_put        @ Update the the value of the LED GPIO pin (based on value in r1)
    b       svc_done            @ Branch back to the main ISR when done

@ SVC function entry jump table.
.align 2
svc_jmptbl:
    .word svc_num0              @ Entry zero goes to SVC function #0.
    .word svc_num1              @ Entry one goes to SVC function #1.
    .word 0                     @ Null termination of the jump table.

@ Set data alignment
.data
    .align 4
