#!/usr/bin/env bash
# Copies JavaRosa's test forms (and their CSV/GeoJSON/XML secondary
# instances) into conformance/forms/javarosa, pinned to the JavaRosa version
# the oracle runs against.
set -euo pipefail
TAG="${1:-v6.0.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/conformance/forms/javarosa"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git -c advice.detachedHead=false clone -q --depth 1 --branch "$TAG" https://github.com/getodk/javarosa.git "$TMP/javarosa"
rm -rf "$DEST"
mkdir -p "$DEST"
cd "$TMP/javarosa/src/test/resources"
find . -type f \( -name '*.xml' -o -name '*.xhtml' -o -name '*.csv' -o -name '*.geojson' \) \
  -not -name 'logback*' -print0 | while IFS= read -r -d '' f; do
  mkdir -p "$DEST/$(dirname "$f")"
  cp "$f" "$DEST/$f"
done
echo "JavaRosa $TAG test resources from https://github.com/getodk/javarosa (Apache-2.0)." > "$DEST/SOURCE.txt"
echo "Imported $(find "$DEST" -type f -not -name SOURCE.txt | wc -l | tr -d ' ') files from JavaRosa $TAG into $DEST"
