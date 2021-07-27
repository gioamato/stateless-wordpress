<?php

// MySQL Configuration
define( 'DB_NAME',     $_ENV['WP_DB_NAME']);
define( 'DB_USER',     $_ENV['WP_DB_USER']);
define( 'DB_PASSWORD', $_ENV['WP_DB_PASSWORD']);
define( 'DB_HOST',     $_ENV['WP_DB_HOST']);
define( 'DB_CHARSET',  $_ENV['WP_DB_CHARSET']);
define( 'DB_COLLATE',  $_ENV['WP_DB_COLLATE']);
$table_prefix = 'wp_';

// Authentication Unique Keys and Salts
define( 'AUTH_KEY',         $_ENV['WP_AUTH_KEY']);
define( 'SECURE_AUTH_KEY',  $_ENV['WP_SECURE_AUTH_KEY']);
define( 'LOGGED_IN_KEY',    $_ENV['WP_LOGGED_IN_KEY']);
define( 'NONCE_KEY',        $_ENV['WP_NONCE_KEY']);
define( 'AUTH_SALT',        $_ENV['WP_AUTH_SALT']);
define( 'SECURE_AUTH_SALT', $_ENV['WP_SECURE_AUTH_SALT']);
define( 'LOGGED_IN_SALT',   $_ENV['WP_LOGGED_IN_SALT']);
define( 'NONCE_SALT',       $_ENV['WP_NONCE_SALT']);

// Debug
define( 'WP_DEBUG', false );

// Stateless 
define( 'DISALLOW_FILE_MODS', true );
define( 'AUTOMATIC_UPDATER_DISABLED', true );
define( 'WP_AUTO_UPDATE_CORE', false );

// Azure Storage
// define( 'MICROSOFT_AZURE_ACCOUNT_NAME',           $_ENV['MICROSOFT_AZURE_ACCOUNT_NAME']);
// define( 'MICROSOFT_AZURE_ACCOUNT_KEY',            $_ENV['MICROSOFT_AZURE_ACCOUNT_KEY']);
// define( 'MICROSOFT_AZURE_CONTAINER',              $_ENV['MICROSOFT_AZURE_CONTAINER']);
// define( 'MICROSOFT_AZURE_CNAME',                  $_ENV['MICROSOFT_AZURE_CNAME']);
// define( 'MICROSOFT_AZURE_USE_FOR_DEFAULT_UPLOAD', $_ENV['MICROSOFT_AZURE_USE_FOR_DEFAULT_UPLOAD']);

// Reverse Proxy
if ( strpos( $_SERVER['HTTP_X_FORWARDED_PROTO'], 'https' ) !== false ) {
	$_SERVER['HTTPS'] = 'on';
}

if ( isset( $_SERVER['HTTP_X_FORWARDED_FOR'] ) ) {
	$http_x_headers = explode( ',', $_SERVER['HTTP_X_FORWARDED_FOR'] );
	$_SERVER['REMOTE_ADDR'] = $http_x_headers[0];
}

// Absolute path to the WordPress directory
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', dirname( __FILE__ ) . '/' );
}

// Sets up WordPress vars and included files
require_once( ABSPATH . 'wp-settings.php' );
