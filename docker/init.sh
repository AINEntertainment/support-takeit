#!/bin/bash
set -euo pipefail

# This part must be commented out as it belongs in the Dockerfile
# FROM frappe/bench:latest
# USER root
# RUN mkdir -p /workspace
# COPY init.sh /workspace/init.sh
# RUN chmod +x /workspace/init.sh
# USER frappe
# End of Dockerfile content

# This script is now ONLY for the initial setup.

if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "$(date) | Bench already exists, skipping init and starting server"
    cd frappe-bench
    # Only run migration/build if you need to update the existing bench
    # bench update --no-pull --no-backup
else
    echo "$(date) | Creating new bench..."

    bench init --skip-redis-config-generation frappe-bench --version version-15

    # --- FIX PERMISSION ERROR (Errno 13) ---
    # The frappe user inside the container (UID 1000) often loses write
    # permissions to files created in a volume mounted from the host.
    # We must explicitly set ownership to the frappe user for the newly created bench.
    # Note: 'sudo' is required here because 'frappe' user might not own the parent
    # directory of the mount, so only 'root' can change ownership.
    sudo chown -R frappe:frappe frappe-bench
    # ---------------------------------------

    cd frappe-bench

    # Use containers instead of localhost
    # These commands will now run successfully after the chown fix.
    bench set-mariadb-host mariadb
    bench set-redis-cache-host redis://redis:6379
    bench set-redis-queue-host redis://redis:6379
    bench set-redis-socketio-host redis://redis:6379

    # The original sed lines were commented out but causing execution issues, removing them.

    bench get-app telephony
    bench get-app helpdesk https://github.com/AINEntertainment/helpdesk-takeit.git --branch develop

    bench new-site helpdesk.localhost \
    --force \
    --mariadb-root-password 123 \
    --admin-password TLAO-GBTf1ylphFxC \
    --no-mariadb-socket

    bench --site helpdesk.localhost install-app telephony
    bench --site helpdesk.localhost install-app helpdesk
    bench --site helpdesk.localhost set-config developer_mode 1
    bench --site helpdesk.localhost set-config mute_emails 1
    bench --site helpdesk.localhost set-config server_script_enabled 1
    bench --site helpdesk.localhost clear-cache
    bench use helpdesk.localhost
    bench build # build asset 
    bench --site helpdesk.localhost clear-cache #remove cache after build
fi

# The key is to run 'bench serve' here to keep the container running
# This command runs for both new setup and existing setups
echo "$(date) | Starting bench server..."
exec bench serve --port 80