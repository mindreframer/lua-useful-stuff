#!/bin/bash

BENCHMARK=$1
NUM_ITERATIONS=$2
if [ -z "${BENCHMARK}" -o -z "${NUM_ITERATIONS}" ]; then
  echo "Usage: $0 <benchmark> <num_iterations>" >&2
  exit 1
fi

if [ ! -f "${BENCHMARK}" ]; then
  echo "Benchmark file '${BENCHMARK}' not found" >&2
  exit 2
fi

./kbench.sh "bench.lua ${BENCHMARK}" ${NUM_ITERATIONS} 2>&1 \
  | lua kbenchparse.lua
