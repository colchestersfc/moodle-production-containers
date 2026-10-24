#!/usr/bin/env bash

set -euo pipefail

MOODLE_DATA="/var/www/moodledata"
MOODLE_DATA_REPOSITORY="/var/www/moodledata/repository"
MOODLE_DATA_BACKUPS="/var/www/moodledata/repository/backups"

#
# Process initialization files
#
process_init_files() {
    echo

    local f
    for f; do
        [ -e "$f" ] || continue

        case "$f" in
            *.sh)
                if [ -x "$f" ]; then
                    echo >&2 "$f executing..."
                    sudo -H -E -u www-data "$f"
                    chmod -x "$f"
                    echo >&2 "$f executed!"
                else
                    echo >&2 "$f skipped, no execute permission"
                fi
                ;;
            *.php)
                echo >&2 "$f executing..."
                php "$f"
                echo >&2 "$f executed!"
                ;;
        esac

        echo
    done
}

#
# Run Moodle setup only when starting php-fpm
#
if [[ "$1" == "php-fpm" ]]; then

    #
    # Determine runtime user/group
    #
    if [ "$(id -u)" = "0" ]; then
        user="www-data"
        group="www-data"
    else
        user="$(id -u)"
        group="$(id -g)"
    fi

    #
    # Generate DB password if missing
    #
    if [[ ! -v MOODLE_MYSQL_PASSWORD ]]; then
        export MOODLE_MYSQL_PASSWORD="$(
            tr -dc "a-zA-Z0-9!@#$%^&*()_+?<>~\`;" < /dev/urandom |
            fold -w 16 |
            head -n 1
        )"
    fi

    #
    # Deploy Moodle code if volume is empty
    #
    if [ ! -f config.php ]; then

        echo >&2 "Moodle not found in $PWD - copying now..."

        if [ -n "$(ls -A . 2>/dev/null)" ]; then
            echo >&2 "WARNING: $PWD is not empty! (copying anyhow)"
        fi

        sourceTarArgs=(
            --create
            --file -
            --directory /usr/src/moodle
            --owner "$user"
            --group "$group"
        )

        targetTarArgs=(
            --extract
            --file -
        )

        if [ "$user" != "0" ]; then
            targetTarArgs+=(--no-overwrite-dir)
        fi

        tar "${sourceTarArgs[@]}" . | tar "${targetTarArgs[@]}"

        chown -R "$user:$group" /var/www/html

        echo >&2 "MOODLE CODE CREATED"

    else
        echo >&2 "MOODLE CODE FOUND: SKIP CREATION"
    fi

    #
    # Wait for database
    #
    echo >&2 "Checking database status..."

    dockerize -wait "tcp://${MOODLE_DB_HOST}:3306" -timeout 50s

    #
    # Check Moodle database
    #
    set +e

    php /var/www/html/admin/cli/check_database_schema.php
    dbStatus=$?

    set -e

    if [ "$dbStatus" -eq 2 ]; then

        echo >&2 "Creating database..."

        php "$PWD/admin/cli/install_database.php" \
            --lang="${MOODLE_LANG}" \
            --adminuser="${MOODLE_ADMIN_USER}" \
            --adminpass="${MOODLE_ADMIN_PASSWORD}" \
            --adminemail="${MOODLE_ADMIN_EMAIL}" \
            --agree-license \
            --fullname="${MOODLE_SITE_FULLNAME}" \
            --shortname="${MOODLE_SITE_NAME}"

        echo >&2 "DATABASE CREATED"

    elif [ "$dbStatus" -eq 0 ]; then

        echo >&2 "MOODLE DATABASE FOUND: SKIP CREATION"

    else

        echo >&2 "ERRORS WITH MOODLE DATABASE!"

    fi

    #
    # Moodle data directory
    #
    if [ ! -d "$MOODLE_DATA" ]; then

        mkdir -p "$MOODLE_DATA"
        mkdir -p "$MOODLE_DATA_REPOSITORY"
        mkdir -p "$MOODLE_DATA_BACKUPS"

        chown -R "$user:$group" "$MOODLE_DATA"

        echo >&2 "MOODLE DATA DIRECTORY CREATED"

    else

        echo >&2 "MOODLE DATA DIRECTORY FOUND: SKIP CREATION"

        if [ "$(id -u)" = "0" ] && [ "$(stat -c '%u:%g' "$MOODLE_DATA")" = "0:0" ]; then
            echo >&2 "Changed permissions to Moodle Data directory"
            chown -R "$user:$group" "$MOODLE_DATA"
        fi
    fi

    #
    # Custom init scripts
    #
    process_init_files /init-scripts/*

fi

exec "$@"
