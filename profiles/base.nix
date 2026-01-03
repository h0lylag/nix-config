# Base profile - Universal configuration for all systems
# This is the foundation that every machine inherits
{
  config,
  lib,
  pkgs,
  nixpkgs-unstable ? null,
  ...
}:

{
  imports = [
    ../modules/mail2discord.nix
  ];

  # Nix settings
  nix.settings = {

    # 0 uses all available cores; 1 is serial
    eval-cores = lib.mkDefault 0;

    experimental-features = [
      "nix-command"
      "flakes"
      "parallel-eval"
    ];
    auto-optimise-store = true;
  };

  # Allow insecure packages required by some gaming/wine-related packages
  nixpkgs.config.permittedInsecurePackages = [
    "libsoup-2.74.3"
    "olm-3.2.16"
    "qtwebengine-5.15.19"
  ];

  # Timezone and locale
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  services.timesyncd.enable = true;

  # SSH defaults - turn it on or off in profiles/hosts
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  services.openssh.settings.PasswordAuthentication = true;
  services.openssh.settings.KbdInteractiveAuthentication = false;
  services.openssh.enable = lib.mkDefault false; # Profiles decide if SSH is needed

  # Security
  services.fail2ban.enable = true;
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=120
  '';

  # Firewall defaults
  networking.firewall.enable = lib.mkDefault true;

  # Shell configuration
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
    gpnh = ''
      cd "/etc/nixos"
      git pull origin main
      nh os switch
    '';
  };

  # Default user configuration
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

  # Essential programs
  programs.git.enable = true;
  programs.nano.enable = true;
  programs.java.enable = true;
  programs.nix-ld.enable = true; # Allow use of dynamically linked binaries
  nixpkgs.config.allowUnfree = true;

  # nh - Nix helper tool
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 5";
    flake = "/etc/nixos";
  };

  # Base system packages
  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    smartmontools
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
    sops
    age
    jq
  ];

  # sops-nix: enable secrets management on all systems
  # Generate and use a system-managed age key at /var/lib/sops-nix/key.txt (created on first switch)
  sops = {
    age.generateKey = true;
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };

  # Mail2Discord: intercept local mail and forward to Discord
  # This triggers sops key generation on first deployment
  services.mail2discord = {
    enable = true;
    sopsFile = ../secrets/mail2discord.yaml;
  };
}
