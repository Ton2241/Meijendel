FROM php:8.3-apache

RUN docker-php-ext-install pdo_mysql

COPY deploy/apache-vhost.conf /etc/apache2/sites-available/000-default.conf

WORKDIR /var/www/html

COPY . /var/www/html/
