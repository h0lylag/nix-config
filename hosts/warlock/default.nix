# warlock - Oracle Cloud free tier VM
# x86_64, UEFI, single disk
{ pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    #../../profiles/common.nix
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

  # Uncomment when common.nix is enabled:
  # programs.java.enable = lib.mkForce false;
  # programs.nix-ld.enable = lib.mkForce false;

  system.stateVersion = "25.11";
}
