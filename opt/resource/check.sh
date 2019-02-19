#!/bin/bash

set -e

exec 3>&1 # make stdout available as fd 3 for the result
exec 1>&2 # redirect all output to stderr for logging

# --------------------------------

request=$(mktemp --tmpdir cf-flyway-resource-check.XXXXXX)
cat > $request <&0

# --------------------------------

REF=$(jq -r '.version.ref // empty' < $request)

if [ -z "$REF" ]; then
  OUT=$(date -u +"%F %T.%3N (utc)")
else
  OUT=$REF
fi

echo $OUT | jq -R . | jq -s 'map({ref: .})' >&3
