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
    systemPackages = [
      pkgs.mcrcon
      pkgs.nix-modrinth-prefetch
      pkgs.jq
    ];
    shellAliases = {
      "rcon-minecraft" =
        "mcrcon -H localhost -P 25575 -p $(cat /run/secrets/minecraft-rcon | grep RCON_PASSWORD | cut -d= -f2)";
    };
  };

  # Run minecraft service as chris
  services.minecraft-servers.user = "chris";
  services.minecraft-servers.group = "users";

  # RCON password secret - .env file for use with environmentFile
  sops.secrets.minecraft-rcon = {
    sopsFile = ../../../../../secrets/minecraft-rcon.env;
    format = "dotenv";
    owner = "chris";
    group = "users";
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
      install -d -m0750 -o chris -g users ${dataDir}/${modLoader}/logs
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
        "-Xms16G"
        "-Xmx16G"
        "-XX:+UseZGC"
        "-XX:+ParallelRefProcEnabled"
        "-XX:+AlwaysPreTouch"
        "-XX:+DisableExplicitGC"
        "-XX:+PerfDisableSharedMem"
        "-XX:-ZUncommit"
        "-XX:SoftMaxHeapSize=14G"
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
        level-type = "large_biomes";
        server-port = 25565;

        enable-rcon = true;
        "rcon.port" = 25575;
        "rcon.password" = "@RCON_PASSWORD@";

        online-mode = true;
        white-list = true;
        enforce-whitelist = true;

        level-seed = "h0lyisgay";
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

        mods = pkgs.linkFarmFromDrvs "mods" (
          builtins.attrValues {

            # https://modrinth.com/mod/fallingtree
            FallingTree = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Fb4jn8m6/versions/Hnj3s9Ez/FallingTree-1.21.11-1.21.11.3.jar";
              sha512 = "56b8b86846e65f9e070ee08af1baf0b8871ea5eb233a43961d0f937a6147f039eed44794a6b3661b4748e4da037e40aa48b903936960585b626bc9f5e9e308d9";
            };

            # https://modrinth.com/mod/netherportalfix
            NetherPortalFix = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/nPZr02ET/versions/D79IUl9r/netherportalfix-fabric-1.21.11-21.11.2.jar";
              sha512 = "9e385c30418e1eb80c2f74d1e319ed5bc45a19dfaa8408fba40b8afb6b4b49dc7a7951cb06fc3b4a1679bd818073300df56740ecee8224f47334e8dd6395bb49";
            };

            # https://modrinth.com/datapack/too-expensive-removed
            TooExpensiveRemoved = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/LrtCyjyV/versions/bCSYiaW1/too-expensive-removed-v1.2.5.jar";
              sha512 = "199091876770af5fbd8def9efcaa3ec8336f98760263554560fe2877b510a9bd7c8f515766e19343667a0925c9dc9b53c2b251c8d2048b22ee1ff930ca53de65";
            };

            # https://modrinth.com/datapack/veinminer
            VeinMiner = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/OhduvhIc/versions/SMDUhqTN/veinminer-fabric-2.5.2.jar";
              sha512 = "965d6766b53b81cba52067fd1040a8b7e6410173245b030cb15b8aecde3e78fdf29facfd754fbd27b84f734ea33b7a80bb16691dbdcdbcccba60773fa445d7a0";
            };

            # https://modrinth.com/mod/rightclickharvest
            RightClickHarvest = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Cnejf5xM/versions/MJkjKHul/rightclickharvest-fabric-4.6.1%2B1.21.11.jar";
              sha512 = "7a5937969f0f1659cde27448d67779ceefe30744b7c95313c56271be3abf14def9217776d7abe473269f006f234edc83017062de78fc6ccf4eddf17f201ee829";
            };

            # https://modrinth.com/mod/universal-graves
            UniversalGraves = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/yn9u3ypm/versions/rZeFZ5ip/graves-3.10.2%2B1.21.11.jar";
              sha512 = "62b4e92a9f93585d65a4ef4965472a55f9c180cbc946d4f08ad1f801c59e967a0123b5b3fc6f444504f1088026c0eca65f9d530adee64721ea85ff7c8cc7eca8";
            };

            # https://modrinth.com/mod/better-than-mending
            BetterThanMending = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Lvv4SHrK/versions/wHUk8xSy/BetterThanMending-2.2.5.jar";
              sha512 = "d56acc54075151dfd4ee697a9c6707919385505d32b01ee4b67a7d083c5e8f656c6a51bfac34de011bf0d8455f9fa3fddf81a45f3c36bd19d1a48d868baaa7ef";
            };

            # https://modrinth.com/mod/mobexplosiongriefinggamerule
            MobExplosionGriefingGamerule = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/l9H9JPmo/versions/Nke6FVKQ/mob_explosion_griefing-2.0.0%2B1.21.11.jar";
              sha512 = "1f45e2941b7fa1f91020b9470fadcbf824b4f5fc2b6d51d73e8d510c426f1d147cb52f33d7bf9e7b8a32bf4ca75e40516cb9cc7b71b6ce0699b4feaeeff9d68a";
            };

            # https://modrinth.com/mod/trade-cycling
            TradeCycling = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/qpPoAL6m/versions/gjL3kDvK/trade-cycling-fabric-1.21.11-1.0.20.jar";
              sha512 = "f58df458b9c2d65c7067e514dd38f115c9c54b6321f1c02e7ba7059655ccf1f7763dbfc91e48361404100d4213b5203e0e09b05a5ff605654191ba970980214f";
            };

            # https://modrinth.com/mod/double-doors
            DoubleDoors = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/JrvR9OHr/versions/roVanbyg/doubledoors-1.21.11-7.2.jar";
              sha512 = "8733142b105741e6ed8cf9d4000e6c816159565dcfdc3137ada1dc007898cf0d056cb14a1c324acb27dd3cd68478200018ac75f8b5171b813a578cb167b80e20";
            };

            # https://modrinth.com/mod/axes-are-weapons
            AxesAreWeapons = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/1jvt7RTc/versions/Sm13IZEm/AxesAreWeapons-1.9.5-fabric-1.21.11.jar";
              sha512 = "b954063b8cdbb46040ae37ac6ce5e9e32a7a6817ebef2144d50f5d932b1ef1d58cc5140e12829a47c0497e29ff55c358a8c4d2650df2f5522db602c1ee9a96ac";
            };

            # https://modrinth.com/mod/appleskin
            AppleSkin = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/EsAfCjCV/versions/59ti1rvg/appleskin-fabric-mc1.21.11-3.0.8.jar";
              sha512 = "d32206cb8d6fac7f0b579f7269203135777283e1639ccb68f8605e9f5469b5b54305fd36ba82c64b48b89ae4f1a38501bfb5827284520c3ec622d95edcfa34de";
            };

            # https://modrinth.com/mod/mine-spawners
            MineSpawners = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/7VESbzyX/versions/Wle6zwiu/mine-spawners-1.6.6.jar";
              sha512 = "fe0a63dbd265d0beadc2f5aed43029a464f62ae6e1aa92af53578c33cb66ca6effc4677ee292029d53d9fb523c9bb9bfd74fd6165fb7c06c530c37ea4061b815";
            };

            # https://modrinth.com/mod/crafting-tweaks
            CraftingTweaks = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/DMu0oBKf/versions/Z8BzLi5v/craftingtweaks-fabric-1.21.11-21.11.4.jar";
              sha512 = "6e951ac5c28bd57122c87ec629bab09df31558729003b97c14aacf8290beffbcd7d0ce6cb5c58d70680dab62b9ce5b23b11799656ec2889e5aebbf3632c147fe";
            };

            # https://modrinth.com/mod/fabric-api
            FabricAPI = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/i5tSkVBH/fabric-api-0.141.3%2B1.21.11.jar";
              sha512 = "c20c017e23d6d2774690d0dd774cec84c16bfac5461da2d9345a1cd95eee495b1954333c421e3d1c66186284d24a433f6b0cced8021f62e0bfa617d2384d0471";
            };

            # https://modrinth.com/mod/distanthorizons
            DistantHorizons = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/uCdwusMi/versions/GT3Bm3GN/DistantHorizons-2.4.5-b-1.21.11-fabric-neoforge.jar";
              sha512 = "a9f673fac1f6f554b7394168cbe726f1a15eb2bbef1b65b3c9979853af8de70bf13a457c88ebdc30b955a071d519e86c631cdbf1dd39cdab7c73b9c2d7f165e1";
            };

            # https://modrinth.com/mod/c2me-fabric
            C2ME = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/VSNURh3q/versions/olrVZpJd/c2me-fabric-mc1.21.11-0.3.6.0.0.jar";
              sha512 = "c9b11100572fb71c3080ff11b011467624e8013b9942aade09a5c77eb62b3289667bad70501ddea8f35deb0a5d26884b79f76d4ed112d32342471ca7384b788a";
            };

            # https://modrinth.com/mod/scalablelux
            ScalableLux = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Ps1zyz6x/versions/PV9KcrYQ/ScalableLux-0.1.6%2Bfabric.c25518a-all.jar";
              sha512 = "729515c1e75cf8d9cd704f12b3487ddb9664cf9928e7b85b12289c8fbbc7ed82d0211e1851375cbd5b385820b4fedbc3f617038fff5e30b302047b0937042ae7";
            };

            # https://modrinth.com/mod/ferrite-core
            FerriteCore = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/uXXizFIs/versions/Ii0gP3D8/ferritecore-8.2.0-fabric.jar";
              sha512 = "3210926a82eb32efd9bcebabe2f6c053daf5c4337eebc6d5bacba96d283510afbde646e7e195751de795ec70a2ea44fef77cb54bf22c8e57bb832d6217418869";
            };

            # https://modrinth.com/mod/xaeros-world-map
            XaerosWorldMap = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/NcUtCpym/versions/CkZVhVE0/xaeroworldmap-fabric-1.21.11-1.40.11.jar";
              sha512 = "3eb12225c10825d4887c2e915b2a331be09b6eac4a75ccc320767542c92633d11bc6a8a63cb2b28bbf062c102e4ec50000d3082892e00328044d6225b1836f65";
            };

            # https://modrinth.com/plugin/bluemap
            BlueMap = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/swbUV1cr/versions/TROfpX7m/bluemap-5.16-fabric.jar";
              sha512 = "138c022c61ff7b37174351625bdb859d7b0fd1dd33b76a32d894dc6fd8fe1c3d3c5d2a8575a3e72a82ca84baaf3253c485085d8a415cc76d1ed20bbabe88ab25";
            };

            # https://modrinth.com/plugin/chunky
            Chunky = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/fALzjamp/versions/1CpEkmcD/Chunky-Fabric-1.4.55.jar";
              sha512 = "3be0e049e3dea6256b395ccb1f7dccc9c6b23cb7b1f6a717a7cd1ca55f9dbda489679df32868c72664ebb28ca05f2c366590d1e1a11f0dc5f69f947903bad833";
            };

            # https://modrinth.com/mod/jade
            Jade = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/nvQzSEkH/versions/HKUAgY3D/Jade-1.21.11-Fabric-21.1.1.jar";
              sha512 = "566a7cf3fa17a8170dcdc52a61d9965bc7848a7b503ecf3b18a7e3caa617f28a77a1d6787ac4e49ac30436d235c8ff01f67e92771546a0b319b34392a47b0baf";
            };

            # https://modrinth.com/mod/lithium
            Lithium = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/qvNsoO3l/lithium-fabric-0.21.3%2Bmc1.21.11.jar";
              sha512 = "2883739303f0bb602d3797cc601ed86ce6833e5ec313ddce675f3d6af3ee6a40b9b0a06dafe39d308d919669325e95c0aafd08d78c97acd976efde899c7810fd";
            };

            # https://modrinth.com/mod/visual-workbench
            VisualWorkbench = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/kfqD1JRw/versions/dn5ujpT7/VisualWorkbench-v21.11.1-mc1.21.11-Fabric.jar";
              sha512 = "36ec9c91d686111cb133f9879a46a76a5c87fe4822c8d76e8a6ab94b11dcb98c284d3b9e91d27ce5092dd914b45a4efa9a5c8f97d23745bfb3a5bff9a9f796a8";
            };

            # https://modrinth.com/mod/cloth-config
            ClothConfig = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/9s6osm5g/versions/xuX40TN5/cloth-config-21.11.153-fabric.jar";
              sha512 = "8f455489d4b71069e998568cf4e1450116f4360a4eb481cd89117f629c6883164886cf63ca08ac4fc929dd13d1112152755a6216d4a1498ee6406ef102093e51";
            };

            # https://modrinth.com/mod/balm
            Balm = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/MBAkmtvl/versions/sbE6e5Gh/balm-fabric-1.21.11-21.11.6.jar";
              sha512 = "89aac07146c8204e705662010589c60b4e8fdf07cabc254e5901116edc95da40448d4a49abfdf179883512c83c7909b7ba02e767cde49cb44b69e1e58c793041";
            };

            # https://modrinth.com/mod/collective
            Collective = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/e0M1UDsY/versions/T8rv7kwo/collective-1.21.11-8.13.jar";
              sha512 = "af145a48ac89346c7b1ffa8c44400a91a9908e4d1df0f6f1a603ff045b1fd82d9aa041aea27a682c196b266c0daf84cb5b7b8d83b07ee53e2bc1a5c210d19a1b";
            };

            # https://modrinth.com/mod/architectury-api
            ArchitecturyAPI = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/lhGA9TYQ/versions/uNdfrcQ8/architectury-19.0.1-fabric.jar";
              sha512 = "7ca532844a0ed3d35e8515e13d1e84f8eadfceaae93281b79ad6b4dac253f4634e3dfcc7592f9543871dec117e1a3092c196ba5eae33735162de223be19dc4ad";
            };

            # https://modrinth.com/mod/jamlib
            JamLib = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/IYY9Siz8/versions/SUWZN0xp/jamlib-fabric-1.3.5%2B1.21.11.jar";
              sha512 = "1355fafed11fc271e25c94d79b3c9ef71cdd4243175052d2e5a806eac86728e2d5fed9b964404a257dae2e70c9b8490019fb43c34577605971c8ac0f22c0a551";
            };

            # https://modrinth.com/mod/polymer
            Polymer = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/xGdtZczs/versions/wugBT1fU/polymer-bundled-0.15.2%2B1.21.11.jar";
              sha512 = "9c205ab398c324ee4dc376269d8aa5df64d11766b6418952a64d2df94f096e665f63eae0c4f0c66e22d03c6ff6767550d1777c28485340131e6556091199062a";
            };

            # https://modrinth.com/mod/fabric-language-kotlin
            FabricLanguageKotlin = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Ha28R6CL/versions/ViT4gucI/fabric-language-kotlin-1.13.9%2Bkotlin.2.3.10.jar";
              sha512 = "498672ee88cf703685026e74f82a85e30d980c62a1c8cc14744cb73add09a857db8d585b405e19f558ec490613642750eb00e09d8ef5a3c9578bc52b53568d51";
            };

            # https://modrinth.com/mod/silk
            Silk = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/aTaCgKLW/versions/tgYliGAU/silk-all-1.11.5.jar";
              sha512 = "23c31d044aae5ea7946d819f304af820dd06bf37f2516c2f24ef3c1f7b1e0bc1096b8b8abb67144936c92c9b8ef4953a6004da3ddb8d52a4ab44ab33c6c2865d";
            };

            # https://modrinth.com/mod/forge-config-api-port
            ForgeConfigAPIPort = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/ohNO6lps/versions/uXrWPsCu/ForgeConfigAPIPort-v21.11.1-mc1.21.11-Fabric.jar";
              sha512 = "28791c992d613da14b8685505d3ef632ed53b5f1e1d517f0b41677d10f8419f192dfbde991308df6cda5d0f113c0aa8fc18ecf4a0834029403b16d2f68dc52d6";
            };

            # https://modrinth.com/mod/puzzles-lib
            PuzzlesLib = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/QAGBst4M/versions/O1SlsQzW/PuzzlesLib-v21.11.11-mc1.21.11-Fabric.jar";
              sha512 = "055feb02f50ef4622595a5670b4c477f0ad1cbe43241e7629746a5732d161d42cd08d736d3d326e07b90fe56758bdb44772b26d99dc6efdd813e7e0eebcc4085";
            };

            # https://modrinth.com/mod/audaki-cart-engine
            AudakiCartEngine = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/V8qsCwta/versions/QdDFfe2e/ACE_mc1.21.11-4.3.jar";
              sha512 = "bfcb02cd41cdad01352fad45a2d60a51912c253674b8168fecadd42f884fc3f0f9c3f4da922420f6a6288df1c7f2ce42d84a1b96aa5a7a266c394d6206a1069a";
            };

            # https://modrinth.com/datapack/veinminer-enchantment
            VeinMinerEnchantment = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/4sP0LXxp/versions/h5oKcjvq/veinminer-enchant-2.3.0.jar";
              sha512 = "151ddfbf7e9d56a964083497cc28e38a4c311cd9fbf43bb6ab7ee6ef6cb0fa11ef977d1244062d6343d5acb1b8b3ebfe2e87f00c9e5e4ffc9a4a06edbf04b65b";
            };

          }
        );
      };
    };
  };
}
