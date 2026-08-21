{ pkgs, ... }:

let
  smartmon-helper = pkgs.callPackage ../../../pkgs/smartmon-helper/package.nix { };
in
{
  systemd.services.smartmon-helper = {
    description = "Read-only smartctl snapshot";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "users";
      UMask = "0137";
      ExecStart = "${smartmon-helper}/bin/smartmon-helper --smartctl ${pkgs.smartmontools}/bin/smartctl --output /var/lib/smartmon-helper/snapshot.json";
      StateDirectory = "smartmon-helper";
      StateDirectoryMode = "0750";
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      PrivateTmp = true;
    };
  };

  systemd.timers.smartmon-helper = {
    description = "Periodic read-only SMART snapshot";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/15";
      Persistent = true;
      Unit = "smartmon-helper.service";
    };
  };
}
