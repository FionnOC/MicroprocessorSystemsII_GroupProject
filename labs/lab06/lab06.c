#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/stdlib.h"
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.
#include "pico/multicore.h" // Required for using multiple cores on the RP2040.

/**
 * @brief This function acts as the main entry-point for core #1.
 *        A function pointer is passed in via the FIFO with one
 *        incoming int32_t used as a parameter. The function will
 *        provide an int32_t return value by pushing it back on 
 *        the FIFO, which also indicates that the result is ready.
 */
void core1_entry() {
    while (1) {
        // 
        int32_t (*func)() = (int32_t(*)()) multicore_fifo_pop_blocking();
        int32_t p = multicore_fifo_pop_blocking();
        int32_t result = (*func)(p);
        multicore_fifo_push_blocking(result);
    }
}

//define the functions to be used
float wallis_function(const int ITER_MAX);
double wallis_function_double(const int ITER_MAX);

int main() {    

    // Initialise the IO as we will be using the UART
    // Only required for hardware and not needed for Wokwi
    const int ITER_MAX = 100000;
    stdio_init_all();
    multicore_launch_core1(core1_entry);

    //calculate pi approximations - sequentially
    absolute_time_t from = get_absolute_time();
    //call the single and double precision functions
    wallis_function(ITER_MAX);
    wallis_function_double(ITER_MAX); 
    absolute_time_t to = get_absolute_time();
    // calculate the total runtime based on the difference in timer values
    int total_runtime = absolute_time_diff_us(from, to);
    printf("Total sequential time: %i\n", total_runtime);

    //initialise the 'before' variable and start the timer
    absolute_time_t before = get_absolute_time();
    //run the single-precision function on the second core
    multicore_fifo_push_blocking((uintptr_t) &wallis_function);
    multicore_fifo_push_blocking(ITER_MAX);
    //pop
    multicore_fifo_pop_blocking();
    // run the double-precision function on this core
    wallis_function_double(ITER_MAX);
    // calculate the absolute runtime
    absolute_time_t after = get_absolute_time();
    int parallel_runtime = absolute_time_diff_us(before, after);
    // print out the parallel runtime
    printf("Total parallel time: %i\n", parallel_runtime);

    return 0;
}

//function to approximate pi using single-precision floating point representation
float wallis_function(const int ITER_MAX) {
    absolute_time_t from = get_absolute_time();
    float prod = 1;
    //for each value of n from 1 - 100001
    for(int n=1; n < ITER_MAX+1; n++) {
        float numerator = 2*n;
        float denom_1 = ((2*n)-1);
        float denom_2 = ((2*n)+1);
        //Wallis formula
        float value = ((float)(numerator)/(float)(denom_1))*((float)(numerator)/(float)(denom_2));
        //multiply each value calculated together
        prod = value*prod;
    }
    absolute_time_t to = get_absolute_time();
    int runtime = absolute_time_diff_us(from, to);
    printf("Single time: %i\n", runtime);
    //return twice the final product since Wallis formula = pi/2
    return 2*prod;
}

//function to approximate pi using double-precision floating point representation
double wallis_function_double(const int ITER_MAX) {
    absolute_time_t from = get_absolute_time();
    double prod = 1;
    //for each n
    for(int n=1; n < ITER_MAX+1; n++) {
        double numerator = 2*n;
        double denom_1 = ((2*n)-1);
        double denom_2 = ((2*n)+1);
        //use wallis formula
        double value = ((double)(numerator)/(double)(denom_1))*((double)(numerator)/(double)(denom_2));
        prod = value*prod;
    }
    absolute_time_t to = get_absolute_time();
    int runtime = absolute_time_diff_us(from, to);
    printf("Double time: %i\n", runtime);
    //return two times the final product since Wallis formula = pi/2
    return 2*prod;
}
