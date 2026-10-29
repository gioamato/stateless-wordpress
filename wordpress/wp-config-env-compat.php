<?php
/**
 * Deprecated variable names, required at the top of wp-config.php (see build-wp-config.sh).
 *
 * Before wp-config.php was built from the official image's template, this image read WP_DB_HOST,
 * WP_AUTH_KEY, ... instead of WORDPRESS_DB_HOST, WORDPRESS_AUTH_KEY, ... Each old name still works
 * while its WORDPRESS_* (and WORDPRESS_*_FILE) counterpart is unset.
 */
foreach ( array(
	'DB_NAME', 'DB_USER', 'DB_PASSWORD', 'DB_HOST', 'DB_CHARSET', 'DB_COLLATE',
	'AUTH_KEY', 'SECURE_AUTH_KEY', 'LOGGED_IN_KEY', 'NONCE_KEY',
	'AUTH_SALT', 'SECURE_AUTH_SALT', 'LOGGED_IN_SALT', 'NONCE_SALT',
) as $compat_name ) {
	$compat_value = getenv( "WP_$compat_name" );
	if ( false !== $compat_value && false === getenv( "WORDPRESS_$compat_name" ) && false === getenv( "WORDPRESS_{$compat_name}_FILE" ) ) {
		// putenv() lasts for the current request, which is when wp-config.php reads it
		putenv( "WORDPRESS_$compat_name=$compat_value" );
	}
}
unset( $compat_name, $compat_value );
