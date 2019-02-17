#!/bin/bash

if [ ! "$BASH_VERSION" ] ; then
    echo "Please do not use sh to run this script ($0), just execute it directly" 1>&2
    exit 1
fi

# execute script from the test directory.
TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo -e "\\nGiven_Out_When_NoOpt_Then_ReturnNewVersion"
jq -n "
{
    source: {
        foo1: \"bar1\"
    },
    params: {
        foo2: \"bar2\"
    }
}
" | tee | $TEST_DIR/../opt/resource/out.sh
