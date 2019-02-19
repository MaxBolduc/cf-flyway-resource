#!/bin/bash

set -e

exec 3>&1 # make stdout available as fd 3 for the result
exec 1>&2 # redirect all output to stderr for logging

# --------------------------------

request=$(mktemp --tmpdir cf-flyway-resource-check.XXXXXX)
cat > $request <&0

# --------------------------------

# required source
PCF_API=$(jq -r '.source.api // empty' < $request)
PCF_ORG=$(jq -r '.source.organization // empty' < $request)
PCF_SPACE=$(jq -r '.source.space // empty' < $request)
PCF_SERVICE=$(jq -r '.source.service // empty' < $request)
PCF_USERNAME=$(jq -r '.source.username // empty' < $request)
PCF_PASSWORD=$(jq -r '.source.password // empty' < $request)

[[ -z "$PCF_API" ]]             && echo "(required) 'source.api' is missing."
[[ -z "$PCF_ORG" ]]             && echo "(required) 'source.organization' is missing."
[[ -z "$PCF_SPACE" ]]           && echo "(required) 'source.space' is missing."
[[ -z "$PCF_SERVICE" ]]         && echo "(required) 'source.service' is missing."
[[ -z "$PCF_USERNAME" ]]        && echo "(required) 'source.username' is missing."
[[ -z "$PCF_PASSWORD" ]]        && echo "(required) 'source.password' is missing."

# --------------------------------

# login to cloud foundry
cf login -a $PCF_API -u $PCF_USERNAME -p $PCF_PASSWORD -o $PCF_ORG -s $PCF_SPACE

version=$(jq -r '.version.ref' < $request)
service_guid=$(cf service $PCF_SERVICE --guid)
metadata=$(cf curl /v2/service_instances/$service_guid | jq .)

output=$(jq -n "
{
    version: {
        ref: \"$version\"
    },
    metadata: [
        {name: \"metadata_url\", value: $(echo $metadata | jq .metadata.url)},
        {name: \"pcf_api\", value: \"$PCF_API\"},
        {name: \"pcf_org\", value: \"$PCF_ORG\"},
        {name: \"pcf_space\", value: \"$PCF_SPACE\"},
        {name: \"service_instance\", value: $(echo $metadata | jq .entity.name)},
        {name: \"service\", value: $(cf curl $(echo $metadata | jq -r .entity.service_url) | jq .entity.label)},
        {name: \"service_plan\", value: $(cf curl $(echo $metadata | jq -r .entity.service_plan_url) | jq .entity.name)}
    ]
}")

# emit output to stdout for the result

echo $output | jq . >&3
