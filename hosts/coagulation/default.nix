# coagulation - physical master home server
{ pkgs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./containers/default.nix
    ../../profiles/base.nix
    ../../features/tailscale.nix
  ];

  boot = {
    kernelParams = [
      "vga=791"
    ];

    supportedFilesystems = [ "zfs" ];

    initrd = {
      systemd.enable = true;
      kernelModules = [ "nvme" ];
    };

    zfs = {
      extraPools = [
        "nvme-pool"
        "hdd-pool"
      ];
    };

    loader = {
      systemd-boot = {
        enable = true;
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

    bridges.br0.interfaces = [ "eno1" ];

    interfaces = {
      eno1.useDHCP = false;
      br0 = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "10.1.1.5";
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

  fileSystems."/mnt/hdd-pool/main" = {
    device = "hdd-pool/main";
    fsType = "zfs";
    neededForBoot = false;
  };

  services = {
    zfs.autoScrub = {
      enable = true;
      interval = "*-*-01 04:00:00";
    };

    fstrim.enable = true;
    openssh.enable = true;
  };

  users.groups.media.gid = 1300;
  users.users.chris.extraGroups = [ "media" ];

  # Set permissions for media pools
  systemd.tmpfiles.rules = [
    "z /mnt/hdd-pool/main      2775  chris  media  -  -"
    "z /mnt/nvme-pool/scratch  2775  chris  media  -  -"
  ];

  system.stateVersion = "25.11";
}
