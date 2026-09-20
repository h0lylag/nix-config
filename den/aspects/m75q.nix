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
        hardware.cpu.amd.ryzen-smu.enable = lib.mkDefault true;

        boot.loader.systemd-boot = {
          enable = lib.mkDefault true;
        };
        boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

        hardware.enableRedistributableFirmware = lib.mkDefault true;

        hardware.graphics = {
          enable = lib.mkDefault true;
          enable32Bit = lib.mkDefault true;
        };

        powerManagement.enable = lib.mkDefault false;
        services.xserver.desktopManager.xfce.enableScreensaver = lib.mkDefault false;
        services.xserver.serverFlagsSection = lib.mkDefault ''
          Option "BlankTime" "0"
          Option "StandbyTime" "0"
          Option "SuspendTime" "0"
          Option "OffTime" "0"
        '';

        services.logind.settings.Login = {
          IdleAction = lib.mkDefault "ignore";
          IdleActionSec = lib.mkDefault "infinity";
          HandlePowerKey = lib.mkDefault "ignore";
          HandleSuspendKey = lib.mkDefault "ignore";
          HandleHibernateKey = lib.mkDefault "ignore";
          HandleLidSwitch = lib.mkDefault "ignore";
          HandleLidSwitchExternalPower = lib.mkDefault "ignore";
          HandleLidSwitchDocked = lib.mkDefault "ignore";
        };

        systemd.sleep.settings.Sleep = {
          AllowSuspend = false;
          AllowHibernation = false;
          AllowHybridSleep = false;
          AllowSuspendThenHibernate = false;
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

        systemd.services.rustdesk = {
          description = "RustDesk remote desktop service";
          wantedBy = [ "multi-user.target" ];
          requires = [ "network.target" ];
          after = [ "systemd-user-sessions.service" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.rustdesk-flutter}/bin/rustdesk --service";
            ExecStop = "${pkgs.procps}/bin/pkill -f 'rustdesk --'";
            PIDFile = "/run/rustdesk.pid";
            User = "root";
            LimitNOFILE = 100000;
            KillMode = "mixed";
            TimeoutStopSec = 30;
            Restart = "on-failure";
            Environment = [
              "PATH=/run/wrappers/bin:/run/current-system/sw/bin"
              "PULSE_LATENCY_MSEC=60"
              "PIPEWIRE_LATENCY=1024/48000"
            ];
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
