# Lockout - systemd-nspawn container configuration on coagulation host
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

  # Define lockout container
  containers.lockout = {
    autoStart = true; # Set to autostart
    enableTun = true;

    # Bridge networking - container gets its own MAC and DHCP lease
    privateNetwork = true;
    hostBridge = "br0";

    # Container configuration
    config =
      { config, pkgs, ... }:

      {
        imports = [ ../container-base.nix ];
        _module.args.nixpkgs-unstable = nixpkgs-unstable;

        # Container static IP configuration
        networking.interfaces.eth0.useDHCP = false;
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.10";
            prefixLength = 24;
          }
        ];

        # Additional firewall ports for management if needed (SSH is already in base)
        networking.firewall.allowedTCPPorts = [
          80
          443
        ];
      };
  };
}
