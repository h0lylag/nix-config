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
      port = 8040;
    };
    movies = {
      port = 8041;
    };
    tv = {
      port = 8042;
    };
    games = {
      port = 8043;
    };
    music = {
      port = 8044;
    };
    private = {
      port = 8099;
    };
  };

  mkTmp = name: ''
    d /var/lib/qbittorrent/${name}/home 0750 ${user} ${group} -
    d /var/log/qbittorrent/${name}      0750 ${user} ${group} -
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
      port = toString (lib.getAttr name instances).port;
      home = "/var/lib/qbittorrent/${name}/home";
      inc = "/var/lib/qbittorrent/${name}/incomplete";
      comp = "/var/lib/qbittorrent/${name}/complete";
      watch = "/var/lib/qbittorrent/${name}/watched";
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

        # Make qBittorrent use XDG under a per-instance HOME
        Environment = [
          "HOME=${home}"
          "XDG_CONFIG_HOME=${home}/.config"
          "XDG_DATA_HOME=${home}/.local/share"
        ];

        # NOTE: No $VARS below — interpolate with Nix so systemd passes literals
        ExecStart = ''
          ${pkgs.qbittorrent-nox}/bin/qbittorrent-nox \
            --webui-port=${port} \
            --save-path=${comp} \
            --temp-path=${inc}
        '';

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
  networking.firewall.allowedTCPPorts = map (n: (lib.getAttr n instances).port) instanceNames;

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
