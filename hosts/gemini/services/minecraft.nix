{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Minecraft server settings
  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;

    dataDir = "/var/lib/minecraft";

    servers.fabric = {
      enable = true;

      # Minecraft version
      package = pkgs.minecraftServers.fabric-1_21_8;

      serverProperties = {
        motd = "h0ly's 5teakCraft Server";

        difficulty = "hard";
        gamemode = "survival";
        spawn-protection = 0;
        max-players = 20;
        view-distance = 12;
        simulation-distance = 12;

        server-port = 25565;

        enable-rcon = false;

        online-mode = true;
        white-list = true;
        enforce-whitelist = true;

        level-seed = "-1111111111111111111111111";
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

            # https://modrinth.com/mod/xaeros-minimap
            XaerosMiniMap = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/1bokaNcj/versions/dEIlpdij/Xaeros_Minimap_25.2.16_Fabric_1.21.8.jar";
              sha512 = "989cd7bf11a0c5d3ba8e034b064b9261ce7a236fb19fd47a9fb5ed986eeeb76d3b591829fd952f79a295dc6491357c6f8f7c7c895c6138c1e8d0aa86e9274c6c";
            };

            # https://modrinth.com/mod/xaeros-maps-x-waystones
            XaerosMapsXWaystones = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/iv2jCzkP/versions/Ph2E1uPA/xaeromaps_waystones-1.0.5%2B1.21.x-fabric.jar";
              sha512 = "7ff970a4c84f8dd29b71b4a6a7ef0a68f53050d67756accfe8cf1abb9220e25912c4877b3f735deff78d97d805aa71b7698ccd024f25250871065bc3bedff8f9";
            };

            # https://modrinth.com/plugin/bluemap
            Bluemap = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/swbUV1cr/versions/plVwynim/bluemap-5.11-fabric.jar";
              sha512 = "8ea0d984e433d3b1833abf30f835654e388aa9b6fdd41ace5ba5792628bc5b9a1f7701304465deec1411122a2f8cd9ecea7c181d5c93fe1e7a8aa764b14352f3";
            };

            # https://modrinth.com/datapack/gamingbarns-guns
            GamingBarnsGuns = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/gLko9Axn/versions/KkSpI3Pd/gamingbarns-guns-V1.26.2-data.jar";
              sha512 = "87c969ac2e930f82d0564aff2c902f41a4e1da45bfffc79699171631e17bec3524c513adec096c2fbed01f19df59917050f3bdfb8a9c54d82cf08eb67d1331f1";
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

          }
        );
      };
    };
  };
}
