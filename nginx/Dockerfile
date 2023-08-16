FROM nginx:1.25.2-alpine

# Install bash to use 'wait-for-it' and entrypoint
RUN apk update && apk add bash && apk add --no-cache coreutils

# Add 'www-data' user
RUN adduser -u 82 -D -S -G www-data www-data

# Add custom configuration
COPY config /etc/nginx

# Add 'wait-for-it' to check upstream availability
COPY wait-for-it.sh /usr/local/bin/wait-for-it
RUN chmod +x /usr/local/bin/wait-for-it

# Add entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
CMD ["nginx", "-g", "daemon off;"]
