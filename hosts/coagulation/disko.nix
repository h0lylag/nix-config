{ ... }:
{
  disko.devices = {
    disk = {
      disk0 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-QEMU_HARDDISK_QM00009";
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
      disk1 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-QEMU_HARDDISK_QM00007";
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
    };

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
            mountpoint = "legacy";
          };
          mountpoint = "/home";
        };
        "nix" = {
          type = "zfs_fs";
          options = {
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
            mountpoint = "legacy";
            recordsize = "16K";
          };
          mountpoint = "/var/log";
        };
      };
    };
  };
}
