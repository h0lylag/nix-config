{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "chris";
  home.homeDirectory = "/home/chris";


  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    terminator
    firefox
    kate
    vesktop
    mpv
    yt-dlp
    jellyfin-media-player
    libreoffice-qt
  ];

  # steam setup
  programs.steam = {
    enable = true;
  };

  # terminator
  programs.terminator = {
    enable = true;
    config = {
    profiles = {
      default = {
        background_darkness = "0.95";
        background_type = "transparent";
        use_system_font = "False";
        font = "Roboto Mono 10";
        show_titlebar = "False";
        scrollback_lines = "10000";
        };
      };
    };
  };

  # mpv
  programs.mpv = {
    enable = true;
    config = {
      "screenshot-format" = "png";
      "screenshot-png-compression" = "9";
      "screenshot-directory" = "${config.home.homeDirectory}/Pictures/Screenshots/mpv";
    };
    bindings = {
      MOUSE_BTN3 = "add volume 5";
      MOUSE_BTN4 = "add volume -5";
    };
  };

  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
