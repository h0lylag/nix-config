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
  services.fail2ban.ignoreIP = [
    "10.1.1.0/24"
    "100.0.0.0/8"
  ];
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=120
  '';

  # Firewall defaults
  networking.firewall.enable = lib.mkDefault true;

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
  programs.git.enable = true;
  programs.nano.enable = true;

  # nh - Nix helper tool
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 5";
    flake = "/etc/nixos";
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
