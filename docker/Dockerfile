FROM amazonlinux:2023

LABEL maintainer="tsuricast"

ARG PHP_VERSION=8.3
ARG WWWUSER=1000

WORKDIR /var/www/html

ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# PHP 8.3 + PostgreSQL クライアント + nginx + 最小限のツール
# （machiiro-dev の構成から TsuriCast に不要な依存を除いたスリム版。
#   API 専用のため Node.js も入れない。クライアントは mobile/ の Expo 側）
RUN dnf update -y && \
    dnf install -y \
        git \
        unzip \
        tar \
        gzip \
        which \
        shadow-utils \
        nginx \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-common \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-pdo \
        php${PHP_VERSION}-pgsql \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-opcache \
        php${PHP_VERSION}-process \
        postgresql16 \
        python3 python3-pip \
    && dnf clean all

# supervisor は dnf に無いので pip から
RUN pip3 install supervisor

# Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# nginx 用ディレクトリ作成
RUN mkdir -p /var/log/nginx \
    && chown -R nginx:nginx /var/log/nginx \
    && mkdir -p /tmp/nginx/client_body /tmp/nginx/proxy /tmp/nginx/fastcgi /tmp/nginx/uwsgi /tmp/nginx/scgi \
    && chown -R nginx:nginx /tmp/nginx

# nginx と php-fpm 設定
COPY ./nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./nginx/laravel.conf /etc/nginx/conf.d/laravel.conf
COPY ./php/php-fpm.conf /etc/php-fpm.conf
COPY ./php/www.conf /etc/php-fpm.d/www.conf
COPY ./php/99-laravel.ini /etc/php.d/99-laravel.ini

# Supervisor 設定
COPY ./supervisord.conf /etc/supervisord.conf

# Laravel 用ユーザー
RUN useradd -ms /bin/bash -u $WWWUSER laravel && \
    chown -R laravel:laravel /var/www/html

# PHP-FPM ログディレクトリ
RUN mkdir -p /var/log/php-fpm \
    && chown -R laravel:laravel /var/log/php-fpm

EXPOSE 80

CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]
