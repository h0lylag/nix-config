{ ... }:

/*
  ZFS Storage Architecture
  ========================

  Topology
  --------
  1. rpool (System):
     - Mirror: 2x SATA SSDs (boot0, boot1)
     - Ashift: 12 (4K sectors)
     - Purpose: OS root, home directories, system logs.

  2. nvme-pool (High Performance):
     - Mirror: 2x NVMe SSDs (nvme0, nvme1)
     - Ashift: 13 (8K sectors, optimized for NVMe NAND)
     - Purpose: VM images, scratch space, high-speed data.

  Tuning & Configuration
  ----------------------
  - Safety Buffer (reserved): 5G-10G datasets with refreservation set to prevent CoW lockups on full pools.
  - Recordsize:
    - Default/System: 128K (ZFS default)
    - /nix: 64K (directory traversal performance)
    - /var/log: 16K (small text appends)
    - /images: 64K (matches typical qcow2 cluster size)
    - /scratch: 1M (sequential large file throughput)
  - Mounting:
    - legacy: Managed via NixOS fileSystems config, precise control.
    - canmount=noauto: Prevents accidental mounting (e.g., during boot or zfs mount -a).

  Disaster Recovery
  -----------------
  # Import pools
  zpool import -f rpool
  zpool import -f nvme-pool

  # Mount critical datasets (example)
  mount -t zfs rpool/root/nixos /mnt
  mount -t zfs -o zfsutil nvme-pool/images /mnt/nvme-pool/images

  # Emergency Space Reclamation
  # If pool is 100% full and refusing writes, temporarily drop reservation:
  zfs set refreservation=none rpool/reserved
  # ... delete files ...
  zfs set refreservation=5G rpool/reserved
*/

{
  disko.devices = {
    disk = {
      # --- System SSDs (SATA Mirror) --- #
      boot0 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_250GB_S3PZNB0JB03916N";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "2G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "nofail"
                  "umask=0077"
                  "noatime"
                ];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
      boot1 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-CT250MX500SSD1_1852E1DFFF85";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "2G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot1";
                mountOptions = [
                  "nofail"
                  "umask=0077"
                  "noatime"
                ];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };

      # --- NVMe Fast Tier (Mirror) --- #
      nvme0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_1TB_S5P2NL0WC00080F";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "nvme-pool";
              };
            };
          };
        };
      };
      nvme1 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_1TB_S5P2NL0WC00081N";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "nvme-pool";
              };
            };
          };
        };
      };
    };

    # --- System Pool (rpool) --- #
    zpool.rpool = {
      type = "zpool";
      mode = "mirror";
      options = {
        ashift = "12";
        autotrim = "on";
        autoreplace = "on";
        cachefile = "none";
      };
      rootFsOptions = {
        mountpoint = "none";
        compression = "zstd";
        atime = "off";
        xattr = "sa";
        acltype = "posixacl";
      };
      datasets = {
        "reserved" = {
          type = "zfs_fs";
          options = {
            mountpoint = "none";
            canmount = "off";
            refreservation = "5G";
          };
        };
        "root" = {
          type = "zfs_fs";
          options = {
            mountpoint = "none";
            canmount = "off";
          };
        };
        "root/nixos" = {
          type = "zfs_fs";
          options = {
            canmount = "noauto";
            mountpoint = "legacy";
          };
          mountpoint = "/";
        };
        "home" = {
          type = "zfs_fs";
          options = {
            canmount = "noauto";
            mountpoint = "legacy";
          };
          mountpoint = "/home";
        };
        "nix" = {
          type = "zfs_fs";
          options = {
            canmount = "noauto";
            mountpoint = "legacy";
            recordsize = "64K";
          };
          mountpoint = "/nix";
        };
        "var" = {
          type = "zfs_fs";
          options = {
            canmount = "off";
            mountpoint = "none";
            xattr = "sa";
            acltype = "posixacl";
          };
        };
        "var/lib" = {
          type = "zfs_fs";
          options = {
            canmount = "off";
            mountpoint = "none";
          };
        };
        "var/log" = {
          type = "zfs_fs";
          options = {
            canmount = "noauto";
            mountpoint = "legacy";
            recordsize = "16K";
          };
          mountpoint = "/var/log";
        };
      };
    };

    # --- NVMe Pool (nvme-pool) --- #
    zpool.nvme-pool = {
      type = "zpool";
      mode = "mirror";
      options = {
        ashift = "13";
        autotrim = "on";
        cachefile = "none";
      };
      rootFsOptions = {
        mountpoint = "none";
        compression = "zstd";
        atime = "off";
        xattr = "sa";
        acltype = "posixacl";
      };
      datasets = {
        "reserved" = {
          type = "zfs_fs";
          options = {
            mountpoint = "none";
            canmount = "off";
            refreservation = "10G";
          };
        };
        "data" = {
          type = "zfs_fs";
          options = {
            canmount = "noauto";
            mountpoint = "legacy";
          };
          mountOptions = [ "nofail" ];
          mountpoint = "/mnt/nvme-pool";
        };
        "images" = {
          type = "zfs_fs";
          options = {
            canmount = "noauto";
            mountpoint = "legacy";
            recordsize = "64K";
          };
          mountOptions = [ "nofail" ];
          mountpoint = "/mnt/nvme-pool/images";
        };
        "containers" = {
          type = "zfs_fs";
          options = {
            canmount = "noauto";
            mountpoint = "legacy";
            recordsize = "64K";
          };
          mountOptions = [ "nofail" ];
          mountpoint = "/var/lib/containers";
        };
        "scratch" = {
          type = "zfs_fs";
          options = {
            canmount = "noauto";
            mountpoint = "legacy";
            recordsize = "1M";
          };
          mountOptions = [ "nofail" ];
          mountpoint = "/mnt/nvme-pool/scratch";
        };

      };
    };
  };
}
