# Satisfactory - dedicated server container
{
  config,
  pkgs,
  lib,
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
          ../../../../modules/satisfactory.nix
        ];
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
