{ config, pkgs, ... }:

let
  # Import krisp overlays
  krisp = import ../pkgs/krisp-patch/krisp-patch.nix { inherit pkgs; };
in
{
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
  ];
}
