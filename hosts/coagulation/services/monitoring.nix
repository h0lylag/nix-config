# Monitoring stack for coagulation
# Prometheus + Grafana with exporters for host and libvirt
{ config, pkgs, ... }:

{
  services.prometheus = {
    enable = true;
    port = 9090;

    exporters = {
      node = {
        enable = true;
        port = 9100;
        # enabledCollectors adds to defaults, not replaces
        enabledCollectors = [ "systemd" ];
      };

      libvirt = {
        enable = true;
        port = 9177;
      };
    };

    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.port}" ];
          }
        ];
      }
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
          }
        ];
      }
      {
        job_name = "libvirt";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.libvirt.port}" ];
          }
        ];
      }
      {
        job_name = "cadvisor";
        static_configs = [
          {
            targets = [ "127.0.0.1:8080" ];
          }
        ];
      }
    ];
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        domain = "localhost";
      };
      # Anonymous access for internal use (adjust if you want auth)
      "auth.anonymous" = {
        enabled = true;
        org_role = "Viewer";
      };
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.services.prometheus.port}";
          isDefault = true;
        }
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [
    3000 # Grafana
    9090 # Prometheus
  ];
}
