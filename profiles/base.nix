# Base profile - Survival essentials for all systems
# Minimum required to reach, identify, and manage a host
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../features/tailscale.nix
  ];

  nix.settings.experimental-features = lib.mkDefault [
    "nix-command"
    "flakes"
  ];

  # Timezone and locale
  time.timeZone = lib.mkDefault "America/Los_Angeles";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  services.timesyncd.enable = lib.mkDefault true;

  # SSH defaults - turn it on or off in profiles/hosts
  services.openssh.settings.PermitRootLogin = lib.mkDefault "prohibit-password";
  services.openssh.settings.PasswordAuthentication = lib.mkDefault true;
  services.openssh.settings.KbdInteractiveAuthentication = lib.mkDefault false;
  services.openssh.enable = lib.mkDefault true;

  # Security
  services.fail2ban.enable = lib.mkDefault true;
  services.fail2ban.ignoreIP = lib.mkDefault [
    "10.1.1.0/24"
    "100.0.0.0/8"
  ];
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=120
  '';

  # Firewall defaults
  networking.firewall.enable = lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.allowedUDPPorts = lib.mkDefault [ ];

  nixpkgs.config.allowUnfree = true;

  # Shell configuration
  environment.interactiveShellInit = ''
    fastfetch
  '';

  environment.shellAliases = {
    gpf = ''
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
      if ! git pull origin main; then
        echo "Git pull failed."
        if [[ -n $(git status --porcelain) ]]; then
          echo "Unstaged/Uncommitted changes detected."
        fi
        read -p "Do you want to reset --hard and force pull? [y/N] " yn
        if [[ $yn =~ ^[Yy]$ ]]; then
          git fetch origin main
          git reset --hard origin/main
        else
          echo "Aborting."
          return 1
        fi
      fi
      nh os switch
    '';
  };

  # Default user configuration
  users.users = {
    root = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWU3a+HOcu4woQiuMoCSxrW8g916Z9P05DW8o7cGysH chris@relic"
      ];
    };
    chris = {
      isNormalUser = true;
      initialPassword = "chris";
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
  programs.git.enable = lib.mkDefault true;
  programs.nano.enable = lib.mkDefault true;

  # nh - Nix helper tool
  programs.nh = {
    enable = lib.mkDefault true;
    clean.enable = lib.mkDefault true;
    clean.extraArgs = lib.mkDefault "--keep-since 7d --keep 5";
    flake = lib.mkDefault "/etc/nixos";
  };

  # Base system packages
  environment.systemPackages = with pkgs; [
    htop
    curl
    wget
    zip
    unzip
    ncdu
    screen
    rsync
    fastfetch
  ];
}
