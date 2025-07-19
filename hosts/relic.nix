{ config, pkgs, ... }:

{
  imports = [
    ../hardware/relic.nix
    ../modules/users.nix
    ../modules/desktop.nix
    ../modules/system-packages.nix
    ../modules/tailscale.nix
    ../modules/fonts.nix
  ];

  # Bootloader and kernel
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ASUS X670E-F bullshit 'fixes'
  boot.blacklistedKernelModules = [ "mt7921e" ];
  boot.kernelParams = [
    "pcie_port_pm=off"
    "pcie_aspm.policy=performance"
  ];

  # Flake shit
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;

  # Host/network basics
  networking.hostName = "relic";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # Desktop environment
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Printing
  services.printing.enable = true;

  # Pipewire audio and real-time support
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Firewall example
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # networking.firewall.enable = false;

  # Don't fuck with it
  system.stateVersion = "25.05";
}
