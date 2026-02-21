{
  config,
  pkgs,
  lib,
  ...
}:

let
  modLoader = "fabric";
  dataDir = "/var/lib/minecraft";

  # Script to send crash logs to Discord
  crashNotifier = pkgs.writeShellScript "minecraft-crash-notifier" ''
    set -eu

    # Use mail2discord webhook
    WEBHOOK_URL=$(cat /run/secrets/mail2discord-webhook 2>/dev/null || echo "")
    if [ -z "$WEBHOOK_URL" ]; then
      echo "No Discord webhook URL found, skipping notification"
      exit 0
    fi

    # Get the last 50 lines of logs
    LOG_CONTENT=$(${pkgs.systemd}/bin/journalctl -u minecraft-server-${modLoader}.service -n 50 --no-pager || echo "Could not fetch logs")

    # Get crash time
    CRASH_TIME=$(date '+%Y-%m-%d %H:%M:%S %Z')

    # Prepare JSON payload
    ${pkgs.curl}/bin/curl -H "Content-Type: application/json" \
      -d "{\"embeds\":[{\"title\":\"🔥 Minecraft Server Crashed\",\"description\":\"The ${modLoader} server has crashed and is restarting.\",\"color\":15158332,\"fields\":[{\"name\":\"Crash Time\",\"value\":\"$CRASH_TIME\",\"inline\":true},{\"name\":\"Server\",\"value\":\"${modLoader}\",\"inline\":true}],\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\"}]}" \
      "$WEBHOOK_URL" || echo "Failed to send Discord notification"

    # Also send log snippet if it's not too large (truncate if needed)
    if [ ''${#LOG_CONTENT} -lt 1500 ]; then
      LOG_ESCAPED=$(echo "$LOG_CONTENT" | ${pkgs.jq}/bin/jq -Rs .)
      ${pkgs.curl}/bin/curl -H "Content-Type: application/json" \
        -d "{\"content\":\"**Last 50 log lines:**\n\`\`\`\n$LOG_ESCAPED\n\`\`\`\"}" \
        "$WEBHOOK_URL" || true
    fi
  '';
in
{

  # Install mcrcon for server management
  environment = {
    systemPackages = [ pkgs.mcrcon pkgs.nix-modrinth-prefetch ];
    shellAliases = {
      "rcon-minecraft" =
        "mcrcon -H localhost -P 25575 -p $(sudo cat /run/secrets/minecraft-rcon | grep RCON_PASSWORD | cut -d= -f2)";
    };
  };

  # RCON password secret - .env file for use with environmentFile
  sops.secrets.minecraft-rcon = {
    sopsFile = ../../../../../secrets/minecraft-rcon.env;
    format = "dotenv";
    owner = "chris";
    group = "chris";
  };

  # Crash notification service
  systemd.services."minecraft-crash-notify-${modLoader}" = {
    description = "Notify Discord when Minecraft server crashes";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = crashNotifier;
    };
  };

  # Minecraft server systemd configuration
  systemd.services."minecraft-server-${modLoader}" = {
    # Create logs directory before server starts
    preStart = ''
      install -d -m0750 -o minecraft -g minecraft ${dataDir}/${modLoader}/logs
    '';

    serviceConfig = {
      LimitNOFILE = 65535;
      Restart = lib.mkForce "on-failure";
      RestartSec = "5s";
      Nice = -5;
      OOMScoreAdjust = -900;
      MemoryMax = "0";
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 4;
    };

    unitConfig = {
      OnFailure = "minecraft-crash-notify-${modLoader}.service";
    };
  };

  # Allow UDP 24454 port for Simple Voice Mod
  networking.firewall.allowedUDPPorts = [ 24454 ];

  # Minecraft server settings
  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;

    dataDir = dataDir;

    environmentFile = config.sops.secrets.minecraft-rcon.path;
    servers.${modLoader} = {
      enable = true;

      package = pkgs.minecraftServers.fabric-1_21_11.override {
        jre_headless = pkgs.temurin-jre-bin-25;
      };

      jvmOpts = lib.concatStringsSep " " [
        "-Xms8G"
        "-Xmx16G"
        "-XX:+UseZGC"
        "-XX:+ZGenerational"
        "-XX:+ParallelRefProcEnabled"
        "-XX:+AlwaysPreTouch"
        "-XX:+DisableExplicitGC"
        "-XX:+PerfDisableSharedMem"
        "-Xlog:gc*,safepoint:file=${dataDir}/${modLoader}/logs/gc.log:tags,uptime,level:filecount=5,filesize=50m"
      ];

      serverProperties = {
        motd = "h0ly's Minecraft Server";

        difficulty = "hard";
        gamemode = "survival";
        spawn-protection = 5;
        max-players = 20;
        view-distance = 10;
        simulation-distance = 10;
        server-port = 25565;

        enable-rcon = true;
        "rcon.port" = 25575;
        "rcon.password" = "@RCON_PASSWORD@";

        online-mode = true;
        white-list = true;
        enforce-whitelist = true;

        level-seed = "-1034099080";
      };

      symlinks = {
        "ops.json" = {
          value = [
            {
              uuid = "1c7f115f-aa3f-489a-b8d6-20b1ac8ca24c";
              name = "h0lylag";
              level = 4;
              bypassesPlayerLimit = true;
            }
          ];
        };

        "whitelist.json" = {
          value = [
            {
              uuid = "1c7f115f-aa3f-489a-b8d6-20b1ac8ca24c";
              name = "h0lylag";
            }
            {
              uuid = "e944dc63-5103-43ae-be1d-bb020b13cfef";
              name = "kingofhawks";
            }
            {
              uuid = "1a254122-99ba-445c-bc32-5ecca479153b";
              name = "TheRealSeddow";
            }
            {
              uuid = "bf202db1-5517-4639-b5dc-6d308b31140b";
              name = "Signifiedzero";
            }
            {
              uuid = "d84746ce-6009-4ad9-8068-a43f37ede316";
              name = "Kognac";
            }
            {
              uuid = "9b96c2a3-2875-48bc-8677-a70e1309c50f";
              name = "5TEAKBESTCORP";
            }
            {
              uuid = "bd1e0dad-04af-405f-8dfa-55530f95a34e";
              name = "1katte";
            }
            {
              uuid = "b0cc2fa9-f09c-4f14-9b75-f43294ef3a92";
              name = "PNWrose";
            }
            {
              uuid = "b0645e01-6dc4-45b5-a872-58b6fa63ea59";
              name = "gib7_";
            }
            {
              uuid = "3e2cc05c-a21f-4bc7-aad9-97d00433d0e5";
              name = "SignifiedZer0";
            }
            {
              uuid = "9132e28a-1eca-4533-b349-d7294c8c2bf7";
              name = "dizeazes";
            }
            {
              uuid = "5bfb1b16-e5f0-4b51-94bc-dc446543e96d";
              name = "EmoLisaSimpson";
            }
            {
              uuid = "54d220fc-1ad1-4d59-8b62-77ce5bac1139";
              name = "Conorob6";
            }
            {
              uuid = "7804fa55-c7d5-436e-98f6-3977bdca328c";
              name = "Max_Bateman";
            }
          ];
        };

        # Mods will be added later
      };
    };
  };
}
