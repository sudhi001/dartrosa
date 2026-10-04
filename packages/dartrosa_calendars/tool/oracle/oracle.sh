#!/usr/bin/env bash
# Regenerates test/vectors/*.dart by running the original JVM calendar
# libraries ODK Collect uses (see deps.txt).
#
#   tool/oracle/oracle.sh
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p lib
grep -v '^#' deps.txt | grep . | while IFS='|' read -r jar url; do
  [ -f "lib/$jar" ] && continue
  echo "Downloading $jar" >&2
  curl -fsSL -o "lib/$jar" "$url"
done
if [ ! -d out ] || [ -n "$(find src -newer out -name '*.java' 2>/dev/null)" ]; then
  rm -rf out gen && mkdir -p gen
  (cd gen && unzip -oq ../lib/persianjodatime-1.2-sources.jar)
  javac -nowarn -encoding UTF-8 -cp "lib/*" -d out \
    $(find gen src -name '*.java') >&2
  touch out
fi
export TZ=UTC
exec java -Duser.timezone=UTC -cp "out:lib/*" CalendarOracle ../../test/vectors
