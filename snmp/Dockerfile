ARG ARCH="amd64"
ARG OS="linux"
FROM quay.io/prometheus/busybox-${OS}-${ARCH}:latest
LABEL maintainer="The Prometheus Authors <prometheus-developers@googlegroups.com>"
LABEL Software="snmp_exporter prometheus for mikrotik"
LABEL Author="IgorKha"

ARG ARCH="amd64"
ARG OS="linux"
COPY snmp_exporter  /bin/snmp_exporter
COPY snmp.yml       /etc/snmp_exporter/snmp.yml

EXPOSE      9116
ENTRYPOINT  [ "/bin/snmp_exporter" ]
CMD         [ "--config.file=/etc/snmp_exporter/snmp.yml" ]