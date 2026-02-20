# Reddit Watch Exchange Monitor service
{
  config,
  pkgs,
  lib,
  ...
}:

let
  reddit-monitor = pkgs.callPackage ../../../pkgs/reddit-monitor/default.nix { };

  keywords = [
    "Hamilton"
    "Seiko"
  ];
  excludeKeywords = [ ];
  discordUserId = "262240479549063168";
  subreddit = "Watchexchange";
  rateLimitDelay = 0.5;

  # Generate config.toml from options
  configToml = pkgs.writeText "reddit-monitor-config.toml" ''
    [reddit]
    subreddit = "${subreddit}"
    base_url = "https://old.reddit.com"

    [discord]
    user_id = "${discordUserId}"
    rate_limit_delay = ${toString rateLimitDelay}

    [filter]
    keywords = [${lib.concatMapStringsSep ", " (k: ''"${k}"'') keywords}]
    exclude_keywords = [${lib.concatMapStringsSep ", " (k: ''"${k}"'') excludeKeywords}]

    output_file = "filtered_posts.json"
    tracking_file = "tracked_posts.json"
    all_posts_file = "all_posts.json"
  '';
in
{
  # Discord webhook secret (dotenv format)
  sops.secrets.reddit-webhook = {
    sopsFile = ../../../secrets/reddit-webhook.env;
    format = "dotenv";
    mode = "0400";
    owner = "reddit-monitor";
    group = "reddit-monitor";
  };

  # Create reddit-monitor user and group
  users.users.reddit-monitor = {
    isSystemUser = true;
    group = "reddit-monitor";
    home = "/var/lib/reddit-monitor";
  };

  users.groups.reddit-monitor = { };

  # Create state directory
  systemd.tmpfiles.rules = [
    "d /var/lib/reddit-monitor 0755 reddit-monitor reddit-monitor"
  ];

  # Systemd service
  systemd.services.reddit-watchexchange-monitor = {
    description = "Reddit Watch Exchange Monitor";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${reddit-monitor}/bin/fetch-posts --config ${configToml} --state-dir /var/lib/reddit-monitor";
      EnvironmentFile = config.sops.secrets.reddit-webhook.path;
      User = "reddit-monitor";
      Group = "reddit-monitor";
      StandardOutput = "journal";
      StandardError = "journal";
      WorkingDirectory = "/var/lib/reddit-monitor";
    };

    unitConfig = {
      ConditionNetwork = "online";
    };
  };

  # Systemd timer (runs every 15 minutes)
  systemd.timers.reddit-watchexchange-monitor = {
    description = "Reddit Watch Exchange Monitor Timer";
    timerConfig = {
      OnBootSec = "1min";
      OnCalendar = "*:0/15";
      AccuracySec = "1min";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };
}
