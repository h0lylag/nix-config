# warlock - Oracle Cloud free tier VM
# Stable server configuration
{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../profiles/base.nix
    ../../features/tailscale.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = "warlock";
    interfaces.ens3.useDHCP = true; # Oracle Cloud uses dhcp on ens3
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
      allowedUDPPorts = [ ];
    };
  };

  services.openssh = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [ ];

  system.stateVersion = "24.11";
}
