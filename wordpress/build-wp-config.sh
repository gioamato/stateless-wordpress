#!/bin/sh
# Builds /usr/src/wordpress/wp-config.php from the official image's wp-config-docker.php (WORDPRESS_* variables,
# *_FILE secrets, WORDPRESS_CONFIG_EXTRA), adding two hooks:
# - wp-config-env-compat.php at the top, for the deprecated WP_* variable names
# - wp-config-stateless.php before "That's all, stop editing!", for this repo's stateless settings
# The hooks use ABSPATH, not __DIR__: WP-CLI evals wp-config.php, where __DIR__ points into WP-CLI itself.
set -eu
cd /usr/src/wordpress

# The template has CRLF line endings, so lines are matched without their trailing \r
awk -v q="'" '
	{ line = $0; sub(/\r$/, "", line) }
	NR == 1 && line == "<?php" {
		print
		print "require_once ( defined( " q "ABSPATH" q " ) ? ABSPATH : __DIR__ . " q "/" q " ) . " q "wp-config-env-compat.php" q ";"
		compat = 1
		next
	}
	index(line, "/* That" q "s all, stop editing!") == 1 {
		print "require_once ( defined( " q "ABSPATH" q " ) ? ABSPATH : __DIR__ . " q "/" q " ) . " q "wp-config-stateless.php" q ";"
		print ""
		stateless = 1
	}
	{ print }
	END {
		if (!compat || !stateless) {
			print "wp-config-docker.php has changed: could not place the wp-config.php hooks" > "/dev/stderr"
			exit 1
		}
	}
' wp-config-docker.php > wp-config.php

chown www-data:www-data wp-config.php
php -l wp-config.php
