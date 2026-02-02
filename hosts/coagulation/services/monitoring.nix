# Monitoring stack for coagulation
# Prometheus + Grafana with exporters for host, libvirt, and podman
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
        job_name = "podman";
        static_configs = [
          {
            targets = [ "127.0.0.1:9882" ];
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

  # Podman Exporter Service
  # Note: For rootless podman, the socket is under the user's runtime dir.
  # This service connects to the rootless podman socket.
  systemd.services.prometheus-podman-exporter = {
    description = "Prometheus Podman Exporter";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      # Run as the podman user to access their rootless socket
      User = "podman";
      Group = "podman";
      ExecStart = "${pkgs.prometheus-podman-exporter}/bin/prometheus-podman-exporter --web.listen-address=:9882";
      Restart = "always";
      RestartSec = 10;
    };
    environment = {
      # Rootless podman socket location
      CONTAINER_HOST = "unix:///run/user/996/podman/podman.sock";
    };
  };

  networking.firewall.allowedTCPPorts = [
    3000 # Grafana
    9090 # Prometheus
  ];
}
