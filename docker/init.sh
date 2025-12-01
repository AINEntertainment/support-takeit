#!/bin/bash

# NOTE: The parent directory is now /home/frappe/frappe-bench 
# due to the volume mount in docker-compose.yml.

if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "Bench already exists, skipping init"
    # This ensures that if the container restarts, it skips the setup phase.
else
    echo "Creating new bench..."

    # The bench is created directly in the current working directory (frappe-bench)
    bench init --skip-redis-config-generation . --version version-15

    # No need to 'cd frappe-bench' here because the mount point is the bench itself.

    # Use containers instead of localhost
    bench set-mariadb-host mariadb
    bench set-redis-cache-host redis://redis:6379
    bench set-redis-queue-host redis://redis:6379
    bench set-redis-socketio-host redis://redis:6379

    # Remove redis, watch from Procfile (These services are external via docker-compose)
    sed -i '/redis/d' ./Procfile
    sed -i '/watch/d' ./Procfile

    bench get-app telephony
    bench get-app helpdesk --branch main

    bench new-site helpdesk.localhost \
    --force \
    --mariadb-root-password 123 \
    --admin-password admin \
    --no-mariadb-socket

    bench --site helpdesk.localhost install-app telephony
    bench --site helpdesk.localhost install-app helpdesk
    bench --site helpdesk.localhost set-config developer_mode 1
    bench --site helpdesk.localhost set-config mute_emails 1
    bench --site helpdesk.localhost set-config server_script_enabled 1
    bench --site helpdesk.localhost clear-cache
    bench use helpdesk.localhost
fi

# The crucial change: bench serve is REMOVED.
# The script exits, and the `docker-compose.yml` command runs `bench start`.