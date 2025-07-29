{
  config,
  pkgs,
  lib,
  specialArgs,
  ...
}:

{

  # 1) Import the official nix-citizen StarCitizen module
  imports = [ inputs.nix-citizen.nixosModules.StarCitizen ];

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
      export DISPLAY=
    '';

    # Set limits manually. Enabled by default
    # setLimits = true;
  };

  # RSI Launcher package
  environment.systemPackages = with pkgs; [
    rsi-launcher
  ];
}
