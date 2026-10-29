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
| `<image>-<version>-alpine` | `wordpress-php8.3-alpine`, `nginx-1.31.8-alpine` | every release on that PHP (WordPress) or NGINX version |
| `<image>-<version>-alpine-<commit>` | `wordpress-php8.3-alpine-dee6de0` | never: each commit is released once, so use it to roll back to a known build |

The WordPress image is tagged by PHP version, like the official image's `php8.3-fpm-alpine`: WordPress itself is copied in on first boot and then kept up to date by its own updater (see [Environments](#environments)).

A release is published only after both architectures pass the smoke test (see [Testing](#testing)), and only for the images whose directory changed.

### Pinning in production

A tag is only as immutable as the registry account behind it, while a digest always resolves to the same bytes. For production, pin the version tag together with its multi-arch digest:

```yaml
image: gioamato/stateless-wordpress:wordpress-php8.3-alpine@sha256:<digest>
```

The digest decides what is pulled and the tag keeps the reference readable; tools like Renovate can update the digest when a new release moves the tag. Every release on the [Releases page](https://github.com/gioamato/stateless-wordpress/releases) lists the ready-to-copy pin for each image it published.

## Usage

### Local Development Environment

```bash
# Clone the repo
git clone https://github.com/gioamato/stateless-wordpress.git
cd stateless-wordpress

# Spin it up with Docker Compose (stateful: WordPress lives in the wp-data volume and updates itself)
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
# - 3 Stateless WordPress replicas (horizontal scaling, WORDPRESS_STATELESS=1: offload media, see Environments)
# - A Secret storing WordPress Enviroment Configuration
# - A Service with type LoadBalancer to expose the app

# Open your browser and head to the service External IP
# You will find the famous WordPress 5-minute install
```

## Environments

The same image runs in two modes, chosen per deployment with `WORDPRESS_STATELESS` on the WordPress container. In both, the WordPress container copies WordPress, plugins and themes from the image into `/var/www/html` when that directory is empty (the official image's first-boot copy), and NGINX serves static files from the same volume.

| | Stateful (default) | Stateless (`WORDPRESS_STATELESS=1`) |
|---|---|---|
| For | Docker / Docker Compose with persistent volumes | Kubernetes or any platform without persistent storage for `/var/www/html` (e.g. an `emptyDir`), several replicas |
| `/var/www/html` | A persistent volume, shared by NGINX and PHP-FPM | Per pod (or container), recreated from the image on every start |
| WordPress, plugins, themes | Installed from the image on first boot, then managed in wp-admin: installs, updates and automatic updates work as usual | Only from the image: plugins and themes come from `composer.json`; no installs, file edits or automatic updates (`DISALLOW_FILE_MODS`, `AUTOMATIC_UPDATER_DISABLED`). Update by deploying a newer image |
| Media uploads | In the volume, or offloaded | **Must be offloaded to object storage**: the local copy is lost with the pod and not shared between replicas |

In stateful mode, `composer.json` only decides what a new site starts with: later changes to it, or a newer image, do not touch an existing volume. Keep WordPress, plugins and themes up to date from wp-admin.

### Required plugin: Nginx Cache

[Nginx Cache](https://wordpress.org/plugins/nginx-cache/) is bundled (via `composer.json`) and required in every environment: it purges the NGINX FastCGI cache when content changes. Activate it after installing WordPress; `NGINX_CACHE_PATH` is preconfigured. Without it, visitors keep getting cached pages until they expire (see [FastCGI cache](#fastcgi-cache)).

### Media offloading

Required in stateless mode, optional in stateful mode.

- **Azure Blob Storage**: [Microsoft Azure Storage for WordPress](https://wordpress.org/plugins/windows-azure-storage/) is bundled. Configure it in wp-admin or with environment variables, which become the plugin's constants: `MICROSOFT_AZURE_ACCOUNT_NAME`, `MICROSOFT_AZURE_ACCOUNT_KEY`, `MICROSOFT_AZURE_CONTAINER`, `MICROSOFT_AZURE_USE_FOR_DEFAULT_UPLOAD=1`, and any other `MICROSOFT_AZURE_*`. Append `_FILE` to read a value from a file, e.g. `MICROSOFT_AZURE_ACCOUNT_KEY_FILE=/run/secrets/azure-key`.
- **Amazon S3, Google Cloud Storage and others**: not bundled. Add an offloading plugin for your provider to `wordpress/composer.json` (from [WordPress Packagist](https://wpackagist.org/), e.g. `wpackagist-plugin/amazon-s3-and-cloudfront`), run `composer update` in `wordpress/` and build your own image. Configure it with its settings page or its constants through `WORDPRESS_CONFIG_EXTRA`.

## Configuration

`wp-config.php` is built from the [official WordPress image](https://hub.docker.com/_/wordpress)'s `wp-config-docker.php`, so the official variables work unchanged:

- `WORDPRESS_DB_HOST`, `WORDPRESS_DB_USER`, `WORDPRESS_DB_PASSWORD`, `WORDPRESS_DB_NAME`, `WORDPRESS_DB_CHARSET`, `WORDPRESS_DB_COLLATE`, `WORDPRESS_TABLE_PREFIX`
- `WORDPRESS_AUTH_KEY`, `WORDPRESS_SECURE_AUTH_KEY`, `WORDPRESS_LOGGED_IN_KEY`, `WORDPRESS_NONCE_KEY`, `WORDPRESS_AUTH_SALT`, `WORDPRESS_SECURE_AUTH_SALT`, `WORDPRESS_LOGGED_IN_SALT`, `WORDPRESS_NONCE_SALT`. Set them when running more than one replica; when unset, WordPress keeps generated salts in the database.
- `WORDPRESS_DEBUG` (any non-empty value enables `WP_DEBUG`) and `WORDPRESS_CONFIG_EXTRA` (PHP code evaluated in `wp-config.php`)
- Append `_FILE` to any of them to read the value from a file instead, e.g. `WORDPRESS_DB_PASSWORD_FILE=/run/secrets/db-password` for Docker or Kubernetes secrets.

This image adds, in `wp-config-extra.php`:

- `WORDPRESS_STATELESS`: `1` (or `true`) switches on [stateless mode](#environments).
- `MICROSOFT_AZURE_*` (and `*_FILE`) variables for [media offloading](#media-offloading).
- `NGINX_CACHE_PATH` for the Nginx Cache plugin.

On the NGINX container, `FASTCGI_CACHE_VALID` sets how long pages stay cached (see [FastCGI cache](#fastcgi-cache)).

The `WP_DB_*` and `WP_*_KEY`/`WP_*_SALT` names used by earlier versions of this image still work when the matching `WORDPRESS_*` variable is unset, but are deprecated.

## FastCGI cache

NGINX caches pages for anonymous visitors for `FASTCGI_CACHE_VALID` (default `1h`) and the Nginx Cache plugin purges the cache when content changes. Each NGINX instance keeps its own cache:

- With a single NGINX (e.g. Docker Compose), a purge clears the whole cache.
- With several (e.g. one per Kubernetes pod), a purge only clears the instance that handled the request; the others keep serving their cached pages until they expire. The Kubernetes example sets `FASTCGI_CACHE_VALID=5m` to bound that; lower it if changes must show up faster, or put a shared cache (e.g. a CDN) in front.

## Client IP addresses

Behind a reverse proxy, NGINX only sees the proxy's address. Tell it which proxies to trust, and it takes the client address from the header they send, for both its logs and WordPress (`REMOTE_ADDR`):

- `REAL_IP_FROM`: addresses or CIDRs of the proxies in front of NGINX, comma or space separated. Unset by default: then the direct peer is the client, and forwarded headers are ignored, since anyone could send them.
- `REAL_IP_HEADER`: the header carrying the client address (default `X-Forwarded-For`). With `X-Forwarded-For`, NGINX walks back past every trusted address to the first untrusted one, so chains of proxies work as long as all of them are listed.

Set them on the NGINX container. Common setups:

| In front of NGINX | `REAL_IP_FROM` | `REAL_IP_HEADER` |
|---|---|---|
| Nothing (port published directly) | unset | |
| NGINX Proxy Manager, Traefik, Caddy... on the same Docker host | the subnet of the Docker network they reach NGINX on (`docker network inspect`), e.g. `172.18.0.0/16` | default |
| Kubernetes ingress controller | the pod network CIDR (where the controller pods run), e.g. `10.244.0.0/16` | default |
| A CDN, e.g. Cloudflare | its published IP ranges, plus any proxy between it and NGINX | default, or the CDN's own header such as `CF-Connecting-IP` |

Only list addresses you control or trust: anything in `REAL_IP_FROM` can make NGINX and WordPress believe any client address.

## Testing

Every pull request runs the same checks you can run locally (only Docker is required):

```bash
# Lint Dockerfiles, shell scripts and workflows, and check composer.lock is in sync
tests/lint.sh

# Build both images, start the stack and test it end to end:
# env-based PHP/FPM/NGINX config, WordPress install, stateful and stateless modes,
# bundled plugins/theme/translations, FastCGI cache, client addresses from trusted
# proxies only, NGINX access rules and clean PHP/NGINX logs
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
