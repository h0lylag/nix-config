# qBittorrent instances configuration for zanzibar container using the new module
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Import the new qBittorrent-nox module
  # Path is 5 levels up: zanzibar -> containers -> beavercreek -> hosts -> .nixos-config -> modules
  imports = [ ../../../../modules/qbittorrent-nox.nix ];

  services.qbt = {
    enable = true;
    openFirewall = true;

    instances = {
      auto = {
        profile = "auto";
        webuiPort = 8040;
        torrentingPort = 58040;
        user = "chris";
        group = "users";
        configManagement.overwriteOnRebuild = true;
        serverConfig = {
          LegalNotice.Accepted = true;
          BitTorrent = {
            "Session\\DefaultSavePath" = "/mnt/nvme-pool/scratch/qbittorrent/downloads";
            "Session\\TempPathEnabled" = false;
          };
          Preferences = {
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
        user = "chris";
        group = "users";
        configManagement.overwriteOnRebuild = true;
        serverConfig = {
          LegalNotice.Accepted = true;
          BitTorrent = {
            "Session\\DefaultSavePath" = "/mnt/hdd-pool/main/Media/Movies";
            "Session\\TempPathEnabled" = false;
          };
          Preferences = {
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
        user = "chris";
        group = "users";
        configManagement.overwriteOnRebuild = true;
        serverConfig = {
          LegalNotice.Accepted = true;
          BitTorrent = {
            "Session\\DefaultSavePath" = "/mnt/hdd-pool/main/Media/TV";
            "Session\\TempPathEnabled" = false;
          };
          Preferences = {
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
        user = "chris";
        group = "users";
        configManagement.overwriteOnRebuild = true;
        serverConfig = {
          LegalNotice.Accepted = true;
          BitTorrent = {
            "Session\\DefaultSavePath" = "/mnt/hdd-pool/main/Games";
            "Session\\TempPathEnabled" = false;
          };
          Preferences = {
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
        user = "chris";
        group = "users";
        configManagement.overwriteOnRebuild = true;
        serverConfig = {
          LegalNotice.Accepted = true;
          BitTorrent = {
            "Session\\DefaultSavePath" = "/mnt/hdd-pool/main/Media/Music";
            "Session\\TempPathEnabled" = false;
          };
          Preferences = {
            "WebUI\\UseUPnP" = false;
          };
          Network = {
            "PortForwardingEnabled" = false;
          };
        };
      };

      private = {
        profile = "private";
        webuiPort = 8099;
        torrentingPort = 58099;
        user = "chris";
        group = "users";
        configManagement.overwriteOnRebuild = true;
        serverConfig = {
          LegalNotice.Accepted = true;
          BitTorrent = {
            "Session\\DefaultSavePath" = "/mnt/hdd-pool/main";
            "Session\\TempPathEnabled" = false;
          };
          Preferences = {
            "WebUI\\UseUPnP" = false;
          };
          Network = {
            "PortForwardingEnabled" = false;
          };
        };
      };
    };
  };
}
