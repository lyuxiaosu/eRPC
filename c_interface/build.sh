#!/bin/bash

#cmake . -DTRANSPORT=dpdk
cmake -DTRANSPORT=dpdk -DSLEDGE_CUSTOMIZED=TRUE -DNUM_TX_RING_DESC=4096 -DSESSION_CREDITS=256 -DSESSION_REQ_WINDOW=256 . 
make -j

sudo bash -c "echo 2048 > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages"
sudo mkdir /mnt/huge
sudo mount -t hugetlbfs nodev /mnt/huge

