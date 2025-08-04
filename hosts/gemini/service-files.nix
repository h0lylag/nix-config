{
  config,
  pkgs,
  lib,
  ...
}:

let
  libstdcppPath = "${pkgs.stdenv.cc.cc.lib}/lib";
  discord-relay = pkgs.callPackage ../../pkgs/discord-relay/default.nix { };
in

{
  # Create discord-relay user
  users.users.discord-relay = {
    isSystemUser = true;
    group = "discord-relay";
    home = "/var/discord-relay";
    createHome = false;
    description = "Discord Relay Bot user";
  };

  users.groups.discord-relay = { };

  # Ensure directories exist with correct permissions
  systemd.tmpfiles.rules = [
    "d /etc/discord-relay 0755 root root -"
    "d /var/discord-relay 0755 discord-relay discord-relay -"
    "d /var/discord-relay/attachment_cache 0755 discord-relay discord-relay -"
    "d /var/log/discord-relay 0755 discord-relay discord-relay -"
  ];

  # Allow nginx to access discord-relay logs
  systemd.services.nginx.serviceConfig.ReadWritePaths = [ "/var/log/discord-relay/" ];

  systemd.services.discord-relay = {
    description = "Discord Relay Bot";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${discord-relay}/bin/discord-relay";
      WorkingDirectory = "/var/discord-relay";
      Environment = [
        "LD_LIBRARY_PATH=${libstdcppPath}"
      ];
      Restart = "always";
      RestartSec = 15;
      StandardOutput = "journal";
      StandardError = "journal";
      User = "discord-relay";
      Group = "discord-relay";
    };
  };

  systemd.services.overseer = {
    description = "Overseer Discord Bot";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "/opt/overseer/result/bin/overseer";
      WorkingDirectory = "/opt/overseer";
      Environment = "LD_LIBRARY_PATH=${libstdcppPath}";
      Restart = "always";
      RestartSec = 15;
      StandardOutput = "journal";
      StandardError = "journal";
      User = "chris";
    };
  };

  systemd.services.diamond-boys = {
    description = "Diamond Boys Bot";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python3}/bin/python -u /opt/diamond_boys/diamond-boys.py";
      WorkingDirectory = "/opt/diamond_boys";
      Restart = "always";
      RestartSec = 5;
      StandardOutput = "journal";
      StandardError = "journal";
      User = "chris";
    };
  };

  #  systemd.services.minecraft-prominence = {
  #    description = "Minecraft Server - Prominence II modpack";
  #    after = [ "network.target" ];
  #    wantedBy = [ "multi-user.target" ];

  #    serviceConfig = {
  #      Type = "simple";
  #      WorkingDirectory = "/home/minecraft/servers/Prominence_II";
  #      ExecStart = "/home/minecraft/servers/Prominence_II/start.sh";
  #      User = "minecraft";
  #      Restart = "on-failure";
  #      RestartSec = 5;

  #      Environment = [
  #        "LD_LIBRARY_PATH=${pkgs.udev}/lib"
  #        "PATH=${lib.makeBinPath [ pkgs.temurin-bin-17 pkgs.coreutils pkgs.bash ]}"
  #      ];
  #    };
  #  };

  systemd.services.minecraft-main = {
    description = "Minecraft Server - Main Instance";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = "/home/minecraft/servers/main";
      ExecStart = "${pkgs.runtimeShell} -c ${
        lib.escapeShellArg (
          lib.concatStringsSep " " [
            "${pkgs.temurin-bin-21}/bin/java"
            "-Xms8G"
            "-Xmx12G"
            "-XX:+AlwaysPreTouch"
            "-XX:+DisableExplicitGC"
            "-XX:+ParallelRefProcEnabled"
            "-XX:+PerfDisableSharedMem"
            "-XX:+UnlockExperimentalVMOptions"
            "-XX:+UseG1GC"
            "-XX:G1HeapRegionSize=8M"
            "-XX:G1HeapWastePercent=5"
            "-XX:G1MaxNewSizePercent=40"
            "-XX:G1MixedGCCountTarget=4"
            "-XX:G1MixedGCLiveThresholdPercent=90"
            "-XX:G1NewSizePercent=30"
            "-XX:G1RSetUpdatingPauseTimePercent=5"
            "-XX:G1ReservePercent=20"
            "-XX:InitiatingHeapOccupancyPercent=15"
            "-XX:MaxGCPauseMillis=200"
            "-XX:MaxTenuringThreshold=1"
            "-XX:SurvivorRatio=32"
            "-Dusing.aikars.flags=https://mcflags.emc.gs"
            "-Daikars.new.flags=true"
            "-jar"
            "/home/minecraft/servers/main/fabric-server-mc.1.21.4-loader.0.16.14-launcher.1.0.3.jar"
            "nogui"
          ]
        )
      }";
      User = "minecraft";
      Restart = "on-failure";
      RestartSec = 5;

      Environment = [
        "LD_LIBRARY_PATH=${pkgs.udev}/lib"
        "PATH=${
          lib.makeBinPath [
            pkgs.temurin-bin-21
            pkgs.coreutils
          ]
        }"
      ];
    };
  };

}
