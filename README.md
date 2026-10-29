# Stateless WordPress

[![Release](https://github.com/gioamato/stateless-wordpress/actions/workflows/release.yml/badge.svg)](https://github.com/gioamato/stateless-wordpress/actions/workflows/release.yml)
[![GitHub](https://img.shields.io/github/license/gioamato/stateless-wordpress)](https://github.com/gioamato/stateless-wordpress/blob/master/LICENSE)
[![Docker Pulls](https://img.shields.io/docker/pulls/gioamato/stateless-wordpress)](https://hub.docker.com/r/gioamato/stateless-wordpress/tags)

Minimal, cloud-native, battle-tested WordPress environment meant to be used both in local development and staging/production.

## Supported Architectures

Images are published as multi-arch manifests for `linux/amd64` and `linux/arm64` (e.g. Apple Silicon, AWS Graviton, Raspberry Pi 4/5 with a 64-bit OS). Docker pulls the right variant automatically.

## Image Tags

Each image is published under three tags on [Docker Hub](https://hub.docker.com/r/gioamato/stateless-wordpress/tags):

| Tag | Example | Moves when |
|---|---|---|
| `<image>-alpine` | `wordpress-alpine` | every release |
| `<image>-<version>-alpine` | `wordpress-7.1.3-alpine` | every release of that upstream WordPress/NGINX version |
| `<image>-<version>-alpine-<commit>` | `wordpress-7.1.3-alpine-dee6de0` | never: each commit is released once, so use it to roll back to a known build |

A release is published only after both architectures pass the smoke test (see [Testing](#testing)), and only for the images whose directory changed.

### Pinning in production

A tag is only as immutable as the registry account behind it, while a digest always resolves to the same bytes. For production, pin the version tag together with its multi-arch digest:

```yaml
image: gioamato/stateless-wordpress:wordpress-7.1.3-alpine@sha256:<digest>
```

The digest decides what is pulled and the tag keeps the reference readable; tools like Renovate can update the digest when a new release moves the tag. Every release on the [Releases page](https://github.com/gioamato/stateless-wordpress/releases) lists the ready-to-copy pin for each image it published.

## Usage

### Local Development Environment

```bash
# Clone the repo
git clone https://github.com/gioamato/stateless-wordpress.git
cd stateless-wordpress

# Spin it up with Docker Compose
docker compose up -d

# Open your browser and head to http://localhost:8080
# You will find the famous WordPress 5-minute install
```

### Kubernetes

```bash
# Deploy with kubectl
kubectl apply -f https://raw.githubusercontent.com/gioamato/stateless-wordpress/master/deploy/kubernetes/deploy.yaml

# The namespace 'stateless-wordpress' is created to host the example resources:
# - 1 Stateful MySQL replica with emptyDir volume (data lost on restart)
# - 3 Stateless WordPress replicas (horizontal scaling)
# - A Secret storing WordPress Enviroment Configuration
# - A Service with type LoadBalancer to expose the app

# Open your browser and head to the service External IP
# You will find the famous WordPress 5-minute install
```

## Configuration

`wp-config.php` is built from the [official WordPress image](https://hub.docker.com/_/wordpress)'s `wp-config-docker.php`, so the official variables work unchanged:

- `WORDPRESS_DB_HOST`, `WORDPRESS_DB_USER`, `WORDPRESS_DB_PASSWORD`, `WORDPRESS_DB_NAME`, `WORDPRESS_DB_CHARSET`, `WORDPRESS_DB_COLLATE`, `WORDPRESS_TABLE_PREFIX`
- `WORDPRESS_AUTH_KEY`, `WORDPRESS_SECURE_AUTH_KEY`, `WORDPRESS_LOGGED_IN_KEY`, `WORDPRESS_NONCE_KEY`, `WORDPRESS_AUTH_SALT`, `WORDPRESS_SECURE_AUTH_SALT`, `WORDPRESS_LOGGED_IN_SALT`, `WORDPRESS_NONCE_SALT`. Set them when running more than one replica; when unset, WordPress keeps generated salts in the database.
- `WORDPRESS_DEBUG` (any non-empty value enables `WP_DEBUG`) and `WORDPRESS_CONFIG_EXTRA` (PHP code evaluated in `wp-config.php`)
- Append `_FILE` to any of them to read the value from a file instead, e.g. `WORDPRESS_DB_PASSWORD_FILE=/run/secrets/db-password` for Docker or Kubernetes secrets.

On top of the official template, `wp-config-stateless.php` disables file edits and automatic updates (WordPress, plugins and themes come from the image and are updated by redeploying), and turns media offloading settings into the constants the bundled plugins read:

- [WP-Stateless](https://wordpress.org/plugins/wp-stateless/) (Google Cloud Storage): any `WP_STATELESS_MEDIA_*` variable, e.g. `WP_STATELESS_MEDIA_MODE=stateless`, `WP_STATELESS_MEDIA_BUCKET`, `WP_STATELESS_MEDIA_JSON_KEY`; the plugin also reads `GOOGLE_APPLICATION_CREDENTIALS` itself.
- [Microsoft Azure Storage for WordPress](https://wordpress.org/plugins/windows-azure-storage/): any `MICROSOFT_AZURE_*` variable, e.g. `MICROSOFT_AZURE_ACCOUNT_NAME`, `MICROSOFT_AZURE_ACCOUNT_KEY`, `MICROSOFT_AZURE_CONTAINER`, `MICROSOFT_AZURE_USE_FOR_DEFAULT_UPLOAD=1`.
- Append `_FILE` to read a value from a file, e.g. `MICROSOFT_AZURE_ACCOUNT_KEY_FILE=/run/secrets/azure-key`.

The `WP_DB_*` and `WP_*_KEY`/`WP_*_SALT` names used by earlier versions of this image still work when the matching `WORDPRESS_*` variable is unset, but are deprecated.

## Testing

Every pull request runs the same checks you can run locally (only Docker is required):

```bash
# Lint Dockerfiles, shell scripts and workflows, and check composer.lock is in sync
tests/lint.sh

# Build both images, start the stack and test it end to end:
# env-based PHP/FPM config, WordPress install, bundled plugins/theme/translations,
# FastCGI cache, NGINX access rules and clean PHP/NGINX logs
tests/smoke.sh
```

The smoke test uses its own Compose project and port (`SMOKE_PORT`, default `8089`), so it can run next to the local development stack.

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## Credits
- [WordPress.org](https://wordpress.org/about/) - This project is built around the great work at WordPress.
- [the Docker Community⁠](https://github.com/docker-library/wordpress) - The official WordPress Docker image is used as base image here.
- [Composer](https://getcomposer.org/) - Used to manage PHP dependencies and packages.
- [WordPress Packagist](https://wpackagist.org/) - Allows WordPress plugins and themes to be managed using Composer.
- [nginx](https://nginx.org/) - Used as reverse proxy with FastCGI + Caching.
- [vishnubob/wait-for-it](https://github.com/vishnubob/wait-for-it) - Used in the nginx image to wait for the upstream server availability (WordPress).

## License
[MIT](https://choosealicense.com/licenses/mit/)
