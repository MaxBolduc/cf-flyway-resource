#!/bin/bash

# No-opt out script. Always return new version.

set -e

exec 3>&1 # make stdout available as fd 3 for the result
exec 1>&2 # redirect all output to stderr for logging

# --------------------------------

BOLD_GREEN="\e[32;1m"
BOLD_CYAN="\e[36;1m"
RESET="\e[0m"

DIR=${1-$(pwd)}
cd $DIR

request=$(mktemp --tmpdir cf-flyway-resource-check.XXXXXX)
cat > $request <&0

cat < $request | jq -r '.params'

# --------------------------------

PCF_API=$(jq -r '.source.api // empty' < $request)
PCF_ORG=$(jq -r '.source.organization // empty' < $request)
PCF_SPACE=$(jq -r '.source.space // empty' < $request)
PCF_USERNAME=$(jq -r '.source.username // empty' < $request)
PCF_PASSWORD=$(jq -r '.source.password // empty' < $request)
PCF_SERVICE=$(jq -r '.source.service // empty' < $request)

LOCATIONS=$(jq -r '.params.locations // empty' < $request)
COMMANDS=$(jq -r '.params.commands // empty' < $request)
FLYWAY_CONF=$(jq -r '.params.flyway_conf // empty' < $request)

[[ -z "$COMMANDS" ]]              && COMMANDS=$(jq -n '["info", "migrate", "info"]')
[[ -f "$FLYWAY_CONF" ]]           && FLYWAY_CONF=$(cat $FLYWAY_CONF)

[[ ! -z "$PCF_API" ]]             && echo "PCF_API : $PCF_API" || echo "'source.api' must be set to the PCF API endpoint!"
[[ ! -z "$PCF_ORG" ]]             && echo "PCF_ORG : $PCF_ORG" || echo "'source.organization' must be set to the organization for PCF deployment!"
[[ ! -z "$PCF_SPACE" ]]           && echo "PCF_SPACE : $PCF_SPACE" || echo "'source.space' must be set to the space for PCF deployment!"
[[ ! -z "$PCF_USERNAME" ]]        && echo "PCF_USERNAME : $PCF_USERNAME" || echo "'source.user' must be set to the username for PCF deployment!"
[[ ! -z "$PCF_PASSWORD" ]]        && echo "PCF_PASSWORD : *************" || echo "'source.password' must be set to the password for PCF deployment!"
[[ ! -z "$PCF_SERVICE" ]]         && echo "PCF_SERVICE : $PCF_SERVICE" || echo "'source.service' the database service instance name."

[[ ! -z "$LOCATIONS" ]]           && echo "LOCATIONS : $LOCATIONS" || echo "(Optional) 'params.locations' Comma-separated list of locations to scan recursively for migrations."
[[ ! -z "$COMMANDS" ]]            && echo "COMMANDS : $COMMANDS" || echo "(Optional) 'params.commands' Comma-separated list of flyway commands to execute. (Default -> params.commands: [\"info\", \"migrate\", \"info\"])"
[[ ! -z "$FLYWAY_CONF" ]]         && echo "FLYWAY_CONF : $FLYWAY_CONF" || echo "(Optional) 'params.flyway_conf' Either a path to a flyway.config file OR inline flyway.config content."


# --------------------------------

# login to cloud foundry
cf login -a $PCF_API -u $PCF_USERNAME -p $PCF_PASSWORD -o $PCF_ORG -s $PCF_SPACE
echo -e '\n'

# create service key if not exist
cf create-service-key $PCF_SERVICE cf-flyway
echo -e '\n'

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
cat flyway.conf | sed "s/flyway\.password\=.*/flyway.password=************/" 
echo -e "${BOLD_GREEN}OK${RESET}\n"

# execute flyway commands
echo $COMMANDS | jq -cr '.[]' | while read cmd; do
    flyway $cmd
done
echo -e "${BOLD_GREEN}OK${RESET}\n"

# --------------------------------

OUT=$(date -u +"%F %T.%3N (utc)")

echo $OUT | jq -R . | jq -r '{version:{ref: .}}' >&3
