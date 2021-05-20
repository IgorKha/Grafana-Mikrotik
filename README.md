# Grafana-Mikrotik
![visitors](https://visitor-badge.laobi.icu/badge?page_id=IgorKha.Grafana-Mikrotik)

Grafana dashboard for Mikrotik/routerOS. [prometheus/snmp_exporter](https://github.com/prometheus/snmp_exporter)

1. add into prometheus.yml
```yml
  - job_name: Mikrotik
    static_configs:
      - targets:
        - 0.0.0.0  # SNMP device IP.
    metrics_path: /snmp
    params:
      module: [mikrotik]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:9116  # The SNMP exporter's real hostname:port.
```
2. Configure Prometheus and run /snmp/snmp_exporter
3. Add dashboard https://grafana.com/grafana/dashboards/14420

![img1](https://github.com/IgorKha/Grafana-Mikrotik/blob/master/readme/1.png)
![img2](https://github.com/IgorKha/Grafana-Mikrotik/blob/master/readme/2.png)
![img3](https://github.com/IgorKha/Grafana-Mikrotik/blob/master/readme/3.png)