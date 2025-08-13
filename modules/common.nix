{ config, pkgs, ... }:

{

  # Flake shit
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;

  # Allow insecure packages required by some gaming/wine-related packages
  nixpkgs.config.permittedInsecurePackages = [
    "libsoup-2.74.3"
    "olm-3.2.16"
  ];

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  services.timesyncd.enable = true;

  # SSH stuff. We turn it on or off in the host config
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  services.openssh.settings.PasswordAuthentication = true;
  services.openssh.settings.KbdInteractiveAuthentication = false;
  services.fail2ban.enable = true;
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=30
  '';

  # add shit to run on shell init
  environment.interactiveShellInit = ''
    fastfetch
  '';

  environment.shellAliases = {
    git-pull-force = ''
      echo "POTENTIAL DATA LOSS"
      echo "THIS WILL PULL AND OVERWRITE EVERYTHING LOCAL FROM GIT"
      read -rp " Continue? [y/N] " yn
      if [[ $yn =~ ^[Yy] ]]; then
        git fetch --all
        git reset --hard @{u}
        git clean -fd
        echo "git-pull-force complete."
      else
        echo "Aborted; no changes made."
      fi
    '';
  };

  users.users = {
    chris = {
      isNormalUser = true;
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWU3a+HOcu4woQiuMoCSxrW8g916Z9P05DW8o7cGysH chris@relic"
      ];
    };
  };

  # turn on some programs and stuff
  programs.git.enable = true;
  programs.nano.enable = true;
  programs.java.enable = true;
  nixpkgs.config.allowUnfree = true;

  # Enable LD, to allow use of dynamically linked binaries
  programs.nix-ld.enable = true;

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 5";
    flake = "/home/chris/.nixos-config";
  };

  environment.systemPackages = with pkgs; [
    pciutils
    nano
    wget
    curl
    nix-prefetch-git
    nixfmt-rfc-style
    htop
    fastfetch
    cht-sh
    nfs-utils
    zip
    unzip
    ncdu
    tree
    screen
    rsync
    pv
    parted
  ];

}
