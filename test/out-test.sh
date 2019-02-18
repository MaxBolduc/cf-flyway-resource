#!/bin/bash

if [ ! "$BASH_VERSION" ] ; then
    echo "Please do not use sh to run this script ($0), just execute it directly" 1>&2
    exit 1
fi

# execute script from the test directory.
TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TMP_DIR="${TEST_DIR}/../tmp"

echo -e "\\nGiven_Out_When_ParamsIsFlywayConfFile_Then_ReturnNewVersion"
jq -n "
{
    source: {
        username: \"${CF_USERNAME}\",
        password: \"${CF_PASSWORD}\",
        api: \"${CF_API}\",
        organization: \"${CF_ORG}\",
        space: \"${CF_SPACE}\",
        service: \"${CF_SERVICE}\"
    },
    params: {
        flyway_conf: \"${TMP_DIR}/artifact/DB/flyway.conf\"
    },
    version: {
        ref: \"2019-01-01 00:00:00.000 (utc)\"
    }
}
" | tee | $TEST_DIR/../opt/resource/out.sh ${TMP_DIR}/destination


echo -e "\\nGiven_Out_When_ParamsIsFlywayConfInline_Then_ReturnNewVersion"
jq -n "
{
    source: {
        username: \"${CF_USERNAME}\",
        password: \"${CF_PASSWORD}\",
        api: \"${CF_API}\",
        organization: \"${CF_ORG}\",
        space: \"${CF_SPACE}\",
        service: \"${CF_SERVICE}\"
    },
    params: {
        flyway_conf: \"\nflyway.schemas=dbo\nflyway.locations=filesystem:${TMP_DIR}/artifact/DB/\n\"
    },
    version: {
        ref: \"2019-01-01 00:00:00.000 (utc)\"
    }
}
" | tee | $TEST_DIR/../opt/resource/out.sh ${TMP_DIR}/destination

echo -e "\\nGiven_Out_When_ParamsLocations_Then_ReturnNewVersion"
jq -n "
{
    source: {
        username: \"${CF_USERNAME}\",
        password: \"${CF_PASSWORD}\",
        api: \"${CF_API}\",
        organization: \"${CF_ORG}\",
        space: \"${CF_SPACE}\",
        service: \"${CF_SERVICE}\"
    },
    params: {
        locations: \"filesystem:${TMP_DIR}/artifact/DB/\",
    },
    version: {
        ref: \"2019-01-01 00:00:00.000 (utc)\"
    }
}
" | tee | $TEST_DIR/../opt/resource/out.sh ${TMP_DIR}/destination
