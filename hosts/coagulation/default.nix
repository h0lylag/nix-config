# coagulation - physical master home server
{ pkgs, lib, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./containers/default.nix
    ./libvirt/default.nix
    ../../profiles/base.nix
    ../../features/tailscale.nix
  ];

  boot = {
    kernelParams = [
      # attempt to set compatibility for my ancient KVM
      "vga=791"

      # enable iommu for virtualization
      "intel_iommu=on"
      "iommu=pt"

      # isolate nvidia P620 (Video + Audio)
      "vfio-pci.ids=10de:1cb6,10de:0fb9"
    ];

    supportedFilesystems = [ "zfs" ];

    # Force VFIO modules to load at the very beginning of the boot process
    initrd = {
      systemd.enable = true;
      kernelModules = [
        "nvme"
        "vfio_pci"
        "vfio"
        "vfio_iommu_type1"
      ];
    };

    # blacklist all host nvidia drivers
    blacklistedKernelModules = [
      "nvidia"
      "nouveau"
      "nvidia_drm"
      "nvidia_modeset"
    ];

    # enable zfs pools
    zfs = {
      extraPools = [
        "nvme-pool"
        "hdd-pool"
      ];
    };

    # enable systemd-boot loader
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

  # enable networking
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
      allowedTCPPortRanges = [
        {
          from = 5900;
          to = 5910;
        }
      ];
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
  users.users.chris.extraGroups = [
    "media"
    "libvirtd"
  ];

  systemd.tmpfiles.rules = [
    "z /mnt/hdd-pool/main        2775  chris          media     -  -"
    "z /mnt/nvme-pool/scratch    2775  chris          media     -  -"
    "d /var/lib/libvirt/images   0711  root           root      -  -"
    "z /var/lib/libvirt/images   0755  qemu-libvirtd  libvirtd  -  -"
  ];

  # Enable root password login (Temporary - Change password immediately with 'passwd')
  users.users.root.initialPassword = "root";
  services.openssh.settings.PermitRootLogin = lib.mkForce "yes";

  system.stateVersion = "25.11";
}
