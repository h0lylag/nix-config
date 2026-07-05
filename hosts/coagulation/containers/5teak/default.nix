# 5teak - general-purpose NixOS container
{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
  sops-nix,
  ...
}:

{
  # Enable container support
  boot.enableContainers = true;

  containers."5teak" = {
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
          ./services/postgresql.nix
        ];
        _module.args.nixpkgs-unstable = nixpkgs-unstable;

        sops.age.generateKey = true;
        sops.age.keyFile = "/var/lib/sops-nix/key.txt";

        environment.systemPackages = [ pkgs.age ];

        system.activationScripts.generate5teakSopsAgeKey = lib.stringAfter [ "specialfs" ] ''
          if [ ! -f /var/lib/sops-nix/key.txt ]; then
            echo "generating 5teak sops age key..."
            install -d -m 0700 /var/lib/sops-nix
            ${pkgs.age}/bin/age-keygen -o /var/lib/sops-nix/key.txt
          fi
        '';

        networking.interfaces.eth0.useDHCP = false;
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.18";
            prefixLength = 24;
          }
        ];

        users.users.carter = {
          isNormalUser = true;
          initialPassword = "carter";
          extraGroups = [ "wheel" ];
        };
      };
  };
}
