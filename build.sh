#!/bin/bash

cmake . -DTRANSPORT=dpdk
make -j
