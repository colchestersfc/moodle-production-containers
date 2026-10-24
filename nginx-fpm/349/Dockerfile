FROM almalinux/8-base

LABEL maintainer="shearingc <shearingc@colchsfc.ac.uk>"

ARG VERSION=3.4.9
ARG COMPOSER_VERSION=1.10.6
ENV DOCKERIZE_VERSION=v0.7.0

VOLUME ["/var/moodledata"]
EXPOSE 80

RUN dnf -y update && \
    dnf -y install epel-release && \
    dnf -y module enable php:7.2

RUN echo "===== REPOS =====" && \
    dnf repolist

RUN echo "===== PHP MODULES =====" && \
    dnf module list php

RUN echo "===== PHP PACKAGES =====" && \
    dnf list available 'php*' | grep -Ei 'redis|memcached|igbinary|apcu|xmlrpc' || true

RUN echo "===== MEMCACHED =====" && \
    dnf search memcached || true

RUN echo "===== REDIS =====" && \
    dnf search redis || true

RUN echo "===== IGBINARY =====" && \
    dnf search igbinary || true

RUN echo "===== UNOCONV =====" && \
    dnf search unoconv || true

RUN dnf -y update && \
    dnf -y install epel-release && \
    dnf -y module enable php:7.2 && \
    dnf -y install \
        shadow-utils \
        php \
        php-cli \
        php-fpm \
        php-common \
        php-devel \
        php-pear \
        php-gd \
        php-intl \
        php-ldap \
        php-mbstring \
        php-mysqlnd \
        php-opcache \
        php-soap \
        php-process \
        php-xml \
        php-xmlrpc \
        php-xsl \
        php-zip \
        php-pecl-apcu \
        gcc \
        gcc-c++ \
        make \
        libmemcached-awesome-devel \
        cyrus-sasl-devel \
        zlib-devel \
        openssl-devel \
        mariadb \
        mariadb-connector-c \
        openldap \
        openldap-clients \
        libxslt \
        curl \
        wget \
        unzip \
        zip \
        tar \
        git \
        sudo \
        ghostscript \
        expect \
        unoconv \
        libreoffice \
        which && \
    dnf clean all

#
# PECL extensions previously installed by php-extensions.sh
#
RUN printf "\n" | pecl install igbinary
RUN printf "\n" | pecl install redis
RUN printf "\n" | pecl install memcached

RUN echo "extension=igbinary.so" > /etc/php.d/40-igbinary.ini && \
    echo "extension=redis.so" > /etc/php.d/40-redis.ini && \
    echo "extension=memcached.so" > /etc/php.d/40-memcached.ini && \
    echo "apc.enable_cli=1" > /etc/php.d/99-apcu.ini

#
# Create Debian-compatible www-data account
#
RUN groupadd -g 33 www-data || true && \
    useradd -u 33 -g 33 -r -s /sbin/nologin www-data || true

#
# OPCACHE
#
RUN { \
    echo 'opcache.memory_consumption=1024'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.revalidate_freq=60'; \
    echo 'opcache.enable_cli=1'; \
    echo 'opcache.use_cwd=1'; \
    echo 'opcache.validate_timestamps=1'; \
    echo 'opcache.save_comments=1'; \
    echo 'opcache.enable_file_override=0'; \
    } > /etc/php.d/99-opcache.ini

#
# Moodle PHP settings
#
RUN { \
    echo 'file_uploads=On'; \
    echo 'memory_limit=512M'; \
    echo 'upload_max_filesize=64M'; \
    echo 'post_max_size=64M'; \
    echo 'max_execution_time=600'; \
    } > /etc/php.d/99-moodle.ini

#
# Moodle
#
RUN curl -o moodle.tgz -fSL "https://download.moodle.org/download.php/direct/stable34/moodle-${VERSION}.tgz" && \
    mkdir -p /usr/src/moodle && \
    tar -xf moodle.tgz -C /usr/src/moodle --strip-components=1 && \
    rm -f moodle.tgz

#
# Composer
#
RUN curl -o composer.phar -fSL "https://github.com/composer/composer/releases/download/${COMPOSER_VERSION}/composer.phar" && \
    chmod +x composer.phar && \
    mv composer.phar /usr/local/bin/composer

#
# Moosh
#
RUN cd /usr/src && \
    curl -o moosh.zip -fSL "https://moodle.org/plugins/download.php/23758/moosh_moodle38_2021032400.zip" && \
    unzip moosh.zip && \
    cd moosh && \
    composer install && \
    ln -s /usr/src/moosh/moosh.php /usr/local/bin/moosh && \
    rm -f /usr/src/moosh.zip

#
# Unoconv
#
RUN mkdir -p /var/www/.config && \
    chown -R www-data:www-data /var/www/.config

#
# Dockerize
#
RUN curl -o dockerize.tar.gz -fSL "https://github.com/jwilder/dockerize/releases/download/${DOCKERIZE_VERSION}/dockerize-linux-amd64-${DOCKERIZE_VERSION}.tar.gz" && \
    tar -xf dockerize.tar.gz -C /usr/local/bin && \
    rm -f dockerize.tar.gz

COPY moodle-config.php /usr/src/moodle/config.php

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

COPY ldap.conf /etc/openldap/ldap.conf

RUN chmod 777 /tmp && \
    chmod +t /tmp && \
    mkdir -p /var/www && \
    chown -R www-data:www-data /usr/src/moodle && \
    chown www-data:www-data /var/www

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["php-fpm", "-F"]
