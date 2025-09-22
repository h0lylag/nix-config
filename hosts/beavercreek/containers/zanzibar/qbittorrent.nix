# qBittorrent instances configuration for zanzibar container using the new module
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Import the qBittorrent-nox module
  imports = [ ../../../../modules/qbitorrent.nix ];

  # Enable qBittorrent-nox service
  services.qbittorrent-nox.enable = true;

  # Configure the 6 instances from the original configuration
  services.qbittorrent-nox.instances = {
    auto = {
      webuiPort = 8040;
      torrentingPort = 58040;
      profile = "auto";
      savePath = "/var/lib/qbittorrent/auto/complete";
      incompletePath = "/var/lib/qbittorrent/auto/incomplete";
      watchPath = "/var/lib/qbittorrent/auto/watched";
      user = "chris";
      group = "users";
      confirmLegalNotice = true;
      logFile = "/var/log/qbittorrent/auto/qbittorrent.log";
    };

    movies = {
      webuiPort = 8041;
      torrentingPort = 58041;
      profile = "movies";
      savePath = "/var/lib/qbittorrent/movies/complete";
      incompletePath = "/var/lib/qbittorrent/movies/incomplete";
      watchPath = "/var/lib/qbittorrent/movies/watched";
      user = "chris";
      group = "users";
      category = "movies";
      confirmLegalNotice = true;
      logFile = "/var/log/qbittorrent/movies/qbittorrent.log";
    };

    tv = {
      webuiPort = 8042;
      torrentingPort = 58042;
      profile = "tv";
      savePath = "/var/lib/qbittorrent/tv/complete";
      incompletePath = "/var/lib/qbittorrent/tv/incomplete";
      watchPath = "/var/lib/qbittorrent/tv/watched";
      user = "chris";
      group = "users";
      category = "tv";
      confirmLegalNotice = true;
      logFile = "/var/log/qbittorrent/tv/qbittorrent.log";
    };

    games = {
      webuiPort = 8043;
      torrentingPort = 58043;
      profile = "games";
      savePath = "/var/lib/qbittorrent/games/complete";
      incompletePath = "/var/lib/qbittorrent/games/incomplete";
      watchPath = "/var/lib/qbittorrent/games/watched";
      user = "chris";
      group = "users";
      category = "games";
      confirmLegalNotice = true;
      logFile = "/var/log/qbittorrent/games/qbittorrent.log";
    };

    music = {
      webuiPort = 8044;
      torrentingPort = 58044;
      profile = "music";
      savePath = "/var/lib/qbittorrent/music/complete";
      incompletePath = "/var/lib/qbittorrent/music/incomplete";
      watchPath = "/var/lib/qbittorrent/music/watched";
      user = "chris";
      group = "users";
      category = "music";
      confirmLegalNotice = true;
      logFile = "/var/log/qbittorrent/music/qbittorrent.log";
    };

    private = {
      webuiPort = 8099;
      torrentingPort = 58099;
      profile = "private";
      savePath = "/var/lib/qbittorrent/private/complete";
      incompletePath = "/var/lib/qbittorrent/private/incomplete";
      watchPath = "/var/lib/qbittorrent/private/watched";
      user = "chris";
      group = "users";
      category = "private";
      confirmLegalNotice = true;
      logFile = "/var/log/qbittorrent/private/qbittorrent.log";
    };
  };

  # Global settings
  services.qbittorrent-nox.global = {
    user = "chris";
    group = "users";
    dataDir = "/var/lib/qbittorrent";
  };

  # Ensure the users group exists (it should by default, but being explicit)
  users.groups.users = { };

  #### Container-specific notes (outside the module, in the container host):
  # - Download folders are now in /var/lib/qbittorrent/<instance>/<complete|incomplete|watched>
  # - Bind-mount your big pool from the HOST into the container at /srv/media
  #   e.g. in the container definition:
  #   bindMounts."/srv/media" = { hostPath = "/mnt/hdd-pool/main/media"; isReadOnly = false; };
  #
  # - Ensure UID/GID mapping makes the container's `chris` match the host's owner of /mnt/hdd-pool/main/media.
  #   For unprivileged containers, set idmap (uidmap/gidmap) so writes land with a sensible host UID/GID.
  #
  # - If you use reverse proxies: don't expose those WebUI ports publicly; proxy them and keep the firewall tight.
}
