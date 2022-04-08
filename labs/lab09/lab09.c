// Must declare the main assembly entry point before use.
#include <stdio.h>
#include <stdlib.h>
#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "hardware/clocks.h"
#include "lab09.pio.h"
//must include the hardware for ADC and GPIO
#include "hardware/adc.h"
#include "hardware/gpio.h"

#define IS_RGBW true        // Will use RGBW format
#define NUM_PIXELS 1        // There is 1 WS2812 device in the chain
#define WS2812_PIN 28       // The GPIO pin that the WS2812 connected to

void main_asm();

static inline void put_pixel(uint32_t pixel_grb) {
    pio_sm_put_blocking(pio0, 0, pixel_grb << 8u);
}

/**
 * @brief Function to generate an unsigned 32-bit composit GRB
 *        value by combining the individual 8-bit paramaters for
 *        red, green and blue together in the right order.
 * 
 * @param r     The 8-bit intensity value for the red component
 * @param g     The 8-bit intensity value for the green component
 * @param b     The 8-bit intensity value for the blue component
 * @return uint32_t Returns the resulting composit 32-bit RGB value
 */

static inline uint32_t urgb_u32(uint8_t r, uint8_t g, uint8_t b) {
    return  ((uint32_t) (r) << 8)  |
            ((uint32_t) (g) << 16) |
            (uint32_t) (b);
}

void asm_adc_init() {
    adc_init();
    adc_set_temp_sensor_enabled(true);
}

void asm_adc_select_input(uint input)  {
    adc_select_input(input);
}

// conversion factor for a 12-bit conversion of raw reading to voltage float
const float conversion_factor = 3.3f / (1 << 12);

// uint16_t asm_adc_read()
void asm_adc_read() {
    // read the data from the temp sensor and store as 'raw'
    uint16_t raw = adc_read();
    // multiply raw by conversion factor to get voltage
    float voltage = raw * conversion_factor;

    // since sensor measures voltage of a biased bipolar diode, the voltage is
    // typically 0.706V at 27 degrees Celsius and has a slope of -1.721mV per degree
    float temp = 27 - (voltage - 0.706) / 0.001721;
    // if the temperature is cold, make the LED blue
    if(temp <= 10) {
        // Set the color to blue at half intensity
        put_pixel(urgb_u32(0x00, 0x00, 0x7F));
    }
    // if the temperature is warm, make the LED yellow
    else if(temp > 10 && temp <= 20) {
        // set color to yellow/orange at half intensity
        put_pixel(urgb_u32(0xE7, 0x84, 0x00));
    }
    // if the temperature is hot, make the LED red
    else {
        //set color to red at half intensity
        put_pixel(urgb_u32(0x7F, 0x00, 0x00));
    }
    // print out the raw data, hex equivalent, converted float and real temperature
    printf("Raw hex value: 0x%x\n", raw);
    printf("Converted floating point value: %f\n", voltage);
    printf("Temperature: %f\n", temp);
    printf("\n");
}

/**
 * @brief LAB #09 - TEMPLATE
 *        Main entry point for the code - calls the main assembly
 *        function where the body of the code is implemented.
 * 
 * @return int      Returns exit-status zero on completion.
 */

//Initialise the WS2812 RGB LED on the MAKER-PI-PICO (you can use any of the code from the “examples/ws2812_rgb” example) using the RP2040 PIO component.
//Implement a suitable function (to be called from the assembly code) that takes in the raw ADC value as an argument and converts it to a floating-point temperature reading.
//Print the current temperature reading to the console
//Set the RGB LED to an appropriate colour based on the temperature reading (e.g red for hot, orange for warm and green for cold).
int main() {
    
    // Jump into the main assembly code subroutine.
    stdio_init_all();
    // in here call func to take raw ADC value as arg and convert to floating point temperature
    // load onto PIO
    PIO pio = pio0;
    // finds free space for program in PIO's instruction memory and loads it
    uint offset = pio_add_program(pio, &ws2812_program);
    // Instantiates an instance of the LED driver
    ws2812_program_init(pio, 0, offset, WS2812_PIN, 800000, IS_RGBW);

    main_asm();

    // Returning zero indicates everything went okay.
    return 0;
}
