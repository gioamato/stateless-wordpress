#!/bin/bash
set -euo pipefail

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

# allow upstream server to be specified via environment variables
envs=(
		UPSTREAM_SERVER
	)

haveConfig=
for e in "${envs[@]}"; do
	file_env "$e"
	if [ -z "$haveConfig" ] && [ -n "${!e}" ]; then
		haveConfig=1
	fi
done

# set upstream server if we have environment-supplied configuration value
# otherwise use 'localhost'
: "${UPSTREAM_SERVER:=localhost}"
echo >&2 "Setting '$UPSTREAM_SERVER' as upstream server"
sed -i -e "s/UPSTREAM_SERVER/$UPSTREAM_SERVER/g" /etc/nginx/conf.d/default.conf

# wait upstream server availability then start NGINX service
wait-for-it $UPSTREAM_SERVER:9000 --timeout=300 --strict
echo >&2 "Starting NGINX service..."
exec "$@"