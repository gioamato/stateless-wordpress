FROM composer:2.1.3 as build
WORKDIR /usr/src/app
COPY composer.* ./
RUN composer install --no-dev

FROM wordpress:5.8.0-fpm-alpine

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

# Copy WordPress files
COPY wp-config.php /usr/src/wordpress/wp-config.php
COPY --from=build /usr/src/app/wp-content /usr/src/wordpress/wp-content
RUN chown -R www-data:www-data /usr/src/wordpress
