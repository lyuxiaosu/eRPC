#!/bin/bash

#./test_fix.sh EDF_INTERRUPT
#./test_fix.sh DARC
#./test_fix.sh SHINJUKU 
#./test_high_bimodal.sh EDF_INTERRUPT
#./test_high_bimodal.sh SHINJUKU
#./test_high_bimodal.sh DARC

#./test_bimodal.sh EDF_INTERRUPT
#./test_bimodal.sh DARC
#./test_bimodal.sh SHINJUKU 

./test_tpcc.sh DARC 10
./test_tpcc.sh SHINJUKU 10
./test_tpcc.sh EDF_INTERRUPT 10
#./test_exponential.sh SHINJUKU 10
#./test_exponential.sh EDF_INTERRUPT 10
#./test_exponential.sh DARC 10
#./test_log_normal.sh SHINJUKU 10
#./test_log_normal.sh EDF_INTERRUPT 10
#./test_log_normal.sh DARC 10

#./measure_function_density_scaling2.sh 1 1 1
#./measure_function_density_scaling2.sh 1 1 12000
#./measure_function_density_scaling2.sh 3 1 1
#./measure_function_density_scaling2.sh 3 1 12000
#./measure_function_density_scaling2.sh 5 1 1
#./measure_function_density_scaling2.sh 5 1 12000




