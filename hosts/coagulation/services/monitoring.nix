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
        job_name = "prometheus-libvirt-exporter";
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
  systemd.services.prometheus-libvirt-exporter.serviceConfig = {
    DynamicUser = lib.mkForce false;
    Environment = "HOME=/var/empty";
    # Allow Unix domain sockets for libvirt daemon communication
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
  };
}
