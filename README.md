# Stateless Wordpress

[![WordPress](https://github.com/gioamato/stateless-wordpress/actions/workflows/wordpress.yml/badge.svg)](https://github.com/gioamato/stateless-wordpress/actions/workflows/wordpress.yml)
[![NGINX](https://github.com/gioamato/stateless-wordpress/actions/workflows/nginx.yml/badge.svg)](https://github.com/gioamato/stateless-wordpress/actions/workflows/nginx.yml)
[![GitHub](https://img.shields.io/github/license/gioamato/stateless-wordpress)](https://github.com/gioamato/stateless-wordpress/blob/master/LICENSE)
[![Docker Pulls](https://img.shields.io/docker/pulls/gioamato/stateless-wordpress)](https://hub.docker.com/r/gioamato/stateless-wordpress/tags)

Minimal, cloud-native, battle-tested WordPress environment meant to be used both in local development and staging/production.

## Usage
### Local Development Environment

```bash
# Clone the repo
git clone https://github.com/gioamato/stateless-wordpress.git
cd stateless-wordpress

# Spin it up with Docker Compose
docker compose up -d

# Open your browser and head to http://localhost:8000
# You will find the famous WordPress 5-minute install
```

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[MIT](https://choosealicense.com/licenses/mit/)
