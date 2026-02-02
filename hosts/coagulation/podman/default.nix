{ pkgs, ... }:

let
  podmanUser = "podman";
  podmanGroup = "podman";
  podmanHome = "/var/lib/podman";
  podmanRuntime = "/run/podman-runtime";
in
{
  imports = [
    ./airdcpp
    ./cadvisor
    ./netalertx
    ./upload-assistant
  ];

  # Make these available to all imported modules
  _module.args = {
    inherit podmanUser podmanGroup podmanHome;
  };

  # --- Podman Configuration (Standalone) --- #
  virtualisation.containers = {
    enable = true;
    registries.search = [ "docker.io" ];

    storage.settings = {
      storage = {
        driver = "zfs";
        graphroot = podmanHome;
        runroot = podmanRuntime;
      };
      storage.options.zfs = {
        fsname = "nvme-pool/podman";
      };
    };
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  environment.systemPackages = [ pkgs.podman-compose ];

  # --- Rootless Podman User Configuration --- #
  users.groups."${podmanGroup}" = { };

  users.users."${podmanUser}" = {
    isSystemUser = true;
    group = podmanGroup;
    extraGroups = [ "media" ];

    # Ensure the user owns the ZFS dataset area
    home = podmanHome;
    createHome = true;

    subUidRanges = [
      {
        startUid = 100000;
        count = 65536;
      }
    ];
    subGidRanges = [
      {
        startGid = 100000;
        count = 65536;
      }
    ];
  };

  systemd.tmpfiles.rules = [
    # Linger file for boot-start
    "f /var/lib/systemd/linger/${podmanUser} 0644 root root - -"

    # Runtime directory in RAM
    "d ${podmanRuntime} 0700 ${podmanUser} ${podmanGroup} - -"

    # Persistent ZFS paths (Base)
    "d ${podmanHome} 0700 ${podmanUser} ${podmanGroup} - -"
  ];
}
