# qBittorrent instances configuration for zanzibar container
{
  config,
  pkgs,
  lib,
  ...
}:
let
  user = "chris";
  group = "users";
  instances = {
    auto = {
      webuiPort = 8040;
      torrentingPort = 58040;
    };
    movies = {
      webuiPort = 8041;
      torrentingPort = 58041;
    };
    tv = {
      webuiPort = 8042;
      torrentingPort = 58042;
    };
    games = {
      webuiPort = 8043;
      torrentingPort = 58043;
    };
    music = {
      webuiPort = 8044;
      torrentingPort = 58044;
    };
    private = {
      webuiPort = 8099;
      torrentingPort = 58099;
    };
  };

  mkTmp = name: ''
    d /var/log/qbittorrent/${name}            0750 ${user} ${group} -
    d /var/lib/qbittorrent/${name}/incomplete 0770 ${user} ${group} -
    d /var/lib/qbittorrent/${name}/complete   0770 ${user} ${group} -
    d /var/lib/qbittorrent/${name}/watched    0770 ${user} ${group} -
  '';

  # Turn the attrset into a list of names
  instanceNames = lib.attrNames instances;

  # Create a service for each instance
  mkService =
    name:
    let
      webuiPort = toString (lib.getAttr name instances).webuiPort;
      torrentingPort = toString (lib.getAttr name instances).torrentingPort;
      home = "/var/lib/qbittorrent/${name}";
      incompleteDownloads = "/var/lib/qbittorrent/${name}/incomplete";
      completedDownloads = "/var/lib/qbittorrent/${name}/complete";
      watchFolder = "/var/lib/qbittorrent/${name}/watched";
    in
    {
      description = "qBittorrent-nox ${name} service";
      documentation = [ "man:qbittorrent-nox(1)" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "nss-lookup.target"
      ];

      serviceConfig = {
        Type = "exec";
        User = user;
        Group = group;

        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --profile=${name}/config --webuiPort=${webuiPort} --torrentingPort=${torrentingPort} --save-path=${completedDownloads}";

        Restart = "always";
        RestartSec = "5s";
        # Optional: write a file log instead of only journald
        # StandardOutput = "append:/var/log/qbittorrent/${name}/qbittorrent.log";
        # StandardError  = "inherit";
      };

      wantedBy = [ "multi-user.target" ];
    };

in
{
  environment.systemPackages = [ pkgs.qbittorrent-nox ];

  # Create all needed directories
  systemd.tmpfiles.rules = lib.flatten (
    map (n: lib.splitString "\n" (lib.trim (mkTmp n))) instanceNames
  );

  # Create services for each instance
  systemd.services = lib.mkMerge (
    map (name: {
      "qbittorrent-${name}" = mkService name;
    }) instanceNames
  );

  # Open all instance WebUI ports
  networking.firewall.allowedTCPPorts = map (n: (lib.getAttr n instances).webuiPort) instanceNames;

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
