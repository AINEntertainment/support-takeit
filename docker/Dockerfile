FROM frappe/bench:latest

USER root

RUN mkdir -p /workspace
COPY init.sh /workspace/init.sh
RUN chmod +x /workspace/init.sh
RUN chmod -R /home/frappe/frappe-bench/patches.txt
RUN chown -R /home/frappe/apps

USER frappe
