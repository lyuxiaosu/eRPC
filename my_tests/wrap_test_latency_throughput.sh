#!/bin/bash

#./test_fix.sh EDF_INTERRUPT
#./test_fix.sh DARC
#./test_fix.sh SHINJUKU 
#./test_high_bimodal.sh EDF_INTERRUPT
#./test_high_bimodal.sh SHINJUKU
#./test_high_bimodal.sh DARC

#./test_high_bimodal_realapp.sh EDF_INTERRUPT
#./test_high_bimodal_realapp.sh SHINJUKU
#./test_high_bimodal_realapp.sh DARC

#./test_vision_3apps_change_deadlines.sh EDF_INTERRUPT 12
#./test_vision_3apps_change_deadlines.sh SHINJUKU 12
#./test_vision_3apps_change_deadlines.sh DARC 12

./test_dispatchers.sh RR 12 
./test_dispatchers.sh JSQ 12
./test_dispatchers.sh LLD 12
./test_dispatchers.sh EDF_INTERRUPT 12

#./test_bimodal.sh EDF_INTERRUPT
#./test_bimodal.sh DARC
#./test_bimodal.sh SHINJUKU 

#./test_tpcc.sh DARC 10
#./test_tpcc.sh SHINJUKU 10
#./test_tpcc.sh EDF_INTERRUPT 10
#./test_vision_same_6apps.sh DARC 12
#./test_vision_same_6apps.sh EDF_INTERRUPT 12
#./test_vision_same_6apps.sh SHINJUKU 12

#./test_vision_more_shorters_6apps.sh DARC 12
#./test_vision_more_shorters_6apps.sh EDF_INTERRUPT 12
#./test_vision_more_shorters_6apps.sh SHINJUKU 12

#./test_vision_more_shorters_5apps.sh DARC 10
#./test_vision_more_shorters_5apps.sh EDF_INTERRUPT 10
#./test_vision_more_shorters_5apps.sh SHINJUKU 10

#./test_vision_3apps.sh DARC 12
#./test_vision_3apps.sh EDF_INTERRUPT 12
#./test_vision_3apps.sh SHINJUKU 12

#./test_vision_3apps_loose3.sh DARC 12
#./test_vision_3apps_loose3.sh EDF_INTERRUPT 12
#./test_vision_3apps_loose3.sh SHINJUKU 12

#./test_vision_3apps_strict.sh DARC 12
#./test_vision_3apps_strict.sh EDF_INTERRUPT 12
#./test_vision_3apps_strict.sh SHINJUKU 12

#./test_vision_3apps_loose2.sh DARC 12
#./test_vision_3apps_loose2.sh EDF_INTERRUPT 12
#./test_vision_3apps_loose2.sh SHINJUKU 12

#./test_vision_3apps_loose.sh DARC 12
#./test_vision_3apps_loose.sh EDF_INTERRUPT 12
#./test_vision_3apps_loose.sh SHINJUKU 12

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




