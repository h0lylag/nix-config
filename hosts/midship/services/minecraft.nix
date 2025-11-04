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
    systemPackages = [ pkgs.mcrcon ];
    shellAliases = {
      "rcon-5teakCraft" =
        "mcrcon -H localhost -P 25575 -p $(sudo cat /run/secrets/minecraft-rcon | grep RCON_PASSWORD | cut -d= -f2)";
    };
  };

  # RCON password secret - .env file for use with environmentFile
  sops.secrets.minecraft-rcon = {
    sopsFile = ../../../secrets/minecraft-rcon.env;
    format = "dotenv";
    owner = "minecraft";
    group = "minecraft";
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

    # Service configuration
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

    # Trigger crash notification on failure
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

    # Environment file for @varname@ substitution
    environmentFile = config.sops.secrets.minecraft-rcon.path;
    servers.${modLoader} = {
      enable = true;

      # Minecraft version with Java 22 override
      # See: https://github.com/Infinidoge/nix-minecraft/issues/64
      package = pkgs.minecraftServers.fabric-1_21_8.override {
        jre_headless = pkgs.temurin-jre-bin-24;
      };

      # Java memory and performance settings
      jvmOpts = lib.concatStringsSep " " [
        "-Xms5G"
        "-Xmx10G"
        "-XX:+UseZGC"
        "-XX:+ZGenerational"
        "-XX:+ParallelRefProcEnabled"
        "-XX:+AlwaysPreTouch"
        "-XX:+DisableExplicitGC"
        "-XX:+PerfDisableSharedMem"
        "-Xlog:gc*,safepoint:file=${dataDir}/${modLoader}/logs/gc.log:tags,uptime,level:filecount=5,filesize=50m"
      ];

      serverProperties = {
        motd = "h0ly's 5teakCraft Server";

        difficulty = "hard";
        gamemode = "survival";
        spawn-protection = 5;
        max-players = 20;
        view-distance = 10;
        simulation-distance = 10;
        # pause-when-empty-seconds = 300;
        server-port = 25565;

        enable-rcon = true;
        "rcon.port" = 25575;
        "rcon.password" = "@RCON_PASSWORD@";

        online-mode = true;
        white-list = true;
        enforce-whitelist = true;

        # level-seed = "263461529217662978"; # Conors
        level-seed = "262240479549063168"; # mine
      };

      # Ops configuration
      symlinks."ops.json" = {
        value = [
          {
            uuid = "1c7f115f-aa3f-489a-b8d6-20b1ac8ca24c";
            name = "h0lylag";
            level = 4;
            bypassesPlayerLimit = true;
          }
        ];
      };

      # Whitelist configuration
      symlinks."whitelist.json" = {
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

      symlinks = {
        mods = pkgs.linkFarmFromDrvs "mods" (
          builtins.attrValues {

            # https://modrinth.com/mod/fabric-api
            FabricApi = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/RMahJx2I/fabric-api-0.136.0%2B1.21.8.jar";
              sha512 = "a86801cac8e2a14c52a13705a6475525c9ade3f3bef053914dcce5f5ccde3854123c544aeca6cf56b75a191f6e359a1b9bd33b314f0762f783a3aa1b94ba57e8";
            };

            # https://modrinth.com/mod/distanthorizons
            DistantHorizons = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/uCdwusMi/versions/iej5xqn2/DistantHorizons-2.3.6-b-1.21.8-fabric-neoforge.jar";
              sha512 = "56c7cc29bc57075252573220ceab01fc1a4697cc6361ec42f96cbfb418c87b19bcce73e252a47d7dde08e126c56d0df99788964843593c3f88fd8c8938e7f28f";
            };

            # https://modrinth.com/mod/fabric-language-kotlin
            FabricKotlinLanguage = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Ha28R6CL/versions/i6MmXDwA/fabric-language-kotlin-1.13.6%2Bkotlin.2.2.20.jar";
              sha512 = "1d1d70bd4662ec1fcba57c9f16c3bceb185e8986119f266594f37d145d6d19772e5d6a50dcfec315e600c9eafd32f2b5f86bab72ae1954891297cde7fce62e9b";
            };

            # https://modrinth.com/mod/silk
            SilkAll = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/aTaCgKLW/versions/IeASn7sM/silk-all-1.11.3.jar";
              sha512 = "d0cb5d24ae3b4e5c0dd743b419112bad43620b8e7c72d463c51a24d7809b560a6b00fb4986b00603922c27ce62ac3651b122f8278a8f6a06b3f68d2aebf18238";
            };

            # https://modrinth.com/mod/architectury-api
            ArchitecturyApi = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/lhGA9TYQ/versions/XcJm5LH4/architectury-17.0.8-fabric.jar";
              sha512 = "7965ed7140c9f50cfcf8cf9b415de90497ae44ea4fb6dfe21704c6eba4210d0a34a4a0b0b6baf8b3e9d3b1cb70d0df79ef1ba93d04b5557f09a754959ac9c8b0";
            };

            # https://modrinth.com/mod/forge-config-api-port
            ForgeConfigApiPort = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/ohNO6lps/versions/daREdLQt/ForgeConfigAPIPort-v21.8.1-1.21.8-Fabric.jar";
              sha512 = "f7817506655bb52d9a53a1d6e25f0e9c1159e6f4137d363a9f79c5f267bfa96612898369598e29d77157e428296c7b75227e226fef93c6a98820c789c0ed1102";
            };

            # https://modrinth.com/mod/cristel-lib
            CristelLib = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/cl223EMc/versions/eSjGT41i/cristellib-fabric-1.21.7-3.0.0.jar";
              sha512 = "5636f15f0d50271c96a51c65ef756c7e1830e16b59e91a0fb6c5ce64c9382913db2249830267a3ee21fc1fd0ae2eb0620f6a55372a6d34302906b6c9fbdd4517";
            };

            # https://modrinth.com/mod/balm
            Balm = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/MBAkmtvl/versions/6STx1UB9/balm-fabric-1.21.8-21.8.10.jar";
              sha512 = "5d7459d885e34b6b056144d3ec6a2b7b2e34adbf2f5e368329b2fa5066d33b1f686ccd16e5c7d647d90206c65537560f8a6fb423f6ea779dfcad391f342f085e";
            };

            # https://modrinth.com/mod/jamlib
            JamLib = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/IYY9Siz8/versions/4kGByLs3/jamlib-fabric-1.3.5%2B1.21.8.jar";
              sha512 = "063ef3b7e804af1ed551650d2cc8c1ecf2cbfcaefdddd9f8280d5c685268e41e4d9ee30e91e444b83c50a64e9be7be4ae71f4fc8d89bb9b3e51aa60c6b3c37c2";
            };

            # https://modrinth.com/mod/yacl
            YetAnotherConfigLib = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/1eAoo2KR/versions/WxYlHLu6/yet_another_config_lib_v3-3.7.1%2B1.21.6-fabric.jar";
              sha512 = "838f57724346a295ed82eba0e9e94880273cc20a7b7825f5d17cac711989311aa4040c61964e9c4a18ef56dba5ec066d3537ad540196eed66c6a56940ac9a1fa";
            };

            # https://modrinth.com/mod/trinkets-canary
            TrinketsCanary = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/nH02ielQ/versions/1MdtHaxo/trinkets-3.11.0.jar";
              sha512 = "aea6d25553077f5b3852214b6e880ef6f52d0d1267d3f5622d0e80c4de65e8abd1f6f78eb305e0d0c513aa55e3c791f3b625ab4603e08adfab6c73b1af920118";
            };

            # https://modrinth.com/mod/lithium
            Lithium = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/qxIL7Kb8/lithium-fabric-0.18.1%2Bmc1.21.8.jar";
              sha512 = "ef3e0820c7c831c352cbd5afa4a1f4ff73db0fa3c4e4428ba35ad2faeb8e7bce8ae4805a04934be82099012444a70c0a2cf2049f2af95fe688ca84d94d1c4672";
            };

            # https://modrinth.com/mod/ferrite-core
            FerriteCore = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/uXXizFIs/versions/CtMpt7Jr/ferritecore-8.0.0-fabric.jar";
              sha512 = "131b82d1d366f0966435bfcb38c362d604d68ecf30c106d31a6261bfc868ca3a82425bb3faebaa2e5ea17d8eed5c92843810eb2df4790f2f8b1e6c1bdc9b7745";
            };

            # https://modrinth.com/mod/scalablelux
            ScalableLux = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Ps1zyz6x/versions/Bi5i8Ema/ScalableLux-0.1.5.1%2Bfabric.abdeefa-all.jar";
              sha512 = "421e1691e8d9506def48910bb15c99413eaf69b1c4fe5b729f513f4c2e1cd25ddb8155397e9c9ebab353ce72850a7ca62619c85fdd06d39bc87cfa7520af0281";
            };

            # https://modrinth.com/mod/structure-layout-optimizer
            StructureLayoutOptimizer = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/ayPU0OHc/versions/Vj2lSmzq/structure_layout_optimizer-1.1.1%2B1.21.6-fabric.jar";
              sha512 = "9b8e1aa2d7997bab8d952ef765aa78f63b2ebdad8864fa292e337e37db45ff3f99aab7eb8ad42f0bd8643c2ba9a3102d66288a01f9c16c5a6d0cbe164f347037";
            };

            # https://modrinth.com/mod/fallingtree
            FallingTree = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Fb4jn8m6/versions/IGtob92Q/FallingTree-1.21.8-1.21.8.3.jar";
              sha512 = "d8889e08d8f1945de03a7db380ff3a6aca06d6f7439c889335e1741e969ed814f23fde89ce61f62aff85ec04d40992115e1ae02ea65cd457e6c735839aa4adad";
            };

            # https://modrinth.com/mod/c2me-fabric
            C2ME = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/VSNURh3q/versions/tlZRTK1v/c2me-fabric-mc1.21.8-0.3.4.0.0.jar";
              sha512 = "30cbc520cb8349036d55a1cb1f26964cf02410cf6d6a561d9cc07164d7566a3a7564367de62510f2bab50723c2c7c401718001153fa833560634ce4b2e212767";
            };

            # https://modrinth.com/mod/resourceful-config
            ResourcefulConfig = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/M1953qlQ/versions/YwwLmDz9/ResourcefulConfig-fabric-1.21.7-3.7.6.jar";
              sha512 = "378d0ffb6d9730a28a34042224d965eea0df918eae285cac7254313c20fffbd053bb88c435fd737b290796010fca7fea87c4e3f66db88c4684d609bb17f334fe";
            };

            # https://modrinth.com/mod/lithostitched
            Lithostitched = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/XaDC71GB/versions/ROo8a9VV/lithostitched-fabric-1.21.6-1.4.11.jar";
              sha512 = "1d63192dba2dcc16f15652f3128a390da582fb5be09a4aa1ad3805c805da0fff3b15fbcade1ebbe9d503eaec1bda4a3e063902aba3d6eeca0eb8bce6fcddb859";
            };

            # https://modrinth.com/datapack/terralith
            Terralith = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/8oi3bsk5/versions/JKg71Gq0/Terralith_1.21.x_v2.5.13.jar";
              sha512 = "3103879ef390d47a68f10bd4bf1b9d406396905afa640b8c15c3a44c8c15bbc3c6fdc4eab5a946b6be15885131408f6cd698c4a8d2065144b2ab1c46fa710cdb";
            };

            # https://modrinth.com/datapack/tectonic
            Tectonic = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/lWDHr9jE/versions/G6Ed4Wsp/tectonic-3.0.13-fabric-1.21.8.jar";
              sha512 = "214ebc1fe8b7735f64211835c14161cd0cec9c4f04bb59e599fe7f7f0fdb00eaa05e89ec037069fb7c2b2802a56a3596a686e56b91b4e880caa5beb650a4fe3f";
            };

            # https://modrinth.com/mod/ksyxis
            Ksyxis = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/2ecVyZ49/versions/vCQj9Ui7/Ksyxis-1.3.4.jar";
              sha512 = "f085627a6dd242bec916fc5dbec5694733f3a44e7826f51ba64887ae50860b5b6e9f89ceac4ca9beefee356c428211260ce4a40bee6bb136bfe636c42753c972";
            };

            # https://modrinth.com/mod/netherportalfix
            NetherPortalFix = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/nPZr02ET/versions/u7d0rUcD/netherportalfix-fabric-1.21.8-21.8.1.jar";
              sha512 = "c86aecb75b3a5ec0b014bc969b424144b806b9e7f8570ee0547c85d83a3bbddccb076ad0b6ac7f92d30ae147ab2024a94a67e1a76894d718fc871997819de1bb";
            };

            # https://modrinth.com/datapack/too-expensive-removed
            TooExpensiveRemoved = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/LrtCyjyV/versions/CNFAPr58/too-expensive-removed-v1.2.4.jar";
              sha512 = "ea0f68c3a9d1c6ad5d5f9547a6044ba067669165770943ad38ec28786689de7e6309b51ce9a3b108eaa3d6f6524f1ce1a3a80c74a19951a9b58b2cdaa14b047e";
            };

            # https://modrinth.com/plugin/simple-voice-chat
            SimpleVoiceChat = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/9eGKb6K1/versions/2Z1g1v36/voicechat-fabric-1.21.8-2.6.6.jar";
              sha512 = "476ad0a99a2ed2b8897866c0a83dc084392cb9f5f385d4dcb4ca0d180aa8ef878a50b06164e59dcd0dfb9738c331431100ced58bdbbcd577a01fd2affae97302";
            };

            # https://modrinth.com/datapack/veinminer
            VeinMiner = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/OhduvhIc/versions/lCVEKyxE/veinminer-fabric-2.5.0.jar";
              sha512 = "211b3bae1bf888cd6fe02ef5f60621c82f3d2a2f8b42c15cd03d5cafa9bdf900e395920327d63a8a0144b4eaef51f32551e8a15762ab30bcb619822b90ed1829";
            };

            # https://modrinth.com/datapack/veinminer-enchantment
            VeinMinerEnchantment = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/4sP0LXxp/versions/h5oKcjvq/veinminer-enchant-2.3.0.jar";
              sha512 = "151ddfbf7e9d56a964083497cc28e38a4c311cd9fbf43bb6ab7ee6ef6cb0fa11ef977d1244062d6343d5acb1b8b3ebfe2e87f00c9e5e4ffc9a4a06edbf04b65b";
            };

            # https://modrinth.com/mod/improved-map-colors
            ImprovedMapColors = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/MzebPvyz/versions/xlPMI8N4/improvedmapcolors-fabric-1.0.0.jar";
              sha512 = "fe022bc4b61627049d1879d722e9099e4f460e4cc6ae7e8d27190905fe06cffc3bb9551b4ce822c5f8f9351b4d9a4bf9e931ddc2ed92497b726c9490c90c3c5b";
            };

            # https://modrinth.com/mod/towns-and-towers
            TownsAndTowers = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/DjLobEOy/versions/HEqgNPcC/t_and_t-fabric-neoforge-1.13.5.jar";
              sha512 = "c3e706f399792db2a8baa1426f44390b936b7221ac7757fa0a9cf3cb04bb4b1f5aeb94d491e1c9fea8a62238d59ae08f29c65746628ff7e96171ad17c5a007d2";
            };

            # https://modrinth.com/mod/waystones
            Waystones = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/LOpKHB2A/versions/jPsizyXy/waystones-fabric-1.21.8-21.8.5.jar";
              sha512 = "6eb60ddd176a7bc0060940e32ef0642056914b8d90115c06a789cf358c428dab2815525932ecfbdc73aea8f95166390367648c9aec8f2e37a44edc08457baa2c";
            };

            # https://modrinth.com/mod/xaeros-world-map
            XaerosWorldMap = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/NcUtCpym/versions/d1Pc1nIN/XaerosWorldMap_1.39.13_Fabric_1.21.8.jar";
              sha512 = "02b661e124bb5a85934cd6092e7aaac9eac6509e1333793be8a8b3c198c4fac2d73beb801d8d9130924452feee0196c8e979c5797774266e0488a96fbbef931c";
            };

            # https://modrinth.com/plugin/bluemap
            Bluemap = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/swbUV1cr/versions/plVwynim/bluemap-5.11-fabric.jar";
              sha512 = "8ea0d984e433d3b1833abf30f835654e388aa9b6fdd41ace5ba5792628bc5b9a1f7701304465deec1411122a2f8cd9ecea7c181d5c93fe1e7a8aa764b14352f3";
            };

            # https://modrinth.com/datapack/guns++
            GunsPlusPlus = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/kdch0Jxf/versions/d6oNxcst/guns%2B%2B-5.8.4.jar";
              sha512 = "7822dbd660095cef274e7345a1df8a540c6c0a9a73528e2dc10434473e0b7f830f6a83542fac4960d9fc5115bf222f3e97a4aabcd7cbe10f088409037f82c469";
            };

            # https://modrinth.com/mod/rightclickharvest
            RightClickHarvest = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Cnejf5xM/versions/Nefe8z6u/rightclickharvest-fabric-4.6.0%2B1.21.8.jar";
              sha512 = "f9d42b586e5033da7db9bee5a53c1b3d624dd6438375a3d57324d0d49ab2018478a6908702c6a54f0cdc50afb5e327b93f1c50f116811712355c1795eb3613a3";
            };

            # https://modrinth.com/mod/better-than-mending
            BetterThanMending = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/Lvv4SHrK/versions/wHUk8xSy/BetterThanMending-2.2.5.jar";
              sha512 = "d56acc54075151dfd4ee697a9c6707919385505d32b01ee4b67a7d083c5e8f656c6a51bfac34de011bf0d8455f9fa3fddf81a45f3c36bd19d1a48d868baaa7ef";
            };

            # https://modrinth.com/mod/universal-graves
            UniversalGraves = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/yn9u3ypm/versions/gdZmLCZD/graves-3.8.1%2B1.21.6.jar";
              sha512 = "8e97e86124445e1e04852c7567dca684ee2180f0a44b0884a3409c47da996b4fdc47c5ee1acefaf52666f11a8065bd92957615353641667a331f7378362a5746";
            };

            # https://modrinth.com/mod/elytra_trinket
            ElytraTrinket = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/wk57PrDM/versions/s632EFZb/Minecraft-Elytra-Trinket-1.0.10.jar";
              sha512 = "7cc6eb4dfc85ad90a081a05518921f0df2c537f1643e99fd4c85f1f2ff282145cb3f920770aa8db7cbd56c0fe45fa819b9fd07cfde508da68b22e515e4c43914";
            };

            # https://modrinth.com/mod/newcompression
            NewCompression = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/zprNPD13/versions/lxWtl75u/block_compress-1.2-fabric-1.21.8.jar";
              sha512 = "73186d68af2f51b02b121e0daa732c641b13b92878be5de40143a76f2b6b5ec214386db261b4b3513b7f296fef4ec57f38d749cd8a800bd31a4690fffb690dc7";
            };

            # https://modrinth.com/mod/mobexplosiongriefinggamerule
            MobExplosionGriefingGamerule = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/l9H9JPmo/versions/MJSMiJds/mob_explosion_griefing-1.5.0%2B1.21.3-1.21.8.jar";
              sha512 = "f2eff9955faea6b3bfe8e34a7844ae3965e5c14c2e430404cd191dfd432d9d564fa6b7fc163f87f44b637f910c7e6ecbf4209cf088e008488e14154f99652780";
            };

            # https://modrinth.com/datapack/afk-sit
            AfkSit = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/aFIdKOKp/versions/xa0amAmz/afk-sit-1.0.1.jar";
              sha512 = "b91912b8d7897e7540129e62764623fc351b1cc222e5910e9f42339ebedb6f859ca4e570e94810c8ffd7f2e9184cc933694a1e20ab52a84723ba09242e1456dd";
            };

            # https://modrinth.com/mod/ping-wheel
            PingWheel = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/QQXAdCzh/versions/hg8vAp2o/Ping-Wheel-1.11.1-fabric-1.21.8.jar";
              sha512 = "18d42916cc9c0e0ee4aea8ea5eda881e87e7432b4cc9a327081be2757a699fc5423888c3ecdd26f47aaa5f0dd77cb56c04e1de30002c45d2aeb76060613a1219";
            };

            # https://modrinth.com/mod/trade-cycling
            TradeCycling = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/qpPoAL6m/versions/xpf5V7wi/trade-cycling-fabric-1.21.8-1.0.19.jar";
              sha512 = "0ab0a0b0a8f747a6e8e02c1d6f70efdd31546a6092614c2f094f95845a60abd589b5bcf42d7e79aebce0d614f7e59473bf4a233e1d1f440ceef7b62e6811f006";
            };

            # https://modrinth.com/plugin/chunky
            Chunky = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/fALzjamp/versions/inWDi2cf/Chunky-Fabric-1.4.40.jar";
              sha512 = "9e0386d032641a124fd953a688a48066df7f4ec1186f7f0f8b0a56d49dced220e2d6938ed56e9d8ead78bb80ddb941bc7873f583add8e565bdacdf62e13adc28";
            };

            # https://modrinth.com/mod/moogs-structure-lib
            MoogsStructureLib = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/1oUDhxuy/versions/uVEm6cHG/moogs_structure_lib-1.0.2-1.21.5-1.21.10-fabric.jar";
              sha512 = "12464442c3a6b80f122f970f204304bcf52f7e6a44888e9b8e79061f55e32eb65d455945b08f638ad031dd9b56410212a4b3f7a860253b0eaa74b43fd27d5006";
            };

            # https://modrinth.com/mod/mns-moogs-nether-structures
            MoogsNetherStructures = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/nGUXvjTa/versions/gDZUSxKT/MoogsNetherStructures-1.21-2.0.0.jar";
              sha512 = "d9570ac3b470623e767ca8b50eadc93e0d6850603e13b58a3fb619c8801dfefefe225c83b825b424e0034727b696d79dedad7d6fe63ffb6b507fbc8b78236c23";
            };

            # https://modrinth.com/mod/mes-moogs-end-structures
            MoogsEndStructures = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/r4PuRGfV/versions/kYvyT50t/mes-1.4.6-1.21.8.jar";
              sha512 = "cca1cbdca0a3a81408dcd18e183034a8717769ac2c5faa45d85f8902b13aa93e173188be794ab5816f8de743cbf51423095a882807f1648c0e551e9898ec6a60";
            };

            # https://modrinth.com/mod/mtr-moogs-temples-reimagined
            MoogsTemplesReimagined = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/UNanzCXS/versions/3vDA6tIA/MoogsTemplesReimagined-1.21-1.0.2.jar";
              sha512 = "70b6da8c1c7b87c1e719ebfb5078d881691211ced5798fd7423557d3dd55b7eab9da471883c18a512faf4671b6297b8fe5810bd9a737a5e7a0bf6ddf3f00e318";
            };

            # https://modrinth.com/mod/mmv-moogs-missing-villages
            MoogsMissingVillages = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/spZb29SD/versions/Ovcslt8K/MoogsMissingVillages-1.21-2.0.0.jar";
              sha512 = "a43534e5bbcbce5482649cd912b111603c9e691a73d05691ae5c79fc80b6994d8f71d08a6e8ce31d1c774bc9134c2e98229d880e9a15bac2d85b668cb9eadfd7";
            };

            # https://modrinth.com/mod/mss-moogs-soaring-structures
            MoogsSoaringStructures = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/RJCLIx7k/versions/MSUM0j0G/MoogsSoaringStructures-1.21-2.0.0.jar";
              sha512 = "86475abb345aecd5e70b7d1bde8c29816612221502e3d97de31393acb08da1dbe49766cfe8739dd6015e8097bdd5efd6dd3c96dc441347a2cf1368bfc9a24129";
            };

            # https://modrinth.com/mod/moogs-voyager-structures
            MoogsVoyagerStructures = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/OQAgZMH1/versions/YWXTj40n/MoogsVoyagerStructures-1.21-5.0.1.jar";
              sha512 = "cbb02521cb4e23666a5d9a27b798180da6fb0225f655f286010bdef9822cc6b9824581b178916e5f2f0b10bb2c486865597b1806d030b6d16a3e0eed5f064fc6";
            };

            # https://modrinth.com/mod/crafting-tweaks
            CraftingTweaks = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/DMu0oBKf/versions/6lHrJlho/craftingtweaks-fabric-1.21.8-21.8.2.jar";
              sha512 = "82a81bce5f4d2e6e6720601ec0368d99a1335af43aa0fe552468ca217fc67fc50fe385f6d8982b70be032e0a0b63b0f1c92862fba215652965fbf8f4b86b740e";
            };

            # https://modrinth.com/mod/collective
            Collective = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/e0M1UDsY/versions/8tJ3qV5y/collective-1.21.8-8.11.jar";
              sha512 = "3fcff2556303ebbb9495fbe3b13d42cb22a284323828520ecfae846b1695eda6c0a9f8b187815a0b128fb9a1e809510d7aabf60ab4555bf0ad22510dcfdd8dee";
            };

            # https://modrinth.com/mod/double-doors
            DoubleDoors = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/JrvR9OHr/versions/Kaxph4k0/doubledoors-1.21.8-7.1.jar";
              sha512 = "09370159d41925eec07558e65cf06cff99253503d55ff13b206bae1f2914c4e8cdab938747526e3e75f900793fa95eaf2636e7eead1f4bdfc9b0d9efeacfc50e";
            };

            # https://modrinth.com/mod/visual-workbench
            VisualWorkbench = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/kfqD1JRw/versions/tpfB5hBp/VisualWorkbench-v21.8.1-1.21.8-Fabric.jar";
              sha512 = "fc9eaa58af57ccade19b1366ae79ddc2bb7dda0efa29e5a23c668268a1d280c67034217006f9d588bf1c47c39a3d40457c6e8c946936185dbe73e20439332ba3";
            };

            # https://modrinth.com/mod/puzzles-lib
            PuzzlesLib = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/QAGBst4M/versions/tXTEdgyF/PuzzlesLib-v21.8.9-1.21.8-Fabric.jar";
              sha512 = "1f6c538a56c95480d8adff65fc86c4dc86c8b6bceace8d95ff492768df985c5be970ea54ae132794436166bc4c0791e7c4be18d0b8af4b8dd6cea265d2944b73";
            };

            # https://modrinth.com/datapack/hopo-better-mineshaft
            HopoBetterMineshaft = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/9IxCUYAP/versions/oHHFvuJR/HopoBetterMineshaft-%5B1.21.6%5D-1.3.2.jar";
              sha512 = "92c396015f08149a45d9be846ea4535d81436f0928b58326715e7ae854bdf0474c33d7191d7c09ed6cf4e38bf8e6b45510813a733e61674f8e3a10c1ed8cc396";
            };

            # https://modrinth.com/datapack/hopo-better-underwater-ruins
            HopoBetterUnderwaterRuins = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/BuWCQzqf/versions/dmRUPAhd/HopoBetterUnderwaterRuins-%5B1.21.6%5D-1.2.4.jar";
              sha512 = "5436f081dce6564707316e4dde62affe6ef280a289154f0a5171cd3e694f602225939d302f0110c1d70c142ed8c8545c18f2daf244b8829527e7b71e957901fe";
            };

            # https://modrinth.com/datapack/hopo-better-ruined-portals
            HopoBetterRuinedPortals = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/hIpLSyga/versions/8HdtnSTx/HopoBetterRuinedPortals-%5B1.21.6%5D-1.4.7.jar";
              sha512 = "d9a4402b53e55bff7e451993bff577fc89f111da2e8b5ed845a05e5836ed268b431e9d64cf6db4a3d4a627bc8ef432664b4c5b1751ca7b9d353bd91624dc3d56";
            };

            # https://modrinth.com/mod/cloth-config
            ClothConfig = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/9s6osm5g/versions/cz0b1j8R/cloth-config-19.0.147-fabric.jar";
              sha512 = "924b7e9bf6da670b936c3eaf3a2ba7904a05eff4fd712acf8ee62e587770c05a225109d3c0bdf015992e870945d2086aa00e738f90b3b109e364b0105c08875a";
            };

            # https://modrinth.com/mod/rei
            RoughlyEnoughMods = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/nfn13YXA/versions/hoEFy7aF/RoughlyEnoughItems-20.0.811-fabric.jar";
              sha512 = "13c50f7e95930bc013fed7e50d8240e376ab8e0e3b2b73ce103a0df60c0010debc3f412a09a7c14e4c03b89d1006f58a6f395617f28512fd35a095be929de785";
            };

            # https://modrinth.com/mod/additional-structures
            AdditionalStructures = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/TWsbC6jW/versions/RURunGvI/AdditionalStructures-1.21.x-%28v.5.1.3-fabric%29.jar";
              sha512 = "336a5ba4a22c7c95d25743c114658dc846f213815acb7b52138b8dd2bd60b0b28acd7143c650d147039be7e1d5599904974bbcddb537c2468a7e88fc0c95be91";
            };

            # https://modrinth.com/mod/axes-are-weapons
            AxesAreWeapons = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/1jvt7RTc/versions/IgfXr6Py/AxesAreWeapons-1.9.4-fabric-1.21.5.jar";
              sha512 = "ff89e4b7f41e0216374749c3a9ca713b3e13d9ec3efc3e6109a62aa5f8476563c07e9f7a7c7d33fea4372299ea95d06000f213857a8031e3e2cc389fa4ea923d";
            };

            # https://modrinth.com/mod/mine-spawners
            MineSpawners = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/7VESbzyX/versions/ZyC5wP3K/mine-spawners-1.6.4.jar";
              sha512 = "6939cbffbf9fe956f0190285d00d39192978b44976aa761c4ccfa0c158e1f3cf33210483e3c46fe1fdbe90c99692e0ff73b3d3c57cd352c2a5ea8583f57e8dc2";
            };

            # https://modrinth.com/datapack/spawn-animations
            # SpawnAnimations = pkgs.fetchurl {
            #   url = "https://cdn.modrinth.com/data/zrzYrlm0/versions/uOUZcu68/spawnanimations-v1.11.2-mc1.17-1.21.10-mod.jar";
            #   sha512 = "26a996b6c8eb1335ac1198f95d07faecaf241c78eb7249fdac890daad258fca60df87e4d9f430a9a7de69cbb711361b5552d167db177d75e1c3b7e71545d67ff";
            # };

            # https://modrinth.com/mod/appleskin
            AppleSkin = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/EsAfCjCV/versions/YAjCkZ29/appleskin-fabric-mc1.21.6-3.0.6.jar";
              sha512 = "e36c78b036676b3fac1ec3edefdcf014ccde8ce65fd3e9c1c2f9a7bbc7c94185168a2cd6c8c27564e9204cd892bfbaae9989830d1acea83e6f37187b7a43ad7d";
            };

            # https://modrinth.com/mod/jade
            Jade = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/nvQzSEkH/versions/o3aatc5Q/Jade-1.21.8-Fabric-19.3.2.jar";
              sha512 = "3cf66c4a859805886777f18d354f587db366f2a7bb47781dee782bd2d29ed19500e0521b1d19c2701c8a16d6e116e7256b0ab287d387e57d02a0430e1312ed4b";
            };
          }
        );
      };
    };
  };
}
