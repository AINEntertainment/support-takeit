FROM frappe/bench:latest

USER root

# Create the persistent directories (frappe-bench, logs, sites)
# This ensures the directories exist inside the image with correct ownership.
RUN mkdir -p /home/frappe/frappe-bench/logs \
    && mkdir -p /home/frappe/frappe-bench/sites \
    && chown -R frappe:frappe /home/frappe/frappe-bench

RUN mkdir -p /workspace
COPY init.sh /workspace/init.sh
RUN chmod +x /workspace/init.sh

USER frappe
