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
      overlays.mumble
    ];

    includes = [
      den.aspects.common
      den.aspects.desktop
      den.aspects.star-citizen
      den.aspects.rea
      #den.aspects.hexstrike
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
          services.llama-cpp.package = pkgs.llama-cpp-rocm;

          # Expose only the 7900 XTX. ROCm also lists the 7950X3D iGPU (gfx1036),
          # which has no kernels in the build and whose shared RAM --fit counts
          # as VRAM.
          systemd.services.llama-cpp.environment.ROCR_VISIBLE_DEVICES = "GPU-fc141a98b8b0071b";
          systemd.services.strata.environment.ROCR_VISIBLE_DEVICES = "GPU-fc141a98b8b0071b";

          # The kernel discards a device coredump, such as an amdgpu hang report,
          # five minutes after creating it and only root can read it.
          services.udev.extraRules = ''
            ACTION=="add", SUBSYSTEM=="devcoredump", TAG+="systemd", ENV{SYSTEMD_WANTS}+="devcoredump-save@%k.service"
          '';
          systemd.services."devcoredump-save@" = {
            description = "Save device coredump %i";
            serviceConfig = {
              Type = "oneshot";
              StateDirectory = "devcoredump";
              StateDirectoryMode = "0700";
            };
            scriptArgs = "%i";
            script = ''
              dump=/sys/class/devcoredump/$1
              device=$(basename "$(readlink -f "$dump/failing_device")")
              cat "$dump/data" > "/var/lib/devcoredump/$(date +%Y%m%dT%H%M%S)-$device.txt"
              # Writing to data releases the dump.
              echo 1 > "$dump/data"
            '';
          };

          # Test for the EVE multibox GPU hangs: RADV leaves CP DMA L2 prefetches
          # running past the end of graphics command buffers.
          hardware.graphics.package = pkgs.mesa.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./patches/radv-cp-dma-prefetch-sync.patch ];
          });

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
            llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp
            llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
            llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
            pkgs.blockbench
            pkgs.mumble
          ];

          system.stateVersion = "25.05";
        }
      )
    ];
  };
}
