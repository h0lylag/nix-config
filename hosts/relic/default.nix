# relic - Main desktop and gaming machine
{
  pkgs,
  eve-l-preview-2,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/workstation.nix
    ../../profiles/gaming.nix
    ../../features/tailscale.nix
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
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

  # NFS mounts with automount to avoid UI hangs
  # soft mode: fail RPCs instead of blocking indefinitely
  # fileSystems = {
  #   "/mnt/hdd-pool/main" = {
  #     device = "10.1.1.5:/mnt/hdd-pool/main";
  #     fsType = "nfs";
  #     options = [
  #       "rw"
  #       "vers=4.2"
  #       "x-systemd.automount"
  #       "noauto"
  #       "x-systemd.idle-timeout=1min"
  #       "nofail"
  #       "soft"
  #       "timeo=150"
  #       "retrans=2"
  #       "bg"
  #     ];
  #   };

  #   "/mnt/nvme-pool/scratch" = {
  #     device = "10.1.1.5:/mnt/nvme-pool/scratch";
  #     fsType = "nfs";
  #     options = [
  #       "rw"
  #       "vers=4.2"
  #       "x-systemd.automount"
  #       "noauto"
  #       "x-systemd.idle-timeout=2min"
  #       "nofail"
  #       "soft"
  #       "timeo=100"
  #       "retrans=2"
  #       "bg"
  #     ];
  #   };
  # };

  services = {
    open-webui.enable = false;

    ollama = {
      enable = false;
      acceleration = "rocm";
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
    pkgs.wmctrl
    pkgs.maim
    pkgs.xdotool
    pkgs.ydotool
    pkgs.rustdesk-flutter
    pkgs.pgadmin4-desktopmode
    pkgs.gimp3-with-plugins
    (pkgs.callPackage ../../pkgs/insta360-studio/default.nix { })
    (eve-l-preview-2.packages.${pkgs.system}.default)
  ];

  system.stateVersion = "25.05";
}
