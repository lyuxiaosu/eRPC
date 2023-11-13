#!/bin/bash
function usage {
        echo "$0 [application, openloop_exponential or openloop_client]"
        exit 1
}

if [ $# != 1 ] ; then
        usage
        exit 1;
fi

app=$1
base_throughput1=16177
base_throughput2=650
#base_throughput1=20
#base_throughput2=20

#throughput_percentage=(1 5 10 15 20 25 30 35 40 45 50 55 60)
throughput_percentage=(88)
#throughput_percentage=(1)


for(( i=0;i<${#throughput_percentage[@]};i++ )) do
        per_throughput1=$(( (${throughput_percentage[i]} * base_throughput1) / 100 ))
	per_throughput2=$(( (${throughput_percentage[i]} * base_throughput2) / 100 ))
	echo ${throughput_percentage[i]} $per_throughput1 $per_throughput2
	replacement_rps=${per_throughput1}
	for ((j=2; j<=8; j++))
	do
  		replacement_rps="${replacement_rps},${per_throughput1}"
	done
	replacement_rps="--rps ${replacement_rps},${per_throughput2}"
	echo $replacement_rps
	./set_rps.sh /users/xiaosuGW/eRPC/apps/$app/config "$replacement_rps" 	
done
