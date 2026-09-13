{
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;
  manual.manpages.enable = false;

  programs.git = {
    enable = true;
    package = null;
    settings = {
      user = {
        email = "h0lylag@gravemind.sh";
        name = "h0lylag";
      };
      credential = {
        "https://github.com".helper = [
          ""
          "!/run/current-system/sw/bin/gh auth git-credential"
        ];
        "https://gist.github.com".helper = [
          ""
          "!/run/current-system/sw/bin/gh auth git-credential"
        ];
      };
    };
  };

  programs.fastfetch = {
    enable = true;
    package = null;
    settings = {
      "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json";
      modules = [
        "title"
        "separator"
        "os"
        "host"
        "kernel"
        "uptime"
        {
          type = "packages";
          format = "{nix-all} (nix), {flatpak-all} (flatpak)";
        }
        "shell"
        "display"
        "de"
        "wm"
        "font"
        "terminal"
        "terminalfont"
        "cpu"
        "gpu"
        "memory"
        "swap"
        "disk"
        "battery"
        "poweradapter"
        "localip"
        {
          type = "weather";
          location = builtins.fromJSON ''"\u0025\u0033\u0039\u0025\u0033\u0037\u0025\u0033\u0030\u0025\u0033\u0037\u0025\u0033\u0031"'';
          timeout = 1500;
        }
        "break"
        "colors"
      ];
    };
  };

  programs.terminator = {
    enable = true;
    config = {
      global_config = { };
      keybindings = { };
      profiles.default = {
        background_darkness = 0.82;
        background_type = "transparent";
        font = "RobotoMono Nerd Font Mono Medium 11";
        show_titlebar = false;
        scrollback_lines = 10000;
        scrollback_infinite = true;
        use_system_font = false;
        title_use_system_font = false;
        title_font = "RobotoMono Nerd Font 9";
      };
      layouts.default = {
        window0 = {
          type = "Window";
          size = "1100, 700";
          parent = "";
        };
        child1 = {
          type = "Terminal";
          parent = "window0";
          profile = "default";
        };
      };
      plugins = { };
    };
  };

  xdg.configFile."terminator/config".force = true;
  xdg.configFile."fastfetch/config.jsonc".force = true;
}
