# warlock - Oracle Cloud free tier VM
# x86_64, UEFI, single disk
{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../profiles/base.nix
    ../../features/tailscale.nix
  ];

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };

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

  zramSwap = {
    enable = true;
  };

  system.stateVersion = "25.11";
}
