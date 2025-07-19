{ config, pkgs, ... }:

let
  # Import krisp overlays
  krisp = import ../pkgs/krisp-patch/krisp-patch.nix { inherit pkgs; };
in
{

  services.flatpak.enable = true;
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # turn on some programs and stuff
  # these are nix options which offer some more integration over raw pkg install
  programs.git.enable = true;
  programs.nano.enable = true;
  programs.java.enable = true;
  programs.firefox.enable = true;
  nixpkgs.config.allowUnfree = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
  };

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/chris/.nixos-config";
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

    pciutils
    nano
    wget
    curl
    terminator
    nixfmt-rfc-style
    htop
    fastfetch
    cht-sh
    nfs-utils
    zip
    unzip
    chromium
    filezilla
    krisp.krisp-patch
    krisp.krisp-patch-all
    libreoffice-fresh
    kdePackages.kdenlive
    mpv
    vlc
    ncdu
    qbittorrent
    yt-dlp
    steam-run
    bolt-launcher
    trayscale
    mangohud
    gamescope
    tree
    vscode
  ];
}
