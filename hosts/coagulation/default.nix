# coagulation - IN TESTING - Replacement for proxmox home server
# ZFS-based VM with disko disk management and nixos-containers
{ pkgs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./containers/default.nix
    ../../profiles/base.nix
    ../../features/tailscale.nix
  ];

  # Essential ZFS support
  boot = {
    kernelParams = [
      "vga=791"
    ];
    supportedFilesystems = [ "zfs" ];

    loader = {
      systemd-boot = {
        enable = true;
        # Sync the primary ESP to the secondary ESP whenever the bootloader is updated
        extraInstallCommands = ''
          echo "[mirror-esp] Syncing /boot → /boot1 ..."
          ${pkgs.rsync}/bin/rsync -a --delete /boot/ /boot1/
        '';
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };

  networking = {
    hostName = "coagulation";
    hostId = "6cfe8ce5";
    enableIPv6 = false;
    useNetworkd = true;
    useDHCP = false;

    # Bridge configuration for containers
    bridges.br0.interfaces = [ "ens18" ];

    interfaces = {
      ens18.useDHCP = false; # Enslaved to bridge, no IP
      br0 = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "10.1.1.50";
            prefixLength = 24;
          }
        ];
      };
    };

    defaultGateway = {
      address = "10.1.1.1";
      interface = "br0";
    };

    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
      "10.1.1.1"
    ];

    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
      allowedUDPPorts = [ ];
    };
  };

  # ZFS main hdd-pool mount point
  #fileSystems."/mnt/hdd-pool/main" = {
  #  device = "hdd-pool/main";
  #  fsType = "zfs";
  #  neededForBoot = false;
  #};

  services = {
    zfs.autoScrub = {
      enable = true;
      interval = "Sun, 04:00";
    };

    openssh.enable = true;
  };

  system.stateVersion = "25.05";
}
