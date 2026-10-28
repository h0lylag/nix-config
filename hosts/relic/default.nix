# relic - Main desktop and gaming machine
{ inputs, den, ... }:
let
  overlays = import ../../overlays { inherit inputs; };
in
{
  den.hosts.x86_64-linux.relic = {
    users.chris.classes = [ "homeManager" ];
    home-manager.module = inputs.home-manager-unstable.nixosModules.home-manager;
    nixpkgs = inputs.nixpkgs-unstable;
    specialArgs = { inherit (inputs) llm-agents; };
  };

  den.aspects.relic = {
    nixos.nixpkgs.overlays = [
      overlays.v4l2loopback
    ];

    includes = [
      den.aspects.common
      den.aspects.desktop
      den.aspects.star-citizen
      den.aspects.agent-bus
      den.aspects.rea
      den.aspects.hexstrike
      den.aspects.llm
    ];

    nixos.imports = [
      (
        {
          config,
          pkgs,
          llm-agents,
          ...
        }:

        {
          imports = [
            ./hardware-configuration.nix
            #./services/reddit-monitor.nix
          ];

          # Wine helpers consume multiple X11 connections per EVE client. Xwayland's
          # default limit is 256 connections even though it supports up to 2048.
          programs.xwayland.package =
            let
              xwayland = pkgs.xwayland.override (_: {
                inherit (config.programs.xwayland) defaultFontPath;
              });
            in
            pkgs.symlinkJoin {
              name = "xwayland-maxclients-2048";
              paths = [ xwayland ];
              nativeBuildInputs = [ pkgs.makeWrapper ];
              postBuild = ''
                wrapProgram "$out/bin/Xwayland" \
                  --add-flags "-maxclients 2048"
              '';
            };

          boot = {
            loader = {
              efi.canTouchEfiVariables = true;
              limine = {
                enable = true;
                efiSupport = true;
                secureBoot.enable = true;
              };
            };

            kernelPackages = pkgs.linuxPackages_latest;

            # ASUS X670E-F workarounds for PCIe issues
            blacklistedKernelModules = [ "mt7921e" ];
            kernelParams = [
              "pcie_port_pm=off"
              "pcie_aspm.policy=performance"
            ];
          };

          # Moonlight client for viewing Sunshine hosts, including 343-guilty-spark.
          programs.moonlight-qt.enable = true;

          zramSwap = {
            enable = true;
            algorithm = "zstd";
            memoryPercent = 25;
            priority = 100;
          };

          boot.kernel.sysctl = {
            "vm.swappiness" = 100;
            "vm.page-cluster" = 0;
          };

          systemd.oomd.enable = true;

          # Samba mounts with automount to avoid UI hangs
          # Automounts disconnect when idle to prevent freezing on network loss
          fileSystems = {
            "/mnt/hdd-pool/main" = {
              device = "//10.1.1.5/main";
              fsType = "cifs";
              options = [
                "x-systemd.automount"
                "noauto"
                "x-systemd.idle-timeout=60"
                "x-systemd.device-timeout=5s"
                "x-systemd.mount-timeout=5s"
                "mfsymlinks"
                "cifsacl"
                "uid=1000"
                "gid=100"
                "credentials=/etc/smb-secrets"
              ];
            };
          };

          # GPU-specific tuning for the llm aspect's llama-cpp service.
          services.llama-cpp = {
            package = pkgs.llama-cpp-rocm;

            settings = {
              # The desktop and games share this GPU. With the default 1 GiB
              # margin, runtime buffers filled VRAM, KWin failed to pin
              # framebuffers, and prompt processing stalled at 0.1 tok/s.
              fit-target = 4096;
              # Keep the KV cache f16. Without matrix cores, quantized KV forces
              # the vector flash-attention kernel, which rereads each KV head for
              # all 8 query heads sharing it; at q8_0, generation fell from 41 to
              # 20 tok/s by 138K context. f16 uses the tile kernel, which reads
              # each KV head once.
              cache-type-k = "f16";
              cache-type-v = "f16";
            };
          };

          # Expose only the 6900 XT. ROCm also lists the 7950X3D iGPU (gfx1036),
          # which has no kernels in the build and whose shared RAM --fit counts
          # as VRAM.
          systemd.services.llama-cpp.environment.ROCR_VISIBLE_DEVICES = "GPU-fbea6dd9f2826db5";

          # Daily jEveAssets update at 4 AM
          systemd.services.jeveassets-update = {
            description = "jEveAssets Daily Update";
            startAt = "04:00";
            serviceConfig.Type = "oneshot";
            path = [ pkgs.local.jeveassets ];
            environment.JEVE_HEADLESS = "1";
            script = "jeveassets -update";
          };

          environment.systemPackages = [
            pkgs.sbctl
            pkgs.efibootmgr
            pkgs.wmctrl
            pkgs.maim
            pkgs.xdotool
            pkgs.ydotool
            #pkgs.bambu-studio
            pkgs.rustdesk-flutter
            pkgs.pgadmin4-desktopmode
            pkgs.gimp3-with-plugins
            pkgs.local.insta360-studio
            llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
            llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
            pkgs.blockbench
          ];

          system.stateVersion = "25.05";
        }
      )
    ];
  };
}
