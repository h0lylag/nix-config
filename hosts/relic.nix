# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  krisp = import ../krisp-patch.nix { inherit pkgs; };
in

{
  imports =
    [ # Include the results of the hardware scan.
      ../hardware/relic.nix
      ../modules/tailscale.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.blacklistedKernelModules = [ "mt7921e" ];
  boot.kernelParams = [
    "pcie_port_pm=off"
    "pcie_aspm.policy=performance"
  ];



  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  networking.hostName = "relic";
  #networking.wireless.enable = true;
  networking.networkmanager.enable = true;

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.roboto-mono
  ];

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };


  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.chris = {
    isNormalUser = true;
    description = "Chris";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "chris";

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


  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # networking.firewall.enable = false;


  # DO NOT CHANGE
  system.stateVersion = "25.05";

}
