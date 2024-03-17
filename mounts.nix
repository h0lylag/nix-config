{ config, lib, pkgs, modulesPath, ... }:

{
  #imports =
  #  [ (modulesPath + "/installer/scan/not-detected.nix")
  #  ];

  fileSystems."/mnt/hdd-pool/main" = {
    device = "10.1.1.5:/mnt/hdd-pool/main";
    fsType = "nfs";
  };

  fileSystems."/mnt/nvme-pool/scratch" = {
    device = "10.1.1.5:/mnt/nvme-pool/scratch";
    fsType = "nfs";
  };

}
