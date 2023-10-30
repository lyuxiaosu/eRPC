#!/bin/bash
function usage {
        echo "$0 [application]"
        exit 1
}

if [ $# != 1 ] ; then
        usage
        exit 1;
fi

app=$1
base_throughput1=32344
base_throughput2=2614
#base_throughput2=32344
#base_throughput1=16000
#base_throughput2=2000

#throughput_percentage=(10 20 30 40 50 60)
throughput_percentage=(90)
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
