#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/stdlib.h"
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.

//#define WOKWI             // Uncomment if running on Wokwi RP2040 emulator.
/**
 * @brief EXAMPLE - HELLO_C
 *        Simple example to initialise the IOs and then 
 *        print a "Hello World!" message to the console.
 * 
 * @return int  Application return code (zero for success).
 */

//define the functions to be used
float wallis_function();
double wallis_function_double();

int main() {    

#ifndef WOKWI
    // Initialise the IO as we will be using the UART
    // Only required for hardware and not needed for Wokwi
    stdio_init_all();
#endif

    //calculate pi approximations
    float product_pi = wallis_function();
    double product_double = wallis_function_double();

    //print calculated PI values
    printf("Calculated value for PI (using single-precision representation): %13.11f\n", product_pi);
    printf("Calculated value for PI (using double-precision representation): %13.11f\n", product_double);

    //calculate errors
    float approximation_error_single = M_PI-product_pi;
    float approximation_error_double = M_PI-product_double;
    //print errors
    printf("Approximation error for single-precision floating point representation: %13.11f\n", approximation_error_single);
    printf("Approximation error for double-precision floating point representation: %13.11f\n", approximation_error_double);
    // Returning zero indicates everything went okay.
    return 0;
}

//function to approximate pi using single-precision floating point representation
float wallis_function() {
    float prod = 1;
    //for each value of n from 1 - 100001
    for(int n=1; n < 100001; n++) {
        float numerator = 2*n;
        float denom_1 = ((2*n)-1);
        float denom_2 = ((2*n)+1);
        //Wallis formula
        float value = ((float)(numerator)/(float)(denom_1))*((float)(numerator)/(float)(denom_2));
        //multiply each value calculated together
        prod = value*prod;
    }
    //return twice the final product since Wallis formula = pi/2
    return 2*prod;
}

//function to approximate pi using double-precision floating point representation
double wallis_function_double() {
    double prod = 1;
    //for each n
    for(int n=1; n < 100001; n++) {
        double numerator = 2*n;
        double denom_1 = ((2*n)-1);
        double denom_2 = ((2*n)+1);
        //use wallis formula
        double value = ((double)(numerator)/(double)(denom_1))*((double)(numerator)/(double)(denom_2));
        prod = value*prod;
    }
    //return two times the final product since Wallis formula = pi/2
    return 2*prod;
}