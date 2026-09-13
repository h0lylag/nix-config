{
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;
  manual.manpages.enable = false;

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
}
