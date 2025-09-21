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
              size = "1G";
              type = "EF00";
              content = {
                type = "mdraid";
                name = "boot";
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
              size = "1G";
              type = "EF00";
              content = {
                type = "mdraid";
                name = "boot";
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

    mdadm = {
      boot = {
        type = "mdadm";
        level = 1; # RAID1 mirror
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
          mountOptions = [ "umask=0077" ];
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
        "root" = {
          type = "zfs_fs";
          options = {
            canmount = "noauto";
            mountpoint = "legacy";
          };
          mountpoint = "/";
        };
        "nix" = {
          type = "zfs_fs";
          options = {
            mountpoint = "legacy";
          };
          mountpoint = "/nix";
        };
        "home" = {
          type = "zfs_fs";
          options = {
            mountpoint = "legacy";
          };
          mountpoint = "/home";
        };
        "var-log" = {
          type = "zfs_fs";
          options = {
            mountpoint = "legacy";
          };
          mountpoint = "/var/log";
        };
      };
    };
  };
}
