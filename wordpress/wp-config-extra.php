<?php
/**
 * This image's additions to wp-config.php, which is built from the official image's wp-config-docker.php
 * (see build-wp-config.sh). WORDPRESS_CONFIG_EXTRA runs first, so it can override any of these.
 */

// Nginx Cache plugin (a must-use plugin in this image, see mu-plugins/stateless-wordpress-nginx-cache.php): purges
// the FastCGI cache NGINX writes here whenever content changes
defined( 'NGINX_CACHE_PATH' ) || define( 'NGINX_CACHE_PATH', '/var/www/html/cache' );
defined( 'NGINX_AUTO_PURGE' ) || define( 'NGINX_AUTO_PURGE', 1 );

// WORDPRESS_STATELESS=1: for environments without persistent storage for /var/www/html (e.g. Kubernetes with
// an emptyDir), where the image is the only source of code. No installs or file edits from wp-admin and no
// automatic updates: WordPress, plugins and themes (composer.json) are updated by deploying a newer image.
// Media uploads must be offloaded to object storage.
if ( filter_var( getenv( 'WORDPRESS_STATELESS' ), FILTER_VALIDATE_BOOLEAN ) ) {
	defined( 'DISALLOW_FILE_MODS' ) || define( 'DISALLOW_FILE_MODS', true );
	defined( 'AUTOMATIC_UPDATER_DISABLED' ) || define( 'AUTOMATIC_UPDATER_DISABLED', true );
	defined( 'WP_AUTO_UPDATE_CORE' ) || define( 'WP_AUTO_UPDATE_CORE', false );
}

// Media offloading (Microsoft Azure Storage plugin): each MICROSOFT_AZURE_* environment variable defines the
// constant of the same name; MICROSOFT_AZURE_*_FILE reads the value from a file (Docker/Kubernetes secrets)
foreach ( getenv() as $extra_env => $extra_value ) {
	if ( ! preg_match( '/^MICROSOFT_AZURE_[A-Z0-9_]+$/', $extra_env ) ) {
		continue;
	}
	if ( '_FILE' === substr( $extra_env, -5 ) ) {
		$extra_env   = substr( $extra_env, 0, -5 );
		$extra_value = rtrim( file_get_contents( $extra_value ), "\r\n" );
	}
	defined( $extra_env ) || define( $extra_env, $extra_value );
}
unset( $extra_env, $extra_value );

// Reverse Proxy
if ( isset( $_SERVER['HTTP_X_FORWARDED_FOR'] ) ) {
	$http_x_headers = explode( ',', $_SERVER['HTTP_X_FORWARDED_FOR'] );
	$_SERVER['REMOTE_ADDR'] = $http_x_headers[0];
}
