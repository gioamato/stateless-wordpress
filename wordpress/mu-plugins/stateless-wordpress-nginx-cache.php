<?php
/**
 * Plugin Name: Nginx Cache (always on)
 * Description: Loads the bundled Nginx Cache plugin as a must-use plugin, so it can't be deactivated: NGINX always caches pages in this image, and this plugin is what purges that cache when content changes. Its cache path and auto-purge settings are pinned to the NGINX_CACHE_PATH and NGINX_AUTO_PURGE constants (see wp-config-extra.php, overridable with WORDPRESS_CONFIG_EXTRA).
 */

defined( 'ABSPATH' ) || exit;

// Pin the settings before the plugin loads: it reads nginx_auto_purge in its constructor
foreach ( array( 'nginx_cache_path' => 'NGINX_CACHE_PATH', 'nginx_auto_purge' => 'NGINX_AUTO_PURGE' ) as $stateless_option => $stateless_constant ) {
	if ( ! defined( $stateless_constant ) ) {
		continue;
	}
	$stateless_pin = static function () use ( $stateless_constant ) {
		return constant( $stateless_constant );
	};
	add_filter( "default_option_{$stateless_option}", $stateless_pin );
	add_filter( "option_{$stateless_option}", $stateless_pin );
	add_filter( "pre_update_option_{$stateless_option}", $stateless_pin );
}
unset( $stateless_option, $stateless_constant, $stateless_pin );

// Installed here by composer.json (installer-paths), since WordPress only loads the top-level files of mu-plugins
require_once __DIR__ . '/nginx-cache/nginx-cache.php';
