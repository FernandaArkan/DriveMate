
FROM composer:2 AS composer_deps

WORKDIR /app

COPY api/composer.json api/composer.lock ./

RUN composer install \
    --no-dev \
    --prefer-dist \
    --no-interaction \
    --no-progress \
    --optimize-autoloader

FROM php:8.2-cli

RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq-dev \
    && docker-php-ext-install pdo_pgsql \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY api/ ./api/
COPY --from=composer_deps /app/vendor ./api/vendor

ENV PORT=8080
ENV PHP_CLI_SERVER_WORKERS=4

EXPOSE 8080

CMD ["sh", "-c", "php -S 0.0.0.0:${PORT} -t api api/router.php"]
