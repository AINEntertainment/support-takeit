#!/bin/bash
BENCH_DIR="/home/frappe/frappe-bench"
FRAPPE_USER_UID=1000

# =======================================================
# STEP 1: FIX PERMISSIONS (Resolves PermissionError: [Errno 13])
# =======================================================
# Ensure the frappe user owns the mounted volume directories before proceeding.
echo "Setting correct ownership for mounted volumes to frappe:frappe..."
sudo chown -R $FRAPPE_USER_UID:$FRAPPE_USER_UID $BENCH_DIR
echo "Ownership set. Starting checks."

# =======================================================
# STEP 2: CHECK FOR EXISTING BENCH AND EXECUTE FLOW
# =======================================================

# Use the 'sites' directory as the existence check
if [ -d "$BENCH_DIR/sites" ]; then
    echo "Bench already exists, skipping initialization."
    
    # CRITICAL: Change directory before running bench commands
    cd $BENCH_DIR
    
    # Final step: Start the bench
    exec bench start
else
    echo "Creating new bench..."
fi

bench init --skip-redis-config-generation frappe-bench --version version-15

cd frappe-bench

# Use containers instead of localhost
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

# Remove redis, watch from Procfile
sed -i '/redis/d' ./Procfile
sed -i '/watch/d' ./Procfile

bench get-app telephony
bench get-app helpdesk https://github.com/AINEntertainment/support-takeit.git --branch develop

bench update --patch

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
    bench build # build asset 
    bench --site helpdesk.localhost clear-cache #remove cache after build

bench serve --port 80