#!/bin/bash

# --- Safety Configuration ---
# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# The exit status of a pipeline is the exit status of the last command that failed.
set -euo pipefail

# Define the path to the bench directory
BENCH_PATH="/home/frappe/frappe-bench"

# --- Conditional Bench Initialization (Runs only once) ---
# Check if the bench already exists by looking for the frappe app directory.
if [ -d "${BENCH_PATH}/apps/frappe" ]; then
    echo "Bench already exists, skipping initial setup and moving to update/start phase."
    cd "${BENCH_PATH}"
else
    echo "Creating new bench and installing initial apps..."
    
    # 1. Initialize the new bench
    bench init --skip-redis-config-generation frappe-bench --version version-15
    cd "${BENCH_PATH}"
    
    # 2. Configure container services for Frappe/ERPNext
    bench set-mariadb-host mariadb
    bench set-redis-cache-host redis://redis:6379
    bench set-redis-queue-host redis://redis:6379
    bench set-redis-socketio-host redis://redis:6379

    # 3. Remove redis-server and watch processes from Procfile 
    # as they are handled by separate Docker containers (redis and the new bench start section).
    sed -i '/redis/d' ./Procfile
    sed -i '/watch/d' ./Procfile

    # 4. Get the required applications
    bench get-app telephony
    # Pull the helpdesk app from the specified GitHub repository and the 'develop' branch
    bench get-app helpdesk https://github.com/AINEntertainment/support-takeit.git --branch develop

    # 5. Create a new site
    bench new-site helpdesk.localhost \
    --force \
    --mariadb-root-password 123 \
    --admin-password admin \
    --no-mariadb-socket

    # 6. Install the apps on the new site and set developer configs
    bench --site helpdesk.localhost install-app telephony
    bench --site helpdesk.localhost install-app helpdesk
    bench --site helpdesk.localhost set-config developer_mode 1
    bench --site helpdesk.localhost set-config mute_emails 1
    bench --site helpdesk.localhost set-config server_script_enabled 1
    bench --site helpdesk.localhost clear-cache
    
    # 7. Set the site as the default site
    bench use helpdesk.localhost
fi

# --------------------------------------------------------------------------
# --- Update and Start Phase (Runs every time to get latest code) ---
# This section ensures that the latest code from the 'develop' branch is pulled 
# and assets are rebuilt on every container start, resolving the issue of changes not appearing.

echo "Pulling latest changes, migrating database, and building assets..."

# Navigate to the bench directory if not already there (safety check)
if [ ! -d "${BENCH_PATH}" ]; then
    echo "Error: Bench directory not found after setup attempt. Exiting."
    exit 1
fi
cd "${BENCH_PATH}"

# 1. PULL LATEST CODE AND FORCE RESET: 
# This command pulls the latest changes for all apps and uses --reset to discard any 
# uncommitted local changes, forcing the Git update to succeed. This ensures you 
# get the latest code from your 'develop' branch.
bench update --pull --reset

# 2. Apply any database migrations after code pull
bench migrate

# 3. Rebuild frontend assets (JS/CSS) to reflect code changes
bench build

# 4. Start the bench services
echo "Starting bench with latest code..."
bench start