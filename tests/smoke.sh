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

# usage: expect_header PATH HEADER VALUE
expect_header() {
	local path="$1" header="$2" want="$3"
	local got
	got="$(curl -s -o /dev/null -D - "${BASE}${path}" | tr -d '\r' | awk -v h="${header,,}:" 'tolower($1) == h { print $2 }')"
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
expect_eq "opcache.enable (opcache.ini from PHP_OPCACHE_ENABLE)" 1 \
	"$(compose exec -T wordpress php -r 'echo ini_get("opcache.enable");')"
expect_eq "pm.max_children (FPM pool from PHP_FPM_MAX_CHILDREN)" 7 \
	"$(compose exec -T wordpress php-fpm -tt 2>&1 | sed -n 's/.*pm\.max_children = //p' | tail -1)"
if compose exec -T wordpress php-fpm -t >/dev/null 2>&1; then pass "php-fpm -t"; else fail "php-fpm -t"; fi
if compose exec -T nginx nginx -t >/dev/null 2>&1; then pass "nginx -t"; else fail "nginx -t"; fi

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

echo "# Bundled plugins, theme and translations"
plugins="$(wp plugin list --field=name)"
for plugin in nginx-cache windows-azure-storage wp-stateless; do expect_line "plugins" "$plugin" "$plugins"; done
expect_line "themes" twentytwentytwo "$(wp theme list --field=name)"
if compose exec -T wordpress test -f /var/www/html/wp-content/languages/it_IT.mo; then pass "it_IT core translation"; else fail "it_IT core translation is missing"; fi
expect_eq "DISALLOW_FILE_MODS" true "$(wp eval 'var_export(DISALLOW_FILE_MODS);')"
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
expect_header /wp-login.php X-Cache BYPASS

echo "# Access rules"
expect_status 403 /wp-config.php
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
