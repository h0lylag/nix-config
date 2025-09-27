{
  config,
  pkgs,
  winapps,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/tailscale.nix
    ../../modules/desktop.nix
    ../../modules/star-citizen.nix
    ../../modules/podman.nix
    ../../modules/mail2discord.nix
  ];

  # Bootloader and kernel
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages;

  # enable our user to use input devices - read keyboards, mice, etc for hotkeys
  hardware.uinput.enable = true;
  users.users.chris = {
    extraGroups = [
      "input"
      "podman"
    ];
  };

  # Host/network basics
  networking.hostName = "relic";

  # mullvad needs systemd-resolved
  # https://discourse.nixos.org/t/connected-to-mullvadvpn-but-no-internet-connection/35803/8?u=lion
  services.resolved.enable = true;
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved"; # let NM hand DNS to resolved

  # ASUS X670E-F bullshit 'fixes' (they dont fix it)
  boot.blacklistedKernelModules = [ "mt7921e" ];
  boot.kernelParams = [
    "pcie_port_pm=off"
    "pcie_aspm.policy=performance"
  ];

  # More forgiving NFS mounts (avoid UI hangs):
  # - x-systemd.automount + noauto: mount on first access instead of at boot
  # - x-systemd.idle-timeout=1min: auto unmount when idle to release hangs
  # - nofail: don't drop to emergency shell if server unavailable
  # - soft,timeo=150,retrans=2: fail RPCs instead of hard blocking (suitable for mostly read / casual access)
  # - bg: retry in background
  # - vers=4.2 (adjust if needed)
  # NOTE: For critical write integrity remove 'soft'
  fileSystems."/mnt/hdd-pool/main" = {
    device = "10.1.1.5:/mnt/hdd-pool/main";
    fsType = "nfs";
    options = [
      "rw"
      "vers=4.2"
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=1min"
      "nofail"
      "soft"
      "timeo=150" # (1/10th sec units) => 15s RPC timeout
      "retrans=2"
      "bg"
      # "fsc"           # enable FS-Cache if desired (needs cachefilesd service)
    ];
  };

  fileSystems."/mnt/nvme-pool/scratch" = {
    device = "10.1.1.5:/mnt/nvme-pool/scratch";
    fsType = "nfs";
    options = [
      "rw"
      "vers=4.2"
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=2min"
      "nofail"
      "soft"
      "timeo=100" # 10s for scratch a bit faster fail
      "retrans=2"
      "bg"
    ];
  };

  # enable ollama and webui
  services.open-webui.enable = true;
  services.ollama = {
    enable = true;
    acceleration = "rocm"; # rocm for AMD GPUs, cuda for NVIDIA GPUs
    loadModels = [
      "gpt-oss:latest"
      "deepseek-r1:latest"
      "gemma3:latest"
    ]; # declare models to load https://ollama.com/library
  };

  # service to run jEveAssets daily at 4am
  systemd.services.jeveassets-update = {
    description = "jEveAssets Daily Update";

    startAt = "04:00";
    serviceConfig = {
      Type = "oneshot";
    };

    path = [ (pkgs.callPackage ../../pkgs/jeveassets/default.nix { }) ];
    environment.JEVE_HEADLESS = "1";
    script = ''
      jeveassets -update
    '';
  };

  services.openssh.enable = false;

  # Intercept local mail and forward to Discord via webhook from sops
  services.mail2discord.enable = true;

  # Firewall
  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];

  # Make the Insta360 Studio launcher available on this host
  environment.systemPackages = [
    (pkgs.callPackage ../../pkgs/insta360-studio/default.nix { })
  ]
  ++ [
    # WinApps core package and optional launcher
    (winapps.packages.${pkgs.system}.winapps)
    (winapps.packages.${pkgs.system}.winapps-launcher)
  ];

  # sops-nix: enable secrets management
  # Use shared default from modules/common.nix (secrets/common.yaml)
  # and add host-only secrets from secrets/relic.yaml via the helper below.
  sops =
    let
      # Helper to source a secret key from this host's relic.yaml
      fromRelic = name: {
        sopsFile = ../../secrets/hosts/relic.yaml;
      };
    in
    {
      # Generate and use a system-managed age key at /var/lib/sops-nix/key (created on first switch)
      age.generateKey = true;
      age.keyFile = "/var/lib/sops-nix/key";
      secrets = { };
    };

  # Don't fuck with it
  system.stateVersion = "25.05";

}
