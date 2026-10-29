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
		FASTCGI_CACHE_VALID
		REAL_IP_FROM
		REAL_IP_HEADER
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

# A hostname upstream (the Docker Compose service, which may have several replicas) is re-resolved with the
# container's DNS server; localhost and IP addresses (e.g. the Kubernetes sidecar setup) need no resolver
resolver=""
upstream_resolve=""
if [ "$UPSTREAM_SERVER" != localhost ] && ! [[ "$UPSTREAM_SERVER" =~ ^[0-9.]+$|: ]]; then
	nameserver="$(awk '/^nameserver/ { print $2; exit }' /etc/resolv.conf)"
	if [ -n "$nameserver" ]; then
		[[ "$nameserver" == *:* ]] && nameserver="[$nameserver]"
		resolver="resolver $nameserver valid=10s;"
		upstream_resolve=" resolve"
	fi
fi

# How long pages stay in the FastCGI cache. Each NGINX keeps its own cache, so with several NGINX instances
# (e.g. Kubernetes pods) a purge only reaches one of them: a short value bounds how stale the others can get
: "${FASTCGI_CACHE_VALID:=1h}"
if ! [[ "$FASTCGI_CACHE_VALID" =~ ^[0-9]+(ms|s|m|h|d|w|M|y)?$ ]]; then
	echo >&2 "error: FASTCGI_CACHE_VALID must be an NGINX time such as 10m or 1h, got '$FASTCGI_CACHE_VALID'"
	exit 1
fi

# Client addresses behind reverse proxies (NGINX Proxy Manager, an ingress controller, a CDN...): trust the
# REAL_IP_HEADER (default X-Forwarded-For) only from the REAL_IP_FROM addresses/CIDRs (comma or space separated).
# With real_ip_recursive, X-Forwarded-For is walked back past every trusted proxy to the first untrusted address.
: "${REAL_IP_HEADER:=X-Forwarded-For}"
real_ip_conf=""
if [ -n "${REAL_IP_FROM:-}" ]; then
	if ! [[ "$REAL_IP_HEADER" =~ ^[A-Za-z0-9-]+$ ]]; then
		echo >&2 "error: REAL_IP_HEADER must be a header name such as X-Forwarded-For, got '$REAL_IP_HEADER'"
		exit 1
	fi
	IFS=', ' read -r -a real_ip_sources <<< "$REAL_IP_FROM"
	for source in "${real_ip_sources[@]}"; do
		if ! [[ "$source" =~ ^([0-9a-fA-F:.]+(/[0-9]{1,3})?|unix:)$ ]]; then
			echo >&2 "error: REAL_IP_FROM entries must be addresses or CIDRs, got '$source'"
			exit 1
		fi
		real_ip_conf+="set_real_ip_from $source;"$'\n'
	done
	real_ip_conf+="real_ip_header $REAL_IP_HEADER;"$'\n'"real_ip_recursive on;"$'\n'
	echo >&2 "Taking client addresses from $REAL_IP_HEADER when sent by: $REAL_IP_FROM"
fi
printf '%s' "$real_ip_conf" > /etc/nginx/real-ip.conf

sed -i \
	-e "s|#{UPSTREAM_SERVER}|$UPSTREAM_SERVER|g" \
	-e "s|#{UPSTREAM_RESOLVE}|$upstream_resolve|g" \
	-e "s|#{RESOLVER}|$resolver|g" \
	-e "s|#{FASTCGI_CACHE_VALID}|$FASTCGI_CACHE_VALID|g" \
	/etc/nginx/nginx.conf

# wait upstream server availability then start NGINX service
wait-for-it "$UPSTREAM_SERVER:9000" --timeout=300 --strict
echo >&2 "Starting NGINX service..."
exec "$@"
