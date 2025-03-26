# Stateless WordPress

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
