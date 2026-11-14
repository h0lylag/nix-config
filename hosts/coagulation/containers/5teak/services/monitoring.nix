{
  config,
  pkgs,
  lib,
  ...
}:

let
  prism-django = pkgs.local.prism-django;
  prismSource = prism-django.src;
  user = "prism-v1";
  host = "prism-v1.gravemind.sh";
  redisUnit = "redis-prism-v1.service";
  metricsRuntimeDirectory = "prism-django/prometheus";
  metricsRuntimePath = "/run/${metricsRuntimeDirectory}";
  postgresExporterPort = 9187;
  redisExporterPort = 9121;
  nodeExporterPort = 9100;
  metricsEnvironment = [
    "PROMETHEUS_MULTIPROC_DIR=${metricsRuntimePath}"
  ];
  # The v1 processes that write to the shared prometheus-client directory.
  metricsProducers = [
    "prism-django"
    "prism-celery-worker"
    "prism-celery-bulk"
    "prism-celery-beat"
  ];
  targetAvailabilityRules = (pkgs.formats.yaml { }).generate "prism-target-availability.rules.yml" {
    groups = [
      {
        name = "prism-monitoring-targets";
        rules = [
          {
            alert = "PrismMetricsTargetDown";
            expr = ''up{job=~"prism|postgres|redis|node"} == 0'';
            for = "2m";
            labels.severity = "critical";
            annotations = {
              summary = "{{ $labels.job }} metrics target is down";
              description = "Prometheus cannot scrape {{ $labels.instance }}.";
            };
          }
        ];
      }
    ];
  };
