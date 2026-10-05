#!/usr/bin/env bash
# Copyright 2026 The DartRosa Authors
# SPDX-License-Identifier: Apache-2.0

# Builds (if needed) and runs the JavaRosa oracle.
#
#   ./oracle.sh walk <form.xml>                 trace one form to stdout
#   ./oracle.sh scenario <file.scenario.json>   run one scenario to stdout
#   ./oracle.sh batch <conformance-dir>         trace every form and scenario
#                                               into <conformance-dir>/traces
set -euo pipefail
args=()
for a in "$@"; do
  if [ -e "$a" ] || [ -d "$(dirname "$a")" -a "$a" != "$(basename "$a")" ]; then args+=("$(cd "$(dirname "$a")" && pwd)/$(basename "$a")"); else args+=("$a"); fi
done
cd "$(dirname "$0")"

if [ ! -d lib ] || [ deps.txt -nt lib ]; then
  mkdir -p lib
  grep -v '^#' deps.txt | grep . | while IFS=: read -r group artifact version; do
    jar="lib/$artifact-$version.jar"
    [ -f "$jar" ] && continue
    url="https://repo1.maven.org/maven2/${group//.//}/$artifact/$version/$artifact-$version.jar"
    echo "Downloading $artifact $version" >&2
    curl -fsSL -o "$jar" "$url"
  done
  touch lib
fi

if [ ! -d out ] || [ -n "$(find src -newer out -name '*.java' 2>/dev/null)" ]; then
  rm -rf out
  if ! javac -nowarn -encoding UTF-8 -cp "lib/*" -d out $(find src -name '*.java') >&2; then
    rm -rf out
    exit 1
  fi
  touch out
fi

# Pin the time zone so traces are identical on every machine.
export TZ=UTC
exec java -Duser.timezone=UTC -cp "out:lib/*" org.dartrosa.oracle.Oracle "${args[@]}"
