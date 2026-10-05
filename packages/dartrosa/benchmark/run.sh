#!/bin/sh
# Runs the engine benchmark compiled ahead of time, saves the JSON results
# and redraws docs/images/benchmarks.svg. Run from anywhere:
#
#   packages/dartrosa/benchmark/run.sh
#
# Extra arguments go to the benchmark (for example --runs=3).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
package=$(dirname "$here")
repo=$(dirname "$(dirname "$package")")
exe="${TMPDIR:-/tmp}/dartrosa-engine-benchmark"
cd "$package"
dart compile exe benchmark/engine_benchmark.dart -o "$exe"
"$exe" --out=benchmark/results.json "$@"
dart run benchmark/render_chart.dart benchmark/results.json \
  "$repo/docs/images/benchmarks.svg"
echo "Wrote benchmark/results.json and docs/images/benchmarks.svg"
