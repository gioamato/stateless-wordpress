#!/usr/bin/env bash
# usage: image-tag-exists.sh IMAGE_REF
# Exits 0 if the tag exists in the registry, 1 if it does not, 2 on any other error
# (rate limit, network), so callers never mistake a registry error for a missing tag.
set -uo pipefail

if output="$(docker buildx imagetools inspect "$1" 2>&1)"; then
	exit 0
fi
if grep -qiE 'not found|manifest unknown' <<<"$output"; then
	exit 1
fi
echo "Could not check $1: $output" >&2
exit 2
