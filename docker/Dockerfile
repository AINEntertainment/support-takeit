FROM frappe/bench:latest

USER root

RUN mkdir -p /workspace
COPY init.sh /workspace/init.sh
RUN chmod +x /workspace/init.sh
RUN chown -R /home/frappe/frappe-bench/apps/frappe
RUN chmod +x frappe:frappe /home/frappe/frappe-bench/patches.txt


USER frappe
