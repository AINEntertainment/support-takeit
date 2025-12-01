#!bin/bash

# --- VOLUME CHECK & INITIALIZATION LOGIC ---
# This checks if the persistent volume (mapped to $SITES_DIR) is mounted AND contains site data.
if [ -d "$SITES_DIR" ] && [ "$(ls -A $SITES_DIR)" ]; then
    echo "=================================================="
    echo "Existing Frappe Bench volume detected. Skipping full init."
    echo "=================================================="
    
    # Switch to the bench directory to prepare for serving
    cd $BENCH_DIR
    
    # Run any necessary updates/patches on existing data
    echo "Running bench update --patch..."
    bench update --patch
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