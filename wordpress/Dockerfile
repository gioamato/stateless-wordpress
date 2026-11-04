# PHP version of the final image: one of the base-<version> stages below. Its default is the version
# the floating wordpress-alpine tag follows. CI builds, tests and releases every base-<version> stage
ARG PHP_VERSION=php8.3

# Build stage output is platform-independent, so run it natively on the build host
FROM --platform=$BUILDPLATFORM composer:2.11.1 AS build
WORKDIR /usr/src/app
COPY composer.* ./
RUN composer install --no-dev
COPY mu-plugins ./wp-content/mu-plugins
COPY themes ./themes
RUN for file in `ls ./themes/*.zip`; do unzip "${file}" -d "./wp-content/themes"; done
COPY plugins ./plugins
RUN for file in `ls ./plugins/*.zip`; do unzip "${file}" -d "./wp-content/plugins"; done

# One base stage per supported PHP version, named base-<tag's PHP version>. Tagged by PHP version: WordPress
# core is copied into the volume on first boot and then updates itself (or, with WORDPRESS_STATELESS, is updated
# by deploying a newer image). Each is a FROM line pinned by digest, so Dependabot refreshes every digest;
# BuildKit builds only the stage PHP_VERSION selects. To add a version, add its line here
FROM wordpress:php8.2-fpm-alpine@sha256:6498fd5623c4f4085aea5c56a4b19bd5a69b4dd97923e71b0b72a27fb23a68cf AS base-php8.2
FROM wordpress:php8.3-fpm-alpine@sha256:82d93a279778e5307902813c402b9118521e8104459a0e350ed719f6d6c4d1ab AS base-php8.3
FROM wordpress:php8.4-fpm-alpine@sha256:d3dd20e58ada4d172fe6a580b31885d20f9514363ef8147ff9a48181ed4977d9 AS base-php8.4
FROM wordpress:php8.5-fpm-alpine@sha256:58fc1e252c39e9c2939c4bc179cddb0ecbd583010dc46aafdd89cfee3f02ba03 AS base-php8.5

# Everything below is shared by every PHP version
# hadolint ignore=DL3006
FROM base-${PHP_VERSION}

# PHP defaults
ENV PHP_MEMORY_LIMIT="128M"
ENV PHP_UPLOAD_MAX_FILESIZE="50M"
ENV PHP_POST_MAX_SIZE="50M"
ENV PHP_MAX_EXECUTION_TIME="60"
ENV PHP_MAX_INPUT_TIME="-1"
ENV PHP_MAX_INPUT_VARS="1000"

# Copy the PHP configuration file
COPY php.ini "$PHP_INI_DIR/conf.d/php.ini"

# OPcache defaults
ENV PHP_OPCACHE_ENABLE="1"
ENV PHP_OPCACHE_MEMORY_CONSUMPTION="128"
ENV PHP_OPCACHE_MAX_ACCELERATED_FILES="10000"
ENV PHP_OPCACHE_REVALIDATE_FREQUENCY="0"
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS="0"

# Install opcache unless the base already has it (the official image enables it, and PHP 8.5+ always builds
# it in, so docker-php-ext-install fails there), and add the configuration file
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN php -m | grep -qxF 'Zend OPcache' || docker-php-ext-install opcache
COPY opcache.ini "$PHP_INI_DIR/conf.d/opcache.ini"

# PHP-FPM defaults
ENV PHP_FPM_PM="dynamic"
ENV PHP_FPM_MAX_CHILDREN="5"
ENV PHP_FPM_START_SERVERS="2"
ENV PHP_FPM_MIN_SPARE_SERVERS="1"
ENV PHP_FPM_MAX_SPARE_SERVERS="2"
ENV PHP_FPM_MAX_REQUESTS="1000"

# Copy the PHP-FPM configuration file, named to load after all of the image's pool files
# (read in alphabetical order, last value wins), so these settings always apply
COPY ./php-fpm.conf /usr/local/etc/php-fpm.d/zzz-custom.conf

# Default Themes/Plugins Cleanup
RUN rm -r /usr/src/wordpress/wp-content/themes/*
RUN rm -r /usr/src/wordpress/wp-content/plugins/*

# wp-config.php is the official image's wp-config-docker.php (WORDPRESS_* variables, *_FILE secrets),
# with hooks for this image's additions (stateless mode, offloading) and the deprecated WP_* variable names
COPY --chown=www-data:www-data wp-config-extra.php wp-config-env-compat.php /usr/src/wordpress/
COPY build-wp-config.sh /usr/local/bin/build-wp-config
RUN build-wp-config

# Copy WordPress files
COPY --chown=www-data:www-data --from=build /usr/src/app/wp-content /usr/src/wordpress/wp-content
