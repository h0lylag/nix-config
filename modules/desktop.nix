{ config, pkgs, ... }:

let
  krisp = pkgs.callPackage ../pkgs/krisp-patch/default.nix { };
  eve-online = pkgs.callPackage ../pkgs/eve-online/default.nix { };
  jeveassets = pkgs.callPackage ../pkgs/jeveassets/default.nix { };
  eve-l-preview = pkgs.callPackage ../pkgs/eve-l-preview/default.nix { };
in

{

  # AMD GPUs are expected to work out of the box
  # graphics acceleration still needs to be enabled.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Enable the KDE Plasma Desktop Environment.
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "chris";

  # Pipewire audio and real-time support
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Printing
  services.printing.enable = true;

  # add some fonts
  fonts.packages = with pkgs; [
    nerd-fonts.roboto-mono
  ];

  # Enable Flatpak support
  xdg.portal.enable = true;
  services.flatpak.enable = true;
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    '';
  };

  environment.shellAliases = {
    plasma-restart = ''
      plasmashell --replace &
    '';
  };

  # turn on some programs and stuff
  # these are nix options which offer some more integration over raw pkg install
  programs.firefox.enable = true;
  programs.gpu-screen-recorder.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
  };

  environment.systemPackages = with pkgs; [
    (discord.override {
      withOpenASAR = true;
      withVencord = true;
    })
    (discord-ptb.override {
      withOpenASAR = true;
      withVencord = true;
    })

    ntfs3g
    krisp.krisp-patch
    krisp.krisp-patch-all
    kdePackages.kcalc
    terminator
    trayscale
    mangohud
    gamescope
    filezilla
    vscode
    mpv
    vlc
    qbittorrent
    gpu-screen-recorder-gtk
    yt-dlp
    libreoffice-fresh
    kdePackages.kdenlive
    steam-run
    bolt-launcher
    chromium
    cinny-desktop
    jellyfin-media-player
    jellyflix
    pyfa
    wineWowPackages.stable
    eve-online
    teamspeak3
    jeveassets
    eve-l-preview
  ];

}
