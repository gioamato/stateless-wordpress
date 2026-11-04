#!/usr/bin/env bash
# usage: php-versions.sh [DOCKERFILE]
# Prints the PHP versions the WordPress image is built for, as read from its Dockerfile, as
# {"versions":["php8.2",...],"default":"php8.3"}: one entry per base-<version> stage, and the
# default of ARG PHP_VERSION (the version the floating wordpress-alpine tag follows).
# Fails unless every base stage is FROM wordpress:<version>-fpm-alpine@sha256:<digest> AS base-<version>,
# the default is one of them, and the final stage is FROM base-${PHP_VERSION}.
set -euo pipefail

dockerfile="${1:-$(dirname "$0")/../../wordpress/Dockerfile}"
fail() { echo "$dockerfile: $*" >&2; exit 1; }

versions=()
while read -r line; do
	[[ "$line" =~ ^FROM\ +wordpress:(php[0-9]+\.[0-9]+)-fpm-alpine@sha256:[0-9a-f]{64}\ +AS\ +base-(php[0-9]+\.[0-9]+)$ ]] \
		|| fail "not a pinned base stage: $line"
	[ "${BASH_REMATCH[1]}" = "${BASH_REMATCH[2]}" ] || fail "stage base-${BASH_REMATCH[2]} uses the ${BASH_REMATCH[1]} image"
	versions+=("${BASH_REMATCH[1]}")
done < <(grep -E '^FROM +wordpress:' "$dockerfile")
[ "${#versions[@]}" -gt 0 ] || fail "no base-<version> stages"
[ "$(printf '%s\n' "${versions[@]}" | sort -u | wc -l)" -eq "${#versions[@]}" ] || fail "duplicate base stages"

default="$(sed -nE 's/^ARG +PHP_VERSION=(php[0-9]+\.[0-9]+)$/\1/p' "$dockerfile")"
[ -n "$default" ] || fail "no ARG PHP_VERSION=php<major>.<minor> default"
printf '%s\n' "${versions[@]}" | grep -qxF "$default" || fail "default $default has no base-$default stage"
# shellcheck disable=SC2016 # the literal Dockerfile line
final='FROM base-${PHP_VERSION}'
[ "$(grep -E '^FROM ' "$dockerfile" | tail -1)" = "$final" ] || fail "the final stage is not $final"

json="$(printf '"%s",' "${versions[@]}")"
printf '{"versions":[%s],"default":"%s"}\n' "${json%,}" "$default"
