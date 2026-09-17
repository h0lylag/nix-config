# Generated on turf with `nixos-generate-config --no-filesystems`.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "virtio_blk"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.kernelParams = [
    "console=tty1"
    "console=ttyS0,115200n8"
  ];
  boot.loader.grub.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
