{
  config,
  pkgs,
  lib,
  specialArgs,
  ...
}:

let
  # Make it easier to refer to the flake inputs
  inputs = specialArgs;

  # RSI Launcher with overrides
  rsi-launcher = pkgs.rsi-launcher.override (prev: {
    # Wine DLL overrides (keep previous + add custom ones)
    # wineDllOverrides = prev.wineDllOverrides ++ [ "dxgi=n" "d3d11=n" ];

    # GameScope settings
    gameScopeEnable = false;
    gameScopeArgs = [
      "-W 3840"
      "-H 2160"
      "-f"
    ];

    preCommands = ''
      unset DISPLAY
    '';

    # Extra environment variables
    extraEnvVars = {
      MANGOHUD = "1";
    };
  });
in
{
  # 1) Import the official nix-citizen StarCitizen module
  imports = [ inputs.nix-citizen.nixosModules.StarCitizen ];

  # Allow unfree packages (needed for Star Citizen)
  nixpkgs.config.allowUnfree = true;

  # Cachix settings for nix-gaming and nix-citizen
  nix.settings = {
    substituters = [
      "https://nix-gaming.cachix.org"
      "https://nix-citizen.cachix.org"
    ];
    trusted-public-keys = [
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo="
    ];
  };

  # Star Citizen configuration
  nix-citizen.starCitizen = {
    enable = true;

    # Commands to run before launching the game
    preCommands = ''
      export MANGOHUD=1
      unset DISPLAY
      #set -- "$@" "--in-process-gpu"
    '';

    # Set limits manually. Enabled by default
    # setLimits = true;
  };

  # RSI Launcher package
  environment.systemPackages = with pkgs; [
    rsi-launcher
  ];
}
