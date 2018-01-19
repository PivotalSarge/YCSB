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
  echo "$1: -d <db> [-l <locator>] [-t <threads>] [-o <operations>]" >&2
}

do_ycsb() {
  COMMAND=$1
  WORKLOAD=$2
  SHORT_WORKLOAD=$(basename $WORKLOAD)
  $YCSB_DIR/bin/ycsb "$COMMAND" $DATABASE \
    -P "$WORKLOAD" \
    -p "geode.locator=$LOCATOR" \
    -p exportfile=$(echo $EXPORT_FILE | sed -e "s?\.\([^.]*\)?_${COMMAND}_${SHORT_WORKLOAD}.\1?") \
    -s \
    -threads $THREADS \
    -p operationcount=$OPERATIONS
}

DATABASE=
LOCATOR='localhost[10334]'
EXPORT_FILE=
THREADS=1
OPERATIONS=1000
while [ 0 -lt $# ]
do
  if [ "$1" = "-h" ]
  then
    echo_usage $0
    exit 0
  elif [ "$1" = "-d" ]
  then
    shift
    DATABASE=$1
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
  else
    echo_usage $0
    exit 1
  fi
  shift
done

if [ -z "$DATABASE" ]
then
  echo_usage $0
  exit 1
fi

if [ -z "$EXPORT_FILE" ]
then
  EXPORT_FILE="${DATABASE}_$(date '+%Y%m%dT%H%M%S').txt"
fi

if [ -z "$GEODE_HOME" ]
then
  GEODE_HOME=/geode
fi

cd $YCSB_DIR

echo "Started:  $(date '+%Y-%m-%d %H:%M:%S')"

echo "Starting Geode"
$GEODE_HOME/bin/gfsh run --file=$YCSB_DIR/geode_protobuf/start.gfsh
$GEODE_HOME/bin/gfsh run --file=$YCSB_DIR/geode_protobuf/create.gfsh

echo ""
echo ""

echo "Loading database from A"
do_ycsb load workloads/workloada

echo ""
echo ""

echo "Running workload A"
do_ycsb run workloads/workloada

echo ""
echo ""

echo "Running workload B"
do_ycsb run workloads/workloadb

echo ""
echo ""

echo "Running workload C"
do_ycsb run workloads/workloadc

echo ""
echo ""

echo "Running workload F"
do_ycsb run workloads/workloadf

echo ""
echo ""

echo "Running workload D"
do_ycsb run workloads/workloadd

echo ""
echo ""

echo "Emptying Geode"
$GEODE_HOME/bin/gfsh run --file=$YCSB_DIR/geode_protobuf/destroy.gfsh
$GEODE_HOME/bin/gfsh run --file=$YCSB_DIR/geode_protobuf/create.gfsh

echo ""
echo ""

echo "Loading database from E"
do_ycsb load workloads/workloade

echo ""
echo ""

echo "Running workload E"
do_ycsb run workloads/workloade

echo ""
echo ""

echo "Stopping Geode"
$GEODE_HOME/bin/gfsh run --file=$YCSB_DIR/geode_protobuf/destroy.gfsh
$GEODE_HOME/bin/gfsh run --file=$YCSB_DIR/geode_protobuf/stop.gfsh

echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
