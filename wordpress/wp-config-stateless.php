<?php
/**
 * Stateless settings, required by wp-config.php (built from the official image's wp-config-docker.php,
 * see build-wp-config.sh). WORDPRESS_CONFIG_EXTRA runs first, so it can override any of these.
 */

// Code is immutable and comes from the image: WordPress, plugins and themes are updated by redeploying
defined( 'DISALLOW_FILE_MODS' ) || define( 'DISALLOW_FILE_MODS', true );
defined( 'AUTOMATIC_UPDATER_DISABLED' ) || define( 'AUTOMATIC_UPDATER_DISABLED', true );
defined( 'WP_AUTO_UPDATE_CORE' ) || define( 'WP_AUTO_UPDATE_CORE', false );

// Nginx Cache plugin: the FastCGI cache NGINX writes into the shared /var/www/html volume
defined( 'NGINX_CACHE_PATH' ) || define( 'NGINX_CACHE_PATH', '/var/www/html/cache' );

// Media offloading plugins read their settings from constants: each WP_STATELESS_MEDIA_* (wp-stateless,
// Google Cloud Storage) and MICROSOFT_AZURE_* (Microsoft Azure Storage) environment variable defines the
// constant of the same name. NAME_FILE reads the value from a file instead (Docker/Kubernetes secrets).
foreach ( getenv() as $stateless_env => $stateless_value ) {
	if ( ! preg_match( '/^(WP_STATELESS_MEDIA|MICROSOFT_AZURE)_[A-Z0-9_]+$/', $stateless_env ) ) {
		continue;
	}
	if ( '_FILE' === substr( $stateless_env, -5 ) ) {
		$stateless_env   = substr( $stateless_env, 0, -5 );
		$stateless_value = rtrim( file_get_contents( $stateless_value ), "\r\n" );
	}
	defined( $stateless_env ) || define( $stateless_env, $stateless_value );
}
unset( $stateless_env, $stateless_value );

// Reverse Proxy
if ( isset( $_SERVER['HTTP_X_FORWARDED_FOR'] ) ) {
	$http_x_headers = explode( ',', $_SERVER['HTTP_X_FORWARDED_FOR'] );
	$_SERVER['REMOTE_ADDR'] = $http_x_headers[0];
}
