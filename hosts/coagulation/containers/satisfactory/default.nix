# Satisfactory - dedicated server container
{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
  ...
}:

{
  containers.satisfactory = {
    autoStart = true;
    enableTun = true;
    privateNetwork = true;
    hostBridge = "br0";

    config =
      { config, pkgs, ... }:
      {
        imports = [
          ../container-base.nix
          ../../../../modules/satisfactory.nix
        ];

        _module.args.nixpkgs-unstable = nixpkgs-unstable;
        nixpkgs.config.allowUnfree = true;

        networking.interfaces.eth0.useDHCP = false;
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.17";
            prefixLength = 24;
          }
        ];

        services.satisfactory = {
          enable = true;
          openFirewall = true;
        };
      };
  };
}
