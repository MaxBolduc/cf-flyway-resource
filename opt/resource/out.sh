#!/bin/bash

# No-opt out script. Always return new version.

set -e

exec 3>&1 # make stdout available as fd 3 for the result
exec 1>&2 # redirect all output to stderr for logging

OUT=$(date -u +"%F %T.%3N (utc)")

echo $OUT | jq -R . | jq -r '{version:{ref: .}}' >&3
