#include <stdio.h>
#include <stdlib.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "hardware/pio.h"
#include "hardware/clocks.h"
#include "assign02.pio.h"
#include "hardware/watchdog.h"
#include <time.h>

#define IS_RGBW true  // Will use RGBW format
#define NUM_PIXELS 1  // There is 1 WS2812 device in the chain
#define WS2812_PIN 28 // The GPIO pin that the WS2812 connected to

/**
 * @brief character array to store the alphabet
 *
 */
char morse_letters[] = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
                        'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
                        'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
                        'Y', 'Z', '1', '2', '3', '4', '5', '6',
                        '7', '8', '9', '0', '?'};

/**
 * @brief   int array which stores the alphabet in binary, 0's as dots and 1's as dashes.
 *           a random number was placed at the beginning of each to prevent leading 0's from being a problem
 */
int morse_encoder[] = {501, 51000, 51010, 5100, 50, 50010, 5110, // A-G
                       50000, 500, 50111, 5101, 50100, 511, 510, // H-N
                       5111, 50110, 51101, 5010, 5000, 51, 5001, // O-U
                       50001, 5011, 51001, 51011, 51100, 501111, // V-1
                       500111, 500011, 500001, 500000, 510000,   // 2-6
                       511000, 511100, 511110, 511111};          // 7-0

/**
 * @brief character array which stores the corresponding morse for each number and letter
 *
 */
char *morsetable[] = {
    // Letters A-Z (indices 0-25)
    ".-", "-...", "-.-.", "-..", ".", "..-.", "--.", "....",
    "..", ".---", "-.-", ".-..", "--", "-.", "---", ".--.",
    "--.-", ".-.", "...", "-", "..-", "...-", ".--", "-..-",
    "-.--", "--..",
    // Digits start here (indices 26-35)
    ".----", "..--", "...--", "....-", "....",
    "-...", "--...", "---..", "----.", "-----"};

/**
 * @brief global variables initialised here
 *
 */
int lives = 3;
int int_maker = 5;
int count;
int level1_finished = 0;
int finished_game = 0;
int level = 0;
int alarm_flag = 0;
int total_lives_lost = 0;
int total_lives_gained = 0;

/**
 * @brief Must declare the main assembly entry point before use.
 *
 */
void main_asm();

/**
 * @brief  Initialise a GPIO pin – see SDK for detail on gpio_init()
 *
 * @param pin
 */
void asm_gpio_init(uint pin)
{
    gpio_init(pin);
}

/**
 * @brief  Set direction of a GPIO pin – see SDK for detail on gpio_set_dir()
 *
 * @param pin
 * @param out
 */
void asm_gpio_set_dir(uint pin, bool out)
{
    gpio_set_dir(pin, out);
}

/**
 * @brief Get the value of a GPIO pin – see SDK for detail on gpio_get()
 *
 * @param pin
 * @return true
 * @return false
 */
bool asm_gpio_get(uint pin)
{
    return gpio_get(pin);
}

/**
 * @brief Set the value of a GPIO pin – see SDK for detail on gpio_put()
 *
 * @param pin
 * @param value
 */
void asm_gpio_put(uint pin, bool value)
{
    gpio_put(pin, value);
}

/**
 * @brief Enable falling-edge interrupt – see SDK for detail on gpio_set_irq_enabled()
 *
 * @param pin
 */
void asm_gpio_set_irq(uint pin)
{
    gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_FALL | GPIO_IRQ_EDGE_RISE, true);
}

/**
 * @brief wrapper function to push 32-bit RGB colour value out to LED serially
 *
 * @param pixel_grb
 */
static inline void put_pixel(uint32_t pixel_grb)
{
    pio_sm_put_blocking(pio0, 0, pixel_grb << 8u);
}

/**
 * @brief generate a 32-bit int composit RGB value by combining individual 8-bit params
 *
 * @param r
 * @param g
 * @param b
 * @return uint32_t
 */

static inline uint32_t urgb_u32(uint8_t r, uint8_t g, uint8_t b)
{
    return ((uint32_t)(r) << 8) |
           ((uint32_t)(g) << 16) |
           (uint32_t)(b);
}

absolute_time_t start_time;

/**
 * @brief fetches and stores the current time
 *
 */
void start_timer()
{
    start_time = get_absolute_time();
}

/**
 * @brief calculates the difference between the rising edge and the falling edge to differentiate between a dot and dash
 *
 * @return int
 */
int end_timer()
{
    int time_diff = (int)absolute_time_diff_us(start_time, get_absolute_time());
    return time_diff;
}

/**
 * @brief sets the alarm flag; tells the rest of the .c code that the alarm in the .S file has been fired
 *
 */
void alarm_call()
{
    alarm_flag = 1;
}

/**
 * @brief takes in a dot and dash from .S and updates current input
 *
 * @param bit_arm
 */
