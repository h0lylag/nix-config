# Monitoring stack for coagulation
# Prometheus + Grafana with exporters for host, libvirt, and containers
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Fix prometheus-libvirt-exporter binary name (nixpkgs bug)
  nixpkgs.overlays = [
    (final: prev: {
      prometheus-libvirt-exporter = prev.prometheus-libvirt-exporter.overrideAttrs (old: {
        meta = old.meta // {
          mainProgram = "libvirt-exporter";
        };
      });
    })
  ];

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
        user = "prometheus-libvirt-exporter";
        group = "libvirtd";
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

  # Fetch community dashboards from grafana.com
  environment.etc = {
    # Node Exporter Full - https://grafana.com/grafana/dashboards/1860
    "grafana-dashboards/node/node-exporter-full.json".source = pkgs.fetchurl {
      url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
      sha256 = "sha256-1DE1aaanRHHeCOMWDGdOS1wBXxOF84UXAjJzT5Ek6mM=";
    };

    # cAdvisor Exporter - https://grafana.com/grafana/dashboards/14282
    "grafana-dashboards/cadvisor/cadvisor.json".source = pkgs.fetchurl {
      url = "https://grafana.com/api/dashboards/14282/revisions/1/download";
      sha256 = "sha256-dqhaC4r4rXHCJpASt5y3EZXW00g5fhkQM+MgNcgX1c0=";
    };
  };

  networking.firewall.allowedTCPPorts = [
    3000 # Grafana
    9090 # Prometheus
  ];

  # Create static user for libvirt exporter
  users.users.prometheus-libvirt-exporter = {
    isSystemUser = true;
    group = "prometheus-libvirt-exporter";
    extraGroups = [ "libvirtd" ];
  };
  users.groups.prometheus-libvirt-exporter = { };

  # Explicitly disable DynamicUser (workaround for libvirt socket access)
  systemd.services.prometheus-libvirt-exporter.serviceConfig.DynamicUser = lib.mkForce false;
}
