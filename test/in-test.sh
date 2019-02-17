#!/bin/bash

if [ ! "$BASH_VERSION" ] ; then
    echo "Please do not use sh to run this script ($0), just execute it directly" 1>&2
    exit 1
fi

# execute script from the test directory.
TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo -e "\\nGiven_In_When_NoOpt_Then_ReturnVersion"
jq -n "
{
    version: {
        ref: \"2019-01-01 00:00:00.000 (utc)\"
    }
}
" | tee | $TEST_DIR/../opt/resource/in.sh $DEST