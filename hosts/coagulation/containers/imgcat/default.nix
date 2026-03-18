# imgcat - container for imgcat hosting website
{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
  sops-nix,
  ...
}:

{
  boot.enableContainers = true;

  containers.imgcat = {
    autoStart = true;
    enableTun = true;

    privateNetwork = true;
    hostBridge = "br0";

    config =
      { config, pkgs, ... }:

      {
        imports = [
          ../container-base.nix
          sops-nix.nixosModules.sops
          ./services/postgres.nix
          ./services/imgcat.nix
          ./services/nginx.nix
        ];
        _module.args.nixpkgs-unstable = nixpkgs-unstable;

        sops.age.generateKey = true;
        sops.age.keyFile = "/var/lib/sops-nix/key.txt";

        networking.interfaces.eth0.useDHCP = false;
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.16";
            prefixLength = 24;
          }
        ];

        networking.firewall.allowedTCPPorts = [ 80 ];

        systemd.tmpfiles.rules = [
          "d /srv/www              0755 root   root   -"
          "d /srv/www/imgcat       0755 imgcat imgcat -"
          "d /srv/www/imgcat/static 0755 imgcat imgcat -"
          "d /srv/www/imgcat/media  0755 imgcat imgcat -"
        ];

        environment.systemPackages = [
          (pkgs.writeShellScriptBin "imgcat-manage" ''
            set -a
            source /run/secrets/imgcat-env
            set +a
            exec runuser -u imgcat -- ${
              pkgs.unstable.callPackage ../../../../pkgs/imgcat-django/default.nix { }
            }/bin/imgcat-manage "$@"
          '')
        ];

        # imgcat service user — matches the PostgreSQL role for peer auth
        users.users.imgcat = {
          isSystemUser = true;
          group = "imgcat";
          description = "imgcat Django service user";
        };
        users.groups.imgcat = { };
      };
  };
}
