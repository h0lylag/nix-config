# Based on read-only inspection of the Ubuntu guest on 2026-09-05.
# /sys/firmware/efi is absent: BIOS boot, despite an existing EFI partition.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
  ];
  boot.kernelParams = [
    "console=tty1"
    "console=ttyS0,115200n8"
  ];
  boot.loader.grub.enable = true;
  # Disko supplies GRUB's disk device from the BIOS boot partition.

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
