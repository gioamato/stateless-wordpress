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

# Spin it up with Docker Compose: MySQL, NGINX and 2 WordPress (PHP-FPM) replicas
docker compose up -d

# Open your browser and head to http://localhost:8080
# You will find the famous WordPress 5-minute install
```

Only the database is persisted. Configure media offloading (see [Data and persistence](#data-and-persistence)) before uploading anything you want to keep.

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

## Data and persistence

Following the official image's ["static image / updates-via-redeploy"](https://hub.docker.com/_/wordpress) model, the containers hold no data:

| What | Where | Persisted |
|---|---|---|
| WordPress core, plugins, themes, translations, `wp-config.php` | The image | Never: update by deploying a new image |
| Media uploads | Object storage, through the bundled offloading plugins | Yes, outside the containers |
| Content and settings | MySQL | Yes, outside the containers |
| FastCGI cache | Next to the code | No |

`/var/www/html` is shared between NGINX (static files) and PHP-FPM, and lives only as long as the containers: an in-memory volume in Docker Compose, an `emptyDir` in Kubernetes. On every start the WordPress container compares the code in the image with what the volume holds and, if they differ, wipes the volume and copies the code in again, so a new image always takes effect, even while NGINX keeps the volume mounted.

Media uploads must be offloaded, since the volume is wiped and is not shared between Kubernetes pods. Configure [WP-Stateless](https://wordpress.org/plugins/wp-stateless/) (Google Cloud Storage, e.g. `WP_STATELESS_MEDIA_MODE=stateless`) or [Microsoft Azure Storage for WordPress](https://wordpress.org/plugins/windows-azure-storage/) through environment variables (see [Configuration](#configuration)) or in wp-admin. Without it, uploads work until the next restart or update.

## Scaling

- Docker Compose runs one NGINX in front of `WORDPRESS_REPLICAS` PHP-FPM replicas (default 2), e.g. `WORDPRESS_REPLICAS=4 docker compose up -d`. NGINX re-resolves the `wordpress` service every 10 seconds and balances requests across the replicas, so it follows scaling and updates without a restart.
- Kubernetes scales whole pods (NGINX and PHP-FPM side by side): set `replicas` in `deploy/kubernetes/deploy.yaml`.

With more than one replica, set the `WORDPRESS_*_KEY`/`WORDPRESS_*_SALT` variables, or let WordPress keep its generated salts in the database (the default when they are unset); never let each replica generate its own.

## FastCGI cache

NGINX caches pages for anonymous visitors for `FASTCGI_CACHE_VALID` (default `1h`; set it on the NGINX container, e.g. `10m`). The bundled [Nginx Cache](https://wordpress.org/plugins/nginx-cache/) plugin purges it when content changes.

Each NGINX instance keeps its own cache:

- Docker Compose has a single NGINX, so a purge clears the whole cache.
- In Kubernetes every pod has its own NGINX and cache, and a purge only reaches the pod that handled the request: the other pods keep serving their cached pages until they expire. The example deployment sets `FASTCGI_CACHE_VALID=5m` to bound that; lower it if content must show up faster, or put a shared cache (e.g. a CDN) in front instead.

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
# env-based PHP/FPM/NGINX config, WordPress install, bundled plugins/theme/translations,
# replicas and load balancing, FastCGI cache, client addresses from trusted proxies only,
# NGINX access rules, a code update on the
# running stack and clean PHP/NGINX logs
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
