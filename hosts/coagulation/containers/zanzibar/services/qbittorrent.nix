{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ ../../../../../modules/qbittorrent-nox.nix ];

  services.qbittorrent = {
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

  systemd.services = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "qbittorrent-${name}" {
      serviceConfig.UMask = "0002";
    }
  ) config.services.qbittorrent.instances;
}
