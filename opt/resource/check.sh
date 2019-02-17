#!/bin/bash

# No-opt check script. Always return current version, or create currrent version if none receive.

set -e

exec 3>&1 # make stdout available as fd 3 for the result
exec 1>&2 # redirect all output to stderr for logging

PAYLOAD=$(cat <&0)
# echo $PAYLOAD | jq -r '.'

REF=$(echo $PAYLOAD | jq -r '.version.ref // empty') # return empty string instead of 'null'

if [ -z "$REF" ]; then
  OUT=$(date -u +"%F %T.%3N (utc)")
else
  OUT=$REF
fi

echo $OUT | jq -R . | jq -s 'map({ref: .})' >&3
