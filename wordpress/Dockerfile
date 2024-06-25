FROM composer:2.7.7 as build
WORKDIR /usr/src/app
COPY composer.* ./
RUN composer install --no-dev
COPY mu-plugins ./wp-content/mu-plugins
COPY themes ./themes
RUN for file in `ls ./themes/*.zip`; do unzip "${file}" -d "./wp-content/themes"; done
COPY plugins ./plugins
RUN for file in `ls ./plugins/*.zip`; do unzip "${file}" -d "./wp-content/plugins"; done

FROM wordpress:6.5.5-fpm-alpine

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

# Install opcache and add the configuration file
RUN docker-php-ext-install opcache
ADD opcache.ini "$PHP_INI_DIR/conf.d/opcache.ini"

# PHP-FPM defaults
ENV PHP_FPM_PM="dynamic"
ENV PHP_FPM_MAX_CHILDREN="5"
ENV PHP_FPM_START_SERVERS="2"
ENV PHP_FPM_MIN_SPARE_SERVERS="1"
ENV PHP_FPM_MAX_SPARE_SERVERS="2"
ENV PHP_FPM_MAX_REQUESTS="1000"

# Copy the PHP-FPM configuration file
COPY ./www.conf /usr/local/etc/php-fpm.d/www.conf

# Default Themes/Plugins Cleanup
RUN rm -r /usr/src/wordpress/wp-content/themes/*
RUN rm -r /usr/src/wordpress/wp-content/plugins/*

# Copy WordPress files
# TODO: Use wp-config-docker.php from the WordPress official Docker image
COPY --chown=www-data:www-data wp-config.php /usr/src/wordpress/wp-config.php
COPY --chown=www-data:www-data --from=build /usr/src/app/wp-content /usr/src/wordpress/wp-content
