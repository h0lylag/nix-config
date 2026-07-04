# backwash - Thinkpad x230 laptop
{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../profiles/common.nix
    ../../modules/coagulation-builder.nix
    ../../profiles/workstation.nix
    ../../profiles/gaming.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "backwash";

  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];

  environment.systemPackages = with pkgs; [
    rustdesk-flutter
  ];

  system.stateVersion = "25.11";
}
