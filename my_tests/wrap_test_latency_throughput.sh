#!/bin/bash

#./test_bimodal.sh EDF_INTERRUPT
#./test_bimodal.sh DARC
#./test_bimodal.sh SHINJUKU 
#./test_exponential.sh DARC
#./test_exponential.sh EDF_INTERRUPT 
#./test_exponential.sh SHINJUKU

#./test_exponential.sh EDF_INTERRUPT false true 9 
#./test_exponential.sh EDF_INTERRUPT true false 9
#./test_exponential.sh EDF_INTERRUPT true true 27
#./test_exponential.sh EDF_INTERRUPT true false 27

./test_tpcc.sh DARC true true 10
./test_tpcc.sh SHINJUKU true true 10
./test_tpcc.sh EDF_INTERRUPT true true 10
./test_exponential.sh SHINJUKU true true 10
./test_exponential.sh EDF_INTERRUPT true true 10
./test_log_normal.sh SHINJUKU true true 10
./test_log_normal.sh EDF_INTERRUPT true true 10
