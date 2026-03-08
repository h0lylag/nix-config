# warlock - Oracle Cloud free tier VM
# x86_64, UEFI, single disk
{ pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../features/tailscale.nix
  ];

  networking = {
    hostName = "warlock";
    useDHCP = false;
    interfaces.ens3 = {
      useDHCP = true;
      mtu = 9000;
    };
    firewall.allowedTCPPorts = [ 22 ];
  };

  services.openssh.enable = true;

  swapDevices = [
    {
      device = "/swapfile";
      size = 16384;
    }
  ];

  zramSwap = {
    enable = true;
  };

  programs.java.enable = lib.mkForce false;

  system.stateVersion = "25.11";
}