in
{
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    retentionTime = "30d";
    extraFlags = [ "--storage.tsdb.retention.size=10GB" ];
    ruleFiles = [
      "${prismSource}/observability/prometheus/prism.rules.yml"
      targetAvailabilityRules
    ];
    globalConfig = {
      scrape_interval = "15s";
      # Prism queue alerts use five-second thresholds, so evaluate them at the
      # same rate as the Prism scrape job.
      evaluation_interval = "5s";
    };
    exporters = {
      postgres = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = postgresExporterPort;
        runAsLocalSuperUser = true;
      };
      redis = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = redisExporterPort;
      };
      node = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = nodeExporterPort;
      };
    };
    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = [ "127.0.0.1:9090" ];
          }
        ];
      }
      {
        job_name = "prism";
        scrape_interval = "5s";
        static_configs = [
          {
            targets = [ "127.0.0.1:9108" ];
          }
        ];
      }
      {
        job_name = "postgres";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString postgresExporterPort}" ];
          }
        ];
      }
      {
        job_name = "redis";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString redisExporterPort}" ];
          }
        ];
      }
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString nodeExporterPort}" ];
          }
        ];
      }
    ];
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
        domain = host;
        root_url = "https://${host}/grafana/";
        serve_from_sub_path = true;
      };
      security = {
        admin_password = "$__file{/var/lib/grafana/admin-password}";
        cookie_secure = true;
        secret_key = "$__file{/var/lib/grafana/secret-key}";
      };
      users.allow_sign_up = false;
      "auth.anonymous".enabled = false;
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:9090";
          isDefault = true;
          editable = false;
        }
      ];
      dashboards.settings.providers = [
        {
          name = "Prism";
          orgId = 1;
          folder = "Prism";
          type = "file";
          disableDeletion = true;
          updateIntervalSeconds = 30;
          options.path = "${prismSource}/observability/grafana/dashboards";
        }
      ];
    };
  };

  # The edge proxy forwards this path to 5teak. Keep Grafana and Prometheus
  # bound to loopback so neither service bypasses Nginx or Grafana login.
  services.nginx.virtualHosts.${host}.locations = {
    "= /grafana".extraConfig = ''
      return 308 /grafana/;
    '';
    "/grafana/" = {
      proxyPass = "http://127.0.0.1:3000";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $prism_forwarded_proto;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Prefix /grafana;
      '';
    };
  };

  systemd.services =
    lib.genAttrs metricsProducers (_: {
      after = [ "prism-metrics-runtime.service" ];
      requires = [ "prism-metrics-runtime.service" ];
      partOf = [ "prism-metrics-runtime.service" ];
      serviceConfig = {
        Environment = metricsEnvironment;
        ReadWritePaths = [ metricsRuntimePath ];
      };
    })
    // {
      # One long-lived unit owns the shared prometheus-client directory. A Prism
      # package change restarts this unit, clears stale process files, and rolls
      # each metrics producer with it.
      prism-metrics-runtime = {
        description = "Prism shared Prometheus metrics directory";
        wantedBy = [ "multi-user.target" ];
        before = map (name: "${name}.service") (metricsProducers ++ [ "prism-metrics-exporter" ]);
        restartTriggers = [ prism-django ];
        serviceConfig = {
          Type = "oneshot";
          User = user;
          Group = user;
          RuntimeDirectory = metricsRuntimeDirectory;
          RuntimeDirectoryMode = "0750";
          ExecStart = "${pkgs.coreutils}/bin/true";
          RemainAfterExit = true;
        };
      };

      prism-metrics-exporter = {
        description = "Prism Prometheus metrics exporter";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "postgresql.service"
          redisUnit
          "prism-metrics-runtime.service"
          "prism-django.service"
        ];
        wants = [ "network-online.target" ];
        requires = [
          "postgresql.service"
          redisUnit
          "prism-metrics-runtime.service"
          "prism-django.service"
        ];
        partOf = [
          "prism-metrics-runtime.service"
          "prism-django.service"
        ];
        serviceConfig = {
          User = user;
          Group = user;
          Type = "simple";
          WorkingDirectory = "${prism-django}/share/prism-django";
          ExecStart = "${prism-django}/bin/prism-manage run_metrics_exporter --address 127.0.0.1 --port 9108";
          Environment = metricsEnvironment ++ [
            "DEBUG=false"
            "ALLOWED_HOSTS=localhost,127.0.0.1"
            "USE_POSTGRES=true"
            "POSTGRES_DB=prism_v1"
            "EVE_SDE_DB_NAME=eve-sde"
            "POSTGRES_HOST=localhost"
            "POSTGRES_PORT=5432"
            "REDIS_URL=unix://${config.services.redis.servers.prism-v1.unixSocket}?db=0"
            "REDIS_CACHE_URL=redis://127.0.0.1:6379/1"
            "REDIS_SESSION_URL=redis://127.0.0.1:6379/2"
            "CELERY_BROKER_URL=redis://127.0.0.1:6379/0"
          ];
          EnvironmentFile = config.sops.secrets.prism-env.path;
          Restart = "always";
          RestartSec = 10;

          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          LockPersonality = true;
          ProtectClock = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          RestrictSUIDSGID = true;
          RestrictRealtime = true;
          SystemCallArchitectures = "native";
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
          ReadWritePaths = [ metricsRuntimePath ];
        };
      };

      prometheus-postgres-exporter = {
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];
      };

      prometheus-redis-exporter = {
        after = [ redisUnit ];
        requires = [ redisUnit ];
      };

      nginx = {
        after = [ "grafana.service" ];
        wants = [ "grafana.service" ];
      };

      grafana = {
        after = [ "prometheus.service" ];
        wants = [ "prometheus.service" ];
        preStart = ''
          if [ ! -s /var/lib/grafana/admin-password ]; then
            umask 077
            ${pkgs.openssl}/bin/openssl rand -base64 -out /var/lib/grafana/admin-password 32
          fi
          if [ ! -s /var/lib/grafana/secret-key ]; then
            umask 077
            ${pkgs.openssl}/bin/openssl rand -hex -out /var/lib/grafana/secret-key 32
          fi
        '';
      };
    };
}
