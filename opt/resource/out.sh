#!/bin/bash

set -e

exec 3>&1 # make stdout available as fd 3 for the result
exec 1>&2 # redirect all output to stderr for logging

# --------------------------------

BOLD_GREEN="\e[32;1m"
BOLD_CYAN="\e[36;1m"
LIGHT_RED="\e[91m"
LIGHT_CYAN="\e[96m"
RESET="\e[0m"

DIR=${1-$(pwd)}
cd $DIR

request=$(mktemp --tmpdir cf-flyway-resource-check.XXXXXX)
cat > $request <&0

# --------------------------------

# source
PCF_API=$(jq -r '.source.api // empty' < $request)
PCF_ORG=$(jq -r '.source.organization // empty' < $request)
PCF_SPACE=$(jq -r '.source.space // empty' < $request)
PCF_SERVICE=$(jq -r '.source.service // empty' < $request)
PCF_USERNAME=$(jq -r '.source.username // empty' < $request)
PCF_PASSWORD=$(jq -r '.source.password // empty' < $request)

[[ -z "$PCF_API" ]]                     && echo -e "${LIGHT_RED}(required) 'source.api' is missing.${RESET}" && valid_input=1
[[ -z "$PCF_ORG" ]]                     && echo -e "${LIGHT_RED}(required) 'source.organization' is missing.${RESET}" && valid_input=1
[[ -z "$PCF_SPACE" ]]                   && echo -e "${LIGHT_RED}(required) 'source.space' is missing.${RESET}" && valid_input=1
[[ -z "$PCF_SERVICE" ]]                 && echo -e "${LIGHT_RED}(required) 'source.service' is missing.${RESET}" && valid_input=1
[[ -z "$PCF_USERNAME" ]]                && echo -e "${LIGHT_RED}(required) 'source.username' is missing.${RESET}" && valid_input=1
[[ -z "$PCF_PASSWORD" ]]                && echo -e "${LIGHT_RED}(required) 'source.password' is missing.${RESET}" && valid_input=1

# params
LOCATIONS=$(jq -r '.params.locations // empty' < $request)
COMMANDS=$(jq -r '.params.commands // ["info", "migrate", "info"]' < $request)
CLEAN_DISABLED=$(jq -r '.params.clean_disabled' < $request)
DELETE_SERVICE_KEY=$(jq -r '.params.delete_service_key' < $request)
FLYWAY_CONF=$(jq -r '.params.flyway_conf // empty' < $request)

[[ -z "$LOCATIONS" ]]                   && echo -e "${LIGHT_RED}(required) 'params.locations' is missing." && valid_input=1
[[ ${CLEAN_DISABLED} != false ]]        && CLEAN_DISABLED=true
[[ ${DELETE_SERVICE_KEY} != true ]]     && DELETE_SERVICE_KEY=false
[[ -f "$FLYWAY_CONF" ]]                 && FLYWAY_CONF=$(cat $FLYWAY_CONF)

[[ valid_input -eq 1 ]]                 && exit 1

# --------------------------------

# login to cloud foundry
unbuffer cf login -a $PCF_API -u $PCF_USERNAME -p $PCF_PASSWORD -o $PCF_ORG -s $PCF_SPACE
echo ""

# create service key if not exist
unbuffer cf create-service-key $PCF_SERVICE cf-flyway

# create flyway.conf
echo -e "Creating flyway configuration file for service instance ${BOLD_CYAN}${PCF_SERVICE}${RESET} using credentials from service key ${BOLD_CYAN}cf-flyway${RESET}..."
echo -e "Reference: ${BOLD_CYAN}https://flywaydb.org/documentation/configfiles${RESET}"

# obtain service key credentials
credentials="$(cf service-key $PCF_SERVICE cf-flyway | grep -Pzoh '(?s)\{.*\}' | tr "\0" "\n")" # tr used to suppress "warning: command substitution: ignored null byte in input" 

service_url=$(cf curl /v2/service_instances/$(cf service $PCF_SERVICE --guid) | jq -r .entity.service_url)
service_label=$(cf curl $service_url | jq -r .entity.label)

# detect service-key format and read database jdbc url.
if [[ $service_label == "a9s-postgresql94" ]] ; then
    db_url="jdbc:postgresql://$(echo $credentials | jq -r '.uri' | grep -Poh '(?<=@).*')"
elif [[ "$service_label" == "postgresql-9.5-odb" ]] ; then
    db_url=$(echo $credentials | jq -r .jdbc_uri)
elif [[ "$service_label" == "p-mysql" ]] ; then
    db_url=$(echo $credentials | jq -r .jdbcUrl | grep -Poh '[^?]*')
else
    echo -e "Database service ${BOLD_CYAN}'$service_label'${RESET} is not supported by this resource. However, adding support is trivial. Please file an issues and we'll add support.\n"
    exit 1
fi

db_username=$(echo $credentials | jq -r '.username')
db_password=$(echo $credentials | jq -r '.password')

# create flyway.conf
if [[ ! -z "$FLYWAY_CONF" ]] ; then
    echo -e "# Copied from flyway_conf parameter.\n$FLYWAY_CONF" > flyway.conf
else    
    echo > flyway.conf
fi

sed -i /flyway\.url=.*/d ./flyway.conf
sed -i /flyway\.user=.*/d ./flyway.conf
sed -i /flyway\.password=.*/d ./flyway.conf
sed -i /flyway\.locations=.*/d ./flyway.conf
sed -i /flyway\.cleanDisabled=.*/d ./flyway.conf

cat >> flyway.conf <<- EOF

# Added by cf-flyway-resource
flyway.url=$db_url
flyway.user=$db_username
flyway.password=$db_password
flyway.locations=$LOCATIONS
flyway.cleanDisabled=$CLEAN_DISABLED
EOF

# output flyway.conf (don't show password)
echo -e "${LIGHT_CYAN}"
cat flyway.conf | sed "s/flyway\.password\=.*/flyway.password=************/" && echo ""
echo -e "${BOLD_GREEN}OK${RESET}\n"

# execute flyway commands
echo -e "Executing flyway command sequence ${BOLD_CYAN}[ $(echo ${COMMANDS} | jq -r 'map(.) | join(", ")') ]${RESET} on database service instance ${BOLD_CYAN}${PCF_SERVICE}${RESET}.\n"

echo $COMMANDS | jq -cr '.[]' | while read cmd; do
    echo -e "${BOLD_CYAN}$ flyway ${cmd}${RESET}"
    flyway $cmd
    if [[ "$cmd" != "info" ]] ; then echo "" ; fi
done
echo -e "${BOLD_GREEN}OK${RESET}\n"

if [[ $DELETE_SERVICE_KEY == true ]] ; then
    unbuffer cf delete-service-key $PCF_SERVICE cf-flyway -f
fi 

# --------------------------------

# create version with metadata output.
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
