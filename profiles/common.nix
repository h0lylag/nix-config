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
    "electron-39.8.10"
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
    comma
  ];

}
