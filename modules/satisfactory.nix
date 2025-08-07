{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkIf
    mkOption
    mkEnableOption
    types
    optionalString
    ;
  cfg = config.services.satisfactory;
  appId = 1690800; # Steam App ID
in
{
  options.services.satisfactory = {
    enable = mkEnableOption "Satisfactory Dedicated Server";
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/satisfactory";
      description = "Base data directory (will contain 'server').";
    };
    user = mkOption {
      type = types.str;
      default = "satisfactory";
      description = "System user.";
    };
    group = mkOption {
      type = types.str;
      default = "satisfactory";
      description = "System group.";
    };
    portGame = mkOption {
      type = types.port;
      default = 7777;
      description = "Primary game port (-Port). Used for UDP game traffic and TCP HTTPS API.";
    };
    portApi = mkOption {
      type = types.port;
      default = 8888;
      description = "HTTPS API TCP port (required since Patch 1.1.0.0).";
    };
    experimental = mkOption {
      type = types.bool;
      default = false;
      description = "Use experimental branch.";
    };
    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open required TCP/UDP ports automatically.";
    };
    extraArgs = mkOption {
      type = types.str;
      default = "";
      description = "Extra args for FactoryServer.sh.";
    };
    validate = mkOption {
      type = types.bool;
      default = true;
      description = "Run steamcmd validate on update.";
    };
  };

  config = mkIf cfg.enable {
    users.groups.${cfg.group} = { };
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/server 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Open the correct ports for modern Satisfactory versions
    networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall [
      cfg.portGame
    ];
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [
      cfg.portGame # TCP used for HTTPS API on primary port
      cfg.portApi # Additional/required HTTPS API port (>= 1.1)
    ];

    environment.systemPackages = [ pkgs.steamcmd ];

    systemd.services.satisfactory = {
      description = "Satisfactory Dedicated Server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = "${cfg.dataDir}/server";
        StateDirectory = "satisfactory/server"; # uses systemd DynamicUser style dir mgmt
        KillSignal = "SIGINT";
        TimeoutStopSec = 60;
        Restart = "on-failure";
        RestartSec = 5;
        ExecStartPre =
          let
            betaArg = optionalString cfg.experimental " -beta experimental";
            validateArg = optionalString cfg.validate " validate";
          in
          ''
            ${pkgs.steamcmd}/bin/steamcmd \
              +@sSteamCmdForcePlatformType linux \
              +force_install_dir ${cfg.dataDir}/server \
              +login anonymous \
              +app_update ${toString appId}${betaArg}${validateArg} \
              +quit
          '';
        ExecStart = ''${cfg.dataDir}/server/FactoryServer.sh -unattended -log -Port=${toString cfg.portGame} ${cfg.extraArgs}'';
      };
    };
  };
}
