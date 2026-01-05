# relic - Main desktop and gaming machine
{
  pkgs,
  nixpkgs,
  ...
}:

let
  pkgs-stable = import nixpkgs {
    system = pkgs.system;
    config.allowUnfree = true;
  };
in

{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/workstation.nix
    ../../profiles/gaming.nix
    ../../features/tailscale.nix
  ];

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      limine = {
        enable = true;
        efiSupport = true;
        secureBoot.enable = true;
      };
    };

    kernelPackages = pkgs.linuxPackages;

    # ASUS X670E-F workarounds for PCIe issues
    blacklistedKernelModules = [ "mt7921e" ];
    kernelParams = [
      "pcie_port_pm=off"
      "pcie_aspm.policy=performance"
    ];
  };

  networking.hostName = "relic";

  # Samba mounts with automount to avoid UI hangs
  # Automounts disconnect when idle to prevent freezing on network loss
  fileSystems = {
    "/mnt/hdd-pool/main" = {
      device = "//10.1.1.5/main";
      fsType = "cifs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=60"
        "x-systemd.device-timeout=5s"
        "x-systemd.mount-timeout=5s"
        "mfsymlinks"
        "cifsacl"
        "credentials=/etc/smb-secrets"
      ];
    };

  services = {
    open-webui.enable = false;

    ollama = {
      enable = false;
      package = pkgs.ollama-rocm;
      loadModels = [
        "gpt-oss:latest"
        "deepseek-r1:latest"
        "gemma3:latest"
      ];
    };
  };

  # Daily jEveAssets update at 4 AM
  systemd.services.jeveassets-update = {
    description = "jEveAssets Daily Update";
    startAt = "04:00";
    serviceConfig.Type = "oneshot";
    path = [ (pkgs.callPackage ../../pkgs/jeveassets/default.nix { }) ];
    environment.JEVE_HEADLESS = "1";
    script = "jeveassets -update";
  };

  environment.systemPackages = [
    pkgs.sbctl
    pkgs.efibootmgr
    pkgs.wmctrl
    pkgs.maim
    pkgs.xdotool
    pkgs.ydotool
    pkgs-stable.rustdesk-flutter
    pkgs.pgadmin4-desktopmode
    pkgs.gimp3-with-plugins
    (pkgs.callPackage ../../pkgs/insta360-studio/default.nix { })
  ];

  system.stateVersion = "25.05";
}
