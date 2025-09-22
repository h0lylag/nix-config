{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./containers.nix
    ../../modules/common.nix
    ../../modules/tailscale.nix
  ];

  # Basic networking configuration
  networking.hostName = "beavercreek";
  networking.hostId = "7a3d39c7"; # Required for ZFS. Ensures when using ZFS that a pool isn't imported accidentally on a wrong machine.
  networking.enableIPv6 = false;

  # Host networking (bridge br0 with static IP)
  networking.useNetworkd = true; # Use systemd-networkd for interface management
  networking.useDHCP = false; # No dhcpcd on host interfaces

  # Create bridge and enslave physical NIC
  networking.bridges.br0.interfaces = [ "ens18" ];

  # Interface assignments
  networking.interfaces.ens18.useDHCP = false; # enslaved, no IP
  networking.interfaces.br0 = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = "10.1.1.50";
        prefixLength = 24;
      }
    ];
  };

  # Default gateway and DNS
  networking.defaultGateway = {
    address = "10.1.1.1";
    interface = "br0";
  };
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
    "10.1.1.1"
  ];

  # ZFS configuration
  boot.kernelPackages = pkgs.linuxPackages; # Use default stable kernel
  boot.supportedFilesystems = [ "zfs" ];
  services.zfs.autoScrub.enable = true;

  # UEFI bootloader configuration
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;

  # Mirror ESP partitions - sync /boot to /boot1 after system rebuilds
  system.activationScripts.mirrorESP = {
    text = ''
      set -eu
      if mountpoint -q /boot1; then
        echo "[mirror-esp] Syncing /boot → /boot1 ..."
        ${pkgs.rsync}/bin/rsync -aH --delete /boot/ /boot1/
        sync
      else
        echo "[mirror-esp] /boot1 not mounted; skipping"
      fi
    '';
    deps = [ ];
  };

  # Networking specifics (bridge and IP are configured in containers.nix)

  # Enable SSH for remote access
  services.openssh.enable = true;

  # Firewall Rules
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
  ];
  networking.firewall.allowedUDPPorts = [ ];

  system.stateVersion = "25.05";
}
