# Uplift - File sharing container
{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
  ...
}:

{
  containers.uplift = {
    autoStart = true;
    enableTun = true;
    privateNetwork = true;
    hostBridge = "br0";

    bindMounts = {
      "/mnt/hdd-pool/main" = {
        hostPath = "/mnt/hdd-pool/main";
        isReadOnly = false;
      };
      "/mnt/nvme-pool/scratch" = {
        hostPath = "/mnt/nvme-pool/scratch";
        isReadOnly = false;
      };
    };

    # --- Uplift Container Configuration --- #
    config =
      { config, pkgs, ... }:
      {

        imports = [
          ../base.nix
          ../../../../modules/qbittorrent-nox.nix
          ../../../../modules/qbt-backup.nix
        ];

        _module.args.nixpkgs-unstable = nixpkgs-unstable;

        # Network Configuration
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.12";
            prefixLength = 24;
          }
        ];

        # Explicitly add service users to media group (defined in base)
        users.users.qbittorrent.extraGroups = [ "media" ];
        users.users.qui.extraGroups = [ "media" ];

        # --- qBittorrent Service --- #
        services.qbt = {
          enable = true;
          openFirewall = true;

          instances = {

            auto = {
              profile = "auto";
              webuiPort = 8040;
              torrentingPort = 58040;
              user = "qbittorrent";
              group = "media";
              configManagement.overwriteOnRebuild = true;
              serverConfig = {
                LegalNotice.Accepted = true;
                BitTorrent = {
                  "Session\\DHTEnabled" = false;
                  "Session\\LSDEnabled" = false;
                  "Session\\PeXEnabled" = false;
                  "Session\\DefaultSavePath" = "/mnt/nvme-pool/scratch/qbittorrent/downloads";
                  "Session\\TempPathEnabled" = false;
                  "Session\\QueueingSystemEnabled" = false;
                  "Session\\MaxActiveTorrents" = -1;
                  "Session\\MaxActiveUploads" = -1;
                  "Session\\GlobalMaxRatio" = -1;
                  "Session\\GlobalMaxSeedingMinutes" = 43200;
                  "Session\\GlobalMaxInactiveSeedingMinutes" = 43200;
                  "Session\\ShareLimitAction" = "RemoveWithContent";
                };
                Preferences = {
                  "WebUI\\AuthSubnetWhitelist" = "10.1.1.0/24";
                  "WebUI\\AuthSubnetWhitelistEnabled" = true;
                  "WebUI\\LocalHostAuth" = false;
                  "WebUI\\UseUPnP" = false;
                };
                Network = {
                  "PortForwardingEnabled" = false;
                };
              };
            };

            movies = {
              profile = "movies";
              webuiPort = 8041;
              torrentingPort = 58041;
              user = "qbittorrent";
              group = "media";
              configManagement.overwriteOnRebuild = true;
              serverConfig = {
                LegalNotice.Accepted = true;
                BitTorrent = {
                  "Session\\DHTEnabled" = false;
                  "Session\\LSDEnabled" = false;
                  "Session\\PeXEnabled" = false;
                  "Session\\DefaultSavePath" = "/mnt/hdd-pool/main/Media/Movies";
                  "Session\\TempPathEnabled" = false;
                  "Session\\QueueingSystemEnabled" = false;
                  "Session\\MaxActiveTorrents" = -1;
                  "Session\\MaxActiveUploads" = -1;
                  "Session\\GlobalMaxRatio" = -1;
                };
                Preferences = {
                  "WebUI\\AuthSubnetWhitelist" = "10.1.1.0/24";
                  "WebUI\\AuthSubnetWhitelistEnabled" = true;
                  "WebUI\\LocalHostAuth" = false;
                  "WebUI\\UseUPnP" = false;
                };
                Network = {
                  "PortForwardingEnabled" = false;
                };
              };
            };

            tv = {
              profile = "tv";
              webuiPort = 8042;
              torrentingPort = 58042;
              user = "qbittorrent";
              group = "media";
              configManagement.overwriteOnRebuild = true;
              serverConfig = {
                LegalNotice.Accepted = true;
                BitTorrent = {
                  "Session\\DHTEnabled" = false;
                  "Session\\LSDEnabled" = false;
                  "Session\\PeXEnabled" = false;
                  "Session\\DefaultSavePath" = "/mnt/hdd-pool/main/Media/TV";
                  "Session\\TempPathEnabled" = false;
                  "Session\\QueueingSystemEnabled" = false;
                  "Session\\MaxActiveTorrents" = -1;
                  "Session\\MaxActiveUploads" = -1;
                  "Session\\GlobalMaxRatio" = -1;
                };
                Preferences = {
                  "WebUI\\AuthSubnetWhitelist" = "10.1.1.0/24";
                  "WebUI\\AuthSubnetWhitelistEnabled" = true;
                  "WebUI\\LocalHostAuth" = false;
                  "WebUI\\UseUPnP" = false;
                };
                Network = {
                  "PortForwardingEnabled" = false;
                };
              };
            };

            games = {
              profile = "games";
              webuiPort = 8043;
              torrentingPort = 58043;
              user = "qbittorrent";
              group = "media";
              configManagement.overwriteOnRebuild = true;
              serverConfig = {
                LegalNotice.Accepted = true;
                BitTorrent = {
                  "Session\\DHTEnabled" = false;
                  "Session\\LSDEnabled" = false;
                  "Session\\PeXEnabled" = false;
                  "Session\\DefaultSavePath" = "/mnt/hdd-pool/main/Games";
                  "Session\\TempPathEnabled" = false;
                  "Session\\QueueingSystemEnabled" = false;
                  "Session\\MaxActiveTorrents" = -1;
                  "Session\\MaxActiveUploads" = -1;
                  "Session\\GlobalMaxRatio" = -1;
                };
                Preferences = {
                  "WebUI\\AuthSubnetWhitelist" = "10.1.1.0/24";
                  "WebUI\\AuthSubnetWhitelistEnabled" = true;
                  "WebUI\\LocalHostAuth" = false;
                  "WebUI\\UseUPnP" = false;
                };
                Network = {
                  "PortForwardingEnabled" = false;
                };
              };
            };

            music = {
              profile = "music";
              webuiPort = 8044;
              torrentingPort = 58044;
              user = "qbittorrent";
              group = "media";
              configManagement.overwriteOnRebuild = true;
              serverConfig = {
                LegalNotice.Accepted = true;
                BitTorrent = {
                  "Session\\DHTEnabled" = false;
                  "Session\\LSDEnabled" = false;
                  "Session\\PeXEnabled" = false;
                  "Session\\DefaultSavePath" = "/mnt/hdd-pool/main/Media/Music";
                  "Session\\TempPathEnabled" = false;
                  "Session\\QueueingSystemEnabled" = false;
                  "Session\\MaxActiveTorrents" = -1;
                  "Session\\MaxActiveUploads" = -1;
                  "Session\\GlobalMaxRatio" = -1;
                };
                Preferences = {
                  "WebUI\\AuthSubnetWhitelist" = "10.1.1.0/24";
                  "WebUI\\AuthSubnetWhitelistEnabled" = true;
                  "WebUI\\LocalHostAuth" = false;
                  "WebUI\\UseUPnP" = false;
                };
                Network = {
                  "PortForwardingEnabled" = false;
                };
              };
            };

            private = {
              profile = "private";
              webuiPort = 8050;
              torrentingPort = 58050;
              user = "qbittorrent";
              group = "media";
              configManagement.overwriteOnRebuild = true;
              serverConfig = {
                LegalNotice.Accepted = true;
                BitTorrent = {
                  "Session\\DHTEnabled" = false;
                  "Session\\LSDEnabled" = false;
                  "Session\\PeXEnabled" = false;
                  "Session\\DefaultSavePath" = "/mnt/hdd-pool/main";
                  "Session\\TempPathEnabled" = false;
                  "Session\\QueueingSystemEnabled" = false;
                  "Session\\MaxActiveTorrents" = -1;
                  "Session\\MaxActiveUploads" = -1;
                  "Session\\GlobalMaxRatio" = -1;
                };
                Preferences = {
                  "WebUI\\AuthSubnetWhitelist" = "10.1.1.0/24";
                  "WebUI\\AuthSubnetWhitelistEnabled" = true;
                  "WebUI\\LocalHostAuth" = false;
                  "WebUI\\UseUPnP" = false;
                };
                Network = {
                  "PortForwardingEnabled" = false;
                };
              };
            };
          };
        };

        # --- Qui Service --- #
        environment.systemPackages = [ pkgs.unstable.qui ];

        users.users.qui = {
          isSystemUser = true;
          group = "media";
        };

        systemd.services =
          (lib.mapAttrs' (
            name: _:
            lib.nameValuePair "qbt-${name}" {
              serviceConfig.UMask = "0002";
            }
          ) config.services.qbt.instances)
          // {
            qui = {
              description = "Qui - Modern qBittorrent WebUI";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "simple";
                User = "qui";
                Group = "media";
                UMask = "0002";

                # Automatically create /var/lib/qui with correct permissions
                StateDirectory = "qui";
                WorkingDirectory = "/var/lib/qui";

                ExecStart = "${pkgs.qui}/bin/qui serve";
                Restart = "always";
                RestartSec = "10";
              };

              environment = {
                QUI__PORT = "7476";
                QUI__HOST = "0.0.0.0";
                QUI__DATA_DIR = "/var/lib/qui";
                HOME = "/var/lib/qui";
              };
            };
          };

        networking.firewall.allowedTCPPorts = [
          7476 # qui
        ];

        services.qbt-backup = {
          enable = true;
          user = "qbittorrent";
          group = "media";

          retention = {
            hourly = {
              enable = true;
              keep = 24;
            };
            daily = {
              enable = true;
              keep = 7;
            };
            weekly = {
              enable = true;
              keep = 4;
            };
            monthly = {
              enable = true;
              keep = 12;
            };
          };
        };
      };
  };
}
