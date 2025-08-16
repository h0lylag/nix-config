{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.minecraft-main;
in
{
  options.services.minecraft-main = {
    enable = lib.mkEnableOption "Minecraft main server";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall ports for Minecraft server";
    };

    gamePort = lib.mkOption {
      type = lib.types.port;
      default = 25565;
      description = "Minecraft game port";
    };

    voiceChatPort = lib.mkOption {
      type = lib.types.port;
      default = 24454;
      description = "Minecraft voice chat port (UDP)";
    };
  };

  config = lib.mkIf cfg.enable {
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

    # Firewall configuration
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.gamePort ];
      allowedUDPPorts = [ cfg.voiceChatPort ];
    };

  };
}
