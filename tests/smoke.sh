#!/usr/bin/env bash
# End-to-end smoke test for the WordPress + NGINX images, run on every PR and before every push.
#
# Usage:
#   tests/smoke.sh                     build both images with Docker Compose, then test them
#   SMOKE_NO_BUILD=1 tests/smoke.sh    test already-built images ($WORDPRESS_IMAGE / $NGINX_IMAGE,
#                                      default stateless-wordpress:{wordpress,nginx}-test)
set -euo pipefail
cd "$(dirname "$0")/.."

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-stateless-wordpress-smoke}"
export SMOKE_PORT="${SMOKE_PORT:-8089}"
BASE="http://localhost:${SMOKE_PORT}"
SITE_TITLE="Smoke Test Site"

compose() { docker compose -f docker-compose.yml -f tests/compose.smoke.yml "$@"; }
wp() { compose run --rm -T cli wp "$@"; }

failures=0
pass() { echo "ok   - $*"; }
fail() { echo "FAIL - $*"; failures=$((failures + 1)); }

cleanup() {
	local status=$?
	if [ "$status" -ne 0 ] || [ "$failures" -ne 0 ]; then
		echo "--- container logs ---"
		compose logs --no-color --tail=200 || true
	fi
	compose --profile cli down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

# usage: expect_status CODE PATH [curl args...]
expect_status() {
	local want="$1" path="$2"; shift 2
	local got
	got="$(curl -s -o /dev/null -w '%{http_code}' "$@" "${BASE}${path}")"
	if [ "$got" = "$want" ]; then pass "GET ${path} -> ${want}"; else fail "GET ${path} -> ${got}, want ${want}"; fi
}

# usage: expect_header PATH HEADER VALUE [curl args...]
expect_header() {
	local path="$1" header="$2" want="$3"; shift 3
	local got
	got="$(curl -s -o /dev/null -D - "$@" "${BASE}${path}" | tr -d '\r' | awk -v h="${header,,}:" 'tolower($1) == h { print $2 }')"
	if [ "$got" = "$want" ]; then pass "${path} ${header}: ${want}"; else fail "${path} ${header}: '${got}', want '${want}'"; fi
}

# usage: expect_eq DESCRIPTION WANT GOT
expect_eq() {
	if [ "$3" = "$2" ]; then pass "$1 = $2"; else fail "$1 = '$3', want '$2'"; fi
}

# usage: expect_line DESCRIPTION LINE OUTPUT
expect_line() {
	if grep -qxF -- "$2" <<<"$3"; then pass "$1 has $2"; else fail "$1 is missing $2 (got: $(tr '\n' ' ' <<<"$3"))"; fi
}

# usage: expect_clean_page PATH -- the page renders with no PHP errors printed into it
expect_clean_page() {
	local body
	body="$(curl -s "${BASE}$1")"
	if grep -qE '(Fatal error|Warning|Deprecated|Notice|Parse error)</b>:' <<<"$body"; then
		fail "$1 prints PHP errors: $(grep -oE '(Fatal error|Warning|Deprecated|Notice|Parse error)</b>:[^<]*' <<<"$body" | head -3)"
	else
		pass "$1 has no PHP errors in the page"
	fi
}

echo "# Starting the stack (project ${COMPOSE_PROJECT_NAME}, port ${SMOKE_PORT})"
if [ -n "${SMOKE_NO_BUILD:-}" ]; then
	compose up -d --no-build
else
	compose up -d --build
fi

# NGINX only starts once php-fpm accepts connections on wordpress:9000
for _ in $(seq 1 120); do
	curl -sf -o /dev/null "${BASE}/healthz" && break
	sleep 1
done
expect_status 200 /healthz
if [ "$failures" -ne 0 ]; then
	echo "Stack did not come up"
	exit 1
fi

echo "# Configuration from environment variables"
expect_eq "memory_limit (php.ini from PHP_MEMORY_LIMIT)" 192M \
	"$(compose exec -T wordpress php -r 'echo ini_get("memory_limit");')"
expect_eq "pm.max_children (FPM pool from PHP_FPM_MAX_CHILDREN)" 7 \
	"$(compose exec -T wordpress php-fpm -tt 2>&1 | sed -n 's/.*pm\.max_children = //p' | tail -1)"
# Every php.ini and opcache.ini directive reads a variable: each one gets a non-default value in a one-off
# php process (get_cfg_var shows the value from the file, before any runtime change)
for setting in \
	PHP_MEMORY_LIMIT=256M:memory_limit \
	PHP_UPLOAD_MAX_FILESIZE=64M:upload_max_filesize \
	PHP_POST_MAX_SIZE=72M:post_max_size \
	PHP_MAX_INPUT_VARS=2000:max_input_vars \
	PHP_OPCACHE_ENABLE=0:opcache.enable \
	PHP_OPCACHE_MEMORY_CONSUMPTION=96:opcache.memory_consumption \
	PHP_OPCACHE_MAX_ACCELERATED_FILES=5000:opcache.max_accelerated_files \
	PHP_OPCACHE_REVALIDATE_FREQUENCY=5:opcache.revalidate_freq \
	PHP_OPCACHE_VALIDATE_TIMESTAMPS=1:opcache.validate_timestamps; do
	variable="${setting%%=*}" value="${setting#*=}" directive="${setting##*:}"
	value="${value%%:*}"
	expect_eq "$directive ($variable)" "$value" \
		"$(compose exec -T -e "$variable=$value" wordpress php -r "echo get_cfg_var('$directive');")"
done
# The CLI forces max_execution_time (0) and max_input_time (-1) over any ini file, so read those two the way
# PHP parses the image's php.ini instead
for setting in PHP_MAX_EXECUTION_TIME=90:max_execution_time PHP_MAX_INPUT_TIME=30:max_input_time; do
	variable="${setting%%=*}" value="${setting#*=}" directive="${setting##*:}"
	value="${value%%:*}"
	expect_eq "$directive ($variable)" "$value" \
		"$(compose exec -T -e "$variable=$value" wordpress \
			php -r "echo parse_ini_file(getenv('PHP_INI_DIR') . '/conf.d/php.ini')['$directive'];")"
done
# Same for the FPM pool, in one php-fpm -tt run (the running pool is not touched)
fpm_config="$(compose exec -T -e PHP_FPM_PM=static -e PHP_FPM_MAX_CHILDREN=9 -e PHP_FPM_START_SERVERS=3 \
	-e PHP_FPM_MIN_SPARE_SERVERS=2 -e PHP_FPM_MAX_SPARE_SERVERS=4 -e PHP_FPM_MAX_REQUESTS=500 wordpress php-fpm -tt 2>&1)"
for setting in PHP_FPM_PM=static:pm PHP_FPM_MAX_CHILDREN=9:pm.max_children PHP_FPM_START_SERVERS=3:pm.start_servers \
	PHP_FPM_MIN_SPARE_SERVERS=2:pm.min_spare_servers PHP_FPM_MAX_SPARE_SERVERS=4:pm.max_spare_servers \
	PHP_FPM_MAX_REQUESTS=500:pm.max_requests; do
	variable="${setting%%=*}" value="${setting#*=}" directive="${setting##*:}"
	value="${value%%:*}"
	expect_eq "$directive ($variable)" "$value" \
		"$(sed -n "s/.*[[:space:]]${directive//./\\.} = //p" <<<"$fpm_config" | tail -1)"
done
if compose exec -T wordpress php-fpm -t >/dev/null 2>&1; then pass "php-fpm -t"; else fail "php-fpm -t"; fi
if compose exec -T nginx nginx -t >/dev/null 2>&1; then pass "nginx -t"; else fail "nginx -t"; fi
expect_line "NGINX cache lifetime (FASTCGI_CACHE_VALID)" "            fastcgi_cache_valid 200 302 2h;" \
	"$(compose exec -T nginx nginx -T 2>/dev/null)"

echo "# WordPress install through NGINX"
install_body="$(curl -s -X POST "${BASE}/wp-admin/install.php?step=2" \
	--data-urlencode "weblog_title=${SITE_TITLE}" \
	--data-urlencode "user_name=admin" \
	--data-urlencode "admin_password=smoke-test-password-1!" \
	--data-urlencode "admin_password2=smoke-test-password-1!" \
	--data-urlencode "pw_weak=1" \
	--data-urlencode "admin_email=admin@example.com" \
	--data-urlencode "blog_public=0" \
	--data-urlencode "language=")"
if grep -q 'Success!' <<<"$install_body"; then pass "install.php step 2"; else fail "install.php step 2 did not report success"; fi
if wp core is-installed >/dev/null 2>&1; then pass "wp core is-installed"; else fail "wp core is-installed"; fi

echo "# wp-config.php (official template with this image's hooks)"
# The web side reads WORDPRESS_DB_PASSWORD_FILE and the deprecated WP_DB_USER (neither default would connect):
# the install above proves both
expect_eq "MICROSOFT_AZURE_CONTAINER (offloading constant from an env variable)" smoke-container \
	"$(wp eval 'echo MICROSOFT_AZURE_CONTAINER;')"
expect_eq "MICROSOFT_AZURE_ACCOUNT_KEY (offloading constant from a *_FILE secret)" smoke-account-key \
	"$(wp eval 'echo MICROSOFT_AZURE_ACCOUNT_KEY;')"
# Default (stateful) mode: WordPress may install and update code; WORDPRESS_STATELESS=1 locks it to the image
expect_eq "file mods and auto-updates (default)" "false false" \
	"$(wp eval 'echo var_export(defined("DISALLOW_FILE_MODS") && DISALLOW_FILE_MODS, true), " ", var_export(defined("AUTOMATIC_UPDATER_DISABLED") && AUTOMATIC_UPDATER_DISABLED, true);')"
expect_eq "file mods and auto-updates disabled (WORDPRESS_STATELESS=1)" "true true" \
	"$(compose run --rm -T -e WORDPRESS_STATELESS=1 cli wp eval 'echo var_export(DISALLOW_FILE_MODS, true), " ", var_export(AUTOMATIC_UPDATER_DISABLED, true);')"

echo "# Bundled plugins, theme and language"
# Nginx Cache is a must-use plugin: loaded without activation, with its settings pinned to the constants
expect_line "must-use plugins" stateless-wordpress-nginx-cache "$(wp plugin list --status=must-use --field=name)"
expect_eq "Nginx Cache loaded" yes "$(wp eval 'echo class_exists("NginxCache") ? "yes" : "no";')"
expect_eq "nginx_cache_path (NGINX_CACHE_PATH)" /var/www/html/cache "$(wp option get nginx_cache_path)"
expect_eq "nginx_auto_purge (NGINX_AUTO_PURGE)" 1 "$(wp option get nginx_auto_purge)"
expect_line "plugins" windows-azure-storage "$(wp plugin list --field=name)"
expect_eq "active theme" twentytwentyfive "$(wp theme list --status=active --field=name)"
expect_eq "locale" en_US "$(wp eval 'echo get_locale();')"
if wp plugin activate --all >/dev/null; then pass "all plugins activate"; else fail "activating plugins"; fi

echo "# Front end and FastCGI cache"
expect_status 200 /
# Capture the page first: piping curl into grep -q fails under pipefail when grep exits early
home_body="$(curl -s "${BASE}/")"
if grep -qF "$SITE_TITLE" <<<"$home_body"; then pass "/ shows the site title"; else fail "/ does not show the site title"; fi
expect_clean_page /
expect_status 200 /wp-login.php
expect_clean_page /wp-login.php
expect_status 200 / -H 'X-Forwarded-Proto: https'
curl -s -o /dev/null "${BASE}/"
expect_header / X-Cache HIT
# The forwarded scheme is part of the cache key, so a page cached for one scheme (e.g. a redirect
# to HTTPS for a direct plain-HTTP request) is never served to requests that came in another way
expect_header / X-Cache MISS -H 'X-Forwarded-Proto: smoke-test'
expect_header /wp-login.php X-Cache BYPASS
# Publishing content purges the cache through the Nginx Cache plugin, so the next visit is served fresh
curl -s -o /dev/null "${BASE}/"
expect_header / X-Cache HIT
wp post create --post_status=publish --post_title="Cache purge check" >/dev/null
expect_header / X-Cache MISS

echo "# Access rules"
expect_status 403 /wp-config.php
expect_status 403 /wp-config-docker.php
expect_status 403 /wp-config-extra.php
expect_status 403 /wp-config-sample.php
# Include-only PHP files (WordPress hardening guide, plus wp-settings.php in the root)
for path in /wp-admin/includes/admin.php /wp-includes/version.php /wp-includes/js/tinymce/langs/wp-langs-en.php \
	/wp-includes/theme-compat/header.php /wp-settings.php; do
	expect_status 403 "$path"
done
# Scripts in wp-includes subfolders other than those still reach PHP, like the classic editor's wp-tinymce.php
expect_status 200 /wp-includes/js/tinymce/wp-tinymce.php
expect_status 403 /.htaccess
expect_status 403 /wp-content/uploads/shell.php
expect_status 403 /wp-content/uploads/page.html
expect_status 403 /wp-content/uploads/script.js
# media in uploads is not caught by the deny rules (404: the file does not exist)
expect_status 404 /wp-content/uploads/photo.png

echo "# Logs"
if errors="$(compose logs --no-color wordpress nginx | grep -E 'PHP (Fatal|Parse|Warning|Deprecated)|\[(emerg|alert|crit)\]')"; then
	fail "errors in container logs:"
	echo "$errors" | head -20
else
	pass "no PHP or NGINX errors in container logs"
fi

if [ "$failures" -ne 0 ]; then
	echo "${failures} check(s) failed"
	exit 1
fi
echo "All checks passed"
