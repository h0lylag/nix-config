# backwash - HP ZBook Firefly 14 G11 A
{ den, ... }:
{
  den.hosts.x86_64-linux.backwash.users.chris.classes = [ "homeManager" ];

  den.aspects.backwash = {
    includes = [
      den.aspects.desktop
      den.aspects.distributed-build-client
    ];

    nixos.imports = [
      (
        { lib, pkgs, ... }:

        {
          imports = [
            ./hardware-configuration.nix
          ];

          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;
          boot.kernelPackages = pkgs.linuxPackages_latest;

          swapDevices = [
            {
              device = "/var/lib/swapfile";
              size = 16 * 1024;
            }
          ];

          zramSwap = {
            enable = true;
            algorithm = "zstd";
            memoryPercent = 50;
            priority = 100;
          };

          boot.kernel.sysctl = {
            "vm.swappiness" = 100;
            "vm.page-cluster" = 0;
          };

          systemd.oomd.enable = true;

          hardware.bluetooth.enable = true;

          services.fprintd.enable = true;

          environment.systemPackages = with pkgs; [
            rustdesk-flutter
          ];

          system.stateVersion = "26.05";
        }
      )
    ];
  };
}
