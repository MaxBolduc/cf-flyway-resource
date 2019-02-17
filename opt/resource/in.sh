#!/bin/bash

# No-opt in script. Always return current version.

set -e

exec 3>&1 # make stdout available as fd 3 for the result
exec 1>&2 # redirect all output to stderr for logging

PAYLOAD=$(cat <&0)
VERSION=$(echo $PAYLOAD | jq {version})

# emit output to stdout for the result
echo $VERSION | jq . >&3
