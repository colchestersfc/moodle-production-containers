#!/usr/bin/env bash

set -e

echo "***** Installing apt dependencies:"

# Build packages will be added during the build, but will be removed at the end.
BUILD_PACKAGES="gettext gnupg libcurl4-openssl-dev libfreetype6-dev libicu-dev libjpeg62-turbo-dev \
  libldap2-dev libmariadb-dev-compat libmariadb-dev libmemcached-dev libpng-dev libpq-dev libxml2-dev libxslt-dev \
  unixodbc-dev uuid-dev"

# Packages for Postgres.
PACKAGES_POSTGRES="libpq5"

# Packages for MariaDB and MySQL.
PACKAGES_MYMARIA="libmariadb3 mariadb-client"

# Packages for other Moodle runtime dependenices.
PACKAGES_RUNTIME="ghostscript libaio1 libcurl4 libgss3  libmcrypt-dev libxml2 libxslt1.1 \
  libzip-dev locales sassc unixodbc unzip zip git sudo"
  # libicu67

# Packages for Memcached.
PACKAGES_MEMCACHED="libmemcached11 libmemcachedutil2"

# Packages for LDAP.
PACKAGES_LDAP="libldap-2.4-2"

apt-get update
apt-get install -y --no-install-recommends apt-transport-https \
    $BUILD_PACKAGES \
    $PACKAGES_POSTGRES \
    $PACKAGES_MYMARIA \
    $PACKAGES_RUNTIME \
    $PACKAGES_MEMCACHED \
    $PACKAGES_LDAP

#Install libicu63 for debian10. 
# dpkg -i /tmp/libicu63_63.1-6+deb10u1_amd64.deb
# apt-get -f install



# Generate the locales configuration
#echo '***** Generating locales..'
#echo 'es_ES.UTF-8 UTF-8' > /etc/locale.gen
#locale-gen

echo "***** Installing php extensions"
# TODO: Revisar las extensiones que hacen falta para Moodle 4.x PHP Extensions and libraries https://docs.moodle.org/401/en/PHP
docker-php-ext-install -j$(nproc) \
    intl \
    mysqli \
    opcache \
    pgsql \
    soap \
    xsl \
    exif \
    xmlrpc \
    sockets # faster than tcp for communnication with nginx
    # https://php.watch/versions/8.0/xmlrpc PHP 8.0: XMLRPC extension is moved to PECL
    # xmlrpc \
    # INCLUDED XMLRPC FOR PHP7 and MOODLE 3.4

# GD.
echo "***** Installing GD"
docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/
docker-php-ext-install -j$(nproc) gd

# LDAP.
echo "***** Installing LDAP"
docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/
docker-php-ext-install -j$(nproc) ldap

# Memcached, MongoDB, Redis, APCu, igbinary.
# TODO: Por qué instarlar MongoDB si usamos mariaDB ?
echo "***** Installing Memcached, MongoDB, Redis, APCu, igbinary"
pecl install memcached  redis apcu igbinary uuid  #mongodb
docker-php-ext-enable memcached redis apcu igbinary uuid  #mongodb

# ZIP
echo "***** Installing ZIP"
# docker-php-ext-configure zip --with-libzip # https://stackoverflow.com/questions/65513366/docker-php-adding-zip-extension
docker-php-ext-install zip

echo 'apc.enable_cli = On' >> /usr/local/etc/php/conf.d/docker-php-ext-apcu.ini

# Keep our image size down..
echo "***** Keep our image size down"
pecl clear-cache
apt-get remove --purge -y $BUILD_PACKAGES
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "***** All php-extensions.sh actions done"