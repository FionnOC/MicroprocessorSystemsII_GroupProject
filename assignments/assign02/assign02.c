#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"

// Must declare the main assembly entry point before use.
void main_asm();

// Initialise a GPIO pin – see SDK for detail on gpio_init()
void asm_gpio_init(uint pin) {
    gpio_init(pin);
}

// Set direction of a GPIO pin – see SDK for detail on gpio_set_dir()
void asm_gpio_set_dir(uint pin, bool out) {
    gpio_set_dir(pin, out);
}

// Get the value of a GPIO pin – see SDK for detail on gpio_get()
bool asm_gpio_get(uint pin) {
    return gpio_get(pin);
}

// Set the value of a GPIO pin – see SDK for detail on gpio_put()
void asm_gpio_put(uint pin, bool value) {
    gpio_put(pin, value);
}

// Enable falling-edge interrupt – see SDK for detail on gpio_set_irq_enabled()
void asm_gpio_set_irq_fall(uint pin) {
    gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_FALL, true);
}

// Enable rising-edge interrupt – see SDK for detail on gpio_set_irq_enabled()
void asm_gpio_set_irq_rise(uint pin) {
    gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_RISE, true);
}
/*
 * Main entry point for the code - simply calls the main assembly function.
 */
int main() {
    stdio_init_all();// Initialise all basic IO
    printf("+---------------------------------------------+\n");
    printf("|          Assignment 2 Lab Group 20          |\n");
    printf("+---------------------------------------------+\n");
    printf("|   *       *******    *    ******  *     *   |\n");
    printf("|   *       *         * *   *     * **    *   |\n");
    printf("|   *       *        *   *  *     * * *   *   |\n");
    printf("|   *       ******* ******* ******  *  *  *   |\n");
    printf("|   *       *       *     * *   *   *   * *   |\n");
    printf("|   *       *       *     * *    *  *    **   |\n");
    printf("|   ******* ******* *     * *     * *     *   |\n");
    printf("|                                             |\n");
    printf("|   *     * ******* ******   *****  *******   |\n");
    printf("|   **   ** *     * *     * *     * *         |\n");
    printf("|   * * * * *     * *     * *       *         |\n");
    printf("|   *  *  * *     * ******   *****  *******   |\n");
    printf("|   *     * *     * *   *         * *         |\n");
    printf("|   *     * *     * *    *  *     * *         |\n");
    printf("|   *     * ******* *     *  *****  *******   |\n");
    printf("+---------------------------------------------+\n");
    printf("|   Enter Sequence on GP21 to choose Level    |\n");
    printf("|                                             |\n");
    printf("|   ""-----""  - Level #1 - CHARS (EASY)          |\n");
    printf("|   "".----""  - Level #2 - WORDS (HARD)          |\n");
    printf("+---------------------------------------------+\n");
    main_asm();
    return(0);
}
