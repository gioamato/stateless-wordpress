#!/usr/bin/env bash
# Static checks for Dockerfiles, shell scripts, workflows and Composer files. Needs only Docker.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

status=0
run() {
	echo "# $1"; shift
	"$@" || status=1
}

# Run Composer with the same version as the WordPress image's build stage
composer_image="$(grep -oE '^FROM .*(composer:[^ ]+)' wordpress/Dockerfile | grep -oE 'composer:[^ ]+')"

for dockerfile in wordpress/Dockerfile nginx/Dockerfile; do
	run "hadolint ${dockerfile}" \
		docker run --rm -i hadolint/hadolint:v2.14.0 hadolint --failure-threshold error - < "$dockerfile"
done

# wait-for-it.sh is vendored from vishnubob/wait-for-it, so it is not linted here
run "shellcheck" \
	docker run --rm -v "$PWD:/mnt:ro" -w /mnt koalaman/shellcheck:v0.11.0 \
	nginx/docker-entrypoint.sh tests/smoke.sh tests/lint.sh .github/scripts/image-tag-exists.sh wordpress/build-wp-config.sh

run "actionlint" \
	docker run --rm -v "$PWD:/repo:ro" -w /repo rhysd/actionlint:1.7.7 -no-color

# Fails when composer.lock is out of sync with composer.json; the exact version pins are intentional
run "composer validate (${composer_image})" \
	docker run --rm -v "$PWD/wordpress:/app:ro" -w /app "$composer_image" \
	composer validate --no-check-all --no-check-publish

exit "$status"
