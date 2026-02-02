# Monitoring stack for coagulation
# Prometheus + Grafana with exporters for host, libvirt, and containers
{ config, pkgs, ... }:

{
  services.prometheus = {
    enable = true;
    port = 9090;

    exporters = {
      node = {
        enable = true;
        port = 9100;
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
      dashboards.settings.providers = [
        {
          name = "node";
          options.path = "/etc/grafana-dashboards/node";
        }
        {
          name = "cadvisor";
          options.path = "/etc/grafana-dashboards/cadvisor";
        }
      ];
    };
  };

  # Fetch community dashboards
  environment.etc = {
    "grafana-dashboards/node/node-exporter-full.json".source = pkgs.fetchurl {
      url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };

    "grafana-dashboards/cadvisor/cadvisor.json".source = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/google/cadvisor/master/deploy/kubernetes/base/grafana-dashboard.json";
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
  };

  networking.firewall.allowedTCPPorts = [
    3000 # Grafana
    9090 # Prometheus
  ];
}
