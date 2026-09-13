{ inputs, ... }:
{
  den.aspects.star-citizen.nixos =
    # Star Citizen aspect - Game-specific configuration
    # Automatically configures cachix binary caches for faster builds
    {
      imports = [ inputs.nix-citizen.nixosModules.StarCitizen ];

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
    };

  den.aspects.star-citizen.homeManager = {
    programs.mangohud = {
      enable = true;
      settingsPerApplication."wine-StarCitizen" = {
        legacy_layout = 0;
        pci_dev = "0:03:00.0";
        gpu_index = 0;
        gpu_metrics_order = 0;
        cpu_stats = true;
        cpu_temp = true;
        gpu_stats = true;
        gpu_temp = true;
        ram = true;
        vram = true;
        fps = true;
        hud_compact = 0;
        horizontal = 1;
        horizontal_stretch = 0;
        hud_no_margin = 0;
        background_alpha = 0.2;
        font_size = 22;
        position = "top-center";
        round_corners = 10;
        text_color = "febf09";
        text_outline_thickness = 0.5;
        gpu_text = "AMD 6900XT";
        cpu_text = "AMD 7950X3D";
        gpu_load_change = true;
        cpu_load_change = true;
        core_load_change = true;
        fsr = true;
        toggle_hud = "Menu";
        toggle_logging = "Shift_L+F2";
        reload_config = "Shift+F12";
        frametime = 0;
      };
    };

    xdg.configFile."MangoHud/wine-StarCitizen.conf".force = true;
  };
}
