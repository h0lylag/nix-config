{ config, pkgs, ... }:

{
  imports = [
    ../hardware/relic.nix
    ../modules/common.nix
    ../modules/tailscale.nix
    ../modules/desktop.nix
  ];

  # Bootloader and kernel
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Host/network basics
  networking.hostName = "relic";
  networking.networkmanager.enable = true;

  # ASUS X670E-F bullshit 'fixes' (they dont fix it)
  boot.blacklistedKernelModules = [ "mt7921e" ];
  boot.kernelParams = [
    "pcie_port_pm=off"
    "pcie_aspm.policy=performance"
  ];

  fileSystems."/mnt/hdd-pool/main" = {
    device = "10.1.1.5:/mnt/hdd-pool/main";
    fsType = "nfs";
    options = [
      "rw"
      #"sync"
      #"hard"
      #"intr"
    ];
  };

  fileSystems."/mnt/nvme-pool/scratch" = {
    device = "10.1.1.5:/mnt/nvme-pool/scratch";
    fsType = "nfs";
    options = [
      "rw"
      #"sync"
      #"hard"
      #"intr"
    ];
  };

  # Firewall
  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];

  # Don't fuck with it
  system.stateVersion = "25.05";

}
