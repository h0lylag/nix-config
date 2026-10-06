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
      amethystSteamRun = amethystPkgs.writeShellScript "amethyst-steam-run" ''
        unset PYTHONPATH PYTHONHOME
        exec ${lib.getExe amethystSteamRuntime} "$@"
      '';
      amethystProtontricks = amethystPkgs.writeShellScript "amethyst-protontricks" ''
        # Protontricks uses a different Python version from Amethyst.
        unset PYTHONPATH PYTHONHOME
        exec ${lib.getExe' pkgs.protontricks "protontricks"} "$@"
      '';
      amethyst =
        (inputs.amethyst-mod-manager.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
          # Mod archives can require the RAR decoder omitted from ordinary 7-Zip.
          _7zz = amethystPkgs._7zz-rar;
        }).overrideAttrs
          (old: {
            # Upstream runs native Proton and bundled Winetricks without the
            # Steam environment. On NixOS this fails at /lib/ld-linux.so.2.
            postPatch = (old.postPatch or "") + ''
              substituteInPlace src/Utils/launchers/steam.py \
                --replace-fail 'cmd = [str(script), *payload]' \
                  'cmd = ["${amethystSteamRun}", str(script), *payload]' \
                --replace-fail 'return base' \
                  'return ["${amethystSteamRun}", *base]'
              substituteInPlace src/Utils/wine/protontricks.py \
                --replace-fail '[winetricks, "-q", component]' \
                  '["${amethystSteamRun}", winetricks, "-q", component]' \
                --replace-fail 'return ["protontricks"]' \
                  'return ["${amethystProtontricks}"]'
            '';
            # Upstream omits xxhash, which is required to import Wabbajack lists.
            qtWrapperArgs = (old.qtWrapperArgs or [ ]) ++ [
              "--prefix"
              "PYTHONPATH"
              ":"
              "${amethystPkgs.python313Packages.xxhash}/${amethystPkgs.python313.sitePackages}"
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
