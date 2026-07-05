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
          ./services/redis.nix
          ./services/prism-django.nix
          ./services/nginx.nix
          ./services/discord-relay.nix
          ./services/steak-bot.nix
        ];
        _module.args.nixpkgs-unstable = nixpkgs-unstable;

        sops.age.generateKey = true;
        sops.age.keyFile = "/var/lib/sops-nix/key.txt";

        environment.systemPackages = [ pkgs.age ];

        # Temporary migration access. Remove after 5teak service cutover.
        services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";
        users.users.root.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWU3a+HOcu4woQiuMoCSxrW8g916Z9P05DW8o7cGysH chris@relic"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFB1tzcZzr4LNtG/8uQZ8zTV9QkcmWSL3NGLgmE+oP1D chris@midship"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGgptHWisSxEzg5hSPIN+Rh8M1tWMEgNED0QOvHmWLOy root@midship"
        ];

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
