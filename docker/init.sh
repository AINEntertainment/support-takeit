#!/bin/bash
set -euo pipefail

# Define variables for clarity and future environment variable usage
SITE_NAME="helpdesk.localhost"
BENCH_PATH="/home/frappe/frappe-bench"

# --- LOGIC: Check if the bench already exists ---
if [ -d "${BENCH_PATH}/apps/frappe" ]; then
    echo "Bench already exists, skipping initialization."
    
    # --- UPDATE BLOCK: Runs on subsequent restarts to pull latest code ---
    echo "Running bench update to fetch latest changes and apply patches..."
    
    # Must navigate inside the bench folder before running update
    cd frappe-bench
    
    # The 'bench update --patch' command handles git pull, database migrations, 
    # and asset building for all installed apps.
    bench update --patch
    
else
    # --- INITIAL SETUP BLOCK: Only runs on first boot ---
    echo "Creating new bench..."

    # 1. Create the directory (Docker volume mount handles persistence here) and enter it
    mkdir -p frappe-bench
    cd frappe-bench

    # CRITICAL FIX: If the persistent volume exists but is only partially initialized, 
    # the subsequent 'bench init .' fails. We check for a common missing file 
    # (sites/common_site_config.json) and wipe the directory if it's missing, forcing a clean init.
    if [ ! -f "./sites/common_site_config.json" ] && [ "$(ls -A .)" ]; then
        echo "WARN: Persistent bench directory is incomplete or corrupt. Cleaning contents..."
        # Note: 'rm -rf .' is generally dangerous but safe here because we are in a 
        # containerized path mapped to a named volume.
        rm -rf ./* ./.git* ./.bench*
        rm -rf ./.* 2>/dev/null || true # Clean up dot files/folders, ignoring errors
    fi

    # 2. Run bench init WITHOUT the directory name to initialize the current directory ('.')
    bench init --skip-redis-config-generation . --version version-15

    # Configure hosts for container services
    bench set-mariadb-host mariadb
    bench set-redis-cache-host redis://redis:6379
    bench set-redis-queue-host redis://redis:6379
    bench set-redis-socketio-host redis://redis:6379

    # Remove bench start components (redis, watch) since we use bench serve
    sed -i '/redis/d' ./Procfile
    sed -i '/watch/d' ./Procfile

    # Get applications (Note: Using the corrected source for helpdesk)
    bench get-app telephony
    bench get-app helpdesk https://github.com/AINEntertainment/support-takeit.git --branch develop

    # Create the new site
    bench new-site ${SITE_NAME} \
    --force \
    --mariadb-root-password 123 \
    --admin-password admin \
    --no-mariadb-socket

    # Install apps onto the newly created site
    bench --site ${SITE_NAME} install-app telephony
    bench --site ${SITE_NAME} install-app helpdesk

    # Set site configurations
    bench --site ${SITE_NAME} set-config developer_mode 1
    bench --site ${SITE_NAME} set-config mute_emails 1
    bench --site ${SITE_NAME} set-config server_script_enabled 1
    
    # Use the site and build assets
    bench use ${SITE_NAME}
    bench build # build assets (JS/CSS)
    bench --site ${SITE_NAME} clear-cache # Clear cache after build is critical
fi

# --- APPLICATION START: Runs every time, regardless of whether init was run ---

# 1. Start the Socket.IO server in the background (required for real-time updates)
bench start --only socketio & 

# 2. Run Gunicorn (bench serve) in the foreground, keeping the container alive.
bench serve --port 80