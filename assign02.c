#include <stdio.h>
#include <stdlib.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "hardware/pio.h"
#include "hardware/clocks.h"
#include "assign02.pio.h"
#include "hardware/watchdog.h"

#define IS_RGBW true        // Will use RGBW format
#define NUM_PIXELS 1        // There is 1 WS2812 device in the chain
#define WS2812_PIN 28       // The GPIO pin that the WS2812 connected to

char letters[] = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '1', '2', '3', '4', '5', '6', '7', '8', '9', '?'};

int lives = 3;

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
void asm_gpio_set_irq(uint pin) {
    gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_FALL|GPIO_IRQ_EDGE_RISE, true);
}

void levelChooser(int input);

int morse_buffer = 1;
int level_flag = 0;

void morse (int input){
    if (input == 0){
        printf("Dot .\n");
        morse_buffer = morse_buffer * 10;
    }
    else if (input == 1){
        printf("Dash -\n");
        morse_buffer = (morse_buffer * 10) + 1;
    }
    else if (input == 2){
        if (level_flag == 0){
            levelChooser(morse_buffer);
        }
        if (morse_buffer == 1001){
            printf(". . -\n");
            morse_buffer = 1;
        }
    }
    else printf("Error.\n");
}


// wrapper function to push 32-bit RGB colour value out to LED serially
static inline void put_pixel(uint32_t pixel_grb) {
    pio_sm_put_blocking(pio0, 0, pixel_grb << 8u);
}

// generate a 32-bit int composit RGB value by combining individual 8-bit params
static inline uint32_t urgb_u32(uint8_t r, uint8_t g, uint8_t b) {
    return  ((uint32_t) (r) << 8)  |
            ((uint32_t) (g) << 16) |
            (uint32_t) (b);
}

absolute_time_t start_time;
void start_timer(){
    start_time = get_absolute_time();
}

int end_timer(){
    int time_diff = (int) absolute_time_diff_us(start_time, get_absolute_time());
    printf("%d\n", time_diff);
    watchdog_update();
    return time_diff;
}

void life_indicator (int lives) {
    if (lives == 3){
        put_pixel(urgb_u32(0x00, 0x2F, 0x00)); // green
    }
    else if (lives == 2){
        put_pixel(urgb_u32(0x2F, 0x2F, 0x00)); // yellow
    }
    else if (lives == 1){
        put_pixel(urgb_u32(0x2F, 0xC, 0x00)); // orange
    }
    else if (lives == 0){
        put_pixel(urgb_u32(0x2F, 0x00, 0x00)); // red
    }
    else put_pixel(urgb_u32(0x00, 0x00, 0x2F)); // blue
}

// function to display which level has been chosen
void levelChooser(int input) {
    //char inp = letters[index];
    // level 1
    if(input == 101111) {
        // level chosen so set LED to green
        put_pixel(urgb_u32(0x00, 0x2F, 0x00)); // green
        printf("Level 1 starting...\n\n");
    }
    // level 2
    else if(input == 100111) {
        // level chosen so set LED to green
        put_pixel(urgb_u32(0x00, 0x2F, 0x00)); // green
        printf("Level 2 starting...\n\n");
    }
    else {
        printf("Incorrect morse sequence entered... Please retry!\n\n");
        printf("Level 1 = .----\n");
        printf("Level 2 = ..---\n");
        printf("User Input: ");
    }
}

/*
 * Main entry point for the code - simply calls the main assembly function.
 */
int main() {
    stdio_init_all();// Initialise all basic IO

    if (watchdog_caused_reboot()) {
            printf("Rebooted by Watchdog!\n");
            return 0;
        } else {
            printf("Clean boot\n");
        }

    watchdog_enable(9000, 1);
    // initialise the button for falling edge and rising edge design
    //gpio_set_irq_enabled(21, GPIO_IRQ_EDGE_FALL, true);
    //gpio_set_irq_enabled(21, GPIO_IRQ_EDGE_RISE, true);

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
    printf("|   "".----""  - Level #2 - CHARS (HARD)          |\n");
    printf("+---------------------------------------------+\n");

    // Initialise the PIO interface with the WS2812 code
    PIO pio = pio0;
    uint offset = pio_add_program(pio, &ws2812_program);
    ws2812_program_init(pio, 0, offset, WS2812_PIN, 800000, IS_RGBW);
    put_pixel(urgb_u32(0x00, 0x00, 0x2F)); // Set the colour to blue


    main_asm();
    return 0;
}
