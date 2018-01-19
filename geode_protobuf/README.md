<!--
Copyright (c) 2014 - 2016 YCSB contributors. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License"); you
may not use this file except in compliance with the License. You
may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing
permissions and limitations under the License. See accompanying
LICENSE file.
-->

## Quick Start

This section describes how to run YCSB on Apache Geode.

### Get Apache Geode

You can download Geode (version 1.5 or later) from: http://geode.apache.org/releases/

### Run the Standard YCSB Sequence

Use the wrapper script `run_sequence.sh` to start a Geode locator and server, run the standard YCSB
sequence, and stop the locator and server.

From your YCSB directory:
```
geode_protobuf/run_sequence.sh -d geode_protobuf  -t <number of threads> -o <number of operations>
```