void morse_parser(int bit_arm)
{

    if (bit_arm == 1)
    {
        int_maker = int_maker * 10;
        int_maker++;
    }
    else
    {
        int_maker = 10 * int_maker;
    }

    // watchdog_update();
}

/**
 * @brief print the welcome screen
 *
 */
void welcomeScreen()
{
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
    printf("|   "
           ".----"
           "  - Level #1 - CHARS (EASY)          |\n");
    printf("|   "
           "..---"
           "  - Level #2 - CHARS (HARD)          |\n");
    printf("+---------------------------------------------+\n");
}

/**
 * @brief function to display which level has been chosen
 *
 * @return int
 */
int levelChooser()
{
    printf("Level code: \n");
    while (int_maker <= 501111 && alarm_flag != 1)
    {
        if (int_maker == 501111)
        {

            return 1;
        }
        else if (int_maker == 500111)
        {

            return 2;
        }
        else if (int_maker == 500011)
        {

            return 3;
        }
        else if (int_maker == 500001)
        {

            return 4;
        }
    }
    printf("This is not a valid level, please retry...\n");
    return 100;
}

/**
 * @brief changes colour of the LED depending on the life count
 *
 * @param lives
 */
void life_indicator(int lives)
{
    if (lives == 3)
    {
        put_pixel(urgb_u32(0x00, 0x2F, 0x00)); // green
    }
    else if (lives == 2)
    {
        put_pixel(urgb_u32(0x2F, 0x2F, 0x00)); // yellow
    }
    else if (lives == 1)
    {
        put_pixel(urgb_u32(0x2F, 0xC, 0x00)); // orange
    }
    else if (lives == 0)
    {
        put_pixel(urgb_u32(0x2F, 0x00, 0x00)); // red
    }
    else
        put_pixel(urgb_u32(0x00, 0x00, 0x2F)); // blue
}

/**
 * @brief Prints the Alphanumeric Character equivalent of the morse input
 *
 */
void print_input_result()
{

    switch (int_maker)
    {
    case 501:
        printf("A");
        break;

    case 51000:
        printf("B");
        break;

    case 51010:
        printf("C");
        break;

    case 5100:
        printf("D");
        break;

    case 50:
        printf("E");
        break;

    case 50010:
        printf("F");
        break;

    case 5110:
        printf("G");
        break;

    case 50000:
        printf("H");
        break;

    case 500:
        printf("I");
        break;

    case 50111:
        printf("J");
        break;

    case 5101:
        printf("K");
        break;

    case 50100:
        printf("L");
        break;

    case 511:
        printf("M");
        break;

    case 510:
        printf("N");
        break;

    case 5111:
        printf("O");
        break;

    case 50110:
        printf("P");
        break;

    case 51101:
        printf("Q");
        break;

    case 5010:
        printf("R");
        break;

    case 5000:
        printf("S");
        break;

    case 51:
        printf("T");
        break;

    case 5001:
        printf("U");
        break;

    case 50001:
        printf("V");
        break;

    case 5011:
        printf("W");
        break;

    case 51001:
        printf("X");
        break;

    case 51011:
        printf("Y");
        break;

    case 51100:
        printf("Z");
        break;

    case 511111:
        printf("0");
        break;

    case 501111:
        printf("1");
        break;

    case 500111:
        printf("2");
        break;

    case 500011:
        printf("3");
        break;

    case 500001:
        printf("4");
        break;

    case 500000:
        printf("5");
        break;

    case 510000:
        printf("6");
        break;

    case 511000:
        printf("7");
        break;

    case 511100:
        printf("8");
        break;

    case 511110:
        printf("9");
        break;
    // operator doesn't match any case constant
    default:
        printf("?");
    }
}

/**
 * @brief function to play the gam based on what level is chosen
 *
 */
