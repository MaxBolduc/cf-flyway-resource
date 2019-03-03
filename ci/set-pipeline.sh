#!/bin/bash

# execute script in the '/ci' directory.
cd "$(dirname "${BASH_SOURCE[0]}")"

fly -t emerald-squad sp -p cf-flyway-resource -c pipeline.yml -l parameters.yml