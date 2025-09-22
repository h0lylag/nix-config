# qbittorrent multiple instances configuration for zanzibar container
# This extends the built-in NixOS qbittorrent service for multiple instances
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Import the qbittorrent instances module
  imports = [ ../../../../modules/qbittorrent-instances.nix ];

  # Configure the main qbittorrent service (this provides defaults)
  services.qbittorrent = {
    enable = false; # We're using instances instead
    user = "chris";
    group = "users";
    package = pkgs.qbittorrent-nox;
  };

  # Enable qbittorrent-nox instances
  services.qbittorrent-nox-instances.enable = true;

  # Configure the 6 instances with organized directory structure
  services.qbittorrent-nox-instances.instances = {
    auto = {
      webuiPort = 8040;
      torrentingPort = 58040;
      profileDir = "/var/lib/qbittorrent/auto";
      logFile = "/var/log/qbittorrent/auto/qbittorrent.log";
    };

    movies = {
      webuiPort = 8041;
      torrentingPort = 58041;
      profileDir = "/var/lib/qbittorrent/movies";
      logFile = "/var/log/qbittorrent/movies/qbittorrent.log";
    };

    tv = {
      webuiPort = 8042;
      torrentingPort = 58042;
      profileDir = "/var/lib/qbittorrent/tv";
      logFile = "/var/log/qbittorrent/tv/qbittorrent.log";
    };

    games = {
      webuiPort = 8043;
      torrentingPort = 58043;
      profileDir = "/var/lib/qbittorrent/games";
      logFile = "/var/log/qbittorrent/games/qbittorrent.log";
    };

    music = {
      webuiPort = 8044;
      torrentingPort = 58044;
      profileDir = "/var/lib/qbittorrent/music";
      logFile = "/var/log/qbittorrent/music/qbittorrent.log";
    };

    private = {
      webuiPort = 8099;
      torrentingPort = 58099;
      profileDir = "/var/lib/qbittorrent/private";
      logFile = "/var/log/qbittorrent/private/qbittorrent.log";
    };
  };

  # Ensure the users group exists
  users.groups.users = { };
}
