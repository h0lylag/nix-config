{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.services.qbt;

  # Helper function to format configuration values (from blog post)
  formatValue =
    value:
    if isBool value then
      (if value then "true" else "false")
    else if isList value then
      concatStringsSep ", " (map toString value)
    else
      toString value;

  # Generate configuration file (following blog post approach)
  generateConfig =
    instanceCfg:
    let
      # Build configuration sections
      sections = filterAttrs (_: v: v != { }) {
        AutoRun = filterAttrs (_: v: v != null) {
          "enabled" = instanceCfg.autoRun.enabled;
          "program" = instanceCfg.autoRun.program;
        };

        BitTorrent = filterAttrs (_: v: v != null) {
          "Session\\AlternativeGlobalDLSpeedLimit" = instanceCfg.bittorrent.alternativeGlobalDLSpeedLimit;
          "Session\\AlternativeGlobalUPSpeedLimit" = instanceCfg.bittorrent.alternativeGlobalUPSpeedLimit;
          "Session\\DHTEnabled" = instanceCfg.bittorrent.dhtEnabled;
          "Session\\DefaultSavePath" = instanceCfg.bittorrent.defaultSavePath;
          "Session\\LSDEnabled" = instanceCfg.bittorrent.lsdEnabled;
          "Session\\MaxUploads" = instanceCfg.bittorrent.maxUploads;
          "Session\\MaxUploadsPerTorrent" = instanceCfg.bittorrent.maxUploadsPerTorrent;
          "Session\\PeXEnabled" = instanceCfg.bittorrent.pexEnabled;
          "Session\\Port" = instanceCfg.bittorrent.port;
          "Session\\QueueingSystemEnabled" = instanceCfg.bittorrent.queueingEnabled;
        };

        Core = filterAttrs (_: v: v != null) {
          "AutoDeleteAddedTorrentFile" = instanceCfg.core.autoDeleteAddedTorrentFile;
        };

        Meta = filterAttrs (_: v: v != null) {
          "MigrationVersion" = instanceCfg.meta.migrationVersion;
        };

        Network = filterAttrs (_: v: v != null) {
          "Cookies" = instanceCfg.network.cookies;
          "PortForwardingEnabled" = instanceCfg.network.portForwardingEnabled;
          "Proxy\\OnlyForTorrents" = instanceCfg.network.proxy.onlyForTorrents;
        };

        Preferences = filterAttrs (_: v: v != null) {
          # Advanced settings
          "Advanced\\RecheckOnCompletion" = instanceCfg.preferences.advanced.recheckOnCompletion;
          "Advanced\\trackerPort" = instanceCfg.preferences.advanced.trackerPort;

          # Connection settings
          "Connection\\ResolvePeerCountries" = instanceCfg.preferences.connection.resolvePeerCountries;

          # DynDNS settings
          "DynDNS\\DomainName" = instanceCfg.preferences.dynDns.domainName;
          "DynDNS\\Enabled" = instanceCfg.preferences.dynDns.enabled;
          "DynDNS\\Password" = instanceCfg.preferences.dynDns.password;
          "DynDNS\\Service" = instanceCfg.preferences.dynDns.service;
          "DynDNS\\Username" = instanceCfg.preferences.dynDns.username;

          # General settings
          "General\\Locale" = instanceCfg.preferences.general.locale;

          # Mail notification settings
          "MailNotification\\email" = instanceCfg.preferences.mailNotification.email;
          "MailNotification\\enabled" = instanceCfg.preferences.mailNotification.enabled;
          "MailNotification\\password" = instanceCfg.preferences.mailNotification.password;
          "MailNotification\\req_auth" = instanceCfg.preferences.mailNotification.reqAuth;
          "MailNotification\\req_ssl" = instanceCfg.preferences.mailNotification.reqSsl;
          "MailNotification\\sender" = instanceCfg.preferences.mailNotification.sender;
          "MailNotification\\smtp_server" = instanceCfg.preferences.mailNotification.smtpServer;
          "MailNotification\\username" = instanceCfg.preferences.mailNotification.username;

          # WebUI settings
          "WebUI\\Address" = instanceCfg.preferences.webui.address;
          "WebUI\\AlternativeUIEnabled" = instanceCfg.preferences.webui.alternativeUIEnabled;
          "WebUI\\AuthSubnetWhitelist" = instanceCfg.preferences.webui.authSubnetWhitelist;
          "WebUI\\AuthSubnetWhitelistEnabled" = instanceCfg.preferences.webui.authSubnetWhitelistEnabled;
          "WebUI\\BanDuration" = instanceCfg.preferences.webui.banDuration;
          "WebUI\\CSRFProtection" = instanceCfg.preferences.webui.csrfProtection;
          "WebUI\\ClickjackingProtection" = instanceCfg.preferences.webui.clickjackingProtection;
          "WebUI\\CustomHTTPHeaders" = instanceCfg.preferences.webui.customHTTPHeaders;
          "WebUI\\CustomHTTPHeadersEnabled" = instanceCfg.preferences.webui.customHTTPHeadersEnabled;
          "WebUI\\HTTPS\\CertificatePath" = instanceCfg.preferences.webui.https.certificatePath;
          "WebUI\\HTTPS\\Enabled" = instanceCfg.preferences.webui.https.enabled;
          "WebUI\\HTTPS\\KeyPath" = instanceCfg.preferences.webui.https.keyPath;
          "WebUI\\HostHeaderValidation" = instanceCfg.preferences.webui.hostHeaderValidation;
          "WebUI\\LocalHostAuth" = instanceCfg.preferences.webui.localHostAuth;
          "WebUI\\MaxAuthenticationFailCount" = instanceCfg.preferences.webui.maxAuthenticationFailCount;
          "WebUI\\Password_PBKDF2" = instanceCfg.preferences.webui.password;
          "WebUI\\Port" = instanceCfg.preferences.webui.port;
          "WebUI\\ReverseProxySupportEnabled" = instanceCfg.preferences.webui.reverseProxySupportEnabled;
          "WebUI\\RootFolder" = instanceCfg.preferences.webui.rootFolder;
          "WebUI\\SecureCookie" = instanceCfg.preferences.webui.secureCookie;
          "WebUI\\ServerDomains" = instanceCfg.preferences.webui.serverDomains;
          "WebUI\\SessionTimeout" = instanceCfg.preferences.webui.sessionTimeout;
          "WebUI\\TrustedReverseProxiesList" = instanceCfg.preferences.webui.trustedReverseProxiesList;
          "WebUI\\UseUPnP" = instanceCfg.preferences.webui.useUPnP;
          "WebUI\\Username" = instanceCfg.preferences.webui.username;
        };

        RSS = filterAttrs (_: v: v != null) {
          "AutoDownloader\\DownloadRepacks" = instanceCfg.rss.autoDownloader.downloadRepacks;
          "AutoDownloader\\SmartEpisodeFilter" = instanceCfg.rss.autoDownloader.smartEpisodeFilter;
        };
      };

      # Convert sections to config file format
      configLines = concatStringsSep "\n\n" (
        mapAttrsToList (
          sectionName: sectionAttrs:
          let
            lines = mapAttrsToList (key: value: "${key}=${formatValue value}") sectionAttrs;
          in
          if lines == [ ] then "" else "[${sectionName}]\n" + concatStringsSep "\n" lines
        ) sections
      );
    in
    pkgs.writeText "qBittorrent.conf" configLines;

  # Generate systemd service for an instance
  mkService =
    name: instanceCfg:
    let
      profileDir = "${instanceCfg.dataDir}/${instanceCfg.profile}";
      configFile = generateConfig instanceCfg;

      # Build command line arguments
      args = concatStringsSep " " (
        filter (x: x != "") [
          "--profile=${profileDir}"
          (optionalString instanceCfg.configManagement.overwriteOnRebuild "--configuration=${configFile}")
        ]
        ++ instanceCfg.extraArgs
      );
    in
    {
      description = "qBittorrent ${name} service";
      documentation = [ "man:qbittorrent-nox(1)" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "nss-lookup.target"
      ];

      serviceConfig = {
        Type = "exec";
        User = instanceCfg.user;
        Group = instanceCfg.group;
        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox ${args}";
        Restart = "always";
        RestartSec = instanceCfg.restartSec;
        Environment = mapAttrsToList (name: value: "${name}=${value}") instanceCfg.environment;
        WorkingDirectory = profileDir;
      };

      wantedBy = [ "multi-user.target" ];
    };

  # Generate tmpfiles rules for an instance
  mkTmpfiles =
    name: instanceCfg:
    let
      profileDir = "${instanceCfg.dataDir}/${instanceCfg.profile}";
    in
    [
      "d ${profileDir} 0750 ${instanceCfg.user} ${instanceCfg.group} -"
      "d ${profileDir}/config 0750 ${instanceCfg.user} ${instanceCfg.group} -"
      "d ${profileDir}/downloads 0770 ${instanceCfg.user} ${instanceCfg.group} -"
      "d ${profileDir}/incomplete 0770 ${instanceCfg.user} ${instanceCfg.group} -"
      "d ${profileDir}/watched 0770 ${instanceCfg.user} ${instanceCfg.group} -"
    ];

  # Generate config management script
  mkConfigManager =
    name: instanceCfg:
    let
      profileDir = "${instanceCfg.dataDir}/${instanceCfg.profile}";
      configFile = generateConfig instanceCfg;
      configPath = "${profileDir}/config/qBittorrent.conf";
    in
    pkgs.writeScript "qbittorrent-config-manager-${name}" ''
      #!/bin/bash
      set -e

      CONFIG_PATH="${configPath}"
      GENERATED_CONFIG="${configFile}"

      # Create config directory if it doesn't exist
      mkdir -p "$(dirname "$CONFIG_PATH")"

      if [ ! -f "$CONFIG_PATH" ]; then
        # Config doesn't exist, copy generated config
        echo "Creating initial qBittorrent config for ${name}..."
        cp "$GENERATED_CONFIG" "$CONFIG_PATH"
        chown ${instanceCfg.user}:${instanceCfg.group} "$CONFIG_PATH"
        chmod 640 "$CONFIG_PATH"
      elif ${if instanceCfg.configManagement.overwriteOnRebuild then "true" else "false"}; then
        # Overwrite mode enabled, replace config
        echo "Overwriting qBittorrent config for ${name}..."
        cp "$GENERATED_CONFIG" "$CONFIG_PATH"
        chown ${instanceCfg.user}:${instanceCfg.group} "$CONFIG_PATH"
        chmod 640 "$CONFIG_PATH"
      else
        # Seed mode, only copy if config is empty or missing critical settings
        echo "Checking qBittorrent config for ${name}..."
        if [ ! -s "$CONFIG_PATH" ] || ! grep -q "Session\\\\DefaultSavePath" "$CONFIG_PATH"; then
          echo "Seeding qBittorrent config for ${name}..."
          cp "$GENERATED_CONFIG" "$CONFIG_PATH"
          chown ${instanceCfg.user}:${instanceCfg.group} "$CONFIG_PATH"
          chmod 640 "$CONFIG_PATH"
        fi
      fi
    '';

in
{
  options.services.qbt = {
    enable = mkEnableOption "qBittorrent service";

    package = mkOption {
      type = types.package;
      default = pkgs.qbittorrent-nox;
      description = "qBittorrent-nox package to use";
    };

    instances = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to enable this qBittorrent instance";
            };

            # Core instance settings
            profile = mkOption {
              type = types.str;
              description = "Profile directory name for this instance";
              example = "main";
            };

            user = mkOption {
              type = types.str;
              default = "qbittorrent";
              description = "User to run qBittorrent as";
            };

            group = mkOption {
              type = types.str;
              default = "qbittorrent";
              description = "Group to run qBittorrent as";
            };

            dataDir = mkOption {
              type = types.str;
              default = "/var/lib/qbittorrent";
              description = "Base directory for qBittorrent data";
            };

            # Configuration sections
            autoRun = mkOption {
              type = types.submodule {
                options = {
                  enabled = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Enable AutoRun";
                  };

                  program = mkOption {
                    type = types.str;
                    default = "";
                    description = "Program to run on torrent completion";
                  };
                };
              };
              default = { };
              description = "AutoRun configuration";
            };

            bittorrent = mkOption {
              type = types.submodule {
                options = {
                  alternativeGlobalDLSpeedLimit = mkOption {
                    type = types.nullOr types.int;
                    default = null;
                    description = "Alternative global download speed limit in KB/s";
                  };

                  alternativeGlobalUPSpeedLimit = mkOption {
                    type = types.nullOr types.int;
                    default = null;
                    description = "Alternative global upload speed limit in KB/s";
                  };

                  dhtEnabled = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable DHT";
                  };

                  defaultSavePath = mkOption {
                    type = types.str;
                    description = "Default save path for torrents";
                  };

                  lsdEnabled = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable Local Service Discovery";
                  };

                  maxUploads = mkOption {
                    type = types.int;
                    default = -1;
                    description = "Maximum uploads (-1 = unlimited)";
                  };

                  maxUploadsPerTorrent = mkOption {
                    type = types.int;
                    default = -1;
                    description = "Maximum uploads per torrent (-1 = unlimited)";
                  };

                  pexEnabled = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable Peer Exchange";
                  };

                  port = mkOption {
                    type = types.port;
                    default = 6881;
                    description = "Port for BitTorrent connections";
                  };

                  queueingEnabled = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable torrent queueing";
                  };
                };
              };
              default = { };
              description = "BitTorrent configuration";
            };

            core = mkOption {
              type = types.submodule {
                options = {
                  autoDeleteAddedTorrentFile = mkOption {
                    type = types.enum [
                      "Never"
                      "Always"
                      "OnSuccessfulDownload"
                    ];
                    default = "Never";
                    description = "When to auto-delete added torrent files";
                  };
                };
              };
              default = { };
              description = "Core settings";
            };

            meta = mkOption {
              type = types.submodule {
                options = {
                  migrationVersion = mkOption {
                    type = types.int;
                    default = 6;
                    description = "Migration version";
                  };
                };
              };
              default = { };
              description = "Meta settings";
            };

            network = mkOption {
              type = types.submodule {
                options = {
                  cookies = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Network cookies";
                  };

                  portForwardingEnabled = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Enable port forwarding";
                  };

                  proxy = mkOption {
                    type = types.submodule {
                      options = {
                        onlyForTorrents = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Use proxy only for torrents";
                        };
                      };
                    };
                    default = { };
                    description = "Proxy settings";
                  };
                };
              };
              default = { };
              description = "Network settings";
            };

            preferences = mkOption {
              type = types.submodule {
                options = {
                  advanced = mkOption {
                    type = types.submodule {
                      options = {
                        recheckOnCompletion = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Recheck torrents on completion";
                        };

                        trackerPort = mkOption {
                          type = types.port;
                          default = 9000;
                          description = "Tracker port";
                        };
                      };
                    };
                    default = { };
                    description = "Advanced settings";
                  };

                  connection = mkOption {
                    type = types.submodule {
                      options = {
                        resolvePeerCountries = mkOption {
                          type = types.bool;
                          default = true;
                          description = "Resolve peer countries";
                        };
                      };
                    };
                    default = { };
                    description = "Connection settings";
                  };

                  dynDns = mkOption {
                    type = types.submodule {
                      options = {
                        domainName = mkOption {
                          type = types.str;
                          default = "changeme.dyndns.org";
                          description = "DynDNS domain name";
                        };

                        enabled = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Enable DynDNS";
                        };

                        password = mkOption {
                          type = types.str;
                          default = "";
                          description = "DynDNS password";
                        };

                        service = mkOption {
                          type = types.str;
                          default = "DynDNS";
                          description = "DynDNS service";
                        };

                        username = mkOption {
                          type = types.str;
                          default = "";
                          description = "DynDNS username";
                        };
                      };
                    };
                    default = { };
                    description = "DynDNS settings";
                  };

                  general = mkOption {
                    type = types.submodule {
                      options = {
                        locale = mkOption {
                          type = types.str;
                          default = "";
                          description = "Interface locale";
                        };
                      };
                    };
                    default = { };
                    description = "General settings";
                  };

                  mailNotification = mkOption {
                    type = types.submodule {
                      options = {
                        email = mkOption {
                          type = types.str;
                          default = "";
                          description = "Email address for notifications";
                        };

                        enabled = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Enable mail notifications";
                        };

                        password = mkOption {
                          type = types.str;
                          default = "";
                          description = "SMTP password";
                        };

                        reqAuth = mkOption {
                          type = types.bool;
                          default = true;
                          description = "Require SMTP authentication";
                        };

                        reqSsl = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Require SSL for SMTP";
                        };

                        sender = mkOption {
                          type = types.str;
                          default = "qBittorrent_notification@example.com";
                          description = "Email sender address";
                        };

                        smtpServer = mkOption {
                          type = types.str;
                          default = "smtp.changeme.com";
                          description = "SMTP server";
                        };

                        username = mkOption {
                          type = types.str;
                          default = "";
                          description = "SMTP username";
                        };
                      };
                    };
                    default = { };
                    description = "Mail notification settings";
                  };

                  webui = mkOption {
                    type = types.submodule {
                      options = {
                        address = mkOption {
                          type = types.str;
                          default = "*";
                          description = "WebUI address to bind to";
                        };

                        alternativeUIEnabled = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Enable alternative UI";
                        };

                        authSubnetWhitelist = mkOption {
                          type = types.str;
                          default = "";
                          description = "Authentication subnet whitelist";
                        };

                        authSubnetWhitelistEnabled = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Enable authentication subnet whitelist";
                        };

                        banDuration = mkOption {
                          type = types.int;
                          default = 3600;
                          description = "Ban duration in seconds";
                        };

                        csrfProtection = mkOption {
                          type = types.bool;
                          default = true;
                          description = "Enable CSRF protection";
                        };

                        clickjackingProtection = mkOption {
                          type = types.bool;
                          default = true;
                          description = "Enable clickjacking protection";
                        };

                        customHTTPHeaders = mkOption {
                          type = types.str;
                          default = "";
                          description = "Custom HTTP headers";
                        };

                        customHTTPHeadersEnabled = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Enable custom HTTP headers";
                        };

                        https = mkOption {
                          type = types.submodule {
                            options = {
                              certificatePath = mkOption {
                                type = types.str;
                                default = "";
                                description = "HTTPS certificate path";
                              };

                              enabled = mkOption {
                                type = types.bool;
                                default = false;
                                description = "Enable HTTPS";
                              };

                              keyPath = mkOption {
                                type = types.str;
                                default = "";
                                description = "HTTPS key path";
                              };
                            };
                          };
                          default = { };
                          description = "HTTPS settings";
                        };

                        hostHeaderValidation = mkOption {
                          type = types.bool;
                          default = true;
                          description = "Enable host header validation";
                        };

                        localHostAuth = mkOption {
                          type = types.bool;
                          default = true;
                          description = "Allow localhost authentication bypass";
                        };

                        maxAuthenticationFailCount = mkOption {
                          type = types.int;
                          default = 5;
                          description = "Maximum authentication failures";
                        };

                        password = mkOption {
                          type = types.str;
                          description = "WebUI password (will be hashed automatically)";
                        };

                        port = mkOption {
                          type = types.port;
                          default = 8080;
                          description = "WebUI port";
                        };

                        reverseProxySupportEnabled = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Enable reverse proxy support";
                        };

                        rootFolder = mkOption {
                          type = types.str;
                          default = "";
                          description = "WebUI root folder";
                        };

                        secureCookie = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Use secure cookies";
                        };

                        serverDomains = mkOption {
                          type = types.str;
                          default = "*";
                          description = "Server domains";
                        };

                        sessionTimeout = mkOption {
                          type = types.int;
                          default = 3600;
                          description = "Session timeout in seconds";
                        };

                        trustedReverseProxiesList = mkOption {
                          type = types.str;
                          default = "";
                          description = "Trusted reverse proxies list";
                        };

                        useUPnP = mkOption {
                          type = types.bool;
                          default = true;
                          description = "Use UPnP for WebUI";
                        };

                        username = mkOption {
                          type = types.str;
                          default = "admin";
                          description = "WebUI username";
                        };
                      };
                    };
                    default = { };
                    description = "WebUI settings";
                  };
                };
              };
              default = { };
              description = "Preferences configuration";
            };

            rss = mkOption {
              type = types.submodule {
                options = {
                  autoDownloader = mkOption {
                    type = types.submodule {
                      options = {
                        downloadRepacks = mkOption {
                          type = types.bool;
                          default = true;
                          description = "Download repacks";
                        };

                        smartEpisodeFilter = mkOption {
                          type = types.str;
                          default = "s(\\\\d+)e(\\\\d+), (\\\\d+)x(\\\\d+), \"(\\\\d{4}[.\\\\-]\\\\d{1,2}[.\\\\-]\\\\d{1,2})\", \"(\\\\d{1,2}[.\\\\-]\\\\d{1,2}[.\\\\-]\\\\d{4})\"";
                          description = "Smart episode filter regex";
                        };
                      };
                    };
                    default = { };
                    description = "RSS auto-downloader settings";
                  };
                };
              };
              default = { };
              description = "RSS settings";
            };

            # Config file management
            configManagement = mkOption {
              type = types.submodule {
                options = {
                  overwriteOnRebuild = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Overwrite config file on every rebuild (true) or seed it once (false)";
                  };

                  seedConfig = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Create initial config file if it doesn't exist";
                  };
                };
              };
              default = { };
              description = "Configuration file management options";
            };

            # Service options
            restartSec = mkOption {
              type = types.str;
              default = "5s";
              description = "Restart delay for the service";
            };

            environment = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = "Environment variables for the service";
            };

            extraArgs = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Additional command line arguments";
            };
          };
        }
      );
      default = { };
      description = "qBittorrent instances to run";
      example = {
        main = {
          profile = "main";
          bittorrent.defaultSavePath = "/var/lib/qbittorrent/downloads";
          preferences.webui.port = 8080;
          preferences.webui.username = "admin";
          preferences.webui.password = "admin123";
        };
      };
    };

    # Global options that apply to all instances
    global = {
      user = mkOption {
        type = types.str;
        default = "qbittorrent";
        description = "Default user for qBittorrent instances";
      };

      group = mkOption {
        type = types.str;
        default = "qbittorrent";
        description = "Default group for qBittorrent instances";
      };

      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/qbittorrent";
        description = "Default base directory for qBittorrent data";
      };
    };
  };

  config = mkIf cfg.enable {
    # Add qBittorrent-nox to system packages
    environment.systemPackages = [ cfg.package ];

    # Generate tmpfiles rules for all instances
    systemd.tmpfiles.rules = concatLists (
      mapAttrsToList (
        name: instanceCfg: if instanceCfg.enable then mkTmpfiles name instanceCfg else [ ]
      ) cfg.instances
    );

    # Generate systemd services for all instances
    systemd.services = listToAttrs (
      mapAttrsToList (
        name: instanceCfg:
        if instanceCfg.enable then
          nameValuePair "qbt-${name}" (
            (mkService name instanceCfg)
            // {
              preStart = "${mkConfigManager name instanceCfg}";
            }
          )
        else
          nameValuePair "qbt-${name}" { }
      ) cfg.instances
    );

    # Open firewall ports for all enabled instances
    networking.firewall.allowedTCPPorts = concatLists (
      mapAttrsToList (
        name: instanceCfg:
        if instanceCfg.enable then
          [
            instanceCfg.preferences.webui.port
            instanceCfg.bittorrent.port
          ]
        else
          [ ]
      ) cfg.instances
    );

    # Allow UDP for torrenting ports
    networking.firewall.allowedUDPPorts = concatLists (
      mapAttrsToList (
        name: instanceCfg: if instanceCfg.enable then [ instanceCfg.bittorrent.port ] else [ ]
      ) cfg.instances
    );
  };
}
