# This Dockerfile builds the main stochastix image.
# It contains the PHP environment and the pre-built UI, but NO Symfony source code.

# Stage 1: Fetch the latest UI release assets
FROM alpine:latest AS ui-fetcher

ARG UI_REPO="phpquant/stochastix-ui"
ARG UI_VERSION="latest"

WORKDIR /downloads

RUN apk add --no-cache curl jq

# Use the GitHub API to get the download URL for the .tar.gz asset
RUN ASSET_URL=$(curl -sL https://api.github.com/repos/${UI_REPO}/releases/${UI_VERSION} | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url') && \
    if [ -z "$ASSET_URL" ] || [ "$ASSET_URL" = "null" ]; then echo "Error: Could not find UI release asset." >&2; exit 1; fi && \
    curl -L -o stochastix-ui.tar.gz "${ASSET_URL}" && \
    mkdir -p /ui_assets && \
    tar -xzf stochastix-ui.tar.gz -C /ui_assets

# Stage 2: Prepare the final application environment image
# Versions
FROM dunglas/frankenphp:1-php8.4 AS frankenphp_upstream

# The different stages of this Dockerfile are meant to be built into separate images
# https://docs.docker.com/develop/develop-images/multistage-build/#stop-at-a-specific-build-stage
# https://docs.docker.com/compose/compose-file/#target


# Base FrankenPHP image
FROM frankenphp_upstream AS frankenphp_base

WORKDIR /app

VOLUME /app/var/

# persistent / runtime deps
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
  libgmp-dev \
	acl \
	file \
	gettext \
	git \
	&& rm -rf /var/lib/apt/lists/*

RUN set -eux; \
	install-php-extensions \
		@composer \
		apcu \
		intl \
		opcache \
		zip \
    bcmath \
    gmp \
    pdo \
    pdo_sqlite \
  ; \
  pecl install \
    trader \
    ds \
  ; \
  docker-php-ext-enable \
    bcmath \
    gmp \
    trader \
    ds \
  ;

RUN git config --global --add safe.directory /app

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1

# Transport to use by Mercure (default to Bolt)
ENV MERCURE_TRANSPORT_URL=bolt:///data/mercure.db

ENV PHP_INI_SCAN_DIR=":$PHP_INI_DIR/app.conf.d"

COPY --link templates/frankenphp/conf.d/10-app.ini $PHP_INI_DIR/app.conf.d/
COPY --link --chmod=755 templates/frankenphp/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY --link templates/frankenphp/Caddyfile /etc/caddy/Caddyfile

COPY --from=ui-fetcher /ui_assets/ /srv/ui/
RUN chown -R www-data:www-data /srv/ui

ENTRYPOINT ["docker-entrypoint"]

HEALTHCHECK --start-period=60s CMD curl -f http://localhost:2019/metrics || exit 1
CMD [ "frankenphp", "run", "--config", "/etc/caddy/Caddyfile" ]

# Dev FrankenPHP image
FROM frankenphp_base AS frankenphp_dev

ENV APP_ENV=dev
ENV XDEBUG_MODE=off
ENV FRANKENPHP_WORKER_CONFIG=watch

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

RUN set -eux; \
	install-php-extensions \
		xdebug \
	;

COPY --link templates/frankenphp/conf.d/20-app.dev.ini $PHP_INI_DIR/app.conf.d/

CMD [ "frankenphp", "run", "--config", "/etc/caddy/Caddyfile", "--watch" ]

# Prod FrankenPHP image
FROM frankenphp_base AS frankenphp_prod

ENV APP_ENV=prod

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY --link templates/frankenphp/conf.d/20-app.prod.ini $PHP_INI_DIR/app.conf.d/

# prevent the reinstallation of vendors at every changes in the source code
COPY --link composer.* symfony.* ./
RUN set -eux; \
	composer install --no-cache --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress

# copy sources
COPY --link . ./
RUN rm -Rf frankenphp/

RUN set -eux; \
	mkdir -p var/cache var/log; \
	composer dump-autoload --classmap-authoritative --no-dev; \
	composer dump-env prod; \
	composer run-script --no-dev post-install-cmd; \
	chmod +x bin/console; sync;
