#!/bin/bash
BENCH_DIR="/home/frappe/frappe-bench"
FRAPPE_USER_UID=1000

# CRITICAL: Always start in the working directory defined in docker-compose.yml
cd /home/frappe

# =======================================================
# STEP 1: FIX PERMISSIONS (Resolves PermissionError)
# =======================================================
echo "Setting correct ownership for mounted volumes to frappe:frappe..."
# This must run outside the container to fix host-created volume permissions
sudo chown -R $FRAPPE_USER_UID:$FRAPPE_USER_UID $BENCH_DIR
echo "Ownership set. Starting checks."

# =======================================================
# STEP 2: CHECK FOR EXISTING BENCH AND EXECUTE FLOW
# =======================================================

# Check for a fully initialized bench (sites folder is the key indicator)
if [ -d "$BENCH_DIR/sites" ]; then
    echo "Bench already exists, skipping initialization."
    
    # Change directory to the bench folder
    cd frappe-bench
    
    # Final step: Start the bench
    exec bench start
else
    # New Bench/Initialization Case
    echo "Creating new bench..."

    # 1. Initialize the bench. This must run from the parent directory (/home/frappe)
    # This will create the frappe-bench folder structure.
    bench init --skip-redis-config-generation frappe-bench --version version-15

    # CRITICAL: Change directory into the newly created bench folder
    cd frappe-bench
    
    # 2. Configuration (These now run safely from inside frappe-bench)
    bench set-mariadb-host mariadb
    bench set-redis-cache-host redis://redis:6379
    bench set-redis-queue-host redis://redis:6379
    bench set-redis-socketio-host redis://redis:6379

    # Remove redis, watch from Procfile
    sed -i '/redis/d' ./Procfile
    sed -i '/watch/d' ./Procfile

    # 3. App Installation and Site Creation
    bench get-app telephony
    bench get-app helpdesk https://github.com/AINEntertainment/support-takeit.git --branch develop
    bench update --patch

    bench new-site helpdesk.localhost \
        --force \
        --mariadb-root-password 123 \
        --admin-password admin \
        --no-mariadb-socket

    # 4. Site Setup
    bench --site helpdesk.localhost install-app telephony
    bench --site helpdesk.localhost install-app helpdesk
    bench --site helpdesk.localhost set-config developer_mode 1
    bench --site helpdesk.localhost set-config mute_emails 1
    bench --site helpdesk.localhost set-config server_script_enabled 1
    bench --site helpdesk.localhost clear-cache
    bench use helpdesk.localhost
    bench build # build asset 

    # Final step: Start the bench
    exec bench start
fi