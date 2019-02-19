#!/bin/bash

set -e

exec 3>&1 # make stdout available as fd 3 for the result
exec 1>&2 # redirect all output to stderr for logging

# --------------------------------

BOLD_GREEN="\e[32;1m"
BOLD_CYAN="\e[36;1m"
LIGHT_BLUE="\e[94m"
RESET="\e[0m"

DIR=${1-$(pwd)}
cd $DIR

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

# optional params
LOCATIONS=$(jq -r '.params.locations // empty' < $request)
COMMANDS=$(jq -r '.params.commands // empty' < $request)
FLYWAY_CONF=$(jq -r '.params.flyway_conf // empty' < $request)

[[ -z "$COMMANDS" ]]              && COMMANDS=$(jq -n '["info", "migrate", "info"]')
[[ -f "$FLYWAY_CONF" ]]           && FLYWAY_CONF=$(cat $FLYWAY_CONF)

# --------------------------------

# login to cloud foundry
cf login -a $PCF_API -u $PCF_USERNAME -p $PCF_PASSWORD -o $PCF_ORG -s $PCF_SPACE

# create service key if not exist
cf create-service-key $PCF_SERVICE cf-flyway

# create flyway.conf
echo -e "Creating flyway configuration file for service instance ${BOLD_CYAN}${PCF_SERVICE}${RESET} using credentials from service key ${BOLD_CYAN}cf-flyway${RESET}..."
echo -e "Reference: ${BOLD_CYAN}https://flywaydb.org/documentation/configfiles${RESET}\n"

# obtain service key credentials
credentials=`echo $(cf service-key $PCF_SERVICE cf-flyway) | tee | sed "s/.*{/{/"`

db_url="jdbc:postgresql://"$(echo $credentials | jq -r '.uri // empty' | grep -Poh '(?<=@).*')
db_username=$(echo $credentials | jq -r '.username')
db_password=$(echo $credentials | jq -r '.password')

echo "$FLYWAY_CONF" > flyway.conf 

cat >> flyway.conf <<- EOF
flyway.url=$db_url
flyway.user=$db_username
flyway.password=$db_password
EOF

[[ ! -z "$LOCATIONS" ]] && echo "flyway.locations=$LOCATIONS" >> flyway.conf

# output flyway.conf (don't show password)
echo -e "${LIGHT_BLUE}"
cat flyway.conf | sed "s/flyway\.password\=.*/flyway.password=************/" 
echo -e "${BOLD_GREEN}OK${RESET}\n"

# execute flyway commands
echo $COMMANDS | jq -cr '.[]' | while read cmd; do
    flyway $cmd
done
echo -e "${BOLD_GREEN}OK${RESET}\n"

# --------------------------------

version=$(date -u +"%F %T.%3N (utc)")

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
        {name: \"service_label\", value: $(cf curl $(echo $metadata | jq -r .entity.service_url) | jq .entity.label)},
        {name: \"service_plan\", value: $(cf curl $(echo $metadata | jq -r .entity.service_plan_url) | jq .entity.name)}
    ]
}")

# emit output to stdout for the result
echo $output | jq . >&3
