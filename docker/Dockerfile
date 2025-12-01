FROM frappe/bench:latest

USER root

RUN mkdir -p /workspace
COPY init.sh /workspace/init.sh
RUN chmod +x /workspace/init.sh


USER frappe
