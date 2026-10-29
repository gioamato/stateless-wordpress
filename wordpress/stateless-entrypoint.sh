#!/usr/bin/env bash
# Keeps /var/www/html in sync with the code in this image (/usr/src/wordpress), then hands over to the official
# entrypoint. The official one only copies the code into an empty /var/www/html, so a volume that outlives the
# container (e.g. while NGINX keeps it mounted during `docker compose up`) would keep serving the old code.
#
# Nothing in /var/www/html is data: media are offloaded to object storage and the FastCGI cache is disposable.
# So whenever the code differs from what the volume holds, the volume is wiped and refilled. The code is
# identified by a hash of its files, computed at startup so images built FROM this one are covered too.
# Replicas sharing the volume (Docker Compose) sync one at a time, and only the first one copies.
set -Eeuo pipefail

if [ "${1-}" = 'php-fpm' ]; then
	code_id="$(cd /usr/src/wordpress && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)"

	exec 9> /var/www/html/.sync.lock
	flock 9
	if [ "$(cat /var/www/html/.code-id 2>/dev/null || true)" != "$code_id" ]; then
		echo >&2 "Syncing WordPress code from the image into /var/www/html (code $code_id)"
		find /var/www/html -mindepth 1 -maxdepth 1 ! -name .sync.lock -exec rm -rf {} +
		# The official copy step, without starting php-fpm
		docker-ensure-installed.sh
		echo "$code_id" > /var/www/html/.code-id
	fi
	flock -u 9
	exec 9>&-
fi

exec docker-entrypoint.sh "$@"
