{ den, ... }:
{
  den.aspects.m75q = {
    includes = [
      den.aspects.base
      den.aspects.common
      den.aspects.pipewire
      den.aspects.xfce
      den.aspects.gaming
    ];

    nixos =
      {
        lib,
        pkgs,
        ...
      }:
      {
        boot.loader.systemd-boot = {
          enable = lib.mkDefault true;
        };
        boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

        hardware.enableRedistributableFirmware = lib.mkDefault true;

        hardware.graphics = {
          enable = lib.mkDefault true;
          enable32Bit = lib.mkDefault true;
        };

        networking.useDHCP = lib.mkDefault false;
        networking.interfaces.enp2s0f0.useDHCP = lib.mkDefault false;
        networking.defaultGateway = {
          address = lib.mkDefault "10.1.1.1";
          interface = lib.mkDefault "enp2s0f0";
        };
        networking.nameservers = lib.mkDefault [
          "10.1.1.8"
          "1.1.1.1"
          "8.8.8.8"
        ];

        services.tailscale.extraSetFlags = lib.mkDefault [
          "--exit-node=turf"
          "--exit-node-allow-lan-access=true"
        ];

        swapDevices = [
          {
            device = "/var/lib/swapfile";
            size = 16 * 1024;
            priority = 10;
          }
        ];
        zramSwap = {
          enable = lib.mkDefault true;
          algorithm = lib.mkDefault "zstd";
          memoryPercent = lib.mkDefault 50;
          priority = lib.mkDefault 100;
        };

        boot.kernel.sysctl = {
          "vm.swappiness" = lib.mkDefault 100;
          "vm.page-cluster" = lib.mkDefault 0;
        };
        systemd.oomd.enable = lib.mkDefault true;

        systemd.services.ryzenadj = {
          description = "Set M75q APU power limit to 20w";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.mkDefault "${pkgs.ryzenadj}/bin/ryzenadj --stapm-limit=20000 --fast-limit=20000 --slow-limit=20000";
          };
        };

        services.sunshine = {
          enable = lib.mkDefault true;
          autoStart = lib.mkDefault true;
          openFirewall = lib.mkDefault false;
        };

        environment.systemPackages = with pkgs; [
          ryzenadj
          firefox
          bitwarden-desktop
          trayscale
        ];

      };
  };
}
