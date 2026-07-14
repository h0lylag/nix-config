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

  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];

  # Minecraft server settings
  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = false;

    dataDir = dataDir;

    environmentFile = config.sops.secrets.minecraft-rcon.path;
    servers.${modLoader} = {
      enable = true;

      package = pkgs.minecraftServers.fabric-26_2.override {
        jre_headless = pkgs.temurin-jre-bin-25;
      };

      jvmOpts = lib.concatStringsSep " " [
        "-Xms16G"
        "-Xmx16G"
        "-XX:+UseZGC"
        "-XX:+AlwaysPreTouch"
        "-XX:+DisableExplicitGC"
        "-Xlog:async"
        "-Xlog:gc*,safepoint:file=${dataDir}/${modLoader}/logs/gc.log:time,uptime,level,tags:filecount=5,filesize=50m"
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

        level-seed = "-5373255381197842874";
        #level-type = "minecraft:large_biomes";
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
            {
              uuid = "5a14a881-b740-4f60-bcf8-cc5d7902f280";
              name = "khanpaso";
            }
            {
              uuid = "d6dd0d3c-a32a-4f54-ae05-01c71228e50f";
              name = "Author50CO";
            }
          ];
        };

        mods = pkgs.linkFarmFromDrvs "mods" (
          builtins.attrValues {

            # https://modrinth.com/mod/fallingtree
            FallingTree = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Fb4jn8m6/versions/sOoH5kkd/FallingTree-26.2-25.jar";
              sha512 = "b47a93c6fed4bfc9da70881d6eea5df771c79a679fc2473b0c987935736a3c85b1a5c7ab1a2580d0833413ddc6ca02aa5d5996e9e88bd7b0387a3ff74f049130";
            };

            # https://modrinth.com/mod/netherportalfix
            NetherPortalFix = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/nPZr02ET/versions/GQpccFqg/netherportalfix-fabric-26.2-26.2.0.1.jar";
              sha512 = "59d02006e5f51bd9a7e57de05a39f6803e504303bc22fb3451e41756c41ff7333ff6348ee51cf3b585dcf27454c0556407523a1a0bc4a84639e0d0b331ce8b6b";
            };

            # https://modrinth.com/datapack/too-expensive-removed
            TooExpensiveRemoved = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/LrtCyjyV/versions/eXbPJfUB/too-expensive-removed-v1.2.7.jar";
              sha512 = "4300c0c7c19c193dc0b057daa94c3796e559bc7c7b8e50b23e6231c70d82eac937dd2c292bc5155a2dcf05b02ca48e02b4a6ccff661c429e6937b458400cbc77";
            };

            # https://modrinth.com/datapack/veinminer
            VeinMiner = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/OhduvhIc/versions/QwoUn7GM/veinminer-fabric-2.11.1.jar";
              sha512 = "4b97b416cef3ecdd23d1b5427d82acb841ca208fe76145d736a9d360f641411fc43ec4466bc5bd3b2ed1cedf4c22414b949c77a5712b982f263598b8dd746151";
            };

            # https://modrinth.com/mod/rightclickharvest
            RightClickHarvest = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Cnejf5xM/versions/MMi9Zx44/rightclickharvest-fabric-4.6.2%2B26.2.x.jar";
              sha512 = "f3b14c46818d4d017d891bf9d8fbc4524fbe020ceda5942d72e5a2c28e6901a889d166160e5a1e33e0c45d7057f8ba1cf262821d5b14f59395008da9057b308c";
            };

            # https://modrinth.com/mod/universal-graves
            UniversalGraves = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/yn9u3ypm/versions/BZfhXd0q/graves-3.12.0%2B26.2.jar";
              sha512 = "499f52b063b1313351d7128fc94f46ac0e256684ebd7d39206a6d331a74c7fb276364448ddb4563a8bc08f8ca3c948a2f7f065e70b23b10cf24686f69e8b3013";
            };

            # https://modrinth.com/mod/better-than-mending
            BetterThanMending = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Lvv4SHrK/versions/SydvTww2/BetterThanMending-2.3.0-merged.jar";
              sha512 = "cd540aa7a436186e669cd733b46b6ae2e3403dc1978577d479bbaa654a8c71233eba17f1bcf9510a2fcd1991d708273f77dec61b2b2c2d94064863f15392fb36";
            };

            # https://modrinth.com/mod/mobexplosiongriefinggamerule
            # REVIEW(26.2): No compatible release on Modrinth as of 2026-07-13.
            # MobExplosionGriefingGamerule = pkgs.fetchurl {
            #   url = "https://cdn.modrinth.com/data/l9H9JPmo/versions/Nke6FVKQ/mob_explosion_griefing-2.0.0%2B1.21.11.jar";
            #   sha512 = "1f45e2941b7fa1f91020b9470fadcbf824b4f5fc2b6d51d73e8d510c426f1d147cb52f33d7bf9e7b8a32bf4ca75e40516cb9cc7b71b6ce0699b4feaeeff9d68a";
            # };

            # https://modrinth.com/mod/trade-cycling
            TradeCycling = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/qpPoAL6m/versions/Pw2HCuRa/trade-cycling-fabric-1.0.21%2B26.2.jar";
              sha512 = "c1246c37a08744d71f6b0296fb2f9d6180cb95445af7502a0e95ff0bde9a2288d224528f6772faa8da0c19387e0628634fa73f5e9da7bc6b9673ae1fef784c38";
            };

            # https://modrinth.com/mod/double-doors
            DoubleDoors = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/JrvR9OHr/versions/uiANFlUz/doubledoors-26.2.0-7.2.jar";
              sha512 = "8d63de32bd7558812c78d67e5fe4e620bbb2aaa9f2f6b7af56020844aa5f7dcf9f7313db287bada2483073f04dfe05822c00a86eca83c597821543f85e22f024";
            };

            # https://modrinth.com/mod/axes-are-weapons
            AxesAreWeapons = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/1jvt7RTc/versions/oBhr7V5c/AxesAreWeapons-1.10.2-fabric-26.1.jar";
              sha512 = "ae3d2414647f14ae100930a74d6a6e351d957f8b2bd0c29d804c30ad1364c8885d4b315a43c8706d6e47ace5cb8aee3aab706095c86c0c44d84a00ebaac790b4";
            };

            # https://modrinth.com/mod/appleskin
            AppleSkin = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/EsAfCjCV/versions/uo5bAN1Y/appleskin-fabric-mc26.2-3.0.10.jar";
              sha512 = "ddf31d8fe239f66760632606221a9ea55d31907a9f7f8667331929cad348457ec2199cb90d410ee1a06e36bafc01a3bf152a06fd3c9b9e46f50841240875832b";
            };

            # https://modrinth.com/mod/mine-spawners
            # REVIEW(26.2): No compatible release on Modrinth as of 2026-07-13.
            # MineSpawners = pkgs.fetchurl {
            #   url = "https://cdn.modrinth.com/data/7VESbzyX/versions/Wle6zwiu/mine-spawners-1.6.6.jar";
            #   sha512 = "fe0a63dbd265d0beadc2f5aed43029a464f62ae6e1aa92af53578c33cb66ca6effc4677ee292029d53d9fb523c9bb9bfd74fd6165fb7c06c530c37ea4061b815";
            # };

            # https://modrinth.com/mod/crafting-tweaks
            CraftingTweaks = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/DMu0oBKf/versions/L8AL817i/craftingtweaks-fabric-26.2-26.2.0.2.jar";
              sha512 = "80fe133b3cb2459471eb037f74d11b3b7ac332da0357e9dc634b28a57bd94ae7ec1e6fcfd4a4810564e489a7428d41b7dadf50883310e16dba62edfad0c6d61a";
            };

            # https://modrinth.com/mod/fabric-api
            FabricAPI = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/Kr4WG5mG/fabric-api-0.154.2%2B26.2.jar";
              sha512 = "7cedad862e8105a7de8db090c0707c25a14a9472654090861dcf490f834862c3212723e762f6f797a0e4683104f4b3a20d3692fb29d7b5c0af437613283d34db";
            };

            # https://modrinth.com/mod/distanthorizons
            DistantHorizons = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/uCdwusMi/versions/gBf0SaV1/DistantHorizons-3.2.0-b-26.2-fabric-neoforge.jar";
              sha512 = "c1b8857776a002c2232887d891bd49195f3c3127a7abe1242376ad20371e31554d8ba6c7c92a195b70782cad94fe970941487f2af530988d9b8819455c859e72";
            };

            # https://modrinth.com/mod/c2me-fabric
            C2ME = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/VSNURh3q/versions/XQMx5J57/c2me-fabric-mc26.2-0.4.2-alpha.0.13.jar";
              sha512 = "052c79f8da23a4215a812e3c3fb592b3992d519e1c5daedd193d66742823855dac65365de31408c18b750bb58990f2650e4402a3abc32cf0e30aab7125adb15b";
            };

            # https://modrinth.com/mod/scalablelux
            ScalableLux = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Ps1zyz6x/versions/FuGn0NlI/ScalableLux-0.2.1%2Bfabric.2b08348-all.jar";
              sha512 = "46cc3df58ad2723fb7f925da0e380e22481e15ceb0e61fbd7947f48d2902e7a67ae4d2d22df4faab4e3140ccf79aa9f59d91ec9959bd6e2afbf0fb90970a02fc";
            };

            # https://modrinth.com/mod/ferrite-core
            FerriteCore = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/uXXizFIs/versions/d5ddUdiB/ferritecore-9.0.0-fabric.jar";
              sha512 = "d81fa97e11784c19d42f89c2f433831d007603dd7193cee45fa177e4a6a9c52b384b198586e04a0f7f63cd996fed713322578bde9a8db57e1188854ae5cbe584";
            };

            # https://modrinth.com/mod/xaeros-world-map
            XaerosWorldMap = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/NcUtCpym/versions/lshIyDHq/xaeroworldmap-fabric-26.2-1.44.0.jar";
              sha512 = "3f8b8109cbe2492897f932e7631c48b16be72c42c9157fab4e6db2704a1c494a3b5f70b49dfffec398af9771266e20ba2a4282183696ac03a3c1abd7c23e5de6";
            };

            # https://modrinth.com/plugin/bluemap
            BlueMap = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/swbUV1cr/versions/VTvifNPN/bluemap-5.22-fabric.jar";
              sha512 = "ec597df7e974f1f28baa15325373442968c9643a157a6d2627cd5c36f8841c3023f2c08023d203bcfa7e0e51bce69d4623ba712babb84da73bd40f0e0c7f4dbd";
            };

            # https://modrinth.com/plugin/chunky
            #Chunky = pkgs.fetchurl {
            #  url = "https://cdn.modrinth.com/data/fALzjamp/versions/4Eotm6ov/Chunky-Fabric-1.5.3.jar";
            #  sha512 = "b83bfe7b218d0aa6232af977ae741dc1f82b10e50cd12bb759f65cf416b8b62beccb543e587ef0b9670abe03815660f8e091bc6823624d65cf07300571573516";
            #};

            # https://modrinth.com/mod/jade
            Jade = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/nvQzSEkH/versions/YVZmJZjb/Jade-mc26.2-Fabric-26.2.8.jar";
              sha512 = "a748497dc5a005ad3a917699a9e7cae848adbf3ca4956c222453e8d55136803f0631f2b2f8223001ac26da0ce9e61140f580c26010e0b7ac81b417267637f775";
            };

            # https://modrinth.com/mod/lithium
            Lithium = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/UPNexAfy/lithium-fabric-0.25.2%2Bmc26.2.jar";
              sha512 = "db676376c05b7e912cdae5aad9e51f125adc1554ae2b204599ccb598751921aedbac98e97b9cba0333b6b52488c6b75c915a7dbd50436f97800387fe1aad1c50";
            };

            # https://modrinth.com/mod/visual-workbench
            VisualWorkbench = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/kfqD1JRw/versions/m2UkOgBN/VisualWorkbench-v26.2.1-mc26.2.x-Fabric.jar";
              sha512 = "f7a9682b24b2def42b2b96bfe027e755eb592d87271b7a102baf9c903ffbdd7566f43055f5624d76b466b347646641575c1d380b7cf0525314d8f16dffa142eb";
            };

            # https://modrinth.com/mod/cloth-config
            ClothConfig = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/9s6osm5g/versions/Nv3xnWXd/cloth-config-26.2.155.jar";
              sha512 = "37b1e402f0df5a383656e21a38ee18cdd15cb4ba3fb62fbeba82ef4b959a4479fc32718ac0d9d154a7d9104c5f7315bfa67dbeced0b8ff240b8039d4848d5df1";
            };

            # https://modrinth.com/mod/balm
            Balm = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/MBAkmtvl/versions/ZLn74Oar/balm-fabric-26.2-26.2.0.3.jar";
              sha512 = "da7227ac0eadd8e7fb534a8f205753c63f27b2ed2f0ef4955dbdd37445448bd3b65729c419b40eb47faff235c0a11d921e02994bedb0e8c81a50af9137be535a";
            };

            # https://modrinth.com/mod/collective
            Collective = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/e0M1UDsY/versions/M75JwjyS/collective-26.2.0-8.39.jar";
              sha512 = "e27620080ae53460b00cabacaff409a960e0d6c6811b7e3519d5461cb62654e0016161eed914352171af56191b70a97c79320b3ef29c0636b74a0471c2398055";
            };

            # https://modrinth.com/mod/architectury-api
            ArchitecturyAPI = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/lhGA9TYQ/versions/Y3dxcAYK/architectury-fabric-21.0.3.jar";
              sha512 = "4fb39036c8ad4fb97ea0aeb5861a021cbfc241fa34bf4d16b50adfdcb592792b3c42220589ead0ea715210f4a665bc207b0aabacff5c6872ef165226042301a1";
            };

            # https://modrinth.com/mod/jamlib
            JamLib = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/IYY9Siz8/versions/4KQpfS7o/jamlib-fabric-2.3.1%2B26.2.x.jar";
              sha512 = "9c083d0649d5a66b007c74e161ec8e7094808b475dda3b22576088f3c5affb2cb929c4f7600b280f23a881a2580ddbc55c0504983814eaf572d1aa100687a103";
            };

            # https://modrinth.com/mod/polymer
            Polymer = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/xGdtZczs/versions/w0N4I45x/polymer-bundled-0.17.3%2B26.2.jar";
              sha512 = "1459edf99834bbbb2eff5f7df2e7159688ad88e20e8704bc473752e81a755963bb96c511641d53c9f7b4e5867436f7b49ef839e3b857c48ca54af93627c2a110";
            };

            # https://modrinth.com/mod/fabric-language-kotlin
            FabricLanguageKotlin = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Ha28R6CL/versions/Pd0xrHCw/fabric-language-kotlin-1.13.12%2Bkotlin.2.4.0.jar";
              sha512 = "ca238ee480dfb237062200fd300be493d022e0837b6998c15807e01488b2a30d5ba4731e5c6d05a5333719c8923a1cb84c06fd6fa45aa88ced492ddb5b40906f";
            };

            # https://modrinth.com/mod/silk
            Silk = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/aTaCgKLW/versions/JMCeeIMi/silk-all-1.12.0.jar";
              sha512 = "fd0c4e74bd4eac3f52303aa9fced8bf91fb41eb76a712cc9a686da1a8c1a494cd2caffa9c79ab89eb91260a7aee0ecdac4e2f44418ed0feac8cf6cf022c62fe9";
            };

            # https://modrinth.com/mod/forge-config-api-port
            ForgeConfigAPIPort = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/ohNO6lps/versions/rSd3GiG8/ForgeConfigAPIPort-v26.2.1-mc26.2.x-Fabric.jar";
              sha512 = "948b8d83de61a11aad2fc0bb0744a8b4848c9b2f0663c9aa015389d9560b3fa78518e609c44ec90278de0e159a92ebd721ccbdebb453aa455c353e5cd19413bf";
            };

            # https://modrinth.com/mod/puzzles-lib
            PuzzlesLib = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/QAGBst4M/versions/HfGQTxSR/PuzzlesLib-v26.2.1-mc26.2.x-Fabric.jar";
              sha512 = "6af3543197bbacb064e147af9c96af1d4ff35d3b5195f49874098f06e2d14023d75c0a248e0b9f4babf80a946c3519a1deb528293df38653d39def683d389e13";
            };

            # https://modrinth.com/mod/audaki-cart-engine
            AudakiCartEngine = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/V8qsCwta/versions/xnXxitQi/ACE_mc26.2-5.0.1.jar";
              sha512 = "f816dc0a160d642aca4fa6939d94f4e92f8c201ad2706cef80ff69eff631ceb365894a58ae3ed8d50c74a772bb58521ea9ff13791460124387562bba6a335ba2";
            };

            # https://modrinth.com/datapack/veinminer-enchantment
            VeinMinerEnchantment = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/4sP0LXxp/versions/6zzsM770/veinminer-enchant-2.10.3.jar";
              sha512 = "0606429e7b65bb01fa3eb335bb932bab5eeff4d772728b15d7dc2d1af1cddb60eb247d5249e6b1ee2084114e823dacba37677c0a19ac78fa4fef80e7eff170d7";
            };

            # https://modrinth.com/mod/chunk-loaders
            ChunkLoaders = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/t1VgucWo/versions/Lgsy83RX/chunkloaders-1.2.9-fabric-mc26.2.jar";
              sha512 = "b30b522258f15512ec899308e55a642f99349fe1ada8facd9a1fb849d70bc12aa236e0941fcde4e74dedea060fec77e756e0ab349d34c5397eb9b781ce8b7ff7";
            };

            # https://modrinth.com/mod/supermartijn642s-core-lib
            SuperMartijn642sCoreLib = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/rOUBggPv/versions/taJl1g0T/supermartijn642corelib-1.1.21b-fabric-mc26.2.jar";
              sha512 = "b3b4dd46416fb6a0c27e7e64ee9be8b805545f494f2053cc9a4254473bc528aafade62945ae9abff0bb7356d08b3f6df292f5f1b29c8d84d25c5dda4af8d2369";
            };

            # https://modrinth.com/mod/supermartijn642s-config-lib
            SuperMartijn642sConfigLib = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/LN9BxssP/versions/tg619S8t/supermartijn642configlib-1.1.8-fabric-mc26.2.jar";
              sha512 = "415c6ce953ccc618a98653c08eb36bfa1344227ef9e17c4c7603a07882f71e29266091e67b391dde59f76836b7d7d783342c65e75b6c4cffaaf31d0d929dacef";
            };

          }
        );
      };
    };
  };
}
