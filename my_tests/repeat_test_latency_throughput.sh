#!/bin/bash

policy=(EDF_INTERRUPT DARC SHINJUKU)
for(( i=0;i<${#policy[@]};i++ )) do
       for j in {1..5}
       do
       ./test_bimodal.sh ${policy[i]} $j
       echo ${policy[i]} $j
       done
done

