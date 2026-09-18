{ den, inputs, ... }:
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
        config,
        lib,
        pkgs,
        ...
      }:
      {
        boot.extraModulePackages = [
          config.boot.kernelPackages.ryzen-smu
        ];
        boot.kernelModules = [
          "ryzen_smu"
        ];

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

        nixpkgs.overlays = [
          (final: prev: {
            rustdesk-flutter =
              inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.rustdesk-flutter;
          })
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

        systemd.services.rustdesk = {
          description = "RustDesk remote desktop service";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [
            "network-online.target"
            "systemd-user-sessions.service"
          ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.rustdesk-flutter}/bin/rustdesk --service";
            ExecStop = "${pkgs.procps}/bin/pkill -f 'rustdesk --'";
            User = "root";
            LimitNOFILE = 100000;
            KillMode = "mixed";
            TimeoutStopSec = 30;
            Restart = "on-failure";
          };
        };

        environment.etc."xdg/autostart/rustdesk-tray.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=RustDesk
          Comment=RustDesk tray client
          Exec=${pkgs.rustdesk-flutter}/bin/rustdesk --tray
          Icon=rustdesk
          Terminal=false
          NoDisplay=true
          StartupNotify=false
          X-GNOME-Autostart-enabled=true
          OnlyShowIn=XFCE;
        '';

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
          rustdesk-flutter
        ];

      };
  };
}
