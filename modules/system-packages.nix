{ config, pkgs, ... }:

let
  # Import krisp overlays
  krisp = import ../pkgs/krisp-patch/krisp-patch.nix { inherit pkgs; };
in
{

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

  # cache for nix-gaming
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
