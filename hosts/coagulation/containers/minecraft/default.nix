# minecraft - Fabric Minecraft server container
{
  config,
  pkgs,
  lib,
  nix-minecraft,
  ...
}:

{
  containers.minecraft = {
    autoStart = true;
    enableTun = true;
    privateNetwork = true;
    hostBridge = "br0";

    config =
      { config, pkgs, ... }:
      {
        imports = [
          nix-minecraft.nixosModules.minecraft-servers
          ./services/minecraft.nix
        ];

        nixpkgs.overlays = [ nix-minecraft.overlay ];
        nixpkgs.config.allowUnfree = true;

        networking.interfaces.eth0.useDHCP = false;
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.15";
            prefixLength = 24;
          }
        ];

        networking.firewall.allowedTCPPorts = [ ];
        networking.firewall.allowedUDPPorts = [ ];

      };
  };
}
