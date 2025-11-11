# Workstation profile - Full graphical workstation configuration
{
  config,
  lib,
  pkgs,
  ...
}:

let
  krisp = pkgs.callPackage ../pkgs/krisp-patch/default.nix { };
  wine-test = pkgs.callPackage ../pkgs/wine-test/default.nix { };
in

{
  imports = [
    ./base.nix
    ../features/podman.nix
  ];

  # Workstation machines get systemd-resolved for VPN compatibility (mullvad, etc.)
  services.resolved.enable = lib.mkDefault true;

  # NetworkManager for desktop convenience
  networking.networkmanager = {
    enable = lib.mkDefault true;
    dns = lib.mkDefault "systemd-resolved";
  };

  # Workstations typically don't need SSH (can override if desired)
  services.openssh.enable = lib.mkDefault false;

  # Workstation firewall is more restrictive by default
  # Hosts can open ports as needed
  networking.firewall = {
    enable = lib.mkDefault true;
    allowedTCPPorts = lib.mkDefault [ ];
    allowedUDPPorts = lib.mkDefault [ ];
  };

  # Enable our user to use input devices for hotkeys, controllers, etc.
  hardware.uinput.enable = lib.mkDefault true;

  # Default workstation user configuration
  # Hosts can extend this with additional groups
  users.users.chris = {
    extraGroups = [
      "input"
      "podman"
      "networkmanager"
    ];
  };

  # Hardware configuration for graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # KDE Plasma Desktop Environment
  services.desktopManager.plasma6.enable = lib.mkDefault true;
  services.displayManager.sddm.enable = lib.mkDefault true;
  services.displayManager.autoLogin.enable = lib.mkDefault true;
  services.displayManager.autoLogin.user = lib.mkDefault "chris";

  # Pipewire audio and real-time support
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Printing support
  services.printing.enable = lib.mkDefault true;
  services.avahi = {
    enable = lib.mkDefault true;
    nssmdns4 = lib.mkDefault true;
    openFirewall = lib.mkDefault true;
  };

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.roboto-mono
  ];

  # Flatpak support
  xdg.portal.enable = true;
  services.flatpak.enable = lib.mkDefault true;

  # Add Flathub at activation time
  system.activationScripts.setupFlathub = lib.mkDefault ''
    ${pkgs.flatpak}/bin/flatpak --system remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  '';

  # Shell aliases
  environment.shellAliases = {
    plasma-restart = ''
      plasmashell --replace &
    '';
  };

  # Mullvad VPN client
  services.mullvad-vpn = {
    enable = lib.mkDefault true;
    package = pkgs.mullvad-vpn;
  };

  # Programs with NixOS integration
  programs.firefox.enable = lib.mkDefault true;
  programs.gpu-screen-recorder.enable = lib.mkDefault true;

  programs.kde-pim = {
    enable = lib.mkDefault true;
    kmail = lib.mkDefault true;
  };

  # Chrome/Chromium with Wayland backend
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Workstation packages
  environment.systemPackages = with pkgs; [

    (discord.override {
      withOpenASAR = true;
      withVencord = true;
    })

    (discord-ptb.override {
      withOpenASAR = true;
      withVencord = true;
    })

    (chromium.override {
      enableWideVine = false;
    })

    ntfs3g
    filezilla
    krisp.krisp-patch
    krisp.krisp-patch-all
    mpv
    vlc
    gpu-screen-recorder-gtk
    yt-dlp
    kdePackages.kdenlive
    kdePackages.skanlite
    kdePackages.kcalc
    kdePackages.kolourpaint
    python3
    python313Packages.tkinter
    python313Packages.requests
    terminator
    vscode
    qbittorrent
    libreoffice-fresh
    wineWowPackages.stable
    winetricks
    signal-desktop
    teamspeak3
    nheko
    trayscale
  ];
}
