#!/bin/bash

set -e

PGM="main"

#BENCH_INDEX=""

#if [ $# -lt 1 ]; then
#	echo "Usage:  ./run.sh numberic-value"
#	exit 1
#else
	#if [[ ! "$1" =~ ^[0-9]+$ ]]; then
	#	echo "ERROR:  value must be numeric"
	#	echo "Usage:  ./run.sh numberic-value"
	#	exit 1
	#else
	#	BENCH_INDEX=$1
	#fi
#  echo " "
#fi

#time bin/${PGM}.elf ${BENCH_INDEX} $2 $3
time bin/${PGM}.elf $1 $2 $3 $4 $5 $6 $7 $8
