# Star Citizen feature - Game-specific configuration
# Automatically configures cachix binary caches for faster builds
{ nix-citizen, ... }:

{
  imports = [ nix-citizen.nixosModules.StarCitizen ];

  # Cachix binary caches for nix-gaming and nix-citizen
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

  programs.rsi-launcher = {
    enable = true;
    # Wayland fix: Unsetting DISPLAY keeps mouse locked in game window
    # Enable MangoHud overlay for performance monitoring
    preCommands = ''
      export MANGOHUD=1
      export DISPLAY=
    '';
  };
}
