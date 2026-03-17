# imgcat - container for imgcat hosting website
{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
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
        imports = [ ../container-base.nix ];
        _module.args.nixpkgs-unstable = nixpkgs-unstable;

        networking.interfaces.eth0.useDHCP = false;
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.16";
            prefixLength = 24;
          }
        ];

        networking.firewall.allowedTCPPorts = [ ];
      };
  };
}
