# 5teak - general-purpose NixOS container
{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
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
          ./services/postgresql.nix
        ];
        _module.args.nixpkgs-unstable = nixpkgs-unstable;

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
