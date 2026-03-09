# Common profile - Extended tooling for all managed hosts
{
  config,
  lib,
  pkgs,
  nixpkgs-unstable ? null,
  determinate-nix,
  ...
}:

{
  imports = [
    determinate-nix.nixosModules.default
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

  # Essential programs
  programs.java.enable = true;
  programs.nix-ld.enable = true; # Allow use of dynamically linked binaries

  # Extended system packages
  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    smartmontools
    nano
    nix-prefetch-git
    nixfmt
    cht-sh
    nfs-utils
    tree
    python3
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
