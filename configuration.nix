# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./mounts.nix
    ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    networkmanager.enable = true;
    hostName = "arbiter";
  };

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  services = {

    # plasma6 + wayland
    desktopManager.plasma6.enable = true;
    xserver = {
      enable = true;
      displayManager.sddm.enable = true;
      displayManager.sddm.autoNumlock = true;
      displayManager.sddm.wayland.enable = true;
      displayManager.defaultSession = "plasma";
    };

    #enable pipewire and other audio shit
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
 
    # misc    
    fstrim.enable = true;
    printing.enable = true;
    flatpak.enable = true;
    
  };


  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;

  # Configure keymap in X11
  #services.xserver = {
  #  layout = "us";
  #  xkbVariant = "";
  #};

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.chris = {
    isNormalUser = true;
    description = "Chris";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      #firefox
      #kate
    ];
  };

  nixpkgs.config.allowUnfree = true;

  environment.interactiveShellInit = ''
    neofetch
  '';

  nix.settings.experimental-features = [ "nix-command" "flakes" ];


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  nano
  git
  wget
  curl
  htop
  neofetch
  cht-sh
  nfs-utils
  ];

#  environment.sessionVariables = {
#    GDK_SCALE = "2";
#  };


  # font config
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [ 
      roboto
      roboto-mono
    ];

    fontconfig = {
      defaultFonts = {
        #serif = [ "Vazirmatn" "Ubuntu" ];
        #sansSerif = [ "Vazirmatn" "Ubuntu" ];
        monospace = [ "Roboto Mono" ];
      };
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
