{ inputs, den, ... }:
let
  overlays = import ../../overlays { inherit inputs; };
in
{
  den.aspects.gaming.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Use the same Python package set as the upstream Amethyst flake.
      amethystPkgs = import inputs.amethyst-mod-manager.inputs.nixpkgs {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
      amethystSteamRuntime =
        (amethystPkgs.steam.override {
          # Prefix tools need both Linux loaders and FreeType, like Protontricks.
          extraLibraries = p: [ p.freetype ];
          # Keep temporary installer files and Wine sockets visible across calls.
          privateTmp = false;
        }).run-free;
      # Upstream wraps Proton, Wine, and Winetricks with the first steam-run on
      # PATH on NixOS; shadow it with the customized runtime above.
      amethystSteamRun = amethystPkgs.writeShellScriptBin "steam-run" ''
        unset PYTHONPATH PYTHONHOME
        exec ${lib.getExe amethystSteamRuntime} "$@"
      '';
      amethystProtontricks = amethystPkgs.writeShellScript "amethyst-protontricks" ''
        # Protontricks uses a different Python version from Amethyst.
        unset PYTHONPATH PYTHONHOME
        exec ${lib.getExe' pkgs.protontricks "protontricks"} "$@"
      '';
      amethyst =
        inputs.amethyst-mod-manager.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
          (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace src/Utils/wine/protontricks.py \
                --replace-fail 'return ["protontricks"]' \
                  'return ["${amethystProtontricks}"]'
            '';
            qtWrapperArgs = (old.qtWrapperArgs or [ ]) ++ [
              "--prefix"
              "PATH"
              ":"
              "${amethystSteamRun}/bin"
              # Upstream omits xxhash, which is required to import Wabbajack lists.
              "--prefix"
              "PYTHONPATH"
              ":"
              "${amethystPkgs.python3Packages.xxhash}/${amethystPkgs.python3.sitePackages}"
            ];
          });
    in
    {
      nixpkgs.overlays = [
        inputs.nix-eve.overlays.default
        overlays.bolt-launcher
      ];

      # Gaming support - Steam with remote play
      programs.steam = {
        enable = lib.mkDefault true;
        remotePlay.openFirewall = lib.mkDefault true;
        dedicatedServer.openFirewall = lib.mkDefault false;
      };

      # Gaming packages
      environment.systemPackages = with pkgs; [
        mangohud
        gamescope
        protontricks
        bolt-launcher
        prismlauncher
        eve-online
        pkgs.local.cmel
        pkgs.local.evemon
        pkgs.local.jeveassets
        pyfa
        pkgs.local.dayz-tools.a2s-info
        pkgs.local.dayz-tools.xml-validator
        pkgs.local.rusty-shovel
        cubiomes-viewer
        amethyst
        inputs.eve-preview-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
        inputs.set-desto.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
}
