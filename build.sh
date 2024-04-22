#!/bin/bash

cmake -DTRANSPORT=dpdk -DSLEDGE_CUSTOMIZED=TRUE -DNUM_RX_RING_ENTRIES=4096 -DMAX_QUEUE_PER_PORT=32 -DNUM_TX_RING_DESC=4096 -DSESSION_CREDITS=1024 -DSESSION_REQ_WINDOW=1024 .
#cmake -DTRANSPORT=dpdk -DSLEDGE_CUSTOMIZED=TRUE -DNUM_TX_RING_DESC=128 -DSESSION_CREDITS=32 -DSESSION_REQ_WINDOW=8 .
#cmake . -DTRANSPORT=dpdk
make -j

sudo bash -c "echo 2048 > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages"
sudo mkdir /mnt/huge
sudo mount -t hugetlbfs nodev /mnt/huge
