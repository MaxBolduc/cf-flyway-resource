#!/bin/bash

# No-opt in script. Always return current version.

set -e

exec 3>&1 # make stdout available as fd 3 for the result
exec 1>&2 # redirect all output to stderr for logging

# --------------------------------

request=$(mktemp --tmpdir cf-flyway-resource-check.XXXXXX)
cat > $request <&0

cat < $request | jq -r . | sed "s/\"password\":.*/\"password\": \"********************\"/" 

# --------------------------------

PCF_API=$(jq -r '.source.api // empty' < $request)
PCF_ORG=$(jq -r '.source.organization // empty' < $request)
PCF_SPACE=$(jq -r '.source.space // empty' < $request)
PCF_SERVICE=$(jq -r '.source.service // empty' < $request)
PCF_USERNAME=$(jq -r '.source.username // empty' < $request)
PCF_PASSWORD=$(jq -r '.source.password // empty' < $request)

[[ ! -z "$PCF_API" ]]             && echo "PCF_API : $PCF_API" || echo "'source.api' must be set to the PCF API endpoint!"
[[ ! -z "$PCF_ORG" ]]             && echo "PCF_ORG : $PCF_ORG" || echo "'source.organization' must be set to the organization for PCF deployment!"
[[ ! -z "$PCF_SPACE" ]]           && echo "PCF_SPACE : $PCF_SPACE" || echo "'source.space' must be set to the space for PCF deployment!"
[[ ! -z "$PCF_SERVICE" ]]         && echo "PCF_SERVICE : $PCF_SERVICE" || echo "'source.service' the database service instance name."
[[ ! -z "$PCF_USERNAME" ]]        && echo "PCF_USERNAME : $PCF_USERNAME" || echo "'source.username' must be set to the username for PCF deployment!"
[[ ! -z "$PCF_PASSWORD" ]]        && echo "PCF_PASSWORD : ********************" || echo "'source.password' must be set to the password for PCF deployment!"

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
        {name: \"metadata_updated_at\", value: $(echo $metadata | jq .metadata.updated_at)},
        {name: \"pcf_api\", value: \"$PCF_API\"},
        {name: \"pcf_org\", value: \"$PCF_ORG\"},
        {name: \"pcf_space\", value: \"$PCF_SPACE\"},
        {name: \"service\", value: $(cf curl $(echo $metadata | jq -r .entity.service_url) | jq .entity.label)},
        {name: \"service_instance\", value: $(echo $metadata | jq .entity.name)},
        {name: \"service_plan\", value: $(cf curl $(echo $metadata | jq -r .entity.service_plan_url) | jq .entity.name)}
    ]
}")

# emit output to stdout for the result

echo $output | jq . >&3
