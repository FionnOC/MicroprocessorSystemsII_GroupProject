#include <stdio.h>
#include <stdlib.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "hardware/pio.h"
#include "hardware/clocks.h"
#include "assign02.pio.h"
#include "hardware/watchdog.h"
#include <time.h>

#define IS_RGBW true        // Will use RGBW format
#define NUM_PIXELS 1        // There is 1 WS2812 device in the chain
#define WS2812_PIN 28       // The GPIO pin that the WS2812 connected to

char morse_letters[] = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
                        'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 
                        'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 
                        'Y', 'Z', '1', '2', '3', '4', '5', '6', 
                        '7', '8', '9', '0', '?'};
int morse_encoder[] = {501, 5100, 51010, 5100, 50, 50010, 5110, // A-G
                        50000, 500, 50111, 5101, 50100, 511, 510, // H-N
                        5111, 50110, 51101, 5010, 5000, 51, 5001, // O-U
                        50001, 5011, 51001, 51011, 51100, 501111, // V-1
                        500111, 500011, 500001, 500000, 510000, // 2-6
                        511000, 511100, 511110, 511111}; // 7-0
char* morsetable[] = {
    // Letters A-Z (indices 0-25)
    ".-", "-...", "-.-.", "-..", ".", "..-.", "--.", "....",
    "..", ".---", "-.-", ".-..", "--", "-.", "---", ".--.",
    "--.-", ".-.", "...", "-", "..-", "...-", ".--", "-..-",
    "-.--", "--..", 
    // Digits start here (indices 26-35)
    ".----", "..--", "...--", "....-", "....",
    "-...", "--...", "---..", "----.", "-----"
};

int lives = 3;
int int_maker = 5;
int count;
int level1_finished = 0;
int finished_game = 0;
int level = 0;


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
    if (time_diff > 250000) {
        int_maker = int_maker * 10;
        int_maker++;
    }
    else {
        int_maker = 10*int_maker;
    }
    //watchdog_update();
    return time_diff;
}

void welcomeScreen() {
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
    printf("|   "".----""  - Level #1 - CHARS (EASY)          |\n");
    printf("|   ""..---""  - Level #2 - CHARS (HARD)          |\n");
    printf("|   ""...--""  - Level #3 - WORDS (EASY)          |\n");
    printf("|   ""....-""  - Level #4 - WORDS (HARD)          |\n");
    printf("+---------------------------------------------+\n");
}

// function to display which level has been chosen
int levelChooser() {
    printf("Level code: \n");
    while (int_maker <= 501111) {
        if (int_maker == 501111) {
            printf("%i", int_maker);
            return 1;
        }
        else if (int_maker == 500111) {
            printf("%i", int_maker);
            return 2;
        }
        else if (int_maker == 500011) {
            printf("%i", int_maker);
            return 3;
        }
        else if (int_maker == 500001) {
            printf("%i", int_maker);
            return 4;
        }
    }
    printf("This is not a valid level, please retry...\n");
    return 100;
}

void life_indicator (int lives) {
    if (lives == 3) {
        put_pixel(urgb_u32(0x00, 0x2F, 0x00)); // green
    }
    else if (lives == 2) {
        put_pixel(urgb_u32(0x2F, 0x2F, 0x00)); // yellow
    }
    else if (lives == 1) {
        put_pixel(urgb_u32(0x2F, 0xC, 0x00)); // orange
    }
    else if (lives == 0) {
        put_pixel(urgb_u32(0x2F, 0x00, 0x00)); // red
    }
    else put_pixel(urgb_u32(0x00, 0x00, 0x2F)); // blue
}

// function play the game based on what level is chosen

void play() {
    int value = (rand() % 36);

    if(level == 1 && level1_finished != 1) {
        int_maker = 5;
        // need to update the morse values to have the letters and binary equivs in separate arrays
        printf("Enter the letter %c in Morse Code (Hint: %s)\n", morse_letters[value], morsetable[value] );

        while(int_maker <= morse_encoder[value] && count != 5) {
            if(int_maker == morse_encoder[value]) {
                printf("That is correct! Good job!\n");
                count++;
                if(count == 5){
                level1_finished = 1;
                }
                if(lives != 3){
                lives++;
                }
                return;
            }            
        }
        printf("That is incorrect :(\n");
        count = 0;
        lives--;
        return;
    }


    if(level == 2 || count == 5) {
        int_maker = 5;
        

        if(count == 5){
            printf("Well Done progressed To Level 2!\n");
            count = 0;
            level = 2;
        }

      
        // need to update the morse values to have the letters and binary equivs in separate arrays
        printf("Enter the letter %c in Morse Code (Hint: %s)\n", morse_letters[value], morsetable[value] );

        while(int_maker <= morse_encoder[value] && count != 5) {
            if(int_maker == morse_encoder[value]) {
                printf("That is correct! Good job!\n");
                count++;
                if(count == 5){
                    finished_game = 1;
                }
                if(lives != 3){
                lives++;
                }
                return;
            }            
        }
        printf("That is incorrect :(\n");
        count = 0;
        lives--;
        return;
    }
}

// function to start the game
void start_game() {
    // set the LED to green and initialise a counter
    put_pixel(urgb_u32(0x00, 0x2F, 0x00)); // green
    count = 0;
    
    // while lives have not run out and a 'win' (counter=5) has not been achieved
    while(lives != 0 && finished_game != 1) {
        // start game at the correct level
        play();
        // set the LED
        life_indicator(lives);
        printf("\n%i\n", count);
    }

    if(lives == 0){
        printf("Ran out of Lives!");
    }

    if(finished_game == 1){
        printf("Congratulations You Won!\n");
        finished_game = 0;
    }
}
 
 
/*
 * Main entry point for the code - simply calls the main assembly function.
 */
int main() {
    
    // srand(time(NULL)) goes at start of main to allow for rand() to be used properly
    srand(time(NULL));
    stdio_init_all();// Initialise all basic IO
/*
    if (watchdog_caused_reboot()) {
            printf("Rebooted by Watchdog!\n");
            return 0;
        } else {
            printf("Clean boot\n");
        }

    watchdog_enable(8000000, 1);
*/

    // display the welcome screen
    welcomeScreen();

    // Initialise the PIO interface with the WS2812 code
    PIO pio = pio0;
    uint offset = pio_add_program(pio, &ws2812_program);
    ws2812_program_init(pio, 0, offset, WS2812_PIN, 800000, IS_RGBW);
    put_pixel(urgb_u32(0x00, 0x00, 0x2F)); // Set the colour to blue

    main_asm();

    // choosing a level
  
    while(level == 0) {

        while ((level < 1 || level > 4) && level != 100) {
            level = levelChooser();
        }

        if(level != 100) {
            printf("\nYou have selected Level %d.\n\n", level);
        }

        else {
            printf("|   Enter Sequence on GP21 to choose Level    |\n");
            printf("|                                             |\n");
            printf("|   "".----""  - Level #1 - CHARS (EASY)          |\n");
            printf("|   ""..---""  - Level #2 - CHARS (HARD)          |\n");
            printf("|   ""...--""  - Level #3 - WORDS (EASY)          |\n");
            printf("|   ""....-""  - Level #4 - WORDS (HARD)          |\n");
            level = 0;
            int_maker = 5;
        }
        
    }

    start_game();
    if(lives == 0) {
        printf("GAME OVER!!! Better luck next time!\n\n");
    }
    return 0;
}
