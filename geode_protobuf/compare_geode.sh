#!/usr/bin/env bash
#
# Copyright (c) 2013 - 2018 YCSB Contributors. All rights reserved.
# <p>
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License. You
# may obtain a copy of the License at
# <p>
# http://www.apache.org/licenses/LICENSE-2.0
# <p>
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License. See accompanying
# LICENSE file.
#

YCSB_DIR=$(dirname $(dirname $0))

echo_usage() {
  echo "$1: [-l <locator>] -t <threads> -o <operations> [-f <reportfileprefix>]" >&2
}

extract_value() {
  fgrep "${1}, ${2}" $3 | head -1 | cut -d, -f3 | tr -d '[:space:]'
}

COOKIE=.$(basename $0).cookie
LOCATOR='localhost[10334]'
THREADS=
OPERATIONS=
REPORT_FILE_PREFIX=
while [ 0 -lt $# ]
do
  if [ "$1" = "-h" ]
  then
    echo_usage $0
    exit 0
  elif [ "$1" = "-l" ]
  then
    shift
    LOCATOR=$1
  elif [ "$1" = "-t" ]
  then
    shift
    THREADS=$1
  elif [ "$1" = "-o" ]
  then
    shift
    OPERATIONS=$1
  elif [ "$1" = "-f" ]
  then
    shift
    REPORT_FILE_PREFIX=$1
  else
    echo_usage $0
    exit 1
  fi
  shift
done

if [ -z "$THREADS" -o -z "$OPERATIONS" ]
then
  echo_usage $0
  exit 1
fi

if [ -z "$TMP" ]
then
  TMP=/tmp
fi
TMP_FILE=$TMP/$$

touch $COOKIE

echo "Running sequence with Geode"
$YCSB_DIR/geode_protobuf/run_sequence.sh -d geode -t $THREADS -o $OPERATIONS

echo ""
echo ""

echo "Running sequence with Geode protobuf"
$YCSB_DIR/geode_protobuf/run_sequence.sh -d geode_protobuf -t $THREADS -o $OPERATIONS

echo ""
echo ""
echo "Processing output"
if [ -z "$REPORT_FILE_PREFIX" ]
then
  REPORT_FILE=/dev/null
else
  REPORT_FILE=${REPORT_FILE_PREFIX}_${THREADS}_${OPERATIONS}.txt
fi
(
find * -type d -prune -o -type f -name 'geode_*T*_*.txt' -Bnewer $COOKIE -print | sort | fgrep -v _load_ >$TMP_FILE
printf "Locator: %20s\nThreads:                %5d\nOperations:             %5d\n" $LOCATOR $THREADS $OPERATIONS
for PROTOBUF_WORKLOAD in $(fgrep geode_protobuf $TMP_FILE)
do
  ORIGINAL_WORKLOAD=$(find * -type d -prune -o -type f -name "$(echo $PROTOBUF_WORKLOAD | sed -e 's/_protobuf_[0-9]*T[0-9]*_/_[0-9]*_/')" -Bnewer $COOKIE -print | head -1)
  echo ""
  echo "Workload: $(echo $PROTOBUF_WORKLOAD | sed -e 's/.*_\([^_]*\)\.txt/\1/')"
  echo "                          Original    Protobuf"
  echo "             ---------------------------------"
  printf "              Throughput:    %5.0f       %5.0f (operations/second)\n" \
      $(extract_value "[OVERALL]" "Throughput(ops/sec)" $ORIGINAL_WORKLOAD) \
      $(extract_value "[OVERALL]" "Throughput(ops/sec)" $PROTOBUF_WORKLOAD)
  for OPERATION in $(egrep -h '\[[A-Z]+\]' $(cat $TMP_FILE) | sed -e 's/,.*//' | sort -u | egrep -v '\[CLEANUP\]|\[OVERALL\]')
  do
    if fgrep -q "$OPERATION" $PROTOBUF_WORKLOAD
    then
      printf "%12s:\n" $(echo $OPERATION | tr '[:upper:]' '[:lower:]' | sed -e 's/\[\(.*\)\]/\1/g')
      printf "            %13s    %5d       %5d (micro-seconds)\n" "Operations:" \
          $(extract_value $OPERATION "Operations" $ORIGINAL_WORKLOAD) \
          $(extract_value $OPERATION "Operations" $PROTOBUF_WORKLOAD)
      printf "            %13s    %5.0f       %5.0f (micro-seconds)\n" "Avg Latency:" \
          $(extract_value $OPERATION "AverageLatency(us)" $ORIGINAL_WORKLOAD) \
          $(extract_value $OPERATION "AverageLatency(us)" $PROTOBUF_WORKLOAD)
      printf "            %13s    %5.0f       %5.0f (micro-seconds)\n" "Min Latency:" \
          $(extract_value $OPERATION "MinLatency(us)" $ORIGINAL_WORKLOAD) \
          $(extract_value $OPERATION "MinLatency(us)" $PROTOBUF_WORKLOAD)
      printf "            %13s    %5.0f       %5.0f (micro-seconds)\n" "Max Latency:" \
          $(extract_value $OPERATION "MaxLatency(us)" $ORIGINAL_WORKLOAD) \
          $(extract_value $OPERATION "MaxLatency(us)" $PROTOBUF_WORKLOAD)
      printf "            %13s    %5.0f       %5.0f (micro-seconds)\n" "95th Latency:" \
          $(extract_value $OPERATION "95thPercentileLatency(us)" $ORIGINAL_WORKLOAD) \
          $(extract_value $OPERATION "95thPercentileLatency(us)" $PROTOBUF_WORKLOAD)
      printf "            %13s    %5.0f       %5.0f (micro-seconds)\n" "99th Latency:" \
          $(extract_value $OPERATION "99thPercentileLatency(us)" $ORIGINAL_WORKLOAD) \
          $(extract_value $OPERATION "99thPercentileLatency(us)" $PROTOBUF_WORKLOAD)
    fi
  done
done
) | tee $REPORT_FILE

rm -f $COOKIE $TMP_FILE
