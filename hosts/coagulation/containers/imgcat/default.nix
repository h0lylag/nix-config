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

        networking.firewall.allowedTCPPorts = [ ];

        # imgcat service user — matches the PostgreSQL role for peer auth
        users.users.imgcat = {
          isSystemUser = true;
          group = "imgcat";
          description = "imgcat Django service user";
        };
        users.groups.imgcat = { };
  };
}