void play()
{
    int value = (rand() % 36);

    // if on level 1 and player has not failed ...
    if (level == 1 && level1_finished != 1)
    {
        int_maker = 5; // 5 placed at start of each input to negate problem with leading 0's

        // need to update the morse values to have the letters and binary equivs in separate arrays
        printf("Enter %c in Morse Code (Hint: %s)\n", morse_letters[value], morsetable[value]);

        // while inputting; while input length is less than correct length and while you are on less than 5 attempts, and the alarm flag has not been fired...
        while (int_maker <= morse_encoder[value] && count != 5 && alarm_flag != 1)
        {

            sleep_us(100); // hard fault if delay not here

            // if input is the same as the correct morse value
            if (int_maker == morse_encoder[value])
            {
                printf("\nYou enterd the correct sequence %c\n", morse_letters[value]);
                count++;              // increase count by 1
                total_lives_gained++; // increase stat on total lives earned throughout the game
                if (count == 5)       // if count reaches 5, finished level and leave while loop
                {
                    level1_finished = 1;
                }
                if (lives != 3) // do not add more than 3 lives
                {
                    lives++;
                }
                return;
            }
        }
        // If incorrect...
        printf("\nThe sequence ");
        print_input_result(); // call on function to output letter that the user has inputted
        printf(" you entered did not match %c\n", morse_letters[value]);
        count = 0;          // reset the count
        total_lives_lost++; // increase stat on total lives lost
        lives--;            // decrease player lives by 1
        return;
    }

    // if level 1 completed...
    if (level == 2 || count == 5)
    {
        int_maker = 5; // reset input from user

        if (count == 5)
        {
            printf("Well Done progressed To Level 2!\n");
            count = 0;
            level = 2;
        }

        // need to update the morse values to have the letters and binary equivalents in separate arrays
        printf("Enter %c in Morse Code\n", morse_letters[value], morsetable[value]);

        // level 2 code
        while (int_maker <= morse_encoder[value] && count != 5 && alarm_flag != 1)
        {
            sleep_us(100); // hard fault if no delay

            // if input is the same as correct morse value
            if (int_maker == morse_encoder[value])
            {
                printf("\nYou entered the correct sequence %c\n", morse_letters[value]);
                count++;              // increase count by 1
                total_lives_gained++; // increase stat on total lives gained throughout the game

                if (count == 5) // if count reaches 5, finished level and leave while loop
                {
                    finished_game = 1;
                }
                if (lives != 3) // do not add more than 3 lives
                {
                    lives++;
                }
                return;
            }
        }
        // If incorrect...
        printf("\nThe sequence ");
        print_input_result(); // call on function to output letter that the user has inputted
        printf(" you entered did not match %c\n", morse_letters[value]);
        total_lives_lost++; // increase stat on total lives lost
        count = 0;          // reset the count
        lives--;            // decrease player lives by 1
        return;
    }
}

/**
 * @brief function to start the game
 *
 */
void start_game()
{
    // set the LED to green and initialise a counter
    put_pixel(urgb_u32(0x00, 0x2F, 0x00)); // green
    count = 0;

    // while lives have not run out and a 'win' (counter=5) has not been achieved
    while (lives != 0 && finished_game != 1)
    {
        // start game at the correct level
        play();
        // set the LED
        life_indicator(lives);
        printf("Current Streak : %i\n", count);
        alarm_flag = 0;
    }
}

/**
 * @brief Main entry point for the code - simply calls the main assembly function.
 *
 */
int main()
{

    // srand(time(NULL)) goes at start of main to allow for rand() to be used properly
    srand(time(NULL));
    stdio_init_all(); // Initialise all basic IO

    watchdog_enable(8300, 1);

    if (watchdog_caused_reboot())
    {
        printf("Rebooted by Watchdog!\n");
    }

    // display the welcome screen
    while (1)
    {

        // initialise all the global variables
        lives = 3;
        int_maker = 5;
        count = 0;
        level1_finished = 0;
        finished_game = 0;
        level = 0;
        total_lives_lost = 0;
        total_lives_gained = 0;

        main_asm();      // call on the main_asm subroutine from the .S file
        welcomeScreen(); // output the welcome screen

        // Initialise the PIO interface with the WS2812 code
        PIO pio = pio0;
        uint offset = pio_add_program(pio, &ws2812_program);
        ws2812_program_init(pio, 0, offset, WS2812_PIN, 800000, IS_RGBW);
        put_pixel(urgb_u32(0x00, 0x00, 0x2F)); // Set the colour to blue

        // choose a level
        while (level == 0)
        {

            while ((level < 1 || level > 4) && level != 100)
            {
                level = levelChooser();
            }

            if (level != 100)
            {
                printf("\nYou have selected Level %d.\n\n", level);
            }

            else
            {
                printf("|   Enter Sequence on GP21 to choose Level    |\n");
                printf("|                                             |\n");
                printf("|   "
                       ".----"
                       "  - Level #1 - CHARS (EASY)          |\n");
                printf("|   "
                       "..---"
                       "  - Level #2 - CHARS (HARD)          |\n");

                level = 0;
                int_maker = 5;
                alarm_flag = 0;
            }
        }

        start_game(); // start the game!!

        if (lives == 0) // if player loses the game
        {
            printf("GAME OVER!!! Better luck next time!\n");
        }

        if (finished_game == 1) // if the player wins
        {
            printf("Congratulations you are a master at Morse Code!!!\n");
        }

        printf("+---------------------------+\n");
        printf("| Total Lives Gained :  %-4i|\n", total_lives_gained);
        printf("| Total Lives Lost :    %-4i|\n", total_lives_lost);
        printf("| Total Attempts Made : %-4i|\n", total_lives_gained + total_lives_lost);
        printf("| Sucess Rate :         %i%%|\n", 100 * (total_lives_gained) / (total_lives_gained + total_lives_lost));
        printf("| Level Reached :       %i   |\n", level);
        printf("+---------------------------+\n");

        sleep_ms(2);
    }
}
