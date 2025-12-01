#!/bin/bash
BENCH_DIR="/home/frappe/frappe-bench"
FRAPPE_USER_UID=1000

# Fix 1: Ensure the frappe user owns the mounted volume directories
# This resolves the PermissionError on logs and sites files.
echo "Setting ownership of $BENCH_DIR to user $FRAPPE_USER_UID..."
sudo chown -R $FRAPPE_USER_UID:$FRAPPE_USER_UID $BENCH_DIR
echo "Ownership set."

# Use the 'sites' directory as the existence check, as it's created during a successful bench init.
if [ -d "$BENCH_DIR/sites" ]; then
    echo "Bench already exists, skipping initialization."
    cd $BENCH_DIR
    # Use 'exec' to replace the shell process with bench start
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