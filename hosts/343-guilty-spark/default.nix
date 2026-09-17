# 343-guilty-spark - workstation dual-boots with Windows.
{ den, ... }:
{
  den.hosts.x86_64-linux."343-guilty-spark".users.chris.classes = [ "homeManager" ];

  den.aspects."343-guilty-spark" = {
    includes = [
      den.aspects.nixcord
      den.aspects.workstation
      den.aspects.gaming
    ];

    nixos.imports = [
      (
        { pkgs, ... }:
        {
          imports = [ ./hardware-configuration.nix ];

          # No whole-disk Disko layout: partitions 1–4 belong to Windows.
          # Keep the Windows EFI partition untouched. NixOS uses its own ESP.
          boot.loader = {
            efi = {
              canTouchEfiVariables = true;
              efiSysMountPoint = "/boot";
            };
            grub = {
              enable = true;
              configurationLimit = 5;
              device = "nodev";
              efiSupport = true;
              useOSProber = true;
              extraEntries = ''
                menuentry "Windows Boot Manager" {
                  insmod part_gpt
                  insmod fat
                  search --no-floppy --fs-uuid --set=root C69D-9304
                  chainloader /EFI/Microsoft/Boot/bootmgfw.efi
                }
              '';
            };
          };

          hardware.enableRedistributableFirmware = true;

          # Sunshine host for streaming this desktop to Moonlight clients.
          # CAP_SYS_ADMIN lets Sunshine use DRM/KMS capture under Wayland.
          services.sunshine = {
            enable = true;
            capSysAdmin = true;
            # tailscale0 is already trusted by the base firewall aspect.
            openFirewall = false;
          };

          # This is a mains-powered workstation: keep the CPU in its
          # highest-performance governor and prevent every suspend path.
          powerManagement.cpuFreqGovernor = "performance";

          services.power-profiles-daemon.enable = true;

          systemd.services.power-profile-performance = {
            description = "Select the performance power profile";
            wantedBy = [ "multi-user.target" ];
            wants = [ "power-profiles-daemon.service" ];
            after = [ "power-profiles-daemon.service" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
              RemainAfterExit = true;
            };
          };

          services.logind.settings.Login = {
            HandlePowerKey = "ignore";
            HandlePowerKeyLongPress = "ignore";
            HandleSuspendKey = "ignore";
            HandleSuspendKeyLongPress = "ignore";
            HandleHibernateKey = "ignore";
            HandleHibernateKeyLongPress = "ignore";
            HandleLidSwitch = "ignore";
            HandleLidSwitchExternalPower = "ignore";
            HandleLidSwitchDocked = "ignore";
            IdleAction = "ignore";
            IdleActionSec = "infinity";
          };

          systemd.sleep.settings.Sleep = {
            AllowSuspend = false;
            AllowHibernation = false;
            AllowHybridSleep = false;
            AllowSuspendThenHibernate = false;
          };

          zramSwap = {
            enable = true;
            algorithm = "zstd";
            memoryPercent = 50;
            priority = 100;
          };

          swapDevices = [
            {
              device = "/var/lib/swapfile";
              size = 16384;
            }
          ];

          system.stateVersion = "26.05";
        }
      )
    ];
  };
}
