# minecraft - Fabric Minecraft server container
{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
  nix-minecraft,
  sops-nix,
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
          ../base.nix
          sops-nix.nixosModules.sops
          nix-minecraft.nixosModules.minecraft-servers
          ./services/minecraft.nix
        ];

        nixpkgs.overlays = [ nix-minecraft.overlay ];
        nixpkgs.config.allowUnfree = true;
        _module.args.nixpkgs-unstable = nixpkgs-unstable;

        sops.age.generateKey = true;
        sops.age.keyFile = "/var/lib/sops-nix/key.txt";

        networking.interfaces.eth0.useDHCP = false;
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.15";
            prefixLength = 24;
          }
        ];

        networking.firewall.allowedTCPPorts = [
          25565 # Minecraft
          25575 # RCON
        ];
      };
  };
}
