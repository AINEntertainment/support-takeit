FROM frappe/bench:latest

USER root

RUN mkdir -p /workspace
COPY init.sh /workspace/init.sh
RUN chmod +x /workspace/init.sh

RUN chown -R frappe:frappe /home/frappe/apps/frappe
RUN chown -R /home/frappe/frappe-bench

USER frappe
